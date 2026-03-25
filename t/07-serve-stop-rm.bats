#!/usr/bin/env bats

load helpers

# --- _w_write_ports ---

@test "write_ports writes JSON to ports.json" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local root
  root="$(_w_find_root)"
  _w_write_ports "$root" '{"test": {"slot": 1}}'
  local file
  file="$(_w_ports_file "$root")"
  [[ -f "$file" ]]
  local content
  content="$(cat "$file")"
  [[ "$content" == *'"test"'* ]]
}

@test "read_ports returns empty object when no file" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local root
  root="$(_w_find_root)"
  local result
  result="$(_w_read_ports "$root")"
  [[ "$result" == "{}" ]]
}

@test "read_ports returns content after write" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local root
  root="$(_w_find_root)"
  _w_write_ports "$root" '{"feat-x": {"slot": 1, "servers": {}}}'
  local result
  result="$(_w_read_ports "$root")"
  [[ "$(printf '%s' "$result" | jq -r '.["feat-x"].slot')" == "1" ]]
}

# --- _w_cmd_serve ---

@test "serve starts a background process and writes ports.json" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local root
  root="$(_w_find_root)"

  # Create a .wtconfig.toml with a server
  cat > "$TEST_DIR/.wtconfig.toml" <<'TOML'
[[server]]
name = "test-server"
command = "sleep 600"
port-env = "PORT"
base-port = 9000
TOML

  # Assign main slot
  _w_cmd_serve "main" 2>/dev/null

  # Check ports.json
  local ports_json
  ports_json="$(_w_read_ports "$root")"
  local port pid
  port="$(printf '%s' "$ports_json" | jq -r '.main.servers["test-server"].port')"
  pid="$(printf '%s' "$ports_json" | jq -r '.main.servers["test-server"].pid')"

  [[ "$port" == "9000" ]]
  [[ -n "$pid" ]]
  [[ -d "/proc/$pid" ]]

  # Clean up
  kill "$pid" 2>/dev/null || true
}

@test "serve respects --only flag" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local root
  root="$(_w_find_root)"

  cat > "$TEST_DIR/.wtconfig.toml" <<'TOML'
[[server]]
name = "frontend"
command = "sleep 600"
port-env = "PORT"
base-port = 9000

[[server]]
name = "backend"
command = "sleep 600"
port-env = "API_PORT"
base-port = 9100
TOML

  _w_cmd_serve "main" --only=frontend 2>/dev/null

  local ports_json
  ports_json="$(_w_read_ports "$root")"

  # frontend should be started
  local fe_pid
  fe_pid="$(printf '%s' "$ports_json" | jq -r '.main.servers.frontend.pid')"
  [[ -n "$fe_pid" && "$fe_pid" != "null" ]]

  # backend should NOT be started
  local be_pid
  be_pid="$(printf '%s' "$ports_json" | jq -r '.main.servers.backend.pid // empty')"
  [[ -z "$be_pid" ]]

  kill "$fe_pid" 2>/dev/null || true
}

@test "serve computes port from base-port + slot" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local root
  root="$(_w_find_root)"

  cat > "$TEST_DIR/.wtconfig.toml" <<'TOML'
[[server]]
name = "web"
command = "sleep 600"
port-env = "PORT"
base-port = 3000
TOML

  # Assign slot for feat-x
  _w_slot_assign "feat-x" "$root" > /dev/null

  # Create a fake worktree path so serve doesn't fail
  local wt_path
  wt_path="$(_w_resolve_path "$root" "feat-x")"
  mkdir -p "$wt_path"

  _w_cmd_serve "feat-x" 2>/dev/null

  local ports_json
  ports_json="$(_w_read_ports "$root")"
  local port
  port="$(printf '%s' "$ports_json" | jq -r '.["feat-x"].servers.web.port')"
  # slot 1 -> 3000 + 1 = 3001
  [[ "$port" == "3001" ]]

  # Clean up
  local pid
  pid="$(printf '%s' "$ports_json" | jq -r '.["feat-x"].servers.web.pid')"
  kill "$pid" 2>/dev/null || true
  rm -rf "$wt_path"
}

# --- _w_cmd_stop ---

@test "stop kills running server and cleans ports.json" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local root
  root="$(_w_find_root)"

  cat > "$TEST_DIR/.wtconfig.toml" <<'TOML'
[[server]]
name = "test-server"
command = "sleep 600"
port-env = "PORT"
base-port = 9000
TOML

  _w_cmd_serve "main" 2>/dev/null

  local ports_json pid
  ports_json="$(_w_read_ports "$root")"
  pid="$(printf '%s' "$ports_json" | jq -r '.main.servers["test-server"].pid')"
  [[ -d "/proc/$pid" ]]

  _w_cmd_stop "main" 2>/dev/null

  # PID should be gone
  sleep 0.5
  [[ ! -d "/proc/$pid" ]]

  # ports.json should have main removed
  ports_json="$(_w_read_ports "$root")"
  local has_main
  has_main="$(printf '%s' "$ports_json" | jq 'has("main")')"
  [[ "$has_main" == "false" ]]
}

@test "stop with --only removes only specified server" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local root
  root="$(_w_find_root)"

  cat > "$TEST_DIR/.wtconfig.toml" <<'TOML'
[[server]]
name = "frontend"
command = "sleep 600"
port-env = "PORT"
base-port = 9000

[[server]]
name = "backend"
command = "sleep 600"
port-env = "API_PORT"
base-port = 9100
TOML

  _w_cmd_serve "main" 2>/dev/null

  local ports_json fe_pid be_pid
  ports_json="$(_w_read_ports "$root")"
  fe_pid="$(printf '%s' "$ports_json" | jq -r '.main.servers.frontend.pid')"
  be_pid="$(printf '%s' "$ports_json" | jq -r '.main.servers.backend.pid')"

  _w_cmd_stop "main" --only=frontend 2>/dev/null
  sleep 0.3

  # frontend PID should be gone
  [[ ! -d "/proc/$fe_pid" ]]
  # backend PID should still be alive
  [[ -d "/proc/$be_pid" ]]

  # ports.json should still have main with backend only
  ports_json="$(_w_read_ports "$root")"
  local has_fe has_be
  has_fe="$(printf '%s' "$ports_json" | jq -r '.main.servers | has("frontend")')"
  has_be="$(printf '%s' "$ports_json" | jq -r '.main.servers | has("backend")')"
  [[ "$has_fe" == "false" ]]
  [[ "$has_be" == "true" ]]

  # Clean up
  kill "$be_pid" 2>/dev/null || true
}

# --- _w_cmd_rm ---

@test "rm refuses to remove branch with unmerged commits" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local root
  root="$(_w_find_root)"

  # Create a worktree with an unmerged commit
  _w_cmd_go "feat-rm-test" 2>/dev/null
  rm -f "$W_STATE_DIR/cd-target"
  local wt_path
  wt_path="$(_w_resolve_path "$root" "feat-rm-test")"
  git -C "$wt_path" -c user.email=test@test.com -c user.name=Test commit --allow-empty -m "unmerged work" --quiet

  cd "$TEST_DIR"
  run bash -c "source '$W_BIN' --source-only && cd '$TEST_DIR' && _w_cmd_rm feat-rm-test"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"unmerged commits"* ]]

  # Worktree should still exist
  [[ -d "$wt_path" ]]
}

@test "rm with --force removes branch with unmerged commits" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local root
  root="$(_w_find_root)"

  # Create a worktree with an unmerged commit
  _w_cmd_go "feat-rm-force" 2>/dev/null
  rm -f "$W_STATE_DIR/cd-target"
  local wt_path
  wt_path="$(_w_resolve_path "$root" "feat-rm-force")"
  git -C "$wt_path" -c user.email=test@test.com -c user.name=Test commit --allow-empty -m "unmerged" --quiet

  cd "$TEST_DIR"
  _w_cmd_rm "feat-rm-force" --force 2>/dev/null

  # Worktree should be gone
  [[ ! -d "$wt_path" ]]

  # Slot should be freed
  local slot
  slot="$(_w_slot_get "feat-rm-force" "$root")"
  [[ -z "$slot" ]]
}

@test "rm stops servers before removing" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local root
  root="$(_w_find_root)"

  cat > "$TEST_DIR/.wtconfig.toml" <<'TOML'
[[server]]
name = "test-srv"
command = "sleep 600"
port-env = "PORT"
base-port = 9000
TOML

  # Create worktree and start server
  _w_cmd_go "feat-rm-srv" 2>/dev/null
  rm -f "$W_STATE_DIR/cd-target"
  _w_cmd_serve "feat-rm-srv" 2>/dev/null

  local ports_json pid
  ports_json="$(_w_read_ports "$root")"
  pid="$(printf '%s' "$ports_json" | jq -r '.["feat-rm-srv"].servers["test-srv"].pid')"
  [[ -d "/proc/$pid" ]]

  cd "$TEST_DIR"
  _w_cmd_rm "feat-rm-srv" --force 2>/dev/null
  sleep 0.5

  # PID should be gone
  [[ ! -d "/proc/$pid" ]]
}
