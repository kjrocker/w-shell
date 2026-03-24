#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

PROMPT_FILE="PROMPT.md"
TODO_FILE="TODO.md"
MAX_ITERATIONS=20

todo_done() {
    # True if no unchecked items remain
    ! grep -q '^\- \[ \]' "$TODO_FILE"
}

current_section() {
    # Print the number of the first section with unchecked items
    grep -B 50 '^\- \[ \]' "$TODO_FILE" | grep -oP '(?<=^## )\d+' | head -1
}

iteration=0
while true; do
    iteration=$((iteration + 1))

    if todo_done; then
        echo "=== All TODO items complete ==="
        break
    fi

    if [ "$iteration" -gt "$MAX_ITERATIONS" ]; then
        echo "=== Hit max iterations ($MAX_ITERATIONS), stopping ==="
        break
    fi

    section=$(current_section)
    echo "=== Iteration $iteration — working on section $section ==="

    prompt=$(cat "$PROMPT_FILE")

    "$SCRIPT_DIR/claude-container" -p "$prompt" \
        --max-turns 50 \
        --verbose 2>&1 | tee "/tmp/claude-todo-run-${iteration}.log"

    echo "=== Iteration $iteration finished ==="
    echo ""
done

echo "=== Done after $iteration iteration(s) ==="
