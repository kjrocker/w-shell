# w shell integration
# Source this file in your .zshrc:
#   source /path/to/w-raku/shell/w.zsh

W_ROOT="${W_ROOT:-$(cd "$(dirname "${(%):-%x}")/.." && pwd)}"

w() {
  "$W_ROOT/bin/w" "$@"
  local target="$HOME/.local/state/w/cd-target"
  if [[ -f "$target" ]]; then
    cd "$(cat "$target")"
    rm "$target"
  fi
}
