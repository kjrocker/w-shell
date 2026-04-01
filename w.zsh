# w shell integration (zsh)
# Source this file in your .zshrc:
#   source /path/to/w/w.zsh

_W_INSTALL_DIR="${_W_INSTALL_DIR:-$(cd "$(dirname "${(%):-%x}")" && pwd)}"

w() {
  "$_W_INSTALL_DIR/bin/w" "$@"
}
