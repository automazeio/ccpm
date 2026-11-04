# Using CCPM with a database

CCPM takes a feature from a PRD to an epic, to tasks, to GitHub issues, and then to agents that implement those issues. This guide covers projects that store data: how to keep those agents from sharing one writable database.

[Neon](https://neon.com) is the path this guide walks through. Neon is a serverless Postgres provider (part of Databricks). The same rules apply to any database you can clone.

The helper is `skill/ccpm/references/scripts/neon-branch.sh`. It creates a Neon branch for an epic, and with `--issue` a child branch for one issue. It writes `DATABASE_URL` and `DATABASE_URL_UNPOOLED` into that worktree's env file, and deletes the branches when the epic merges. It is optional. If the Neon CLI is missing, or `NEON_PROJECT_ID` is unset, the script prints a short message and exits 0.

## What CCPM already isolates

CCPM keeps work in files under `.claude/` in the project you are building:

```
.claude/
├── prds/<name>.md
└── epics/<name>/
    ├── epic.md
    ├── <issue>.md          # one task per file, renamed to the GitHub issue number on sync
    ├── <issue>-analysis.md # parallel streams inside one issue
    └── updates/<issue>/    # per-stream progress
```

Sync creates one git branch per epic, `epic/<name>`, and one worktree for it at `../epic-<name>/` (a sibling of the project root). Agents for that epic work in that worktree. They commit as `Issue #<N>: <description>`.

Tasks carry three fields that decide what may run together:

| Field | Meaning |
|---|---|
| `parallel: true` | This task may run at the same time as tasks it does not conflict with |
| `depends_on` | Task numbers, then GitHub issue numbers after sync, that must finish first |
| `conflicts_with` | Issue numbers that touch the same files and must not run together |

Inside one issue, CCPM splits the work into streams (database, service, API, UI, tests). Streams that can start immediately run at the same time. Streams that depend on another stream wait. Every stream still uses the one epic worktree, and each stream is limited to its own files.

That isolates files. It does not isolate data. Agents in one worktree share that directory, including its `.env` file. If they load the same `DATABASE_URL`, they share tables, sequences, and migration history.

## Give each writer its own database

Use one database per thing that writes, and a shared database only when a single writer is active.

| CCPM unit | Database |
|---|---|
| Epic worktree `../epic-<name>/` on branch `epic/<name>` | One database, branched from the database you develop against |
| A task or stream that runs `INSERT`, `UPDATE`, `DELETE`, or a migration while another writer is active | Its own database, created from the epic database after the shared schema is in place |
| Work that does not touch the database (docs, UI against a mock, a type-only change) | No extra database |

On Neon, the epic database is a branch named `epic/<name>`. A writing issue gets a child named `epic/<name>/issue-<N>`. The script records those names in `.claude/epics/<name>/neon-branches.txt` and a short `.claude/epics/<name>/database.md`. Neither file contains a connection string.

Epic sync runs `neon-branch.sh create <name>` after it adds the worktree. Epic merge runs `neon-branch.sh cleanup <name>` before it removes the worktree. Both calls are safe when Neon is not configured.

## Works the same without Neon

If you are not on Neon, keep the mapping above and swap the mechanism:

- One Postgres database per epic (`CREATE DATABASE epic_order_status`) and one more per parallel writer, or one schema per writer with its own `search_path`.
- Or one container per worktree, with its own port and volume, started from the worktree directory.
- Put the connection string in an env var for that worktree or that agent.
- Make schema changes a task with `parallel: false`. Point every task that needs the new schema at it with `depends_on`.
- Drop the extra database when the issue closes, and drop the epic database when the epic merges.

Leave `NEON_PROJECT_ID` unset. `neon-branch.sh` will skip its work. Anything that gives you a separate database (or a separate schema) and a connection string fits this guide. The rest of the page uses Neon branches, which are a copy of the parent you can create in about a second. Writes on a branch stay on that branch.

## Set up Neon

You need a Neon account, a project, Node.js 20.19 or newer, and the Neon CLI. The CLI command is `neon`. `neonctl` is an alias, so the script uses whichever one it finds, preferring `neon`.

```bash
npm i -g neon
neon login
```

`brew install neonctl` installs the same CLI. In CI, or anywhere a browser login is awkward, create an API key in the Neon Console and export it in your shell. Do not commit it.

```bash
export NEON_API_KEY=<your-api-key>
export NEON_PROJECT_ID=<project-id>
```

`NEON_PROJECT_ID` is the switch. Find the id with `neon projects list`. Projects created with the CLI or API use a default branch named `main`. Projects created in the Console use `production`. `neon branches list --project-id "$NEON_PROJECT_ID"` marks the default. Set `NEON_PARENT_BRANCH` when the epic should branch from something other than that default:

```bash
export NEON_PARENT_BRANCH=main
```

The script adds these to `.gitignore` when they are not already ignored, in the epic worktree and in the main checkout. Commit the `.gitignore` change. Do not commit the env file.

```
.env
.env.local
.env.*.local
.env.issue-*
.neon
```

## Create the epic branch

From the project root, after the epic worktree exists (`../epic-<name>/`):

```bash
bash skill/ccpm/references/scripts/neon-branch.sh create order-status
```

If CCPM is installed somewhere else, call the same file under that skill directory:

```bash
bash <skill_path>/references/scripts/neon-branch.sh create order-status
```

`<skill_path>` is the directory that contains `SKILL.md` (`skill/ccpm` in this repo).

What that does:

1. Creates a Neon branch named `epic/order-status`. With `NEON_PARENT_BRANCH` or `--parent`, that branch is the parent. Otherwise Neon uses the project's default branch.
2. Writes the worktree file `../epic-order-status/.env` (mode `600`). Existing lines stay. These keys are replaced:

   - `DATABASE_URL`: pooled connection, for the app
   - `DATABASE_URL_UNPOOLED`: direct connection, for migrations
   - `NEON_BRANCH`: the branch name, which is not a secret

3. Refuses to write if that `.env` is already tracked by git.
4. If the branch already exists, it keeps the branch and refreshes the env file.

A sibling worktree does not see the main checkout's `.neon` file. The script does not need one. It passes `--project-id "$NEON_PROJECT_ID"` on every Neon call.

`DATABASE_URL` goes through Neon's pooler (PgBouncer in transaction mode). Use it for the app. Use `DATABASE_URL_UNPOOLED` for schema migrations, `pg_dump`, and anything that needs session state (`SET`, `LISTEN/NOTIFY`, advisory locks, temporary tables). The pooled hostname contains `-pooler`. The direct hostname does not.

## Give a writing issue its own branch

Run this after the epic branch exists, and after any shared migration has been applied on it. The child is cut from `epic/<name>`, not from production, unless you pass `--parent`.

```bash
bash skill/ccpm/references/scripts/neon-branch.sh create order-status --issue 1236
```

The connection strings go to `../epic-order-status/.env.issue-1236`. The shared `.env` is left alone, so other agents in the worktree do not follow this issue. Pass that file only to the agent for issue 1236. Do not copy it over `.env`, and do not print it into a commit, a progress file, or a GitHub comment.

Do this when:

- Two tasks are both `parallel: true` and both write rows or run migrations.
- One issue's analysis has two streams that both write, and both are allowed to start.

Read-only work stays on the epic branch. It does not need `--issue`.

Add this to the agent prompt CCPM already uses for a stream:

```text
Database: if .env.issue-<N> exists, load DATABASE_URL and
DATABASE_URL_UNPOOLED from that file. Otherwise use the worktree .env.
Do not edit the shared .env. Do not print the connection string.
```

## Run schema migrations in order

Give the schema its own task. Mark it `parallel: false`. Put every task that queries the new tables in `depends_on`. Put any other task that edits the same migration files in `conflicts_with`.

Inside one issue, the database stream is the same idea: other streams list it as a dependency and wait until it finishes. That stream is the only one that applies migrations, and it uses the epic branch (the shared worktree `.env`), not a child.

From the worktree, point the migrator at the direct connection the script wrote:

```bash
cd ../epic-order-status
set -a
. ./.env
set +a
export DATABASE_URL="$DATABASE_URL_UNPOOLED"

# Use the migrator this project already has. One of these, not all of them:
# npx prisma migrate dev
# npx drizzle-kit migrate
# alembic upgrade head
# rails db:migrate
```

Prisma Migrate, Drizzle Kit, and Django's `migrate` need the direct connection. On Neon, `DATABASE_URL` from the script is the pooled string, and `DATABASE_URL_UNPOOLED` is the direct one. For Prisma 7, set the datasource URL in the Prisma config file to `env("DATABASE_URL_UNPOOLED")`. For Prisma 6 and earlier, set `directUrl = env("DATABASE_URL_UNPOOLED")` on the datasource. See [Schema migrations with Prisma and Neon](https://neon.com/docs/guides/prisma-migrations).

Create `--issue` branches after this migration has been applied, so each child starts from the new schema.

## Clean up

Deleting a Neon branch deletes its databases, roles, and compute. Children go first. The project's default branch is never named `epic/<name>`, so the script will not target it.

When an issue closes and it had its own branch:

```bash
bash skill/ccpm/references/scripts/neon-branch.sh cleanup order-status --issue 1236
```

When the epic merges, CCPM runs cleanup with no `--issue`, then removes the git worktree and the git branch `epic/<name>`:

```bash
bash skill/ccpm/references/scripts/neon-branch.sh cleanup order-status
```

Cleanup deletes every child recorded in `neon-branches.txt`. When `python3` is available it also asks Neon for branch names under `epic/<name>/`, so a child that was created outside the script is still removed. Then it deletes `epic/<name>`. `database.md` is left as a note that the branches were deleted. Connection strings are not written there.

If cleanup exits non-zero, stop. Do not remove the git worktree until the Neon branches are gone or you have deleted them yourself.

## Example: order status history

A feature that adds an `order_status_history` table, an API to append a status, and an integration test that inserts rows. Three tasks. The migration goes first. The API and the test both write, so they get child branches after the migration.

Tell CCPM:

```text
I want to build order status history: a table of status changes,
an API to append one, and an integration test that inserts rows.
```

After the PRD and the epic exist:

```text
break down the order-status epic
sync the order-status epic to GitHub
```

Task frontmatter, before sync renames `001.md` to the GitHub issue number:

```yaml
# 001.md  schema
name: Add order_status_history
parallel: false
depends_on: []
conflicts_with: []
```

```yaml
# 002.md  API
name: Append order status API
parallel: true
depends_on: [001]
conflicts_with: []
```

```yaml
# 003.md  integration test
name: Order status integration test
parallel: true
depends_on: [001]
conflicts_with: []
```

`002` and `003` do not edit the same files, so `conflicts_with` stays empty. They still must not share a database, because both insert rows. Sync might number them `#1235` (schema), `#1236` (API), and `#1237` (test), and it creates `../epic-order-status/` on `epic/order-status`. Sync then runs:

```bash
bash skill/ccpm/references/scripts/neon-branch.sh create order-status
```

With `NEON_PROJECT_ID` set, that writes `../epic-order-status/.env`. Start issue 1235 and apply the migration on that epic branch, using `DATABASE_URL_UNPOOLED`. Then:

```bash
bash skill/ccpm/references/scripts/neon-branch.sh create order-status --issue 1236
bash skill/ccpm/references/scripts/neon-branch.sh create order-status --issue 1237
```

Start issues 1236 and 1237 with their own `.env.issue-<N>` files. Each agent commits under `Issue #<N>: ...` in the shared worktree and writes only to its own Neon branch.

Track them the usual way: `standup`, or read `.claude/epics/order-status/updates/<N>/`. Branch names, not URIs, are in `.claude/epics/order-status/database.md`.

When an issue closes, `cleanup order-status --issue <N>`. When the epic merges, `cleanup order-status`.

## Commands the script runs

You do not need these for the normal path. They are what `neon-branch.sh` calls, so you can run the same steps by hand or see why a command failed. The script never prints the connection string. These commands do, so do not paste their output into git.

Create the epic branch. `--parent` is included only when you set a parent. `--no-secrets` (Neon CLI 4.9.0 and later) keeps the URI out of the create output. Older releases ignore the flag and still print it.

```bash
neon branches create \
  --name epic/order-status \
  --parent main \
  --project-id "$NEON_PROJECT_ID" \
  --no-secrets

neon connection-string epic/order-status --pooled --project-id "$NEON_PROJECT_ID"
neon connection-string epic/order-status --project-id "$NEON_PROJECT_ID"
```

The first `connection-string` is `DATABASE_URL`. The second is `DATABASE_URL_UNPOOLED`.

Create a child for one issue:

```bash
neon branches create \
  --name epic/order-status/issue-1236 \
  --parent epic/order-status \
  --project-id "$NEON_PROJECT_ID" \
  --no-secrets
```

Delete children, then the epic branch:

```bash
neon branches delete epic/order-status/issue-1236 --project-id "$NEON_PROJECT_ID"
neon branches delete epic/order-status --project-id "$NEON_PROJECT_ID"
```

`neon branches get <name> --project-id "$NEON_PROJECT_ID"` is how the script checks that a branch exists before it creates or deletes one.

The script does not set a branch expiry, reset a child, or create a schema-only branch. Use the CLI for those.

For a short-lived epic, set an expiry so a forgotten branch is removed even if cleanup is skipped. CLI branches do not expire unless you set this. GNU `date` and BSD `date` differ:

```bash
# Linux
neon branches create \
  --name epic/order-status \
  --parent main \
  --project-id "$NEON_PROJECT_ID" \
  --no-secrets \
  --expires-at "$(date -u -d '+7 days' +%Y-%m-%dT%H:%M:%SZ)"

# macOS
neon branches create \
  --name epic/order-status \
  --parent main \
  --project-id "$NEON_PROJECT_ID" \
  --no-secrets \
  --expires-at "$(date -u -v+7d +%Y-%m-%dT%H:%M:%SZ)"
```

To change or clear an expiry later:

```bash
neon branches set-expiration epic/order-status \
  --expires-at "2026-11-11T12:00:00Z" \
  --project-id "$NEON_PROJECT_ID"

# omit --expires-at to clear it
neon branches set-expiration epic/order-status --project-id "$NEON_PROJECT_ID"
```

If a child was created before the migration landed, reset it from the epic branch. Reset replaces the child with the parent's current schema and data. The connection string stays the same. It is not a merge. Local rows on the child are gone. Reset fails while that child has children of its own. See [Reset from parent](https://neon.com/docs/guides/reset-from-parent).

```bash
neon branches reset epic/order-status/issue-1236 --parent --project-id "$NEON_PROJECT_ID"
```

When the parent database holds data you should not copy, create the epic branch as schema-only and then keep using the script only for children of that branch. Schema-only is beta. The branch copies tables, views, and roles, and no rows. It is a root branch: it has no parent, and `neon branches reset --parent` does not apply. Root-branch limits depend on the Neon plan. If the flag is rejected, create the branch in the Neon Console and choose Schema only. See [Schema-only branches](https://neon.com/docs/guides/branching-schema-only).

```bash
neon branches create \
  --name epic/order-status \
  --schema-only \
  --project-id "$NEON_PROJECT_ID" \
  --no-secrets
```

A normal child of that branch still works:

```bash
bash skill/ccpm/references/scripts/neon-branch.sh create order-status --issue 1236 --parent epic/order-status
```

## Optional: Neon MCP

The script is the path to use in sync, merge, and CI. If the agent should call Neon itself, connect the hosted MCP server. It is for local development and testing. Do not connect it to a production database. Read each action it wants to take before you allow it.

```bash
npx neon@latest mcp
```

That writes the MCP config for the agents you pick and points them at `https://mcp.neon.tech/mcp`. `npx neon@latest init` does that plus project linking. OAuth is the default. An API key works too; keep it out of the repo.

`?readonly=true` on that URL blocks branch creation and hides `get_connection_string`. Leave read-only mode off for this workflow, or run the script yourself.

The server exposes `create_branch` (optional `expiresAt`), `get_connection_string`, and `delete_branch` for this. Full setup, tool list, and the security rules are in the [Neon MCP server docs](https://neon.com/docs/ai/neon-mcp-server).

## Reference

- [Branching with the Neon CLI](https://neon.com/docs/guides/branching-neon-cli)
- [Neon CLI: branches](https://neon.com/docs/cli/branches)
- [connection-string](https://neon.com/docs/cli/connection-string)
- [Connection pooling](https://neon.com/docs/connect/connection-pooling) (pooled vs direct)
- [Schema-only branches](https://neon.com/docs/guides/branching-schema-only)
- [Reset from parent](https://neon.com/docs/guides/reset-from-parent)
- [Neon MCP server](https://neon.com/docs/ai/neon-mcp-server)
