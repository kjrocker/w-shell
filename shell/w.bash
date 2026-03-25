# w shell integration (bash)
# Source this file in your .bashrc:
#   source /path/to/w-raku/shell/w.bash

W_ROOT="${W_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

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

_w_completions() {
  local cur prev subcmds
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  subcmds="init ls rm exit status serve stop --version --help"

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
    serve|stop)
      if [[ $COMP_CWORD -eq 2 ]]; then
        local worktrees
        worktrees="$(git worktree list --porcelain 2>/dev/null | grep '^branch ' | sed 's|^branch refs/heads/||')"
        COMPREPLY=( $(compgen -W "$worktrees" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "--only" -- "$cur") )
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
