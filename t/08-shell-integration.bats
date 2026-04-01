#!/usr/bin/env bats

load helpers

# --- w.bash wrapper tests ---

@test "bash wrapper: w function calls bin/w" {
  local result
  result="$(
    local w_dir="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export W_STATE_DIR="$W_STATE_DIR"
    source "$w_dir/w.bash"
    cd "$TEST_DIR"
    w --version
  )"
  [[ "$result" == "w "* ]]
}

@test "bash wrapper: w ls works through wrapper" {
  local result
  result="$(
    export W_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export W_STATE_DIR="$W_STATE_DIR" NO_COLOR=1
    source "$W_ROOT/w.bash"
    cd "$TEST_DIR"
    w ls 2>/dev/null
  )"
  [[ "$result" == *"main"* ]]
}

# --- completions/_w basic structure test ---

@test "completions/_w file exists and contains _w function" {
  local compfile="$BATS_TEST_DIRNAME/../completions/_w"
  [[ -f "$compfile" ]]
  grep -q '_w()' "$compfile"
  grep -q '_w_worktree_names()' "$compfile"
  grep -q '#compdef w' "$compfile"
}

@test "completions/_w lists subcommands" {
  local compfile="$BATS_TEST_DIRNAME/../completions/_w"
  grep -q "'ls:" "$compfile"
  grep -q "'rm:" "$compfile"
  grep -q "'exit:" "$compfile"
  grep -q "'status:" "$compfile"
}

@test "completions/_w does not list serve or stop" {
  local compfile="$BATS_TEST_DIRNAME/../completions/_w"
  ! grep -q "'serve:" "$compfile"
  ! grep -q "'stop:" "$compfile"
}

# --- w.bash completion function test ---

@test "bash completion function is defined after sourcing" {
  local result
  result="$(
    local w_dir="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    source "$w_dir/w.bash"
    type -t _w_completions
  )"
  [[ "$result" == "function" ]]
}
