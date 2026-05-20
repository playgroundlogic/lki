// Cedar policy templates for commit_changes@2.0.0
// LKI format version: 0.2
//
// CHANGES FROM v1.0.0 PROJECTION:
//   - Safety floor uses GitRepository observed attributes (working_dir_rooted,
//     is_detached_head, has_in_progress_operation) directly
//   - Three-axis policy examples in baseline and tenant template
//   - context.purpose differentiates user-facing state mutation from
//     implementation-detail filesystem operations
//   - Process::Spawn policies reference Tool entities by identity (Lki::Tool::"git")

// ===========================================================================
// TIER 1: SAFETY FLOOR
// ===========================================================================

// Safety: commits only to repositories within principal's working_dir
forbid (
  principal,
  action == Lki::Action::"StateMutation::Write::Git",
  resource
)
when {
  !resource.working_dir_rooted
};

// Safety: no commits during in-progress git operations
forbid (
  principal,
  action == Lki::Action::"StateMutation::Write::Git",
  resource
)
when {
  resource.has_in_progress_operation
};

// Safety: no commits in detached HEAD state
forbid (
  principal,
  action == Lki::Action::"StateMutation::Write::Git",
  resource
)
when {
  resource.is_detached_head
};

// Safety: no spawning of system-critical tools by default
forbid (
  principal,
  action == Lki::Action::"Process::Spawn",
  resource
)
when {
  resource.is_system_critical
};

// Safety: implementation_detail filesystem operations restricted to working_dir
// (catches edge case where someone manages to inject system-path into the
// .git path expansion)
forbid (
  principal,
  action == Lki::Action::"Filesystem::Read",
  resource
)
when {
  context.purpose == "implementation_detail" &&
  resource.is_system_path
};

forbid (
  principal,
  action == Lki::Action::"Filesystem::Write",
  resource
)
when {
  context.purpose == "implementation_detail" &&
  resource.is_system_path
};

// ===========================================================================
// TIER 2: BASELINE
// ===========================================================================

// Baseline: agents may spawn git as part of commit_changes
permit (
  principal,
  action == Lki::Action::"Process::Spawn",
  resource
)
when {
  resource == Lki::Tool::"git" &&
  context.intent_name == "commit_changes" &&
  context.uid_required == "current"
};

// Baseline: agents may read git internals when committing (implementation_detail)
permit (
  principal,
  action == Lki::Action::"Filesystem::Read",
  resource
)
when {
  context.intent_name == "commit_changes" &&
  context.purpose == "implementation_detail" &&
  resource.is_within_working_dir &&
  !resource.is_system_path
};

// Baseline: agents may write to .git internals when committing
permit (
  principal,
  action == Lki::Action::"Filesystem::Write",
  resource
)
when {
  context.intent_name == "commit_changes" &&
  context.purpose == "implementation_detail" &&
  resource.is_within_working_dir &&
  !resource.is_system_path
};

// Baseline: agents may commit to repositories in their working dir
permit (
  principal,
  action == Lki::Action::"StateMutation::Write::Git",
  resource
)
when {
  context.intent_name == "commit_changes" &&
  context.operation == "commit" &&
  context.purpose == "user_facing" &&
  resource.working_dir_rooted &&
  !resource.is_detached_head &&
  !resource.has_in_progress_operation
};

// ===========================================================================
// TIER 3: TENANT TEMPLATE
// ===========================================================================

// EXAMPLE: protected branches require explicit approval label
// forbid (
//   principal,
//   action == Lki::Action::"StateMutation::Write::Git",
//   resource
// )
// when {
//   ["main", "master", "production", "release"].contains(resource.current_branch) &&
//   !principal.labels.contains("approved_for_protected_branches")
// };

// EXAMPLE: production repositories require fsynced durability (three-axis rule!)
// This is the kind of rule the three-axis decomposition enables;
// v0.1's boolean atomic flag couldn't express this.
// forbid (
//   principal,
//   action == Lki::Action::"StateMutation::Write::Git",
//   resource
// )
// when {
//   resource.canonical_path like "*/production-*" &&
//   context.durability != "fsynced_with_dir"
// };

// EXAMPLE: audit-sensitive commits must be at least locally reversible
// forbid (
//   principal,
//   action == Lki::Action::"StateMutation::Write::Git",
//   resource
// )
// when {
//   principal.labels.contains("audit_sensitive_workload") &&
//   context.reversibility == "irreversible"
// };

// EXAMPLE: require conventional commit message length
// forbid (
//   principal,
//   action == Lki::Action::"StateMutation::Write::Git",
//   resource
// )
// when {
//   context.message_subject_length > 72 ||
//   context.message_subject_length < 10
// };

// EXAMPLE: permit broader access for CI principals
// permit (
//   principal,
//   action == Lki::Action::"StateMutation::Write::Git",
//   resource
// )
// when {
//   principal.labels.contains("ci") &&
//   context.intent_name == "commit_changes"
// };
