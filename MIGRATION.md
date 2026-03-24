# Shell migration analysis

Current `w-raku --help` takes ~370ms. Bare Raku VM startup is ~105ms, module loading adds ~265ms. Lazy loading shaved ~20-50ms on light commands but can't beat the VM floor.

A pure zsh/bash implementation would have near-zero startup. This document analyzes each subcommand's feasibility as shell.

## Timing baseline

| Command | Raku (current) | Shell (estimated) |
|---------|----------------|-------------------|
| `w --version` | 350ms | <5ms |
| `w exit` | 425ms | <10ms |
| `w feat-x` (existing) | 400ms | <15ms |
| `w ls` | 500ms+ | ~50ms (git is the bottleneck) |
| `w serve` | 500ms+ | ~20ms |

## Per-subcommand analysis

### `w --version` — trivial
```zsh
echo "w 0.0.1"
```

### `w exit` — trivial
```zsh
git worktree list | head -1 | awk '{print $1}'
```
Write to cd-target, let the wrapper read it. ~5 lines of shell.

### `w <name>` (navigate to existing worktree) — easy

Resolve worktree path, check it exists, write cd-target. Requires:
- Read `.wtconfig.toml` for path template (or use default)
- Template substitution: `{parent}`, `{project}`, `{name}`, `{home}`

Shell equivalent (~15 lines):
```zsh
root=$(git rev-parse --show-toplevel)
project=$(basename "$root")
parent=$(dirname "$root")
# template substitution with ${var//pattern/replacement}
path="${parent}/${project}.${name}"  # default
if [[ -d "$path" && -e "$path/.git" ]]; then
  echo "$path" > ~/.local/state/w/cd-target
fi
```

Path template substitution is straightforward with `${var//\{project\}/$project}`.

### `w <name>` (create new worktree) — medium

Same as navigate, plus:
- `git worktree add -b $name $path main` with branch-exists fallback
- Slot allocation (read/write `slots.json`)
- Run setup commands from config

The git commands are trivial. Slot allocation needs `jq` for JSON. Setup is just a for loop running commands. ~40 lines.

### `w <name> <cmd...>` — easy

Resolve path + `(cd "$path" && eval "$@")`. ~10 lines.

### `w rm <name>` — easy-medium

- Stop servers (read `ports.json`, kill PIDs)
- `git worktree remove`
- Free slot from `slots.json`

Needs `jq` for JSON. ~25 lines.

### `w ls` — medium

Per worktree: `git status --porcelain`, `git rev-list --left-right --count`, read `ports.json` for server status. ANSI color formatting. ~50 lines.

The git porcelain grammar translates to awk:
```zsh
git worktree list --porcelain | awk '/^worktree /{path=$2} /^branch /{...}'
```

### `w status` — medium

Same data as `ls` with more formatting. ~60 lines.

### `w serve` — medium

- Parse `.wtconfig.toml` for `[[server]]` entries
- Look up slot from `slots.json`
- Start background processes with port env vars
- Write PIDs + ports to `ports.json`

Starting background processes is native shell. The harder part is TOML parsing.

### `w stop` — easy

Read `ports.json`, kill PIDs, update JSON. ~20 lines with `jq`.

## Key dependencies for shell version

### TOML parsing

The `.wtconfig.toml` format used by w-raku is simple — flat keys, one `[setup]` table, and `[[server]]` array-of-tables. Two options:

1. **`yq`** ([mikefarah/yq](https://github.com/mikefarah/yq), Go binary) — reads TOML natively: `yq -oy '.setup.commands[]' .wtconfig.toml`
2. **Inline awk parser** — The config is simple enough to parse with awk in ~20 lines. No nested tables beyond what's used.

`yq` is cleaner. Available via `dnf install yq` on Fedora.

### JSON read/write

`jq` — universally available, handles `slots.json` and `ports.json` cleanly. Every JSON operation in the codebase maps directly to a `jq` expression:

| Raku | jq |
|------|----|
| `%slots{$name}` | `.[$name]` |
| `%slots{$name}:delete` | `del(.[$name])` |
| `%slots.values` | `[.[]] \| sort` |
| `%ports{$name}<servers>` | `.[$name].servers` |

### Git porcelain parsing

The Raku grammar (`WorktreeList`) parses `git worktree list --porcelain` into structured records. The format is line-oriented key-value pairs separated by blank lines — ideal for awk:

```awk
/^worktree /{ path=$2 }
/^branch /{ branch=$2; sub(/refs\/heads\//, "", branch) }
/^$/{ print path, branch; path=""; branch="" }
```

No actual grammar needed.

## What Raku buys you (and what you'd lose)

| Raku feature | Used where | Shell equivalent | Loss |
|---|---|---|---|
| Grammar + Actions | Porcelain parsing | awk (simpler, fine) | None — format is trivial |
| Multi-dispatch MAIN | Subcommand routing | case statement | None |
| Proc::Async + await | `w serve` | `cmd & ; echo $!` | None — shell bg is native |
| Named parameters | Everywhere | Function args | Readability |
| TOML::Thumb | Config | yq or awk | External dep |
| Type safety | Everywhere | Nothing | Correctness at scale |
| Test framework | `prove6 -Ilib t/` | bats or plain asserts | Test ergonomics |

The honest answer: **nothing in this codebase requires Raku**. The grammar is the most "Raku-native" piece and the format it parses is trivially handled by awk. Every operation is shelling out to git, reading/writing JSON, or managing processes — all things shell does natively.

## Estimated shell implementation size

| Component | Lines (est.) |
|-----------|-------------|
| Core: cd-target, project discovery | 20 |
| Worktree: create, remove, exists, list, path template | 60 |
| Display: color helpers, status formatting | 30 |
| Slots: assign, free, get (jq) | 30 |
| Server: start, stop, status (jq) | 50 |
| Config: TOML parsing (yq) | 15 |
| Setup: run commands | 10 |
| CLI: case routing + all subcommands | 80 |
| **Total** | **~300 lines** |

Compared to ~540 LOC in Raku (plus the MoarVM runtime).

## Migration strategy

### Option A: Full rewrite to zsh

Rewrite the whole thing as a single `w` function (or sourced script). Drops Raku entirely. Dependencies: `jq`, `yq` (mikefarah/yq).

**Pros**: Near-instant startup, zero runtime dependencies beyond git+jq, ~300 lines, single file.
**Cons**: Loses the Raku exercise aspect. Testing is less ergonomic (bats vs prove6).

### Option B: Shell fast-path, Raku fallback

Keep Raku for complex commands (`serve`, `status`), handle the hot path in shell:

```zsh
w() {
  case "$1" in
    exit)   _w_exit ;;
    "")     w-raku --help ;;
    *)
      # Check if worktree exists — if so, just cd (no Raku)
      local path=$(_w_resolve_path "$1")
      if [[ -d "$path" && -e "$path/.git" ]] && [[ $# -eq 1 ]]; then
        echo "$path" > ~/.local/state/w/cd-target
      else
        w-raku "$@"
      fi
      ;;
  esac
  # cd-target handling...
}
```

**Pros**: Instant for the most common operation (switching worktrees). Keeps Raku for the interesting parts. Incremental.
**Cons**: Two implementations to maintain. Behavior divergence risk.

### Option C: Compile to a faster language

Rewrite in Go, Rust, or Nim for a single static binary with ~5ms startup. Same architecture, better performance.

**Pros**: Fast, type-safe, single binary distribution.
**Cons**: Largest effort. Loses Raku exercise.

## Recommendation

**Option B is the best next step.** The most-used command (`w <name>` to switch worktrees) can be handled entirely in the shell wrapper with ~30 lines. This covers the case where responsiveness matters most — interactive navigation — while keeping Raku for the commands where 370ms is fine (create, serve, status, rm).

If that's not enough, Option A is straightforward — the codebase is small and maps cleanly to shell.
