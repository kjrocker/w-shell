# w

Git worktree manager. Create, navigate, list, and remove worktrees. Optionally orchestrate setup commands and dev servers with automatic port allocation via `.wtconfig.toml`.

Originally a Raku tool, now rewritten as a pure-shell (bash) implementation.

## Dependencies

- `jq` — JSON state files
- `yq` — TOML config parsing ([mikefarah/yq](https://github.com/mikefarah/yq), Go binary)
- `bats-core` — tests only

## Install

Clone this repo, then source the shell wrapper in your shell rc file:

```bash
# zsh — add to ~/.zshrc
source /path/to/w/shell/w.zsh

# bash — add to ~/.bashrc
source /path/to/w/shell/w.bash
```

The wrapper defines a `w` function that calls `bin/w` and handles directory changes. Zsh completions are in `completions/_w`.

## Usage

```
w <name>          Switch to (or create) worktree
w <name> <cmd>    Run command in worktree
w init            Create a .wtconfig.toml in the repo root
w ls              List worktrees
w status          Project dashboard
w rm <name>       Remove worktree
w exit            Return to main worktree
w serve [name]    Start dev servers
w stop [name]     Stop dev servers
```

## Config

Optional `.wtconfig.toml` in the repo root:

```toml
path = "{parent}/{project}.{name}"

[setup]
commands = ["npm install", "cp .env.example .env"]

[[server]]
name = "frontend"
command = "npm run dev"
port-env = "PORT"
base-port = 3000
```

See [SPEC.md](SPEC.md) for full documentation.
