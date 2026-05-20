// Package projection applies the Cedar projection rules from Chapter 9
// of the LKI Format Specification.
//
// Inputs:
//   - A set of parsed LKI specs (from the spec package)
//   - Type and tool registries
//
// Outputs:
//   - A Cedar schema (entity types, action types, context attributes)
//   - Per-spec policy templates (safety_floor, baseline, tenant_template)
//   - A validation report (missing tool entries, context schema
//     inconsistencies across specs, etc.)
//
// Projection is deterministic: the same input set produces byte-identical
// output across runs. This is essential for the golden-file test
// approach using the committed projections at projections/.
//
// The projection algorithm is documented in Chapter 9.9.
package projection
