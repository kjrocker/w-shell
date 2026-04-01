#!/usr/bin/env bats

load helpers

# --- _w_format_status ---

@test "format_status shows green clean for non-dirty" {
  source "$W_BIN" --source-only
  local result
  result="$(_w_format_status false 0)"
  [[ "$result" == "clean" ]]
}

@test "format_status shows dirty with file count" {
  source "$W_BIN" --source-only
  local result
  result="$(_w_format_status true 3)"
  [[ "$result" == *"dirty"* ]]
  [[ "$result" == *"3 files changed"* ]]
}

@test "format_status shows singular file for count 1" {
  source "$W_BIN" --source-only
  local result
  result="$(_w_format_status true 1)"
  [[ "$result" == *"1 file changed"* ]]
}

# --- _w_env_status_line ---

@test "env_status_line returns empty when no env config" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local root
  root="$(_w_find_root)"
  local result
  result="$(_w_env_status_line "main" "$root")"
  [[ -z "$result" ]]
}

@test "env_status_line shows computed port" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local root
  root="$(_w_find_root)"
  cat > "$TEST_DIR/.wtconfig.toml" <<'TOML'
[env]
PORT = "{base:3000}"
TOML
  _w_slot_assign "feat-x" "$root" > /dev/null
  local result
  result="$(_w_env_status_line "feat-x" "$root")"
  [[ "$result" == *"PORT=3001"* ]]
}

@test "env_status_line shows slot 0 for main" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  cat > "$TEST_DIR/.wtconfig.toml" <<'TOML'
[env]
PORT = "{base:3000}"
TOML
  local result
  result="$(_w_env_status_line "main" "$TEST_DIR")"
  [[ "$result" == *"PORT=3000"* ]]
}

# --- _w_cmd_ls ---

@test "ls lists worktrees with marker for current" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local result
  result="$(_w_cmd_ls)"
  [[ "$result" == *"main"* ]]
  [[ "$result" == *"*"* ]]
  [[ "$result" == *"clean"* ]]
}

@test "ls labels the main worktree" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local result
  result="$(_w_cmd_ls)"
  [[ "$result" == *"(main)"* ]]
}

@test "ls shows dirty status for modified worktree" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  echo "change" > "$TEST_DIR/dirty-file.txt"
  local result
  result="$(_w_cmd_ls)"
  [[ "$result" == *"dirty"* ]]
  [[ "$result" == *"1 file changed"* ]]
}

@test "ls shows multiple worktrees" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  # Create worktree directly
  local root path
  root="$(_w_find_root)"
  path="$(_w_resolve_path "$root" feat-ls-test)"
  _w_create_worktree feat-ls-test "$path" "$root"
  _w_slot_assign feat-ls-test "$root" > /dev/null
  cd "$TEST_DIR"
  local result
  result="$(_w_cmd_ls)"
  [[ "$result" == *"main"* ]]
  [[ "$result" == *"feat-ls-test"* ]]
}

@test "ls shows env status when configured" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  cat > "$TEST_DIR/.wtconfig.toml" <<'TOML'
[env]
PORT = "{base:3000}"
TOML
  local result
  result="$(_w_cmd_ls)"
  [[ "$result" == *"PORT=3000"* ]]
}

@test "ls works from inside a worktree subshell" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local root path
  root="$(_w_find_root)"
  path="$(_w_resolve_path "$root" feat-wt-ls)"
  _w_create_worktree feat-wt-ls "$path" "$root"
  _w_slot_assign feat-wt-ls "$root" > /dev/null
  cd "$path"
  local result
  result="$(_w_cmd_ls)"
  [[ "$result" == *"main"* ]]
  [[ "$result" == *"feat-wt-ls"* ]]
}

# --- _w_cmd_status ---

@test "status shows project header with worktree count" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local result
  result="$(_w_cmd_status)"
  local proj
  proj="$(_w_project_name "$(_w_find_root)")"
  [[ "$result" == *"$proj"* ]]
  [[ "$result" == *"worktree"* ]]
}

@test "status shows worktree details" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local result
  result="$(_w_cmd_status)"
  [[ "$result" == *"main"* ]]
  [[ "$result" == *"clean"* ]]
}

@test "status labels the main worktree" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local result
  result="$(_w_cmd_status)"
  [[ "$result" == *"(main)"* ]]
}

@test "status works from inside a worktree subshell" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local root path
  root="$(_w_find_root)"
  path="$(_w_resolve_path "$root" feat-wt-status)"
  _w_create_worktree feat-wt-status "$path" "$root"
  _w_slot_assign feat-wt-status "$root" > /dev/null
  cd "$path"
  local result
  result="$(_w_cmd_status)"
  [[ "$result" == *"main"* ]]
  [[ "$result" == *"feat-wt-status"* ]]
}

@test "status shows worktree paths" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local result
  result="$(_w_cmd_status)"
  [[ "$result" == *"$TEST_DIR"* ]]
}

@test "status shows env vars when configured" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  cat > "$TEST_DIR/.wtconfig.toml" <<'TOML'
[env]
PORT = "{base:3000}"
TOML
  local result
  result="$(_w_cmd_status)"
  [[ "$result" == *"PORT=3000"* ]]
}
