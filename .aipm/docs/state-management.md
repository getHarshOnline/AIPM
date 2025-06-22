# AIPM State Management Architecture

## Overview

AIPM implements a comprehensive state management system (`opinions-state.sh`) that pre-computes ALL possible values at initialization time. This ensures ZERO runtime computation - everything is calculated once and stored in `workspace.json` for instant access.

## Core Philosophy

```
1. Pre-compute Everything: No runtime calculations
2. Single Source of Truth: workspace.json contains ALL state
3. Instant Access: All values available via simple lookups
4. Bidirectional Updates: Changes flow back to maintain consistency
```

## Architecture

### State Flow

```
opinions.yaml (configuration source)
    ↓
opinions-loader.sh (pure YAML→shell transformation)
    ↓
opinions-state.sh (pre-computation engine)
    ↓
workspace.json (complete pre-computed state)
    ↓
Wrapper Scripts (instant lookups via get_value())
    ↓
State Updates (bidirectional via update_state())
```

## State Structure

The `workspace.json` file contains five major sections:

### 1. Metadata
```json
{
  "metadata": {
    "version": "1.0",
    "generated": "2024-06-22T10:30:00Z",
    "opinionsHash": "sha256:abc123...",
    "workspace": {
      "name": "AIPM",
      "type": "framework"
    }
  }
}
```

### 2. Raw Exports
All AIPM_* environment variables from opinions-loader.sh:
```json
{
  "raw_exports": {
    "AIPM_WORKSPACE_NAME": "AIPM",
    "AIPM_BRANCHING_PREFIX": "AIPM_",
    "AIPM_MEMORY_ENTITYPREFIX": "AIPM_",
    "AIPM_WORKFLOWS_BRANCHCREATION_STARTBEHAVIOR": "check-first"
    // ... hundreds more
  }
}
```

### 3. Computed Values
Pre-calculated patterns, rules, and configurations:
```json
{
  "computed": {
    "mainBranch": "AIPM_MAIN",
    "branchPatterns": {
      "feature": {
        "original": "feature/{description}",
        "full": "AIPM_feature/{description}",
        "glob": "AIPM_feature/*",
        "regex": "^AIPM_feature/(.+)$"
      }
    },
    "protectedBranches": {
      "userBranches": ["main", "develop"],
      "aipmBranches": [{"suffix": "MAIN", "full": "AIPM_MAIN"}],
      "all": ["main", "develop", "AIPM_MAIN"]
    },
    "lifecycleMatrix": {
      "feature": {
        "deleteAfterMerge": true,
        "daysToKeep": 0,
        "deleteTiming": "immediate",
        "description": "Delete immediately after merge"
      }
    },
    "workflows": {
      "branchCreation": {
        "startBehavior": "check-first",
        "protectionResponse": "prompt",
        "typeSelection": "prompt"
      }
    }
  }
}
```

### 4. Runtime State
Current git and session information:
```json
{
  "runtime": {
    "currentBranch": "AIPM_feature/state-management",
    "branches": {
      "all": ["AIPM_MAIN", "AIPM_feature/state-management"],
      "byType": {
        "feature": ["AIPM_feature/state-management"]
      },
      "stale": [],
      "readyForCleanup": []
    },
    "git": {
      "hasRemote": true,
      "isClean": false,
      "uncommittedCount": 3,
      "ahead": 2,
      "behind": 0
    },
    "session": {
      "active": true,
      "id": "aipm_20240622_143022",
      "context": "framework"
    }
  }
}
```

### 5. Pre-made Decisions
All possible decisions pre-computed:
```json
{
  "decisions": {
    "canCreateBranch": true,
    "shouldFetchOnStart": true,
    "mergeTarget": "AIPM_MAIN",
    "cleanupBranches": ["AIPM_test/old-test"],
    "workflowPrompts": {
      "protectedBranch": "You're trying to save to main branch..."
    }
  }
}
```

## Implementation Details

### State Initialization

From `opinions-state.sh` (lines 2417-2545):

```bash
initialize_state() {
    # 1. Load opinions via opinions-loader.sh
    load_and_export_opinions
    
    # 2. Collect ALL raw exports
    local raw_exports='{}'
    # Captures all AIPM_* environment variables
    
    # 3. Compute ALL derived values
    local computed=$(jq -n \
        --argjson bp "$(compute_all_branch_patterns)" \
        --argjson pb "$(compute_protected_branches_list)" \
        --argjson lm "$(compute_complete_lifecycle_matrix)" \
        --argjson wf "$(compute_complete_workflow_rules)" \
        # ... many more computations
    )
    
    # 4. Get runtime state
    local runtime=$(get_complete_runtime_state)
    
    # 5. Make ALL decisions
    local decisions=$(make_complete_decisions "$runtime" "$computed")
    
    # 6. Write complete state
    write_state_file "$state"
}
```

### Pre-computation Functions

#### Branch Patterns (lines 619-679)
```bash
compute_all_branch_patterns() {
    # For each branch type (feature, fix, etc.):
    # - Original pattern: "feature/{description}"
    # - Full pattern: "AIPM_feature/{description}"
    # - Glob pattern: "AIPM_feature/*"
    # - Regex pattern: "^AIPM_feature/(.+)$"
}
```

#### Lifecycle Matrix (lines 795-884)
```bash
compute_complete_lifecycle_matrix() {
    # For each branch type:
    # - deletion timing (immediate/scheduled/never)
    # - trigger (merge date vs last commit)
    # - human-readable descriptions
}
```

#### Workflow Rules (lines 906-1181)
```bash
compute_complete_workflow_rules() {
    # All workflow decisions with prompt text:
    # - Branch creation behaviors
    # - Merge strategies
    # - Sync triggers
    # - Cleanup rules
}
```

### State Access

#### Get Value (lines 2560-2577)
```bash
get_value() {
    local path="$1"
    
    # Lazy load state if needed
    ensure_state
    
    # Direct JSON lookup - instant!
    echo "$STATE_CACHE" | jq -r ".$path // empty"
}
```

Usage examples:
```bash
# Get raw configuration
local prefix=$(get_value "raw_exports.AIPM_BRANCHING_PREFIX")

# Get computed pattern
local feature_glob=$(get_value "computed.branchPatterns.feature.glob")

# Get runtime info
local current_branch=$(get_value "runtime.currentBranch")

# Get pre-made decision
local can_create=$(get_value "decisions.canCreateBranch")
```

### Bidirectional Updates

#### Single Update (lines 2932-3011)
```bash
update_state() {
    local path="$1"
    local value="$2"
    
    acquire_state_lock
    update_state_internal "$path" "$value"
    release_state_lock
}
```

#### Batch Updates (lines 3102-3161)
```bash
update_state_batch() {
    local updates="$1"  # JSON array
    
    acquire_state_lock
    # Apply all updates atomically
    release_state_lock
}
```

#### Specialized Updates
```bash
# Increment numeric value
increment_state "runtime.git.uncommittedCount"

# Append to array
append_state "runtime.branches.stale" "AIPM_test/old"

# Remove from state
remove_state "runtime.session.tempData"
```

### Wrapper Script Integration

Example from a hypothetical improved `save.sh`:

```bash
source opinions-state.sh
ensure_state

# Check if on protected branch
local current=$(get_value "runtime.currentBranch")
local protected=$(get_value "computed.protectedBranches.all")

if echo "$protected" | jq -e --arg b "$current" '.[] | select(. == $b)' >/dev/null; then
    # Get workflow rule
    local response=$(get_value "computed.workflows.branchCreation.protectionResponse")
    
    if [[ "$response" == "prompt" ]]; then
        # Get pre-computed prompt
        local prompt=$(get_value "decisions.workflowPrompts.protectedBranch")
        echo "$prompt"
    fi
fi

# After save operation, report back
report_git_operation "save" "success" "{\"branch\": \"$current\"}"
```

## Performance Benefits

### Traditional Approach (Slow)
```bash
# Parse YAML on every call
local prefix=$(yq '.branching.prefix' opinions.yaml)
# Check git status repeatedly
if [[ $(git status --porcelain | wc -l) -gt 0 ]]; then
# Compute patterns at runtime
local pattern="$prefix$type/*"
```

### AIPM Approach (Instant)
```bash
# Everything pre-computed
local prefix=$(get_value "computed.branchPatterns.feature.glob")
local is_clean=$(get_value "runtime.git.isClean")
# No computation needed!
```

## Lock-Based Concurrency

State updates use file locking to prevent corruption:

```bash
# Lock acquisition (lines 306-343)
acquire_state_lock() {
    local timeout=${AIPM_STATE_LOCK_TIMEOUT:-30}
    
    # Try flock first (kernel-level)
    if command -v flock &>/dev/null; then
        flock -w "$timeout" "$STATE_LOCK_FD"
    else
        # Fallback to directory-based lock
        while ! mkdir "$STATE_LOCK.dir" && [[ $elapsed -lt $timeout ]]; do
            sleep 0.5
        done
    fi
}
```

## State Refresh Strategy

### Full Refresh
```bash
refresh_state "all"  # Recompute everything
```

### Partial Refresh
```bash
refresh_state "branches"  # Only git branch info
refresh_state "runtime"   # Only runtime state
```

### Automatic Refresh
- On opinions.yaml change (hash mismatch)
- Every 5 minutes (configurable)
- On demand via wrapper scripts

## Integration Points

### With Workflows
See [workflow.md](workflow.md) - all workflow rules are pre-computed and stored in state.

### With Memory Management  
See [memory-management.md](memory-management.md) - memory operations update runtime state.

### With Version Control (CRITICAL: Bidirectional Integration)

**EXHAUSTIVE INVESTIGATION FINDING**: version-control.sh currently has NO awareness of state management, causing constant desync issues.

For the complete architectural solution including:
- Atomic operation patterns with rollback
- Lock management for concurrent operations
- State update matrix for all git operations
- Implementation requirements and patterns

**See: [Version Control Architecture](version-control.md)** - The single source of truth for git operations and state integration.

## Best Practices

### 1. Always Use State Functions
```bash
# Bad: Direct file access
local value=$(jq -r '.computed.value' workspace.json)

# Good: State function
local value=$(get_value "computed.value")
```

### 2. Report All Changes
```bash
# Bad: Change without reporting
git checkout feature/new

# Good: Change and report
checkout_branch "feature/new"  # Wrapper that updates state
```

### 3. Batch Related Updates
```bash
# Good: Atomic updates
update_state_batch '[
    {"path": "runtime.git.branch", "value": "main"},
    {"path": "runtime.git.uncommittedCount", "value": "0"}
]'
```

## Future Enhancements

1. **State History**: Track changes over time
2. **State Diff**: Compare states between refreshes
3. **State Subscriptions**: Watch for specific changes
4. **State Metrics**: Performance analytics
5. **Distributed State**: Share across team members

## Summary

AIPM's state management provides:
- **Zero Runtime Computation**: Everything pre-calculated
- **Instant Access**: Simple JSON lookups
- **Complete Coverage**: ALL configuration and runtime data
- **Bidirectional Flow**: Maintains consistency automatically

The state system is the brain of AIPM - it knows everything about the workspace and provides instant answers to any query.