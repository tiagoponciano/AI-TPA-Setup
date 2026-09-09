---
name: session-checkpoint
description: Write or update STATUS.md so work can be resumed cheaply after a session ends. Use when a plan step completes, when ~6 commits have landed since the last checkpoint, before a destructive operation, when work is about to pause, when a blocker appears, or when the user says "checkpoint", "pausa" or "salva aí".
---

# Session checkpoint

AI sessions have a usage limit and can cut off without warning. A checkpoint is
cheap; losing an afternoon isn't.

## What to do, in order

1. **Commit any uncommitted work**, following Rule 2 — one logical change per
   commit. If unrelated changes are dirty at the same time, commit each
   separately, in a sensible order. Never leave uncommitted work on the table
   when a session might end.

2. **Write or overwrite `STATUS.md`** at the project root, using the template
   below.

3. **Notify, don't repeat.** If the user is away, send a short status line
   (done / in-progress + one line). No second notification if nothing changed.

## Template

```markdown
# Status — <feature/branch name>

**Last updated:** <date/time>
**Branch:** <branch name>

## Where it stopped
<one paragraph, plain language, what was just finished>

## What's left
- [ ] <next step>
- [ ] <next step>

## Resume command
<exact command or exact prompt to run next — copy-pasteable, no placeholders>

## Blockers
<anything waiting on the user, or "None">
```

## Size budget

`STATUS.md` exists to make the *resume* cheap. Reading it must be cheaper than
re-reading the conversation or re-scanning the repo.

- **40 lines maximum.** If it doesn't fit, "What's left" is too granular —
  collapse it.
- **Overwrite, never append.** No history, no changelog of past checkpoints, no
  "previously completed". Only the current state matters; the git log holds the
  history.
- No code blocks except the resume command.
- No restating what's already in commit messages.

## Hard constraints

- **`STATUS.md` is never committed.** It's a local, disposable note. Add it to
  `.gitignore` the first time it's created (`echo "STATUS.md" >> .gitignore`, as
  its own commit). It should never appear in a diff, a commit, or a PR.
- **Never fabricate progress.** Every line reflects what was actually done and
  verified.
- **Never auto-resume a fix-and-validate loop.** A checkpoint is a save point,
  not a green light to keep iterating unsupervised. Only continue work the user
  explicitly asked to continue.
- **On resume, read `STATUS.md` first**, before touching any code.
