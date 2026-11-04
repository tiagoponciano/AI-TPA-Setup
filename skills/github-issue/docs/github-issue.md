# GitHub issue creation

## What this is

`github-issue` converts screenshots and descriptions into GitHub issue drafts
or published issues. Its runtime instructions are in [SKILL.md](../SKILL.md).
It supports bug reports and UI redesigns, including current/proposed image
comparisons and verified relationships to existing issues.

The skill is instruction-only. It does not bundle a GitHub client, image
generator, credentials, screenshots, or a repository-specific issue template.

## Rules and behavior

| Request or evidence | Outcome |
|---|---|
| Draft from a screenshot and notes | Copyable title and body; no external write |
| Explicitly create an issue | Check related work, publish, and fetch the stored issue to verify it |
| Only generate a solution image | Generate and inspect the requested image; stop before issue creation |
| Current and proposed screenshots | Label both roles and describe the intended change in text |
| Reported behavior not visible in a screenshot | Attribute it to the report; do not claim reproduction |
| Corrected placement or design constraint | Apply the latest correction to both prose and proposed visual |
| Complementary issue | Verify the reference and explain the shared requirement |
| Apparent duplicate | Resolve whether to update or create before writing externally |
| Required images have only local paths | Attach through the GitHub web editor with browser tools, or finish the draft and ask the user to paste the images |
| Sensitive data visible in a screenshot | Name it and ask whether to crop or redact; do not upload until resolved |
| Uncertain create result | Search for the issue before attempting another creation |

Repository instructions and templates govern issue language and structure.
Without a language convention, issue content defaults to English. Conversation
follows the user's language. Acceptance criteria remain unchecked.

## What this does NOT do

It does not implement fixes, write PR descriptions, or automatically close
related issues. It does not update a counterpart issue without authorization.
Generated designs are proposals, never evidence of the running application.

## Gotchas

- Local images fail to render on GitHub: filesystem paths are not attachment
  URLs, and `gh` cannot upload images.
- A proposal disagrees with a correction: generated visuals can preserve an
  earlier placement. Inspect the image and correct it before publishing.

## Setup

The canonical bundle is `skills/github-issue/`. Claude Code uses the existing
`~/.claude/skills` link to `skills/`. `scripts/generate-configs.sh` creates
`.agents/skills/github-issue` as a symlink to the bundle for Codex, and inlines
the runtime instructions in Cursor's generated working agreement. The optional
`agents/openai.yaml` supplies Codex display metadata and an invocation prompt.

Publishing requires a GitHub connector or authenticated CLI with access to the
target repository. Image generation and attachment uploads require available
tools supporting those operations. Drafting can proceed without them.
