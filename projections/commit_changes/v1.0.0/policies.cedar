// Cedar policy templates for commit_changes@1.0.0
// LKI format version: 0.1
//
// Three-tier structure matches fetch_url.cedar pattern:
//   1. Safety floor — always applied, never permissive
//   2. Baseline — sensible defaults for most agents
//   3. Tenant template — site-specific customization

// ===========================================================================
// TIER 1: SAFETY FLOOR
// Always-applied forbids derived from anti_patterns in the LKI spec.
// ===========================================================================

// Anti-pattern: commits to repositories outside policy-permitted scope
forbid (
  principal,
  action == Lki::Action::"StateMutation::Write::Git",
  resource
)
when {
  !resource.working_dir_rooted
};

// Anti-pattern: commits during in-progress rebase/merge/cherry-pick
// These usually indicate the agent is in a state it didn't intend to be in.
// Recovery requires human attention.
forbid (
  principal,
  action == Lki::Action::"StateMutation::Write::Git",
  resource
)
when {
  resource.has_in_progress_operation
};

// Anti-pattern: commits in detached HEAD state
// Commits to detached HEAD are typically lost when HEAD moves; this is
// almost always not what the agent intended.
forbid (
  principal,
  action == Lki::Action::"StateMutation::Write::Git",
  resource
)
when {
  resource.is_detached_head
};

// Anti-pattern: spawning system-critical tools by default
forbid (
  principal,
  action == Lki::Action::"Process::Spawn",
  resource
)
when {
  resource.is_system_critical
};


// ===========================================================================
// TIER 2: BASELINE
// Permissive defaults for the common, expected cases.
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

// Baseline: agents may read git internals when committing
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
  resource.working_dir_rooted &&
  !resource.is_detached_head &&
  !resource.has_in_progress_operation
};


// ===========================================================================
// TIER 3: TENANT TEMPLATE
// Site-specific customizations. Comments document common shapes.
// ===========================================================================

// Example: require commit signing for production repositories
// forbid (
//   principal,
//   action == Lki::Action::"StateMutation::Write::Git",
//   resource
// )
// when {
//   resource.canonical_path like "*/production-*" &&
//   context.intent_name == "commit_changes"
//   // GPG-sign requirement enforced via separate context attribute (not in v0.1 schema)
// };

// Example: forbid commits to protected branches
// forbid (
//   principal,
//   action == Lki::Action::"StateMutation::Write::Git",
//   resource
// )
// when {
//   ["main", "master", "production", "release"].contains(resource.current_branch)
// };

// Example: require message subject length (encourages conventional commits)
// forbid (
//   principal,
//   action == Lki::Action::"StateMutation::Write::Git",
//   resource
// )
// when {
//   context.message_subject_length > 72 ||
//   context.message_subject_length < 10
// };

// Example: permit broader access for "ci" labeled principals
// permit (
//   principal,
//   action == Lki::Action::"StateMutation::Write::Git",
//   resource
// )
// when {
//   principal.labels.contains("ci") &&
//   context.intent_name == "commit_changes"
// };
