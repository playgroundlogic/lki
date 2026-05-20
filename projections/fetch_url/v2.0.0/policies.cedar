// Cedar policy templates for fetch_url@2.0.0
// LKI format version: 0.2
// Three-tier structure per Chapter 9.8.
//
// CHANGES FROM v1.0.0 PROJECTION:
//   - Policies now reference context.purpose for finer-grained rules
//   - Resource bound policies (over context.timeout_bound) added
//   - intent_name comparisons remain the same (intent is context, not entity)

// ===========================================================================
// TIER 1: SAFETY FLOOR
// Always applied, never permissive. Derived from anti_patterns whose
// rejection field references structural/observed attributes.
// ===========================================================================

// Anti-pattern: writes to system paths
// Source: fetch_url@2.0.0 anti_pattern about /etc/cron.d/job
forbid (
  principal,
  action == Lki::Action::"Filesystem::Write",
  resource
)
when {
  resource.is_system_path
};

// Anti-pattern: outbound network to metadata endpoints
// Source: generalization from "TLS bypass to internal/secrets" anti-pattern
// plus general principle from v1.0.0 projection
forbid (
  principal,
  action == Lki::Action::"Network::Outbound",
  resource
)
when {
  resource.is_metadata
};

// Anti-pattern: writes outside principal's working directory
// Source: implicit from all anti-patterns about path traversal
forbid (
  principal,
  action == Lki::Action::"Filesystem::Write",
  resource
)
when {
  !resource.is_within_working_dir &&
  !resource.is_system_path  // already denied by previous policy; this catches the rest
};

// Note: anti-pattern about TLS bypass (curl --insecure) and URL composition
// from agent-controlled strings are documented but rejected at parameter
// validation / type level, not via Cedar policy. They appear in v0.2 spec's
// anti_patterns but don't generate safety floor policies.

// ===========================================================================
// TIER 2: BASELINE
// Reasonable defaults. Operators relax or tighten via tenant template.
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
  context.purpose == "user_facing" &&
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
  context.purpose == "user_facing" &&
  resource.is_within_working_dir &&
  !resource.is_system_path
};

// Baseline: resource bound on timeout
// Reasonable agents shouldn't need > 5min timeouts; force escalation for more
forbid (
  principal,
  action == Lki::Action::"Network::Outbound",
  resource
)
when {
  context.intent_name == "fetch_url" &&
  context.timeout_bound > 300 &&
  !principal.labels.contains("extended_timeout_permitted")
};

// ===========================================================================
// TIER 3: TENANT TEMPLATE
// Site-specific customization. Operators add rules below.
// ===========================================================================

// EXAMPLE: allow internal hosts for principals with "internal" label
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

// EXAMPLE: forbid downloads of executable extensions
// forbid (
//   principal,
//   action == Lki::Action::"Filesystem::Write",
//   resource
// )
// when {
//   context.intent_name == "fetch_url" &&
//   [".exe", ".dmg", ".sh", ".ps1", ".bat"].contains(resource.extension)
// };

// EXAMPLE: rate limit (Cedar can't express rate limits natively; this is
// a TODO marker for runtime extension that consults stateful budget pools)
// — see F-034 in FINDINGS_v0.2.md for v0.3 breach_handling design
