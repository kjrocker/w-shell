#!/usr/bin/env bats

load helpers

# --- _w_cmd_rm ---

@test "rm refuses to remove branch with unmerged commits" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local root
  root="$(_w_find_root)"

  # Create a worktree with an unmerged commit
  local wt_path
  wt_path="$(_w_resolve_path "$root" "feat-rm-test")"
  _w_create_worktree feat-rm-test "$wt_path" "$root"
  _w_slot_assign feat-rm-test "$root" > /dev/null
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

  local wt_path
  wt_path="$(_w_resolve_path "$root" "feat-rm-force")"
  _w_create_worktree feat-rm-force "$wt_path" "$root"
  _w_slot_assign feat-rm-force "$root" > /dev/null
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

@test "rm with -f flag removes branch with unmerged commits" {
  source "$W_BIN" --source-only
  cd "$TEST_DIR"
  local root
  root="$(_w_find_root)"

  local wt_path
  wt_path="$(_w_resolve_path "$root" "feat-rm-shortflag")"
  _w_create_worktree feat-rm-shortflag "$wt_path" "$root"
  _w_slot_assign feat-rm-shortflag "$root" > /dev/null
  git -C "$wt_path" -c user.email=test@test.com -c user.name=Test commit --allow-empty -m "unmerged" --quiet

  cd "$TEST_DIR"
  _w_cmd_rm "feat-rm-shortflag" -f 2>/dev/null

  [[ ! -d "$wt_path" ]]
}

@test "rm refuses when inside the target subshell" {
  run bash -c "
    export W_STATE_DIR='$W_STATE_DIR' W_WORKTREE=feat-active NO_COLOR=1
    source '$W_BIN' --source-only 2>/dev/null
    cd '$TEST_DIR'
    _w_cmd_rm feat-active
  "
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"Cannot remove"* ]]
}
