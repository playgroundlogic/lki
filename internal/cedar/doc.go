// Package cedar emits Cedar schemas, policies, and PDP query examples.
//
// Cedar emission is text-based for v1: the package produces .cedarschema
// and .cedar files as strings, without round-tripping through Cedar's
// own AST. This keeps the dependency surface minimal and the output
// directly reviewable.
//
// When Cedar Go bindings stabilize, future versions may emit via the
// schema-aware library for stronger guarantees.
//
// This package does not parse LKI specs; it consumes the in-memory
// representation from the spec package and applies projection rules
// from the projection package.
package cedar
