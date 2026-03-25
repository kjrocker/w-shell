#!/usr/bin/env bats

load helpers

# --- _w_config_file ---

@test "_w_config_file returns path when config exists" {
  echo 'path = "{parent}/{project}.{name}"' > "$TEST_DIR/.wtconfig.toml"
  run bash -c "source '$W_BIN' --source-only 2>/dev/null; _w_config_file '$TEST_DIR'"
  [ "$status" -eq 0 ]
  [ "$output" = "$TEST_DIR/.wtconfig.toml" ]
}

@test "_w_config_file returns 1 when config missing" {
  run bash -c "source '$W_BIN' --source-only 2>/dev/null; _w_config_file '$TEST_DIR'"
  [ "$status" -eq 1 ]
  [ "$output" = "" ]
}

# --- _w_config_get ---

@test "_w_config_get reads path from config" {
  cat > "$TEST_DIR/.wtconfig.toml" <<'EOF'
path = "{parent}/{project}.worktrees/{name}"
EOF
  run bash -c "source '$W_BIN' --source-only 2>/dev/null; _w_config_get '$TEST_DIR' '.path'"
  [ "$status" -eq 0 ]
  [ "$output" = "{parent}/{project}.worktrees/{name}" ]
}

@test "_w_config_get reads setup commands from config" {
  cat > "$TEST_DIR/.wtconfig.toml" <<'EOF'
[setup]
commands = ["npm install", "cp .env.example .env"]
EOF
  run bash -c "source '$W_BIN' --source-only 2>/dev/null; _w_config_get '$TEST_DIR' '.setup.commands[]'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"npm install"* ]]
  [[ "$output" == *"cp .env.example .env"* ]]
}

@test "_w_config_get reads server name from config" {
  cat > "$TEST_DIR/.wtconfig.toml" <<'EOF'
[[server]]
name = "frontend"
command = "npm run dev"
port-env = "PORT"
base-port = 3000
EOF
  run bash -c "source '$W_BIN' --source-only 2>/dev/null; _w_config_get '$TEST_DIR' '.server[0].name'"
  [ "$status" -eq 0 ]
  [ "$output" = "frontend" ]
}

@test "_w_config_get returns 1 when config missing" {
  run bash -c "source '$W_BIN' --source-only 2>/dev/null; _w_config_get '$TEST_DIR' '.path'"
  [ "$status" -eq 1 ]
}

# --- _w_resolve_path ---

@test "_w_resolve_path uses default sibling pattern without config" {
  cd "$TEST_DIR"
  run bash -c "source '$W_BIN' --source-only 2>/dev/null; _w_resolve_path '$TEST_DIR' 'feat-x'"
  [ "$status" -eq 0 ]
  local parent
  parent="$(dirname "$TEST_DIR")"
  local project
  project="$(basename "$TEST_DIR")"
  [ "$output" = "$parent/$project.feat-x" ]
}

@test "_w_resolve_path expands sibling template" {
  cat > "$TEST_DIR/.wtconfig.toml" <<'EOF'
path = "{parent}/{project}.{name}"
EOF
  cd "$TEST_DIR"
  run bash -c "source '$W_BIN' --source-only 2>/dev/null; _w_resolve_path '$TEST_DIR' 'feat-x'"
  [ "$status" -eq 0 ]
  local parent
  parent="$(dirname "$TEST_DIR")"
  local project
  project="$(basename "$TEST_DIR")"
  [ "$output" = "$parent/$project.feat-x" ]
}

@test "_w_resolve_path expands subdirectory template" {
  cat > "$TEST_DIR/.wtconfig.toml" <<'EOF'
path = "{parent}/{project}.worktrees/{name}"
EOF
  cd "$TEST_DIR"
  run bash -c "source '$W_BIN' --source-only 2>/dev/null; _w_resolve_path '$TEST_DIR' 'feat-x'"
  [ "$status" -eq 0 ]
  local parent
  parent="$(dirname "$TEST_DIR")"
  local project
  project="$(basename "$TEST_DIR")"
  [ "$output" = "$parent/$project.worktrees/feat-x" ]
}

@test "_w_resolve_path expands global home template" {
  cat > "$TEST_DIR/.wtconfig.toml" <<'EOF'
path = "{home}/worktrees/{project}/{name}"
EOF
  cd "$TEST_DIR"
  run bash -c "source '$W_BIN' --source-only 2>/dev/null; _w_resolve_path '$TEST_DIR' 'feat-x'"
  [ "$status" -eq 0 ]
  local project
  project="$(basename "$TEST_DIR")"
  [ "$output" = "$HOME/worktrees/$project/feat-x" ]
}

@test "_w_resolve_path returns default path when config has no path key" {
  cat > "$TEST_DIR/.wtconfig.toml" <<'EOF'
[setup]
commands = ["npm install"]
EOF
  cd "$TEST_DIR"
  run bash -c "source '$W_BIN' --source-only 2>/dev/null; _w_resolve_path '$TEST_DIR' 'feat-x'"
  [ "$status" -eq 0 ]
  local parent
  parent="$(dirname "$TEST_DIR")"
  local project
  project="$(basename "$TEST_DIR")"
  [ "$output" = "$parent/$project.feat-x" ]
}
