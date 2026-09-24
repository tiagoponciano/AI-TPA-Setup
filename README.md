# AI-TPA-Setup

TPA's development conventions — working agreement, path-scoped rules, skills,
git guardrails, and the attribution policy — kept in one repo and linked into
Claude Code, Cursor and Codex.

## What it does

The files here do nothing by themselves. `CLAUDE.md` sitting in this folder is
just a text file — Claude Code doesn't read this folder at all unless told to,
and it only checks two places: the project currently open, and `~/.claude/` (a
fixed folder in the home directory that applies to every project). Same idea
for Cursor and Codex, each with its own fixed location. "Installing" this repo
means putting a link to it in those fixed locations, so those tools start
reading it. Nothing here reads your mind — it activates the moment the steps
below finish, and only then.

## Running it locally

Do this once, on each computer where Claude Code or Codex is used.

**1. Put this repo somewhere permanent.** Not a temp folder — if it's deleted
or moved later, everything below breaks (the links point at this exact path).

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
*not* a symlink — Claude Code writes to the real `~/.claude/settings.json`
during use (for its own auto-memory toggle, for instance), so linking it here
would let Claude Code's writes silently edit this git repo. Open
`~/.claude/settings.json` (create it if it doesn't exist) and copy in the
`hooks` and `attribution` blocks from this repo's `settings.json` by hand,
next to whatever is already there.

**5. Restart Claude Code** (or open a new terminal tab) so it re-reads
`~/.claude/`. Steps 2-4 only take effect in sessions that start after them.

**6. Codex (optional, same machine).** Codex reads `~/.codex/AGENTS.md` for
global guidance, discovers skills from `~/.agents/skills`, and can run lifecycle
hooks from `~/.codex/hooks.json`:

```bash
mkdir -p ~/.codex
ln -sfn ~/dev/AI-TPA-Setup/AGENTS.md ~/.codex/AGENTS.md

mkdir -p ~/.agents
ln -sfn ~/dev/AI-TPA-Setup/.agents/skills ~/.agents/skills
```

In `~/.codex/config.toml` (create if missing), enable hooks:

```toml
[features]
hooks = true
```

Then merge `hooks/codex-hooks.json` into `~/.codex/hooks.json`. If this is the
only Codex hook on the machine, a symlink is enough:

```bash
ln -sfn ~/dev/AI-TPA-Setup/hooks/codex-hooks.json ~/.codex/hooks.json
```

If `~/.codex/hooks.json` already exists, keep the existing hooks and add the
`PreToolUse` entry from `hooks/codex-hooks.json` under its top-level `hooks`
object. Restart Codex, run `/hooks`, and trust the new hook definition.

**7. Cursor attribution (optional).** Rules live under `.cursor/rules/` when
this repo (or a generated copy) is open. Also turn product injection off:

- Cursor Settings → Git & PRs → Attribution → off for commits and PRs
- `~/.cursor/cli-config.json`: `attributeCommitsToAgent` / `attributePRsToAgent`
  → `false`

That's the whole install. Steps 1-2 happen once; to edit the rules afterward,
edit the files in `~/dev/AI-TPA-Setup` (the real location) — the symlinks pick
it up automatically, everywhere, immediately.

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
├── .agents/skills/              → ~/.agents/skills/ (Codex, loaded on demand)
│   ├── tests/SKILL.md
│   └── data-work/SKILL.md
├── hooks/
│   ├── git-guardrails.sh         → ~/.claude/hooks/           (blocks risky git commands)
│   ├── commit-msg                → strips AI attribution from every commit
│   └── codex-hooks.json          → ~/.codex/hooks.json        (Codex PreToolUse wrapper)
├── settings.json                 → merge (never symlink) into ~/.claude/settings.json
├── scripts/
│   └── generate-configs.sh       → generates the two entries below, for Cursor and Codex
├── AGENTS.md                     → ~/.codex/AGENTS.md         (Codex global + this repo)
└── .cursor/rules/                → ~/.cursor/rules/           (Cursor global via symlink)
    ├── working-agreement.mdc
    ├── tests.mdc
    └── data-work.mdc
```

## Common tasks

| Command | Checks |
|---|---|
| `/context` | `CLAUDE.md` loaded, under "Memory files" |
| `/hooks` | `git-guardrails` registered under PreToolUse |
| `/memory` | lists and opens the instruction files |
| `git config --get core.hooksPath` | expect `/Users/<you>/.claude/hooks` |
| `/hooks` in Codex | `git-guardrails` registered and trusted under PreToolUse |
| `echo '{"tool_input":{"command":"git add ."},"cwd":"'"$PWD"'"}' \| ~/.claude/hooks/git-guardrails.sh; echo $?` | expect `2` — the guardrail blocked it |
| `./scripts/generate-configs.sh` | regenerates `AGENTS.md` and `.cursor/rules/*.mdc` after editing `CLAUDE.md`, `skills/` or `rules/` |

If any of the checks above come back empty or wrong, go back to the matching
install step — nothing here half-works; it's either linked or it isn't.

## What enforces what

| Layer | Mechanism | Guarantee |
|---|---|---|
| Conventions and judgment | `CLAUDE.md`, rules, skills | Guidance — Claude reads and follows, without hard compliance |
| Destructive git actions in Claude Code | `settings.json` PreToolUse + `hooks/git-guardrails.sh` | Deterministic — runs before every matching Bash call, once installed |
| Destructive git actions in Codex | `~/.codex/hooks.json` PreToolUse + `hooks/git-guardrails.sh` | Deterministic after `/hooks` trusts the hook definition |
| AI attribution in commits | `hooks/commit-msg` + `settings.json` | Deterministic — see [Attribution](#attribution), once installed |

Hooks fire before any permission-mode check, so they hold even under
`--dangerously-skip-permissions`. They can only tighten restrictions, never
loosen them — and none of this fires until the install steps above are done.

### What the git-guardrails hook blocks

- `git add .`, `git add -A`, `git add --all`, `git add *`
- staging any `.env` variant except `.env.example`, any `*.pem` or `*.key`, and `STATUS.md`
- `git push --force` and `--force-with-lease`
- `git push <remote> dev|main|master` and `HEAD:dev|main|master`
- any `git push` while the current branch is `dev`, `main` or `master`
- `git merge` while on a base branch, and `git checkout dev && git merge <branch>`

Everything else passes through untouched.

## Attribution

**This only affects commits made after step 3 of the install is done.** It
cannot reach into git history: any commit made before `core.hooksPath` was
set — on any repo, on any computer — keeps whatever it already says, forever.
GitHub reads that text directly to decide who to list as a co-author, so a
past commit that already says `Co-Authored-By: Claude` will keep showing
Claude as a contributor even after installing this. The only way to remove it
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

**Cursor / Codex product injection** is separate from Claude Code:

| Tool | Disable attribution |
|---|---|
| Cursor IDE | Settings → Git & PRs → Attribution off |
| Cursor CLI | `~/.cursor/cli-config.json` → `attributeCommitsToAgent` / `attributePRsToAgent` false |
| Codex | Use `hooks/commit-msg` through global `core.hooksPath`; older `commit_attribution = ""` settings may be ignored by current Codex versions |

`hooks/commit-msg` still strips AI trailers (including `Made with Cursor`) on
every commit when `core.hooksPath` points at `~/.claude/hooks`.

In PR bodies, use bare GitHub refs (`owner/repo#123`) so status icons render —
never markdown links. See the `pr-message` skill / `AGENTS.md` appendix.

**Caveat:** `core.hooksPath` is global to the machine, so a repository that
sets its *own* `core.hooksPath` locally — husky does this — overrides it, and
`commit-msg` won't run there. In those repos, call this script from the
project's own hook instead.

## Adapting for Cursor and Codex

Claude Code has one global folder (`~/.claude/`) that every project shares —
that's what the symlinks above plug into. **Codex** also has a global home
(`~/.codex/`): symlink this repo's generated `AGENTS.md` there (install step
6) so every Codex session gets the working agreement, and add
`hooks/codex-hooks.json` to `~/.codex/hooks.json` so Codex runs the same
`git-guardrails.sh` before Bash commands. **Cursor** reads
`.cursor/rules/` from the open project; symlink or copy the generated
`.cursor/rules/*.mdc` into projects that need them, or open this repo.

Codex supports the same on-demand skill model through `~/.agents/skills`.
`scripts/generate-configs.sh` derives adapted outputs from the same source
(`CLAUDE.md`, `skills/`, `rules/`):

- **`AGENTS.md`** — read by Codex from `~/.codex/AGENTS.md` (global) and from
  a project root when present. It contains only always-on rules, keeping the
  repeated context small.
- **`.agents/skills/`** — contains Codex skill bundles for the path-scoped
  `tests` and `data-work` conventions. Codex sees their metadata and reads the
  full `SKILL.md` only when relevant.
- **`.cursor/rules/*.mdc`** — read automatically by Cursor. `working-agreement.mdc`
  is `alwaysApply: true` with the same inlined skill appendix; `tests.mdc` and
  `data-work.mdc` stay separate, glob-scoped files — Cursor supports
  path-scoped rules natively, converted from each source file's `paths:`
  frontmatter.

The adapted instruction files do not contain hook configuration. Codex gets the
Bash guardrail from `hooks/codex-hooks.json`, and both Claude Code and Codex get
the commit-message backstop from Git's global `core.hooksPath`.

**`CLAUDE.md`, `skills/` and `rules/` are the source of truth.** Edit those,
never `AGENTS.md` or `.cursor/rules/*.mdc` directly (each starts with a
`GENERATED FILE` marker as a reminder), then regenerate and commit the result:

```bash
./scripts/generate-configs.sh
```
