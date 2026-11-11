# PR size check

How `hooks/pr-size-check.sh` measures a branch and applies Rule 8 of `CLAUDE.md`.
For anyone changing the hook or working out why it blocked a command.

## What this is

A `PreToolUse` hook on Bash, registered in `settings.json` for Claude Code and in
`codex-hooks.json` for Codex. It blocks `git push` and `gh pr create` when the
current branch changes more than 500 lines of code against its base. The number
is a guide, so the stop happens once per commit: exit code 2 holds the command
back, stderr tells the agent to check whether the PR bundles separate deliverables,
and the same command goes through on retry.

- The guide is inclusive: 500 lines passes without a stop, 501 stops once.
- It measures the commits on the branch, not uncommitted work.
- It runs in agents only. A `git push` typed in a terminal never reaches it.

## Surface

| Invocation | Input | Result |
|---|---|---|
| `pr-size-check.sh` | Hook JSON on stdin: `.tool_input.command`, `.cwd` | Exit `0` allows, exit `2` stops this command once for this commit |
| `pr-size-check.sh count <ref>` | A git ref, normally `origin/<base>` | Prints the line count. Exit `1` on an unknown ref |

`count` does not fetch, so run `git fetch origin` first for a current result.

## Rules and behavior

### What counts

The count is additions plus deletions in `git diff --numstat <base>...HEAD`, so
lines the base gained after the branch left it, or that arrived by merging the
base in, are not counted.

| Change | Counted |
|---|---|
| Source, config | Yes |
| Tests: `*.test.*`, `*.spec.*`, `test_*.py`, `*_test.go`/`.py`/`.sh`, files under `test/`, `tests/`, `__tests__/`, `spec/`, `specs/` | No |
| Docs: `*.md`, `*.mdx`, files under `doc/`, `docs/` | No |
| A modified line | Twice: one deletion, one addition |
| Pure rename | No |
| Rename with edits | Only the edited lines |
| Binary file | No |
| `pnpm-lock.yaml`, `package-lock.json`, `yarn.lock`, `poetry.lock`, `uv.lock`, `Gemfile.lock`, `Cargo.lock`, in any directory | No |
| `*.snap` | No |
| Path with `linguist-generated` or `linguist-generated=true` in `.gitattributes` | No |
| Path with `linguist-generated=false` | Yes |

### Which base it measures against

The first match wins:

1. `--base` or `-B` on the `gh pr create` command
2. The base of the open PR for this branch, from `gh pr view`
3. `origin/dev`, when it exists
4. `origin/main`

### When it lets the command through without measuring

- The command is not a `git push` or `gh pr create` at the start of a command or
  after `;`, `&`, `|`.
- The command is `git push` with `--delete` or `-d`.
- The working directory is not a git repository, or HEAD is detached.
- The current branch is `dev`, `main` or `master`. `git-guardrails.sh` owns that case.
- `git fetch origin` fails.
- The resolved base has no `origin/<base>` ref.

### The stop-once warning

The first time a commit goes over the guide, the hook writes its SHA to
`<git-dir>/pr-size-seen` and exits `2`. The same `git push` or `gh pr create`
at the same HEAD then passes, whichever of the two comes first. A new commit
changes HEAD and warns again.

The warning asks the agent to decide between two outcomes: the PR bundles
separate deliverables and gets split by what each delivers, or it is one change
that cannot ship smaller and the reason goes in the PR's `## Notes`. No approval
from the user is needed to continue.

## What this does NOT do

- **It does not check for one deliverable.** That half of Rule 8 needs judgment, so
  it lives in Check 0 of the `pr-message` skill.
- **It does not stop a branch that is under the guide.** A small PR can still bundle
  separate deliverables; only the skill and the reviewer catch that.
- **It does not run in Cursor**, which has no hook support in this setup, nor on
  GitHub. A repo that needs a server-side guarantee needs its own CI check.
- **It does not cover merging or editing a PR.** Only the two commands above.

## Gotchas

- **A branch that deletes a file and adds a similar one measures small** → git
  detects a rename when files are at least 50% similar, and counts only the
  difference → expected. Moved code needs less review than new code.
- **A regenerated file stops the push** → the repo has not marked it as generated
  → add it to `.gitattributes` with `linguist-generated`. This repo does so for
  the output of `scripts/generate-configs.sh`.
- **The hook never fires on this machine, though it is in the repo** → the hook
  has no symlink in `~/.claude/hooks`, or `~/.claude/settings.json` lacks its
  entries → redo install steps 2 and 4 of the README.

## Setup

Requires `jq` and `git`. `gh` is optional: without it, base resolution skips step 2.

Run the tests with `hooks/pr-size-check.test.sh`. They use local throwaway repos
and a stubbed `gh`, so they need no network or GitHub auth.
