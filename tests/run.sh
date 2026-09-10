#!/usr/bin/env bash
# Runs every case file under tests/cases/, or the ones named: tests/run.sh plan cost.
# Exit status is non-zero when any case file failed. Each file sources tests/lib.sh.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ $# -gt 0 ]; then files=(); for n in "$@"; do files+=("$here/cases/$n.sh"); done
else files=("$here"/cases/*.sh); fi
bad=0
for f in "${files[@]}"; do
  [ -f "$f" ] || { echo "no such case file: $f" >&2; bad=$((bad + 1)); continue; }
  echo "== $(basename "$f" .sh)"
  bash "$f" || bad=$((bad + 1))
done
echo
if [ "$bad" -eq 0 ]; then echo "all case files passed"; else echo "$bad case file(s) failed"; exit 1; fi
