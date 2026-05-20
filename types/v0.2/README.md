# v0.2 Type Catalog

This directory will hold individual shared type definitions referenced
by 2+ specs. Per Chapter 5 of the v0.2 format spec, types used by only
one spec are declared inline in that spec's `types:` section.

**Current status:** types are defined inline in the
[LKI_FORMAT_v0.2.md](../../format/v0.2/LKI_FORMAT.md) Chapter 5 catalog
plus per-spec `types:` sections. Individual type files are extracted
here when the type catalog graduates to its own files (deferred until
extraction is justified by usage).

Types currently described in Chapter 5:

- Primitives: string, int, float, bool, bytes
- Structured: URL, FilePath, Duration, Regex, Bytes
- Compound: list<T>, map<K,V>, enum<>, union<>

Types currently defined per-spec:

- DirectoryEntry, DirectoryListing (in list_directory@2.0.0.yaml)
- Match (in grep_files@2.0.0.yaml)
- CommitResult (in commit_changes@2.0.0.yaml)
- DeletionResult (in remove_files@2.0.0.yaml)
- WriteResult (in write_file@2.0.0.yaml)

Several are candidates for extraction (DirectoryEntry could be shared
between list_directory and a future find_files intent).
