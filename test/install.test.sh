#!/usr/bin/env bash
# Dependency-free tests for install.sh.
# Runs the real installer against a throwaway $HOME and project dir, then asserts
# the per-tool artifacts land in the right place. No bats / no network.
#
#   bash test/install.test.sh        # run all, prints PASS/FAIL, exits non-zero on any failure
#
# Notes:
# - We always pass explicit --tools/--all-tools so detection of the host's real
#   tools never leaks in.
# - $HOME is redirected to a temp dir so global installs are sandboxed.

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/.." && pwd)
INSTALL="$REPO/install.sh"
SKILL="prototype-to-prd"   # the skill that exists in this repo

pass=0
fail=0
fails=""

ok()   { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
no()   { fail=$((fail+1)); fails="$fails\n  - $1"; printf '  FAIL %s\n' "$1"; }

assert_file()   { if [ -f "$1" ]; then ok "$2"; else no "$2 (missing file: $1)"; fi; }
assert_symlink(){ if [ -L "$1" ]; then ok "$2"; else no "$2 (not a symlink: $1)"; fi; }
assert_absent() { if [ ! -e "$1" ] && [ ! -L "$1" ]; then ok "$2"; else no "$2 (still present: $1)"; fi; }
assert_grep()   { if grep -q "$1" "$2" 2>/dev/null; then ok "$3"; else no "$3 (pattern '$1' not in $2)"; fi; }

# Fresh sandbox per case: temp HOME + temp project, exported for the installer.
new_sandbox() {
  SBOX=$(mktemp -d)
  export HOME="$SBOX/home"
  PROJ="$SBOX/proj"
  mkdir -p "$HOME" "$PROJ"
  # Make sure no bootstrap ever triggers: the script must find skills next to itself.
  unset CSG_SKILLS_BOOTSTRAPPED 2>/dev/null || true
}
drop_sandbox() { rm -rf "$SBOX"; }

run() { bash "$INSTALL" "$@"; }

echo "== install.sh tests =="

# 1. copy global: lands in the three native per-user dirs; cursor skipped.
new_sandbox
run --global --copy --all-tools >/dev/null 2>&1
assert_file "$HOME/.claude/skills/$SKILL/SKILL.md"            "1a claude global skill present"
assert_file "$HOME/.agents/skills/$SKILL/SKILL.md"           "1b codex (.agents) global skill present"
assert_file "$HOME/.config/opencode/skills/$SKILL/SKILL.md"  "1c opencode global skill present"
drop_sandbox

# 2. project cursor: valid .mdc rule + command + bundled skill dir.
new_sandbox
run "$SKILL" --project="$PROJ" --copy --tools cursor >/dev/null 2>&1
MDC="$PROJ/.cursor/rules/$SKILL.mdc"
assert_file "$MDC"                                            "2a cursor .mdc rule present"
assert_grep "alwaysApply: false"  "$MDC"                     "2b .mdc has alwaysApply: false"
assert_grep "^description:"       "$MDC"                     "2c .mdc has a description field"
assert_file "$PROJ/.cursor/commands/$SKILL.md"               "2d cursor slash command present"
assert_file "$PROJ/.cursor/skills/$SKILL/SKILL.md"           "2e bundled skill dir present"
drop_sandbox

# 3. link mode: creates a symlink resolving back to the repo skill dir.
new_sandbox
run --global --link --tools claude >/dev/null 2>&1
assert_symlink "$HOME/.claude/skills/$SKILL"                 "3a claude install is a symlink"
assert_file    "$HOME/.claude/skills/$SKILL/SKILL.md"        "3b symlink resolves to SKILL.md"
drop_sandbox

# 4. uninstall: reverses a copy install; leaves an unrelated planted file alone.
new_sandbox
mkdir -p "$HOME/.claude/skills"
touch "$HOME/.claude/skills/UNRELATED.txt"
run --global --copy --tools claude >/dev/null 2>&1
assert_file "$HOME/.claude/skills/$SKILL/SKILL.md"           "4a installed before uninstall"
run --global --uninstall --tools claude >/dev/null 2>&1
assert_absent "$HOME/.claude/skills/$SKILL"                  "4b skill removed after uninstall"
assert_file   "$HOME/.claude/skills/UNRELATED.txt"           "4c unrelated file untouched"
drop_sandbox

# 5. dry-run: prints actions, changes nothing on disk.
new_sandbox
out=$(run --global --copy --tools claude --dry-run 2>&1)
assert_absent "$HOME/.claude/skills/$SKILL"                  "5a dry-run created nothing"
if printf '%s' "$out" | grep -qi "$SKILL"; then ok "5b dry-run printed an action mentioning the skill"; else no "5b dry-run printed no action"; fi
drop_sandbox

# 6. default-all: no positional skill arg installs every discovered skill.
new_sandbox
run --global --copy --tools claude >/dev/null 2>&1
assert_file "$HOME/.claude/skills/$SKILL/SKILL.md"           "6a no-arg run installs all skills"
drop_sandbox

echo
echo "passed: $pass   failed: $fail"
if [ "$fail" -ne 0 ]; then printf 'FAILURES:%b\n' "$fails"; exit 1; fi
echo "ALL PASS"
