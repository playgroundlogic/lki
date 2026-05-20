# v0.2 Tool Registry

This directory will hold the canonical tool registry per Chapter 9.6
of the v0.2 format spec. The registry validates that every
`process.spawn` capability and `implementation.tool` field references
a known tool.

**Current status:** the tool registry has not yet been formally
extracted to a registry file. Tools referenced by the seven v2.0.0
specs:

| Tool | Used by | Notes |
|---|---|---|
| curl | fetch_url | Preferred; primary HTTP client |
| wget | fetch_url | Alternate; lower priority |
| cat | read_file | POSIX |
| rg (ripgrep) | grep_files | Preferred; JSON output |
| grep | grep_files | Alternate; POSIX |
| find | list_directory | Preferred; structured output |
| ls | list_directory | Alternate; fallback parsing |
| rm | remove_files | POSIX |
| git | commit_changes | >= 2.30 |
| mv, mkdir, mktemp, chmod, sync | write_file | Multiple coreutils |

Shell built-ins (printf) used in write_file are tracked under F-035 in
[../../findings/v0.2.md](../../findings/v0.2.md) — the design
question of whether shell built-ins need their own Tool entities is
pending v0.3.
