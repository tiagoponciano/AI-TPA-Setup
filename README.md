# claude-config

Personal Claude Code configuration: working agreement, path-scoped rules,
skills, and git guardrails. Symlinked into `~/.claude/` so it applies to every
project on the machine.

## Layout

```
claude-config/
├── CLAUDE.md                     → ~/.claude/CLAUDE.md        (every session)
├── rules/
│   ├── tests.md                  → ~/.claude/rules/           (when touching test files)
│   └── data-work.md                                           (notebooks, SQL, pipelines)
├── skills/
│   ├── pr-message/SKILL.md       → ~/.claude/skills/          (on demand)
│   ├── session-checkpoint/SKILL.md
│   └── feature-doc/SKILL.md
├── hooks/
│   └── git-guardrails.sh         → ~/.claude/hooks/           (blocks, doesn't advise)
└── settings.json                 → merge into ~/.claude/settings.json
```

## Install

```bash
git clone git@github.com:<user>/claude-config.git ~/dev/claude-config
cd ~/dev/claude-config
mkdir -p ~/.claude

ln -sfn ~/dev/claude-config/CLAUDE.md ~/.claude/CLAUDE.md
ln -sfn ~/dev/claude-config/rules     ~/.claude/rules
ln -sfn ~/dev/claude-config/skills    ~/.claude/skills
ln -sfn ~/dev/claude-config/hooks     ~/.claude/hooks
chmod +x ~/dev/claude-config/hooks/git-guardrails.sh
```

`settings.json` is **not** symlinked — Claude Code writes to it (the auto-memory
toggle, for one). Merge the `hooks` block into the existing file by hand, or
create it if there isn't one.

`jq` is required by the hook: `brew install jq` on macOS,
`apt-get install jq` on Debian and Ubuntu.

## Verify

```
/context     # confirms CLAUDE.md loaded, under "Memory files"
/hooks       # confirms git-guardrails is registered under PreToolUse
/memory      # lists and opens the instruction files
```

Test the guardrail directly before trusting it:

```bash
echo '{"tool_input":{"command":"git add ."},"cwd":"'"$PWD"'"}' | ~/.claude/hooks/git-guardrails.sh
echo $?    # expect 2
```

## What enforces what

| Layer | Mechanism | Guarantee |
|---|---|---|
| Conventions and judgment | `CLAUDE.md`, rules, skills | Guidance — Claude reads and follows, without hard compliance |
| Destructive git actions | `hooks/git-guardrails.sh` | Deterministic — runs before every matching Bash call |

The hook fires before any permission-mode check, so it holds even under
`--dangerously-skip-permissions`. Hooks can tighten restrictions, never loosen
them.

## What the hook blocks

- `git add .`, `git add -A`, `git add --all`, `git add *`
- staging any `.env` variant except `.env.example`, any `*.pem` or `*.key`, and `STATUS.md`
- `git push --force` and `--force-with-lease`
- `git push <remote> dev|main|master` and `HEAD:dev|main|master`
- any `git push` while the current branch is `dev`, `main` or `master`
- `git merge` while on a base branch, and `git checkout dev && git merge <branch>`

Everything else passes through untouched.
