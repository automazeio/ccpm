# Using CCPM with a database

CCPM takes a feature from a PRD to an epic, to tasks, to GitHub issues, and then to agents that implement those issues. This guide covers projects that store data: how to keep those agents from sharing one writable database.

[Neon](https://neon.com) is the path this guide walks through. Neon is a serverless Postgres provider (part of Databricks). The same rules apply to any database you can clone.

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

Record branch names in the epic. Do not record connection strings. A file such as `.claude/epics/<name>/database.md` is enough. CCPM does not read that file; it is there so the next session, and the next agent, can see which databases exist.

Run the steps below yourself when you sync an epic, when you start a writing stream, and when you close the issue or merge the epic. The skill's scripts do not call Neon.

## Works the same without Neon

If you are not on Neon, keep the mapping above and swap the mechanism:

- One Postgres database per epic (`CREATE DATABASE epic_order_status`) and one more per parallel writer, or one schema per writer with its own `search_path`.
- Or one container per worktree, with its own port and volume, started from the worktree directory.
- Put the connection string in an env var for that worktree or that agent.
- Make schema changes a task with `parallel: false`. Point every task that needs the new schema at it with `depends_on`.
- Drop the extra database when the issue closes, and drop the epic database when the epic merges.

Anything that gives you a separate database (or a separate schema) and a connection string fits this guide. The rest of the page uses Neon branches, which are a copy of the parent you can create in about a second. Writes on a branch stay on that branch.

## Set up Neon

You need a Neon account, a project, Node.js 20.19 or newer, and the Neon CLI. The CLI command is `neon`. `neonctl` is an alias, so every command below works with either name.

```bash
npm i -g neon
neon login
```

`brew install neonctl` installs the same CLI. In CI, or anywhere a browser login is awkward, create an API key in the Neon Console and export it in your shell. Do not commit it.

```bash
export NEON_API_KEY=<your-api-key>
```

Find the project id, then the default branch. Projects created with the CLI or API use `main`. Projects created in the Console use `production`. `neon branches list` marks the default.

```bash
neon projects list
neon branches list --project-id "$NEON_PROJECT_ID"
```

Add these to the project's `.gitignore` before you create branches. A worktree uses the same ignore rules. The CLI also adds `.neon` the first time it writes that file; adding it yourself covers the worktree you create first.

```
.env
.env.local
.env.*.local
.env.issue-*
.neon
```

`neon branches create` prints a connection URI unless you pass `--no-secrets` (Neon CLI 4.9.0 and later; older releases ignore the flag and still print it). Do not paste that URI into a task file, an issue comment, or a commit. `neon connection-string` prints a password too. Use it in a local shell, not in a log you keep.

## Create one branch per epic

Sync the epic first. CCPM checks out `main`, pulls, and adds the worktree:

```bash
git worktree add ../epic-<name> -b epic/<name>
```

Create a Neon branch with the same name, from the branch you actually develop against. `--parent` defaults to the project's default branch. Pass it anyway so the parent is obvious in the command history. `neon checkout --create` always branches from the default branch, so use `branches create` when the parent is something else.

```bash
neon branches create \
  --name epic/order-status \
  --parent main \
  --project-id "$NEON_PROJECT_ID" \
  --no-secrets
```

Then point the worktree at that branch. A sibling worktree does not see the `.neon` file in the main checkout. The CLI only walks up parent directories, and the worktree's parents are not the main checkout. Run checkout inside the worktree.

```bash
cd ../epic-order-status
neon checkout epic/order-status --project-id "$NEON_PROJECT_ID"
```

Checkout writes `.neon` and pulls Neon variables into the existing `.env`, or into `.env.local` if there is no `.env`. You get `DATABASE_URL` (pooled), `DATABASE_URL_UNPOOLED` (direct), and `NEON_BRANCH`. Other lines in the file are left alone.

`DATABASE_URL` goes through Neon's pooler (PgBouncer in transaction mode). Use it for the app. Use `DATABASE_URL_UNPOOLED` for schema migrations, `pg_dump`, and anything that needs session state (`SET`, `LISTEN/NOTIFY`, advisory locks, temporary tables). The pooled hostname contains `-pooler`. The direct hostname does not.

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

Write the branch name into `.claude/epics/order-status/database.md` in the worktree and commit that file. Leave the URIs out.

## Give parallel writers their own branches

Create a child branch only for a task or stream that will write while another writer is active. Create it from the epic branch, after that branch has the schema the child needs.

Do this in two cases:

- Two tasks are both `parallel: true` and both write rows or run migrations.
- One issue's analysis has two streams that both write, and both are allowed to start.

```bash
neon branches create \
  --name epic/order-status/issue-1236 \
  --parent epic/order-status \
  --project-id "$NEON_PROJECT_ID" \
  --no-secrets
```

Do not run `neon env pull` for that child without `--file`. A pull with no `--file` rewrites `DATABASE_URL` in the shared `.env` / `.env.local`, and every agent in the worktree follows the last writer.

Pass the URL only to the agent that owns the branch:

```bash
export DATABASE_URL="$(neon connection-string epic/order-status/issue-1236 --pooled --project-id "$NEON_PROJECT_ID")"
export DATABASE_URL_UNPOOLED="$(neon connection-string epic/order-status/issue-1236 --project-id "$NEON_PROJECT_ID")"
```

If the harness cannot take env vars and instead reads a file, pull into a file that only that agent loads. `.env.issue-*` is gitignored above.

```bash
neon env pull \
  --branch epic/order-status/issue-1236 \
  --file .env.issue-1236 \
  --project-id "$NEON_PROJECT_ID"
```

Add this to the agent prompt CCPM already uses for a stream. The rest of that prompt (work only in the assigned files, commit as `Issue #<N>: ...`, no `--force`) stays as it is.

```text
Database: use DATABASE_URL and DATABASE_URL_UNPOOLED from your environment
(or from .env.issue-<N> if that file was given to you).
Do not edit the shared .env or .env.local.
Do not print the connection string into a commit, a progress file, or a GitHub comment.
Neon branch name for this stream: epic/order-status/issue-<N>
```

Read-only streams stay on the epic branch. They do not need a child.

## Run schema migrations in order

Give the schema its own task. Mark it `parallel: false`. Put every task that queries the new tables in `depends_on`. Put any other task that edits the same migration files in `conflicts_with`.

Inside one issue, the database stream is the same idea: other streams list it as a dependency and wait until it finishes. That stream is the only one that applies migrations.

Run the migration against the epic branch, on the direct connection, from the worktree:

```bash
cd ../epic-order-status
export DATABASE_URL="$DATABASE_URL_UNPOOLED"

# Use the migrator this project already has. One of these, not all of them:
# npx prisma migrate dev
# npx drizzle-kit migrate
# alembic upgrade head
# rails db:migrate
```

Prisma Migrate, Drizzle Kit, and Django's `migrate` need the direct connection. On Neon, `DATABASE_URL` from `neon env pull` is the pooled string, and `DATABASE_URL_UNPOOLED` is the direct one. Point the migrator at `DATABASE_URL_UNPOOLED`. For Prisma 7, set the datasource URL in the Prisma config file to `env("DATABASE_URL_UNPOOLED")`. For Prisma 6 and earlier, set `directUrl = env("DATABASE_URL_UNPOOLED")` on the datasource. See [Schema migrations with Prisma and Neon](https://neon.com/docs/guides/prisma-migrations).

Create child branches after this migration has been applied, so each child starts from the new schema. If a child was created too early, reset it from the epic branch:

```bash
neon branches reset epic/order-status/issue-1236 --parent --project-id "$NEON_PROJECT_ID"
```

Reset replaces the child with the parent's current schema and data. The connection string stays the same. It is not a merge. Local rows on the child are gone. Reset fails while that child has children of its own; delete those first, or pass `--preserve-under-name` to keep the old state under a new name. See [Reset from parent](https://neon.com/docs/guides/reset-from-parent).

When the parent database holds data you should not copy, create the epic branch as schema-only. This is beta. The branch copies tables, views, and roles, and no rows. It is a root branch: it has no parent, and `neon branches reset --parent` does not apply. Root-branch limits depend on the Neon plan.

```bash
neon branches create \
  --name epic/order-status \
  --schema-only \
  --project-id "$NEON_PROJECT_ID" \
  --no-secrets
```

If that flag is rejected, create the branch in the Neon Console and choose Schema only. Further agent branches can still use `--parent epic/order-status`. Those children are normal branches. See [Schema-only branches](https://neon.com/docs/guides/branching-schema-only).

## Clean up branches

Deleting a Neon branch deletes its databases, roles, and compute. You cannot delete a branch that still has children. Delete the children first. You cannot delete the project's default branch.

When you close an issue, delete the branches that belonged to that issue:

```bash
neon branches delete epic/order-status/issue-1236 --project-id "$NEON_PROJECT_ID"
```

When you merge the epic, CCPM removes the git worktree, deletes the git branch `epic/<name>`, archives `.claude/epics/<name>/`, and closes the epic issue. It does not touch Neon. After the child branches are gone, delete the epic branch:

```bash
neon branches delete epic/order-status --project-id "$NEON_PROJECT_ID"
```

Note the branch name in the epic issue comment if you want the cleanup in the GitHub trail. Do not include the connection string.

To change or clear an expiry later:

```bash
neon branches set-expiration epic/order-status \
  --expires-at "2026-11-11T12:00:00Z" \
  --project-id "$NEON_PROJECT_ID"

# omit --expires-at to clear it
neon branches set-expiration epic/order-status --project-id "$NEON_PROJECT_ID"
```

## Optional: Neon MCP

The CLI is the copy-paste path, and it is the one to use in scripts. If the agent should call Neon itself, connect the hosted MCP server. It is for local development and testing. Do not connect it to a production database. Read each action it wants to take before you allow it.

```bash
npx neon@latest mcp
```

That writes the MCP config for the agents you pick and points them at `https://mcp.neon.tech/mcp`. `npx neon@latest init` does that plus project linking. OAuth is the default. An API key works too; keep it out of the repo.

`?readonly=true` on that URL blocks branch creation and hides `get_connection_string`. Leave read-only mode off for the workflow in this guide, or run the CLI yourself.

You can tell the agent:

```text
Create a Neon branch named epic/order-status from parent main
in project <project-id>. Do not write the connection string into
any file that gets committed. I will run neon checkout in the worktree.
```

The server exposes `create_branch` (optional `expiresAt`), `get_connection_string`, and `delete_branch` for this. Full setup, tool list, and the security rules are in the [Neon MCP server docs](https://neon.com/docs/ai/neon-mcp-server).

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

`002` and `003` do not edit the same files, so `conflicts_with` stays empty. They still must not share a database, because both insert rows. Sync might number them `#1235` (schema), `#1236` (API), and `#1237` (test), and it creates `../epic-order-status/` on `epic/order-status`.

From the main checkout, with `NEON_PROJECT_ID` set:

```bash
neon branches create \
  --name epic/order-status \
  --parent main \
  --project-id "$NEON_PROJECT_ID" \
  --no-secrets

cd ../epic-order-status
neon checkout epic/order-status --project-id "$NEON_PROJECT_ID"

# migration task only, direct connection, project migrator
export DATABASE_URL="$DATABASE_URL_UNPOOLED"
```

Start issue 1235 and let that agent apply the migration on the epic branch. Then branch the two writers from the updated parent:

```bash
neon branches create \
  --name epic/order-status/issue-1236 \
  --parent epic/order-status \
  --project-id "$NEON_PROJECT_ID" \
  --no-secrets

neon branches create \
  --name epic/order-status/issue-1237 \
  --parent epic/order-status \
  --project-id "$NEON_PROJECT_ID" \
  --no-secrets
```

Start issues 1236 and 1237 with a `DATABASE_URL` from `neon connection-string` for that issue's branch, as shown above. Each agent commits under `Issue #<N>: ...` in the shared worktree and writes only to its own Neon branch.

Track them the usual way: `standup`, or read `.claude/epics/order-status/updates/<N>/`. Branch names, not URIs, go in `.claude/epics/order-status/database.md`:

```markdown
# Database branches

Neon project: <project-id>
Parent: main

| CCPM unit | Neon branch |
|---|---|
| worktree `../epic-order-status` | `epic/order-status` |
| issue #1236 API | `epic/order-status/issue-1236` |
| issue #1237 integration test | `epic/order-status/issue-1237` |
```

When an issue closes, delete its Neon branch. When the epic merges, delete `epic/order-status` after those children are gone.

```bash
neon branches delete epic/order-status/issue-1236 --project-id "$NEON_PROJECT_ID"
neon branches delete epic/order-status/issue-1237 --project-id "$NEON_PROJECT_ID"
neon branches delete epic/order-status --project-id "$NEON_PROJECT_ID"
```

## Reference

- [Branching with the Neon CLI](https://neon.com/docs/guides/branching-neon-cli)
- [Neon CLI: branches](https://neon.com/docs/cli/branches)
- [connection-string](https://neon.com/docs/cli/connection-string)
- [checkout](https://neon.com/docs/cli/checkout) and [env pull](https://neon.com/docs/cli/env)
- [Connection pooling](https://neon.com/docs/connect/connection-pooling) (pooled vs direct)
- [Schema-only branches](https://neon.com/docs/guides/branching-schema-only)
- [Reset from parent](https://neon.com/docs/guides/reset-from-parent)
- [Neon MCP server](https://neon.com/docs/ai/neon-mcp-server)
