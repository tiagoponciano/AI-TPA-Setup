---
name: github-issue
description: Draft or create actionable GitHub issues from screenshots, bug reports, and UI improvement descriptions, with visual evidence, acceptance criteria, and verified related issues. Use when turning user observations into issues ("cria uma issue", "abre uma issue disso", "olha esse print", "write an issue for this"); not for implementing fixes or writing pull requests.
---

# GitHub Issue

Turn rough observations into a concise issue a developer can implement and
verify. Preserve the user's intent, including the latest visual correction.

## Establish the scope

- Infer the target repository from the supplied URL or current project. Ask
  only when multiple targets remain plausible or a required input is missing.
- Read applicable repository instructions and issue templates. Follow their
  language and format; default to English for issue titles and bodies when
  neither specifies a language. Converse in the user's language.
- Distinguish drafting, generating a design image, creating an issue, and
  editing an existing issue. An explicit request to create an issue authorizes
  that action; a request for a draft or image alone does not.
- If the latest request is only for a solution image, produce that image and
  stop. Resume issue work only when requested. Do not implement the fix.

## Read the evidence

Inspect each supplied screenshot before describing it. Separate the current
UI from any proposed design. If their roles are ambiguous, ask instead of
guessing. Use the user's description for behavior that a still image cannot
demonstrate, and attribute it as reported rather than independently reproduced.

Name the affected screen, observable problem, and practical impact. Do not
invent browser versions, viewport measurements, routes, errors, reproduction
steps, root causes, or implementation details. Include reproduction steps only
when supplied or verified. A clipped chart is evidence of clipping, not proof
of a particular CSS bug.

Keep explicit design constraints concrete: position, dimensions when supplied,
visible information, actions, and responsive behavior. A later correction
such as "bottom-right" replaces an earlier position everywhere in the issue
and design reference. Do not turn one task's layout choice into a default for
other tasks.

## Check screenshots for sensitive data

Before any screenshot leaves the machine, look for tokens, API keys, e-mail
addresses, customer data, internal URLs, and anything else that should not be
public. Check the target repository's visibility first. If something sensitive
is visible, say what and where, and ask whether to crop or redact it. Never
upload or embed the image until that is resolved.

## Prepare visual evidence when requested

- Preserve the original screenshot as current-state evidence. Do not present
  a generated or edited image as the actual application.
- Generate or edit a proposed design only when requested, using available
  image tools. Preserve surrounding UI and change only the requested area.
- Inspect the result against the latest instructions before using it. For
  example, if a widget moved from the upper-left to the bottom-right, check
  that the old copy is gone and the new copy is in the requested corner.
- Label the images **Current** and **Proposed**. Explain the intended change
  in text, so the requirement remains understandable without the images.
- Embed actual, accessible attachment URLs, with descriptive alt text. Local
  paths and temporary preview links are not GitHub attachments. Use a supported
  upload mechanism when available; do not invent an upload API or asset URL.
  If uploading is unavailable and images are required, prepare the full draft
  and request the attachments or durable URLs before publishing. Do not commit
  screenshots to the repository merely to obtain URLs.

## Find related work

Search the target repository for the affected feature and similar symptoms
before creating an issue. Fetch promising matches, including any issue the
user identifies, and verify the repository, number, title, status, and scope.
If search is unavailable, disclose that limitation and never claim that no
duplicates exist.

- For an apparent duplicate, show the existing issue and ask whether the user
  wants an update or a separate issue, unless that choice is already explicit.
- For complementary work, explain the shared requirement without merging
  distinct scopes. Use `Related to #123` in the same repository or
  `Related to owner/repo#123` across repositories.
- Use dependency language only when the dependency is established. Do not use
  closing keywords such as `Closes` merely to associate issues.
- Updating the counterpart is a separate mutation: do it only when requested
  or already authorized. Do not change its labels, state, or scope by default.

## Write the issue

Use a short, concrete title naming the symptom or requested outcome. Keep one
cohesive problem per issue; split independently actionable problems when the
user requests them. Avoid generic titles, decorative headings, and speculative
technical solutions.

Use the repository template when present. Otherwise use this structure,
omitting conditional sections rather than leaving empty headings:

```markdown
## Problem
Describe the affected screen, current behavior, and user impact.

## Steps to reproduce
Include only supplied or verified steps; omit when unavailable.

## Expected behavior
Describe the intended observable outcome.

## Acceptance criteria
- [ ] State an observable outcome that can be checked.
- [ ] Cover relevant states and responsive behavior within the agreed scope.

## Screenshot
Describe and embed current-state evidence using an actual attachment URL.

## Related issue
- Related to #123 — explain the verified relationship.
```

For a redesign, use **Proposed design** instead of **Expected behavior**, and
**Visual comparison** instead of **Screenshot**, with **Current** and
**Proposed** image captions. For a report without images, omit visual sections.
Replace all template guidance with actual content and include related issues
only after verification.

Acceptance criteria describe completion, not an unverified test result. Keep
checkboxes unchecked. Include reported navigation states, readability, controls,
and layout constraints when relevant. Do not invent pixel values, performance
targets, or unrelated requirements. A design reference illustrates intent;
the issue text defines the behavior.

## Deliver or publish

For drafts, return a copyable title and Markdown body. For publication, use the
available GitHub connector, or an authenticated CLI if the connector lacks the
needed capability. Preserve multiline bodies exactly; with a CLI, prefer a
temporary body file over shell-interpolated text. Ask for missing required
fields or permissions only when they block the authorized action. Apply labels,
assignees, milestones, and project membership only when requested or required
by the repository's established workflow; never invent their values.

Before publishing, check the latest corrections against the title, body, and
images; confirm that attachment URLs and related references are real. After
creating or updating, fetch the stored issue and verify its title, body,
attachments, and relationships. If the result of a create call is uncertain,
search for that issue before retrying to avoid duplicates. Stop and report a
permission or upload failure instead of repeatedly attempting the same action.

Return the issue link and a brief description of what was created or updated.
Keep any limitations visible. Never claim a fix was implemented, a bug was
reproduced, or acceptance checks passed merely because the issue was written.
