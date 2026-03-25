#!/usr/bin/env bats

load helpers

@test "_w_find_root returns repo path" {
  cd "$TEST_DIR"
  run bash -c "source '$W_BIN' --source-only 2>/dev/null; _w_find_root"
  [ "$status" -eq 0 ]
  [ "$output" = "$TEST_DIR" ]
}

@test "_w_find_root fails outside git repo" {
  cd /tmp
  run bash -c "source '$W_BIN' --source-only 2>/dev/null; _w_find_root"
  [ "$status" -ne 0 ]
}

@test "_w_project_name returns basename" {
  run bash -c "source '$W_BIN' --source-only 2>/dev/null; _w_project_name /home/user/projects/myapp"
  [ "$status" -eq 0 ]
  [ "$output" = "myapp" ]
}

@test "_w_parent_dir returns dirname" {
  run bash -c "source '$W_BIN' --source-only 2>/dev/null; _w_parent_dir /home/user/projects/myapp"
  [ "$status" -eq 0 ]
  [ "$output" = "/home/user/projects" ]
}

@test "_w_find_main_worktree returns first worktree path" {
  cd "$TEST_DIR"
  run bash -c "source '$W_BIN' --source-only 2>/dev/null; _w_find_main_worktree"
  [ "$status" -eq 0 ]
  [ "$output" = "$TEST_DIR" ]
}

@test "--version prints version string" {
  run_w --version
  [ "$status" -eq 0 ]
  [[ "$output" == "w "* ]]
}

@test "--help prints usage to stderr" {
  cd "$TEST_DIR"
  run "$W_BIN" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

# --- Outside git repo ---

@test "--help works outside git repo" {
  cd /tmp
  run "$W_BIN" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "--version works outside git repo" {
  cd /tmp
  run "$W_BIN" --version
  [ "$status" -eq 0 ]
  [[ "$output" == "w "* ]]
}

@test "no args shows help outside git repo" {
  cd /tmp
  run "$W_BIN"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "unknown command fails gracefully outside git repo" {
  cd /tmp
  run "$W_BIN" nonexistent
  [ "$status" -ne 0 ]
  [[ "$output" == *"Not inside a git repository"* ]]
}
