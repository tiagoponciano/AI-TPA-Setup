---
name: notion-task
description: Link a repository to its Notion project and run its task cards end to end. Use whenever the user mentions Notion in the context of this repository — linking or saving which Notion page or project the repo belongs to, asking which card or task to work on, starting work on a card, reading the sprint or meeting minutes, or updating, moving or closing a card — and from the pr-message skill once the PR exists. Requires the Notion MCP server.
---

# Notion task

Most work starts as a card on a sprint board in Notion. This skill ties the card
to the branch: it finds the user's card, reads it and the project's meeting
minutes before any code, keeps a checklist on the card while the work happens,
and closes the card with the PR links once the PR is open.

Two phases. **Start** runs when the user picks up a task. **Close** runs after
the PR exists — the `pr-message` skill hands off here.

If the Notion MCP tools aren't available, say so and stop. Never guess card
content.

## Which Notion project is this repo?

The repo doesn't know. The map lives next to this file, in
`notion-projects.md` (local only, gitignored — it names clients and internal
pages). Format in `notion-projects.example.md`.

1. Read the repo's remote: `git remote get-url origin` → `owner/repo`.
2. Look it up in `notion-projects.md`. Found → use that project page, side and
   minutes database.
3. Not found → search the project database under `default_root` for a project
   whose name matches the repo. Show the user the candidates and ask which one.
   Not under the default root (a project outside NEO) → ask for the page link.
4. Once confirmed, add the row to `notion-projects.md` so the question never
   comes back for this repo. Fill in the minutes database once Phase 1 finds
   it (step 3), so later runs go straight to it. Ask whether this repo is
   `BE`, `FE` or something else if it isn't obvious from the code.

When the user only asked to link or save the Notion page for this repo, stop
here: confirm the row that was written and don't start Phase 1. A link the user
pastes is the project page — use it directly instead of searching. Never save
the link anywhere else (project memory, `STATUS.md`, the repo).

## Phase 1 — Start

1. **Find the card.** The user is whoever owns the connected Notion account —
   read it from the Notion MCP, never from a hardcoded name. In the project's
   current sprint, take the cards where that user is `Responsável` and that
   aren't done.
   - **User named a task** → match it among those cards.
   - **User didn't name one** → pick it yourself: `In progress` before
     `Not started` (unfinished work first), then by `Prioridade` and `Prazo`
     when they're filled. Skip cards marked `[Backlog]` unless nothing else is
     left.
   - Show the pick in one line with the other open cards below it, and wait
     for the user's OK before going on. More than one equally good candidate →
     list them and ask. Never start on a card silently.
   - No open cards for the user in the sprint → say so and stop.
2. **Read the card** — title, properties, body, comments.
3. **Read the meeting minutes.** Every project page has a database of minutes
   below the board, one page per meeting with a date property. Names change
   from project to project (the database, the meetings — "Follow-up", "Weekly",
   "Daily"…), so find it by shape, not by name: a database on the project page
   whose rows are dated meeting pages. Go newest first and read the meetings
   held during the card's sprint (no dates on the sprint → the last two weeks
   of meetings). In each one, the decisions and next-steps sections carry the
   most weight — that's where scope and owners are set. Pull only what concerns
   this card: what was agreed, scope limits, who depends on it. Nothing about
   the card → say so; don't stretch an unrelated note into a requirement. No
   minutes database on the project page → ask where the minutes are.
4. **Report back in chat**, short: what the card asks, what the minutes add,
   and anything that contradicts between the two. A contradiction is a
   question for the user, not a call to make.
5. **Propose the checklist** in chat, two groups:
   - **To do** — the implementation steps, as verifiable outcomes, not files.
   - **To test** — one line per scenario, written as `scenario → expected
     outcome`. These become the PR test plan later, so write them that way now.
6. **On the user's OK**, write the checklist to the card and move it to the
   in-progress status. One confirmation covers both.

### Writing to the card

Append a `## Plan` section at the end of the card body with two to-do lists:

```markdown
## Plan

**To do**
- [ ] <step>

**To test**
- [ ] <scenario → expected outcome>
```

- Append only. Never rewrite or delete what's already on the card — other
  people write there too.
- Use the status names the board actually has (read the database schema; on the
  NEO boards it's usually `Not started` / `In progress` / `Done`). Never invent
  a status.
- The only property this skill changes is `Status`. Not `Prazo`, `Prioridade`,
  `Responsável` or anything else.
- Card language follows the card. If the card is in Portuguese, the checklist is
  in Portuguese. Rule 0 covers the repo, not the board.

## During the work

Tick checklist items on the card as they're actually done or tested — same rule
as the PR: a box is checked only after it was run and the output read. Scope
that grows past the card goes to the user first, not silently into the list.

## Phase 2 — Close

Runs after the `pr-message` skill, once the PR exists on GitHub (the user opened
it, or said to open it). No PR URL → nothing to close.

1. **Test plan comes from the card.** Every `To test` line becomes a PR test
   plan line. Checked on the PR only if it was exercised in this work. The rest
   stay `- [ ]` with a reason. The card and the PR must agree.
2. **Add the PR link to the card** under the heading for this repo's side
   (`BE:`, `FE:`…). Heading exists → add below it. Missing → create it above
   `## Plan`. Paste the bare PR URL on its own line so Notion renders the GitHub
   preview.
3. **Tick the card's checklist** to match the PR test plan.
4. **Move the card to the done status.**
5. One line in chat: card moved, links added.

A task that spans BE and FE is closed by the second PR. After the first one,
add its link and leave the status alone. Ask which case it is when unsure.

## Never

- Touch a card the user isn't `Responsável` for.
- Move a card to done without a PR link on it.
- Check a box for something that wasn't run.
- Write sprint minutes, card content or Notion links into the repository.
