# LKI Format Specification v0.2

**Status:** Stable
**Format version:** `0.2`
**Released:** 2026-05-19
**Predecessor:** [LKI_FORMAT_v0.1.md](../v0.1/LKI_FORMAT.md)
**Migration guide:** [MIGRATION_FROM_v0.1.md](../../migrations/v0.1-to-v0.2.md)
**Findings against this version:** [FINDINGS_v0.2.md](../../findings/v0.2.md)

## What's new from v0.1

v0.2 incorporates 33 findings from v0.1 use, organized as 25 mechanical
integrations and 5 substantive design decisions. The most significant
changes:

- **Structural vs observed entity attributes** (was F-005, F-030): type
  catalog distinguishes attributes guaranteed by the type from attributes
  observed per-request from environment state.
- **Shared type and entity registries** (was F-018, F-031): types and
  entity types referenced by 2+ specs live in shared registries, not
  inline pseudocode or per-spec declarations.
- **Three-axis state mutation semantics** (was F-003, F-025): visibility,
  durability, and reversibility as independent capability attributes.
- **Three pagination modes** (was F-016): bounded, paginated, streamed
  with distinct Cedar projection rules per mode.
- **Resolver constraints separate from capability** (was F-008): non-Cedar
  checks (regex complexity, encoding validation) live in their own section
  rather than polluting the capability section.
- **Conditional cases for templates and capabilities** (was F-009, F-022,
  F-023): single unified expression grammar for both conditional template
  substitution and conditional capability requirements.
- **Render modifiers in interpolation grammar** (was F-011): pipe syntax
  for shell quoting, URL encoding, JSON escape, etc.
- **Resolver pipeline made explicit** (was F-024): canonical ordering of
  validation, encoding, conditional resolution, template substitution.

A full mapping of findings to v0.2 sections is in MIGRATION_FROM_v0.1.md.

---

## Chapter 1 — Purpose and scope

LKI (LLM Knowledge Intent) is a spec format for declaring
agent-invokable operations in a structure that:

1. Aligns intent representation with how LLMs already reason (the LKI
   layer)
2. Projects cleanly to Cedar policy for capability enforcement
3. Resolves to concrete implementations across one or more candidate
   tools
4. Optionally produces training data for specialized Tool-SI models
   when higher reliability than foundation models is justified by
   measurement

A single LKI spec file is the source of truth for one *intent* — a named,
typed, capability-declared operation an agent can request. Cedar policies,
implementation routing, audit log structure, and Tool-SI training data
are derived from the spec; they are not separate artifacts requiring
separate maintenance.

This document defines the format that v0.2 LKI specs conform to. Future
versions will extend or modify; breaking changes bump the major version
of the format itself.

### Tool-SI: what it is, and that it is not required

LKI-based systems work today with foundation models alone. An agent
(using Claude, GPT-4, Gemini, or any capable LLM) emits a structured
intent conforming to an LKI spec; the resolver picks an implementation
and constructs the command per the spec's templates; Cedar PDP gates
execution against derived policy; the audit log records the decision.
Foundation models consume LKI specs as structured input; their
first-pass correctness on the discrete output space LKI provides is
usually adequate for production deployment.

Tool-SI is a *future optional optimization*: small specialized models
trained on the `(intent, expected_command)` pairs from LKI specs,
fine-tuned for higher first-pass correctness than foundation models
achieve on the same task. Tool-SI is appropriate when audit-log
evidence shows specific intents have unacceptable foundation-model
error rates and the volume justifies the training investment. Tool-SI
is *never* a prerequisite for adopting LKI.

The default deployment path is foundation-model-based. Tool-SI is the
upgrade path for the cases where measurement demonstrates it's worth
the training cost. Spec authors do not need to think about Tool-SI
when writing specs — the `examples` and `anti_patterns` sections that
produce Tool-SI training data also serve as documentation, policy test
cases, and LLM few-shot examples. They earn their place in the spec
regardless of whether Tool-SI is ever trained for the intent.

### Intent variants and the hierarchy question

When an operation has variants that differ in policy-relevant ways
(different return types, different streaming behavior, different
side effects), prefer separate intents over parameter-determined
polymorphism. Example: `read_file` (returns string with encoding
parameter) and `read_file_bytes` (returns bytes) are separate intents
with shared anti-patterns and similar capability profiles.

**Naming convention for intent variants:** `<base_intent>_<variant_axis>`.
Examples: `read_file_bytes`, `read_file_streaming`, `fetch_url_streaming`,
`commit_changes_bypass_hooks`. The base intent represents the most
common case; variants are named for what differs.

**Cedar projection rule for variants:** Separate intents share Cedar
actions when the capability semantics are identical and only
output/processing differs. They get distinct actions only when
capability semantics actually differ. `read_file` and `read_file_bytes`
both project to `Filesystem::Read` because the access pattern is
identical; the difference is in the resolver's processing of the result.
Cedar policies can differentiate via the `intent_name` context attribute
when needed.

**Hierarchical intents as a format feature** are deferred to v0.3 or
later. v0.2 documents the variant pattern and naming convention but
does not provide format-level inheritance. When 5+ sister-intent
families exist, the format may evolve to support explicit hierarchy.
Until then: shared elements (common anti-patterns, common capability
patterns) use registry references (see Chapter 5: Type and entity
catalog).

---

## Chapter 2 — Versioning

LKI uses **four** independent versioning regimes in v0.2 (one more
than v0.1). The added regime tracks shared type and entity registries.

### 2.1 Format version

Top-level field on every spec:

```yaml
lki_version: "0.2"
```

Format version bumps on:
- New required sections
- Removal of sections
- Breaking changes to interpolation grammar or expression grammar
- Breaking changes to the type catalog or entity model
- Breaking changes to capability declaration structure
- Breaking changes to cedar projection rules

Format version does NOT bump on:
- Addition of optional sections
- Addition of new types to the catalog (additive only)
- Addition of new render modifiers (additive only)
- Addition of new capability sub-categories (additive only)
- Clarifications to wording without semantic change

### 2.2 Intent version

Each intent declares its own semver:

```yaml
spec:
  intent: fetch_url
  intent_version: "2.0.0"
```

Required on every spec. Consumers can pin: `fetch_url@^2.0` means
"any 2.x of fetch_url, do not auto-apply breaking changes in 3.0."

Intent version bumps:
- **Major** (3.0.0 ← 2.x.x): Signature changes (parameter added without
  default, parameter removed, parameter type changed), capability
  requirement changes (new capabilities added, removed, or changed
  semantically), behavior semantics changed
- **Minor** (2.1.0 ← 2.0.x): New optional parameters with defaults,
  new implementation tools added, new examples added, new anti-patterns
  documented, new internal_behaviors documented
- **Patch** (2.0.1 ← 2.0.0): Description text changes, typo fixes,
  example wording improvements, anti-pattern reason rewording — no
  semantic change

Tool-SI training data is keyed by `(intent_name, intent_version)`.
Major bumps require training data regeneration; minor and patch bumps
do not invalidate existing training data.

### 2.3 Tool version pinning

Implementation section declares minimum and tested-against versions:

```yaml
implementation:
  - tool: curl
    requires: "curl >= 7.50"
    tested_against: ["curl 7.x", "curl 8.0 - 8.4"]
```

Versions can be:
- Exact: `"curl 7.81.0"`
- Major range: `"curl 7.x"` (any 7.x patch level)
- Bounded range: `"curl 8.0 - 8.4"` (8.0.0 through 8.4.x inclusive)
- Open range: `"curl >= 7.50"` (any version 7.50 or later)

Resolvers may warn or refuse when a tool's available version is:
- Below `requires` (refuse — known incompatibility)
- Above the highest `tested_against` (warn — unverified)
- Outside the `tested_against` range entirely (warn or refuse,
  configurable)

### 2.4 Type and entity registry versions (new in v0.2)

Shared types and entities (Chapter 5) carry their own versions:

```yaml
# in types/v0.2/FilePath.lki.yaml
type:
  name: FilePath
  type_version: "1.0.0"
```

Specs reference these by name and version:

```yaml
# in a spec
signature:
  inputs:
    - name: path
      type: FilePath@1.x   # any 1.x of FilePath
```

Registry version bumps follow the same semver rules as intent versions:
- Major: removing or renaming attributes; changing attribute types
- Minor: adding new optional attributes; adding new methods
- Patch: documentation changes

Adding a new attribute to a shared type is a minor version bump on the
type. Specs that don't reference the new attribute continue working
unchanged. Specs that want the new attribute bump their type reference
to the new minor version.

### 2.5 Combined reference example

A fully-pinned reference looks like:

```yaml
lki_version: "0.2"
spec:
  intent: fetch_url
  intent_version: "2.0.0"
  signature:
    inputs:
      - name: url
        type: URL@1.x
      - name: output
        type: FilePath@1.x
        optional: true
  implementation:
    - tool: curl
      requires: "curl >= 7.50"
      tested_against: ["curl 8.x"]
```

The tuple `(lki_version, intent_version, type_versions, tool_versions)`
fully describes the reproducibility envelope. Environments matching
all four can reproduce behavior; mismatches in any are warnings or
errors at resolver load time.

---

## Chapter 3 — Spec file structure

Every LKI v0.2 spec is a YAML document with this top-level skeleton:

```yaml
lki_version: "0.2"

spec:
  intent: <snake_case_identifier>
  intent_version: "<semver>"
  description: <one-line summary>

  signature:
    inputs: [<typed parameter list>]
    output: <type reference>

  behavior: |
    <multi-line description of what the intent does>

  constraints:
    parameter_constraints: [...]      # per-parameter validity rules
    cross_parameter_constraints: [...]  # rules involving multiple parameters

  capability: {...}              # Cedar-projectable capability requirements

  resolver_constraints: {...}    # checks the resolver enforces before PDP

  internal_behaviors: {...}      # hooks, retries, cache lookups, etc.

  implementation: [...]          # one or more implementation candidates

  examples: [...]

  anti_patterns: [...]
```

### 3.1 Required vs optional sections

**Required on every spec:**
- `lki_version`
- `spec.intent`
- `spec.intent_version`
- `spec.description`
- `spec.signature`
- `spec.behavior`
- `spec.capability` (may be empty list if no capabilities required, but
  the section must exist)
- `spec.implementation` (minimum one entry)

**Optional but strongly recommended:**
- `spec.constraints` (both subsections)
- `spec.examples` (minimum 3 for documentation, few-shot, and policy
  testing purposes)
- `spec.anti_patterns` (minimum 2 for policy test coverage)
- `spec.resolver_constraints` (often empty; required only when the
  intent has non-PDP checks)
- `spec.internal_behaviors` (often empty; required when the intent has
  documented side behaviors like hooks)

### 3.2 Constraint placement (resolves F-013)

Constraints fall into three categories with clear placement rules:

**Parameter-level constraints** live inside the parameter definition:

```yaml
inputs:
  - name: timeout
    type: Duration@1.x
    default: 30s
    constraint: "must be <= 300s"
```

These rules involve only the single parameter. Validation happens at
intent construction time before any other processing.

**Cross-parameter constraints** live in `constraints.cross_parameter_constraints`:

```yaml
constraints:
  cross_parameter_constraints:
    - description: "If method is HEAD, output cannot be specified"
      rule: "method == HEAD implies output is null"
    - description: "atomic mode requires write permission to parent"
      rule: "atomic == true implies path.parent is_writable"
```

These rules involve multiple parameters or relate parameters to
environment state. Validation happens at intent construction time
after individual parameter validation passes.

**Behavioral constraints** are documented in `behavior` prose, not in
a machine-parseable section:

```yaml
behavior: |
  Issue a single HTTP(S) request to url and return the response body.
  Fails fast on 4xx/5xx without retry. Response body is treated as
  opaque bytes; never piped to another tool or executed.
```

Behavioral constraints describe semantic properties of the intent's
execution that aren't validation rules but are part of the contract.
They are normative for spec authors and resolver implementers but not
checked mechanically.

### 3.3 Conditional capability requirements (resolves F-023)

Capabilities can be conditional on parameter values via `required_if:`:

```yaml
capability:
  filesystem:
    - operation: write
      paths: ["{output}"]
      required_if: "output is not null"
```

The `required_if` value is an expression in the v0.2 condition grammar
(Chapter 6 — Interpolation and Expression grammar). The same grammar
serves conditional template cases.

If the condition evaluates to false at intent construction time, the
capability is not declared as needed, and no PDP query is made for it.

---

## Chapter 4 — Spec file structure (continued): Sections in detail

### 4.1 The `signature` section

```yaml
signature:
  inputs:
    - name: <identifier>
      type: <type reference, e.g. URL@1.x or local type name>
      optional: <bool, default false>
      default: <value, requires optional or distinct default behavior>
      constraint: <single-parameter constraint string>
      description: <human description>
      is_resource_bound: <bool, default false>   # see Chapter 7
  output:
    type: <type reference>
```

The `is_resource_bound: true` annotation marks parameters that cap
resource use (max_size, max_entries, timeout, max_pattern_complexity).
Cedar policies can write rules over resource_bound parameters
specifically. See Chapter 7 (Capability section) for how this projects.

### 4.2 The `behavior` section

Free prose describing what the intent does. Required. No format
constraints beyond YAML multi-line string. Behavioral constraints
(see 3.2) belong here.

### 4.3 The `constraints` section

Two required subsections (both may be empty lists):

```yaml
constraints:
  parameter_constraints:
    # Optional - prefer inline `constraint:` on parameters when the
    # constraint involves only that parameter. This subsection is for
    # constraints that don't fit inline (formatting, multi-line, etc.)
    - parameter: timeout
      rule: "must be <= 300s"
  cross_parameter_constraints:
    - description: "If method is HEAD, output cannot be specified"
      rule: "method == HEAD implies output is null"
```

In practice most parameter constraints stay inline; the
`parameter_constraints` subsection is mostly empty in real specs. The
two-subsection structure exists so tooling can mechanically extract
all constraints.

### 4.4 The `capability` section

Cedar-projectable capability requirements. See Chapter 7 for details.
Skeleton:

```yaml
capability:
  network: [...]
  filesystem: [...]
  process: [...]
  state_mutation: [...]
  compute: [...]
  access_grant: [...]    # new in v0.2 (was F-026, partially)
```

All sub-sections are optional; specs declare only the categories they
need. Each entry within a sub-section is one capability requirement.

### 4.5 The `resolver_constraints` section (new in v0.2)

Non-Cedar checks the resolver enforces *before* PDP is consulted.
These are validation and safety constraints that can't be expressed
as Cedar policy because Cedar's semantics don't reason about them.

```yaml
resolver_constraints:
  pattern_complexity:
    - parameter: pattern
      rule: "no nested quantifiers when grammar is perl"
      reason: "ReDoS prevention"
  encoding_validation:
    - parameter: content
      rule: "must decode successfully using {encoding}"
      reason: "Prevent partial-write on encoding failure"
  shell_metacharacter_rejection:
    - parameter: paths
      rule: "no shell metacharacters in path strings"
      reason: "Prevent shell injection in templates"
```

Resolver constraints fail the intent atomically before any PDP query
is constructed. The error returned to the caller identifies which
resolver constraint failed.

### 4.6 The `internal_behaviors` section (new in v0.2)

Documents behaviors the intent performs internally that aren't direct
capability uses but matter for transparency. v0.2 introduces this
section with a small initial vocabulary; v0.3 may formalize further.

```yaml
internal_behaviors:
  hook_execution:
    - description: "git pre-commit and commit-msg hooks run if installed"
      controllable_via_parameter: false   # cannot be disabled in this intent
      policy_relevance: "hooks may modify or reject the commit"
  cache_lookup:
    - description: "DNS lookups cached at OS level"
      controllable_via_parameter: false
      policy_relevance: "DNS cache poisoning is out of scope"
  retry:
    - description: "No automatic retry on transient failure"
      controllable_via_parameter: false
      policy_relevance: "Caller must retry; intent is single-attempt"
```

Internal behaviors are informational. They appear in audit logs (so
policy auditors can see what happened) but Cedar policies cannot deny
them directly. If denying or constraining a behavior is needed, it
must be promoted to a capability declaration.

### 4.7 The `implementation` section

See Chapter 8 (Implementation section) for full detail. Skeleton:

```yaml
implementation:
  - tool: <tool name>
    priority: <int, higher is preferred>
    requires: <version constraint>
    tested_against: [<version list or ranges>]
    working_directory: <FilePath expression, optional>
    template:
      <static template OR cases-based conditional template>
    parameter_mapping: {...}
    notes: <optional notes>
    limitations: [<optional limitations>]
```

### 4.8 The `examples` section

Each entry is a `(intent, expected_command)` pair:

```yaml
examples:
  - description: <human summary>
    intent:
      <parameter>: <value>
    expected_command: |
      <literal string the resolver should produce>
    notes: <optional explanation>
```

Examples serve four simultaneous purposes (documentation, LLM few-shot
context, policy test cases, Tool-SI training data — see Chapter 1's
Tool-SI subsection).

### 4.9 The `anti_patterns` section

Each entry documents a known bad usage:

```yaml
anti_patterns:
  - bad: <the bad form>
    reason: <why this is bad>
    rejection: <which layer of enforcement catches it>
```

Same structure as v0.1. Anti-patterns serve as documentation, test
cases for enforcement layers, and (when Tool-SI is trained) negative
training signal.

---

## Chapter 5 — Type and entity catalog

v0.2 separates *types* (parameter and output types) from *entities*
(Cedar resource entities used in policy). Both have shared registries.

### 5.1 Type registry organization

Types referenced by 2+ specs live in `types/v0.x/<TypeName>.lki.yaml`.
Types unique to one spec are declared at the top of that spec in a
`types:` section.

Promotion from per-spec to shared: any type referenced by ≥2 specs
should migrate to the shared registry. The `cedar-from-lki` tooling
detects unmigrated cross-spec types and warns.

A shared type declaration:

```yaml
# types/v0.2/FilePath.lki.yaml
lki_version: "0.2"
type:
  name: FilePath
  type_version: "1.0.0"
  description: "Filesystem path with safety canonicalization"
  
  structural_attributes:
    canonical:
      type: string
      description: "Canonicalized form (resolved, normalized)"
    is_absolute:
      type: bool
    parent:
      type: FilePath
      description: "Path of the containing directory"
    basename:
      type: string
    extension:
      type: string
  
  observed_attributes:
    is_system_path:
      type: bool
      description: "True for /etc, /usr, /bin, /sbin, /var, /boot, /lib, /lib64 trees"
    is_within_working_dir:
      type: bool
      description: "True if path is descendant of principal's working_dir"
    exists:
      type: bool
      description: "True if path resolves to an existing filesystem entry"
    is_writable_by_policy:
      type: bool
      description: "True if filesystem allows writes (independent of LKI policy)"
  
  methods:
    canonicalize:
      returns: FilePath
      description: "Returns the canonicalized form; resolves .. and symlinks"
    is_within:
      returns: bool
      parameters:
        - name: other
          type: FilePath
      description: "True if this path is a descendant of other"
  
  parse_rules:
    - rule: "Shell metacharacters ($, `, ;, |, &, <, >, *, ?, [, newline) rejected at parse"
    - rule: "Empty path string rejected"
    - rule: "Path length must be <= PATH_MAX (typically 4096)"
```

### 5.2 Structural vs observed attributes (resolves F-005, F-030)

The split is load-bearing for policy authors:

**Structural attributes** are guaranteed by the type definition. They
are stable for the entity's identity — `canonical` doesn't change for
a given FilePath; `parent` is deterministic from the path. Policies
over structural attributes are time-independent.

**Observed attributes** are populated at request construction time
from environment state. `is_system_path` depends on the path string
(structural-ish) but more importantly, `exists` and `is_within_working_dir`
depend on filesystem state and principal context. Policies over
observed attributes have TOCTOU implications: the observation was made
at construction time, but the intent executes some time later.

The format spec requires authors to declare which category each
attribute belongs to. Tooling can warn policy authors when they
write rules referencing observed attributes in ways that assume
durability.

### 5.3 Per-spec type declarations

When a type is used only in one spec, declare it inline:

```yaml
# in a spec file
spec:
  intent: list_directory
  intent_version: "2.0.0"
  
  types:
    DirectoryEntry:
      type_version: "1.0.0"
      structural_attributes:
        name:
          type: string
        path:
          type: FilePath@1.x
        type:
          type: enum<file, directory, symlink, other>
        is_hidden:
          type: bool
      observed_attributes:
        size:
          type: Bytes@1.x
```

If `DirectoryEntry` later appears in a second spec, the v0.2 tooling
detects the duplication and the type migrates to the shared registry.

### 5.4 Entity catalog organization

Cedar entities (the things Cedar policies write rules over) live in
`types/v0.x/entities/<EntityName>.lki.yaml`. Each entity type
corresponds to one or more capability resources.

```yaml
# types/v0.2/entities/GitRepository.lki.yaml
lki_version: "0.2"
entity_type:
  name: GitRepository
  entity_type_version: "1.0.0"
  description: "Git working tree, identified by canonical root path"
  identity:
    field: canonical_path
    type: string
  
  structural_attributes:
    canonical_path:
      type: string
  
  observed_attributes:
    working_dir_rooted:
      type: bool
      description: "True if repo is within principal's working_dir"
    current_branch:
      type: string
    has_uncommitted_changes:
      type: bool
    is_detached_head:
      type: bool
    has_in_progress_operation:
      type: bool
      description: "rebase, merge, cherry-pick, bisect in progress"
    remote_count:
      type: int
```

Entity types are referenced from `capability` declarations:

```yaml
# in a spec
capability:
  state_mutation:
    - operation: write
      resource_type: GitRepository@1.x
      resource_identifier: "{repository_path.canonical}"
```

### 5.5 Primitive types

v0.2 ships these primitive types (declared in
`types/v0.2/primitives/`):

| Type | Description | Structural attributes | Methods |
|------|-------------|----------------------|---------|
| `string` | UTF-8 text | none | `.length`, `.is_empty` |
| `int` | 64-bit signed integer | none | `.abs`, `.sign` |
| `float` | 64-bit IEEE 754 | none | `.abs`, `.sign`, `.rounded` |
| `bool` | true/false | none | none |
| `bytes` | byte sequence | none | `.length`, `.base64` |

Primitives have no observed attributes (they're pure values, not
environmental observations).

### 5.6 Structured types shipped with v0.2

In addition to primitives, v0.2 ships these structured types in
`types/v0.2/`:

- `URL` — RFC 3986 URI with `.scheme`, `.host`, `.port`, `.path`,
  `.query`, `.fragment` structural; `.is_loopback`, `.is_private`,
  `.is_metadata` observed
- `FilePath` — see 5.1
- `Duration` — time duration with `.seconds`, `.milliseconds`,
  `.iso8601` methods
- `Regex` — typed regex with declared grammar; `.grammar` structural,
  `.complexity_class` observed (computed by resolver constraints)
- `Bytes` — byte count for resource bounds; `.kb`, `.mb`, `.gb`,
  `.bytes` methods

### 5.7 Compound types shipped with v0.2

- `list<T>` — homogeneous list, `.length` method, list-flatten
  interpolation
- `map<K,V>` — string-keyed map, `.keys`/`.values`/`.entries` methods
- `enum<A,B,C>` — bounded enumeration
- `union<A | B | C>` — sum type, used for return types when multiple
  output shapes are possible

### 5.8 Adding new types

Adding a new shared type:
1. Create `types/v0.x/<TypeName>.lki.yaml`
2. Declare type_version starting at 1.0.0
3. Update any specs that should use it (intent_version minor bump)

Adding a new attribute to an existing shared type:
1. Bump type_version's minor (e.g., 1.0.0 → 1.1.0)
2. Specs not using the new attribute continue working with `@1.x`
   reference unchanged
3. Specs wanting the new attribute update reference to `@1.1.x`

Removing or renaming an attribute on an existing shared type:
1. Bump type_version's major (1.x.x → 2.0.0)
2. Specs must update to reference @2.x explicitly
3. v1.x version remains available for backward compatibility through
   the v0.x format major version

---
## Chapter 6 — Interpolation and expression grammar

v0.2 unifies what v0.1 had as two ad-hoc grammars (interpolation in
templates, informal expressions in `required_if` conditions) into two
related grammars that share their parameter reference primitives. This
resolves F-009 (conditional template parameters), F-011 (render
modifiers), F-022 (multi-discriminator cases), and F-023 (conditional
capability expression grammar).

### 6.1 Two grammars, one parameter reference vocabulary

**Interpolation grammar** produces strings by substituting parameter
values into templates. Used in `implementation.template`,
`implementation.parameter_mapping`, and capability resource
identifiers (e.g., `paths: ["{path.canonical}"]`).

**Expression grammar** produces booleans by evaluating predicates over
parameter values. Used in `required_if`, conditional template `when:`
clauses, and `cross_parameter_constraints`.

Both grammars use the same primitives for referencing parameters and
their attributes/methods. The difference is in their composition
operators: interpolation composes via render modifiers and list
flattening; expression composes via boolean and comparison operators.

### 6.2 Shared parameter reference primitives

Both grammars support these forms for referring to parameters:

**Plain reference:**
```
name
```
Refers to the value of parameter `name`. In interpolation, written as
`{name}` to mark substitution boundary; in expression, written bare.

**Attribute access:**
```
name.attribute_name
```
Accesses a structural or observed attribute of the parameter's type.
Type catalog declares which attributes each type has.

**Method invocation (no arguments):**
```
name.method_name
```
Calls a parameterless method. v0.2 does not support method arguments;
methods that would need arguments are declared as separate methods or
as type-level operations.

**List indexing (interpolation only):**
```
name[separator]
```
Renders a list parameter by joining elements with the given separator.
Default separator is single space. Used only in interpolation; in
expression grammar, list operations use `.length`, `.contains`, `in`.

### 6.3 Interpolation grammar

The interpolation grammar produces strings via substitution. Used in
templates, parameter_mapping values, and capability resource
identifiers.

#### 6.3.1 Substitution forms

**Plain substitution:** `{name}`

Substitutes the parameter's value using its type's default string
representation.

**Attribute substitution:** `{name.attribute}`

Substitutes the value of the named attribute.

**Method substitution:** `{name.method}`

Substitutes the result of the parameterless method.

**List flatten:** `{name[separator]}`

For list-typed parameters, renders each element separated by the given
separator (default space).

#### 6.3.2 Render modifiers (resolves F-011)

Render modifiers transform the substituted value through a pipe syntax:

```
{name|modifier}
{name.attribute|modifier}
{name|modifier1|modifier2}
```

Modifiers compose left-to-right. v0.2 ships these standard modifiers:

| Modifier | Effect |
|----------|--------|
| `shell_quoted` | Single-quote the value, escape embedded single quotes |
| `shell_quoted_double` | Double-quote the value, escape embedded double quotes and `$`, `` ` ``, `\` |
| `url_encoded` | Percent-encode the value per RFC 3986 |
| `json_escaped` | Escape for JSON string context (no surrounding quotes) |
| `yaml_quoted` | YAML-safe quote, choosing single/double/literal as appropriate |
| `base64` | Base64-encode the byte value |
| `hex` | Hex-encode the byte value |
| `regex_escaped` | Escape regex metacharacters in the string |
| `null_to_empty` | If value is null/absent, render empty string instead of failing |

Adding a new modifier is non-breaking for the format version (additive
only). Modifier names are reserved namespace; spec authors cannot
define custom modifiers in v0.2 (deferred to v0.3+).

#### 6.3.3 What's not supported in v0.2 interpolation

- Nested interpolation (`{outer{inner}}`) — produces unclear semantics
- Recursive evaluation of substituted values
- Conditional rendering with inline if-then-else — moved to expression
  grammar via cases/when (see 6.4)
- Arithmetic on substituted values
- Custom modifiers defined per-spec

Conditional substitution that was awkward in v0.1 is now handled
through the cases mechanism in templates (Chapter 8) using the
expression grammar.

### 6.4 Expression grammar

The expression grammar produces booleans. Used in `required_if:`,
conditional template `when:`, and `cross_parameter_constraints.rule`.

#### 6.4.1 Atoms

**Literal values:**
- Boolean: `true`, `false`
- Integer: `42`, `-1`, `0`
- String: `"literal text"` (double-quoted)
- Null: `null`
- List: `["a", "b", "c"]`

**Parameter references:**
- `name`
- `name.attribute`
- `name.method`

#### 6.4.2 Operators

**Comparison operators:**
- `==` — equality
- `!=` — inequality
- `<`, `<=`, `>`, `>=` — ordering (defined for int, float, Duration, Bytes)

**Presence operators:**
- `name is null`
- `name is not null`

**Membership operators:**
- `value in list` — list contains value
- `list contains value` — alias, more readable in some contexts
- `string starts_with prefix`
- `string ends_with suffix`
- `string matches regex_literal` — regex match (uses extended_posix grammar)

**Boolean operators:**
- `and`, `or`, `not`
- Standard precedence: `not` > `and` > `or`
- Parentheses for grouping

**Implication operator:**
- `A implies B` — equivalent to `not A or B`
- Used in `cross_parameter_constraints.rule` for clarity

#### 6.4.3 Examples

In a `required_if`:
```yaml
capability:
  filesystem:
    - operation: write
      paths: ["{output}"]
      required_if: "output is not null"
```

In a `when` clause:
```yaml
template:
  cases:
    - when: "atomic == true and mode == replace"
      command: |
        tmpfile=$(...) && printf ... && mv ...
    - when: "atomic == true and mode == append"
      command: |
        printf ... >> {path}
    - when: "atomic == false"
      command: |
        printf ... > {path}
    - default:
      command: |
        # fallback
```

In a `cross_parameter_constraints.rule`:
```yaml
constraints:
  cross_parameter_constraints:
    - description: "HEAD method incompatible with output destination"
      rule: "method == HEAD implies output is null"
    - description: "Recursive flag required when paths contains directories"
      rule: "paths.any_is_directory implies recursive == true"
```

#### 6.4.4 Type discipline in expressions

Expressions must be well-typed. The expression compiler:
- Resolves all parameter references against the spec's signature
- Resolves all attributes and methods against the type catalog
- Verifies that comparison operators receive comparable types
- Verifies that boolean operators receive booleans
- Rejects expressions that don't typecheck with a clear error

This validation happens at spec load time (when the resolver parses the
spec), not at runtime. Malformed expressions in a spec are spec authoring
errors, not runtime failures.

#### 6.4.5 What's not supported in v0.2 expressions

- Function definitions (no user-defined predicates)
- Pattern matching beyond `matches` operator
- Aggregation operators on lists (`any`, `all`) — instead, declare an
  observed attribute on the type that captures the aggregation
- Side effects of any kind — expressions are pure

### 6.5 Conditional cases for templates and parameter mapping

The cases mechanism handles multi-discriminator template variation
(resolves F-022).

#### 6.5.1 Template cases

```yaml
template:
  cases:
    - when: <expression>
      command: |
        <template string>
    - when: <expression>
      command: |
        <template string>
    - default:
      command: |
        <template string>
```

Cases are evaluated in order; the first `when` clause that evaluates
to true selects that case. If no `when` matches and a `default` exists,
default is selected. If no `when` matches and no `default` exists, the
intent fails at construction time with an explicit error.

#### 6.5.2 Parameter mapping cases

Same structure for parameter mapping:

```yaml
parameter_mapping:
  some_template_part:
    cases:
      - when: <expression>
        value: <literal or interpolation>
      - when: <expression>
        value: <literal or interpolation>
      - default:
        value: <literal or interpolation>
```

Parameter mapping values use the interpolation grammar (they produce
strings); the `when` conditions use the expression grammar.

#### 6.5.3 Merge mode for template cases

For templates that have one common base with small variations, the
`merge:` mode combines a base template with case-specific additions:

```yaml
template:
  base: |
    git -C {repository_path}
        commit
        {author_flag}
        --message {message|shell_quoted}
  cases:
    - when: "sign == true"
      merge:
        append_after_base: " --gpg-sign"
    - when: "allow_empty == true"
      merge:
        append_after_base: " --allow-empty"
```

`merge` mode supports `append_after_base`, `prepend_before_base`, and
`replace_segment` (with explicit segment marker). Discouraged for
complex cases — when 3+ merges interact, write explicit `cases` with
full templates instead. The merge mode optimizes the common case where
a base template grows by single flags.

---

## Chapter 7 — Capability section

The `capability` section declares the Cedar-projectable capabilities
the intent requires when invoked. This is the section that projects to
Cedar schema and policy templates. Non-Cedar checks live in
`resolver_constraints` (Chapter 4.5).

### 7.1 Structure

```yaml
capability:
  network: [...]
  filesystem: [...]
  process: [...]
  state_mutation: [...]
  access_grant: [...]
  compute: [...]
```

All categories are optional; specs declare only what they need. Each
category contains a list of capability declarations. Each declaration
has a category-specific structure plus shared fields:

**Shared fields on every capability declaration:**

```yaml
- # category-specific fields...
  purpose: user_facing | implementation_detail | policy_required
  description: <optional human description>
  required_if: <optional expression; capability needed only when true>
```

The `purpose` field (resolves F-027) categorizes why the capability
is needed:

- **`user_facing`**: directly serves the user's intent. The agent
  asked for fetch_url, this is the network call that fulfills it.
- **`implementation_detail`**: required by the implementation but not
  conceptually part of the user's request. write_file's parent
  directory write for atomic temp-file creation is implementation
  detail.
- **`policy_required`**: required because policy mandates it, not
  because the user asked. Audit log writes for compliance frameworks
  are policy_required.

Cedar policies can write rules that ignore implementation_detail
capabilities when the user_facing ones are permitted. Audit logs
distinguish all three.

### 7.2 Network capability

```yaml
network:
  - direction: outbound | inbound
    host: <interpolation producing hostname or "*" for wildcard>
    port: <int or interpolation producing int>
    protocol: http | https | tcp | udp | raw
    purpose: <user_facing | implementation_detail | policy_required>
    required_if: <optional expression>
```

`direction: outbound` is the common case (agent initiates connection).
`inbound` is for intents that bind a listener (uncommon; mostly future
intents for receiving callbacks, webhooks).

Cedar projection: `Action::"Network::Outbound"` (or `::Inbound`) with
resource `Host`, context attributes `port`, `protocol`, `purpose`,
plus the standard `intent_name`, `intent_version`.

### 7.3 Filesystem capability

```yaml
filesystem:
  - operation: read | write | delete | execute
    paths: <list of interpolated FilePath references>
    recursive: <bool>
    follow_symlinks: <bool, default false>
    canonical: <bool, default true>
    recursion_safety: {...}    # see 7.3.1
    purpose: <as above>
    required_if: <optional expression>
```

#### 7.3.1 Recursion safety (resolves F-021)

When `recursive: true`, the resolver implements cycle prevention. The
`recursion_safety` block declares the policy:

```yaml
recursion_safety:
  cycle_prevention: required | not_applicable
  max_depth: <int> | unbounded
  visited_set: by_canonical_path | by_inode
```

- **`cycle_prevention: required`** — resolver must track visited paths/
  inodes and refuse to revisit. Required for any recursive operation
  that follows symlinks or descends into mount points.
- **`cycle_prevention: not_applicable`** — recursion is bounded
  structurally (e.g., walking a known-acyclic tree like a git commit
  graph by hash).
- **`max_depth`** — explicit depth limit. Recursive filesystem
  operations should declare a limit even when cycle_prevention is
  required, because pathological-but-acyclic structures (deeply
  nested directories) can also produce resource exhaustion.
- **`visited_set`** — how the resolver identifies "already visited."
  `by_canonical_path` is simpler; `by_inode` correctly handles
  hardlinks but requires filesystem support.

If `recursive: false`, the `recursion_safety` block can be omitted.

#### 7.3.2 Expansion to PDP queries (resolves F-029)

A filesystem capability with a list-valued `paths` expands into one
PDP query per resolved path. The audit log records each query
separately. Policies that should apply to all paths in a capability
must be written without per-path attributes; policies that distinguish
per-path use `resource.canonical_path` matching.

Cedar projection: `Action::"Filesystem::<Read|Write|Delete|Execute>"`
with resource `FilePath`, context attributes `recursive`,
`follow_symlinks`, `purpose`.

### 7.4 Process capability

```yaml
process:
  - operation: spawn | signal | kill
    target: <interpolation producing tool name, must match registered Tool>
    uid_required: current | root | declared
    purpose: <as above>
    required_if: <optional expression>
```

The `target` resolves to a Tool entity from the Tool registry (see
Chapter 9). Resolvers fail at spec load time if a Process capability
references a Tool not in the registry.

`uid_required: declared` means a separate parameter declares the UID
to run as. Currently rare; most intents use `current`.

Cedar projection: `Action::"Process::Spawn"` (or `::Signal`, `::Kill`)
with resource `Tool`, context attributes `uid_required`, `arg_count`,
`purpose`.

### 7.5 State mutation capability (resolves F-003, F-025)

The deepest v0.2 design decision. State mutation requires three
independent attributes characterizing the operation:

```yaml
state_mutation:
  - operation: write | append | delete | update
    resource_type: <entity type reference, e.g. GitRepository@1.x>
    resource_identifier: <interpolated string>
    visibility: immediate | rename_atomic | transactional
    durability: in_memory | committed | fsynced | fsynced_with_dir
    reversibility: irreversible | reversible_locally | reversible_until_remote_sync | undo_via_compensating_action
    purpose: <as above>
    required_if: <optional expression>
```

#### 7.5.1 The three axes

These three attributes are independent — a capability can have any
combination. Spec authors declare what the operation actually provides;
Cedar policies require specific levels for specific resources.

**Visibility** — When does the change become observable to other
readers?

- **`immediate`**: change visible as soon as the syscall returns.
  Other processes reading the resource see the new state immediately.
  Common for non-atomic writes, append operations, direct overwrites.
- **`rename_atomic`**: change visible only when a temp file rename
  succeeds. Concurrent readers see either the old state or the new
  state, never a partial state. The atomic-write pattern in write_file
  uses this.
- **`transactional`**: change visible only when a transaction commits.
  Multiple writes within a transaction are visible together or not at
  all. Database operations, some filesystems with transactional
  semantics, distributed state systems.

**Durability** — What survives what kind of failure?

- **`in_memory`**: change is in kernel buffers or application memory.
  Lost on power failure even if the operation returned success.
- **`committed`**: change is in filesystem journal/log or database
  write-ahead-log. Survives process crash. May not survive power
  failure for some filesystems.
- **`fsynced`**: `fsync()` returned successfully for the modified
  resource. Survives kernel crash on conformant filesystems.
- **`fsynced_with_dir`**: `fsync()` on both the file and its parent
  directory. Survives kernel crash for *new* files too (the parent
  dir's entry for the new file needs its own fsync).

**Reversibility** — Can the operation be undone, and within what
window?

- **`irreversible`**: no undo at the operation layer. `rm` without
  trash is irreversible. The operation can only be "undone" by
  separately recreating the deleted state.
- **`reversible_locally`**: undo possible from local state. `git
  commit` before push is reversible via `git reset`. File deletion
  with a trash mechanism is reversible until trash is emptied.
- **`reversible_until_remote_sync`**: undo possible until the change
  has propagated to a remote. `git commit` is in this category once
  you also consider `git push`: reversible until pushed; irreversible
  thereafter (without rewriting remote history).
- **`undo_via_compensating_action`**: undo requires an explicit
  inverse operation. HTTP `DELETE` to remove a resource created by
  `POST`. Email retraction. Database `DELETE` to undo `INSERT`. The
  inverse is a separate operation, not a rollback.

#### 7.5.2 Examples of axis combinations

| Intent | Visibility | Durability | Reversibility |
|--------|-----------|-----------|---------------|
| `write_file` (atomic=false, fsync=false) | immediate | in_memory | irreversible |
| `write_file` (atomic=true, fsync=false) | rename_atomic | committed | irreversible |
| `write_file` (atomic=true, fsync=true) | rename_atomic | fsynced | irreversible |
| `commit_changes` | immediate | committed | reversible_until_remote_sync |
| `remove_files` | immediate | committed | irreversible |
| `send_email` | n/a (no local read) | committed (in MTA queue) | undo_via_compensating_action |
| `database_insert` (default isolation) | transactional | fsynced (depending on DB) | reversible_locally (until commit) |

#### 7.5.3 Cedar policy examples

The three-axis decomposition enables policies like:

```cedar
// Production data writes require fsynced durability
forbid (
  principal,
  action == Lki::Action::"StateMutation::Write::Filesystem",
  resource
) when {
  resource.is_production_data &&
  context.durability != "fsynced_with_dir"
};

// Audit-sensitive data must be reversible at least locally
forbid (
  principal,
  action == Lki::Action::"StateMutation::Write::Database",
  resource
) when {
  resource.classification == "audit_sensitive" &&
  context.reversibility == "irreversible"
};

// Compliance: no transactional mutations to compliance store from
// non-compliance-cleared principals
forbid (
  principal,
  action == Lki::Action::"StateMutation::Write::Database",
  resource
) when {
  resource.database_name == "compliance" &&
  context.visibility == "transactional" &&
  !principal.labels.contains("compliance_cleared")
};
```

These rules are not expressible with v0.1's boolean `atomic`. They
require the three-axis decomposition.

#### 7.5.4 Cedar projection

`Action::"StateMutation::<Verb>::<ResourceClass>"` with resource the
declared `resource_type`, context attributes `operation`, `visibility`,
`durability`, `reversibility`, `purpose`. The action naming convention
follows F-032 (Chapter 9).

### 7.6 Access grant capability (resolves F-026 partially)

When an operation creates or modifies access rights to a resource, the
grant itself is a capability separate from the operation that creates
the resource:

```yaml
access_grant:
  - operation: set_mode | set_owner | grant_capability | revoke_capability
    resource: <interpolated entity reference>
    granted_capability: <description string for set_mode; structured for grant_capability>
    purpose: <as above>
    required_if: <optional expression>
```

For `set_mode`: the grant is the resulting file mode bits.

For `grant_capability`: the grant is structured (Cedar-relevant
capabilities being granted to a principal).

write_file's permissions parameter would project to an access_grant
capability:

```yaml
access_grant:
  - operation: set_mode
    resource: "filesystem:{path.canonical}"
    granted_capability: "{permissions}"
    purpose: user_facing
    required_if: "permissions is not null"
```

Cedar policies can express grant constraints:

```cedar
forbid (
  principal,
  action == Lki::Action::"AccessGrant::SetMode",
  resource
) when {
  context.granted_capability matches "0??7" ||   // any world-write
  context.granted_capability matches "0?7?" ||   // any group-write
  context.granted_capability matches "07??"      // any owner-modifier in restricted dirs
};
```

v0.2 ships `set_mode` and `set_owner` as fully-specified
access_grant operations. `grant_capability` and `revoke_capability`
are reserved for future use (likely v0.3) when capabilities can be
transferred between principals.

Cedar projection: `Action::"AccessGrant::<Operation>"` with resource
the affected resource entity, context attribute `granted_capability`.

### 7.7 Compute capability

#### 7.7.1 Structure

```yaml
compute:
  - resource: <resource_class>
    bound: <interpolation producing bound value>
    cost_model: <optional cost model reference>
    provider: <optional provider reference>
    purpose: <user_facing | implementation_detail | policy_required>
    required_if: <optional expression>
```

The `resource` field identifies what's being consumed. v0.2 ships these
resource classes:

| Resource | Bound type | Common cost model |
|----------|-----------|-------------------|
| `time` | Duration | none (wall-clock is free) |
| `memory` | Bytes | none (memory is free in most contexts) |
| `cpu_cores` | int | none |
| `cpu_seconds` | Duration | per-cpu-second (cloud instance pricing) |
| `tokens` | int | per-token-with-provider-pricing |
| `api_calls` | int | per-call-with-provider-pricing |
| `gpu_time` | Duration | per-gpu-second (instance-type-dependent) |
| `gpu_memory` | Bytes | none (allocated time has the cost) |
| `network_bandwidth` | Bytes | provider-dependent (egress fees) |
| `storage_io_read` | Bytes | provider-dependent |
| `storage_io_write` | Bytes | provider-dependent |

Adding a new resource class is a minor version bump on the format spec.
Custom resource classes per-spec are not supported in v0.2 (reserved
namespace).

#### 7.7.2 Cost models

The `cost_model` field is optional but recommended for any resource
with non-trivial cost. Standard cost models:

- `none` — no associated cost; bound is purely about preventing
  resource exhaustion
- `per_unit_with_provider_pricing` — cost per unit consumed, with
  the provider determining the unit price (e.g., per_token, per_api_call,
  per_cpu_second). Requires a `provider` field naming the cost provider.
- `flat_fee_per_invocation` — single cost per intent invocation
  regardless of resource consumed
- `tiered_per_unit_with_provider_pricing` — tiered pricing where unit
  cost varies with cumulative consumption (e.g., first 1M tokens at
  one rate, next 9M at another)

When `cost_model` is specified, the audit log captures the actual cost
incurred by the operation. Cedar policies can reference cost via
context attributes (Chapter 9.3.1).

#### 7.7.3 Cedar projection

`Action::"Compute::<ResourceClass>"` with resource `ComputeBudget`
synthetic entity, context attributes:

```cedar
context: {
  "intent_name": String,
  "intent_version": String,
  "purpose": String,
  "resource_class": String,
  "bound_value": Long,        // unit depends on resource_class
  "bound_unit": String,       // "seconds", "bytes", "tokens", "calls"
  "cost_model": String,
  "provider": String,         // empty when cost_model is none
  "estimated_cost": Long,     // in fractional cents; 0 when cost_model is none
}
```

Cedar policies can reason about cost:

```cedar
forbid (
  principal,
  action == Lki::Action::"Compute::Tokens",
  resource
) when {
  context.estimated_cost > 1000 &&  // > $10.00 in fractional cents
  !principal.has_approved_budget_pool("api_costs")
};
```

#### 7.7.4 Breach handling — deferred to v0.3

v0.2's bound-exceeded behavior is binary: PDP returns Deny when policy
forbids the consumption level. This is insufficient for real cost-aware
deployments where soft bounds, approval workflows, budget-pool
deduction, throttling, and degradation are needed.

v0.3 will add a `breach_handling:` field with options:

```yaml
breach_handling:
  strict_bound: <hard limit; deny above this regardless>
  soft_bound_actions:    # actions when between 'bound' and 'strict_bound'
    - request_approval
    - log_warning
    - deduct_from_budget_pool
    - throttle_until_budget_available
    - degrade_to_alternative
```

This is a substantial design effort because it requires:
- Budget pool entities in Cedar with stateful tracking
- Approval workflow integration with the agent runtime
- Cedar conditional-permit semantics (Allow with conditions the resolver must satisfy)
- Audit log records of breach decisions and their resolutions

v0.2 specs declare `bound:` only. Resolvers implement Cedar's
Allow/Deny response without the subtlety; environments that need
soft-bound behavior must implement it externally to LKI for now.

Tracked as new finding F-034 (added to FINDINGS_v0.2.md when that
document opens).

### 7.8 Interaction between capabilities and resource bounds

Parameters annotated `is_resource_bound: true` (Chapter 4.1) appear
in the signature but flow into capability context as policy-relevant
attributes. A `timeout` parameter on fetch_url with
`is_resource_bound: true` results in `context.timeout_bound` being
available in the Network capability's Cedar context, so policies can
write rules like:

```cedar
forbid (
  principal,
  action == Lki::Action::"Network::Outbound",
  resource
) when {
  context.timeout_bound > 300  // 5 minutes
};
```

This is cleaner than v0.1's mixing resource bounds with arbitrary
parameters because policy authors can filter on `is_resource_bound`
without enumerating which parameters are bounds.

---

---

## Chapter 8 — Implementation section

The `implementation` section declares one or more concrete tool-based
implementations of the intent. Resolvers select among them at runtime
based on tool availability and version constraints.

This chapter resolves F-012 (working_directory replacing `cd && ...`
patterns) and F-015 (version range syntax in `tested_against`).

### 8.1 Structure

```yaml
implementation:
  - tool: <tool name; must match registered Tool entity>
    priority: <int, higher is preferred>
    requires: <version constraint string>
    tested_against: [<version constraint strings>]
    working_directory: <interpolated FilePath, optional>
    template: <string or cases-structured template>
    parameter_mapping: {...}
    notes: <optional notes>
    limitations: [<optional limitation strings>]
```

Multiple entries are permitted. Resolver behavior is specified in 8.6.

### 8.2 `tool` field

References a Tool entity from the Tool registry (Chapter 9, section
9.6). Resolvers fail at spec load time if a referenced tool is not in
the registry — there is no silent acceptance of unknown tools.

The `tool` field is also used for the corresponding `process.spawn`
capability declaration. An implementation declaring `tool: git` must
have a `process.spawn` capability with `target: git` in the spec's
capability section. Spec validation tooling enforces this consistency.

### 8.3 `priority` field

Integer; higher values are preferred. Required when multiple
implementations are declared. Resolvers select the implementation with
the highest priority whose `tool` is available and whose `requires`
version constraint is satisfied.

There is no automatic fallback between implementations in v0.2. If the
highest-priority implementation's tool is unavailable, the resolver
selects the next-highest. If no implementation satisfies its
constraints, the intent fails to load with an explicit error
identifying which tools were checked and what versions were found.

Automatic fallback semantics with policy-equivalence requirements are
deferred to v0.3 (F-020). v0.2's "highest priority among available" is
the conservative position: predictable selection, no silent surprises
when production tooling differs from development tooling.

### 8.4 `requires` and `tested_against`

Version constraints declare which tool versions the implementation is
compatible with.

**`requires`** is the minimum compatibility constraint. Below this
version, the implementation is known to be incompatible and the
resolver refuses to use it.

**`tested_against`** is a list of verified versions or version ranges.
At least one constraint must match the available tool version, or the
resolver warns (configurable to refuse).

#### 8.4.1 Version constraint syntax

Constraints follow standard semver-style syntax, prefixed with the
tool name:

```yaml
requires: "curl >= 7.50"
tested_against:
  - "curl 7.x"           # any 7.x.x version
  - "curl 8.0 - 8.4"     # 8.0.0 through 8.4.x inclusive
  - "curl 8.7.1"         # exact version
  - "curl >= 9.0"        # 9.0.0 or higher
```

Recognized constraint forms:

| Form | Matches |
|------|---------|
| `tool x.y.z` | Exactly that version |
| `tool x.y` | Any patch version of x.y |
| `tool x.x` | Any minor.patch of x |
| `tool >= x.y.z` | x.y.z or later |
| `tool <= x.y.z` | x.y.z or earlier |
| `tool > x.y.z` | After x.y.z |
| `tool < x.y.z` | Before x.y.z |
| `tool a.b.c - x.y.z` | Inclusive range a.b.c through x.y.z |
| `tool ~> x.y.z` | x.y.z or later, but less than x.(y+1).0 |
| `tool ^x.y.z` | x.y.z or later, but less than (x+1).0.0 |

Tool name appears as a prefix because the same constraint syntax is
used across multiple tools and tool names disambiguate. Constraint
parsing rejects mismatched tool names (a constraint of `curl >= 7.50`
against a `tool: wget` implementation fails to parse).

#### 8.4.2 Range matching semantics

The resolver determines the available tool version via tool-specific
mechanisms (`curl --version`, `git --version`, etc.). The available
version is then matched against each constraint in `tested_against`.

If any constraint matches: implementation is fully verified.
If none match: implementation is usable (requires is satisfied) but
verification status is "untested for this version" — resolver warns.

### 8.5 `working_directory` (resolves F-012)

When the tool needs to execute in a specific directory, declare it
explicitly via `working_directory`:

```yaml
working_directory: "{repository_path}"
template: |
  git commit --message {message|shell_quoted}
```

The resolver implements `working_directory` using tool-native
facilities or process spawn options:

| Tool | Mechanism |
|------|-----------|
| `git` | `git -C <dir> ...` |
| `tar` | `tar -C <dir> ...` |
| `make` | `make -C <dir> ...` |
| `find` | first argument is the search root |
| (other) | process spawn with `cwd` set |

The format spec **forbids** `cd <dir> && ...` patterns in templates.
This restriction is enforced by spec validation tooling. The reason:
`cd` has process-wide side effects (changes the resolver's working
directory if not run in a subshell), interacts badly with subsequent
operations, and isn't recoverable when the command fails mid-execution.

Templates assume execution in the declared `working_directory`. If
omitted, the resolver's current directory at intent execution time is
used (typically the principal's `working_dir`).

### 8.6 Resolver selection algorithm

When an intent is invoked, the resolver selects an implementation via:

1. **Filter by `requires`**: discard implementations whose `requires`
   constraint isn't satisfied by the available tool version (or where
   the tool isn't available at all).
2. **Sort by `priority`**: descending.
3. **Select the first**: highest-priority implementation that survived
   filtering.
4. **Verify `tested_against`**: if no `tested_against` constraint
   matches the available version, emit a warning to the resolver's
   diagnostic stream. The implementation is still used.
5. **Construct invocation**: apply the implementation's template and
   parameter_mapping to produce the executable command.

If filtering removes all implementations, the intent fails to load
with an error listing each declared implementation, its tool, the
version found, and why each was rejected. This is a spec-deployment
issue (the environment lacks compatible tools), not a runtime failure.

### 8.7 `template` and `parameter_mapping`

Templates and parameter mappings use the interpolation and expression
grammars from Chapter 6. Two forms:

**Simple template** (no conditional variation):

```yaml
template: |
  cat -- {path}
```

**Cases template** (conditional variation):

```yaml
template:
  cases:
    - when: <expression>
      command: |
        <template string>
    - default:
      command: |
        <template string>
```

Same for parameter_mapping (Chapter 6.5).

### 8.8 `notes` and `limitations`

`notes` is free prose. Document non-obvious behavior, design rationale,
or version-specific behaviors.

`limitations` is a list of strings describing where the implementation
falls short of the intent's full contract:

```yaml
limitations:
  - "No native pattern matching; resolver must filter results"
  - "Recursive mode requires GNU find; BSD find requires different invocation"
```

Limitations are informational; they don't change resolver selection.
A spec author who declares limitations should also declare a
higher-priority implementation without those limitations when one
exists.

---

## Chapter 9 — Cedar projection rules

The cedar-from-lki tooling produces Cedar artifacts from LKI specs.
This chapter specifies the projection rules unambiguously enough that
multiple implementations produce identical Cedar output for the same
input.

Resolves F-004 (intent as context attribute), F-006 (intent-level
atomicity), F-028 (entity for capability target), F-031 (cross-spec
entity sharing), F-032 (action naming convention), and F-033 (Tool
registry validation). Builds on F-029 (capability expansion to PDP
queries) documented in Chapter 7.

### 9.1 Three artifacts produced

For an input directory of LKI specs + type/entity registries +
tool registry, cedar-from-lki produces:

1. **Cedar schema** (`schema.cedarschema`): entity types and action
   types covering all specs
2. **Policy templates** (`policies/`): one set of three-tier policy
   templates per spec
3. **Tool registry validation report**: list of Tool references in
   specs that lack corresponding registry entries

Each artifact has a deterministic generation rule from the input. Two
runs of cedar-from-lki on the same input produce byte-identical output
(modulo file-system metadata).

### 9.2 Entity type projection

Each entity type declared in `types/v0.x/entities/<EntityName>.lki.yaml`
projects to a Cedar `entity` declaration in the schema:

```yaml
# Source: types/v0.2/entities/GitRepository.lki.yaml
entity_type:
  name: GitRepository
  structural_attributes:
    canonical_path:
      type: string
  observed_attributes:
    current_branch:
      type: string
    is_detached_head:
      type: bool
```

Projects to:

```cedar
entity GitRepository = {
  // structural
  "canonical_path": String,
  // observed
  "current_branch": String,
  "is_detached_head": Bool,
};
```

The schema does not syntactically distinguish structural from observed
in Cedar. The distinction is metadata for spec authors and policy
authors, enforced at type-load time and present in generated documentation.

#### 9.2.1 Synthetic entity types for capability categories without natural resources

Per F-028, some capability categories don't have a natural resource
entity. The projection introduces synthetic entity types per category:

| Capability | Resource entity |
|------------|----------------|
| `network` | `Host` (declared in shared registry) |
| `filesystem` | `FilePath` (declared in shared registry) |
| `process` | `Tool` (declared per tool in tool registry) |
| `state_mutation` | The `resource_type` field of the declaration |
| `compute` | `ComputeBudget` (synthetic; not a real entity in any environment) |
| `access_grant` | The affected resource entity from the declaration |

For `state_mutation` and `access_grant`, the resource entity is
declared per capability. For `compute`, the `ComputeBudget` entity is
synthetic — it has no real-world identity, but Cedar's request shape
requires a resource, so we provide one.

### 9.3 Action type projection

Each unique `(capability_category, operation)` combination across all
specs projects to one Cedar action. Action names follow the convention
established in F-032:

`<CapabilityCategory>::<Operation>` for categories with one operation
class, or `<CapabilityCategory>::<Operation>::<Specifier>` when the
specifier distinguishes meaningfully different actions.

The current set:

| Category | Operation | Action name |
|----------|-----------|-------------|
| `network` | `outbound` | `Network::Outbound` |
| `network` | `inbound` | `Network::Inbound` |
| `filesystem` | `read` | `Filesystem::Read` |
| `filesystem` | `write` | `Filesystem::Write` |
| `filesystem` | `delete` | `Filesystem::Delete` |
| `filesystem` | `execute` | `Filesystem::Execute` |
| `process` | `spawn` | `Process::Spawn` |
| `process` | `signal` | `Process::Signal` |
| `process` | `kill` | `Process::Kill` |
| `state_mutation` | `write` + resource_type `GitRepository` | `StateMutation::Write::Git` |
| `state_mutation` | `write` + resource_type `EmailAccount` | `StateMutation::Write::Email` |
| `state_mutation` | `write` + resource_type `Database` | `StateMutation::Write::Database` |
| `access_grant` | `set_mode` | `AccessGrant::SetMode` |
| `access_grant` | `set_owner` | `AccessGrant::SetOwner` |
| `compute` | `bounded_time` | `Compute::BoundedTime` |
| `compute` | `bounded_memory` | `Compute::BoundedMemory` |

State mutations get a specifier because policies will frequently want
to write rules specific to git vs email vs database. Other categories
generally don't need specifiers; the resource entity carries the
specificity.

#### 9.3.1 Action context attributes

Every action has a base context comprising:

```cedar
context: {
  "intent_name": String,
  "intent_version": String,
  "purpose": String,         // "user_facing" | "implementation_detail" | "policy_required"
}
```

Plus action-specific context per category. For example, `Filesystem::Read`:

```cedar
context: {
  "intent_name": String,
  "intent_version": String,
  "purpose": String,
  "recursive": Bool,
  "follow_symlinks": Bool,
}
```

`StateMutation::Write::Git`:

```cedar
context: {
  "intent_name": String,
  "intent_version": String,
  "purpose": String,
  "operation": String,
  "visibility": String,
  "durability": String,
  "reversibility": String,
}
```

The full context schema per action is specified in 9.7 (Appendix).

#### 9.3.2 Resource bounds in context

Parameters annotated `is_resource_bound: true` (Chapter 4.1) flow into
the context of all capabilities the intent declares. The attribute name
is `<parameter_name>_bound` to disambiguate from other context
attributes:

```cedar
// fetch_url has parameter 'timeout' with is_resource_bound: true
context: {
  "intent_name": String,
  "intent_version": String,
  "purpose": String,
  "port": Long,
  "protocol": String,
  "timeout_bound": Long,    // from the resource_bound parameter
}
```

Policies can reason about resource bounds across all capabilities of an
intent uniformly.

### 9.4 Intent is not a Cedar entity (resolves F-004)

The intent itself does not project to a Cedar entity. The reasoning:

1. One intent invocation produces multiple capability checks (multiple
   PDP queries per intent). Making intent an entity would require
   synthesizing a transient entity per invocation, then attaching it
   to each Cedar request.
2. Cedar policies that need to reason about the intent can use the
   `context.intent_name` and `context.intent_version` attributes,
   which are present on every action context.
3. The intent's parameters flow into context as needed (resource bounds,
   capability-specific attributes); the intent itself doesn't need
   independent identity in Cedar.

This is a deliberate choice. Future formats may revisit if policy
expressiveness suffers, but v0.2 commits to intent-as-context.

### 9.5 Intent-level atomicity (resolves F-006)

A single intent invocation produces N Cedar requests, where N is the
sum of expanded capabilities (per F-029). All N must return Allow for
the intent to proceed; any Deny fails the intent atomically.

The cedar-from-lki tooling does not produce code to enforce atomicity
— atomicity is the resolver's responsibility, not Cedar's. But the
generated documentation explicitly notes the contract:

> Intent `<name>@<version>` requires <N> capability checks per
> invocation. All must Allow for the intent to execute. If any Deny,
> the intent fails atomically and returns a structured error
> identifying which capability was denied and which policy caused
> the denial.

Resolvers must respect intent-level atomicity. Partial-allow (some
capabilities allowed, intent proceeds with reduced scope) is never a
valid outcome.

### 9.6 Tool registry (resolves F-033)

Tools referenced by `process.spawn` capabilities and by
`implementation.tool` fields must exist in a Tool registry maintained
alongside specs.

```yaml
# registries/tools/v0.2/tools.lki.yaml
lki_version: "0.2"
tools:
  - name: git
    is_system_critical: false
    typical_path: "/usr/bin/git"
    capabilities_provided:
      - "Filesystem::Read on .git"
      - "Filesystem::Write on .git"
      - "Network::Outbound for fetch/push (when network operations used)"
  - name: curl
    is_system_critical: false
    typical_path: "/usr/bin/curl"
    capabilities_provided:
      - "Network::Outbound"
      - "Filesystem::Write for --output"
  - name: docker
    is_system_critical: false
    typical_path: "/usr/bin/docker"
    capabilities_provided:
      - "Process::Spawn (for container init)"
      - "Network::* (varies by container configuration)"
      - "Filesystem::* (varies by mounts)"
    requires_privileged_access: true
  - name: systemctl
    is_system_critical: true
    typical_path: "/bin/systemctl"
    capabilities_provided:
      - "Process::Signal"
      - "StateMutation::* (system services)"
```

Each tool projects to a Cedar entity:

```cedar
Lki::Tool::"git" = {
  "name": "git",
  "is_system_critical": false,
  ...
};
```

cedar-from-lki **validates** that every tool referenced in specs has a
registry entry. Missing entries produce errors at projection time, not
silent failures at runtime. The validation report lists:
- Tools referenced but not in registry (errors)
- Tools in registry but not referenced by any spec (informational)

The registry is itself versioned (Chapter 2.4). Adding a tool is a
minor version bump on the tool registry.

### 9.7 Action context schema (Appendix)

Full context attribute schemas for every action type defined in v0.2:

#### Network::Outbound, Network::Inbound

```cedar
context: {
  "intent_name": String,
  "intent_version": String,
  "purpose": String,
  "port": Long,
  "protocol": String,
}
```

Plus any resource_bound parameters from the parent intent.

#### Filesystem::Read, Filesystem::Write, Filesystem::Delete, Filesystem::Execute

```cedar
context: {
  "intent_name": String,
  "intent_version": String,
  "purpose": String,
  "recursive": Bool,
  "follow_symlinks": Bool,
}
```

Plus any resource_bound parameters from the parent intent.

#### Process::Spawn, Process::Signal, Process::Kill

```cedar
context: {
  "intent_name": String,
  "intent_version": String,
  "purpose": String,
  "uid_required": String,
  "arg_count": Long,
}
```

#### StateMutation::Write::<ResourceClass>

```cedar
context: {
  "intent_name": String,
  "intent_version": String,
  "purpose": String,
  "operation": String,
  "visibility": String,      // "immediate" | "rename_atomic" | "transactional"
  "durability": String,      // "in_memory" | "committed" | "fsynced" | "fsynced_with_dir"
  "reversibility": String,   // "irreversible" | "reversible_locally" | "reversible_until_remote_sync" | "undo_via_compensating_action"
}
```

Plus resource-class-specific attributes from the resource_type
declaration.

#### AccessGrant::SetMode, AccessGrant::SetOwner

```cedar
context: {
  "intent_name": String,
  "intent_version": String,
  "purpose": String,
  "granted_capability": String,
}
```

#### Compute::BoundedTime, Compute::BoundedMemory

```cedar
context: {
  "intent_name": String,
  "intent_version": String,
  "purpose": String,
  "bound_value": Long,
}
```

### 9.8 Three-tier policy generation

For each spec, cedar-from-lki generates a three-tier policy file:

```
policies/<intent_name>/v<intent_version>/
  safety_floor.cedar
  baseline.cedar
  tenant_template.cedar
```

**Safety floor** is derived from anti_patterns. Each anti-pattern with
a structurally-decodable rejection generates a `forbid` policy.
Anti-patterns whose rejection is purely resolver-side (parameter
validation, type rejection) do not generate Cedar policy because Cedar
isn't enforcing them — the resolver is.

**Baseline** is derived from the capability section. Each capability
declaration generates a `permit` policy that allows the capability
under the typical conditions implied by the declaration. Baseline
policies are intentionally permissive defaults; operators tighten them
in the tenant template.

**Tenant template** is empty by default with commented examples
showing the shapes of common customizations (allowed hosts, branch
restrictions, label-based access). Operators populate this file with
site-specific rules.

#### 9.8.1 Safety floor generation

For each `anti_pattern` in the spec, if the `rejection` field
references a structural property of an entity or context attribute,
generate a forbid:

```yaml
# Source anti-pattern:
- bad: 'curl https://example.com -o /etc/cron.d/job'
  reason: "Writes downloaded content to a privileged execution path"
  rejection: |
    Output path must satisfy filesystem write policy. System and
    execution paths require explicit per-path permission.
```

```cedar
// Generated safety floor policy:
forbid (
  principal,
  action == Lki::Action::"Filesystem::Write",
  resource
) when {
  resource.is_system_path
};
```

Anti-patterns whose rejection refers to types, parameter validation,
or resolver-internal checks don't generate Cedar — they're documentation
of resolver-enforced rejections.

#### 9.8.2 Baseline generation

For each capability declaration in a spec, generate a permit:

```yaml
# Source capability:
filesystem:
  - operation: write
    paths: ["{output}"]
    purpose: user_facing
    required_if: "output is not null"
```

```cedar
// Generated baseline policy:
permit (
  principal,
  action == Lki::Action::"Filesystem::Write",
  resource
) when {
  context.intent_name == "fetch_url" &&
  context.purpose == "user_facing" &&
  resource.is_within_working_dir &&
  !resource.is_system_path
};
```

Baselines apply `is_within_working_dir` and `!is_system_path` as
default scope restrictions; operators relax or tighten via tenant
template.

#### 9.8.3 Tenant template generation

Tenant templates are scaffolded but empty:

```cedar
// Tenant policy template for fetch_url@2.0.0
// Operators add site-specific rules below.

// EXAMPLE: allow internal hosts for principals with "internal" label
// permit (
//   principal,
//   action == Lki::Action::"Network::Outbound",
//   resource
// )
// when {
//   principal.labels.contains("internal") &&
//   context.intent_name == "fetch_url" &&
//   resource.fqdn like "*.internal.example.com"
// };

// EXAMPLE: forbid downloads of risky extensions
// forbid (...) when { [".exe", ".dmg"].contains(resource.extension) };
```

Tenant templates are checked into the deployment's policy repository
and edited by operators. Regeneration of safety_floor.cedar and
baseline.cedar from updated specs does not overwrite tenant_template.cedar.

### 9.9 Schema generation algorithm

The complete algorithm for generating `schema.cedarschema`:

```
1. Read all type registries (types/v0.x/*)
   For each entity_type, emit Cedar entity declaration.

2. Read tool registry (registries/tools/v0.x/tools.lki.yaml)
   For each tool, emit Tool entity declaration with attributes.

3. Read all specs (specs/**/*.yaml)
   For each spec:
     For each capability declaration:
       Identify (category, operation, specifier) tuple
       If tuple's action not yet emitted:
         Emit action declaration with appropriate resource and context

4. Validate:
   - All process.spawn capabilities reference a Tool in the registry
   - All state_mutation.resource_type references an entity type in registries
   - All action declarations have consistent context schemas across specs
     (two specs declaring the same action must have compatible contexts)

5. Output the Cedar schema with all entities and actions, in
   alphabetical order within each category for stable diffs.
```

The output is deterministic and version-controllable. Two runs against
the same input produce byte-identical schemas.

### 9.10 Variant intent sharing (from Chapter 1)

When two intents are variants (Chapter 1: separate intents with
identical capability semantics), they share Cedar actions. The projection
detects variants by capability-section equivalence:

```yaml
# read_file
capability:
  filesystem:
    - operation: read
      paths: ["{path}"]
      recursive: false

# read_file_bytes  
capability:
  filesystem:
    - operation: read
      paths: ["{path}"]
      recursive: false
```

Both project to the same `Filesystem::Read` action. Policies on this
action apply uniformly to both intents. Differentiation, where needed,
uses `context.intent_name`:

```cedar
// Permit either variant; differentiate via intent_name if needed
permit (
  principal,
  action == Lki::Action::"Filesystem::Read",
  resource
) when {
  ["read_file", "read_file_bytes"].contains(context.intent_name)
};
```

If a variant has *different* capability semantics (different paths,
different recursion behavior), it doesn't share actions — capability
equivalence is the test, not naming similarity.

---
## Chapter 10 — Audit log structure

The audit log is the canonical record of intent invocations. Every
intent invocation produces exactly one audit entry, regardless of
outcome (Allow, Deny, error during execution). This chapter formalizes
the entry structure so all LKI implementations produce compatible
streams (resolves F-007).

### 10.1 Required entry fields

Every audit entry contains:

```yaml
audit_entry:
  # Identity and timing
  entry_id: <content hash of the entry>
  schema_version: "0.2"          # the audit schema version, not LKI format
  timestamp: <ISO 8601 with millisecond precision and timezone>
  principal:
    id: <string>
    session_id: <string>
    labels: <list of strings>
  
  # Intent identification
  intent:
    name: <string>
    version: <semver string>
  
  # Input
  intent_parameters: <map of parameter name to value>
  resource_bounds:               # subset of parameters where is_resource_bound: true
    <param_name>: <value>
  
  # Observed environment state at request time
  observed_state:
    <entity_identifier>: <map of observed attributes>
  
  # Capability resolution
  resolved_capabilities: <list of resolved capability instances>
  
  # PDP evaluation
  pdp_decisions: <list of decisions, one per resolved capability>
  
  # Atomic outcome
  intent_outcome: "Allow" | "Deny" | "Error"
  
  # Execution (only when intent_outcome is Allow)
  execution:
    started_at: <timestamp>
    completed_at: <timestamp>
    duration_ms: <int>
    result: "success" | "failure"
    error: <optional structured error>
    actual_cost: <map of compute resources to actual consumption>
```

### 10.2 Entry identity and content addressing

Each audit entry has an `entry_id` computed as the SHA-256 of the
canonicalized YAML form of all entry fields except `entry_id` itself.

Canonicalization:
1. Sort all map keys lexicographically
2. Use a consistent YAML emitter that produces stable output for
   equivalent semantic content (no trailing whitespace, consistent
   quoting, consistent indentation)
3. Serialize and hash the canonical form

This makes audit logs verifiable: any modification to an entry breaks
its `entry_id`, and downstream systems can detect tampering. It also
makes audit entries content-addressable for storage and deduplication.

### 10.3 Append-only semantics

Audit logs are append-only. Once an entry is written, it is immutable.
Corrections do not modify existing entries; they append new entries
referencing the originals:

```yaml
# Correction entry
audit_entry:
  entry_id: <hash>
  schema_version: "0.2"
  entry_type: correction
  corrects: <entry_id of the original>
  correction_reason: <human description>
  # ... full corrected entry content ...
```

The correction relationship is queryable; consumers can resolve "what's
the current truth about this intent invocation" by following the
correction chain.

### 10.4 PDP decision records

Each entry in `pdp_decisions` records one Cedar evaluation:

```yaml
pdp_decisions:
  - capability_source: "filesystem.read[0]"   # references the spec's capability declaration
    cedar_request:
      principal: <entity reference>
      action: <action name>
      resource: <entity reference>
      context: <map of context attributes>
    decision: "Allow" | "Deny"
    determining_policies: <list of policy IDs that contributed to the decision>
    determining_reason: <optional human-readable reason from the policy>
    evaluation_duration_ms: <int>
```

The `capability_source` field references the spec's capability
declaration position (e.g., `filesystem.read[0]` means "the first
entry in the filesystem.read list of the capability section"). This
makes audit entries cross-referenceable to the spec.

### 10.5 Observed state recording

The `observed_state` field captures the values of observed attributes
on entities at request construction time. This serves two purposes:

1. **Reproducibility:** future analysis can determine what state the
   PDP evaluated against, even though that state may have changed since.
2. **TOCTOU forensics:** if an intent's outcome depended on observed
   state that changed before execution, the audit log reveals the gap.

Example:

```yaml
observed_state:
  "GitRepository:/home/agent/workspace/lki":
    current_branch: "main"
    is_detached_head: false
    has_in_progress_operation: false
    has_uncommitted_changes: true
  "FilePath:/home/agent/workspace/lki":
    is_within_working_dir: true
    is_system_path: false
```

### 10.6 Execution sub-record

Present only when `intent_outcome` is `Allow` and execution was
attempted:

```yaml
execution:
  started_at: "2026-05-19T10:23:11.482Z"
  completed_at: "2026-05-19T10:23:11.894Z"
  duration_ms: 412
  result: "success"
  
  # Compute resources actually consumed (when intent declared compute capabilities)
  actual_cost:
    time:
      bound: "30s"
      actual: "0.412s"
    tokens:
      bound: 10000
      actual: 8473
      cost_cents: 84    # if cost_model was set
```

For failures:

```yaml
execution:
  started_at: "..."
  completed_at: "..."
  duration_ms: 87
  result: "failure"
  error:
    type: "tool_invocation_failure" | "constraint_violation" | "timeout" | "unexpected"
    exit_code: <int, when applicable>
    stderr: <string, truncated to 4KB>
    structured_reason: <optional spec-defined error code>
```

### 10.7 Audit log storage and querying

This document does not specify storage backends. Implementations may
store audit logs as:
- Flat-file JSON Lines (one entry per line)
- Append-only databases
- Streaming systems (Kafka, Kinesis)
- Cloud audit services (CloudTrail-equivalent)

Storage format does not affect schema conformance. The same audit
entries can be expressed across multiple storage backends.

For querying, the recommended pattern is to project audit entries
into a queryable substrate keyed by:
- `principal.id` (for "what did this agent do?")
- `intent.name` (for "what calls of this intent have happened?")
- `timestamp` ranges (for "what happened during this window?")
- `intent_outcome` (for "what was denied?")
- `pdp_decisions[].determining_policies` (for "what fired this policy?")

The queryable substrate is itself outside LKI's scope; the audit log
schema enables the substrate, doesn't prescribe it.

### 10.8 Privacy and retention

Audit entries contain principal identifiers, session identifiers, and
intent parameters that may include sensitive information. Implementations
must address:
- **Retention policy:** how long entries are kept
- **Access control:** who can read audit entries (Cedar-policy-enforced)
- **Redaction:** sensitive parameter values that should not appear in
  long-term audit storage

v0.2 does not specify retention or redaction policies; those are
deployment decisions. The schema accommodates redaction via a
`redacted: true` marker that can replace any field value:

```yaml
intent_parameters:
  url: "https://api.example.com/v1/sensitive"
  headers:
    Authorization: { redacted: true, redaction_reason: "credential" }
```

The redaction marker preserves entry validity for content-address
hashing.

---

## Chapter 11 — Resolver execution model

This chapter formalizes the resolver pipeline — the ordered sequence
of operations from intent receipt to execution to audit log emission.
Specifying this explicitly resolves F-024 and makes resolver behavior
predictable across implementations.

### 11.1 The eleven-stage pipeline

Every intent invocation flows through these stages in order:

```
1. Parameter parsing and type validation
2. Resolver constraints
3. Cross-parameter constraints
4. Conditional capability resolution
5. Capability expansion (interpolation against concrete values)
6. PDP query construction
7. PDP evaluation (intent-level atomic)
8. Implementation selection
9. Template substitution
10. Execution
11. Audit log emission
```

Each stage may fail; failure produces an audit entry with the
appropriate `intent_outcome` (Deny for policy denials, Error for
non-policy failures) and skips remaining stages.

### 11.2 Stage details

#### 11.2.1 Parameter parsing and type validation

Input: raw intent parameters from the caller.

Operations:
- Parse each parameter according to its declared type
- Validate parameter-level constraints (the `constraint:` field on each parameter)
- Reject if any parameter fails type parsing or constraint validation

Output: validated, typed parameter values.

Failure mode: `intent_outcome: Error`, `execution.error.type: "constraint_violation"`.

#### 11.2.2 Resolver constraints

Input: validated parameters.

Operations:
- For each entry in `resolver_constraints`, evaluate the rule
- Reject if any constraint fails

Output: parameters that have passed all resolver-side validation.

Failure mode: `intent_outcome: Error`, error indicates which constraint
fired.

#### 11.2.3 Cross-parameter constraints

Input: validated parameters.

Operations:
- For each entry in `constraints.cross_parameter_constraints`, evaluate
  the rule
- Reject if any constraint fails

Output: parameters validated cross-parameter.

Failure mode: `intent_outcome: Error`.

#### 11.2.4 Conditional capability resolution

Input: validated parameters.

Operations:
- For each capability declaration, evaluate `required_if` (if present)
- Mark capabilities with false `required_if` as "not needed"
- Capabilities without `required_if` are always needed

Output: list of capabilities that will be checked by PDP.

#### 11.2.5 Capability expansion

Input: list of required capabilities.

Operations:
- For each capability, resolve all interpolations against concrete
  parameter values (and observed entity attributes where applicable)
- Expand list-valued resource fields into per-resource capability instances
- Compute observed attributes for resources (canonicalize FilePaths,
  resolve Host attributes, etc.)

Output: list of fully-resolved capability instances, each ready for
PDP evaluation.

#### 11.2.6 PDP query construction

Input: resolved capability instances.

Operations:
- For each resolved instance, construct a Cedar request with
  appropriate principal, action, resource, and context
- Attach intent-wide context (intent_name, intent_version, purpose)
- Attach resource-bound context where applicable

Output: list of Cedar requests.

#### 11.2.7 PDP evaluation

Input: list of Cedar requests.

Operations:
- Submit each request to the Cedar PDP
- Collect all decisions

**Atomicity check** (F-006): if all decisions are Allow, the intent
proceeds. If any is Deny, the intent fails atomically; no further
stages execute.

Output: PDP decisions for all requests; intent_outcome of Allow or Deny.

Failure mode: `intent_outcome: Deny`. Audit log records all decisions
including the denying ones.

#### 11.2.8 Implementation selection

Input: validated parameters (intent has been Allowed by PDP).

Operations:
- Filter implementations by `requires` constraint and tool availability
- Sort by `priority` descending
- Select highest-priority survivor

Output: the chosen implementation entry.

Failure mode: `intent_outcome: Error`, `execution.error.type:
"no_implementation_available"`.

#### 11.2.9 Template substitution

Input: chosen implementation, validated parameters.

Operations:
- Evaluate template cases (if cases-structured) using the expression grammar
- Apply parameter_mapping
- Apply interpolation grammar with render modifiers
- Apply shell quoting via the `shell_quoted` modifier where present

Output: executable command string.

#### 11.2.10 Execution

Input: executable command, working_directory.

Operations:
- Spawn the tool process with the specified working_directory
- Set process arguments and environment per the resolver's policies
- Capture stdout, stderr, exit code
- Apply timeout (from resource bounds, if declared)

Output: execution result (success/failure, stdout, stderr, duration).

Failure mode: `execution.result: "failure"`, error details captured.

#### 11.2.11 Audit log emission

Input: all data accumulated through the pipeline.

Operations:
- Construct the audit entry per Chapter 10 schema
- Compute the content-addressed entry_id
- Append to the audit log

Output: audit entry committed.

This stage MUST run even if earlier stages failed. Audit log emission
is mandatory; a resolver that fails to emit an audit entry is
non-conformant.

### 11.3 Encoding handling in the pipeline

Per F-024, parameter encoding is applied between stages 1 and 5,
specifically before template substitution. Templates receive
post-encoding values; they cannot perform encoding themselves.

The encoding stage happens within stage 1 (parameter parsing): when a
parameter has both a value and an encoding, the resolver decodes
during parsing. The substituted value in templates is the decoded
form.

### 11.4 Pipeline determinism

Two invocations of the same intent with identical parameters in
equivalent environments must produce identical results through stages
1-9. Stages 10 and 11 produce timestamps and execution-specific data
that legitimately differ.

This determinism is the basis for:
- **Reproducibility:** same parameters, same outcome
- **Testability:** policy changes can be evaluated against historical
  audit logs without re-running the intents
- **Verification:** suspicious behavior can be isolated to a specific
  pipeline stage

### 11.5 Pipeline observability

Implementations should expose pipeline timing metrics:
- Time spent in each stage
- Overall pipeline duration
- PDP query latency
- Execution duration (already in audit log)

These metrics enable performance tuning and detection of pathological
intents (specs that exercise expensive Cedar policies, specs whose
expansion produces excessive PDP queries).

---

## Chapter 12 — Pagination and streaming

When an intent produces result sets that don't fit a single
return, the format supports three modes for handling large output:
`bounded`, `paginated`, and `streamed`. Each has distinct Cedar
projection rules and audit semantics. Resolves F-016.

### 12.1 Mode selection

The `output` declaration in `signature` includes a `streaming` field
declaring which mode applies:

```yaml
signature:
  output:
    type: <type reference>
    streaming: bounded | paginated | streamed
```

Default is `bounded` (the v0.1 behavior). Specs that produce
potentially-large output should explicitly declare paginated or
streamed.

### 12.2 Bounded mode

The intent returns the full result in a single response, capped by a
resource bound parameter (typically `max_size` or `max_entries`). If
the natural result exceeds the bound, the result is truncated and a
`truncated: true` flag is set in the output.

```yaml
signature:
  inputs:
    - name: max_entries
      type: int
      default: 1000
      is_resource_bound: true
  output:
    type: DirectoryListing
    streaming: bounded
```

PDP evaluation: single PDP query per capability, evaluated once.

Audit log: single audit entry per invocation.

Cedar projection: standard; nothing pagination-specific.

Bounded is appropriate when:
- The natural result is usually small
- Truncation losing data is acceptable when it occurs
- Callers don't need to retrieve the truncated portion

### 12.3 Paginated mode

The intent returns one page of results plus a continuation token. The
caller invokes the intent again with the token to retrieve the next
page. Pagination ends when no more results exist (continuation_token
is null).

```yaml
signature:
  inputs:
    - name: page_size
      type: int
      default: 100
      is_resource_bound: true
    - name: continuation_token
      type: string
      optional: true
      description: |
        Token returned by a prior invocation; pass to retrieve next page.
        Null/absent on first page.
  output:
    type: PaginatedResult
    streaming: paginated
    schema: |
      PaginatedResult {
        items: list<...>
        continuation_token: string | null   # null on last page
      }
```

PDP evaluation: each page is a separate PDP query. The Cedar context
carries `continuation_of: <prior_query_audit_id>` to link related
queries:

```cedar
context: {
  "intent_name": "list_directory",
  "intent_version": "2.0.0",
  "purpose": "user_facing",
  "page_number": 3,
  "continuation_of": "<audit_entry_id_of_prior_page>",
  ...
}
```

This lets policies write rules over paginated sessions:

```cedar
forbid (
  principal,
  action == Lki::Action::"Filesystem::Read",
  resource
) when {
  context.page_number > 100   // refuse runaway pagination
};
```

Audit log: one entry per page. Entries are linked via
`continuation_of` references for analysis.

Paginated is appropriate when:
- Result sets are naturally large and bounded
- Callers want stop-and-resume control
- Per-page PDP evaluation is acceptable (not too expensive)

### 12.4 Streamed mode

The intent returns a handle to a stream the caller iterates. The
resolver evaluates Cedar once at handle creation; the caller can pull
items until exhausted or until they close the handle.

```yaml
signature:
  inputs:
    - name: pattern
      type: Regex
    - name: paths
      type: list<FilePath>
  output:
    type: StreamHandle
    streaming: streamed
    item_type: Match
```

PDP evaluation: once at handle creation. The Cedar request reflects the
total intent — paths, pattern, capability requirements — and the PDP
decision authorizes the entire stream.

Audit log:
- One entry at stream creation with full PDP decision
- One entry per N items consumed (configurable batching) with running
  totals, no PDP re-evaluation
- One entry at stream close with final totals

The trade-off: streamed has less granular policy enforcement (no
per-item check) but allows much higher throughput. Use when the result
set is potentially huge and per-item PDP overhead would be unacceptable.

Cedar policies for streamed mode can constrain the request to bounded
totals:

```cedar
forbid (
  principal,
  action == Lki::Action::"Filesystem::Read",
  resource
) when {
  context.streaming_mode == "streamed" &&
  context.estimated_result_count > 100000
};
```

Streamed is appropriate when:
- Result sets can be huge (millions of items)
- Per-item PDP evaluation would dominate execution cost
- Coarse-grained authorization at stream creation is acceptable

### 12.5 Mode interaction with capability declarations

Capabilities don't change between modes — a `grep_files` intent
declares the same filesystem.read capability regardless of which mode
its output uses. What changes is when and how often Cedar is consulted.

The `streaming` field on output declarations is purely about the
output handling. Capability checks are still per-capability-instance
per resolved-resource-instance, just evaluated at different times.

### 12.6 Conversion between modes

An intent's `streaming` mode is part of the intent's signature; it
doesn't vary per invocation. A spec author who wants to support
multiple modes for the same logical operation should declare separate
intents (variants per Chapter 1):

- `grep_files` — paginated, default
- `grep_files_streaming` — streamed, for huge result sets
- `grep_files_bounded` — bounded, for small known-bounded results

Per Chapter 9.10, these may share Cedar actions if their capability
semantics are identical. The audit log differentiates via
`intent_name`.

### 12.7 Resource bounds in streaming modes

`is_resource_bound: true` parameters work across modes but with
slightly different semantics:

- **Bounded:** `max_entries` is the cap on returned results
- **Paginated:** `page_size` is the per-page cap; total result count
  is unbounded
- **Streamed:** `max_items` (when declared) is the cap on total items
  consumable from the stream before forced close

Resolvers enforce the relevant cap per mode. Cedar policies can
constrain the bound value as a resource bound.

---
## Chapter 13 — Examples section

The `examples` section in an LKI spec contains `(intent, expected_command)`
pairs that document, validate, and (when applicable) train.

### 13.1 Purpose

Each example serves four simultaneous purposes:

1. **Documentation** — readers see concrete usage at varying complexity
2. **LLM few-shot context** — foundation models prompted with these
   examples produce more reliable invocations
3. **Policy test cases** — each example is a positive test for the
   enforcement layer (should be allowed under permissive policy)
4. **Tool-SI training data** — when Tool-SI is trained for this intent
   (optional, see Chapter 1)

The format is the same regardless of which purpose dominates for a
given deployment.

### 13.2 Structure

```yaml
examples:
  - description: <human-readable summary>
    intent:
      <parameter>: <value>
      # all signature parameters either with concrete values or omitted (for defaults)
    expected_command: |
      <literal string the resolver should produce>
    notes: <optional explanation of edge cases or what this exercises>
```

### 13.3 Coverage guidance

For documentation, few-shot context, and policy testing purposes,
three examples is the recommended minimum per spec, ideally covering:

1. The simplest valid invocation (minimum required parameters)
2. A common case with several optional parameters set
3. An edge case or unusual parameter combination

If the spec uses cases-structured templates (Chapter 6.5), examples
should exercise each major case. The resolver's case selection is
behavior the examples should make verifiable.

If Tool-SI training is pursued for an intent, dozens to hundreds of
examples per intent are required, generated synthetically against the
spec and verified by sandbox execution. The examples in the spec file
are exemplars of shape and document the contract; they are not the
Tool-SI training corpus.

### 13.4 Examples and cases-structured templates

When a spec uses cases-structured templates, examples should
demonstrate the case selection logic. The `expected_command` reflects
which case was selected for the given parameters:

```yaml
examples:
  - description: "Atomic replace mode (the default)"
    intent:
      path: "/home/agent/workspace/output.txt"
      content: "Hello\n"
    expected_command: |
      tmpfile=$(mktemp ...) && printf '%s' 'Hello\n' > "$tmpfile" && mv -- "$tmpfile" /home/agent/workspace/output.txt
    notes: "atomic=true and mode=replace are defaults; this exercises the atomic-replace case"

  - description: "Append mode with append-safe semantics"
    intent:
      path: "/home/agent/workspace/log.txt"
      content: "Entry\n"
      mode: append
    expected_command: |
      printf '%s' 'Entry\n' >> /home/agent/workspace/log.txt
    notes: "mode=append selects a different case template"
```

This makes the case-selection logic part of the verifiable contract.
Test infrastructure can verify that the resolver's case selection
matches the documented examples.

### 13.5 Examples and resource bounds

Examples should exercise resource-bound parameters at varying values
to demonstrate that the resolver handles them correctly:

```yaml
examples:
  - description: "Default timeout (30 seconds)"
    intent:
      url: "https://api.example.com/data"
    expected_command: |
      curl --max-time 30 ...

  - description: "Extended timeout for known-slow endpoint"
    intent:
      url: "https://slow.example.com/heavy-query"
      timeout: 120s
    expected_command: |
      curl --max-time 120 ...
```

Cedar policies that constrain resource bounds (Chapter 9.3.2) can be
tested against these examples — the test infrastructure replays the
example through PDP and verifies the expected outcome.

### 13.6 Examples and pagination modes

For paginated and streamed intents (Chapter 12), examples should
demonstrate the pagination contract:

```yaml
examples:
  - description: "First page request"
    intent:
      pattern: "TODO"
      paths: ["./src"]
      page_size: 50
    expected_command: |
      rg --max-count 50 'TODO' ./src

  - description: "Subsequent page with continuation token"
    intent:
      pattern: "TODO"
      paths: ["./src"]
      page_size: 50
      continuation_token: "eyJvZmZzZXQiOjUwfQ"
    expected_command: |
      rg --max-count 50 --skip 50 'TODO' ./src
    notes: "Continuation token decodes to offset; resolver uses --skip"
```

For streamed intents, examples show the handle-creation form only;
per-item retrieval is the caller's iteration over the handle.

### 13.7 What examples should not include

Examples are not the place for:
- **Error cases** — those are anti-patterns (Chapter 14)
- **Performance benchmarks** — duration measurements vary by environment
- **Output content** — examples specify `expected_command`, not what
  the command produces when run
- **Resolution of observed attributes** — examples assume canonical
  paths and observed state at request time; they don't include the
  resolver's canonicalization steps

If an intent's behavior is too complex to capture in clean examples,
that's a signal the intent's scope may be too broad. Consider
splitting into variant intents (Chapter 1) where each variant has
demonstrable examples.

---

## Chapter 14 — Anti-patterns section

The `anti_patterns` section documents known bad usages with structured
explanations. Anti-patterns serve as documentation, test cases for
enforcement layers, and (when Tool-SI is trained) negative training
signal.

### 14.1 Structure

```yaml
anti_patterns:
  - bad: <the bad form, as a literal pattern or command>
    reason: <explanation of why this is bad>
    rejection: <which layer of enforcement catches it and how>
```

### 14.2 Anti-pattern categories

Anti-patterns fall into three categories based on which enforcement
layer rejects them:

**Cedar-rejected:** rejection is via a Cedar safety floor policy
generated from the anti-pattern. The rejection field references
structural properties of entities or context attributes that map to
Cedar predicates.

```yaml
- bad: 'curl https://example.com -o /etc/cron.d/job'
  reason: "Writes downloaded content to a privileged execution path"
  rejection: |
    Output path satisfies resource.is_system_path = true; Cedar safety
    floor policy forbids writes to system paths.
```

The projection generator (Chapter 9.8.1) reads this rejection and
emits a corresponding `forbid` policy.

**Resolver-rejected:** rejection happens at resolver constraints
(Chapter 4.5) or parameter validation (Chapter 11 stage 1-3). The
rejection field describes which check catches it.

```yaml
- bad: 'rm -rf $VAR'
  reason: "Unbounded variable expansion"
  rejection: |
    Intent declares paths as a typed list. Shell variable expansion
    happens before intent construction; the intent receives the
    resolved literal paths. Empty list is rejected at intent
    construction.
```

These do not generate Cedar safety floor policies because Cedar isn't
the enforcement layer — the resolver is.

**Type-rejected:** rejection at type parsing. The bad form contains
something the type system refuses to accept.

```yaml
- bad: 'grep "${USER_PATTERN}" data.txt'
  reason: "Pattern from agent-controlled string can include ReDoS constructs"
  rejection: |
    pattern is a typed Regex with declared grammar. Pattern validation
    against the declared grammar happens at parameter parsing; ReDoS
    constructs in perl mode are rejected before any other processing.
```

Like resolver-rejected, these don't generate Cedar policies; the
projection generator notes them as "documented as type-level rejections."

### 14.3 Coverage guidance

Minimum 2 anti-patterns per spec is recommended for policy test
coverage. Better specs have:

- At least one Cedar-rejected anti-pattern (verifies safety floor
  generation)
- At least one resolver-rejected anti-pattern (verifies resolver
  constraints work)
- At least one type-rejected anti-pattern (verifies type validation works)

Coverage of all three categories demonstrates the layered enforcement
model is exercised by the spec's tests.

### 14.4 Writing rejections that the projection generator can use

For Cedar-rejected anti-patterns, the `rejection` field should
reference structural properties using consistent vocabulary. The
projection generator pattern-matches on these phrases:

| Phrase pattern | Generated Cedar predicate |
|---|---|
| `resource.is_system_path = true` | `resource.is_system_path` |
| `resource.is_metadata = true` | `resource.is_metadata` |
| `!resource.is_within_working_dir` | `!resource.is_within_working_dir` |
| `context.X = "Y"` | `context.X == "Y"` |
| `resource.<attribute> matches "<pattern>"` | `resource.<attribute> like "<pattern>"` |

The phrase-pattern grammar is documented in `cedar-from-lki`'s
projection rules. Anti-patterns whose rejection doesn't match a
pattern are categorized as "manual review needed" — the projection
generator flags them for spec authors to either reword or accept that
no Cedar policy will be generated from them.

This pattern-matching is intentionally limited. Anti-patterns that
need expressive Cedar policy should be hand-written in the tenant
template; the auto-generation is for the obvious cases only.

### 14.5 Anti-patterns and intent variants

When an intent has variants (Chapter 1), anti-patterns can be:

- **Variant-specific:** documented in the variant's spec, not the base
- **Shared across all variants:** documented in a registry reference

For shared anti-patterns, the v0.2 format supports referencing a
shared anti-pattern registry (similar to the type registry from
Chapter 5):

```yaml
anti_patterns:
  - $ref: "registries/anti_patterns/v0.2/system_path_writes.yaml"
  - bad: 'curl --insecure https://internal/secrets'
    reason: "Bypasses TLS verification"
    rejection: "fetch_url cannot disable TLS"
```

References are resolved at spec load time. Tooling validates that
references resolve to existing anti-pattern entries.

### 14.6 What anti-patterns should not include

Anti-patterns are not the place for:
- **Stylistic preferences** — "use single quotes not double quotes"
  is not a security or correctness concern
- **Performance anti-patterns** — performance issues are
  documentation concerns, not enforcement concerns
- **Best practices** — "you should use HTTPS" is a tenant policy
  choice, not a universal anti-pattern
- **Implementation-specific issues** — anti-patterns are about the
  intent contract, not how specific tools fail

If an anti-pattern doesn't translate to a rejection at any enforcement
layer, it doesn't belong in the spec — it belongs in documentation.

---

## Chapter 15 — Format evolution discipline

LKI is an actively-evolving format. v0.x versions are explicitly
expected to be revised based on accumulated evidence of where the
format fights real specs. This chapter formalizes the evolution
discipline.

### 15.1 Version immutability

Once shipped, a format version is immutable. Editing `LKI_FORMAT_v0.2.md`
to add corrections or clarifications is not permitted; corrections
go in a new version.

This discipline preserves the historical record. Someone reading the
project's evolution six months from now must be able to see exactly
what each version was when it shipped, including its limitations.

The same discipline applies to:
- LKI format spec versions (v0.1, v0.2, ...)
- Intent versions (fetch_url@1.0.0, @2.0.0, ...)
- Type and entity registry versions (FilePath@1.0.0, ...)
- Tool registry versions
- Cedar projection artifact versions

### 15.2 Findings documents

Each format version has an associated FINDINGS document that accumulates
issues observed during use:

- `FINDINGS_v0.1.md` was opened when v0.1 shipped, closed when v0.2 ships
- `FINDINGS_v0.2.md` opens now; closes when v0.3 ships
- `FINDINGS_v0.x.md` follows the same pattern

Findings are tagged with source attribution:
- `[scoping]` — known limitation from original version's design
- `[projection]` — surfaced by Cedar projection of a spec
- `[drafting]` — surfaced by writing a spec against this version
- `[deployment]` — surfaced by deploying specs in real environments
- `[research]` — surfaced by external research or analysis

Each finding describes the issue, why it matters, and proposes a
direction for the next version. Proposals are not commitments; the
next version may handle differently.

### 15.3 Evolution rhythm

The expected pattern:

1. **Ship a format version** with known limitations documented
2. **Use the version** by drafting specs and performing projections
3. **Accumulate findings** in the FINDINGS document for that version
4. **When findings density is high enough** (typically 15-30 findings),
   start the next-version drafting
5. **Triage findings** with explicit accept/modify/reject/defer decisions
6. **Draft the next version** incorporating accepted findings
7. **Migrate existing specs** to the new version
8. **Close the prior FINDINGS document** with each finding marked as
   resolved or carried forward
9. **Open the next FINDINGS document** and repeat

The cadence is evidence-driven. v0.1 to v0.2 took approximately three
months and seven shipped specs. Future revisions should follow similar
timing — long enough for real evidence, not so long that the format
becomes calcified.

### 15.4 Migration discipline

When a new format version ships, existing specs migrate. Migration is
explicit:

- **Mechanical migrations** can be auto-applied by tooling (e.g.,
  renaming sections, restructuring identical content)
- **Substantive migrations** require human review (e.g., the three-axis
  state mutation from v0.1's `atomic: bool` requires actually
  thinking about what each spec's atomicity claim means)

A `MIGRATION_FROM_v0.x.md` document accompanies each new version,
covering both mechanical and substantive migrations.

Migrated specs get new intent versions (e.g., v1.x.x intents become
v2.0.0). The old versions remain as historical artifacts in the
versioned spec directory.

### 15.5 Breaking changes

Breaking changes within a format version are forbidden once shipped.
Across format versions, breaking changes are tolerated:

- **v0.1 → v0.2:** breaking changes expected; we are still learning
  the right shape
- **v0.2 → v0.3:** breaking changes acceptable but should be rare
- **v0.x → v1.0:** the transition to v1.0 indicates the format has
  stabilized; breaking changes after v1.0 require strong justification
- **Post v1.0:** breaking changes follow semver discipline on the
  format itself (major version bumps, with deprecation windows)

v0.2 is still in the "we're learning" phase. The expectation is at
least one more major revision (v0.3) before we approach v1.0.

### 15.6 Compatibility guarantees

Within a format major version, intent versions follow standard semver:

- Same format major version + same intent major version: forward
  and backward compatible at the policy/projection level
- Different format versions: no compatibility guarantee; resolvers
  may support multiple format versions but the spec authors should
  not assume this

Tooling that consumes LKI specs (resolvers, cedar-from-lki,
tool-si-data-from-lki) declares which format versions it supports.
Specs declare their format version via `lki_version:`. Mismatches
produce explicit errors, not silent acceptance.

### 15.7 The format spec is itself a deliverable

This document — the format specification — is a versioned, immutable
artifact in the same way as LKI specs themselves. Future versions
will not edit this document; they will create new versions.

The format spec exists because the format must be precisely defined
for tooling to be interoperable. Different cedar-from-lki
implementations must produce the same Cedar from the same input. The
format spec is the contract that makes interoperability possible.

This is also why the format spec includes design rationale, not just
syntax. Future revisers need to understand *why* decisions were made,
not just *what* the decisions were. The rationale lets revisers
decide whether changed circumstances warrant changing the decision.

### 15.8 Closing v0.2

When v0.3 ships:

1. `FINDINGS_v0.2.md` is closed; each finding is marked as resolved
   in v0.3 or carried forward to FINDINGS_v0.3.md
2. `MIGRATION_FROM_v0.2.md` is published alongside v0.3
3. The v0.2 spec library migrates to v3.0.0 intent versions
4. v0.2 cedar projections migrate to v3.0.0
5. v0.2 specs and projections remain in their versioned directories as
   historical record

The pattern repeats indefinitely. Format evolution is the steady-state
of the project, not a phase that ends.

---

## End of v0.2 format specification

This concludes the LKI Format Specification v0.2. The complete spec
comprises:

- Chapter 1: Purpose and scope
- Chapter 2: Versioning
- Chapter 3: Spec file structure
- Chapter 4: Spec file structure continued
- Chapter 5: Type and entity catalog
- Chapter 6: Interpolation and expression grammar
- Chapter 7: Capability section (with revised 7.7)
- Chapter 8: Implementation section
- Chapter 9: Cedar projection rules
- Chapter 10: Audit log structure
- Chapter 11: Resolver execution model
- Chapter 12: Pagination and streaming
- Chapter 13: Examples section
- Chapter 14: Anti-patterns section
- Chapter 15: Format evolution discipline

Companion documents:
- `MIGRATION_FROM_v0.1.md` — how to migrate v0.1 specs and projections to v0.2
- `FINDINGS_v0.2.md` — opens to accumulate findings during v0.2 use

Implementation deliverables:
- `cedar-from-lki` — projection tool
- `lki-validate` — spec validation against this format
- `tool-si-data-from-lki` — optional Tool-SI training data extractor
- `lki-migrate` — automated mechanical migrations between format versions

These are not part of the format spec itself; they are tooling that
consumes specs in this format.
