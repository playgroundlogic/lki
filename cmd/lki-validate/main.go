// Package main is the entrypoint for lki-validate.
//
// lki-validate checks that an LKI spec file conforms to the format
// specification. It validates structural well-formedness, type
// references, capability declaration shape, interpolation grammar,
// and cross-section consistency.
//
// This file is a skeleton. See README.md for the tool contract.
package main

import (
	"fmt"
	"os"
)

func main() {
	fmt.Fprintln(os.Stderr, "lki-validate: not yet implemented")
	fmt.Fprintln(os.Stderr, "See cmd/lki-validate/README.md")
	os.Exit(1)
}
