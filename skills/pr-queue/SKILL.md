---
name: pr-queue
description: Check the open pull requests on a base branch against each other, not just against the base, and propose a merge order. Use when the user asks whether their open PRs conflict ("checa a fila de PRs", "algum PR meu vai dar conflito?", "quais PRs mexem nos mesmos arquivos?"), and from the pr-message skill as Check 1b.
---

# PR queue

Several PRs open on the same base can each merge clean against it and still
collide with each other. Checking a branch only against `origin/dev` misses
this: once the first PR lands, the rest are compared against a base that moved.
This skill checks the queue as a whole — read-only, nothing is merged, pushed or
checked out in the user's working tree.

## The hook runs first

`hooks/pr-queue-check.sh` does the conflict part deterministically, without
anyone asking:

- **Before `git push` and `gh pr create`** on a feature branch: every other open
  PR on the base is merged in sequence, then this branch on top. A conflict with
  one of the user's own PRs blocks the command; a conflict only with someone
  else's PR lets it through with a warning.
- **At session start**: lists the user's open PRs that no longer merge clean,
  against the base or once the PRs ahead of them land.

When the hook blocks or warns, this skill is the follow-up: explain the
conflict, propose the order, and say who resolves what. If the user decides to
push anyway, write the `HEAD` SHA to `.git/pr-queue-ack` as the block message
says — only on the user's explicit word, never on your own. The hook does not
build the combined state; step 5 below still does.

## 1. List the queue

```bash
git fetch origin
gh pr list --base dev --state open --json number,title,author,headRefName,files
```

Use the actual base (`dev` or `main`). The queue is every open PR on it — the
user's and everyone else's. When run from `pr-message`, the current branch is
part of the queue even if its PR isn't open yet.

## 2. Map the overlap

For each PR, the files it touches (`files` above, or
`git diff --name-only origin/dev...origin/<branch>`). Build the list of files
that appear in more than one PR. No shared files anywhere → report that in one
line and stop; there is nothing to simulate.

## 3. Propose an order

Default order, for the user's PRs:

1. PRs that change shared foundations (types, schemas, shared components,
   migrations) before PRs that only consume them
2. Among the rest, smaller and older first
3. PRs that touch a lockfile (`pnpm-lock.yaml`, `package-lock.json`,
   `yarn.lock`, `poetry.lock`, `uv.lock`) last

Other people's PRs keep their place as-is; don't reorder around them unless the
user asks.

## 4. Simulate the queue in sequence

Merge the PRs one on top of the other, in the proposed order, using plumbing
only — no `git merge`, no checkout, no branch touched:

```bash
TIP=$(git rev-parse origin/dev)
for ref in origin/<branch-1> origin/<branch-2> origin/<branch-3>; do
  if TREE=$(git merge-tree --write-tree "$TIP" "$ref"); then
    TIP=$(git commit-tree "$TREE" -p "$TIP" -p "$ref" -m "queue: $ref")
    echo "clean  $ref"
  else
    echo "CONFLICT $ref"          # merge-tree lists the conflicting paths
    echo "$TREE" | grep CONFLICT
  fi
done
```

Checking each PR against `dev` alone is not enough: C can merge clean against
`dev` and still conflict once A is in. The sequence is what will actually
happen.

A conflicting PR is left out of `TIP` and the loop keeps going, so the report
covers the whole queue. Record which earlier PR it collides with — the one whose
files overlap with the conflicting paths.

## 5. Verify the combined state

Only when some files overlap: check out the final simulated commit in a
throwaway worktree and run the project's verification there (same table as
`pr-message` Check 2).

```bash
Q=$(mktemp -d)
git worktree add --detach "$Q" "$TIP"
# run the project's build + tests inside "$Q"
git worktree remove --force "$Q"
```

This catches what git can't: one PR renames a function, another still calls the
old name — no textual conflict, broken build. Always remove the worktree, even
when the run fails.

## 6. Report

One block, one line per PR, in the proposed order:

```
Queue on dev: #104 → #105 → #108 (this branch)
#104  no overlap
#105  features/projects/api.ts shared with #108 → clean in sequence
#108  CONFLICT with #105 in features/projects/api.ts
Combined build + tests: passed
Lockfile: #105 changes pnpm-lock.yaml — merge it last, or regenerate in the later PR
```

Then the recommendation: the order to merge in, and who resolves what.

## Resolving

- **Between the user's own PRs:** the later PR in the order resolves, and only
  after the earlier one is merged — bring the updated base into the later
  branch, exactly as `pr-message` Check 1 does. Never merge one PR branch into
  another to get ahead of it: that ties them together, and the second can no
  longer merge, be reverted or be reviewed on its own.
- **With someone else's PR:** report only. Never push to, merge into or comment
  on another person's branch.
- **Lockfiles:** never hand-resolve. The later PR regenerates it with the
  project's package manager after the base updates.
- Resolving is a separate step the user asks for. This skill only reports.

## Never

- Merge, rebase, push or check out anything in the user's working tree.
- Leave a worktree behind.
- Report a combined build as passing without having run it.
