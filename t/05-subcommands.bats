#!/usr/bin/env bats

load helpers

# --- _w_cmd_version ---

@test "version prints version string" {
  run_w --version
  [[ "$status" -eq 0 ]]
  [[ "$output" == "w "* ]]
}

# --- _w_cmd_exit ---

@test "exit writes main worktree to cd-target" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  _w_cmd_exit
  [[ -f "$W_STATE_DIR/cd-target" ]]
  local target
  target="$(cat "$W_STATE_DIR/cd-target")"
  [[ "$target" == "$TEST_DIR" ]]
}

# --- _w_cmd_go ---

@test "go to new name creates worktree and slot" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  _w_cmd_go feat-test
  # cd-target should be set
  [[ -f "$W_STATE_DIR/cd-target" ]]
  local target
  target="$(cat "$W_STATE_DIR/cd-target")"
  # The worktree should exist at the resolved path
  [[ -d "$target" ]]
  [[ -e "$target/.git" ]]
  # Slot should be assigned
  local slot
  slot="$(_w_slot_get feat-test "$TEST_DIR")"
  [[ "$slot" == "1" ]]
}

@test "go to existing worktree writes cd-target" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  # Create worktree first
  _w_cmd_go feat-exist
  rm -f "$W_STATE_DIR/cd-target"
  # Go again — should just set cd-target
  _w_cmd_go feat-exist
  [[ -f "$W_STATE_DIR/cd-target" ]]
  local target
  target="$(cat "$W_STATE_DIR/cd-target")"
  [[ -d "$target" ]]
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
  # Create a .wtconfig.toml with setup commands
  cat > "$root/.wtconfig.toml" <<'TOML'
[setup]
commands = ["touch setup-marker"]
TOML
  # Create a worktree to run setup in
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
  # No .wtconfig.toml — should not fail
  _w_run_setup "$TEST_DIR" "$root"
}

# --- _w_cmd_run ---

@test "run executes command in worktree directory" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  # Create a worktree first
  _w_cmd_go run-test
  rm -f "$W_STATE_DIR/cd-target"
  local output
  output="$(_w_cmd_run run-test pwd)"
  local expected
  expected="$(_w_resolve_path "$(_w_find_root)" run-test)"
  [[ "$output" == "$expected" ]]
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
  # Create worktree first
  _w_cmd_go cmd-test
  rm -f "$W_STATE_DIR/cd-target"
  local output
  output="$(_w_cmd_go cmd-test pwd)"
  local expected
  expected="$(_w_resolve_path "$(_w_find_root)" cmd-test)"
  [[ "$output" == "$expected" ]]
  # Should NOT set cd-target
  [[ ! -f "$W_STATE_DIR/cd-target" ]]
}
