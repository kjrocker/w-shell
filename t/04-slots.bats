#!/usr/bin/env bats

load helpers

# --- _w_project_id ---

@test "project_id replaces slashes with underscores and strips leading underscore" {
  source "$W_BIN" --source-only
  local id
  id="$(_w_project_id "$TEST_DIR")"
  # Should not contain slashes
  [[ "$id" != */* ]]
  # Should not start with underscore
  [[ "$id" != _* ]]
  # Should be non-empty
  [[ -n "$id" ]]
}

# --- _w_state_dir ---

@test "state_dir creates project state directory" {
  source "$W_BIN" --source-only
  local dir
  dir="$(_w_state_dir "$TEST_DIR")"
  [[ -d "$dir" ]]
  [[ "$dir" == "$W_STATE_DIR/projects/"* ]]
}

# --- _w_slot_assign ---

@test "slot_assign assigns sequential slots starting at 1" {
  source "$W_BIN" --source-only
  local s1 s2 s3
  s1="$(_w_slot_assign a "$TEST_DIR")"
  s2="$(_w_slot_assign b "$TEST_DIR")"
  s3="$(_w_slot_assign c "$TEST_DIR")"
  [[ "$s1" == "1" ]]
  [[ "$s2" == "2" ]]
  [[ "$s3" == "3" ]]
}

@test "slot_assign is idempotent" {
  source "$W_BIN" --source-only
  local s1 s2
  s1="$(_w_slot_assign a "$TEST_DIR")"
  s2="$(_w_slot_assign a "$TEST_DIR")"
  [[ "$s1" == "$s2" ]]
}

# --- _w_slot_free ---

@test "slot_free frees a slot for reuse" {
  source "$W_BIN" --source-only
  _w_slot_assign a "$TEST_DIR"
  _w_slot_assign b "$TEST_DIR"
  _w_slot_assign c "$TEST_DIR"
  _w_slot_free b "$TEST_DIR"
  local s
  s="$(_w_slot_assign d "$TEST_DIR")"
  # Should reuse slot 2 (freed from b)
  [[ "$s" == "2" ]]
}

# --- _w_slot_get ---

@test "slot_get returns 0 for main" {
  source "$W_BIN" --source-only
  local s
  s="$(_w_slot_get main "$TEST_DIR")"
  [[ "$s" == "0" ]]
}

@test "slot_get returns assigned slot" {
  source "$W_BIN" --source-only
  _w_slot_assign feat "$TEST_DIR"
  local s
  s="$(_w_slot_get feat "$TEST_DIR")"
  [[ "$s" == "1" ]]
}

@test "slot_get returns empty for unassigned name" {
  source "$W_BIN" --source-only
  local s
  s="$(_w_slot_get nonexistent "$TEST_DIR")"
  [[ -z "$s" ]]
}
