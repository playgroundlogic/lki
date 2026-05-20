// Package spec parses and validates LKI intent specifications.
//
// An LKI spec is a YAML document conforming to the LKI Format
// Specification (see format/v0.2/LKI_FORMAT.md). This package provides
// the in-memory representation, parser, and validator.
//
// The parser is strict: unknown fields produce errors, version
// constraints are enforced, and type references are resolved against
// the type registry at parse time.
//
// Typical usage:
//
//	specs, err := spec.LoadDir("specs/cli/")
//	if err != nil { return err }
//	for _, s := range specs {
//	    // s is a fully-parsed, type-resolved Spec
//	}
//
// This package does not depend on Cedar; projection logic lives in
// the projection package.
package spec
