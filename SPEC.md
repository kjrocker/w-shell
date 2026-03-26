# w: Git Worktree Orchestrator

A pure-shell git worktree manager. Adds setup orchestration, worktree management, dynamic naming, and per-worktree environment configuration with automatic port allocation.

## Shell integration

`w <name>` spawns an interactive subshell in the worktree directory with computed environment variables pre-loaded. When the user types `exit`, the subshell closes and they return to their original shell.

A thin wrapper function ensures `w` invokes `bin/w` correctly:

```bash
w() {
  bin/w "$@"
}
```

Source `w.bash` (or `w.zsh`) in your shell config to register the wrapper and completions.

All user-facing output goes to stderr; stdout is reserved for data output (`ls`, `status`).

## Subcommands

### `w <name>` — enter worktree

Create worktree from `main` (if it doesn't exist), run setup commands, and spawn an interactive subshell in the worktree directory. Environment variables from `[env]` in `.wtconfig.toml` are exported into the subshell.

The worktree destination is determined by the `path` template in configuration (see [Worktree path template](#worktree-path-template)). Default: sibling directories.

```
$ w feat-x
Creating worktree feat-x...
Running setup: npm install
Running setup: cp .env.example .env
→ ~/projects/myapp.feat-x
$ echo $PORT     # env vars are set
3001
$ exit           # return to original shell
```

Nesting is prevented: running `w another` inside an existing subshell will refuse with a message.

### `w <name> <cmd...>` — run in worktree

Run a command in the worktree's directory without entering a subshell. Environment variables from `[env]` are also set for the command.

```
$ w feat-x npm test
# runs npm test in ~/projects/myapp.feat-x with PORT=3001 etc.
```

### `w ls` — list worktrees

List all worktrees for the current project with git status summary and computed env vars. Project-scoped (current repo only).

```
$ w ls
  main        clean   [ahead 2]  PORT=3000
* feat-x      dirty   3 files changed  PORT=3001
  bugfix-y    clean
```

Columns: name, clean/dirty, ahead/behind, env vars (if configured).

### `w rm <name>` — remove worktree

Remove worktree directory. Refuses to remove if the branch has unmerged commits (override with `--force`). Cannot remove a worktree while inside its subshell.

```
$ w rm feat-x
Removing worktree feat-x...
Done.
```

### `w exit` — hint

Prints a reminder to type `exit` to leave the subshell. Kept in the router to prevent accidentally creating a worktree named "exit".

### `w status` — project dashboard

Show all worktrees for the current project with full status: git state, computed env vars.

```
$ w status
myapp — 3 worktrees

  main        clean   [ahead 2]
              PORT=3000
  feat-x      dirty   3 files changed
              PORT=3001
  bugfix-y    clean
```

### `w init` — create config

Create a skeleton `.wtconfig.toml` in the repo root with commented-out examples of all config sections.

## Per-repo config: `.wtconfig.toml`

Optional. Lives in the main worktree / repo root. Without it, `w` does plain worktree create/navigate/remove with no setup or env features.

```toml
path = "{parent}/{project}.worktrees/{name}"   # override default layout

[setup]
commands = ["npm install", "cp .env.example .env"]

[env]
PORT = "{base:3000}"
API_PORT = "{base:8080}"
DATABASE_URL = "postgres://localhost/myapp_{name}"
NODE_ENV = "development"
```

### Config fields

**`path`** — worktree directory template (see [Worktree path template](#worktree-path-template)). Optional; defaults to `{parent}/{project}.{name}`.

**`[setup]`**
- `commands` — list of shell commands run sequentially in the new worktree directory after creation. If any command fails, the worktree is still created but a warning is printed. Each command has access to `W_ROOT` (base repo path) and `W_WORKTREE` (branch name), enabling copy operations like `cp "$W_ROOT/.env" .env`.

**`[env]`** — key-value pairs exported into the worktree subshell and into commands run via `w <name> <cmd>`.
- Values support template substitution:
  - `{base:N}` — compute `N + slot` for automatic port allocation
  - `{name}` — worktree / branch name
  - `{project}` — project directory name
- Literal values are exported as-is

## Worktree path template

The `path` setting controls where worktree directories are created. It supports interpolation of magic strings:

| Token | Expands to | Example |
|---|---|---|
| `{project}` | Name of the main repo directory | `myapp` |
| `{name}` | Worktree / branch name | `feat-x` |
| `{parent}` | Parent directory of the main repo | `/home/kevin/projects` |
| `{home}` | User's home directory | `/home/kevin` |

### Common patterns

**Sibling directories** (default):
```toml
path = "{parent}/{project}.{name}"
# ~/projects/myapp.feat-x
```

**Subdirectory of project**:
```toml
path = "{parent}/{project}.worktrees/{name}"
# ~/projects/myapp.worktrees/feat-x
```

**Dedicated global worktree directory**:
```toml
path = "{home}/worktrees/{project}/{name}"
# ~/worktrees/myapp/feat-x
```

The default (when no config exists) is `{parent}/{project}.{name}`.

Intermediate directories are created automatically. The template must include `{name}` — it is an error to omit it.

## Port allocation

Each worktree is assigned a **slot** — a small integer (0, 1, 2, ...) that is stable for the lifetime of the worktree. The main worktree is always slot 0. New worktrees get the lowest available slot.

Actual ports are computed as `base-port + slot`. With the config above:

| Worktree | Slot | PORT | API_PORT |
|---|---|---|---|
| main | 0 | 3000 | 8080 |
| feat-x | 1 | 3001 | 8081 |
| bugfix-y | 2 | 3002 | 8082 |

Slots are recorded in `~/.local/state/w/projects/<project-id>/slots.json`. When a worktree is removed, its slot is freed and can be reused.

Port values are injected into the subshell (or one-off command) as environment variables. There is no separate server management — users run their own dev servers inside the subshell, where `PORT` etc. are already set.

## Subshell environment

When `w <name>` spawns a subshell, the following environment variables are set:

| Variable | Value |
|---|---|
| `W_WORKTREE` | Worktree / branch name (e.g., `feat-x`) |
| `W_PROJECT` | Project directory name (e.g., `myapp`) |
| `W_ROOT` | Absolute path to the main repo root |
| *(from [env])* | Computed values from `.wtconfig.toml` |

`W_WORKTREE` also serves as the nesting guard — if it's already set, `w` refuses to spawn another subshell.

The shell is determined by `$SHELL` (falling back to `/bin/bash`). No rcfile customization is performed — the user's normal shell config loads as usual. Users can check `$W_WORKTREE` in their prompt if desired.

## Repo layout

```
w/
├── bin/w                         # Entry point (#!/usr/bin/env bash)
├── w.zsh                         # Zsh wrapper (sources bin/w)
├── w.bash                        # Bash wrapper + completions
├── completions/_w                # Zsh completions
└── t/                            # Tests (bats)
```

## Parsing

- **Git porcelain** — `git worktree list --porcelain` is parsed with `awk`. The format is line-oriented key-value pairs separated by blank lines — no grammar needed.
- **TOML config** — `.wtconfig.toml` is parsed with `yq` ([mikefarah/yq](https://github.com/mikefarah/yq), Go binary). Reads TOML natively: `yq -oy '.path' .wtconfig.toml`.
- **JSON state** — `slots.json` is read/written with `jq`.

## Dependencies

- `jq` — JSON read/write for state files
- `yq` — TOML parsing for .wtconfig.toml ([mikefarah/yq](https://github.com/mikefarah/yq))
- `bats-core` — test framework

## Runtime state

All state lives under `~/.local/state/w/`:

```
~/.local/state/w/
└── projects/
    └── <project-id>/
        └── slots.json                     # slot assignments: { "feat-x": 1, "bugfix-y": 2 }
```

`<project-id>` is derived from the repo root path (e.g., a sanitized absolute path or a hash). This keeps state per-project without collisions.
