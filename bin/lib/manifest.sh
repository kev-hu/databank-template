# bin/lib/manifest.sh — atomic read/write of state/manifest.json. Source me.
#
# Requires DATABANK_ROOT to be set by the caller.

_manifest_path() { echo "$DATABANK_ROOT/state/manifest.json"; }

_manifest_init_if_missing() {
  local p; p=$(_manifest_path)
  if [ ! -f "$p" ]; then
    mkdir -p "$(dirname "$p")"
    echo '{}' > "$p"
  fi
}

# Echo full JSON object for a key, or empty if absent.
manifest_get() {
  local key="${1:?key required}"
  _manifest_init_if_missing
  jq --arg k "$key" '.[$k] // empty' "$(_manifest_path)"
}

# Echo one scalar field for a key, or empty if absent.
manifest_get_field() {
  local key="${1:?key required}" field="${2:?field required}"
  _manifest_init_if_missing
  jq -r --arg k "$key" --arg f "$field" '.[$k][$f] // ""' "$(_manifest_path)"
}

# Set a key's value to the given JSON. Atomic and safe under parallel
# sweep workers — uses an mkdir-based lock to serialize the read-modify-
# write so concurrent writers don't clobber each other. Per-PID tmp
# filename prevents .tmp collisions; mkdir is atomic on POSIX.
# Usage: manifest_set <key> <json-string>
manifest_set() {
  local key="${1:?key required}" json="${2:?json required}"
  _manifest_init_if_missing
  local p tmp lockdir waited=0
  p=$(_manifest_path)
  lockdir="$p.lock"
  while ! mkdir "$lockdir" 2>/dev/null; do
    sleep 0.1
    waited=$((waited + 1))
    if [ "$waited" -gt 600 ]; then
      echo "manifest_set: lock timeout (60s) on $lockdir — breaking stale lock" >&2
      rmdir "$lockdir" 2>/dev/null || true
      waited=0
    fi
  done
  tmp="$p.tmp.$$"
  local rc=0
  jq --arg k "$key" --argjson v "$json" '.[$k] = $v' "$p" > "$tmp" && mv "$tmp" "$p" || rc=$?
  rmdir "$lockdir" 2>/dev/null || true
  [ -f "$tmp" ] && rm -f "$tmp"
  return "$rc"
}

# Helper: mark an entry ok with last_fetched=now and merge in extra fields.
# Usage: manifest_set_ok <key> [extra-json]
manifest_set_ok() {
  local key="${1:?key required}" extra="${2:-{\}}"
  local now; now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local merged
  merged=$(jq -n --arg t "$now" --argjson x "$extra" '{last_fetched: $t, status: "ok"} + $x')
  manifest_set "$key" "$merged"
}

# Helper: mark an entry error with last_fetched=now and the given message.
# Usage: manifest_set_error <key> <error-message>
manifest_set_error() {
  local key="${1:?key required}" msg="${2:?error message required}"
  local now; now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local merged
  merged=$(jq -n --arg t "$now" --arg e "$msg" '{last_fetched: $t, status: "error", error: $e}')
  manifest_set "$key" "$merged"
}
