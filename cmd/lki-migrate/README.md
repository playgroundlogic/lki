# lki-migrate

Apply mechanical migrations between LKI format versions.

## What this tool does

Given a spec file at format version N, produce a draft of the same
spec at format version N+1 by applying the mechanical migrations
documented in the migration guide.

For the v0.1 → v0.2 migration these are the M1-M6 changes from
[`migrations/v0.1-to-v0.2.md`](../../migrations/v0.1-to-v0.2.md):

- M1 — Format version field bump
- M2 — Intent version major bump
- M3 — Constraints section restructuring
- M4 — Type reference version pinning syntax
- M5 — Examples and anti-patterns structure preservation
- M6 — `tested_against` version syntax (optional)

Substantive migrations (S1-S9) are **flagged** as TODO comments in the
output rather than auto-applied. A human reviews and completes the
substantive migrations before the spec ships.

## Success criterion

Running `lki-migrate --from 0.1 --to 0.2` against a v0.1 spec produces
output where:
- M1-M6 mechanical changes are applied
- S1-S9 substantive changes appear as TODO markers identifying the
  finding numbers and the migration guide section
- A diff against the hand-migrated v2.0.0 version of the same spec
  shows only substantive changes (the M-changes match)

## Usage (planned)

```
lki-migrate [flags] <spec-file>

Flags:
  --from=<version>           Source format version
  --to=<version>             Target format version
  --in-place                 Modify the input file (default: write to stdout)
  --output=<path>            Write to a specific path
```

## Status

Skeleton only. Implementation pending. Lower priority than
`cedar-from-lki` and `lki-validate` since manual migration of the
v0.1 → v0.2 specs is complete; this tool earns its place when v0.3
ships and a new batch of migrations needs running.

## Implementation notes

The migration logic is roughly:
1. Parse source-version spec
2. Apply mechanical transforms (mostly key renames and structural splits)
3. Walk substantive migration rules; emit TODO comments where human review is needed
4. Serialize back to YAML, preserving comments where possible (using a
   YAML library that supports round-tripping with comment preservation)

The "preserve comments" requirement may dictate library choice;
`gopkg.in/yaml.v3` round-trips poorly with comments. May need to use
a higher-fidelity YAML library or accept comment loss.

## Dependencies

- YAML library TBD pending the comment preservation question
