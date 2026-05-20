# Flight Plan — Goal Post Sketch

**Status:** Working draft; goal post, not specification
**Date:** 2026-05-19
**Purpose:** Capture the target user-facing layer above the LKI substrate
so subsequent work has something concrete to aim at. Revise as the picture
sharpens.

## The premise

The LKI/Cedar substrate we've built (v0.2 format spec, seven migrated
specs, two cedar projections, audit log structure, resolver pipeline) is
the *enforcement substrate*. It's dense by necessity — Cedar policy
authoring, type catalogs, projection rules, three-axis state mutation
semantics. This density is appropriate for substrate; it's inappropriate
for the surface a human operator sees.

Working backwards from "how does a human declare what an agent is allowed
to do" reveals the missing layer: the **flight plan**. A flight plan is
the operator's contract with a cast — the structured statement of what
the agent should do, where it's allowed to operate, what it costs, and
when to recall it.

The flight plan is to the LKI substrate what a Terraform configuration is
to provider Go code, or what a Kubernetes manifest is to controller logic.
Users write flight plans. The substrate enforces them. The compiler
between is small but architecturally significant — it's where ergonomics
meets rigor.

## What a flight plan looks like

A flight plan is a YAML document. It declares the bird, the falconer, the
quarry (the goal), the scope of permitted action, the budget, and the
recall conditions. Everything else is derived.

### The JSON-to-YAML demo's flight plan

```yaml
quarry: |
  Migrate JSON config files in ./configs/ to YAML.
  Create one .yaml per .json with identical structure.
  Delete the .json files after successful migration.
  Commit the result with message "Migrate configs to YAML".

bird: claude-sonnet-4-5
falconer: scott@playgroundlogic.co

scope:
  workspace: /home/scott/src/configs-demo
  git:
    repo: /home/scott/src/configs-demo
    branch: main
    push: false
  network: deny

budget:
  duration: 10m
  tokens: 50¢
  stoops: 50

recall:
  success_criteria:
    - "All .json files in ./configs/ have corresponding .yaml versions"
    - "Original .json files are removed"
    - "Exactly one git commit was made"
  abort_on:
    - thwarted_stoop: any
    - budget_exhausted: true
    - timeout: true
```

That's 25 lines. A human can write this. A human can read this and *know*
what the agent will be permitted to do.

### What this flight plan compiles into

The substrate below the flight plan is the dense LKI/Cedar machinery the
operator never sees:

- **Filesystem jess** — read/write/delete capability bounded to
  `/home/scott/src/configs-demo` and its descendants. Uses the FilePath
  `is_within_working_dir` observed attribute plus canonical path scope.
  Cedar permit policies for `Filesystem::Read`, `Filesystem::Write`, and
  `Filesystem::Delete` actions are generated; their context restricts
  resources to the workspace.

- **Git jess** — `StateMutation::Write::Git` permitted only for
  `{operation: "commit", resource: GitRepository:"/home/scott/src/configs-demo"}`.
  `push: false` enforced indirectly via no `Network::Outbound` permits
  to git remotes; commit produces local state only.

- **Network deny** — no `Network::Outbound` permits in the cast's
  effective policy. Implicit default-deny means any network stoop is
  thwarted at the swivel.

- **Spend cap** — `Compute::Tokens` with cost-aware bound of 50¢
  worth of tokens at the bird's current pricing. (F-034 territory —
  hard-bound today; soft-bound with breach handling lands in v0.3.)

- **Stoop count** — enforced at the gauntlet runtime, not Cedar.
  Counter increments per intent invocation; cast aborts at 50.

- **Duration cap** — runtime timeout; cast aborts at 10 minutes
  wall-clock.

- **Recall on thwarted stoop** — runtime watches PDP decisions; any
  Deny triggers cast termination after the current quill is emitted.

- **Quill emission** — every stoop emits one audit log entry per
  Chapter 10 schema, regardless of outcome.

The compiler translating flight plan → substrate is probably a few
hundred lines of Go. The dense work is the substrate; the compiler is
the small bridge.

## What the falconer sees during a cast

The demo's experience, from the falconer's perspective:

1. **Author the flight plan** — 25 lines of YAML, as above. Validated
   at submission (well-formed, references known bird, scope paths
   exist, falconer is authenticated, etc.).

2. **`gauntlet cast --plan flight.yaml`** — the gauntlet acknowledges
   the cast, prints the cast ID, and begins.

3. **Live quill emission** — each stoop produces a one-line summary
   on stdout (or in the eyrie web UI when that exists):

   ```
   cast/8f2a3b4c stoop/01 Filesystem::Read /home/scott/src/configs-demo/configs/   ALLOW   3ms
   cast/8f2a3b4c stoop/02 Filesystem::Read /home/scott/src/configs-demo/configs/db.json   ALLOW   2ms
   cast/8f2a3b4c stoop/03 Filesystem::Write /home/scott/src/configs-demo/configs/db.yaml   ALLOW   4ms
   cast/8f2a3b4c stoop/04 Filesystem::Read /home/scott/src/configs-demo/configs/api.json   ALLOW   2ms
   cast/8f2a3b4c stoop/05 Filesystem::Write /home/scott/src/configs-demo/configs/api.yaml   ALLOW   3ms
   cast/8f2a3b4c stoop/06 Filesystem::Delete /home/scott/src/configs-demo/configs/db.json   ALLOW   2ms
   cast/8f2a3b4c stoop/07 Filesystem::Delete /home/scott/src/configs-demo/configs/api.json   ALLOW   2ms
   cast/8f2a3b4c stoop/08 Network::Outbound api.openai.com:443/https   THWART   policy: no-network-permitted
   cast/8f2a3b4c recall  thwarted_stoop
   ```

4. **Inspect the trail** — `gauntlet quills --cast 8f2a3b4c` shows
   the full audit entries per Chapter 10 schema, content-addressed,
   queryable. The thwarted stoop entry includes the determining policy
   and the policy's rationale.

## Why this demo lands

The demo is "a real OpenClaw that just can't wreck your filesystem
or blithely give out your SSN." Same agent surface, same kinds of
tasks. The structural difference shows up *only* when the agent tries
to do something the substrate prevents — and then the explanation is
right there in the quill.

The moment of failed comparison is the dramatic beat: "wait, why
didn't it do the thing OpenClaw would have done here?" Because Cedar
said no, and the audit trail explains exactly why. The novelty isn't
in what the agent *does*; it's in what it *can't* do — and the
explanation for the can't.

This frames Cedar policies as *constitutive of the partnership*,
not as restraints on a manipulator. Every jess is a clause. Every
quill is evidence of compliance. The safety story isn't defensive,
it's relational.

## What needs to be built (the gap from v0.2 to this demo)

| Component | Existing | Needed |
|---|---|---|
| LKI substrate | ✓ (v0.2 spec, 7 migrated specs, 2 projections) | — |
| Cedar PDP integration | partial (projection examples exist) | wire up actual Cedar evaluator |
| Flight plan format | this doc sketches it | formal spec when stable |
| Flight plan compiler | — | flight plan → effective Cedar policy + runtime constraints |
| Cast runtime (gauntlet) | — | manages cast lifecycle, stoop counter, timeout, recall triggers |
| Bird registration (mews) | — | mechanism for declaring which LLM, with what attestations, is callable as an agent |
| Quill viewer | — | CLI is fine for demo (`gauntlet quills --cast <id>`); web UI later |
| Agent → LKI integration | — | wire LLM tool calls to LKI intent invocations |

The substrate work is done. The remaining work is *integration and user
surface* — substantial but bounded.

## What this lets us defer

The goal post lets us scope decisions cleanly. Things that don't bring
us closer to this demo are deferred:

- **Tool-SI training** — not needed for v0.2 demo; foundation models
  consume LKI specs directly per Chapter 1
- **Pagination and streaming** (F-016) — demo uses bounded mode only
- **Three pagination variants per intent** — defer until needed
- **breach_handling** (F-034) — hard-bound budget is fine for demo
- **endless integration** — gap detection not required for v2.0.0 specs
- **Map iteration in templates** (F-037) — the demo doesn't exercise
  HTTP headers, so this can wait
- **Capability conditional cases** (F-036) — the demo's specs already
  ship with multi-entry workarounds
- **`is_pseudo_filesystem` and related FilePath attributes** (F-038) —
  the demo workspace is in user space, no /proc or /dev concerns

That's a substantial deferral list, and it's all real work that v0.3+
will address. None of it blocks the demo.

## Audience layering implied by this design

Three layers, three audiences:

| Layer | Artifact | Audience |
|---|---|---|
| **User-facing** | Flight plans | Falconers (operators casting agents) |
| **Policy-authoring** | Cedar tenant templates | Austringers (privileged operators / platform admins) |
| **Substrate** | LKI specs, type catalog, tool registry, projection rules | Maintainers (us, and eventual contributors) |

Most operators only see the flight plan. They never write Cedar; they
never write LKI specs. The substrate is dense because it has to be —
but the dense work is invisible at the user surface.

This is the same factoring as Terraform (HCL for users; provider Go
code for maintainers), Kubernetes (YAML manifests for users; controller
code for maintainers), or any other infrastructure-as-code stack with a
substantial substrate. The pattern is validated; we're applying it to
the agent-runtime domain.

## Natural-language entry point (future)

The flight plan format is structured but human-readable. Above it, an
LLM-mediated layer could translate natural language into a draft flight
plan:

> *"Migrate the JSON configs in this directory to YAML, commit when
> done, don't touch anything else, ten minute timeout"*

→

```yaml
quarry: "Migrate JSON configs in ./configs/ to YAML, commit the result"
scope: { workspace: ./configs, git: {commit: true, push: false}, network: deny }
budget: { duration: 10m }
# ... etc
```

The translation is LLM-mediated; the resulting flight plan is then
human-reviewed and the substrate enforcement is deterministic. Natural
language enters the system *above* the substrate; the substrate stays
verifiable. This is the right factoring for AI-mediated tooling on top
of verified infrastructure.

Not v1. Not v2. But the architecture accommodates it cleanly, which is
what matters now.

## Open questions to revisit

- **What's the falconry term for the moment an agent transitions from
  hooded to flying?** "Unhooding" covers the state change; not sure
  there's a discrete term for the threshold crossing event. Worth
  asking someone who actually does falconry.

- **Should `quill` be the audit log term?** It replaces the
  inadvertent `pawprint`. Alternatives: footing (taken; means talon
  grip), casting (taken; means regurgitated pellet), trace (generic),
  mark (too generic). Quill is my current pick — fine-grained,
  authoritative, ties to falcon + writing. Tentative.

- **Is `austringer` worth the cognitive cost?** It's accurate but
  obscure. Alternatives for the policy-authoring role: master falconer,
  or just "admin" with a falconry-themed UI label.

- **Does the demo include destructive operations (delete .json
  files), or just additive ones (create .yaml files)?** Destructive
  makes the policy story stronger — Cedar permits delete only within
  workspace, would deny attempts outside. Adding it.

- **Is the bird Claude Sonnet 4.5, or a smaller specialized model?**
  Sonnet for the demo to keep it real. Smaller models for later
  cost-efficient cases.

- **Web UI (eyrie) — when?** Not for the demo. CLI suffices. Eyrie is
  v2 territory.

## What this document is and isn't

This is a **goal post**. It captures the target so subsequent work has
something to aim at. It's not a specification — the flight plan format
will get formalized once the compiler is being built and the format's
edges are stable.

It's also a **scoping tool**. Anything not in service of this demo can
be deferred without anxiety. Anything that brings the demo closer is
in scope. That clarity is the document's primary value right now.

Revise when the picture sharpens. The format will change; that's fine.
The architecture sketched here is the stable part.
