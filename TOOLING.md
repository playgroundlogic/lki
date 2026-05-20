# Tooling

This document describes the planned Go tooling that consumes LKI
specs. Tools are referenced by name in the format specification
(Chapter 15.7); this document covers their structure, conventions,
and dependencies.

## Overview

| Tool | Status | Purpose |
|---|---|---|
| [`cedar-from-lki`](cmd/cedar-from-lki/) | skeleton | Project LKI specs to Cedar schema + policy templates |
| [`lki-validate`](cmd/lki-validate/) | skeleton | Validate LKI specs against the format specification |
| [`lki-migrate`](cmd/lki-migrate/) | skeleton | Apply mechanical migrations between format versions |
| `tool-si-data-from-lki` | deferred | Optional: produce Tool-SI training data from specs |

The first three are the substrate's needed tools. `tool-si-data-from-lki`
is deferred until Tool-SI training is actually justified by measurement
(per the discipline in [CLAUDE.md](CLAUDE.md) — Tool-SI is not a
prerequisite).

## Repository layout

Standard Go monorepo:

```
lki/
├── go.mod                     # Module: github.com/playgroundlogic/lki
├── go.sum                     # (created when first dep is added)
├── cmd/                       # Binaries, one per tool
│   ├── cedar-from-lki/
│   ├── lki-validate/
│   └── lki-migrate/
└── internal/                  # Non-public shared logic
    ├── spec/                  # Parse and validate LKI specs
    ├── cedar/                 # Emit Cedar artifacts
    └── projection/            # Apply Chapter 9 projection rules
```

Additional internal packages get added as needed by their consumer tools:
- `internal/grammar` — interpolation and expression parsing (when used)
- `internal/migrate` — migration logic (when `lki-migrate` is written)
- `internal/types` — type catalog operations (when extraction justified)

The `internal/` directory is Go convention for packages not intended
for external import. The format itself is the public interface;
consumers use the YAML specs directly, not the Go types.

## Conventions

**Language and version:** Go 1.23.

**Dependencies:** Minimize external dependencies. Initial set:
- `gopkg.in/yaml.v3` for YAML parsing

Future deps to consider when needed:
- Cedar Go bindings (`github.com/cedar-policy/cedar-go`) for schema-aware emission
- A higher-fidelity YAML library if comment preservation becomes required for `lki-migrate`

**Determinism:** All tools produce byte-identical output for identical
input. Cedar emission orders by alphabet within each category. Schema
emission groups by entity type then by action type. Policies are emitted
in declared order.

**Errors:** Tools return non-zero on any error. Validation tools
distinguish errors (non-zero) from warnings (zero exit, warning output).

**Testing:** The committed projections at `projections/{intent}/v2.0.0/`
serve as golden files. Test cases run each tool against its inputs and
compare output to the committed artifacts. Deviation is a test failure.

For `lki-validate`, test fixtures include intentionally-broken specs
under `cmd/lki-validate/testdata/` (TBD when the tool is implemented).

**Building:**

```
go build ./...
```

Binaries land in `./cmd/<tool>/<tool>` by default; the build system can
be enhanced later if needed.

## Implementation order

1. **`cedar-from-lki`** first — clearest success criterion (golden-file
   match against committed projections), exercises every part of the
   v0.2 format spec
2. **`lki-validate`** second — much of the parsing infrastructure is
   shared with `cedar-from-lki`; validation rules are well-documented
3. **`lki-migrate`** third — earns its place when v0.3 ships and a
   batch of migrations needs running; not blocking for v0.2 work

## Out of scope for tooling

- **A library API.** The format is the public interface, not the Go
  types. If external consumers want to read specs, they parse YAML
  directly; if they want to do projection, they implement the rules
  in their own language.
- **A daemon or persistent service.** All tools are batch CLI utilities.
  Long-running components (the gauntlet / cast runtime) live in
  different repositories (agenkit, etc.).
- **Spec authoring assistance.** `lki-validate` checks shape; it doesn't
  help write specs. Authoring is a manual / IDE / Claude Code activity.
- **Cedar evaluation.** These tools produce Cedar; they don't evaluate
  it. Evaluation happens in the runtime that uses these artifacts
  (e.g., the gauntlet).

## When to split into multiple repos

The current monorepo arrangement is appropriate while:
- Tools and format co-evolve closely
- Tools have shared internal packages
- Release cadence is roughly synchronized

If a single tool grows to require its own release cycle (independent
versioning, separate downstream consumers, distinct security profile),
that's the signal to extract it. Don't split prematurely.

The format spec itself stays in this repo regardless; it's the source
of truth, not a tool.
