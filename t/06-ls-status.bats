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

# --- _w_server_status_line ---

@test "server_status_line returns empty for no ports entry" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local root
  root="$(_w_find_root)"
  local result
  result="$(_w_server_status_line "main" "$root")"
  [[ -z "$result" ]]
}

@test "server_status_line shows live server ports" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local root
  root="$(_w_find_root)"
  # Write ports.json with current PID (known alive)
  local state_dir
  state_dir="$(_w_state_dir "$root")"
  cat > "$state_dir/ports.json" <<EOF
{
  "feat-x": {
    "slot": 1,
    "servers": {
      "frontend": { "port": 3001, "pid": $$ }
    }
  }
}
EOF
  local result
  result="$(_w_server_status_line "feat-x" "$root")"
  [[ "$result" == *":3001"* ]]
  [[ "$result" == *"server running"* ]]
}

@test "server_status_line skips dead PIDs" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local root
  root="$(_w_find_root)"
  local state_dir
  state_dir="$(_w_state_dir "$root")"
  cat > "$state_dir/ports.json" <<EOF
{
  "feat-x": {
    "slot": 1,
    "servers": {
      "frontend": { "port": 3001, "pid": 999999 }
    }
  }
}
EOF
  local result
  result="$(_w_server_status_line "feat-x" "$root")"
  [[ -z "$result" ]]
}

# --- _w_server_status_block ---

@test "server_status_block returns empty for no ports entry" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local root
  root="$(_w_find_root)"
  local result
  result="$(_w_server_status_block "main" "$root")"
  [[ -z "$result" ]]
}

@test "server_status_block shows server details with alive status" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local root
  root="$(_w_find_root)"
  local state_dir
  state_dir="$(_w_state_dir "$root")"
  cat > "$state_dir/ports.json" <<EOF
{
  "feat-x": {
    "slot": 1,
    "servers": {
      "frontend": { "port": 3001, "pid": $$ },
      "backend": { "port": 8081, "pid": 999999 }
    }
  }
}
EOF
  local result
  result="$(_w_server_status_block "feat-x" "$root")"
  # Should have 2 lines, sorted by name
  local line_count
  line_count="$(echo "$result" | wc -l)"
  [[ "$line_count" -eq 2 ]]
  # backend (dead) should be first (alphabetical)
  echo "$result" | head -1 | grep -q "backend"
  echo "$result" | head -1 | grep -q "false"
  # frontend (alive) should be second
  echo "$result" | tail -1 | grep -q "frontend"
  echo "$result" | tail -1 | grep -q "true"
}

# --- _w_cmd_ls ---

@test "ls lists worktrees with marker for current" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local result
  result="$(_w_cmd_ls)"
  # Should contain main worktree
  [[ "$result" == *"main"* ]]
  # Current directory is TEST_DIR (the main worktree), so should have * marker
  [[ "$result" == *"*"* ]]
  # Should contain clean status
  [[ "$result" == *"clean"* ]]
}

@test "ls shows dirty status for modified worktree" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  # Make the repo dirty
  echo "change" > "$TEST_DIR/dirty-file.txt"
  local result
  result="$(_w_cmd_ls)"
  [[ "$result" == *"dirty"* ]]
  [[ "$result" == *"1 file changed"* ]]
}

@test "ls shows multiple worktrees" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  # Create a worktree
  _w_cmd_go feat-ls-test 2>/dev/null
  rm -f "$W_STATE_DIR/cd-target"
  cd "$TEST_DIR"
  local result
  result="$(_w_cmd_ls)"
  [[ "$result" == *"main"* ]]
  [[ "$result" == *"feat-ls-test"* ]]
}

# --- _w_cmd_status ---

@test "status shows project header with worktree count" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local result
  result="$(_w_cmd_status)"
  local proj
  proj="$(_w_project_name "$(_w_find_root)")"
  # Header line should contain project name and worktree count
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

@test "status shows server block for running servers" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local root
  root="$(_w_find_root)"
  local state_dir
  state_dir="$(_w_state_dir "$root")"
  cat > "$state_dir/ports.json" <<EOF
{
  "main": {
    "slot": 0,
    "servers": {
      "frontend": { "port": 3000, "pid": $$ }
    }
  }
}
EOF
  local result
  result="$(_w_cmd_status)"
  [[ "$result" == *"frontend"* ]]
  [[ "$result" == *":3000"* ]]
  [[ "$result" == *"pid"* ]]
  # Should use └ connector for single server
  [[ "$result" == *"└"* ]]
}
