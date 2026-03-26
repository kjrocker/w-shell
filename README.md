# w

Git worktree manager. Create, navigate, list, and remove worktrees. Optionally orchestrate setup commands and dev servers with automatic port allocation via `.wtconfig.toml`.

## Dependencies

- `jq` — JSON state files
- `yq` — TOML config parsing
- `bats-core` — tests only

## Install

Clone this repo, then source the shell wrapper in your shell rc file:

```bash
# zsh — add to ~/.zshrc
source /path/to/w/w.zsh

# bash — add to ~/.bashrc
source /path/to/w/w.bash
```

The wrapper defines a `w` function that calls `bin/w`. Zsh completions are in `completions/_w`.

## Usage

```
w <name>          Switch to (or create) worktree
w <name> <cmd>    Run command in worktree
w init            Create a .wtconfig.toml in the repo root
w ls              List worktrees
w status          Project dashboard
w rm <name>       Remove worktree
w exit            Hint to type 'exit' to leave subshell
```

## Config

Optional `.wtconfig.toml` in the repo root:

```toml
path = "{parent}/{project}.{name}"

[setup]
commands = ["npm install", "cp $W_ROOT/.env .env"]

[env]
PORT = "{base:3000}"
API_PORT = "{base:8080}"
DATABASE_URL = "postgres://localhost/myapp_{name}"
```

See [SPEC.md](SPEC.md) for full documentation.
