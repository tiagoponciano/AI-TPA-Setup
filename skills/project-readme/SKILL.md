---
name: project-readme
description: Write or update the README at the root of a project repository. Use when starting a README from scratch, when the way the project is run or set up has changed, or when the user asks to improve an existing one. Not for feature documentation — that's the feature-doc skill.
---

# Project README

The README is the front door, not the reference. It answers three questions for
someone who cloned the repo an hour ago and nothing else:

1. What is this?
2. How do I run it?
3. Where is everything?

Mechanics, contracts and edge cases live in the feature documents inside each
module. The README links to them; it never duplicates them.

**The test for every line:** does a new developer need this to understand, run,
or modify the code? If it's there to impress someone, cut it.

## Structure

Sections marked conditional are omitted entirely when they don't apply — never
an empty heading, never "N/A".

```markdown
# <project-name>

<One sentence: what it is and who uses it. Not a tagline — a description.>

![<what the screenshot shows>](docs/assets/<name>.png)

## What it does

<2-4 sentences. The problem it solves and the shape of the solution. Name the
domain in the user's terms, not the framework's: "tracks hours logged by NEO
members across projects", not "a full-stack CRUD application".>

## Running it locally

<Numbered steps, from clone to a working app. Every command copy-pasteable.
State the versions that are known to work — Node, Python, database — because
"should work with any recent version" is how someone loses an afternoon.>

## Configuration                                        [conditional]

<A table of every environment variable: name, what it's for, whether it's
required, and an example of a fake value. Point at .env.example. Never a real
credential, not even a truncated one.>

## Layout

<Where things live and where to read next. A short tree of the top-level
directories with one line each, then a pointer to the feature docs:
"Each module documents its own features under <module>/docs/.">

## Common tasks                                         [conditional]

<The commands someone actually runs day to day: tests, migrations, seeding,
the linter, a build. One line each, in a table or a short list.>

## Deployment                                           [conditional]

<Where it runs, what triggers a deploy, and how to check it worked. Skip
entirely if deploys are manual and undocumented — an empty promise is worse
than silence.>
```

## Screenshots

- **Store them in `docs/assets/`**, committed, referenced by relative path:
  `![Vendor list with an active filter](docs/assets/vendor-list.png)`. Relative
  paths survive forks and clones; a URL pasted from an issue upload does not.
- **One image near the top**, showing the main surface. More only when there are
  genuinely distinct surfaces worth showing.
- **A short GIF beats five stills** for anything with a flow — a form being
  filled, a filter being applied. Keep it under ten seconds and under 5 MB.
- **Only stable surfaces.** A screenshot of a screen that changes every sprint
  will be wrong within a month, and a wrong screenshot is trusted.
- **Alt text says what the screenshot shows**, not "screenshot". It's what a
  reader sees when the image fails to load.
- **Never a screenshot with real data.** Seed data or redacted values only —
  names, e-mails, document numbers and money figures all count.

## Tone

Written the way a colleague explains the project at a desk. Plain, direct, no
performance.

Never:

- Emoji in headings, or as bullets
- "Welcome to...", "Happy coding!", "Feel free to..."
- "This project aims to...", "designed to provide..."
- Marketing adjectives: `robust`, `seamless`, `powerful`, `blazing fast`,
  `enterprise-grade`, `cutting-edge`, `comprehensive`
- A features list of adjectives instead of capabilities. "Fast and intuitive
  interface" says nothing; "bulk-edits up to 500 rows without a page reload"
  says something.
- Badges that measure nothing. CI status is a fact; language percentage is
  decoration.
- A hand-written table of contents — GitHub generates one from the headings.

## Rules

- **English** (Rule 0), like everything else in the repo.
- **Updated when the front door changes** — a new setup step, a changed
  environment variable, a new way to run the project, a renamed top-level
  directory. Not on every feature: a feature that doesn't change how the project
  is run doesn't touch the README. That's what the feature document is for.
- **Its own commit**: `docs(README): <what changed>`.
- **No fabrication.** Every command in the README must have been run and worked.
  If a step wasn't verified, either verify it or say plainly that it's untested.
- **Nothing that duplicates a feature document.** When a section starts
  explaining resolution order or payload shapes, it belongs in
  `<module>/docs/<feature>.md` — cut it and link.
