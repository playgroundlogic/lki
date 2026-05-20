# lki-validate

Validate an LKI spec against the format specification.

## What this tool does

Given a spec file (or a directory of spec files), verify:

1. **YAML well-formedness** — parses without error
2. **Required sections present** — every required top-level field exists
3. **Format version supported** — `lki_version` declares a version this
   tool supports
4. **Type references resolve** — every `@<version>` reference points to
   a known type in the registry
5. **Capability declarations well-formed** — required fields per
   category, valid resource references, well-formed `required_if`
   expressions
6. **Interpolation grammar valid** — all `{...}` references in templates
   resolve to declared parameters
7. **Implementation references valid** — every tool referenced exists
   in the tool registry
8. **Cross-section consistency** — examples exercise declared
   parameters; anti-patterns reference rejection mechanisms that exist;
   parameter constraints reference parameters that exist

## Success criterion

Running `lki-validate` against the seven committed v2.0.0 specs should
produce zero errors and zero warnings. Running against intentionally-
broken specs (test fixtures) should produce specific errors matching
the broken aspects.

## Usage (planned)

```
lki-validate [flags] <spec-file-or-dir>

Flags:
  --type-registry=<path>     Path to types directory (default: ./types)
  --tool-registry=<path>     Path to tool registry (default: ./registries/tools)
  --strict                   Treat warnings as errors
  --json                     Output structured JSON instead of human-readable text
```

## Status

Skeleton only. Implementation pending.

## Implementation notes

The validation rules are scattered throughout the format spec:
- Chapter 3 — required sections, top-level structure
- Chapter 4 — section-by-section structure
- Chapter 5 — type catalog references
- Chapter 6 — interpolation and expression grammar
- Chapter 7 — capability section structure
- Chapter 8 — implementation section structure
- Chapter 9 — projection-relevant constraints
- Chapter 13 — examples structure
- Chapter 14 — anti-patterns structure

Initial implementation should focus on Chapters 3-8 (the structural
checks). Chapter 9 cross-spec consistency is more naturally enforced
by `cedar-from-lki`'s validation pass.

## Dependencies

- `gopkg.in/yaml.v3` for YAML parsing
