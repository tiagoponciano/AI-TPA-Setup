# Working agreement

Applies to every project on this machine. Procedures and templates live in
`~/.claude/skills/`; rules that only matter for some files live in
`~/.claude/rules/`. A project's own `CLAUDE.md` overrides anything here.

## Karpathy behavioral guidelines

Guidelines to reduce common LLM coding mistakes. They bias toward caution over
speed — for trivial tasks, use judgment.

**Think before coding.** State assumptions explicitly; if uncertain, ask. If
multiple interpretations exist, present them — don't pick silently. If a simpler
approach exists, say so. If something is unclear, stop and name what's confusing.

**Simplicity first.** Minimum code that solves the problem. No features beyond
what was asked, no abstractions for single-use code, no configurability that
wasn't requested, no error handling for impossible scenarios. If you write 200
lines and it could be 50, rewrite it.

**Surgical changes.** Touch only what you must. Don't improve adjacent code,
don't refactor what isn't broken, match existing style even if you'd do it
differently. Remove what *your* change orphaned; leave pre-existing dead code
alone and mention it instead. Every changed line traces directly to the request.

**Goal-driven execution.** Turn tasks into verifiable goals: "fix the bug" →
"write a test that reproduces it, then make it pass". For multi-step work, state
the plan as step → verification, then loop until verified. Strong success
criteria let you loop independently; weak ones ("make it work") force
constant clarification.

These are working if: fewer unnecessary changes in diffs, fewer rewrites from
overcomplication, and clarifying questions arriving before implementation rather
than after mistakes.

---

## Rule 0 — Language

**Everything that lands in the repository is written in English. The conversation
is not.** Talk to the user in whatever language they're using (PT or EN) and
switch when they switch.

English covers code, identifiers, comments, commits, branches, PR descriptions,
tests, logs, internal error messages, TODOs, and every `.md` in the repo.

**The one exception is user-facing content**: i18n files, UI copy, on-screen
validation messages, transactional e-mail. The test is who reads it — *a
developer or an agent reads English; a customer reads the product's language.*
An error string that only appears in a log is English; the same error in a toast
is product language.

- Never mix languages inside an identifier (`getUsuario`, `calcularTVL`).
- Brazilian domain terms with no clean equivalent stay untranslated: `CNPJ`,
  `NF-e`, `Simples Nacional`, `Pix`. Acronyms keep canonical casing: `TVL`, `API`.
- In a file that already uses Portuguese identifiers, match the existing style —
  Surgical Changes wins. Mention the inconsistency, don't rename unilaterally.

---

## Rule 1 — Branch from a synced base

```bash
git checkout dev              # or main — confirm which is the actual base
git pull
git checkout -b @tpa/feat/vendor-creation-endpoint
```

**Naming:** `@tpa/<type>/<short-kebab-case-description>`, where `<type>` is one
of `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `style`, `perf`, `build`,
`ci`, and the description names the plan, not the implementation (3–5 words, no
dates, no ticket-speak).

One type per branch; if a `fix` grows into a `feat`, that's a signal it should
have been two. The branch type doesn't constrain commit types inside it.
`git pull` before `git checkout -b`, every time — branching from an unsynced base
is how work gets silently reverted.

---

## Rule 2 — One logical change per commit

Every commit contains **exactly one logical change**, and **no commit leaves the
tree half-changed**. In practice this usually means one file: if three files are
staged, the default assumption is three separate changes — split them.

The exception is a change that is incoherent when split: a migration and the
entity it maps, a rename and the imports it breaks, a new export and the index
that re-exports it. Those land in one commit, because a commit that references
something it didn't include breaks `git bisect` and can't be reverted on its own.

**The test before staging:** does anything staged here depend on a file that was
left out? If reverting this commit alone would force reverting the next one too,
they were always a single commit.

Never `git add .` or `git add -A`. Stage explicit paths, every time.

**Before every commit:**
- [ ] `git status` shows only the paths this change requires
- [ ] Every staged file traces to the same logical change
- [ ] No staged change depends on a file left out of this commit

The build and test suite are **not** run per commit — that's the PR precondition,
once per branch. This checklist catches the half-change by reading the diff, not
by running anything.

**Message format:** `<type>(<scope>): <summary>`, imperative, ≤72 chars, no
trailing period. Optional body explains *why*, never *what*. Scope is the file
name for single-file commits, the module or feature name when a commit
legitimately spans more.

```
feat(vendor.controller.ts): add POST endpoint for vendor creation
refactor(vendor): rename VendorDto to CreateVendorDto across callers
```

**No attribution, ever.** Commit messages and PR descriptions end at their own
content. Never append `Co-Authored-By: Claude`, `Co-authored-by: Cursor`,
`Generated with Claude Code`, `Claude-Session:`, or any other credit to an AI
tool — not Claude, not Cursor, not Codex, not Copilot, not any agent. Not in a
commit, not in a PR body, not in a merge commit. The author is the person who
asked for the work. This holds regardless of how the message is built: `-m`,
heredoc, or editor. Co-authorship trailers naming actual human collaborators
are fine and stay.

---

## Rule 3 — What never gets committed

The repository holds the code and the context needed to understand and run it:
source, tests, migrations, build config, `README.md`, architecture notes, API
contracts, convention files, and `.env.example` with fake values.

**Never committed:**

- **Secrets, without exception.** Every `.env*` variant except `.env.example`.
  API keys, tokens, `*.pem`, `*.key`, service-account JSON, `credentials.json`,
  dumps with real data.
- **Planning artifacts.** Plans, task breakdowns, checklists, scratchpads,
  session notes, agent transcripts — including `STATUS.md`.
- Local noise: `node_modules/`, `dist/`, `build/`, `.venv/`, `coverage/`,
  `.DS_Store`, IDE folders, `*.log`.

**The test when in doubt:** does a new developer cloning this repo need this file
to understand, run, or modify the code? If it only describes how the work was
organized, it stays out. A repo's own `CLAUDE.md` or `.claude/rules/` are shared
conventions, same category as `CONTRIBUTING.md` — those do get committed.

Enforcement lives in `.gitignore`, not in memory. Before the first commit on any
repo, confirm it covers `.env*` (with `!.env.example`), `*.pem`, `*.key`,
`plans/`, `*.plan.md`, `STATUS.md`, and the local noise above.

**If something forbidden was already committed:** `git rm --cached <path>`, add
it to `.gitignore`, commit both separately. Untracking removes it from future
commits, **not from history** — if a real credential was pushed, rotate it.

---

## Rule 4 — Pull requests

**Generate a PR description only when explicitly asked** ("gera o PR", "bora
mergear", "ready to merge"). Never after a commit, never as a default.

When asked, load the `pr-message` skill and follow it: conflict check, build and
test verification, then the description.

**Always, regardless of the skill:** never merge the PR, never push to the base
branch, never rebase an open branch, and never `git push` without the user
saying so.

---

## Rule 5 — Session checkpoints

Write or update `STATUS.md` when a plan step completes, when ~6 commits have
landed since the last checkpoint, before any destructive operation, when work is
about to pause, when a blocker appears, or when the user says "checkpoint" /
"pausa" / "salva aí". Not on a timer. Load the `session-checkpoint` skill.

On resume, read `STATUS.md` before touching code, and never auto-continue a
fix-and-validate loop the user didn't explicitly ask to continue.

---

## Rule 6 — Documentation

**Every implementation is documented, in the same branch and the same PR, in its
own commit.** The document is named after the feature and lives in a `docs/`
folder inside its module: `server/src/modules/vendor/docs/vendor-creation.md`.
A PR that ships an implementation without touching the corresponding feature
document is incomplete. Load the `feature-doc` skill when writing or updating one.

**Update, never append.** The document describes the code as it is now, not a log
of what happened to it. No changelog, no dates, no "previously the behavior was
X" — when behavior changes, the old sentence is rewritten.

**The root README is different**: it's the front door, not a reference.
Load the `project-readme` skill when starting one from scratch, when how the project is run or set up has changed, or when asked to improve an existing one.

---

## Rule 7 — Tests

**A behavioral change ships with a test that fails without it.** Mandatory for:
bug fixes (write the failing test first, always), new behavior with decision
logic, formulas and derived values, anything with an external contract.

Not required for config changes, dependency bumps, formatting, copy edits, or
pass-throughs with no logic — say so in the PR instead of pretending otherwise.

Detailed conventions load automatically when working with test files
(`~/.claude/rules/tests.md`) or with notebooks, SQL and pipelines
(`~/.claude/rules/data-work.md`).

---

## No fabrication

Applies to the PR test plan, `STATUS.md`, and feature documentation alike:
**never claim something was verified without having run it and read the output.**
Never document behavior that wasn't implemented, never cite a measurement that
wasn't measured, never check a box for something that wasn't exercised. What
wasn't tested stays visible as unchecked, with a reason.

---

## Quick reference

| Trigger | Action |
|---|---|
| Writing anything into the repo | English. Product language only for user-facing copy |
| Starting a feature | `git checkout <base>` → `git pull` → `git checkout -b @tpa/<type>/<desc>` |
| Ready to commit | Stage explicit paths for one logical change → `type(scope): summary` |
| Fixing a bug | Failing test first → fix → same PR |
| About to stage | Never `.env`, plans, or `STATUS.md` |
| Forbidden file tracked | `git rm --cached` → `.gitignore` → rotate if real |
| User asks for the PR | Load `pr-message` skill |
| Plan step done / pause / risky op / "checkpoint" | Load `session-checkpoint` skill |
| Any implementation | Update the feature doc, own commit — load `feature-doc` skill |
| README missing, stale, or asked to improve | Load `project-readme` skill |
| Conflict resolved, build green | Report and stop. Push only on the user's word |
| Resuming a session | Read `STATUS.md` first, before any code |
