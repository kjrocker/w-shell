# w-raku shell integration
# Source this file in your .zshrc:
#   source /path/to/w-raku/shell/w.zsh

W_RAKU_BIN="${W_RAKU_BIN:-$(dirname "${(%):-%x}")/../bin/w-raku}"

w() {
  raku -I"$(dirname "$W_RAKU_BIN")/../lib" "$W_RAKU_BIN" "$@"
  local target="$HOME/.local/state/w/cd-target"
  if [[ -f "$target" ]]; then
    cd "$(cat "$target")"
    rm "$target"
  fi
}
