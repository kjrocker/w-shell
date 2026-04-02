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
