# w-raku: Raku Worktree Orchestrator

A Raku-powered git worktree manager. Adds setup orchestration, worktree management, dynamic naming, and dev server management with port allocation. Also a vehicle for exercising Raku features (grammars, multi-dispatch MAIN, concurrency).

## Shell integration

Raku can't `cd` the parent shell. The script writes a target path to `~/.local/state/w/cd-target`; a thin zsh wrapper reads it after exit:

```zsh
w() {
  w-raku "$@"
  local target="$HOME/.local/state/w/cd-target"
  if [[ -f "$target" ]]; then
    cd "$(cat "$target")"
    rm "$target"
  fi
}
```

All user-facing output goes to stdout/stderr normally from Raku.

## Subcommands

### `w <name>` — switch to worktree

Create worktree from `main` (if it doesn't exist) and cd into it. On first create, runs setup commands from `.wtconfig.toml` if present.

The worktree destination is determined by the `path` template in configuration (see [Worktree path template](#worktree-path-template)). Default: sibling directories.

```
$ w feat-x
Creating worktree feat-x...
Running setup: npm install
Running setup: cp .env.example .env
→ ~/projects/myapp.feat-x

$ w feat-x        # already exists, just cd
→ ~/projects/myapp.feat-x
```

### `w <name> <cmd...>` — run in worktree

Run a command in the worktree's directory without leaving the current shell. Useful for one-off operations.

```
$ w feat-x npm test
# runs npm test in ~/projects/myapp.feat-x
```

### `w ls` — list worktrees

List all worktrees for the current project with git status summary. Project-scoped (current repo only).

```
$ w ls
  main        clean   [ahead 2]
* feat-x      dirty   3 files changed
  bugfix-y    clean
  experiment  clean   ● server running :3001,:8081
```

Columns: name, clean/dirty, ahead/behind, server status if applicable.

### `w rm <name>` — remove worktree

Remove worktree directory. Stops any running servers first. Refuses to remove if the branch has unmerged commits (override with `--force`).

```
$ w rm feat-x
Stopping server frontend (pid 12345)...
Stopping server backend (pid 12346)...
Removing worktree feat-x...
Done.
```

### `w exit` — navigate to project root

Cd back to the main worktree / bare repo root. Useful when you're inside a worktree and want to return.

### `w status` — project dashboard

Show all worktrees for the current project with full status: git state, running servers, allocated ports.

```
$ w status
myapp — 3 worktrees

  main        clean   [ahead 2]
  feat-x      dirty   3 files changed
              ├ frontend  :3001  (pid 12345)
              └ backend   :8081  (pid 12346)
  bugfix-y    clean
```

### `w serve [name]` — start dev servers

Start all servers defined in `.wtconfig.toml` for the named worktree (default: current). Each server gets its port injected via the configured env var.

```
$ w serve feat-x
Starting frontend (npm run dev) on :3001...
Starting backend (cargo run) on :8081...

$ w serve feat-x --only frontend
Starting frontend (npm run dev) on :3001...
```

### `w stop [name]` — stop dev servers

Stop all running servers for the named worktree (default: current).

```
$ w stop feat-x
Stopping frontend (pid 12345)...
Stopping backend (pid 12346)...
```

## Per-repo config: `.wtconfig.toml`

Optional. Lives in the main worktree / repo root. Without it, `w` does plain worktree create/navigate/remove with no setup or server features.

```toml
path = "{parent}/{project}.worktrees/{name}"   # override default layout

[setup]
commands = ["npm install", "cp .env.example .env"]

[[server]]
name = "frontend"
command = "npm run dev"
port-env = "PORT"
base-port = 3000

[[server]]
name = "backend"
command = "cargo run"
port-env = "API_PORT"
base-port = 8080
```

### Config fields

**`path`** — worktree directory template (see [Worktree path template](#worktree-path-template)). Optional; defaults to `{parent}/{project}.{name}`.

**`[setup]`**
- `commands` — list of shell commands run sequentially in the new worktree directory after creation. If any command fails, the worktree is still created but a warning is printed.

**`[[server]]`** (array of tables — one per service)
- `name` — identifier for this service (used in `--only`, dashboard, logs)
- `command` — shell command to start the service
- `port-env` — environment variable name to pass the assigned port
- `base-port` — starting port number; actual port = `base-port + slot`

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

| Worktree | Slot | frontend | backend |
|---|---|---|---|
| main | 0 | 3000 | 8080 |
| feat-x | 1 | 3001 | 8081 |
| bugfix-y | 2 | 3002 | 8082 |

Slots are recorded in `~/.local/state/w/projects/<project-id>/slots.json`. When a worktree is removed, its slot is freed and can be reused.

### Port exposure

Ports are passed to server commands via the env var specified in `port-env`. Additionally, the full port map for all worktrees is written to `~/.local/state/w/projects/<project-id>/ports.json` so external tooling can discover them:

```json
{
  "feat-x": {
    "slot": 1,
    "servers": {
      "frontend": { "port": 3001, "pid": 12345 },
      "backend": { "port": 8081, "pid": 12346 }
    }
  }
}
```

## Repo layout

```
w-raku/
├── bin/w-raku                    # Entry point (#!/usr/bin/env raku)
├── lib/W/
│   ├── Worktree.rakumod          # Worktree operations (create, remove, list, resolve path)
│   ├── Project.rakumod           # Project discovery (find repo root, read config)
│   ├── Server.rakumod            # Server process management (Proc::Async)
│   ├── Config.rakumod            # .wtconfig.toml + global config parsing/merging
│   ├── Slots.rakumod             # Port slot allocation + persistence
│   └── Git/Porcelain.rakumod     # Grammar for git worktree list --porcelain
├── completions/_w                # Zsh completions
├── t/                            # Tests
└── META6.json
```

## Raku features exercised

| Feature | Where |
|---|---|
| Multi-dispatch `MAIN` | Subcommand routing |
| Grammars + Actions | Parsing `git worktree list --porcelain` |
| Functional modules (exported subs) | All `lib/W/` modules |
| `Proc::Async` | Server process management |
| Module system | `lib/` structure with `META6.json` |
| TOML module | Config parsing |

## Implementation phases

1. **Core ops** — scaffold repo, worktree create/navigate/list/remove/exit, grammar for `git worktree list --porcelain`, zsh wrapper + completions.
2. **Config + setup** — `.wtconfig.toml` + global config parsing, path template interpolation, run setup commands on worktree creation, slot allocation + persistence.
3. **Server management** — `serve`/`stop` subcommands, `Proc::Async`, PID tracking, port exposure to env vars and state files.
4. **Dashboard + polish** — `w dash`, `w ls` server status, formatted terminal output.

## Dependencies

- Raku v2026.01+ (rakubrew)
- Phase 1: no external modules
- Phase 2+: TOML parser (`zef install TOML::Thumb` or similar)

## Runtime state

All state lives under `~/.local/state/w/`:

```
~/.local/state/w/
├── cd-target                              # ephemeral, read+deleted by zsh wrapper
└── projects/
    └── <project-id>/
        ├── slots.json                     # slot assignments: { "feat-x": 1, "bugfix-y": 2 }
        └── ports.json                     # running servers: port + pid per worktree
```

`<project-id>` is derived from the repo root path (e.g., a sanitized absolute path or a hash). This keeps state per-project without collisions.
