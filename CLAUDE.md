# w

Git worktree manager. Handles worktree create/navigate/list/remove, setup orchestration via `.wtconfig.toml`, and environment configuration with automatic port allocation. See SPEC.md for full design.

## Build & Run

```bash
# Run the CLI
bin/w --help

# Run all tests (requires sandbox disabled — bats needs /tmp/claude to exist)
bats t/

# Run a single test
bats t/01-core.bats
```

## Dependencies

- `jq` — JSON read/write for slot state
- `yq` — TOML parsing for .wtconfig.toml ([mikefarah/yq](https://github.com/mikefarah/yq), `sudo dnf install yq`)
- `bats-core` — test framework

## Code Style

- **Small, focused functions.** Each function does one thing. Name pattern: `_w_cmd_*` for subcommands, `_w_*` for internal helpers.
- **Prefer pipelines over temp variables.** Use `awk`, `jq`, `sed` inline where readable.
- **Minimal global state.** Pass values as arguments. The only globals are constants (`STATE_DIR`, `VERSION`).
- **Progress and informational messages to stderr** (`>&2`). Data output (ls, status) goes to stdout so it can be piped or captured.
- **Quote all variable expansions.** Always `"$var"`, never `$var`.
- Write tests for every exported function and subcommand
- Commit incrementally, use quick and terse commit messages
