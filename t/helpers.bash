#!/usr/bin/env bash

# Path to the w script under test
W_BIN="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/bin/w"

setup() {
  # Create a temp directory for each test
  TEST_DIR="$(mktemp -d)"
  # Initialize a git repo with an initial commit
  git -C "$TEST_DIR" init -b main --quiet
  git -C "$TEST_DIR" -c user.email=test@test.com -c user.name=Test commit --allow-empty -m "initial" --quiet
  # Override STATE_DIR to isolate test state
  export W_STATE_DIR="$TEST_DIR/.w-state"
  mkdir -p "$W_STATE_DIR"
  # Disable color in tests
  export NO_COLOR=1
}

teardown() {
  rm -rf "$TEST_DIR"
}

# Run w from within the test repo
run_w() {
  cd "$TEST_DIR" && run "$W_BIN" "$@"
}
