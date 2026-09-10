#!/usr/bin/env bash
# Shared by every file under tests/cases/. Sourced by tests/run.sh before a case file runs.
#
#   R            the plugin root; scripts are "$R/scripts/<name>/<name>.sh"
#   WORK         a fresh temporary directory, removed when the case file ends
#   fixture NAME [DEST]   copies tests/fixtures/NAME into $WORK/DEST and prints that path
#   overlay NAME DIR      copies tests/fixtures/NAME/. over DIR — a bad/ variant over a copy of good/
#   repo DIR              makes DIR a git repository with one commit, so hooks that ask git for the root work
#   variant FIXTURE NAME [DEST]   the three above in one: copies tests/fixtures/FIXTURE/good to
#                         $WORK/DEST (DEST defaults to NAME), lays tests/fixtures/FIXTURE/bad/NAME
#                         over it when that directory exists, makes it a repository, prints the path
#
#   check LABEL EXPECTED ACTUAL          strings equal
#   check_match LABEL PATTERN TEXT       grep -E finds PATTERN in TEXT
#   check_no_match LABEL PATTERN TEXT    grep -E does not find PATTERN in TEXT
#   check_ok LABEL CMD...                command exits 0
#   check_rc LABEL CODE CMD...           command exits with exactly CODE
#   check_fails LABEL CMD...             command exits non-zero
#   check_golden LABEL GOLDEN ACTUAL     files identical; UPDATE_GOLDEN=1 rewrites GOLDEN from ACTUAL
#
# Every check prints one line, "ok" or "FAIL", and a FAIL shows expected beside actual. The file's exit
# status is the number of failures, capped at 1.
set -u
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
R="$(cd "$TESTS_DIR/../plugin" && pwd)"
PASSED=0
FAILED=0

pass() { PASSED=$((PASSED + 1)); printf '  ok    %s\n' "$1"; }
fail() { FAILED=$((FAILED + 1)); printf '  FAIL  %s\n' "$1"; shift; printf '        %s\n' "$@"; }

check() {
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected: $2" "actual:   $3"; fi
}
check_match() {
  if printf '%s\n' "$3" | grep -Eq -- "$2"; then pass "$1"; else fail "$1" "pattern: $2" "text:    $(printf '%s' "$3" | head -c 400)"; fi
}
check_no_match() {
  if printf '%s\n' "$3" | grep -Eq -- "$2"; then fail "$1" "unwanted pattern: $2" "text: $(printf '%s' "$3" | grep -E -- "$2" | head -3)"; else pass "$1"; fi
}
check_ok() {
  local label="$1"; shift
  local out; out="$("$@" 2>&1)"; local rc=$?
  if [ $rc -eq 0 ]; then pass "$label"; else fail "$label" "exit $rc from: $*" "$(printf '%s' "$out" | head -5)"; fi
}
check_fails() {
  local label="$1"; shift
  local out; out="$("$@" 2>&1)"; local rc=$?
  if [ $rc -ne 0 ]; then pass "$label"; else fail "$label" "exit 0, expected failure from: $*" "$(printf '%s' "$out" | head -5)"; fi
}
check_rc() {
  local label="$1" want="$2"; shift 2
  local out; out="$("$@" 2>&1)"; local rc=$?
  if [ "$rc" -eq "$want" ]; then pass "$label"
  else fail "$label" "expected: exit $want" "actual:   exit $rc from: $*" "$(printf '%s' "$out" | head -5)"; fi
}
check_golden() {
  if [ "${UPDATE_GOLDEN:-}" = 1 ]; then cp "$3" "$2"; pass "$1 (golden rewritten)"; return; fi
  if [ ! -f "$2" ]; then fail "$1" "no golden file $2; run with UPDATE_GOLDEN=1 to write it"; return; fi
  local d; d="$(diff -u "$2" "$3")" && pass "$1" || fail "$1" "$(printf '%s' "$d" | head -30)"
}

fixture() {
  local dest="${2:-$(basename "$1")}"
  cp -R "$TESTS_DIR/fixtures/$1" "$WORK/$dest"
  printf '%s\n' "$WORK/$dest"
}
overlay() {
  cp -R "$TESTS_DIR/fixtures/$1/." "$2/"
}
repo() {
  (cd "$1" && git init -q --template= && git -c core.autocrlf=false add -A \
    && git -c core.autocrlf=false -c commit.gpgsign=false -c core.hooksPath=/dev/null \
           -c user.email=t@t -c user.name=t commit -qm fixture --allow-empty)
}

variant() {
  local p; p="$(fixture "$1/good" "${3:-$2}")"
  [ -d "$TESTS_DIR/fixtures/$1/bad/$2" ] && overlay "$1/bad/$2" "$p"
  repo "$p" > /dev/null
  printf '%s\n' "$p"
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

finish() {
  printf '%s: %d ok, %d failed\n' "$(basename "${BASH_SOURCE[1]}" .sh)" "$PASSED" "$FAILED"
  [ "$FAILED" -eq 0 ]
}
