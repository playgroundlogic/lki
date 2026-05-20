# LKI

LLM Knowledge Intent — a format for declaring agent-invokable operations under Cedar policy enforcement.

**Status:** v0.2 substrate complete. Positioning prose forthcoming.

## What this is

LKI is the policy and verification layer beneath agent tool calls. It provides a structured intent format that LLMs can consume directly, projection rules to Cedar for capability enforcement, an audit log substrate for after-the-fact verification, and an optional Tool-SI training path for high-volume specialized intents.

## Where to start

- **Format specification:** [format/v0.2/LKI_FORMAT.md](format/v0.2/LKI_FORMAT.md)
- **Migration from v0.1:** [migrations/v0.1-to-v0.2.md](migrations/v0.1-to-v0.2.md)
- **Open findings (toward v0.3):** [findings/v0.2.md](findings/v0.2.md)
- **Design goalpost (Flight Plan):** [design/flight-plan-goalpost.md](design/flight-plan-goalpost.md)

## Reference specifications

v0.2 ships seven specs covering common CLI operations:

| Intent | Version | Spec |
|---|---|---|
| fetch_url | 2.0.0 | [specs/cli/fetch_url/v2.0.0.yaml](specs/cli/fetch_url/v2.0.0.yaml) |
| read_file | 2.0.0 | [specs/cli/read_file/v2.0.0.yaml](specs/cli/read_file/v2.0.0.yaml) |
| grep_files | 2.0.0 | [specs/cli/grep_files/v2.0.0.yaml](specs/cli/grep_files/v2.0.0.yaml) |
| list_directory | 2.0.0 | [specs/cli/list_directory/v2.0.0.yaml](specs/cli/list_directory/v2.0.0.yaml) |
| remove_files | 2.0.0 | [specs/cli/remove_files/v2.0.0.yaml](specs/cli/remove_files/v2.0.0.yaml) |
| commit_changes | 2.0.0 | [specs/cli/commit_changes/v2.0.0.yaml](specs/cli/commit_changes/v2.0.0.yaml) |
| write_file | 2.0.0 | [specs/cli/write_file/v2.0.0.yaml](specs/cli/write_file/v2.0.0.yaml) |

Each intent has a frozen v1.0.0 form (v0.1 format) alongside its v2.0.0 form (v0.2 format) for historical reference and pinning.

## Cedar projections

Two intents have complete cedar projections demonstrating the three-tier policy structure (safety floor, baseline, tenant template):

- [projections/fetch_url/v2.0.0/](projections/fetch_url/v2.0.0/)
- [projections/commit_changes/v2.0.0/](projections/commit_changes/v2.0.0/)

## License

Apache 2.0. See [LICENSE](LICENSE).
