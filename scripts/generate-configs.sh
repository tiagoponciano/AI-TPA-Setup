#!/usr/bin/env bash
# generate-configs.sh — derive AGENTS.md (Codex) and .cursor/rules/*.mdc (Cursor)
# from the single source of truth: CLAUDE.md, skills/*/SKILL.md, rules/*.md.
#
# Cursor has no Claude Code skill-loading mechanism, so:
#   - skill content is inlined in its always-on working-agreement rule
#   - rules/*.md path-scoped conventions become Cursor glob-scoped rule files
# Codex discovers skills from ~/.agents/skills; its AGENTS.md keeps only
# always-on rules and points to the on-demand skills by name.
#   - the git-guardrails.sh hook isn't ported: its checks just restate Rules
#     2-4, which are already in the prose these files carry
#
# Run after editing CLAUDE.md, skills/, or rules/. Never hand-edit the outputs.

set -euo pipefail
cd "$(dirname "$0")/.."

GENERATED_NOTE="<!-- GENERATED FILE — do not edit directly. Source: CLAUDE.md, skills/, rules/. Regenerate with scripts/generate-configs.sh -->"

# Drops the frontmatter block and the one blank line conventionally left
# right after it, so callers don't have to trim a leading blank themselves.
strip_frontmatter() {
  awk '
    BEGIN{fm=0; afterfm=0}
    NR==1 && $0=="---"{fm=1; next}
    fm==1 && $0=="---"{fm=0; afterfm=1; next}
    fm==1{next}
    afterfm==1 && $0==""{afterfm=0; next}
    {afterfm=0; print}
  ' "$1"
}

# One extra "#" on every heading line — nests a skill/rule doc's own H1
# under the section it's placed in.
# Skips fenced code blocks: a "# ..." bash comment or a heading shown inside
# an example ```markdown block is literal content, not a real heading.
demote_headings() {
  awk '
    /^```/{infence = !infence; print; next}
    infence{print; next}
    /^#/{print "#" $0; next}
    {print}
  '
}

paths_to_globs() {
  awk '
    /^paths:/ { p=1; next }
    p && /^---$/ { exit }
    p {
      gsub(/^  - "/, ""); gsub(/"$/, "")
      printf "%s%s", (n++ ? "," : ""), $0
    }
  ' "$1"
}

# Rewrite Claude-specific skill-loading language into Codex skill references.
rewrite_codex_skill_refs() {
  sed \
    -e 's/load the `pr-message` skill and follow it/use the `pr-message` skill and follow it/' \
    -e 's/Load the `session-checkpoint` skill\./Use the `session-checkpoint` skill./' \
    -e 's/Load the `feature-doc` skill when writing or updating one\./Use the `feature-doc` skill when writing or updating one./' \
    -e 's/Load `pr-message` skill/Use the `pr-message` skill/' \
    -e 's/Load `session-checkpoint` skill/Use the `session-checkpoint` skill/' \
    -e 's/load `feature-doc` skill/use the `feature-doc` skill/' \
    -e 's/Load the `project-readme` skill when starting one from scratch, when how the project is run or set up has changed, or when asked to improve an existing one\./Use the `project-readme` skill in those same cases./' \
    -e 's/Load `project-readme` skill/Use the `project-readme` skill/' \
    -e 's/^Detailed conventions load automatically when working with test files$/Use the test conventions when working with test files; use the data-work conventions/' \
    -e 's/^(`~\/\.claude\/rules\/tests\.md`) or with notebooks, SQL and pipelines$/when working with notebooks, SQL and pipelines./' \
    -e 's/^(`~\/\.claude\/rules\/data-work\.md`)\.$//'
}

# Rewrite skill references into Cursor's inlined appendix conventions.
rewrite_cursor_skill_refs() {
  sed \
    -e 's/load the `pr-message` skill and follow it/follow the PR message conventions in the appendix/' \
    -e 's/\*\*Always, regardless of the skill:\*\*/\*\*Always, regardless of these conventions:\*\*/' \
    -e 's/Load the `session-checkpoint` skill\./Follow the session checkpoint conventions in the appendix./' \
    -e 's/Load the `feature-doc` skill when writing or updating one\./Follow the feature documentation conventions in the appendix when writing or updating one./' \
    -e 's/Load `pr-message` skill/Follow PR message conventions (appendix)/' \
    -e 's/Load `session-checkpoint` skill/Follow session checkpoint conventions (appendix)/' \
    -e 's/load `feature-doc` skill/follow feature-doc conventions (appendix)/' \
    -e 's/Load the `project-readme` skill when starting one from scratch, when how the project is run or set up has changed, or when asked to improve an existing one\./follow the project README conventions in the appendix in those same cases./' \
    -e 's/Load `project-readme` skill/Follow project README conventions (appendix)/' \
    -e 's/^Detailed conventions load automatically when working with test files$/Detailed conventions: test-file conventions and notebook\/SQL\/pipeline/' \
    -e 's/^(`~\/\.claude\/rules\/tests\.md`) or with notebooks, SQL and pipelines$/conventions are covered separately below (auto-attached by glob where/' \
    -e 's/^(`~\/\.claude\/rules\/data-work\.md`)\.$/the tool supports it)./'
}

# CLAUDE.md minus its Claude-specific title/intro (lines 1-5), adapted for
# each target's own instruction-loading model.
CODEX_RULES_BODY=$(tail -n +7 CLAUDE.md | rewrite_codex_skill_refs)
CURSOR_RULES_BODY=$(tail -n +7 CLAUDE.md | rewrite_cursor_skill_refs)

PR_MESSAGE_APPENDIX=$(strip_frontmatter skills/pr-message/SKILL.md | demote_headings)
SESSION_CHECKPOINT_APPENDIX=$(strip_frontmatter skills/session-checkpoint/SKILL.md | demote_headings)
FEATURE_DOC_APPENDIX=$(strip_frontmatter skills/feature-doc/SKILL.md | demote_headings)
PROJECT_README_APPENDIX=$(strip_frontmatter skills/project-readme/SKILL.md | demote_headings)
TESTS_BODY=$(strip_frontmatter rules/tests.md | demote_headings)
DATA_WORK_BODY=$(strip_frontmatter rules/data-work.md | demote_headings)

# NOTE: built with printf, not a `cat <<EOF` inside $(...) — bash's parser
# mishandles apostrophes in a heredoc nested inside command substitution.
APPENDIX=$(printf '%s\n\n%s\n\n%s\n\n%s\n\n%s\n\n%s' \
  "## Appendix: on-demand conventions" \
  "These were separate, on-demand skills in Claude Code. Cursor has no skill-loading mechanism, so follow them directly whenever the rules above point to them." \
  "$PR_MESSAGE_APPENDIX" "$SESSION_CHECKPOINT_APPENDIX" "$FEATURE_DOC_APPENDIX" "$PROJECT_README_APPENDIX")

# --- AGENTS.md (Codex) ------------------------------------------------------
# Codex loads skill metadata from ~/.agents/skills and reads a selected
# SKILL.md on demand. Keep this file limited to the always-on agreement.

mkdir -p "$(dirname AGENTS.md)"
cat > AGENTS.md <<EOF
${GENERATED_NOTE}

# Working agreement

Applies to this project. A project's own \`AGENTS.md\` further down the tree
overrides anything here.

${CODEX_RULES_BODY}
EOF

# --- .agents/skills (Codex, repository-local and global source) -------------
# Rules have path-scoped loading in Claude Code and Cursor. Codex exposes
# equivalent conventions as on-demand skills, so generate small skill bundles
# from the same rule sources.

mkdir -p .agents/skills/tests .agents/skills/data-work

for skill in feature-doc pr-message project-readme session-checkpoint; do
  ln -sfn "../../skills/${skill}" ".agents/skills/${skill}"
done

cat > .agents/skills/tests/SKILL.md <<EOF
---
name: tests
description: Apply the project's test conventions when creating or changing test files.
---

${GENERATED_NOTE}

${TESTS_BODY}
EOF

cat > .agents/skills/data-work/SKILL.md <<EOF
---
name: data-work
description: Apply the project's conventions when working with notebooks, SQL, pipelines, ETL, or dbt.
---

${GENERATED_NOTE}

${DATA_WORK_BODY}
EOF

# --- .cursor/rules/*.mdc (Cursor) -------------------------------------------
# Split back out by scope, using Cursor's native glob-scoped loading — the
# same mechanism rules/*.md already uses via its `paths:` frontmatter.

mkdir -p .cursor/rules

cat > .cursor/rules/working-agreement.mdc <<EOF
---
description: Working agreement — Karpathy behavioral guidelines and Rules 0-7 for git, commits, PRs, checkpoints, docs and tests
alwaysApply: true
---

${GENERATED_NOTE}

# Working agreement

${CURSOR_RULES_BODY}

---

${APPENDIX}
EOF

TESTS_GLOBS=$(paths_to_globs rules/tests.md)
cat > .cursor/rules/tests.mdc <<EOF
---
description: Test conventions
globs: ${TESTS_GLOBS}
alwaysApply: false
---

${GENERATED_NOTE}

${TESTS_BODY}
EOF

DATA_WORK_GLOBS=$(paths_to_globs rules/data-work.md)
cat > .cursor/rules/data-work.mdc <<EOF
---
description: Notebook, SQL and pipeline conventions
globs: ${DATA_WORK_GLOBS}
alwaysApply: false
---

${GENERATED_NOTE}

${DATA_WORK_BODY}
EOF

echo "Generated AGENTS.md and .cursor/rules/{working-agreement,tests,data-work}.mdc"
