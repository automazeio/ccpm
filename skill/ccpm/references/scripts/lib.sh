#!/bin/bash
# Shared helpers for CCPM scripts. Source it with:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# True if the path is a task file: digits only, then ".md" (e.g. 12.md).
# Excludes helper files like 12-analysis.md.
is_task_file() {
  [ -f "$1" ] || return 1
  case "$(basename "$1")" in
    *[!0-9]*.md|.md) return 1 ;;
    *.md) return 0 ;;
  esac
  return 1
}

# True if the directory is an archive bucket, not a live epic.
is_archive_dir() {
  case "$(basename "$1")" in
    archived|archive) return 0 ;;
  esac
  return 1
}

# Print all task files of live epics, one per line.
list_task_files() {
  local epic_dir task_file
  for epic_dir in .claude/epics/*/; do
    [ -d "$epic_dir" ] || continue
    is_archive_dir "$epic_dir" && continue
    for task_file in "$epic_dir"*.md; do
      is_task_file "$task_file" && echo "$task_file"
    done
  done
}

# Read a scalar frontmatter field: frontmatter_field <file> <field>
frontmatter_field() {
  grep "^$2:" "$1" | head -1 | sed "s/^$2: *//"
}

# Read a list frontmatter field as space-separated values.
# Handles [1, 2], ["1", "2"] and [#1, #2].
frontmatter_list() {
  frontmatter_field "$1" "$2" | tr -d '[]"#'"'" | tr ',' ' ' | xargs
}

# True if a task status means done.
is_done_status() {
  case "$1" in
    closed|completed|done) return 0 ;;
  esac
  return 1
}

# Print the dependencies of a task that are not done yet.
# A dependency with no task file counts as not done.
unmet_deps() {
  local task_file="$1" epic_dir dep dep_file dep_status out=""
  epic_dir=$(dirname "$task_file")
  for dep in $(frontmatter_list "$task_file" depends_on); do
    dep_file="$epic_dir/$dep.md"
    if [ -f "$dep_file" ]; then
      dep_status=$(frontmatter_field "$dep_file" status)
      is_done_status "$dep_status" || out="$out $dep"
    else
      out="$out $dep"
    fi
  done
  echo "$out" | xargs
}

# Print tasks listed in conflicts_with that are in progress right now.
active_conflicts() {
  local task_file="$1" epic_dir other other_file other_status out=""
  epic_dir=$(dirname "$task_file")
  for other in $(frontmatter_list "$task_file" conflicts_with); do
    other_file="$epic_dir/$other.md"
    [ -f "$other_file" ] || continue
    other_status=$(frontmatter_field "$other_file" status)
    case "$other_status" in
      in-progress|in_progress) out="$out $other" ;;
    esac
  done
  echo "$out" | xargs
}

# Print the body of a markdown file without its frontmatter.
# Files with no frontmatter are printed as-is.
strip_frontmatter() {
  awk 'NR==1 && $0!="---" {fm=2} fm<2 && $0=="---" {fm++; next} fm>=2' "$1"
}
