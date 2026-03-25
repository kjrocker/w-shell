# w shell integration (zsh)
# Source this file in your .zshrc:
#   source /path/to/w/w.zsh

W_ROOT="${W_ROOT:-$(cd "$(dirname "${(%):-%x}")" && pwd)}"

w() {
  "$W_ROOT/bin/w" "$@"
}
