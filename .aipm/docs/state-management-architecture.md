# State Management Architecture

## Overview

The AIPM state management system follows a **pre-computation philosophy** - all decisions, patterns, and rules are computed once and stored for instant access. This eliminates runtime computation and ensures consistency across all operations.

## Core Components

### 1. opinions-loader.sh
- **Role**: Pure YAML to shell transformation
- **Responsibility**: Load and validate opinions.yaml, export as AIPM_* variables
- **No Logic**: Just transformation and validation

### 2. opinions-state.sh  
- **Role**: Complete state management with pre-computation
- **Responsibility**: Build and maintain comprehensive runtime state
- **Key Feature**: Bidirectional updates from wrapper scripts

### 3. workspace.json
- **Role**: The single source of truth
- **Contents**: Raw exports + computed values + runtime state + decisions
- **Access**: Sub-millisecond JSON lookups

## State Structure

```json
{
  "metadata": {
    "version": "1.0",
    "opinionsHash": "sha256:...",
    "lastRefresh": "ISO-8601 timestamp"
  },
  "raw_exports": {
    // All AIPM_* environment variables
  },
  "computed": {
    // Pre-computed patterns, rules, matrices
    "branchPatterns": {},
    "lifecycleMatrix": {},
    "workflows": {},
    "validation": {}
  },
  "runtime": {
    // Current git state
    "currentBranch": "...",
    "branches": {},
    "workingTreeClean": true
  },
  "decisions": {
    // Pre-made decisions
    "canCreateBranch": true,
    "mergeTarget": "..."
  }
}
```

## Bidirectional Communication

### Problem
When wrapper scripts perform git operations, the state becomes stale. We need bidirectional updates.

### Solution
Every wrapper function that modifies git state reports back:

```bash
# In wrapper script
create_branch "feature/new"
report_git_operation "branch-created" "feature/new" "main"

# In opinions-state.sh
report_git_operation() {
    case "$1" in
        "branch-created")
            update_state "runtime.currentBranch" "$2"
            update_state "runtime.branches.$2.exists" "true"
            refresh_state "decisions"  # Recompute decisions
            ;;
    esac
}
```

## API Reference

### Reading State
```bash
# Get single value
current_branch=$(get_value "runtime.currentBranch")

# Check decisions
if [[ "$(get_value 'decisions.canCreateBranch')" == "true" ]]; then
    # Create branch
fi

# Get computed rules
pattern=$(get_value "computed.branchPatterns.feature.glob")
```

### Updating State
```bash
# Single update
update_state "runtime.currentBranch" '"feature/new"'

# Batch update
declare -a updates=(
    'runtime.currentBranch:"feature/new"'
    'runtime.workingTreeClean:false'
)
update_state_batch updates

# Increment counter
increment_state "runtime.uncommittedCount" 1

# Append to array
append_state "runtime.uncommittedChanges" '{"file":"new.txt","type":"added"}'

# Remove value
remove_state "runtime.oldBranch"
```

### Reporting Git Operations
```bash
# Standard operations
report_git_operation "branch-created" "branch-name" "parent-branch"
report_git_operation "branch-switched" "branch-name"
report_git_operation "branch-deleted" "branch-name"
report_git_operation "files-modified" "3"
report_git_operation "commit-created" "abc123"
report_git_operation "branch-merged" "source" "target"
report_git_operation "remote-updated" "2" "0"  # ahead/behind
```

## Performance Characteristics

- **Initial build**: ~2-3 seconds (one-time cost)
- **State refresh**: ~1 second (git queries)
- **Value lookup**: <1ms (JSON parsing)
- **State update**: ~10ms (JSON write + optional refresh)

## Best Practices

### 1. Always Report Back
```bash
# BAD - State becomes stale
git checkout -b feature/new

# GOOD - State stays synchronized
git checkout -b feature/new
report_git_operation "branch-created" "feature/new" "$current"
```

### 2. Batch Updates
```bash
# BAD - Multiple write operations
update_state "runtime.a" "1"
update_state "runtime.b" "2"
update_state "runtime.c" "3"

# GOOD - Single atomic update
declare -a updates=('runtime.a:1' 'runtime.b:2' 'runtime.c:3')
update_state_batch updates
```

### 3. Use Pre-computed Decisions
```bash
# BAD - Computing at runtime
if [[ "$branch" =~ ^AIPM_MAIN$ ]] || [[ "$branch" == "main" ]]; then
    echo "Protected branch"
fi

# GOOD - Using pre-computed decision
if [[ "$(get_value "runtime.branches.$branch.isProtected")" == "true" ]]; then
    echo "Protected branch"
fi
```

## Integration Example

```bash
#!/opt/homebrew/bin/bash
# git-feature.sh - Create feature branch with state management

source opinions-state.sh

# Check if we can create branches
if [[ "$(get_value 'decisions.canCreateBranch')" != "true" ]]; then
    error "Cannot create branch: $(get_value 'decisions.cannotCreateReasons[0]')"
    exit 1
fi

# Get source branch from pre-computed rules
source=$(get_value "computed.workflows.branchFlow.sources.byType.feature/*")
[[ -z "$source" ]] && source=$(get_value "runtime.currentBranch")

# Create the branch
branch_name="$(get_value 'computed.mainBranch' | sed 's/MAIN$//')feature/$1"
git checkout -b "$branch_name" "$source"

# Report back to state
report_git_operation "branch-created" "$branch_name" "$source"

# State is now synchronized!
success "Created $branch_name from $source"
```

## Architecture Principles

1. **Pre-compute Everything**: No runtime rule evaluation
2. **Single Source of Truth**: workspace.json has all answers
3. **Bidirectional Updates**: Wrappers must report back
4. **Atomic Operations**: Use locking for concurrent safety
5. **Fast Lookups**: JSON parsing is instant
6. **Graceful Degradation**: Work without state if needed

## Common Pitfalls

1. **Forgetting to Report**: State becomes stale
2. **Direct Git Commands**: Bypasses state tracking
3. **Runtime Computation**: Defeats the pre-computation purpose
4. **Not Using Decisions**: Reimplementing logic that's pre-computed
5. **Partial Updates**: Not refreshing decisions after runtime changes

## Future Enhancements

1. **State History**: Track changes over time
2. **Incremental Updates**: Update only changed sections
3. **State Subscriptions**: Notify on specific changes
4. **Distributed Sync**: Share state across machines
5. **Performance Metrics**: Track operation timings