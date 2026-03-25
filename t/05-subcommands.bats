#!/usr/bin/env bats

load helpers

# --- _w_cmd_version ---

@test "version prints version string" {
  run_w --version
  [[ "$status" -eq 0 ]]
  [[ "$output" == "w "* ]]
}

# --- _w_cmd_init ---

@test "init creates .wtconfig.toml in repo root" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  _w_cmd_init
  [[ -f "$TEST_DIR/.wtconfig.toml" ]]
  grep -q '\[setup\]' "$TEST_DIR/.wtconfig.toml"
}

@test "init fails if .wtconfig.toml already exists" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  touch "$TEST_DIR/.wtconfig.toml"
  run _w_cmd_init
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"already exists"* ]]
}

@test "init from subdirectory writes to repo root" {
  source "$W_BIN" --source-only
  mkdir -p "$TEST_DIR/sub/dir"
  cd "$TEST_DIR/sub/dir"
  _w_cmd_init
  [[ -f "$TEST_DIR/.wtconfig.toml" ]]
  [[ ! -f "$TEST_DIR/sub/dir/.wtconfig.toml" ]]
}

@test "init skeleton includes env section comment" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  _w_cmd_init
  grep -q '\[env\]' "$TEST_DIR/.wtconfig.toml"
  grep -q 'base:3000' "$TEST_DIR/.wtconfig.toml"
}

# --- _w_cmd_exit ---

@test "exit prints hint when in subshell" {
  run bash -c "export W_STATE_DIR='$W_STATE_DIR' W_WORKTREE=feat-x; source '$W_BIN' --source-only 2>/dev/null; _w_cmd_exit"
  [[ "$output" == *"exit"* ]]
  [[ "$output" == *"feat-x"* ]]
}

@test "exit prints not-in-subshell when outside" {
  run bash -c "export W_STATE_DIR='$W_STATE_DIR'; unset W_WORKTREE; source '$W_BIN' --source-only 2>/dev/null; _w_cmd_exit"
  [[ "$output" == *"Not in a w subshell"* ]]
}

# --- _w_cmd_go ---

@test "go to new name creates worktree and slot" {
  cd "$TEST_DIR"
  # Use /usr/bin/env as SHELL so the exec prints env and exits
  run bash -c "
    export W_STATE_DIR='$W_STATE_DIR' SHELL=/usr/bin/env NO_COLOR=1
    source '$W_BIN' --source-only 2>/dev/null
    cd '$TEST_DIR'
    _w_cmd_go feat-test
  "
  [[ "$status" -eq 0 ]]
  # The worktree should exist
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local path
  path="$(_w_resolve_path "$TEST_DIR" feat-test)"
  [[ -d "$path" ]]
  [[ -e "$path/.git" ]]
  # Slot should be assigned
  local slot
  slot="$(_w_slot_get feat-test "$TEST_DIR")"
  [[ "$slot" == "1" ]]
}

@test "go spawns subshell with W_WORKTREE set" {
  cd "$TEST_DIR"
  local output
  output="$(
    export W_STATE_DIR="$W_STATE_DIR" SHELL=/usr/bin/env NO_COLOR=1
    source "$W_BIN" --source-only 2>/dev/null
    cd "$TEST_DIR"
    _w_cmd_go feat-env 2>/dev/null
  )"
  [[ "$output" == *"W_WORKTREE=feat-env"* ]]
  [[ "$output" == *"W_PROJECT="* ]]
  [[ "$output" == *"W_ROOT="* ]]
}

@test "go spawns subshell with computed env vars" {
  cd "$TEST_DIR"
  cat > "$TEST_DIR/.wtconfig.toml" <<'TOML'
[env]
PORT = "{base:3000}"
TOML
  local output
  output="$(
    export W_STATE_DIR="$W_STATE_DIR" SHELL=/usr/bin/env NO_COLOR=1
    source "$W_BIN" --source-only 2>/dev/null
    cd "$TEST_DIR"
    _w_cmd_go feat-port 2>/dev/null
  )"
  # slot 1 + base 3000 = 3001
  [[ "$output" == *"PORT=3001"* ]]
}

@test "go refuses when already in subshell" {
  run bash -c "
    export W_STATE_DIR='$W_STATE_DIR' W_WORKTREE=existing SHELL=/usr/bin/env NO_COLOR=1
    source '$W_BIN' --source-only 2>/dev/null
    cd '$TEST_DIR'
    _w_cmd_go another
  "
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"Already in worktree"* ]]
}

# --- _w_create_worktree ---

@test "create_worktree creates a worktree directory" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local root path
  root="$(_w_find_root)"
  local parent project
  parent="$(_w_parent_dir "$root")"
  project="$(_w_project_name "$root")"
  path="$parent/$project.test-branch"
  _w_create_worktree test-branch "$path" "$root"
  [[ -d "$path" ]]
  [[ -e "$path/.git" ]]
}

@test "create_worktree retries without -b if branch exists" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local root path
  root="$(_w_find_root)"
  # Create branch first
  git -C "$root" branch existing-branch main
  local parent project
  parent="$(_w_parent_dir "$root")"
  project="$(_w_project_name "$root")"
  path="$parent/$project.existing-branch"
  _w_create_worktree existing-branch "$path" "$root"
  [[ -d "$path" ]]
  [[ -e "$path/.git" ]]
}

# --- _w_run_setup ---

@test "run_setup runs commands from config" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local root
  root="$(_w_find_root)"
  cat > "$root/.wtconfig.toml" <<'TOML'
[setup]
commands = ["touch setup-marker"]
TOML
  local parent project path
  parent="$(_w_parent_dir "$root")"
  project="$(_w_project_name "$root")"
  path="$parent/$project.setup-test"
  _w_create_worktree setup-test "$path" "$root"
  _w_run_setup "$path" "$root"
  [[ -f "$path/setup-marker" ]]
}

@test "run_setup does nothing without config" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local root
  root="$(_w_find_root)"
  _w_run_setup "$TEST_DIR" "$root"
}

# --- _w_cmd_run ---

@test "run executes command in worktree directory" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  # Create a worktree directly (bypass _w_cmd_go which execs)
  local root path
  root="$(_w_find_root)"
  path="$(_w_resolve_path "$root" run-test)"
  _w_create_worktree run-test "$path" "$root"
  _w_slot_assign run-test "$root" > /dev/null
  local output
  output="$(_w_cmd_run run-test pwd)"
  [[ "$output" == "$path" ]]
}

@test "run passes env vars to command" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  cat > "$TEST_DIR/.wtconfig.toml" <<'TOML'
[env]
PORT = "{base:3000}"
TOML
  local root path
  root="$(_w_find_root)"
  path="$(_w_resolve_path "$root" env-run)"
  _w_create_worktree env-run "$path" "$root"
  _w_slot_assign env-run "$root" > /dev/null
  local output
  output="$(_w_cmd_run env-run 'echo $PORT')"
  [[ "$output" == "3001" ]]
}

@test "run sets W_WORKTREE" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local root path
  root="$(_w_find_root)"
  path="$(_w_resolve_path "$root" meta-run)"
  _w_create_worktree meta-run "$path" "$root"
  _w_slot_assign meta-run "$root" > /dev/null
  local output
  output="$(_w_cmd_run meta-run 'echo $W_WORKTREE')"
  [[ "$output" == "meta-run" ]]
}

@test "run dies if worktree does not exist" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  run _w_cmd_run nonexistent echo hello
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"does not exist"* ]]
}

# --- _w_cmd_go with command (run mode) ---

@test "go with extra args runs command in worktree" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  # Create worktree directly
  local root path
  root="$(_w_find_root)"
  path="$(_w_resolve_path "$root" cmd-test)"
  _w_create_worktree cmd-test "$path" "$root"
  _w_slot_assign cmd-test "$root" > /dev/null
  local output
  output="$(_w_cmd_go cmd-test pwd)"
  [[ "$output" == "$path" ]]
}
