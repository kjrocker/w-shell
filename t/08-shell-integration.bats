#!/usr/bin/env bats

load helpers

# --- shell/w.bash wrapper tests ---

@test "bash wrapper: w <name> changes PWD to new worktree" {
  # Source the bash wrapper in a subshell and verify cd happens
  local result
  result="$(
    export W_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export W_STATE_DIR="$W_STATE_DIR"
    source "$W_ROOT/shell/w.bash"
    cd "$TEST_DIR"
    w feat-test 2>/dev/null
    pwd
  )"
  # Should have cd'd to the worktree path
  [[ "$result" == *"feat-test"* ]]
}

@test "bash wrapper: w exit changes PWD to main worktree" {
  # Create a worktree first, then exit back
  cd "$TEST_DIR"
  "$W_BIN" feat-exit 2>/dev/null
  local result
  result="$(
    export W_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export W_STATE_DIR="$W_STATE_DIR"
    source "$W_ROOT/shell/w.bash"
    cd "$TEST_DIR"
    w exit 2>/dev/null
    pwd
  )"
  [[ "$result" == "$TEST_DIR" ]]
}

@test "bash wrapper: non-zero exit does not cd" {
  # w rm with no name should fail and not cd
  local result rc
  result="$(
    export W_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export W_STATE_DIR="$W_STATE_DIR"
    source "$W_ROOT/shell/w.bash"
    cd "$TEST_DIR"
    w rm 2>/dev/null
    echo "rc=$?"
    pwd
  )"
  # Should still be in TEST_DIR
  [[ "$result" == *"$TEST_DIR" ]]
}

@test "bash wrapper: no cd-target file means no cd" {
  local result
  result="$(
    export W_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export W_STATE_DIR="$W_STATE_DIR"
    source "$W_ROOT/shell/w.bash"
    cd "$TEST_DIR"
    w ls 2>/dev/null
    pwd
  )"
  [[ "$result" == *"$TEST_DIR"* ]]
}

@test "bash wrapper: stale cd-target cleaned on source" {
  # Create a stale cd-target
  mkdir -p "$W_STATE_DIR"
  echo "/nonexistent" > "$W_STATE_DIR/cd-target"
  # Source the wrapper — should clean it up
  (
    export W_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export W_STATE_DIR="$W_STATE_DIR"
    source "$W_ROOT/shell/w.bash"
  )
  [[ ! -f "$W_STATE_DIR/cd-target" ]]
}

# --- completions/_w basic structure test ---

@test "completions/_w file exists and contains _w function" {
  local compfile="$BATS_TEST_DIRNAME/../completions/_w"
  [[ -f "$compfile" ]]
  grep -q '_w()' "$compfile"
  grep -q '_w_worktree_names()' "$compfile"
  grep -q '#compdef w' "$compfile"
}

@test "completions/_w lists all subcommands" {
  local compfile="$BATS_TEST_DIRNAME/../completions/_w"
  grep -q "'ls:" "$compfile"
  grep -q "'rm:" "$compfile"
  grep -q "'exit:" "$compfile"
  grep -q "'status:" "$compfile"
  grep -q "'serve:" "$compfile"
  grep -q "'stop:" "$compfile"
}

@test "completions/_w supports --only for serve and stop" {
  local compfile="$BATS_TEST_DIRNAME/../completions/_w"
  # Both serve and stop should have --only completion
  grep -q 'serve)' "$compfile"
  grep -q 'stop)' "$compfile"
  grep -q -- '--only=' "$compfile"
}

# --- shell/w.bash completion function test ---

@test "bash completion function is defined after sourcing" {
  local result
  result="$(
    export W_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    source "$W_ROOT/shell/w.bash"
    type -t _w_completions
  )"
  [[ "$result" == "function" ]]
}
