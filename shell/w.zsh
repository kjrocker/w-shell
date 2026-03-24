# w-raku shell integration
# Source this file in your .zshrc:
#   source /path/to/w-raku/shell/w.zsh

W_RAKU_ROOT="${W_RAKU_ROOT:-$(cd "$(dirname "${(%):-%x}")/.." && pwd)}"

w() {
  raku -I"$W_RAKU_ROOT/lib" "$W_RAKU_ROOT/bin/w-raku" "$@"
  local target="$HOME/.local/state/w/cd-target"
  if [[ -f "$target" ]]; then
    cd "$(cat "$target")"
    rm "$target"
  fi
}
