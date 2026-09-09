#!/usr/bin/env bash
# git-guardrails.sh — hard enforcement for the git rules in ~/.claude/CLAUDE.md.
# PreToolUse hook on Bash. Exit 2 blocks the call; stderr goes back to Claude.

set -uo pipefail

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // ""')
[ -n "$CWD" ] && cd "$CWD" 2>/dev/null

# Collapse newlines and repeated spaces so patterns match multi-line commands.
CMD=$(printf '%s' "$CMD" | tr '\n' ' ' | tr -s ' ')

BASE_BRANCHES="dev main master"
BRANCH=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo "")

block() { printf '%s\n' "$1" >&2; exit 2; }

on_base() {
  for b in $BASE_BRANCHES; do [ "$BRANCH" = "$b" ] && return 0; done
  return 1
}

# --- Rule 2: no blanket staging -------------------------------------------
if printf '%s' "$CMD" | grep -Eq '(^|[;&|] *)git +add +(\.|-A|--all|\*)( |$)'; then
  block "Blocked (Rule 2): 'git add .' stages everything at once. Stage explicit paths — one logical change per commit."
fi

# --- Rule 3: never stage secrets or disposable notes ----------------------
if printf '%s' "$CMD" | grep -Eq '(^|[;&|] *)git +add '; then
  ARGS=$(printf '%s' "$CMD" | sed -E 's/.*git +add +//; s/[;&|].*//')
  for path in $ARGS; do
    case "$path" in
      -*)                    continue ;;
      *.env.example)         continue ;;
      *.env|*.env.*)         block "Blocked (Rule 3): $path is a secret file. Only .env.example is ever committed." ;;
      *.pem|*.key)           block "Blocked (Rule 3): $path is a private key and never goes in the repo." ;;
      STATUS.md|*/STATUS.md) block "Blocked (Rule 3): STATUS.md is a local working note. Add it to .gitignore instead." ;;
    esac
  done
fi

# --- Rule 4: never integrate into the base, never force push --------------
if printf '%s' "$CMD" | grep -Eq '(^|[;&|] *)git +push'; then
  if printf '%s' "$CMD" | grep -Eq 'git +push +.*(--force|--force-with-lease| -f )'; then
    block "Blocked (Rule 4): force push rewrites history on an open PR and drops review comments. Merge commits only."
  fi
  if printf '%s' "$CMD" | grep -Eq 'git +push +[^ ]+ +(HEAD:)?(dev|main|master)( |$)'; then
    block "Blocked (Rule 4): pushing straight to the base branch. Merging is the user's action — report and stop."
  fi
  if on_base; then
    block "Blocked (Rule 4): you are on '$BRANCH', the base branch. Never push from it."
  fi
fi

if printf '%s' "$CMD" | grep -Eq '(^|[;&|] *)git +merge '; then
  if on_base; then
    block "Blocked (Rule 4): merging into '$BRANCH' integrates the branch into the base. Bring the base into the feature branch instead."
  fi
  if printf '%s' "$CMD" | grep -Eq 'git +(checkout|switch) +(dev|main|master).*git +merge'; then
    block "Blocked (Rule 4): switching to the base to merge a feature branch into it. That is the user's action, never yours."
  fi
fi

exit 0
