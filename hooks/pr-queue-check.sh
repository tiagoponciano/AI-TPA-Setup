#!/usr/bin/env bash
# pr-queue-check.sh — deterministic half of the pr-queue skill.
#
#   pretool  (PreToolUse, Bash)  before `git push` / `gh pr create` on a feature
#            branch: merge every other open PR on the base in sequence, then this
#            branch on top. Conflict with one of the user's own PRs → blocked.
#            Conflict only with someone else's PR → allowed, with a warning.
#   session  (SessionStart)      list the user's open PRs in this repo that no
#            longer merge clean — against the base, or once the PRs ahead of
#            them land. Context only, never blocks.
#
# Read-only: plumbing (merge-tree + commit-tree) on fetched refs. No checkout, no
# merge, no branch touched. Anything missing (gh, auth, GitHub remote) → silent.

set -uo pipefail

MODE="${1:-pretool}"
INPUT=$(cat)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)
[ -n "$CWD" ] && cd "$CWD" 2>/dev/null

command -v gh >/dev/null 2>&1 || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0
git remote get-url origin 2>/dev/null | grep -q 'github.com' || exit 0

LOCKFILES='(^|/)(pnpm-lock\.yaml|package-lock\.json|yarn\.lock|poetry\.lock|uv\.lock|Gemfile\.lock|Cargo\.lock)$'

# merge_onto <tip> <ref> → prints the new tip, or fails on conflict
merge_onto() {
  local tree
  tree=$(git merge-tree --write-tree "$1" "$2" 2>/dev/null) || return 1
  git commit-tree "$tree" -p "$1" -p "$2" -m "queue" 2>/dev/null
}

# conflict_paths <tip> <ref>
conflict_paths() {
  git merge-tree --write-tree --name-only "$1" "$2" 2>/dev/null |
    sed -n '2,/^$/p' | grep -v '^$' | sort -u | tr '\n' ' '
}

# check_ref <base> <ref> <exclude-pr-number|""> → sets REPORT, OWN_CONFLICT, OTHER_CONFLICT
check_ref() {
  local base="$1" ref="$2" exclude="$3" tip next num head author paths lock
  REPORT="" OWN_CONFLICT=0 OTHER_CONFLICT=0

  if ! git merge-tree --write-tree "origin/$base" "$ref" >/dev/null 2>&1; then
    REPORT+="  CONFLICT with origin/$base in $(conflict_paths "origin/$base" "$ref")"$'\n'
    OWN_CONFLICT=1
  fi

  # Walk the queue oldest first. A PR is to blame when our ref merged clean on
  # the tip before it and stops merging once it's in. A blamed PR is left out of
  # the tip so each later PR is judged on its own. PRs that conflict among
  # themselves are skipped — not this branch's problem.
  tip=$(git rev-parse "origin/$base")
  while IFS=$'\t' read -r num head author; do
    [ -z "$num" ] && continue
    [ "$num" = "$exclude" ] && continue
    git rev-parse -q --verify "origin/$head" >/dev/null || continue
    [ "$(git rev-parse "origin/$head")" = "$(git rev-parse "$ref")" ] && continue
    next=$(merge_onto "$tip" "origin/$head") || continue
    if git merge-tree --write-tree "$tip" "$ref" >/dev/null 2>&1 &&
       ! git merge-tree --write-tree "$next" "$ref" >/dev/null 2>&1; then
      paths=$(conflict_paths "$next" "$ref")
      if [ "$author" = "$ME" ]; then
        REPORT+="  CONFLICT with your #$num ($head) in $paths"$'\n'
        OWN_CONFLICT=1
      else
        REPORT+="  conflict with #$num by $author ($head) in $paths"$'\n'
        OTHER_CONFLICT=1
      fi
      continue   # leave it out of the tip so later PRs are judged on their own
    fi
    tip=$next
  done <<< "$QUEUE"

  lock=$(git diff --name-only "origin/$base...$ref" 2>/dev/null | grep -E "$LOCKFILES" | tr '\n' ' ')
  [ -n "$lock" ] && REPORT+="  lockfile touched: ${lock}— merge this PR last or regenerate after the base updates"$'\n'
  return 0
}

load_queue() {  # load_queue <base> → QUEUE lines: number<TAB>head<TAB>author, oldest first
  QUEUE=$(gh pr list --base "$1" --state open --limit 50 \
    --json number,headRefName,author,isCrossRepository \
    -q 'sort_by(.number) | .[] | select(.isCrossRepository | not) | "\(.number)\t\(.headRefName)\t\(.author.login)"' 2>/dev/null) || return 1
}

ME=$(gh api user -q .login 2>/dev/null) || exit 0

# --- SessionStart -----------------------------------------------------------
if [ "$MODE" = "session" ]; then
  MINE=$(gh pr list --author @me --state open --limit 30 \
    --json number,headRefName,baseRefName -q '.[] | "\(.number)\t\(.headRefName)\t\(.baseRefName)"' 2>/dev/null) || exit 0
  [ -z "$MINE" ] && exit 0
  git fetch -q origin 2>/dev/null || exit 0
  OUT=""
  while IFS=$'\t' read -r num head base; do
    [ -z "$num" ] && continue
    git rev-parse -q --verify "origin/$head" >/dev/null || continue
    load_queue "$base" || continue
    check_ref "$base" "origin/$head" "$num"
    if [ "$OWN_CONFLICT" = 1 ] || [ "$OTHER_CONFLICT" = 1 ]; then
      OUT+="#$num $head → $base"$'\n'"$REPORT"
    fi
  done <<< "$MINE"
  if [ -n "$OUT" ]; then
    printf 'Open PR queue — these PRs of yours no longer merge clean:\n%sTell the user at the start of your reply. Load the pr-queue skill for the merge order; resolve only if asked.\n' "$OUT"
  fi
  exit 0
fi

# --- PreToolUse -------------------------------------------------------------
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' | tr '\n' ' ' | tr -s ' ')
printf '%s' "$CMD" | grep -Eq '(^|[;&|] *)(git +push|gh +pr +create)( |$)' || exit 0

BRANCH=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) || exit 0
case "$BRANCH" in dev|main|master) exit 0 ;; esac   # git-guardrails.sh owns that case

git fetch -q origin 2>/dev/null || exit 0

PR_JSON=$(gh pr view --json number,baseRefName 2>/dev/null || echo '{}')
SELF=$(printf '%s' "$PR_JSON" | jq -r '.number // ""')
BASE=$(printf '%s' "$CMD" | sed -nE 's/.*gh +pr +create.*(--base|-B)[ =]+([^ ]+).*/\2/p')
[ -z "$BASE" ] && BASE=$(printf '%s' "$PR_JSON" | jq -r '.baseRefName // ""')
if [ -z "$BASE" ]; then
  if git rev-parse -q --verify origin/dev >/dev/null; then BASE=dev; else BASE=main; fi
fi
git rev-parse -q --verify "origin/$BASE" >/dev/null || exit 0

load_queue "$BASE" || exit 0
check_ref "$BASE" HEAD "$SELF"
[ -z "$REPORT" ] && exit 0

HEAD_SHA=$(git rev-parse HEAD)
ACK="$(git rev-parse --git-dir)/pr-queue-ack"

if [ "$OWN_CONFLICT" = 1 ] && [ "$(cat "$ACK" 2>/dev/null)" != "$HEAD_SHA" ]; then
  {
    printf 'Blocked (pr-queue): %s conflicts with the open PR queue on %s:\n%s' "$BRANCH" "$BASE" "$REPORT"
    printf 'Report this to the user and propose a merge order (pr-queue skill). Do not resolve on your own.\n'
    printf 'Only if the user explicitly says to push anyway: echo %s > %s, then retry.\n' "$HEAD_SHA" "$ACK"
  } >&2
  exit 2
fi

jq -n --arg ctx "pr-queue — $BRANCH on $BASE:"$'\n'"$REPORT""Mention this to the user." \
  --arg msg "pr-queue: $(printf '%s' "$REPORT" | head -1 | sed 's/^ *//')" \
  '{systemMessage: $msg, hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}}'
exit 0
