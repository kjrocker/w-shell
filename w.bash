# w shell integration (bash)
# Source this file in your .bashrc:
#   source /path/to/w/w.bash

_W_INSTALL_DIR="${_W_INSTALL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

w() {
  "$_W_INSTALL_DIR/bin/w" "$@"
}

_w_completions() {
  local cur prev subcmds
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  subcmds="init ls rm exit status --version --help"

  if [[ $COMP_CWORD -eq 1 ]]; then
    # Complete subcommands + worktree names
    local worktrees
    worktrees="$(git worktree list --porcelain 2>/dev/null | grep '^branch ' | sed 's|^branch refs/heads/||')"
    COMPREPLY=( $(compgen -W "$subcmds $worktrees" -- "$cur") )
    return
  fi

  case "${COMP_WORDS[1]}" in
    rm)
      if [[ $COMP_CWORD -eq 2 ]]; then
        local worktrees
        worktrees="$(git worktree list --porcelain 2>/dev/null | grep '^branch ' | sed 's|^branch refs/heads/||')"
        COMPREPLY=( $(compgen -W "$worktrees" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "--force" -- "$cur") )
      fi
      ;;
    init|ls|exit|status)
      ;;
    *)
      # w <name> <cmd...> — complete commands
      if [[ $COMP_CWORD -ge 2 ]]; then
        COMPREPLY=( $(compgen -c -- "$cur") )
      fi
      ;;
  esac
}

complete -F _w_completions w
