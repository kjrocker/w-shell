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

@test "_w_cd_target writes path to cd-target file" {
  run bash -c "export W_STATE_DIR='$W_STATE_DIR'; source '$W_BIN' --source-only 2>/dev/null; _w_cd_target /some/path"
  [ "$status" -eq 0 ]
  [ "$(cat "$W_STATE_DIR/cd-target")" = "/some/path" ]
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
