# AI-TPA-Setup

This repository organizes every rule TPA uses in development and work:
working agreement, path-scoped rules, skills, git guardrails, and the
attribution policy — all in one place.

**Read this if you're wondering "why doesn't Claude/Cursor/Codex follow this
yet?"** The files in this repo do nothing by themselves. `CLAUDE.md` sitting
in this folder is just a text file — Claude Code doesn't read this folder at
all unless you tell it to, and it only checks two places: the project you're
currently working in, and `~/.claude/` (a fixed folder in your home directory
that applies to *every* project). Same idea for Cursor and Codex, with their
own fixed locations. **"Installing" this repo means putting a link to it in
those fixed locations, so those tools start reading it.** Nothing here reads
your mind — it activates the moment you finish the steps below, and only then.

## Quick start: making Claude Code actually follow these rules

Do this once, on each computer where you use Claude Code.

**1. Put this repo somewhere permanent.** Not a temp folder — if you delete or
move it later, everything below breaks (the links point at this exact path).

```bash
git clone git@github.com:tiagoponciano/AI-TPA-Setup.git ~/dev/AI-TPA-Setup
```

**2. Create the links.** `ln -sfn` makes a *symlink* — think of it as a
shortcut: `~/.claude/CLAUDE.md` and this repo's `CLAUDE.md` become the same
file living at two addresses. Edit either one and both "change" at once,
because there's really only one file. This is what makes Claude Code, which
only ever looks inside `~/.claude/`, start reading rules that physically live
in this git repo instead.

```bash
mkdir -p ~/.claude

ln -sfn ~/dev/AI-TPA-Setup/CLAUDE.md ~/.claude/CLAUDE.md
ln -sfn ~/dev/AI-TPA-Setup/rules     ~/.claude/rules
ln -sfn ~/dev/AI-TPA-Setup/skills    ~/.claude/skills
ln -sfn ~/dev/AI-TPA-Setup/hooks     ~/.claude/hooks
chmod +x ~/dev/AI-TPA-Setup/hooks/git-guardrails.sh ~/dev/AI-TPA-Setup/hooks/commit-msg
```

**3. Turn on the commit hook globally.** A symlink alone isn't enough for
`hooks/commit-msg` — git doesn't scan `~/.claude/hooks/` on its own. This line
tells git, on this computer, "before finishing *any* commit in *any*
repository, run whatever's in this folder first":

```bash
git config --global core.hooksPath ~/.claude/hooks
```

**4. Merge, don't overwrite, `settings.json`.** This one is deliberately
*not* a symlink — Claude Code writes to your real `~/.claude/settings.json`
while you use it (for its own auto-memory toggle, for instance), so linking it
here would let Claude Code's writes silently edit this git repo. Open
`~/.claude/settings.json` (create it if it doesn't exist) and copy in the
`hooks` and `attribution` blocks from this repo's `settings.json` by hand,
next to whatever is already there.

**5. Restart Claude Code** (or open a new terminal tab) so it re-reads
`~/.claude/`. Steps 2-4 only take effect in sessions that start after them.

That's the whole install. Steps 1-2 you do once; if you ever edit the rules,
edit the files in `~/dev/AI-TPA-Setup` (the real location) — the symlinks pick
it up automatically, everywhere, immediately.

## Verify it actually took

```
/context     # confirms CLAUDE.md loaded, under "Memory files"
/hooks       # confirms git-guardrails is registered under PreToolUse
/memory      # lists and opens the instruction files
```

```bash
git config --get core.hooksPath          # expect: /Users/<you>/.claude/hooks
echo '{"tool_input":{"command":"git add ."},"cwd":"'"$PWD"'"}' | ~/.claude/hooks/git-guardrails.sh
echo $?    # expect 2 — the guardrail blocked it
```

If any of these come back empty or wrong, go back to the matching step above —
nothing here half-works; it's either linked or it isn't.

## Layout

```
AI-TPA-Setup/
├── CLAUDE.md                     → ~/.claude/CLAUDE.md        (every session, every project)
├── rules/
│   ├── tests.md                  → ~/.claude/rules/           (auto-loaded when touching test files)
│   └── data-work.md                                           (notebooks, SQL, pipelines)
├── skills/
│   ├── pr-message/SKILL.md       → ~/.claude/skills/          (loaded on demand, e.g. "gera o PR")
│   ├── session-checkpoint/SKILL.md
│   ├── feature-doc/SKILL.md
│   └── project-readme/SKILL.md
├── hooks/
│   ├── git-guardrails.sh         → ~/.claude/hooks/           (blocks risky git commands)
│   └── commit-msg                → strips AI attribution from every commit
├── settings.json                 → merge (never symlink) into ~/.claude/settings.json
├── scripts/
│   └── generate-configs.sh       → generates the two entries below, for Cursor and Codex
├── AGENTS.md                     → read automatically by Codex CLI, but only inside THIS repo
└── .cursor/rules/                → read automatically by Cursor, but only inside THIS repo
    ├── working-agreement.mdc
    ├── tests.mdc
    └── data-work.mdc
```

## What enforces what

| Layer | Mechanism | Guarantee |
|---|---|---|
| Conventions and judgment | `CLAUDE.md`, rules, skills | Guidance — Claude reads and follows, without hard compliance |
| Destructive git actions | `hooks/git-guardrails.sh` | Deterministic — runs before every matching Bash call, once installed |
| AI attribution in commits | `hooks/commit-msg` + `settings.json` | Deterministic — see [Attribution](#attribution), once installed |

Hooks fire before any permission-mode check, so they hold even under
`--dangerously-skip-permissions`. They can only tighten restrictions, never
loosen them — and none of this fires until the Quick Start above is done.

## What the git-guardrails hook blocks

- `git add .`, `git add -A`, `git add --all`, `git add *`
- staging any `.env` variant except `.env.example`, any `*.pem` or `*.key`, and `STATUS.md`
- `git push --force` and `--force-with-lease`
- `git push <remote> dev|main|master` and `HEAD:dev|main|master`
- any `git push` while the current branch is `dev`, `main` or `master`
- `git merge` while on a base branch, and `git checkout dev && git merge <branch>`

Everything else passes through untouched.

## Attribution

**This only affects commits made after you finish step 3 of the Quick Start.**
It cannot reach into git history: any commit made before `core.hooksPath` was
set — on any repo, on any computer — keeps whatever it already says, forever.
GitHub reads that text directly to decide who to list as a co-author, so a
past commit that already says `Co-Authored-By: Claude` will keep showing
Claude as a contributor even after you install this. The only way to remove it
from an already-pushed commit is rewriting that commit's history and
force-pushing over it, which this repo's own `git-guardrails.sh` blocks on
`dev`/`main`/`master` on purpose — going forward clean is the realistic goal,
not scrubbing the past.

Three layers stop it going forward, because the `settings.json` setting alone
is unreliable:

1. `CLAUDE.md` Rule 2 — the written policy: no AI credit in commits or PRs, ever.
2. `settings.json` `attribution: { commit: "", pr: "", sessionUrl: false }` —
   tells Claude Code itself not to generate the trailer or the session link.
3. `hooks/commit-msg` — the actual backstop. It runs on *every* commit in
   *every* repo once step 3 is done, and deletes any `Co-Authored-By: Claude`,
   `Co-authored-by: Cursor`, `Generated with ...`, or `Claude-Session:` line it
   finds, however the commit message was written. Human co-author trailers are
   left alone.

Layer 3 exists because 1 and 2 aren't guaranteed: the `attribution` setting is
reported as not covering messages the model builds by hand through a shell
command, and it doesn't touch `Claude-Session:` at all — the hook catches both.

**Caveat:** `core.hooksPath` is global to your machine, so a repository that
sets its *own* `core.hooksPath` locally — husky does this — overrides yours,
and `commit-msg` won't run there. In those repos, call this script from the
project's own hook instead.

## Adapting for Cursor and Codex

Claude Code has one global folder (`~/.claude/`) that every project shares —
that's what the symlinks above plug into. **Cursor and Codex don't have that.**
Each reads its config from *inside the project it's currently open in*
(`AGENTS.md`, `.cursor/rules/`), not from one shared folder. That means the
`AGENTS.md` and `.cursor/rules/*.mdc` files in this repo only affect Cursor or
Codex sessions opened on *this* repo — to get the same rules in another
project, generate a copy of them there too (see below), or check that tool's
own global/user-level settings if it offers one.

Neither has Claude Code's skill-loading or hook mechanism either, so
`skills/*/SKILL.md` and `hooks/*.sh` aren't usable there as-is.
`scripts/generate-configs.sh` derives two self-contained, adapted configs from
the same source (`CLAUDE.md`, `skills/`, `rules/`):

- **`AGENTS.md`** — read automatically by Codex CLI at the project root. Skill
  content is inlined as an appendix (there's no on-demand loading), and
  `rules/tests.md` / `rules/data-work.md` become flat sections (there's no
  glob-scoped loading).
- **`.cursor/rules/*.mdc`** — read automatically by Cursor. `working-agreement.mdc`
  is `alwaysApply: true` with the same inlined skill appendix; `tests.mdc` and
  `data-work.mdc` stay separate, glob-scoped files — Cursor supports
  path-scoped rules natively, converted from each source file's `paths:`
  frontmatter.

Neither adapted file ports `hooks/git-guardrails.sh` or `hooks/commit-msg`:
their checks only restate rules already present as prose in both files, and
neither tool runs Bash hooks the way Claude Code does — so those rules are
guidance there, not enforced.

**`CLAUDE.md`, `skills/` and `rules/` are the source of truth.** Edit those,
never `AGENTS.md` or `.cursor/rules/*.mdc` directly (each starts with a
`GENERATED FILE` marker as a reminder), then regenerate and commit the result:

```bash
./scripts/generate-configs.sh
```
