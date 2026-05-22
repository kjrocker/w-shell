#!/usr/bin/env bats

load helpers

# --- _w_build_env ---

@test "build_env returns nothing without config" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local result
  result="$(_w_build_env "$TEST_DIR" "main" "0")"
  [[ -z "$result" ]]
}

@test "build_env returns nothing without env section" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  cat > "$TEST_DIR/.wtconfig.toml" <<'TOML'
[setup]
commands = []
TOML
  local result
  result="$(_w_build_env "$TEST_DIR" "main" "0")"
  [[ -z "$result" ]]
}

@test "build_env computes base port with slot" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  cat > "$TEST_DIR/.wtconfig.toml" <<'TOML'
[env]
PORT = "{base:3000}"
TOML
  local result
  result="$(_w_build_env "$TEST_DIR" "feat-x" "2")"
  [[ "$result" == "PORT=3002" ]]
}

@test "build_env slot 0 returns base port" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  cat > "$TEST_DIR/.wtconfig.toml" <<'TOML'
[env]
PORT = "{base:3000}"
TOML
  local result
  result="$(_w_build_env "$TEST_DIR" "main" "0")"
  [[ "$result" == "PORT=3000" ]]
}

@test "build_env substitutes {name}" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  cat > "$TEST_DIR/.wtconfig.toml" <<'TOML'
[env]
DB = "myapp_{name}"
TOML
  local result
  result="$(_w_build_env "$TEST_DIR" "feat-x" "1")"
  [[ "$result" == "DB=myapp_feat-x" ]]
}

@test "build_env substitutes {project}" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  cat > "$TEST_DIR/.wtconfig.toml" <<'TOML'
[env]
APP = "{project}"
TOML
  local result
  result="$(_w_build_env "$TEST_DIR" "main" "0")"
  local proj
  proj="$(_w_project_name "$TEST_DIR")"
  [[ "$result" == "APP=$proj" ]]
}

@test "build_env passes literal values through" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  cat > "$TEST_DIR/.wtconfig.toml" <<'TOML'
[env]
NODE_ENV = "development"
TOML
  local result
  result="$(_w_build_env "$TEST_DIR" "main" "0")"
  [[ "$result" == "NODE_ENV=development" ]]
}

@test "build_env interpolates {base:N} inside compound values" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  cat > "$TEST_DIR/.wtconfig.toml" <<'TOML'
[env]
DATABASE_URL = "postgres://localhost:{base:5432}/myapp"
TOML
  local result
  result="$(_w_build_env "$TEST_DIR" "feat-x" "2")"
  [[ "$result" == "DATABASE_URL=postgres://localhost:5434/myapp" ]]
}

@test "build_env handles multiple env vars" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  cat > "$TEST_DIR/.wtconfig.toml" <<'TOML'
[env]
PORT = "{base:3000}"
NODE_ENV = "development"
TOML
  local result
  result="$(_w_build_env "$TEST_DIR" "main" "0")"
  local line_count
  line_count="$(echo "$result" | wc -l)"
  [[ "$line_count" -eq 2 ]]
  [[ "$result" == *"PORT=3000"* ]]
  [[ "$result" == *"NODE_ENV=development"* ]]
}

# --- _w_write_ports / _w_read_ports ---

@test "write_ports creates file with export lines" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  cat > "$TEST_DIR/.wtconfig.toml" <<'TOML'
[env]
PORT = "{base:3000}"
TOML
  _w_write_ports "$TEST_DIR" "$TEST_DIR" "main" "0"
  [[ -f "$TEST_DIR/.ports" ]]
  grep -q '^export PORT=3000$' "$TEST_DIR/.ports"
}

@test "write_ports quotes values with spaces and special chars" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  cat > "$TEST_DIR/.wtconfig.toml" <<'TOML'
[env]
MSG = "hello world & symbols"
TOML
  _w_write_ports "$TEST_DIR" "$TEST_DIR" "main" "0"
  # Sourcing the file in a subshell should preserve the value exactly
  local got
  got="$(bash -c "source '$TEST_DIR/.ports' && printf '%s' \"\$MSG\"")"
  [[ "$got" == "hello world & symbols" ]]
}

@test "write_ports removes stale file when no env section" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  cat > "$TEST_DIR/.wtconfig.toml" <<'TOML'
[env]
PORT = "{base:3000}"
TOML
  _w_write_ports "$TEST_DIR" "$TEST_DIR" "main" "0"
  [[ -f "$TEST_DIR/.ports" ]]
  cat > "$TEST_DIR/.wtconfig.toml" <<'TOML'
[setup]
commands = []
TOML
  _w_write_ports "$TEST_DIR" "$TEST_DIR" "main" "0"
  [[ ! -f "$TEST_DIR/.ports" ]]
}

@test "write_ports leaves no file when there was never an env section" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  _w_write_ports "$TEST_DIR" "$TEST_DIR" "main" "0"
  [[ ! -f "$TEST_DIR/.ports" ]]
}

@test "read_ports round-trips KEY=val pairs" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  cat > "$TEST_DIR/.wtconfig.toml" <<'TOML'
[env]
PORT = "{base:3000}"
NODE_ENV = "development"
TOML
  _w_write_ports "$TEST_DIR" "$TEST_DIR" "main" "0"
  local result
  result="$(_w_read_ports "$TEST_DIR")"
  [[ "$result" == *"PORT=3000"* ]]
  [[ "$result" == *"NODE_ENV=development"* ]]
}

@test "read_ports returns nothing when file missing" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local result
  result="$(_w_read_ports "$TEST_DIR")"
  [[ -z "$result" ]]
}
