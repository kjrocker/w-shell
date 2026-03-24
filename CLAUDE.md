# w-raku

Raku-powered git worktree manager. Handles worktree create/navigate/list/remove, setup orchestration via `.wtconfig.toml`, dev server management with automatic port allocation. See SPEC.md for full design.

## Build & Run

```bash
# Run the CLI (requires raku in PATH via rakubrew)
raku -Ilib bin/w-raku

# Run all tests
prove6 -Ilib t/

# Run a single test
raku -Ilib t/01-basic.rakutest
```

## Code Style

- **Strongly prefer functional programming.** Use functions, multi-dispatch, and data-passing over classes and mutable state. Raku supports both — default to functional.
- Use multi-dispatch subs for subcommand routing and polymorphic behavior.
- Grammars are fine — they're a Raku strength and inherently declarative.
- Write tests for any top-level export or non-trivial logic
