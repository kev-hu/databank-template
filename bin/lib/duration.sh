# bin/lib/duration.sh — duration parsing and freshness checks. Source me.

# parse_duration_seconds <Nd|Nh|Nm> → echoes seconds. Exits nonzero on bad input.
parse_duration_seconds() {
  local s="${1:-}"
  if [[ "$s" =~ ^([0-9]+)([dhm])$ ]]; then
    local n="${BASH_REMATCH[1]}" unit="${BASH_REMATCH[2]}"
    case "$unit" in
      d) echo $(( n * 86400 )) ;;
      h) echo $(( n * 3600  )) ;;
      m) echo $(( n * 60    )) ;;
    esac
    return 0
  fi
  echo "invalid duration: $s (expected Nd, Nh, or Nm)" >&2
  return 1
}

# iso_to_epoch <ISO-8601 UTC> → echoes Unix epoch seconds. Empty input → 0.
iso_to_epoch() {
  local ts="${1:-}"
  [ -z "$ts" ] && { echo 0; return 0; }
  # macOS BSD date and GNU date have different flags. Try BSD first.
  date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null \
    || date -u -d "$ts" +%s 2>/dev/null \
    || { echo "iso_to_epoch: bad timestamp: $ts" >&2; return 1; }
}

# is_fresh <iso-timestamp> <max-age-string> → exit 0 if (now - ts) < max_age.
# Empty timestamp is never fresh.
is_fresh() {
  local ts="${1:-}" max="${2:?max-age required}"
  [ -z "$ts" ] && return 1
  local ts_epoch now max_seconds
  ts_epoch=$(iso_to_epoch "$ts")  || return 1
  max_seconds=$(parse_duration_seconds "$max") || return 1
  now=$(date -u +%s)
  [ $(( now - ts_epoch )) -lt "$max_seconds" ]
}
