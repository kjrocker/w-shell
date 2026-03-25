# Shell migration TODO

Rewrite w-raku from Raku to pure zsh/bash. Single-file `bin/w` with subcommands as separate shell functions. Dependencies: `jq`, `yq` (mikefarah/yq, Go binary). Test with `bats`.

## 1. Scaffold and core infrastructure

- [x] Create `bin/w` with: shebang, `set -euo pipefail`, state dir constant (`~/.local/state/w`), project discovery functions:
  - `_w_find_root` — prints `git rev-parse --show-toplevel`, dies if not in a repo
  - `_w_project_name root` — prints basename of repo root
  - `_w_parent_dir root` — prints dirname of repo root
  - `_w_find_main_worktree` — prints path of first worktree from `git worktree list`
- [x] Add `_w_cd_target path` — writes `path` to `$STATE_DIR/cd-target`, creating parent dirs via `mkdir -p`
- [x] Add color helpers respecting `NO_COLOR` env and `[ -t 1 ]` TTY check:
  - `_w_color code text` — wraps text in ANSI escape if color enabled, no-op otherwise
  - `_w_bold`, `_w_green`, `_w_red`, `_w_yellow`, `_w_cyan`, `_w_dim`, `_w_bold_green` — each calls `_w_color` with the appropriate code(s)
- [x] Add main router — `case "$1"` at bottom of file dispatching `ls|rm|exit|status|serve|stop|--version|--help` to `_w_cmd_*` functions, default case calls `_w_cmd_go`
- [x] Add `shell/w.zsh` — sourceable wrapper: calls `bin/w "$@"`, then if `$STATE_DIR/cd-target` exists, reads it into `cd`, deletes the file
- [x] Set up bats scaffolding: `t/helpers.bash` with `setup()` that creates a temp git repo (init + initial commit), `teardown()` that cleans up; first test file `t/01-core.bats` verifying `_w_find_root` returns the temp repo path
- [x] Tests pass, `bin/w --version` prints version string

## 2. Worktree list and porcelain parsing

- [x] `_w_parse_worktrees root` — runs `git -C "$root" worktree list --porcelain`, pipes through awk to emit one tab-delimited line per worktree: `path\tbranch\tsha\tbare|detached|normal`; branch has `refs/heads/` stripped
- [x] `_w_worktree_dirty path` — exits 0 if `git -C "$path" status --porcelain` produces output, 1 otherwise
- [x] `_w_worktree_dirty_count path` — prints number of lines from `git -C "$path" status --porcelain` (0 if clean)
- [x] `_w_worktree_ahead_behind path` — runs `git -C "$path" rev-list --left-right --count HEAD...@{upstream}`, prints `[ahead N, behind M]` (omitting zero components), empty string if no upstream
- [x] Tests: feed canned porcelain strings to the awk parser, assert field extraction; create temp repo with staged+unstaged changes, verify dirty/count/ahead-behind
- [x] Tests pass

## 3. Config parsing (TOML)

- [x] `_w_config_file root` — prints path to `$root/.wtconfig.toml`, returns 1 if missing
- [x] `_w_config_get root query` — runs `tomlq -r "$query" "$root/.wtconfig.toml"`, returns empty/1 if file missing; query is a jq path like `.path`, `.setup.commands[]`, `.server[].name`
- [x] `_w_resolve_path root name` — reads path template from config (or uses default `{parent}/{project}.{name}`), performs `${template//\{project\}/$project}` substitutions for `{project}`, `{name}`, `{parent}`, `{home}`, prints resolved absolute path
- [x] Tests: verify template expansion for sibling (`{parent}/{project}.{name}`), subdirectory (`{parent}/{project}.worktrees/{name}`), and global (`{home}/worktrees/{project}/{name}`) patterns; verify missing config returns default path
- [x] Tests pass

## 4. Slot allocation

- [x] `_w_project_id root` — prints repo root with `/` replaced by `_` and leading `_` stripped (filesystem-safe identifier)
- [x] `_w_state_dir root` — prints `$STATE_DIR/projects/$(_w_project_id "$root")`, runs `mkdir -p` on it
- [x] `_w_slot_assign name root` — reads `slots.json` via jq, if name already assigned prints existing slot, otherwise finds lowest int >= 1 not in `.[]` values, writes updated JSON, prints assigned slot
- [x] `_w_slot_free name root` — deletes key `name` from `slots.json` via `jq 'del(.[$name])'`, writes back
- [x] `_w_slot_get name root` — prints 0 if name is "main", otherwise prints slot from `slots.json` (empty if unassigned)
- [x] Tests: assign slots to a, b, c (expect 1,2,3), free b, assign d (expect reuses 2), get main returns 0
- [x] Tests pass

## 5. Subcommands: exit, version, navigate/create

- [x] `_w_cmd_version` — prints `w <VERSION>` to stdout
- [x] `_w_cmd_exit` — calls `_w_find_main_worktree`, writes result to cd-target via `_w_cd_target`
- [x] `_w_cmd_go name` — calls `_w_resolve_path` for name; if path exists and has `.git`, writes cd-target; otherwise calls `_w_create_worktree` + `_w_slot_assign` + `_w_run_setup`, then writes cd-target
- [x] `_w_create_worktree name path root` — runs `git -C "$root" worktree add -b "$name" "$path" main`; on "already exists" error retries with `git worktree add "$path" "$name"`, dies on other errors
- [x] `_w_run_setup path root` — reads `_w_config_get "$root" '.setup.commands[]'`, runs each line with `(cd "$path" && eval "$cmd")`, prints warning to stderr on non-zero exit, continues
- [x] `_w_cmd_run name cmd...` — resolves path, dies if worktree doesn't exist, runs `(cd "$path" && eval "$@")`, exits with command's exit code
- [x] Tests: exit writes main worktree to cd-target; go to existing worktree writes cd-target; go to new name creates worktree + slot; run echoes from correct directory
- [x] Tests pass

## 6. Subcommands: ls, status

- [ ] `_w_cmd_ls` — for each worktree from `_w_parse_worktrees`: prints `marker  name  status  [ahead/behind]  [server]` where marker is `*` (bold green) if cwd is inside that worktree, name is left-padded to 15 chars
- [ ] `_w_cmd_status` — prints bold project name + worktree count header, then per worktree same as ls, plus `_w_server_status_block` lines indented with `├`/`└` tree connectors
- [ ] `_w_format_status dirty count` — prints yellow `dirty  N files changed` or green `clean`
- [ ] `_w_server_status_line name root` — reads ports.json via jq, for each server where `/proc/$pid` exists collects `:port`, prints `● server running :3001,:8081` or empty
- [ ] `_w_server_status_block name root` — reads ports.json, prints one line per server: `name  :port  (pid N)` or `(stopped)`, with green/red coloring on status
- [ ] Tests: create temp ports.json with known PIDs (use `$$` for alive, 999999 for dead), verify status line/block output; verify ls column alignment with mocked worktree data
- [ ] Tests pass

## 7. Subcommands: serve, stop, rm

- [ ] `_w_ports_file root` — prints `$(_w_state_dir "$root")/ports.json`
- [ ] `_w_read_ports root` — cats ports.json if it exists, otherwise prints `{}`
- [ ] `_w_write_ports root json` — writes json string to ports.json
- [ ] `_w_cmd_serve [name] [--only=srv]` — for each `[[server]]` in config (filtered by `--only`): computes `port = base-port + slot`, starts `sh -c "$command"` in background with `$port_env=$port`, captures `$!` as PID, updates ports.json with slot/port/pid per server
- [ ] `_w_cmd_stop [name] [--only=srv]` — reads ports.json, for each server (filtered by `--only`): sends SIGTERM, sleeps 0.2s, sends SIGKILL if `/proc/$pid` still exists; removes entry from ports.json (removes whole worktree key if no servers remain)
- [ ] `_w_cmd_rm name [--force]` — calls `_w_cmd_stop "$name"`, then unless `--force` checks `git log --oneline main..$name` for unmerged commits (dies if any), runs `git worktree remove`, calls `_w_slot_free`
- [ ] Tests: serve starts a `sleep 600` background process, verify PID appears in ports.json and `/proc/$pid` exists; stop kills it, verify PID gone and ports.json cleaned; rm on branch with unmerged commit dies without `--force`, succeeds with `--force`
- [ ] Tests pass

## 8. Shell integration and completions

- [ ] Port `completions/_w` to work with `bin/w` — dynamic worktree name completion from `git worktree list`, subcommand completion, `--force`/`--only` flag completion
- [ ] Update `shell/w.zsh` wrapper to handle: no cd-target file, non-zero exit from `bin/w` (don't cd), clean up stale cd-target on wrapper source
- [ ] Add `shell/w.bash` — bash equivalent of the zsh wrapper + basic `complete -F` completions
- [ ] End-to-end test: source wrapper in a subshell, run `w <name>`, verify `$PWD` changed
- [ ] Tests pass

## 9. Cleanup

- [ ] Run full bats suite, fix any failures
- [ ] Side-by-side verify: run each subcommand in both Raku and shell versions, confirm matching output
- [ ] Update CLAUDE.md: replace raku build/run/test instructions with `bats t/`, note `jq`+`tomlq` deps
- [ ] Update SPEC.md: repo layout, remove Raku feature table, update dependency list
- [ ] Remove MIGRATION.md
- [ ] Remove Raku source: `lib/`, `META6.json`, `bin/w-raku` (preserved in git history)
