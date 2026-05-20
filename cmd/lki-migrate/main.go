// Package main is the entrypoint for lki-migrate.
//
// lki-migrate applies the mechanical migrations between LKI format
// versions documented in the migration guides. Substantive migrations
// (requiring human judgment per the migration guide) are flagged for
// human review rather than auto-applied.
//
// This file is a skeleton. See README.md for the tool contract.
package main

import (
	"fmt"
	"os"
)

func main() {
	fmt.Fprintln(os.Stderr, "lki-migrate: not yet implemented")
	fmt.Fprintln(os.Stderr, "See cmd/lki-migrate/README.md")
	os.Exit(1)
}
