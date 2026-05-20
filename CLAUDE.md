# CLAUDE.md — Working in this repo

This document orients Claude (Code or otherwise) when working on the LKI
project. Read it first; it tells you what to read next.

## Quick start

**The first time you touch this repo:**
1. Read this file (you are here)
2. Read [README.md](README.md) for the project elevator pitch
3. Skim the chapter list in [format/v0.2/LKI_FORMAT.md](format/v0.2/LKI_FORMAT.md) — don't read 3476 lines; just scan section headings until you know what's where
4. Look at one spec end-to-end (suggest [specs/cli/fetch_url/v2.0.0.yaml](specs/cli/fetch_url/v2.0.0.yaml) — it's the lightest) and its projection
5. Skim [findings/v0.2.md](findings/v0.2.md) for active design questions

**For specific tasks, after the above:**

| Task | Read |
|---|---|
| Edit or migrate a spec | [migrations/v0.1-to-v0.2.md](migrations/v0.1-to-v0.2.md) plus the spec in question |
| Add a new finding | Tail of [findings/v0.2.md](findings/v0.2.md) for the format and tone |
| Implement any tool | [TOOLING.md](TOOLING.md) for layout, conventions, and dependencies |
| Implement `cedar-from-lki` | [cmd/cedar-from-lki/README.md](cmd/cedar-from-lki/README.md), Chapter 9 of format spec, both v2.0.0 projections under [projections/](projections/) |
| Implement `lki-validate` | [cmd/lki-validate/README.md](cmd/lki-validate/README.md) and the full format spec |
| Implement `lki-migrate` | [cmd/lki-migrate/README.md](cmd/lki-migrate/README.md) and [migrations/v0.1-to-v0.2.md](migrations/v0.1-to-v0.2.md) |
| Work on flight plan compiler | [design/flight-plan-goalpost.md](design/flight-plan-goalpost.md) — this is the target |
| Understand falconry vocabulary | See "Vocabulary" section below |

## Project identity

LKI (LLM Knowledge Intent) is a format for declaring agent-invokable
operations under Cedar policy enforcement, plus an audit log substrate
for verifying what happened.

LKI is **the substrate** under any agent runtime that needs:
- Verifiable capability constraints (Cedar PDP-enforced)
- Reproducible audit trails (content-addressed entries)
- Multi-tool implementation routing (specs → resolved invocations)
- Optional specialized model training (Tool-SI, deferred until justified)

LKI is **not**:
- An agent framework. (Agenkit is the framework that will consume LKI.)
- A tool registry per se. (Tool entities live within LKI but aren't its purpose.)
- A natural language interface. (Flight plans are the user surface above LKI; LKI itself is structured.)
- An LLM provider. (LLMs consume LKI specs as tool definitions.)

The closest analogues in adjacent domains: protobuf for RPC (LKI for
agent operations), Cedar policy for IAM (LKI is the layer above Cedar
that produces the policies), OCI image manifests for containers (LKI is
the spec format for invocations the way OCI is the format for images).

## Discipline rules

These are non-negotiable conventions. Violating them creates work
later; following them lets the project compound.

### Version immutability

**Once shipped, a format version is immutable.** This applies to:
- Format specs (`format/v0.x/LKI_FORMAT.md`)
- Intent specs (`specs/cli/<intent>/v<N>.x.y.yaml`)
- Type and entity registry versions
- Cedar projection artifacts (when keyed to a spec version)

Corrections go in a new version, not by editing the shipped one.

**Edge case — infrastructure metadata:** Link target cleanup (fixing
broken markdown links that point to moved files) is allowed without a
version bump. This was decided pragmatically during the v0.2 ship; the
principle is that semantic content is immutable but path metadata can
be corrected. Any change to actual format chapter content or spec
behavior requires a version bump.

If unsure, default to "create a new version" — the cost of a version
bump is small; the cost of a broken historical record is large.

### Findings before changes

When you find an issue with the current shipped format, **record it
as a finding before proposing any change.** Findings accumulate in
`findings/v0.<n>.md` (the open one). Each finding documents:
- The issue
- Why it matters
- A proposed direction (not commitment)
- Source tag: `[scoping]`, `[projection]`, `[drafting]`, `[migration]`, `[deployment]`, `[research]`

When ~15-30 findings accumulate against the current version, that's
the signal to start the next version's design work. Don't try to fix
things one-at-a-time within a version — batch them.

### Migration is per-version

When a format major version bumps (v0.1 → v0.2 → v0.3), every spec
gets a new file with a bumped intent version. The old files stay as
historical record. Consumers can pin to old versions indefinitely.

Never edit old specs in-place. Never delete old versions.

### Spec file naming

In-tree convention is `specs/cli/<intent>/v<N>.0.0.yaml` where the
directory carries the intent name and the filename carries the version.
This differs from the original drafting where files were named
`<intent>_v<N>.0.0.yaml` in a flat directory.

When migrating new specs, follow the in-tree convention from the start.

## Repository layout

```
lki/
├── README.md                              # Project elevator pitch (placeholder; Maya rewrites)
├── LICENSE                                # Apache 2.0
├── CLAUDE.md                              # This file
├── TOOLING.md                             # Tooling overview (Go packages, binaries)
├── go.mod                                 # Go module: github.com/playgroundlogic/lki
├── .gitignore
│
├── format/v0.<n>/LKI_FORMAT.md            # Format specification per version
│
├── specs/cli/<intent>/v<N>.0.0.yaml       # Intent specifications (CLI category)
│                                          # Versioned files; one per major version
│
├── projections/<intent>/v<N>.0.0/         # Cedar projections from specs
│   ├── schema.cedarschema                 # Entity types and action types
│   ├── policies.cedar                     # Safety floor + baseline + tenant template
│   └── pdp-query.yaml                     # Runtime PDP query shape examples
│
├── types/v0.<n>/                          # Shared type catalog (placeholder; extraction deferred)
├── registries/tools/v0.<n>/               # Tool registry (placeholder; extraction deferred)
│
├── findings/v0.<n>.md                     # Findings per format version (open until next ships)
├── migrations/v0.<n>-to-v0.<n+1>.md       # Migration guides per format transition
├── decisions/v0.<n>-triage.md             # Triage decisions for version transitions
├── design/                                # Forward-looking design docs (not yet specs)
│   └── flight-plan-goalpost.md            # Target user-facing layer above LKI
│
├── cmd/                                   # Tool binaries (Go)
│   ├── cedar-from-lki/                    # Project specs to Cedar artifacts
│   ├── lki-validate/                      # Validate specs against the format
│   └── lki-migrate/                       # Mechanical migrations between versions
│
└── internal/                              # Shared Go packages (not for external import)
    ├── spec/                              # Parse and validate LKI specs
    ├── cedar/                             # Emit Cedar artifacts
    └── projection/                        # Apply Chapter 9 projection rules
```

Directories ending in `/v0.<n>/` are versioned. Directories without
version suffix (`design/`, `migrations/`, etc.) hold cross-version docs
that may reference multiple versions.

## Working with versioned artifacts

| Action | Decision rule |
|---|---|
| Adding new spec for new intent | Start at `v1.0.0` for the spec's intent version, but use the **current** format version's `lki_version` |
| Adding new finding | Append to current `findings/v0.<n>.md`; assign next F-NNN number; tag source |
| Fixing typo in shipped format | Allowed as infrastructure metadata cleanup (link targets, formatting) — not semantic content |
| Adding clarification to shipped format | NO — create new version with the clarification; bump format major version when ready |
| Adding new capability category | Format-spec-level addition; deferred to next format major version |
| Adding new type | Type registry minor version bump (additive); no format spec change required |
| Adding new tool | Tool registry minor version bump; no format spec change required |
| Fixing a bug in projection rules | Format-spec-level; deferred to next format major version unless purely cosmetic |

## Open questions and active design

These are tracked in [findings/v0.2.md](findings/v0.2.md) but worth
flagging at the project level:

**Substantial design work for v0.3:**
- **F-034** — Compute capability breach handling (soft bounds, approval, budget pools, throttling, degradation)
- **F-035** — Shell built-ins as Tool entities (write_file uses printf as builtin; format doesn't distinguish)
- **F-036** — Recursion in conditional cases for capability declarations (write_file's three state_mutation entries pattern is verbose)
- **F-037** — Map iteration in interpolation grammar (fetch_url's HTTP headers, future env vars / query params)
- **F-038** — FilePath observed attributes incomplete (`/proc`, `/sys`, `/dev` not categorized; `/home/<other>` not detected)

**Concrete next-phase work:**
- **Flight plan compiler** — translates 25-line user-facing flight plans into LKI/Cedar substrate constraints. See [design/flight-plan-goalpost.md](design/flight-plan-goalpost.md).
- **`cedar-from-lki`** — deterministic projection tool per Chapter 9 of the format spec
- **`lki-validate`** — spec validation against the format spec
- **`lki-migrate`** — automated mechanical migrations between format versions
- **Cast runtime (gauntlet)** — manages cast lifecycle, stoop counter, recall triggers, audit log emission
- **Agenkit integration** — wires LLM tool calls to LKI intent invocations

## Vocabulary

LKI uses two parallel vocabularies that map to the same substrate:

**Technical vocabulary** (in the format spec):
- *Intent* — a single agent-invokable operation
- *Capability* — what an intent needs (network, filesystem, state mutation, etc.)
- *Resolver* — runtime that resolves intents to executable commands via PDP
- *PDP* — Cedar Policy Decision Point
- *Audit entry* — single record of one intent invocation
- *Projection* — derived Cedar artifacts from an LKI spec

**Working vocabulary** (the falconry stack, adopted but not yet
formalized in spec):
- *Eyrie* — control plane (where humans live)
- *Mews* — agent registry (where birds live between flights)
- *Gauntlet* — execution runtime (where the agent perches and runs)
- *Jess* — Cedar policy binding per capability category
- *Swivel* — policy composition / PDP join point
- *Bewits* — Sigstore attestations of agent identity
- *Hood* — agent dormant state; unhood to ready
- *Cast* — one flight; bounded execution with goal, jess set, recall condition
- *Stoop* — single tool invocation; a cast contains many stoops
- *Thwarted stoop* — Cedar-denied tool invocation
- *Quill* — single audit log entry (not "pawprint" — that was an error)
- *Lure* — eval harness
- *Quarry* — structured goal (≠ prompt; quarry is contract, prompt is briefing)
- *Falconer* — human operator
- *Austringer* — privileged operator (policy author) — under review; obscure term
- *Yarak* — agent ready state — under review; falconry-niche

Use working vocabulary in prose, design docs, and the README. Use
technical vocabulary in format specs, intent specs, and code. They
don't need to be unified.

Strategic positioning: the falconry framing is "partnership under
known terms" — Cedar policies are constitutive of the relationship,
not restraints on a manipulator. This inverts the OpenHands/OpenClaw
defensive framing. Demo target: "a real OpenClaw that just can't
wreck your filesystem or blithely give out your SSN."

## Companion projects

LKI lives in an ecosystem of related Playground Logic projects:

- **agenkit** ([github.com/playgroundlogic/agenkit](https://github.com/playgroundlogic/agenkit)) — the agent runtime that will consume LKI specs. LKIAgent + CedarMiddleware are the planned integration points.
- **attest** ([github.com/provabl/attest](https://github.com/provabl/attest)) — compliance compiler with Cedar runtime enforcement. Shares architectural DNA with LKI (Cedar projection patterns, policy templates).
- **queryabl** ([github.com/playgroundlogic/queryabl](https://github.com/playgroundlogic/queryabl)) — coordinate-native data platform. LKI's audit logs are natural input to Queryabl's substrate; gap not yet bridged.
- **endless** — temporal/episodic memory for agents. LKI provides single-invocation records; endless provides cross-time persistence.

Cross-project conventions: Apache 2.0, Go-first for runtime, YAML for
specs, semver everywhere, immutability discipline for versioned artifacts.

## What is explicitly out of scope

To prevent scope creep:

- **Tool-SI training** is not required for LKI to function. It's a
  future optimization for high-volume intents where measurement
  justifies the training cost. Foundation models consume LKI specs
  directly. Don't propose Tool-SI integration as part of any v0.x
  release; it's separate work, downstream.
- **Multi-cloud capability variations.** LKI specs describe operations,
  not cloud-specific variations. If an intent has cloud-specific
  behavior, that's an implementation detail captured in the
  `implementation:` section, not a format concern.
- **Cross-language SI variants.** Aspirationally interesting; not v0.x.
- **Runtime budget enforcement subtleties** beyond Cedar binary Allow/Deny.
  Deferred to v0.3 (F-034). Hard bounds work today.
- **Distributed and multi-host operations.** Deferred to future (P-006).
- **Composition of intents** (one intent that invokes others). Each
  composed operation is its own intent in v0.x; explicit composition
  deferred.

If a request would expand scope beyond the above, surface that
explicitly rather than just implementing — the project benefits from
being narrow.

## Working tone

The project is engineered. Prose is concrete, evidence-driven, candid
about limitations. Avoid marketing language; avoid hedging that
obscures actual claims; avoid bullet point lists where prose conveys
the same content better.

When in doubt, write less. The format spec is dense by necessity; most
documentation should be lighter than the spec. Tables and structured
formatting are fine when they convey relationships that prose
obscures.

For commit messages, the convention is short imperative summary
followed by paragraphs of context. Example from the v0.2 cross-ref
cleanup:

```
Fix cross-reference link targets to use in-tree paths

The v0.2 corpus was originally drafted in a flat directory; cross-references
between documents used the flat filenames. When organizing into the repo's
directory structure, link targets needed updating to reflect the in-tree
layout. Display text retains the original filenames for historical context;
only link targets are updated.

Affected files: 4
```

## When to update this file

This file evolves as project conventions evolve. Edit it when:
- A discipline rule changes (rare)
- A new top-level project component is added
- A vocabulary term is added or retired
- A significant repository layout change happens
- Scope is explicitly added or removed

Don't edit this file for transient state (specific findings count,
specific sprint goals, etc.) — that lives in [findings/](findings/) and
[design/](design/).
