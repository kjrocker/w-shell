# w-shell: Detailed Issue Analysis

## 1. Crash outside a git repository

**Symptom:** Running `w` (no arguments) outside a git repository crashes instead of showing the help message. Same for `w --help` and `w --version`.

**Root cause:** `set -euo pipefail` at the top of `bin/w`. Even though the router (`main()`) dispatches `--help`, `--version`, and `""` to handlers that don't call `_w_find_root()`, the problem is `w` with **no arguments when invoked via the shell wrapper**.

The wrapper function in `w.bash` calls `"$W_ROOT/bin/w" "$@"` — if `bin/w` exits non-zero for any reason, the wrapper returns that error code. But the actual crash path is more subtle: `_w_cmd_help` and `_w_cmd_version` don't touch git at all, so those cases should work fine in the router.

The likely crash path is:
- `w` (no args) through the **wrapper** — the wrapper runs `git worktree list --porcelain` during tab-completion registration, or
- `w init` — calls `_w_find_main_worktree()` which runs `git worktree list` and `exit 1` on failure
- Any typo or unrecognized argument falls through to `_w_cmd_go`, which immediately calls `_w_find_root()` and exits

**Fix:** Guard `_w_find_root()` calls so that only subcommands that genuinely need a repo call it. For `--help`, `--version`, and `""`, the router already dispatches correctly. The remaining issue is likely that running bare `w` triggers something in the shell wrapper (e.g., completion setup) or that the actual user invocation was `w` followed by something that fell to the `*)` case. Worth adding an explicit guard at the top of `main()`:

```bash
main() {
  local cmd="${1:-}"
  # These work anywhere — no repo required
  case "$cmd" in
    --version) _w_cmd_version; return ;;
    --help|"") _w_cmd_help; return ;;
  esac
  # Everything below requires a git repo
  ...
}
```

`init` also needs attention — `_w_find_main_worktree()` has its own `exit 1` path. It should produce a friendlier error.

---

## 2. Skeleton .wtconfig.toml is too minimal

**Current output of `w init`:**

```toml
# path = "{parent}/{project}.{name}"

[setup]
commands = []
```

This doesn't mention `[[server]]` at all. A user seeing this skeleton has no way to discover that server management exists without reading the spec.

**What should be shown:** The skeleton should include commented-out examples of every config section so the full capability set is visible:

```toml
# Worktree directory layout (default: sibling directories)
# path = "{parent}/{project}.{name}"
#
# Available tokens: {project}, {name}, {parent}, {home}
# Examples:
#   "{parent}/{project}.worktrees/{name}"   — subdirectory of project
#   "{home}/worktrees/{project}/{name}"     — global worktree directory

[setup]
commands = []
# commands = ["npm install", "cp .env.example .env"]

# [[server]]
# name = "dev"
# command = "npm run dev"
# port-env = "PORT"
# base-port = 3000
#
# [[server]]
# name = "api"
# command = "cargo run"
# port-env = "API_PORT"
# base-port = 8080
```

This is a straightforward change to the heredoc in `_w_cmd_init()` (line 716 of `bin/w`).

---

## 3. Port handling — one env var per command is limiting

**Current design:** Each `[[server]]` entry has a single `port-env` field. The server command gets exactly one env var set to its computed port. The actual port is `base-port + slot`.

**Problem scenario:** A command that starts both a frontend and backend server (e.g., a monorepo `npm run dev` that spawns two processes) can't receive two different port assignments through a single env var.

**ISSUES.md suggestion:** Template substitution in the command string itself, e.g.:

```toml
[[server]]
name = "all"
command = "PORT={port} API_PORT={port+1} npm run dev"
base-port = 3000
```

**Considerations:**
- The current `base-port + slot` scheme already provides a stable, unique number per worktree per server. The problem is only when one *command* needs multiple ports.
- Adding template variables like `{port}` to the command string would require a new parser and blurs the line between "command" and "configuration."
- An alternative: allow multiple `port-env` values mapping to different offsets from the base. For example:

```toml
[[server]]
name = "all"
command = "npm run dev"
base-port = 3000
ports = [
  { env = "PORT", offset = 0 },
  { env = "API_PORT", offset = 100 }
]
```

This keeps the declaration explicit and avoids command-string templating, but adds complexity to the config schema.

**If the subshell idea (issue 6) is adopted, this problem largely disappears.** The subshell can export as many env vars as needed from the config, and users run their own commands inside it. No per-command port injection is needed.

---

## 4. `w serve` output is invisible

**Current behavior (line 586):**

```bash
env "${port_env}=${port}" sh -c "exec $srv_command" </dev/null >/dev/null 2>&1 &
```

Both stdout and stderr of the server process are redirected to `/dev/null`. The user sees only the "Starting frontend..." message, then nothing. If the server fails to start (wrong command, missing dependency, port already in use), there's no feedback. And because it's backgrounded, `w serve` returns immediately with exit 0 regardless.

**Why it was done this way:** The process must be fully detached so it survives after `bin/w` exits. Redirecting to `/dev/null` prevents output from leaking into the shell wrapper's cd-target mechanism (stdout is reserved for that).

**Possible fixes within the current architecture:**
1. **Log to a file.** Redirect to `$STATE_DIR/projects/<id>/logs/<server>.log` instead of `/dev/null`. Then `w status` or a new `w logs` command can tail it.
2. **Foreground mode.** A `--follow` flag that doesn't background the process, so the user sees output directly. This only works for one server at a time and blocks the shell.
3. **Brief health check.** After starting, sleep ~1 second and check if `/proc/$pid` still exists. If the process died immediately, report the failure.

**If the subshell idea is adopted, this problem disappears entirely.** Users would run their dev commands in the foreground within the subshell and see all output directly, just as they would in a normal terminal.

---

## 5. `w stop` doesn't reliably kill processes

**Current behavior (lines 632-640):**

```bash
if [[ -n "$srv_pid" && -d "/proc/$srv_pid" ]]; then
  kill "$srv_pid" 2>/dev/null || true
  sleep 0.3
  if [[ -d "/proc/$srv_pid" ]]; then
    kill -9 "$srv_pid" 2>/dev/null || true
    sleep 0.1
  fi
fi
```

This sends SIGTERM to the PID, waits 300ms, then SIGKILL if still alive.

**Why it doesn't work:** The PID recorded is the `sh -c "exec $command"` process. If `exec` succeeded, this PID *is* the server process and killing it should work. But many dev servers (webpack-dev-server, next dev, cargo run) spawn child processes — watchers, compilers, the actual HTTP listener. Killing the parent doesn't necessarily kill the children, especially if they've become session leaders or process group leaders.

**Specific failure modes:**
- **npm/node servers:** `npm run dev` spawns a child node process. `exec` replaces `sh`, but `npm` itself spawns a grandchild. Killing the `npm` PID sends SIGTERM to npm, which may or may not forward it.
- **Process groups:** The children may be in the same process group but not necessarily. Depends on the tool.
- **Orphaned listeners:** The child survives, keeps the port bound. `w stop` reports success (parent PID gone), but the page still loads.

**Fixes:**
1. **Kill the process group.** Use `kill -- -$pid` (negative PID) to send the signal to the entire process group rooted at that PID. This requires that the server was started as a process group leader, which can be arranged with `setsid`:

   ```bash
   setsid env "${port_env}=${port}" sh -c "exec $srv_command" </dev/null >/dev/null 2>&1 &
   ```

   Then stop becomes:
   ```bash
   kill -- "-$srv_pid" 2>/dev/null || true
   ```

2. **Port-based kill as fallback.** If the PID is gone but the port is still bound, use `lsof -ti :$port` or `ss -tlnp` to find the actual listener and kill it.

3. **Record the process group ID** in ports.json alongside the PID, for more reliable cleanup.

**If the subshell idea is adopted, this problem disappears.** Processes started in the foreground within a subshell are children of that shell. Exiting the subshell (or pressing Ctrl-C) delivers signals through normal shell job control, which handles process trees correctly.

---

## 6. The subshell idea

> Perhaps `w <name>` should open a subshell at the worktree directory that has a full alternative environment configuration loaded. Then start/stop/serve wouldn't be necessary, and wtconfig.toml can specify multiple env vars. This is inspired by chezmoi, where `chezmoi cd` doesn't technically cd, it starts a subshell.

### What it means

Instead of `w feat-x` writing a cd-target and the wrapper doing `cd`, it would spawn a new interactive shell with:
- Working directory set to the worktree path
- Environment variables loaded from `.wtconfig.toml`
- Port assignments computed and exported
- A modified prompt indicating you're "inside" the worktree
- Exit returns you to where you were

### What it simplifies

| Current complexity | With subshell |
|---|---|
| cd-target file + shell wrapper reads it | Not needed — subshell starts in the right directory |
| `w serve` backgrounds processes, redirects to /dev/null | User runs their own commands in the foreground, sees all output |
| `w stop` needs to track PIDs, kill process trees | Exit the subshell (or Ctrl-C) — normal signal delivery |
| ports.json tracking running servers | Port vars are in the environment, no tracking file needed |
| Single env var per command limitation | Config exports arbitrary env vars; user commands use them freely |
| Invisible server output | Everything is in the foreground, visible |
| Unreliable process termination | Shell job control handles it |

In short, it eliminates the entire `serve`/`stop`/ports.json/PID-tracking subsystem and replaces it with the shell's built-in job control and environment.

### What the config would look like

```toml
path = "{parent}/{project}.{name}"

[setup]
commands = ["npm install", "cp .env.example .env"]

[env]
PORT = "{base:3000}"
API_PORT = "{base:8080}"
DATABASE_URL = "postgres://localhost/myapp_{name}"
NODE_ENV = "development"
```

The `{base:N}` syntax means "N + slot," giving each worktree a unique port. Static values are exported as-is. The `{name}` token expands to the worktree name, useful for per-worktree database names.

### What the implementation requires

**1. Spawning the subshell**

Replace the cd-target mechanism in `_w_cmd_go` with:

```bash
_w_cmd_go() {
  local name="$1"
  local root="$(_w_find_root)"
  local wt_path="$(_w_resolve_path "$root" "$name")"

  # Create worktree if needed (same as today)
  if [[ ! -d "$wt_path/.git" ]]; then
    _w_create_worktree "$name" "$wt_path" "$root"
    _w_slot_assign "$name" "$root"
    _w_run_setup "$wt_path" "$root"
  fi

  # Build environment
  local slot
  slot="$(_w_slot_get "$name" "$root")"
  local env_vars=()
  # ... read [env] section from config, compute ports, build env_vars array

  # Spawn subshell
  env "${env_vars[@]}" \
    W_WORKTREE="$name" \
    W_PROJECT="$(_w_project_name "$root")" \
    bash --rcfile <(_w_generate_rcfile) -i
}
```

**2. The rcfile**

The subshell needs to source the user's normal shell config *plus* w's customizations:

```bash
_w_generate_rcfile() {
  cat <<'RCFILE'
# Source user's normal config
[[ -f ~/.bashrc ]] && source ~/.bashrc

# Customize prompt to show worktree
PS1="(w:$W_WORKTREE) $PS1"

# Override 'exit' or add 'deactivate' alias if desired
RCFILE
}
```

For zsh, it's trickier — zsh's startup file chain (`.zshenv`, `.zshrc`) is less amenable to `--rcfile`. Options:
- Set `ZDOTDIR` to a temp directory containing a `.zshrc` that sources the real one plus w's additions
- Use `zsh -c 'source ~/.zshrc; PS1="..."; exec zsh -i'` (hacky)

**3. Detecting "already inside a subshell"**

`W_WORKTREE` env var serves double duty: it marks the subshell and identifies which worktree. `w feat-x` while already in a subshell should either:
- Warn and refuse ("already in worktree main, exit first")
- Exit the current subshell and start a new one (complex, probably not worth it)
- Nest subshells (simple but messy — user must exit multiple times)

Refusing with a message is the safest approach.

**4. What stays, what goes**

| Keep | Remove | Modify |
|---|---|---|
| `w ls` — list worktrees | `w serve` — no longer needed | `w <name>` — spawn subshell instead of cd |
| `w status` — still useful for overview | `w stop` — no longer needed | `w exit` — just print "type exit" if in subshell, otherwise cd to main |
| `w rm` — remove worktrees | `ports.json` — no longer needed | `.wtconfig.toml` — `[[server]]` replaced by `[env]` |
| `w init` — create config | cd-target file — no longer needed | shell wrapper — simplified or removed |
| slots.json — still needed for port computation | PID tracking | |

**5. The shell wrapper**

The wrapper becomes much simpler or unnecessary. The subshell approach doesn't need the wrapper to cd — the subshell starts in the right place. The wrapper might still be useful for:
- Completions (still need to register those)
- Preventing `w` from being a subprocess that can't affect the parent (but the subshell *is* the point now)

Actually, the wrapper is still needed to prevent running `bin/w` directly (which would spawn the subshell as a child of `bin/w`, adding an unnecessary process). The wrapper should call `exec` to replace itself:

```bash
w() {
  # For subcommands that don't need a subshell, run directly
  case "${1:-}" in
    ls|status|rm|init|--help|--version|"")
      "$W_ROOT/bin/w" "$@"
      return $?
      ;;
  esac
  # For 'go' (default), the subshell approach means bin/w
  # starts an interactive shell — just run it directly
  "$W_ROOT/bin/w" "$@"
}
```

**6. Port computation still works**

The slot system remains unchanged. The difference is only in how port values reach the process:
- **Before:** `w serve` computes the port and injects it via `env PORT=3001 command`
- **After:** `w feat-x` computes the port and exports it: the subshell has `PORT=3001` in its environment, and the user runs their command normally

### Migration path

This is a significant redesign, but it can be done incrementally:

1. **Add `[env]` config section** and the subshell spawn to `_w_cmd_go`, behind a flag or config toggle.
2. **Keep `serve`/`stop`** working for users who prefer background mode.
3. **Once subshell is stable**, deprecate `serve`/`stop` and simplify.

Or, given that this is v0.0.1 with no external users, just replace the architecture directly.

### Open questions

- **Zsh support.** The `--rcfile` approach works for bash. Zsh needs a `ZDOTDIR` workaround. Fish needs something else entirely. Supporting all three adds real complexity.
- **Multiple terminals.** With the current `serve` model, you start servers once and they run across shell sessions. With subshells, each terminal is independent. If you want servers running "in the background," you'd use tmux/screen or `&` within the subshell — which is exactly how people normally work, but loses the "managed" feel.
- **`w status` showing running servers.** Without PID tracking, `w status` can't show which ports are active. It could show which ports *would be* allocated, or use `lsof`/`ss` to check if ports are actually bound.
- **`w <name> <cmd>`** (run a command in a worktree without entering it). This currently doesn't need a subshell — it just runs the command in a subprocess. It could still export the env vars without spawning interactive mode. This use case should be preserved.
