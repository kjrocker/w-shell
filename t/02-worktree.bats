#!/usr/bin/env bats

load helpers

# --- _w_parse_worktrees ---

@test "_w_parse_worktrees parses single worktree" {
  cd "$TEST_DIR"
  run bash -c "source '$W_BIN' --source-only 2>/dev/null; _w_parse_worktrees '$TEST_DIR'"
  [ "$status" -eq 0 ]
  # Should have one line for the main worktree
  [ "$(echo "$output" | wc -l | tr -d ' ')" -eq 1 ]
  # Path should be the test dir
  [[ "$output" == "$TEST_DIR"$'\t'* ]]
  # Branch should be main
  [[ "$output" == *$'\t'"main"$'\t'* ]]
  # State should be normal
  [[ "$output" == *$'\t'"normal" ]]
}

@test "_w_parse_worktrees parses multiple worktrees" {
  cd "$TEST_DIR"
  # Create a second worktree
  git -C "$TEST_DIR" worktree add -b feat "$TEST_DIR/feat-wt" main --quiet
  run bash -c "source '$W_BIN' --source-only 2>/dev/null; _w_parse_worktrees '$TEST_DIR'"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | wc -l | tr -d ' ')" -eq 2 ]
  # Second line should have the feat branch
  local second_line
  second_line="$(echo "$output" | sed -n '2p')"
  [[ "$second_line" == *$'\t'"feat"$'\t'* ]]
}

@test "_w_parse_worktrees strips refs/heads/ from branch" {
  cd "$TEST_DIR"
  run bash -c "source '$W_BIN' --source-only 2>/dev/null; _w_parse_worktrees '$TEST_DIR'"
  [ "$status" -eq 0 ]
  # Branch field should be "main" not "refs/heads/main"
  local branch
  branch="$(echo "$output" | head -1 | cut -f2)"
  [ "$branch" = "main" ]
}

@test "_w_parse_worktrees handles detached HEAD" {
  cd "$TEST_DIR"
  local sha
  sha="$(git -C "$TEST_DIR" rev-parse HEAD)"
  git -C "$TEST_DIR" worktree add --detach "$TEST_DIR/detached-wt" HEAD --quiet
  run bash -c "source '$W_BIN' --source-only 2>/dev/null; _w_parse_worktrees '$TEST_DIR'"
  [ "$status" -eq 0 ]
  local second_line
  second_line="$(echo "$output" | sed -n '2p')"
  [[ "$second_line" == *$'\t'"detached" ]]
}

# --- _w_worktree_dirty ---

@test "_w_worktree_dirty returns 1 for clean repo" {
  cd "$TEST_DIR"
  run bash -c "source '$W_BIN' --source-only 2>/dev/null; _w_worktree_dirty '$TEST_DIR'"
  [ "$status" -eq 1 ]
}

@test "_w_worktree_dirty returns 0 for dirty repo" {
  cd "$TEST_DIR"
  echo "change" > "$TEST_DIR/file.txt"
  run bash -c "source '$W_BIN' --source-only 2>/dev/null; _w_worktree_dirty '$TEST_DIR'"
  [ "$status" -eq 0 ]
}

@test "_w_worktree_dirty returns 0 for staged changes" {
  cd "$TEST_DIR"
  echo "change" > "$TEST_DIR/file.txt"
  git -C "$TEST_DIR" add file.txt
  run bash -c "source '$W_BIN' --source-only 2>/dev/null; _w_worktree_dirty '$TEST_DIR'"
  [ "$status" -eq 0 ]
}

# --- _w_worktree_dirty_count ---

@test "_w_worktree_dirty_count returns 0 for clean repo" {
  cd "$TEST_DIR"
  run bash -c "source '$W_BIN' --source-only 2>/dev/null; _w_worktree_dirty_count '$TEST_DIR'"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "_w_worktree_dirty_count counts dirty files" {
  cd "$TEST_DIR"
  echo "a" > "$TEST_DIR/a.txt"
  echo "b" > "$TEST_DIR/b.txt"
  echo "c" > "$TEST_DIR/c.txt"
  run bash -c "source '$W_BIN' --source-only 2>/dev/null; _w_worktree_dirty_count '$TEST_DIR'"
  [ "$status" -eq 0 ]
  [ "$output" = "3" ]
}

@test "_w_worktree_dirty_count counts staged and unstaged" {
  cd "$TEST_DIR"
  echo "a" > "$TEST_DIR/a.txt"
  git -C "$TEST_DIR" add a.txt
  echo "b" > "$TEST_DIR/b.txt"
  run bash -c "source '$W_BIN' --source-only 2>/dev/null; _w_worktree_dirty_count '$TEST_DIR'"
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
}

# --- _w_worktree_ahead_behind ---

@test "_w_worktree_ahead_behind returns empty with no upstream" {
  cd "$TEST_DIR"
  run bash -c "source '$W_BIN' --source-only 2>/dev/null; _w_worktree_ahead_behind '$TEST_DIR'"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "_w_worktree_ahead_behind shows ahead count" {
  cd "$TEST_DIR"
  # Create a bare remote via clone --bare so HEAD is set properly
  local remote_dir
  remote_dir="$(mktemp -d)/bare.git"
  git clone --bare "$TEST_DIR" "$remote_dir" --quiet 2>/dev/null
  git -C "$TEST_DIR" remote add origin "$remote_dir"
  git -C "$TEST_DIR" push -u origin main --quiet 2>/dev/null
  git -C "$TEST_DIR" -c user.email=test@test.com -c user.name=Test commit --allow-empty -m "second" --quiet
  run bash -c "source '$W_BIN' --source-only 2>/dev/null; _w_worktree_ahead_behind '$TEST_DIR'"
  [ "$status" -eq 0 ]
  [ "$output" = "[ahead 1]" ]
  rm -rf "$remote_dir"
}

@test "_w_worktree_ahead_behind shows behind count" {
  cd "$TEST_DIR"
  local remote_dir
  remote_dir="$(mktemp -d)/bare.git"
  git clone --bare "$TEST_DIR" "$remote_dir" --quiet 2>/dev/null
  git -C "$TEST_DIR" remote add origin "$remote_dir"
  git -C "$TEST_DIR" push -u origin main --quiet 2>/dev/null
  # Simulate behind: clone remote, commit, push, then fetch
  local clone_dir
  clone_dir="$(mktemp -d)/clone"
  git clone "$remote_dir" "$clone_dir" --quiet 2>/dev/null
  git -C "$clone_dir" -c user.email=test@test.com -c user.name=Test commit --allow-empty -m "remote commit" --quiet
  git -C "$clone_dir" push origin main --quiet 2>/dev/null
  git -C "$TEST_DIR" fetch origin --quiet 2>/dev/null
  run bash -c "source '$W_BIN' --source-only 2>/dev/null; _w_worktree_ahead_behind '$TEST_DIR'"
  [ "$status" -eq 0 ]
  [ "$output" = "[behind 1]" ]
  rm -rf "$remote_dir" "$clone_dir"
}

@test "_w_worktree_ahead_behind shows both ahead and behind" {
  cd "$TEST_DIR"
  local remote_dir
  remote_dir="$(mktemp -d)/bare.git"
  git clone --bare "$TEST_DIR" "$remote_dir" --quiet 2>/dev/null
  git -C "$TEST_DIR" remote add origin "$remote_dir"
  git -C "$TEST_DIR" push -u origin main --quiet 2>/dev/null
  # Add a remote commit
  local clone_dir
  clone_dir="$(mktemp -d)/clone"
  git clone "$remote_dir" "$clone_dir" --quiet 2>/dev/null
  git -C "$clone_dir" -c user.email=test@test.com -c user.name=Test commit --allow-empty -m "remote commit" --quiet
  git -C "$clone_dir" push origin main --quiet 2>/dev/null
  # Add a local commit and fetch
  git -C "$TEST_DIR" -c user.email=test@test.com -c user.name=Test commit --allow-empty -m "local commit" --quiet
  git -C "$TEST_DIR" fetch origin --quiet 2>/dev/null
  run bash -c "source '$W_BIN' --source-only 2>/dev/null; _w_worktree_ahead_behind '$TEST_DIR'"
  [ "$status" -eq 0 ]
  [ "$output" = "[ahead 1, behind 1]" ]
  rm -rf "$remote_dir" "$clone_dir"
}
