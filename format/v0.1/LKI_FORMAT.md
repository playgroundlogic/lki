# LKI Format Specification v0.1

**Status:** Draft, actively iterating
**Format version:** `0.1`
**Last updated:** 2026-05-18

## Purpose

LKI (LLM Knowledge Intent) is a spec format for declaring agent-invokable
operations in a structure that:

1. Aligns intent representation with how LLMs already reason (the LKI layer)
2. Projects cleanly to Cedar policy for capability enforcement
3. Resolves to concrete implementations across one or more candidate tools
4. Optionally produces training data for specialized Tool-SI models when
   higher reliability than foundation models is justified by measurement

A single LKI spec file is the source of truth for one *intent* — a named,
typed, capability-declared operation an agent can request. Cedar policies,
implementation routing, audit log structure, and Tool-SI training data are
all derived from the spec; they are not separate artifacts requiring
separate maintenance.

This document defines the format that v0.1 LKI specs conform to. Future
versions will extend or modify; breaking changes bump the major version
of the format itself.

## Tool-SI: what it is, and that it is not required

LKI-based systems work today with foundation models alone. An agent
(using Claude, GPT-4, Gemini, or any capable LLM) emits a structured
intent conforming to an LKI spec; the resolver picks an implementation
and constructs the command per the spec's templates; Cedar PDP gates
execution against derived policy; the audit log records the decision.
Foundation models consume LKI specs as structured input; their first-pass
correctness on the discrete output space LKI provides is usually
adequate for production deployment.

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

---

## Versioning (three layers)

Every LKI spec participates in three independent versioning regimes.

### 1. Format version

Top-level field, declares which version of *this document* the spec conforms to:

```yaml
lki_version: "0.1"
```

Required on every spec. Tools that consume LKI specs (Cedar projection
generator, Tool-SI training data extractor, resolver) check this field and
refuse to process unsupported versions rather than guess.

Format version bumps on:
- New required sections
- Removal of sections
- Breaking changes to interpolation grammar
- Breaking changes to the type catalog
- Breaking changes to capability declaration structure

Format version does NOT bump on:
- Addition of optional sections
- Addition of new types to the catalog (additive only)
- Clarifications to wording that don't change semantics

### 2. Intent version

Each individual intent declares its own semver:

```yaml
spec:
  intent: fetch_url
  intent_version: "1.0.0"
```

Required. Consumers can pin to specific intent versions: `fetch_url@^1.0`
means "any 1.x of fetch_url, do not auto-apply breaking changes in 2.0."

Intent version bumps on:
- **Major** (2.0.0 ← 1.x.x): Signature changes (parameter added without
  default, parameter removed, parameter type changed), capability requirement
  changes (new capabilities added), behavior semantics changed
- **Minor** (1.2.0 ← 1.1.x): New optional parameters with defaults, new
  implementation tools added, new examples added, new anti-patterns documented
- **Patch** (1.0.1 ← 1.0.0): Description text changes, typo fixes, example
  wording improvements, anti-pattern reason rewording — no semantic change

Tool-SI training data is keyed by `(intent_name, intent_version)`. When intent
version bumps majorly, training data must be regenerated against the new
contract. Minor and patch bumps do not invalidate existing training data.

### 3. Tool version pinning

The `implementation` section declares minimum and tested-against versions per
tool:

```yaml
implementation:
  - tool: curl
    requires: "curl >= 7.50"
    tested_against: ["curl 7.81.0", "curl 8.4.0"]
```

The `requires` field is the *minimum* version for the implementation to apply.
The `tested_against` field is the *verified* versions where the spec has been
validated to produce correct invocations.

Resolvers may warn or refuse when a tool's available version is:
- Below `requires` (refuse — known incompatibility)
- Above the highest `tested_against` (warn — unverified)
- Outside the `tested_against` range entirely (warn or refuse, configurable)

This matters for reproducibility. Environments that need to reproduce
behavior six months later must be able to pin to specific tool versions and
know whether the LKI specs have been validated against those versions.

---

## Top-level structure

Every LKI spec is a YAML document with this skeleton:

```yaml
lki_version: "0.1"

spec:
  intent: <snake_case_identifier>
  intent_version: "<semver>"
  description: <one-line summary>

  signature:
    inputs: [<typed parameter list>]
    output: <type or union>

  behavior: |
    <multi-line description of what the intent does>

  constraints:
    - <constraint statement>
    # ...

  capability:
    <capability category>:
      - <capability requirement>
    # ...

  implementation:
    - tool: <tool name>
      requires: <version constraint>
      tested_against: [<version list>]
      preferred: <bool, optional>
      template: |
        <command template with interpolation>
      parameter_mapping:
        <parameter name>:
          <value>: <expansion>
      notes: <optional notes>
      limitations:
        - <optional limitation>

  examples:
    - description: <human-readable example summary>
      intent:
        <parameter>: <value>
        # ...
      expected_command: |
        <what the resolver should produce>

  anti_patterns:
    - bad: <the bad form, as a command or pattern>
      reason: <why this is rejected>
      rejection: <how the layered enforcement catches it>
```

### Required vs optional sections

**Required on every spec:**
- `lki_version`
- `spec.intent`
- `spec.intent_version`
- `spec.description`
- `spec.signature`
- `spec.behavior`
- `spec.capability`
- `spec.implementation` (minimum one entry)

**Optional but strongly recommended:**
- `spec.constraints`
- `spec.examples` (minimum 3 for Tool-SI training viability)
- `spec.anti_patterns` (minimum 2 for policy test coverage)

---

## Interpolation grammar

Templates and capability declarations use a deliberately simple substitution
grammar. v0.1 supports exactly the following forms:

### Plain substitution

```
{name}
```

Substitutes the value of parameter `name`, rendered using the type's default
string representation.

### Attribute access

```
{name.attribute}
```

Substitutes an attribute of the parameter. The type catalog (below) declares
which attributes each type exposes. Examples:
- `{url.host}`, `{url.scheme}`, `{url.port}`, `{url.path}`
- `{path.canonical}`, `{path.parent}`, `{path.basename}`

### Method invocation

```
{name.method}
```

Substitutes the result of calling a parameterless method on the parameter.
Methods are declared per type. Examples:
- `{timeout.seconds}` — Duration rendered as integer seconds
- `{paths.canonical}` — list of FilePaths each canonicalized

v0.1 does not support method arguments. If a method would need arguments,
either declare a more specific method or add a new parameter to the signature.

### Conditional rendering

```
{name?value_if_present:value_if_absent}
```

For optional parameters. If `name` has a value, renders `value_if_present`
with the parameter available for further interpolation; otherwise renders
`value_if_absent`. Either branch may be empty.

Example:
```
{output?--output {output}:}
```
Renders `--output /tmp/file` when `output` is set, empty string otherwise.

### List handling

```
{name[...]}
```

Renders each element of a list parameter, joined by the separator inside
the brackets. Default separator is single space.

Example:
```
{paths[ ]}
```
For `paths: ["/a", "/b", "/c"]` renders `/a /b /c`.

### What's deliberately not supported in v0.1

- Nested interpolation (`{outer{inner}}`)
- Recursive evaluation of substituted values
- Conditional logic beyond presence checks (no `==`, `>`, `<`)
- Loops or iteration constructs (the list form is the only iteration)
- Function calls with arguments
- Arithmetic

These omissions are intentional. The grammar is meant to be obviously parseable
and obviously bounded. If a spec wants something the grammar can't express, the
right answer is usually a richer type with a method that does the work, not a
richer interpolation grammar.

---

## Type catalog (v0.1)

The type catalog declares the typed parameters LKI specs can use, what
attributes and methods each type exposes, and what constraints the type
carries.

### Primitive types

- `string` — UTF-8 text. No attributes. Method: `.length` (integer).
- `int` — 64-bit signed integer. No attributes. Methods: `.abs`, `.sign`.
- `float` — 64-bit IEEE 754. Methods: `.abs`, `.sign`, `.rounded`.
- `bool` — true/false. No attributes or methods.
- `bytes` — arbitrary byte sequence. Methods: `.length`, `.base64`.

### Structured types

- `URL` — RFC 3986 URI.
  - Attributes: `.scheme`, `.host`, `.port`, `.path`, `.query`, `.fragment`
  - Methods: `.canonical` (canonicalized form), `.is_loopback`, `.is_private`
  - Constraints: scheme must be in declared allowed set; defaults to `http`/`https`
- `FilePath` — filesystem path.
  - Attributes: `.parent`, `.basename`, `.extension`
  - Methods: `.canonical` (resolved against working_dir, .. resolved or rejected per policy), `.absolute`, `.is_writable_by_policy`
  - Constraints: declared-shell-metacharacter rejection at parse time
- `Duration` — time duration.
  - Methods: `.seconds`, `.milliseconds`, `.iso8601`
  - Parsed from strings like `30s`, `2m`, `1h30m`, `PT1H30M`
- `Regex` — typed regex with declared grammar.
  - Attributes: `.grammar` (returns the declared grammar — `fixed`, `basic_posix`, `extended_posix`, `perl`)
  - Methods: `.complexity_class` (returns bounded/unbounded), `.compiled` (returns the parsed AST representation)
  - Constraints: length limit per spec, ReDoS-construct rejection for unbounded grammars

### Compound types

- `list<T>` — homogeneous list of type T.
  - Attributes: `.length`
  - Methods: `.canonical` (applies T's `.canonical` to each element if defined)
  - Bracket interpolation: `{list_param[separator]}`
- `map<K,V>` — string-keyed map.
  - Methods: `.keys`, `.values`, `.entries`
- `enum<A, B, C>` — bounded enumeration over named values.
  - Methods: none beyond default rendering
- `union<A | B | C>` — sum type; output unions are common for "returns bytes
  OR writes to file" patterns.

### Adding new types

v0.1 type catalog additions are non-breaking for the format version (no
`lki_version` bump). Each new type must declare:
- Its attributes (and the types those attributes return)
- Its methods (and the types those methods return)
- Its constraint set (what the type enforces at parse time)
- Its rendering rules (how it appears in templates)

Type catalog evolution lives in `TYPES.md` (separate document, this one is
the format spec). New types are appended; existing types are not modified
within a format version.

---

## Capability section structure

The `capability` section is the primary projection target for Cedar policy.
It declares what an instance of this intent (with concrete parameters)
*will need to do*, expressed in entity-action-resource shape.

### Capability categories (v0.1)

```yaml
capability:
  network:
    - direction: <inbound | outbound>
      host: <interpolated string>
      port: <int or interpolated>
      protocol: <enum: http, https, tcp, udp, raw>
  filesystem:
    - operation: <read | write | delete | execute>
      paths: <list of interpolated FilePath>
      recursive: <bool, optional>
      follow_symlinks: <bool, default false>
      canonical: <bool, default true>
  process:
    - operation: <spawn | signal | kill>
      target: <interpolated string>
      uid_required: <enum: current | root | declared>
  state_mutation:
    - operation: <write | append | delete>
      resource: <interpolated entity reference>
      reversible: <bool>
  compute:
    - bounded_regex: <bool>
      max_pattern_complexity: <constraint declaration>
    - bounded_time: <Duration>
    - bounded_memory: <bytes specification>
```

`network`, `filesystem`, `process`, `state_mutation`, and `compute` are the
five capability categories in v0.1. Future versions may add more (notably
expected: `gpu`, `kernel_hooks`, `external_state`).

The interpolation inside capability declarations follows the same grammar as
templates. Capability requirements are evaluated *after* parameter values are
known, so `{url.host}` resolves to the concrete host before Cedar PDP runs.

### Cedar projection

The capability section maps to Cedar by the following rules:

- Each capability category becomes a Cedar entity type
- Each operation becomes a Cedar action
- Interpolated values become attributes on the action's request context
- Cedar policies are written against `Action::"<category>::<operation>"` with
  attribute constraints

A `cedar-from-lki` generator (planned, not yet built) takes a directory of
LKI specs and emits the Cedar schema plus policy templates. v0.1 specs do
not include hand-written Cedar; Cedar is derived.

---

## Examples section

Each entry in `examples` is a `(intent, expected_command)` pair. These
pairs serve four purposes simultaneously, none of which is privileged:

1. **Documentation** — readers see concrete usage at varying complexity
2. **LLM few-shot context** — foundation models prompted with these
   examples produce more reliable invocations
3. **Policy test cases** — each example is a positive test for the
   enforcement layer (should be allowed under permissive policy, and
   anti-patterns provide the complementary negative tests)
4. **Tool-SI training data** — when Tool-SI is being trained for this
   intent (optional)

The format is the same regardless of which purpose dominates for a given
deployment:

```yaml
examples:
  - description: <human summary>
    intent:
      <parameter>: <value>
      # all signature parameters either with concrete values or omitted (for defaults)
    expected_command: |
      <literal string the resolver should produce>
    notes: <optional explanation of edge cases this example covers>
```

For documentation, few-shot context, and policy testing purposes, three
examples is the recommended minimum per spec, ideally covering:
1. The simplest valid invocation (minimum required parameters)
2. A common case with several optional parameters set
3. An edge case or unusual parameter combination

If Tool-SI training is pursued for an intent, dozens to hundreds of
examples per intent are required, generated synthetically against the
spec and verified by sandbox execution. The examples in the spec file
are exemplars of shape and document the contract; they are not the
Tool-SI training corpus themselves.

---

## Anti-patterns: rejection corpus

Each entry in `anti_patterns` is a documented bad usage with explanation:

```yaml
anti_patterns:
  - bad: <the bad form>
    reason: <why this is bad>
    rejection: <which layer of enforcement catches it>
```

The `bad` field is a literal command or invocation pattern that an agent
might attempt. The `reason` is human-readable explanation of the harm. The
`rejection` describes which layer of the LKI stack catches and rejects it —
parameter validation, capability projection, Cedar PDP, audit-log policy,
or runtime constraint.

Anti-patterns serve three purposes:
1. Documentation for spec authors and policy authors
2. Test cases for the enforcement layers (each anti-pattern is a test
   case that should be rejected)
3. Negative training signal for Tool-SI when Tool-SI is trained for this
   intent — not required for v0.1 specs to be usable with foundation
   models

Minimum 2 anti-patterns per spec is recommended for policy test coverage.

---

## Deferred to future versions

Items intentionally not specified in v0.1, with the version they're targeted
for:

### v0.2 candidates

- **Output schemas**: v0.1 uses inline pseudocode (`schema: |`) for complex
  return types. v0.2 should formalize this with the same type catalog used
  for inputs.
- **Endless integration**: Declarations of which fields should trigger
  gap-detection queries. Currently v0.1 specs work without endless;
  missing/unspecified fields produce policy denials rather than clarifying
  questions.
- **State mutation specifics**: The `state_mutation` capability category
  exists but the semantics of `reversible`, the relationship to transactions,
  and rollback declarations are underspecified.

Additional findings accumulated through projection exercises and spec
drafting are tracked in `FINDINGS_v0.1.md` and will be addressed in v0.2.

### v0.3+ candidates

- **Composition**: How an intent that conceptually combines other intents
  (e.g., `clone_repository` ≈ `fetch_url` + `filesystem write` + `git init`)
  declares that composition. Currently each composed operation gets its own
  intent; future versions may allow explicit composition.
- **Side effects beyond output**: Operations like `run_container` whose
  primary effect is process creation, not the returned container ID.
- **Side-channel declarations**: Operations that consume non-obvious
  resources (large memory, GPU, network bandwidth) declared explicitly.
- **Cross-language SI specialization**: Whether an intent should declare
  preferences for which Tool-SI variant handles it (e.g., AWS-specialized
  Tool-SI vs general Tool-SI).

### Open research questions (not v0.2-blocking but tracked)

- **Empirical determination of optimal spec format**: The v0.1 format is
  designed; the empirically-optimal format is unknown. Format may evolve
  based on measured Tool-SI training outcomes.
- **Compositional capability proofs**: Whether multi-intent workflows can
  have their composed capability proven against policy statically. Cedar's
  SMT-decidability suggests yes; implementation deferred.
- **Pattern complexity bounds for typed grammars**: The Regex type declares
  `complexity_class` but the exact bound (what counts as ReDoS-vulnerable)
  needs formalization beyond "nested quantifiers in perl mode."

---

## Format evolution discipline

v0.1 is explicitly draft. The expected evolution:

1. v0.1 specs are written for the next ~10-30 tools using this document
2. Patterns that recur become candidates for format-level support in v0.2
3. Patterns that fight the format become candidates for breaking changes in v0.2
4. v0.2 is defined when the next batch of evidence justifies the changes
5. v0.1 specs may need migration; the migration is documented as part of
   v0.2's release notes

This is the same discipline as protobuf field numbering, OpenAPI spec
evolution, terraform provider schema versions. The format earns its
permanence through use, not through upfront design.

Breaking changes are tolerable in v0.1 → v0.2 but should be rare from v0.2
onward. v0.1's purpose is to be "good enough to ship the first batch and
learn what we got wrong," not to be the permanent answer.

---

## Reference implementations (planned, not yet built)

- `lki-validate` — checks a spec against this format spec, reports violations
- `lki-from-manpage` — generates a v0.1 skeleton from a tool's manpage,
  to be hand-completed
- `cedar-from-lki` — projects the capability section into Cedar schema and
  policy templates
- `tool-si-data-from-lki` — *optional* generator producing synthetic
  Tool-SI training pairs from the examples section and the parameter
  type catalog, for cases where Tool-SI training is justified by
  measured foundation-model error rates
- `lki-resolve` — takes an intent + concrete parameter values + spec, returns
  the resolved command per the implementation section
- `lki-policy-test` — runs anti-patterns through the enforcement stack to
  verify they're correctly rejected

These are downstream artifacts; this document defines the format they
consume and produce.

---

## Contribution patterns

A new LKI spec is contributed via PR to the registry. The PR must include:

1. The spec file (`<intent_name>.yaml`) in the appropriate category directory
2. Minimum required sections per "Required vs optional sections" above
3. Either passing `lki-validate` output, or for v0.1 (before validator exists)
   a manual checklist confirmation
4. A rationale comment explaining the intent's scope — what it does, what it
   deliberately doesn't do, why it's a separate intent rather than a parameter
   of an existing one

Specs go through review for:
- Scope coherence (is this actually a single intent?)
- Capability accuracy (does the capability section actually describe what
  the implementation does?)
- Anti-pattern coverage (are the obvious bad usages documented?)
- Format conformance (does it parse against this document?)

---

## Glossary

- **Intent** — the named, typed, capability-declared operation an agent can
  request. Both the conceptual unit and the artifact (an LKI spec file).
- **LKI** — LLM Knowledge Intent. The substrate: a representation of
  agent-invokable operations aligned with how LLMs reason.
- **Tool-SI** — an *optional* specialized model trained on the
  `(intent, expected_command)` pairs from LKI specs, fine-tuned for
  higher first-pass correctness than foundation models achieve on the
  same task. Not required for LKI-based systems to function. Foundation
  models consume LKI specs directly; Tool-SI is the optimization path
  for intents where measurement demonstrates foundation-model error
  rates are unacceptable for the deployment context.
- **Cedar projection** — the derivation of Cedar policy schema and template
  policies from the `capability` section of LKI specs.
- **Resolver** — the runtime component that takes an LKI intent with concrete
  parameter values, looks up the spec, picks an implementation, and produces
  the executable command.
- **PDP** — Policy Decision Point. Cedar's evaluator, which the resolver
  calls before executing any resolved invocation.

---

*This document is itself versioned. Changes to v0.1 before v0.2 release are
clarifications only; semantic changes bump the format version.*
