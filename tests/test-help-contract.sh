#!/usr/bin/env bash
# test-help-contract.sh — every verb, every source/subcommand, and every
# analyzer must answer --help with exit 0 WITHOUT needing config, network, or
# dependencies. Test cases are auto-derived from the filesystem, so a new
# source or analyzer is covered the moment you add it — no edits here.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB="$ROOT/bin/databank"
fail=0

check() { # description, then the command + args
  local desc="$1"; shift
  if "$@" --help >/dev/null 2>&1; then
    printf '  ok    %s\n' "$desc"
  else
    printf '  FAIL  %s (exit %d)\n' "$desc" "$?" >&2
    fail=1
  fi
}

echo "help-contract:"
for verb in fetch get sweep analyze list status; do
  check "databank $verb --help" "$DB" "$verb"
done

for sdir in "$ROOT"/bin/sources/*/; do
  [ -d "$sdir" ] || continue
  source=$(basename "$sdir")
  for f in "$sdir"/fetch-* "$sdir"/get-*; do
    [ -x "$f" ] || continue
    check "$(basename "$f") --help" "$f"
  done
  [ -x "$sdir/sweep" ] && check "sweep $source --help" "$sdir/sweep"
done

for f in "$ROOT"/bin/analyzers/*; do
  [ -x "$f" ] || continue
  check "analyze $(basename "$f") --help" "$f"
done

if [ "$fail" -eq 0 ]; then echo "PASS"; else echo "FAILED" >&2; fi
exit "$fail"
