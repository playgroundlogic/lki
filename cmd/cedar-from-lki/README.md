# cedar-from-lki

Project LKI specs to Cedar artifacts.

## What this tool does

Given a directory of LKI specs (`.yaml` files conforming to the v0.2
format spec) plus the type and tool registries, produce:

1. **`schema.cedarschema`** — Cedar schema declaring entity types and
   action types covering all input specs
2. **`policies/<intent>/v<N>.0.0/`** — three-tier policy templates per
   spec: `safety_floor.cedar`, `baseline.cedar`, `tenant_template.cedar`
3. **A validation report** — tools referenced in specs but missing from
   the registry, action context inconsistencies across specs, etc.

The projection rules are documented in **Chapter 9 of the format
specification** (`format/v0.2/LKI_FORMAT.md`). Two reference projections
exist at `projections/fetch_url/v2.0.0/` and `projections/commit_changes/v2.0.0/`.

## Success criterion

Running `cedar-from-lki` against `specs/cli/` and the v0.2 registries
should produce output that is byte-identical (modulo deterministic
ordering) to the committed projections at `projections/{fetch_url,commit_changes}/v2.0.0/`.

The two projections in the repo serve as golden files for the tool's
test suite.

## Usage (planned)

```
cedar-from-lki [flags] <specs-dir> [-o <output-dir>]

Flags:
  --format-version=0.2       Target format version (default: latest in specs-dir)
  --type-registry=<path>     Path to types directory (default: ./types)
  --tool-registry=<path>     Path to tool registry (default: ./registries/tools)
  --check                    Verify-only mode; report deviations from committed projections
  --diff                     Show diff against committed projections (implies --check)
```

## Status

Skeleton only. Implementation pending. See [TOOLING.md](../../TOOLING.md)
for the overall tooling design.

## Implementation notes

The projection algorithm in Chapter 9.9 of the format spec is:

1. Walk type registries, emit Cedar entity type declarations
2. Walk tool registry, emit Tool entity declarations with attributes
3. Walk specs; for each capability declaration, identify
   `(category, operation, specifier)` and emit action type if new
4. Validate cross-spec consistency (action context schemas match
   across specs that contribute to the same action)
5. For each spec, generate the three-tier policy templates per
   Chapter 9.8
6. Emit schema and policies in alphabetical order within each category
   for stable diffs across runs

The tool should be deterministic — same input produces byte-identical
output across runs.

## Dependencies

- `gopkg.in/yaml.v3` for YAML parsing
- Cedar Go bindings TBD (verifying via `cedar-go` when emission becomes
  schema-aware; v1 of the tool can emit Cedar text without round-tripping
  through the schema-aware library)
