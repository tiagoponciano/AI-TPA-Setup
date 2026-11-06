#!/usr/bin/env bash
# pr-size-check.test.sh — behavior tests for pr-size-check.sh.
# Run directly: hooks/pr-size-check.test.sh. Uses throwaway repos with a local
# bare remote and a stubbed gh, so it needs no network and no GitHub auth.

set -uo pipefail

HOOK="$(cd "$(dirname "$0")" && pwd)/pr-size-check.sh"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

mkdir "$SANDBOX/bin"
cat > "$SANDBOX/bin/gh" <<'EOF'
#!/usr/bin/env bash
[ -n "${GH_STUB_BASE:-}" ] || exit 1
printf '%s\n' "$GH_STUB_BASE"
EOF
chmod +x "$SANDBOX/bin/gh"
export PATH="$SANDBOX/bin:$PATH"

FAILED=0
PASSED=0

# new_repo → cwd is a clone on branch `feature`, level with origin/main
new_repo() {
  local dir
  dir=$(mktemp -d "$SANDBOX/repo.XXXXXX")
  git init -q --bare -b main "$dir/origin.git"
  git clone -q "$dir/origin.git" "$dir/work" 2>/dev/null
  cd "$dir/work" || exit 1
  git checkout -q -B main
  echo seed > seed.txt
  git add seed.txt
  git commit -qm seed
  git push -q origin main
  git checkout -q -b feature
}

# commit_lines <path> <n> → commits a file holding n lines
commit_lines() {
  mkdir -p "$(dirname "$1")"
  seq 1 "$2" > "$1"
  git add "$1"
  git commit -qm "add $1"
}

# run_hook <command> → sets STATUS and STDERR
run_hook() {
  jq -n --arg c "$1" --arg d "$PWD" '{tool_input: {command: $c}, cwd: $d}' |
    "$HOOK" 2>"$SANDBOX/stderr"
  STATUS=$?
  STDERR=$(cat "$SANDBOX/stderr")
}

# check <test name> <expected> <actual>
check() {
  if [ "$2" = "$3" ]; then
    PASSED=$((PASSED + 1))
  else
    FAILED=$((FAILED + 1))
    printf 'FAIL: %s (expected %s, got %s)\n' "$1" "$2" "$3"
  fi
}

# --- The limit ---------------------------------------------------------------

new_repo; commit_lines a.txt 500; run_hook 'git push'
check 'allows a push of exactly 500 lines' 0 "$STATUS"

new_repo; commit_lines a.txt 501; run_hook 'git push'
check 'blocks a push of 501 lines' 2 "$STATUS"
case "$STDERR" in *501*) r=yes ;; *) r=no ;; esac
check 'block message states the measured size' yes "$r"

new_repo; commit_lines a.txt 501; run_hook 'gh pr create --title x'
check 'blocks gh pr create over the limit' 2 "$STATUS"

new_repo; commit_lines a.txt 501; run_hook 'cd . && git push'
check 'blocks a push chained after another command' 2 "$STATUS"

# --- What counts -------------------------------------------------------------

new_repo; commit_lines src.ts 400; commit_lines src.test.ts 100; commit_lines docs/f.md 1
run_hook 'git push'
check 'counts tests and docs toward the limit' 2 "$STATUS"

new_repo
git checkout -q main; commit_lines big.txt 300; git push -q origin main
git checkout -q feature; git merge -q --ff-only main
git rm -q big.txt; git commit -qm 'remove big'
seq 1001 1201 > a.txt; git add a.txt; git commit -qm 'unrelated content, so git sees no rename'
run_hook 'git push'
check 'counts deletions toward the limit' 2 "$STATUS"

new_repo; commit_lines a.txt 10
git checkout -q main; commit_lines big.txt 600; git push -q origin main
git checkout -q feature; git merge -q --no-edit origin/main
run_hook 'git push'
check 'ignores lines brought in by merging the base' 0 "$STATUS"

new_repo; commit_lines a.txt 10
git checkout -q main; commit_lines big.txt 600; git push -q origin main
git checkout -q feature
run_hook 'git push'
check 'ignores lines the base gained after the branch left it' 0 "$STATUS"

# --- What does not count -----------------------------------------------------

for path in pnpm-lock.yaml package-lock.json yarn.lock poetry.lock uv.lock Gemfile.lock Cargo.lock nested/package-lock.json __snapshots__/a.snap; do
  new_repo; commit_lines "$path" 600; run_hook 'git push'
  check "excludes $path" 0 "$STATUS"
done

new_repo; commit_lines my-yarn.lock.ts 600; run_hook 'git push'
check 'still counts a source file named like a lockfile' 2 "$STATUS"

new_repo
echo 'gen/a.txt linguist-generated' > .gitattributes
git add .gitattributes; git commit -qm attrs
commit_lines gen/a.txt 600; run_hook 'git push'
check 'excludes files marked linguist-generated' 0 "$STATUS"

new_repo
echo 'gen/a.txt linguist-generated=false' > .gitattributes
git add .gitattributes; git commit -qm attrs
commit_lines gen/a.txt 600; run_hook 'git push'
check 'counts files marked linguist-generated=false' 2 "$STATUS"

new_repo
echo '/gen/a.txt linguist-generated' > .gitattributes
git add .gitattributes; git commit -qm attrs
commit_lines gen/a.txt 600; cd gen; run_hook 'git push'
check 'resolves generated files from a subdirectory' 0 "$STATUS"

new_repo
printf '\000\001\002' > a.bin
git add a.bin; git commit -qm binary
commit_lines a.txt 500; run_hook 'git push'
check 'does not count binary files' 0 "$STATUS"

new_repo
git checkout -q main; commit_lines big.txt 600; git push -q origin main
git checkout -q feature; git merge -q --ff-only main
git mv big.txt moved.txt; git commit -qm rename
run_hook 'git push'
check 'does not count a pure rename' 0 "$STATUS"

# --- Base resolution ---------------------------------------------------------

# new_stacked_repo → origin/dev is origin/main + 600 lines; feature is dev + 10.
# Measured against dev it passes, measured against main it is blocked.
new_stacked_repo() {
  new_repo
  git checkout -q main; git checkout -q -b dev
  commit_lines big.txt 600; git push -q origin dev
  git checkout -q feature; git merge -q --ff-only dev
  commit_lines a.txt 10
}

new_stacked_repo; run_hook 'git push'
check 'falls back to origin/dev when it exists' 0 "$STATUS"

new_stacked_repo; GH_STUB_BASE=main run_hook 'git push'
check "uses the open PR's base over origin/dev" 2 "$STATUS"

new_stacked_repo; run_hook 'gh pr create --base main --title x'
check 'uses --base over origin/dev' 2 "$STATUS"

new_stacked_repo; run_hook 'gh pr create -B main --title x'
check 'uses -B over origin/dev' 2 "$STATUS"

new_stacked_repo; GH_STUB_BASE=main run_hook 'gh pr create --base dev --title x'
check "uses --base over the open PR's base" 0 "$STATUS"

new_repo; commit_lines a.txt 501; run_hook 'gh pr create --base nope --title x'
check 'allows the command when the base ref does not exist' 0 "$STATUS"

# --- Approval ----------------------------------------------------------------

new_repo; commit_lines a.txt 501
git rev-parse HEAD > .git/pr-size-ack; run_hook 'git push'
check 'allows an oversized push approved for this commit' 0 "$STATUS"

new_repo; commit_lines a.txt 501
git rev-parse HEAD > .git/pr-size-ack
commit_lines b.txt 1; run_hook 'git push'
check 'blocks again once a commit lands after the approval' 2 "$STATUS"

# --- Commands and states it leaves alone -------------------------------------

new_repo; commit_lines a.txt 501; run_hook 'git status'
check 'ignores unrelated commands' 0 "$STATUS"

new_repo; commit_lines a.txt 501; run_hook 'echo git push'
check 'ignores git push as an argument to another command' 0 "$STATUS"

new_repo; commit_lines a.txt 501; run_hook 'git push origin --delete old-branch'
check 'allows deleting a remote branch with --delete' 0 "$STATUS"

new_repo; commit_lines a.txt 501; run_hook 'git push origin -d old-branch'
check 'allows deleting a remote branch with -d' 0 "$STATUS"

new_repo; commit_lines a.txt 501; run_hook 'git push origin feature-d'
check 'blocks a push of a branch whose name ends in -d' 2 "$STATUS"

new_repo; git checkout -q main; commit_lines a.txt 501; run_hook 'git push'
check 'leaves the base branch to git-guardrails' 0 "$STATUS"

cd "$SANDBOX" || exit 1; run_hook 'git push'
check 'allows the command outside a git repository' 0 "$STATUS"

# --- count mode --------------------------------------------------------------

new_repo; commit_lines a.txt 42; commit_lines yarn.lock 600
check 'count prints the measured lines' 42 "$("$HOOK" count origin/main)"

new_repo
git checkout -q main; commit_lines big.txt 600; git push -q origin main
git checkout -q feature; git merge -q --ff-only main
git mv big.txt moved.txt
sed -i.bak '1,10s/^/x/' moved.txt && rm moved.txt.bak
git add moved.txt; git commit -qm 'rename and edit'
check 'count measures the edits inside a renamed file' 20 "$("$HOOK" count origin/main)"

new_repo; "$HOOK" count origin/nope >/dev/null 2>&1
check 'count fails on an unknown ref' 1 "$?"

# -----------------------------------------------------------------------------

printf '%d passed, %d failed\n' "$PASSED" "$FAILED"
[ "$FAILED" -eq 0 ]
