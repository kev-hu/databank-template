# bin/lib/common.sh — paths and small helpers shared by databank and scrapers.
# Source me. Sets DATABANK_ROOT if not already set.

if [ -z "${DATABANK_ROOT:-}" ]; then
  # Caller is in bin/ or bin/sources/<source>/. Walk up until we find CONTRACT.md.
  _here="$(cd "$(dirname "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}")" && pwd)"
  while [ "$_here" != "/" ] && [ ! -f "$_here/CONTRACT.md" ]; do
    _here="$(dirname "$_here")"
  done
  if [ ! -f "$_here/CONTRACT.md" ]; then
    echo "common.sh: could not locate DATABANK_ROOT (no CONTRACT.md found)" >&2
    return 1
  fi
  DATABANK_ROOT="$_here"
fi
export DATABANK_ROOT

DATABANK_LIB="$DATABANK_ROOT/bin/lib"
DATABANK_DATA="$DATABANK_ROOT/data"
DATABANK_STATE="$DATABANK_ROOT/state"
DATABANK_LOGS="$DATABANK_ROOT/logs"
DATABANK_CONFIG="$DATABANK_ROOT/config"
export DATABANK_LIB DATABANK_DATA DATABANK_STATE DATABANK_LOGS DATABANK_CONFIG

now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# log "msg" → stderr with prefix; intended for human-visible status lines.
log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >&2; }

# Atomically replace $1 with stdin contents.
atomic_write() {
  local out="${1:?output path required}"
  mkdir -p "$(dirname "$out")"
  local tmp="$out.tmp"
  cat > "$tmp"
  mv "$tmp" "$out"
}

# help_guard "<usage text>" "$@" — if -h/--help appears in the args, print the
# usage and exit 0. Call right after sourcing common.sh, before any yq/config
# preflight, so `--help` works without dependencies or config present. Every
# verb+source must satisfy this; tests/test-help-contract.sh enforces it.
help_guard() {
  local usage="$1"; shift
  local a
  for a in "$@"; do
    case "$a" in -h|--help) printf '%s\n' "$usage"; exit 0 ;; esac
  done
}
