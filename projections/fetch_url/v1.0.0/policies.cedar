// Cedar policy templates for fetch_url@1.0.0
// LKI format version: 0.1
//
// Three tiers of policy are derived from a single LKI spec:
//   1. Safety floor (always applied, never permissive)
//   2. Baseline (sensible defaults for most agents)
//   3. Tenant template (placeholder for site-specific customization)
//
// Cedar evaluates all policies; a single forbid is sufficient to deny.
// The safety floor is the always-on layer; baseline is the typical
// reasonable defaults; the tenant template is the layer site operators
// customize.

// ===========================================================================
// TIER 1: SAFETY FLOOR
// These policies are always applied. They are projected from anti_patterns
// in the LKI spec. Operators cannot disable them; they can only add further
// restrictions on top.
// ===========================================================================

// Anti-pattern: fetch_url to instance metadata endpoints
// Spec rationale: "Pipes arbitrary remote content" anti-pattern generalizes
// to any access to credential-serving endpoints (AWS IMDS, GCP metadata,
// Azure IMDS).
forbid (
  principal,
  action == Lki::Action::"Network::Outbound",
  resource
)
when {
  resource.is_metadata
};

// Anti-pattern: writes to system paths
// Spec rationale: "Writes downloaded content to a privileged execution path"
// anti-pattern in fetch_url.yaml, generalized to any system path.
forbid (
  principal,
  action == Lki::Action::"Filesystem::Write",
  resource
)
when {
  resource.is_system_path
};

// Anti-pattern: TLS bypass intents are a different intent
// (fetch_url_insecure), so fetch_url's policy assumes TLS throughout.
// No policy needed here — the intent's signature doesn't permit plaintext
// for non-loopback hosts. Spec-level enforcement, not Cedar-level.


// ===========================================================================
// TIER 2: BASELINE
// Reasonable defaults that most deployments will want. Operators override
// as needed; these are not forbids, they are permits with explicit conditions.
// ===========================================================================

// Baseline: agents may fetch from public HTTPS endpoints
permit (
  principal,
  action == Lki::Action::"Network::Outbound",
  resource
)
when {
  context.protocol == "https" &&
  context.intent_name == "fetch_url" &&
  !resource.is_loopback &&
  !resource.is_private
};

// Baseline: agents may write fetch_url output to their working directory
permit (
  principal,
  action == Lki::Action::"Filesystem::Write",
  resource
)
when {
  context.intent_name == "fetch_url" &&
  resource.is_within_working_dir &&
  !resource.is_system_path
};


// ===========================================================================
// TIER 3: TENANT TEMPLATE
// Placeholder for site-specific customization. Operators replace these
// with their actual policy. Comments document the shape of typical
// customizations.
// ===========================================================================

// Example: allow internal hosts for principals with "internal" label
// permit (
//   principal,
//   action == Lki::Action::"Network::Outbound",
//   resource
// )
// when {
//   principal.labels.contains("internal") &&
//   context.intent_name == "fetch_url" &&
//   resource.fqdn like "*.internal.example.com"
// };

// Example: forbid downloads of specific risky extensions
// forbid (
//   principal,
//   action == Lki::Action::"Filesystem::Write",
//   resource
// )
// when {
//   context.intent_name == "fetch_url" &&
//   [".exe", ".dmg", ".sh", ".ps1"].contains(resource.extension)
// };

// Example: rate-limit-shaped policy (Cedar doesn't do rate limits natively,
// but the PDP can use context.session_id for stateful checks via callbacks)
// — left as a TODO for runtime extension; Cedar policy alone can't express.
