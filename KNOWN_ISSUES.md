# Known issues

## macOS path canonicalization in bats tests

Three tests fail on macOS with `[[ "$slot" == "1" ]]` (or equivalent) mismatches. They are pre-existing — not caused by any specific change — and reproduce on a clean `main` checkout.

### Affected tests

- `t/01-core.bats` — `_w_find_root returns repo path`
- `t/01-core.bats` — `_w_find_main_worktree returns first worktree path`
- `t/05-subcommands.bats` — `go to new name creates worktree and slot`

### Root cause

`mktemp -d` on macOS returns a path under `/var/folders/...`. `/var` is a symlink to `/private/var`, so the same directory has two valid names:

- **Logical:** `/var/folders/.../tmp.XXXX` — what `mktemp` returns and what bats stores in `$TEST_DIR`
- **Physical:** `/private/var/folders/.../tmp.XXXX` — what `git rev-parse --show-toplevel` and `cd ... && pwd -P` return

`_w_project_id` derives the project state directory by replacing `/` with `_` in the resolved path:

```bash
_w_project_id() {
  local root="$1"
  local resolved
  resolved="$(cd "$root" && pwd)"   # logical on macOS, physical on Linux
  printf '%s' "${resolved//\//_}" | sed 's/^_//'
}
```

When `_w_cmd_go` runs, it calls `_w_find_root` (which uses `git rev-parse --show-toplevel` → physical path) and stores the slot under a project ID derived from the **physical** path. When the test later calls `_w_slot_get feat-test "$TEST_DIR"`, it derives the project ID from the **logical** path. The two IDs differ:

- write: `private_var_folders_..._tmp.XXXX`
- read:  `var_folders_..._tmp.XXXX`

So the slot lookup misses and the assertion fails.

### Why it doesn't affect production

In normal use, both the write and read sides flow through `_w_find_root` (or both sides start from the user's `pwd` in a real repo where `/var/folders/...` paths don't appear). The bug only surfaces when the test passes `$TEST_DIR` directly to `_w_slot_get` without canonicalizing.

### How to fix (if/when desired)

Two reasonable options:

1. **Canonicalize in `_w_project_id`** — change `cd "$root" && pwd` to `cd "$root" && pwd -P`. Makes the project ID always physical. Side effect: any existing state directories keyed on logical paths are abandoned.

2. **Canonicalize `TEST_DIR` in `t/helpers.bash`** — `TEST_DIR="$(cd "$(mktemp -d)" && pwd -P)"`. Scoped fix; production code unchanged.

Option 2 is the safer minimal fix since it's test-only and matches what `_w_find_root` does at runtime.

### Verification baseline

Before assuming a test failure is yours, run `git stash && bats t/ 2>&1 | grep "^not ok"` to see the baseline. If the same three tests fail with no other diffs, the failures are this issue.
