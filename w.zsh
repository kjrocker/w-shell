# w shell integration (zsh)
# Source this file in your .zshrc:
#   source /path/to/w-raku/w.zsh

W_ROOT="${W_ROOT:-$(cd "$(dirname "${(%):-%x}")" && pwd)}"

# Clean up stale cd-target on source
[[ -f "${W_STATE_DIR:-$HOME/.local/state/w}/cd-target" ]] && rm -f "${W_STATE_DIR:-$HOME/.local/state/w}/cd-target"

w() {
  local rc target_file target
  target_file="${W_STATE_DIR:-$HOME/.local/state/w}/cd-target"

  "$W_ROOT/bin/w" "$@"
  rc=$?

  # Only cd if bin/w exited successfully and cd-target exists
  if [[ $rc -eq 0 && -f "$target_file" ]]; then
    target="$(cat "$target_file")"
    rm -f "$target_file"
    [[ -n "$target" && -d "$target" ]] && cd "$target"
  else
    # Clean up cd-target on failure
    rm -f "$target_file" 2>/dev/null
  fi

  return $rc
}
