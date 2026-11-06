#!/usr/bin/env bash
# pr-size-check.sh — deterministic half of Rule 8 (one feature, at most 500 lines).
#
#   pretool      (PreToolUse, Bash)  before `git push` / `gh pr create` on a feature
#                branch: measure the branch against its base. Over the limit →
#                blocked, unless the user approved this exact commit.
#   count <ref>  print the lines the current branch changes against <ref>.
#
# Read-only apart from `git fetch`. See hooks/docs/pr-size-check.md.

set -uo pipefail

LIMIT=500
GENERATED='(^|/)(pnpm-lock\.yaml|package-lock\.json|yarn\.lock|poetry\.lock|uv\.lock|Gemfile\.lock|Cargo\.lock)$|\.snap$'

# count_lines <base-ref> → additions + deletions on this branch since it left the
# base, skipping binaries, known generated files and linguist-generated paths.
count_lines() {
  local add del path total=0
  cd "$(git rev-parse --show-toplevel)" || return 1   # numstat paths are root-relative
  while IFS=$'\t' read -r -d '' add del path; do
    if [ -z "$path" ]; then           # rename: -z puts old and new paths in their own fields
      read -r -d '' path
      read -r -d '' path
    fi
    [ "$add" = "-" ] && continue      # binary
    printf '%s' "$path" | grep -Eq "$GENERATED" && continue
    case "$(git check-attr linguist-generated -- "$path")" in
      *': set'|*': true') continue ;;
    esac
    total=$((total + add + del))
  done < <(git diff --numstat -z "$1...HEAD")
  echo "$total"
}

# --- count ------------------------------------------------------------------
if [ "${1:-pretool}" = "count" ]; then
  git rev-parse -q --verify "${2:-}" >/dev/null || {
    printf 'pr-size-check: unknown ref: %s\n' "${2:-}" >&2
    exit 1
  }
  count_lines "$2"
  exit $?
fi

# --- PreToolUse -------------------------------------------------------------
INPUT=$(cat)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)
[ -n "$CWD" ] && cd "$CWD" 2>/dev/null
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' | tr '\n' ' ' | tr -s ' ')
printf '%s' "$CMD" | grep -Eq '(^|[;&|] *)(git +push|gh +pr +create)( |$)' || exit 0
printf '%s' "$CMD" | grep -Eq 'git +push( +[^ ]+)* +(--delete|-d)( |$)' && exit 0

BRANCH=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) || exit 0
case "$BRANCH" in dev|main|master) exit 0 ;; esac   # git-guardrails.sh owns that case

git fetch -q origin 2>/dev/null || exit 0

BASE=$(printf '%s' "$CMD" | sed -nE 's/.*gh +pr +create.*(--base|-B)[ =]+([^ ]+).*/\2/p')
[ -z "$BASE" ] && BASE=$(gh pr view --json baseRefName -q .baseRefName 2>/dev/null)
if [ -z "$BASE" ]; then
  if git rev-parse -q --verify origin/dev >/dev/null; then BASE=dev; else BASE=main; fi
fi
git rev-parse -q --verify "origin/$BASE" >/dev/null || exit 0

LINES=$(count_lines "origin/$BASE") || exit 0
[ "$LINES" -le "$LIMIT" ] && exit 0

HEAD_SHA=$(git rev-parse HEAD)
ACK="$(git rev-parse --absolute-git-dir)/pr-size-ack"
[ "$(cat "$ACK" 2>/dev/null)" = "$HEAD_SHA" ] && exit 0

{
  printf 'Blocked (Rule 8): %s changes %d lines against origin/%s; the limit is %d.\n' "$BRANCH" "$LINES" "$BASE" "$LIMIT"
  printf 'Tests and docs count. Report this to the user and propose how to split it into smaller PRs, each shipping one feature.\n'
  printf 'Only if the user explicitly approves this size: echo %s > %s, then retry, and state the reason in the PR Notes.\n' "$HEAD_SHA" "$ACK"
} >&2
exit 2
