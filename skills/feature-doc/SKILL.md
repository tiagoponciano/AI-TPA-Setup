---
name: feature-doc
description: Write or update the documentation file for a feature, in the same branch as the implementation. Use whenever code changes behavior and the feature's docs/<feature-name>.md needs to reflect it, or when starting documentation for a new feature.
---

# Feature documentation

The PR explains a change to someone reviewing it today. This explains the system
to someone reading it in six months — including an agent picking up the codebase
cold. Different artifacts, different lifespans, and the second is what keeps
implementation detail out of the first.

This is not a planning artifact. **Documentation describes how the code works; a
plan describes how the work was organized.** The first is committed, the second
never is.

## One document per feature

Named after the feature, kebab-case, not after the module or the file layout —
so finding it means guessing the feature name, not walking the directory tree.
No dates, no ticket numbers, no `v2`, no `-refactor` suffix.

```
server/src/modules/business-case/docs/business-case-export.md
server/src/modules/project/docs/project-access-scoping.md
docs/architecture/<topic>.md                          # cross-module concerns only
```

Never a single growing `docs/notes.md`, never a catch-all module document.

**A new document is justified by a new feature, not by a new commit.** A new
fallback branch, a new validation, a new endpoint on an existing surface all edit
the document that already covers it. Only genuinely new capability gets a new
file. If a change spans two features, both documents are updated — each in its
own commit.

## Structure

Four sections are mandatory. `Surface` and `Data shapes` are **conditional**:
write them only when there is no generated contract to point at. When the module
publishes OpenAPI, a `.proto`, a generated client or exported types, link to it
and document only what the generated artifact can't express — auth, who can call
what, units and scales, nullability the type says nothing about. Duplicating a
generated contract by hand is the fastest way to end up confidently wrong.

```markdown
# <Feature name>

<One or two lines: what this covers and who it's for. State plainly that it
describes how the feature works now — not how it was built.>

## What this is                                          [mandatory]
<2-4 sentences: what it does and where it sits in the system. Then the
invariants — the two or three facts that govern everything else.>

## Surface                                               [conditional]
<Only when no generated contract exists. Base path, auth mechanism, table of
every route with method, path, who can call it, what it returns. For a library:
every exported function with its signature and contract.>

## Data shapes                                           [conditional]
<Only when no generated types exist. Exact payloads as annotated code blocks
with real values. Mark optional, server-derived, nullable fields. Regardless of
generation, always state the scale and unit of every number.>

## Rules and behavior                                    [mandatory]
<Validation rules, resolution orders and fallback chains, state transitions,
formulas exactly as the code computes them, including rounding mode and edge
cases. Enumerate case-by-case outcomes in a table.>

## What this does NOT do                                 [mandatory]
<What a reader will assume and be wrong about. Fields that look calculated but
aren't. Values that look like they'd update and don't. Endpoints that exist for
a sibling feature but not this one.>

## Gotchas                                               [mandatory]
<Each one as: symptom → cause → fix. Written from the mistakes actually made
while building the feature. If it's empty, either the feature was trivial or the
mistakes weren't recorded.>

## Setup                                                 [conditional]
<Env vars, external files, seeds, anything needed to run this locally.>
```

## Depth standard

The bar: **a competent developer who has never seen this code can implement
against the feature, correctly, without reading the source and without asking
questions.**

- **Exhaustive over representative, exact over approximate.** Every enum value,
  not "the main ones" — a partial list is worse than none, because the reader
  trusts it. Not "rounds the result" but which rounding, with the boundary case.
- **Name the failure, not just the rule.** "Send only editable fields" is a rule.
  "Re-sending the object you got from GET returns 400, because
  `forbidNonWhitelisted` is on" is what saves someone an hour.
- **Document deliberate inconsistencies as deliberate, and state the differences
  from the sibling feature.** When two parts look symmetric but aren't, that
  asymmetry is the most valuable thing in the document — and it's what stops
  someone "fixing" an intentional 403.

Length follows the feature. Density is the constraint, not word count.

## Keeping it current

The document describes the present and carries no trace of the change that
produced it. None of these belong in it, ever:

- "NEW", "changed", "recently added", "previously the behavior was X"
- Migration notes, "what changed for the frontend"
- Dates, sprint names, ticket numbers, version markers
- Titles framed as an event ("What changed in the API") instead of a subject

A reader six months from now must not be able to tell which parts were added
when. That's what git history is for.

## Rules

- **Update, never append.** When behavior changes, the sentence describing the
  old behavior is rewritten, not supplemented.
- **Same branch, same PR.** Documentation is not a follow-up. A PR that ships an
  implementation without touching the feature document is incomplete.
- **Its own commit**: `docs(<feature>.md): <what changed>`. This wins over Rule
  2's revert test, deliberately: reverting the code commit alone leaves a
  document describing behavior that no longer exists, and that is accepted. A
  stale sentence is a cheap failure; a commit mixing implementation and prose is
  a permanent one — and in practice the revert unit is the PR's merge commit,
  which carries both.
- **The PR links here instead of repeating this.** When a Behavior subsection
  starts explaining mechanics, cut them into this document and leave a link.
- **No fabrication.** Every statement must be true of the code as committed.
  Never document intended behavior that wasn't implemented.
- **Stale is worse than absent**, because it's trusted. If a change makes an
  existing statement wrong, fixing that statement is part of the change, not
  optional cleanup.
- Written in English (Rule 0). No preamble, no "in this document we will
  explore".
