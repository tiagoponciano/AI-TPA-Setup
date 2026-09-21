---
name: pr-message
description: Run the pre-merge checks and write the pull request description for the current branch. Use when the user explicitly asks for the PR ("gera o PR", "bora mergear", "ready to merge", "generate the PR message"). Never invoke this automatically after a commit.
---

# PR message

Produce a complete PR description covering the **full branch diff**, not just the
last commit. Two checks run first, in order — a description for a branch that
doesn't merge cleanly or doesn't build describes a state that can't ship.

## Check 1 — Conflicts against the base

```bash
git fetch origin
git merge-tree --write-tree origin/dev HEAD    # or origin/main — the actual base
```

Clean → say so in one line, continue to check 2.

Conflicts → resolve them **inside the feature branch**, so the PR stays open and
becomes mergeable:

```bash
git merge origin/dev
# resolve the conflicting hunks
git add <resolved files>
git commit                # merge commit — an exception to Rule 2, like the incoherent-split case
```

- **Never integrate the branch into the base.** `git switch dev && git merge
  <branch>`, `git push origin HEAD:dev`, and merging the PR are forbidden,
  always, no matter how clean the result looks. Merging is the user's action.
- Bringing `origin/dev` *into* the feature branch is not integration — the base
  is untouched locally and remotely. That is the allowed direction.
- Resolve only the conflicting hunks. A conflict is not an opening to refactor
  the incoming code.
- Never resolve by taking one side wholesale (`--ours` / `--theirs`) without
  reading both. If the correct resolution isn't obvious, `git merge --abort` and
  ask.
- **Report every resolution before moving on**, one line per conflict: what each
  side was doing, what was kept. A merge commit's diff is hidden by default in
  most review tools, so an unreported resolution is one nobody reviewed.
- After resolving, check 2 is **mandatory**. Git flags textual overlap only; a
  rename on the base that breaks a caller on the branch merges clean and fails at
  build.
- **Never rebase an open PR.** It rewrites history, needs a force push, and drops
  review comments. Merge commits only.
- If `merge-tree` isn't available (Git < 2.38), report that instead of falling
  back to a real merge with `--abort` afterwards.

## Check 2 — Does it still build and pass?

Run the project's verification command on the branch as it stands. **When a test
suite exists it is part of that command** — a green build with a red suite is not
a passing check.

| Project type | Verification |
|---|---|
| TypeScript / Node | `npm run build` (or repo equivalent), typecheck if separate, plus `npm test` |
| Python service | import the package, run the entrypoint's `--help`, plus the test suite |
| Data pipeline / ETL | run end-to-end on the sample or fixture dataset, never on production data |
| Notebook analysis | `jupyter nbconvert --execute` from a clean kernel, top to bottom |
| Library / package | build the distributable and run the test suite |

Passes → one line, continue. Fails → report the failing command and the actual
error output, and **do not fix it unless asked**.

Both checks become test plan lines reflecting what was actually observed.

**Pushing is gated.** After resolving and building green, report the state and
stop. `git push` happens only when the user says so.

## The description

The diff already shows which files changed. The description explains **what the
behavior is now**, **why it changed**, and **how it was verified**. Describe the
system, not the filesystem.

Two targets, in order: someone who reads only the Summary must know what changed
and what it affects; someone who reads the whole thing must be able to predict
what the app does without opening the diff.

```markdown
## Summary
<1-3 sentences: what the system does now that it didn't before. Then one bullet
per behavioral change — not per file.>

* <behavioral change, one line>

## Why
<conditional — the state before this PR and what was broken, missing or awkward.
Omit when the Summary makes it obvious.>

## Behavior
<One subsection per surface or flow touched. Decision logic as a numbered
resolution list matching the code exactly, including the fallback. State what is
NOT affected. Mechanics go in the feature doc — link, don't inline.>

## Test plan
- [x] <scenario → observed outcome>
- [ ] <not covered → why>
```

Conditional sections, appended in this order when they apply: `## Screenshots`
(UI only, before/after pairs labeled with the state shown); `## Breaking changes`
(what breaks, who's affected, exact migration steps — one section, not two);
`## Notes` (scope boundaries, follow-ups, branch dependencies, rollback).

### Rules

- **Summary bullets describe behavior, not files.** "Redirect to `/projects`
  after a successful worksheet submit", not "modified `worksheet.tsx`".
- **Behavior is the core section.** Non-trivial decision logic appears as an
  explicit ordered fallback chain matching the code exactly — five resolution
  steps in the code means five numbered lines. State what stays unchanged: that's
  what stops a reviewer assuming regressions.
- **Nothing is claimed that isn't in the diff.** Every route, field, flag and
  behavior mentioned must exist in the branch's changes. No performance claim
  without a measurement, no coverage number not produced by a run.
- **Test plan is granular, one line per scenario**, written as `scenario →
  observed outcome`. Not "tested the submit flow" — one line per case actually
  exercised, including negative checks.
- **Check boxes as tests are run**, not upfront. Every `- [x]` corresponds to
  something verified in the conversation.
- **Unchecked boxes are part of the contract.** What wasn't tested stays as
  `- [ ]` with a reason. A PR that hides what wasn't covered is worse than one
  that admits it.
- English, senior-dev tone. Code identifiers in backticks. No emoji, no marketing
  language (`enterprise-grade`, `robust`, `seamless`), no summary of the summary.
- Omit conditional sections that don't apply rather than writing "N/A".
- No AI attribution footer (`Made with Cursor`, Co-authored-by agents, etc.).
- Cross-repo and same-repo GitHub issue/PR references use bare refs so GitHub
  renders the status icon: `owner/repo#123` or `#123`. Never wrap them in
  markdown links (`[text](url)`).

### Length budget

A briefing, not a spec. It scales with behavioral changes, not diff size.

- **Behavior describes observable outcomes.** Cell addresses, row capacities,
  internal formula strategies, class names and file layout belong in the feature
  document. If a reviewer can't verify a claim by using the app or calling the
  endpoint, it's implementation — link to the doc instead.
- **Say each thing once.** If Why and Summary explain the same decision, Summary
  keeps the one-liner and Why keeps the rationale.
- **Test plan lines don't re-explain Behavior.**
- Dependency pins and build tooling belong in the commit body, not Notes — unless
  they change how someone runs the project.
- Past ~80 lines, the excess is almost always implementation detail. Move it to
  the feature doc, link to it.
