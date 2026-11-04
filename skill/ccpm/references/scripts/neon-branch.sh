#!/bin/bash
# Optional Neon database branches for a CCPM epic.
#
#   neon-branch.sh create <epic> [--parent <branch>] [--issue <N>]
#   neon-branch.sh cleanup <epic> [--issue <N>]
#
# create makes a Neon branch named epic/<epic> (or epic/<epic>/issue-<N>),
# then writes DATABASE_URL and DATABASE_URL_UNPOOLED into the epic worktree.
# cleanup deletes those branches. Child branches go first.
#
# Exits 0 without changing anything when the Neon CLI is missing or
# NEON_PROJECT_ID is unset. Connection strings are written to gitignored
# env files and are never printed.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  neon-branch.sh create <epic> [--parent <branch>] [--issue <N>]
  neon-branch.sh cleanup <epic> [--issue <N>]

create   Neon branch epic/<epic>, or epic/<epic>/issue-<N> with --issue.
         Writes DATABASE_URL (pooled) and DATABASE_URL_UNPOOLED (direct)
         into the epic worktree. Issue branches use .env.issue-<N>.
cleanup  Deletes the issue branch, or the epic branch and every recorded
         child, child branches first.

No-op (exit 0) when `neon`/`neonctl` is not installed or NEON_PROJECT_ID
is unset. Optional: NEON_PARENT_BRANCH, or --parent, for the epic branch.
The issue branch is always cut from epic/<epic> unless --parent is passed.
EOF
}

fail() {
  echo "❌ $*"
  exit 1
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "help" ]; then
  usage
  exit 0
fi

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

command_name="$1"
shift

case "$command_name" in
  create|cleanup) ;;
  *)
    echo "❌ Unknown command: $command_name"
    usage
    exit 1
    ;;
esac

if [ $# -lt 1 ]; then
  echo "❌ Missing epic name"
  usage
  exit 1
fi

epic_name="$1"
shift

issue=""
explicit_parent=""

while [ $# -gt 0 ]; do
  case "$1" in
    --issue)
      [ $# -ge 2 ] || fail "Missing value for --issue"
      issue="$2"
      shift 2
      ;;
    --parent)
      [ "$command_name" = "create" ] || fail "--parent is only valid with create"
      [ $# -ge 2 ] || fail "Missing value for --parent"
      explicit_parent="$2"
      shift 2
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

if ! printf '%s' "$epic_name" | grep -Eq '^[a-z][a-z0-9-]*$'; then
  fail "Epic name must be kebab-case (example: order-status)"
fi

if [ -n "$issue" ] && ! printf '%s' "$issue" | grep -Eq '^[0-9]+$'; then
  fail "Issue must be a GitHub issue number"
fi

if [ -n "$explicit_parent" ] && ! printf '%s' "$explicit_parent" | grep -Eq '^[A-Za-z0-9._/-]+$'; then
  fail "Parent branch name contains unsupported characters"
fi

# Opt-in gate. Non-Neon projects hit one of these and stop.
if command -v neon >/dev/null 2>&1; then
  neon_bin="neon"
elif command -v neonctl >/dev/null 2>&1; then
  neon_bin="neonctl"
else
  echo "Neon CLI not found. Database branch skipped."
  echo "This is optional. Install with: npm i -g neon"
  echo "Then export NEON_PROJECT_ID and re-run neon-branch.sh $command_name $epic_name"
  exit 0
fi

if [ -z "${NEON_PROJECT_ID:-}" ]; then
  echo "NEON_PROJECT_ID is not set. Database branch skipped."
  echo "Export NEON_PROJECT_ID to create a Neon branch for this epic."
  echo "Projects that do not use Neon can ignore this."
  exit 0
fi

epic_branch="epic/$epic_name"
if [ -n "$issue" ]; then
  neon_branch="$epic_branch/issue-$issue"
  if [ -n "$explicit_parent" ]; then
    parent_branch="$explicit_parent"
  else
    parent_branch="$epic_branch"
  fi
else
  neon_branch="$epic_branch"
  if [ -n "$explicit_parent" ]; then
    parent_branch="$explicit_parent"
  else
    parent_branch="${NEON_PARENT_BRANCH:-}"
  fi
fi

find_main_root() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git worktree list --porcelain | awk '/^worktree / { print substr($0, 10); exit }'
  else
    pwd
  fi
}

main_root="$(find_main_root)"

find_worktree() {
  local candidate
  candidate="$(cd "$main_root/.." && pwd)/epic-$epic_name"
  if [ -d "$candidate" ]; then
    printf '%s\n' "$candidate"
    return 0
  fi
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git worktree list --porcelain | awk '/^worktree / { print substr($0, 10) }' |
      while IFS= read -r wt; do
        if [ "$(basename "$wt")" = "epic-$epic_name" ]; then
          printf '%s\n' "$wt"
          break
        fi
      done
  fi
}

worktree="$(find_worktree || true)"

epic_dir=""
if [ -d "$main_root/.claude/epics/$epic_name" ]; then
  epic_dir="$main_root/.claude/epics/$epic_name"
elif [ -d ".claude/epics/$epic_name" ]; then
  epic_dir="$(pwd)/.claude/epics/$epic_name"
elif [ -n "$worktree" ] && [ -d "$worktree/.claude/epics/$epic_name" ]; then
  epic_dir="$worktree/.claude/epics/$epic_name"
elif [ -d "$main_root/.claude/epics" ]; then
  mkdir -p "$main_root/.claude/epics/$epic_name"
  epic_dir="$main_root/.claude/epics/$epic_name"
fi

branches_file=""
if [ -n "$epic_dir" ]; then
  branches_file="$epic_dir/neon-branches.txt"
fi

branch_exists() {
  "$neon_bin" branches get "$1" --project-id "$NEON_PROJECT_ID" >/dev/null 2>&1
}

record_branch() {
  [ -n "$branches_file" ] || return 0
  touch "$branches_file"
  if ! grep -qxF "$1" "$branches_file"; then
    printf '%s\n' "$1" >> "$branches_file"
  fi
}

forget_branch() {
  [ -n "$branches_file" ] && [ -f "$branches_file" ] || return 0
  local tmp
  tmp="$(mktemp)"
  grep -vxF "$1" "$branches_file" > "$tmp" || true
  mv "$tmp" "$branches_file"
}

record_parent() {
  [ -n "$branches_file" ] || return 0
  local label="$1"
  local tmp
  tmp="$(mktemp)"
  if [ -f "$branches_file" ]; then
    grep -v '^# parent:' "$branches_file" > "$tmp" || true
  fi
  {
    printf '# parent: %s\n' "$label"
    cat "$tmp"
  } > "$branches_file"
  rm -f "$tmp"
}

write_database_md() {
  [ -n "$epic_dir" ] || return 0
  local md="$epic_dir/database.md"
  local parent_label="project default"
  local line n
  if [ -f "$branches_file" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
        "# parent: "*) parent_label="${line#\# parent: }" ;;
      esac
    done < "$branches_file"
  fi
  {
    echo "# Database branches"
    echo
    echo "Neon project: $NEON_PROJECT_ID"
    echo "Epic branch: \`$epic_branch\`"
    echo "Parent: $parent_label"
    echo
    echo "Connection strings are not stored here."
    echo
    echo "| CCPM unit | Neon branch | Env file |"
    echo "|---|---|---|"
    if [ -f "$branches_file" ]; then
      while IFS= read -r line || [ -n "$line" ]; do
        [ -n "$line" ] || continue
        case "$line" in
          \#*) continue ;;
        esac
        if [ "$line" = "$epic_branch" ]; then
          echo "| epic worktree | \`$line\` | \`.env\` |"
        elif printf '%s' "$line" | grep -Eq '^epic/[^/]+/issue-[0-9]+$'; then
          n="${line##*-}"
          echo "| issue #$n | \`$line\` | \`.env.issue-$n\` |"
        else
          echo "| branch | \`$line\` | |"
        fi
      done < "$branches_file"
    fi
  } > "$md"
}

ensure_gitignore() {
  local root="$1"
  local ignore="$root/.gitignore"
  local pattern path
  [ -d "$root" ] || return 0
  touch "$ignore"
  for pattern in '.env' '.env.local' '.env.*.local' '.env.issue-*' '.neon'; do
    case "$pattern" in
      .env) path="$root/.env" ;;
      .env.local) path="$root/.env.local" ;;
      .env.*.local) path="$root/.env.example.local" ;;
      .env.issue-*) path="$root/.env.issue-0" ;;
      .neon) path="$root/.neon" ;;
    esac
    if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      if git -C "$root" check-ignore -q "$path" 2>/dev/null; then
        continue
      fi
    elif grep -qxF "$pattern" "$ignore" 2>/dev/null; then
      continue
    fi
    if grep -qxF "$pattern" "$ignore" 2>/dev/null; then
      continue
    fi
    printf '%s\n' "$pattern" >> "$ignore"
    echo "Added $pattern to $ignore"
  done
}

env_target() {
  if [ -z "$worktree" ]; then
    return 1
  fi
  if [ -n "$issue" ]; then
    printf '%s\n' "$worktree/.env.issue-$issue"
  else
    printf '%s\n' "$worktree/.env"
  fi
}

refuse_tracked_env() {
  local file="$1"
  local rel
  rel="$(basename "$file")"
  if [ -z "$worktree" ]; then
    return 0
  fi
  if git -C "$worktree" rev-parse --is-inside-work-tree >/dev/null 2>&1 &&
    git -C "$worktree" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1; then
    fail "$rel is tracked by git in $worktree. Untrack it, ignore it, then re-run. The connection string was not written."
  fi
}

escape_dq() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

write_env_file() {
  local file="$1"
  local branch="$2"
  local pooled="$3"
  local direct="$4"
  local tmp kept
  pooled="$(escape_dq "$pooled")"
  direct="$(escape_dq "$direct")"
  branch="$(escape_dq "$branch")"
  tmp="$(mktemp)"
  if [ -f "$file" ]; then
    grep -vE '^(DATABASE_URL|DATABASE_URL_UNPOOLED|NEON_BRANCH)=' "$file" > "$tmp" || true
  fi
  kept="$(mktemp)"
  if [ -s "$tmp" ]; then
    cat "$tmp" > "$kept"
    printf '\n' >> "$kept"
  fi
  {
    cat "$kept"
    printf 'DATABASE_URL="%s"\n' "$pooled"
    printf 'DATABASE_URL_UNPOOLED="%s"\n' "$direct"
    printf 'NEON_BRANCH="%s"\n' "$branch"
  } > "$file"
  rm -f "$tmp" "$kept"
  chmod 600 "$file"
}

fetch_and_write_env() {
  local branch="$1"
  local file direct pooled
  file="$(env_target)" || true
  if [ -z "${file:-}" ]; then
    echo "Worktree ../epic-$epic_name was not found. Neon branch is ready."
    echo "Re-run create after the epic worktree exists to write the env file."
    return 0
  fi
  refuse_tracked_env "$file"
  ensure_gitignore "$worktree"
  if [ "$worktree" != "$main_root" ]; then
    ensure_gitignore "$main_root"
  fi

  if ! direct="$("$neon_bin" connection-string "$branch" --project-id "$NEON_PROJECT_ID")"; then
    fail "Could not read the direct connection string for $branch"
  fi
  if ! pooled="$("$neon_bin" connection-string "$branch" --pooled --project-id "$NEON_PROJECT_ID")"; then
    fail "Could not read the pooled connection string for $branch"
  fi
  if [ -z "$direct" ] || [ -z "$pooled" ]; then
    fail "Neon returned an empty connection string for $branch"
  fi

  write_env_file "$file" "$branch" "$pooled" "$direct"
  echo "Wrote DATABASE_URL and DATABASE_URL_UNPOOLED to $file"
  echo "That file is gitignored. Do not commit it or paste it into an issue."
}

create_neon_branch() {
  local branch="$1"
  local parent="$2"
  local out
  if branch_exists "$branch"; then
    echo "Neon branch already exists: $branch"
    return 0
  fi
  local -a args
  args=(branches create --name "$branch" --project-id "$NEON_PROJECT_ID" --no-secrets)
  if [ -n "$parent" ]; then
    args+=(--parent "$parent")
  fi
  out="$(mktemp)"
  if ! "$neon_bin" "${args[@]}" >"$out"; then
    if grep -q 'postgresql://' "$out"; then
      echo "neon branches create failed. Output omitted because it contains a connection string."
    else
      cat "$out" >&2
    fi
    rm -f "$out"
    fail "Could not create Neon branch $branch"
  fi
  rm -f "$out"
  echo "Created Neon branch: $branch"
}

delete_neon_branch() {
  local branch="$1"
  if ! branch_exists "$branch"; then
    echo "Neon branch already gone: $branch"
    forget_branch "$branch"
    return 0
  fi
  if ! "$neon_bin" branches delete "$branch" --project-id "$NEON_PROJECT_ID" >/dev/null; then
    fail "Could not delete Neon branch $branch"
  fi
  forget_branch "$branch"
  echo "Deleted Neon branch: $branch"
}

# Child branch names under this epic, from `neon branches list` when python3 is available.
discover_children() {
  command -v python3 >/dev/null 2>&1 || return 0
  local json
  json="$("$neon_bin" branches list --project-id "$NEON_PROJECT_ID" --output json 2>/dev/null)" || return 0
  [ -n "$json" ] || return 0
  printf '%s' "$json" | python3 -c '
import json, sys
raw = sys.stdin.read().strip()
if not raw:
    sys.exit(0)
data = json.loads(raw)
if isinstance(data, dict):
    data = data.get("branches", [])
prefix = sys.argv[1] + "/"
for branch in data:
    name = branch.get("name", "")
    if name.startswith(prefix):
        print(name)
' "$epic_branch" || true
}

if [ "$command_name" = "create" ]; then
  if [ -n "$worktree" ]; then
    refuse_tracked_env "$(env_target)"
  fi
  if [ -n "$issue" ] && ! branch_exists "$epic_branch"; then
    fail "Epic branch $epic_branch does not exist yet. Run: neon-branch.sh create $epic_name"
  fi
  create_neon_branch "$neon_branch" "$parent_branch"
  record_branch "$neon_branch"
  if [ -n "$issue" ]; then
    record_branch "$epic_branch"
  else
    if [ -n "$parent_branch" ]; then
      record_parent "$parent_branch"
    else
      record_parent "project default"
    fi
  fi
  write_database_md
  fetch_and_write_env "$neon_branch"
  if [ -n "$issue" ] && [ -n "$worktree" ]; then
    echo "Pass $worktree/.env.issue-$issue only to the agent on issue #$issue."
    echo "Do not copy it over the shared worktree .env."
  fi
  exit 0
fi

# cleanup
if [ -n "$issue" ]; then
  delete_neon_branch "$epic_branch/issue-$issue"
  write_database_md
  exit 0
fi

children=()
if [ -n "$branches_file" ] && [ -f "$branches_file" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    case "$line" in
      \#*) continue ;;
    esac
    if [ "$line" != "$epic_branch" ]; then
      children+=("$line")
    fi
  done < "$branches_file"
fi
while IFS= read -r line || [ -n "$line" ]; do
  [ -n "$line" ] || continue
  children+=("$line")
done < <(discover_children || true)

if [ "${#children[@]}" -gt 0 ]; then
  deduped=()
  for child in "${children[@]}"; do
    skip=0
    if [ "${#deduped[@]}" -gt 0 ]; then
      for seen in "${deduped[@]}"; do
        if [ "$child" = "$seen" ]; then
          skip=1
          break
        fi
      done
    fi
    if [ "$skip" -eq 0 ]; then
      deduped+=("$child")
    fi
  done
  # Longer names first so a nested branch is removed before its parent.
  while IFS= read -r child || [ -n "$child" ]; do
    [ -n "$child" ] || continue
    delete_neon_branch "$child"
  done < <(printf '%s\n' "${deduped[@]}" | awk '{ print length($0) "\t" $0 }' | sort -nr | cut -f2-)
fi

delete_neon_branch "$epic_branch"

if [ -n "$epic_dir" ]; then
  rm -f "$branches_file"
  cat > "$epic_dir/database.md" <<EOF
# Database branches

Neon branches for epic \`$epic_name\` were deleted.
EOF
fi

echo "Neon cleanup finished for epic $epic_name"
exit 0
