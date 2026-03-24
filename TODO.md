# TODO — Implementation Plan

## Current state

Phase 1 (core ops) is partially complete: `w <name>` creates worktrees and navigates, `w exit` works, other subcommands are stubs. No config parsing, setup orchestration, or server management exists yet.

---

## 1. Extend `w <name>` with configuration

### 1a. Config module (`lib/W/Config.rakumod`)

- [x] Add TOML parser dependency (`TOML::Thumb` or similar) to META6.json
- [x] Create `W::Config` module exporting:
  - `load-config(IO::Path $repo-root --> Hash)` — reads `.wtconfig.toml` from repo root, returns parsed hash (or empty hash if file absent)
- [x] Test: config file present returns expected structure
- [x] Test: missing config file returns empty hash

### 1b. Path template interpolation

- [x] Add `resolve-path-template(Str :$template, Str :$project, Str :$name, IO::Path :$parent, IO::Path :$home --> IO::Path)` to `W::Worktree`
  - Interpolates `{project}`, `{name}`, `{parent}`, `{home}` tokens
  - Dies if `{name}` is missing from template
- [x] Update `resolve-worktree-path` to accept an optional `:$template` parameter
  - When present, delegates to `resolve-path-template`
  - When absent, uses the current default (`{parent}/{project}.{name}`)
- [x] Test: each token interpolates correctly
- [x] Test: missing `{name}` in template is an error

### 1c. Wire config into `w <name>`

- [x] In `bin/w-raku`, load config via `load-config($root)` in the `MAIN(Str $name)` candidate
- [x] Pass the `path` template (if present in config) through to `resolve-worktree-path`
- [x] Verify end-to-end: config with custom `path` template produces correct worktree location

---

## 2. Setup command orchestration

### 2a. Setup runner (`lib/W/Setup.rakumod`)

- [x] Create `W::Setup` module exporting:
  - `run-setup(IO::Path :$worktree-path, :@commands)` — runs each command sequentially via shell in the worktree directory
  - Prints `Running setup: <cmd>` to stderr for each command
  - On command failure: prints warning to stderr, continues (worktree already created)
  - Returns a list of results (exit codes) for testability
- [x] Test: commands run in specified directory
- [x] Test: failing command prints warning but does not die

### 2b. Wire setup into `w <name>` on first create

- [x] After `create-worktree` succeeds, check config for `setup.commands`
- [x] If present and this is a new worktree (not an existing navigate), call `run-setup`
- [x] Verify end-to-end: creating a new worktree with setup commands in config runs them

---

## 3. Complete remaining Phase 1 subcommands

### 3a. `w ls` — list worktrees

- [x] Create `W::Git::Porcelain` grammar + actions to parse `git worktree list --porcelain` output
- [x] Implement `list-worktrees` in `W::Worktree` using the grammar
- [x] Wire into `MAIN('ls')` — format output as: name, clean/dirty, ahead/behind
- [x] Tests for grammar parsing various porcelain outputs

### 3b. `w rm <name>` — remove worktree

- [x] Implement `remove-worktree(Str :$name, IO::Path :$repo-root, Bool :$force)` in `W::Worktree`
  - Refuses if branch has unmerged commits (unless `--force`)
  - Runs `git worktree remove`
- [x] Wire into `MAIN('rm', ...)`
- [x] Tests for remove (normal case, unmerged refuse, force override)

### 3c. `w <name> <cmd...>` — run in worktree

- [x] Implement in `MAIN(Str $name, *@cmd)`: resolve worktree path, run command via shell in that directory
- [x] Pass through exit code

---

## 4. Slot allocation (`lib/W/Slots.rakumod`)

- [x] Create state directory structure: `~/.local/state/w/projects/<project-id>/`
- [x] Derive `project-id` from repo root path (sanitized or hashed)
- [x] Implement `assign-slot` / `free-slot` / `get-slot` operating on `slots.json`
  - Main worktree is always slot 0
  - New worktrees get lowest available slot
- [x] Assign slot on worktree creation, free on removal
- [x] Tests for slot assignment, reuse of freed slots

---

## 5. Server management

### 5a. Serve/stop (`lib/W/Server.rakumod`)

- [x] Implement `start-servers` using `Proc::Async`
  - Read `[[server]]` entries from config
  - Compute port as `base-port + slot`
  - Set env var (`port-env`) for each server process
  - Track PIDs in `ports.json`
- [x] Implement `stop-servers` — signal tracked PIDs, clean up state
- [x] Wire into `MAIN('serve', ...)` and `MAIN('stop', ...)`
- [x] `w rm` stops servers before removing

### 5b. Port exposure

- [x] Write `ports.json` on serve, update on stop
- [x] Include server status in `w ls` and `w status` output

---

## 6. Dashboard and polish

- [x] `w status` — full project dashboard (worktrees + servers + ports)
- [x] Formatted terminal output (colors, alignment)
- [x] Zsh completions (`completions/_w`)
