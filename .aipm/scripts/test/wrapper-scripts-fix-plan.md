# Wrapper Scripts Fix Plan

## Overview

This document outlines the fixes needed for wrapper scripts (start.sh, stop.sh, save.sh, revert.sh, init.sh) to properly integrate with the state management system and follow architectural principles.

## 🏗️ FOUNDATION: Lock Management Architecture

### Critical Requirement
Per [state-management-fix-plan.md](state-management-fix-plan.md), ALL wrapper scripts MUST use lock management for state operations.

### Lock Patterns for Wrapper Scripts
```bash
# EVERY script that touches state MUST follow this pattern:
source "$SCRIPT_DIR/modules/opinions-state.sh"

# For read operations
acquire_state_lock || die "Cannot acquire lock"
local value=$(get_value "computed.someValue")
release_state_lock

# For write operations (atomic)
begin_atomic_operation "script:operation"
if perform_operations; then
    update_state "path" "value"
    commit_atomic_operation
else
    rollback_atomic_operation
fi
```

### Lock Requirements by Script
- **init.sh**: Exclusive lock for entire initialization
- **start.sh**: Lock for session creation and memory backup
- **save.sh**: Lock for commit and state updates
- **stop.sh**: Lock for session cleanup and merge
- **revert.sh**: Lock for state restoration

## 🚨 CRITICAL DIRECTIVES FROM .agentrules

### MANDATORY Reading
- **Read `.aipm/docs/workflow.md` FIRST** - it is the single source of truth for wrapper script patterns
- **NO DIRECT OUTPUT**: Never use echo/printf - ONLY shell-formatting.sh functions
- **NO DIRECT GIT**: Never use git commands - ONLY version-control.sh functions
- **NO DIRECT MEMORY OPS**: Never manipulate memory files - ONLY migrate-memories.sh functions
- **TEST INCREMENTALLY**: Implement section by section, test before proceeding

### File Reversion Bug Protocol
- **COMMIT FREQUENTLY**: After implementing each script, commit immediately
- **VERIFY CHANGES**: Always grep/check that edits persisted
- **RE-CHECK BEFORE COMMITTING**: Run `git diff` to ensure all changes present

### Memory File Protection
- **NEVER edit .aipm/memory/local_memory.json directly**
- **NEVER modify .aipm/memory.json** (symlink to global memory)
- **ONLY scripts can touch memory files** (handle atomicity and safety)

## State Update Matrix Compliance

Per [version-control.md](../docs/version-control.md), each script MUST update specific state values atomically:

| Script | Required State Updates | Lock Type | Rollback |
|--------|----------------------|-----------|----------|
| init.sh | workspace.initialized<br>runtime.branches.all<br>metadata.initTime | Exclusive | Delete branches |
| start.sh | runtime.session.active=true<br>runtime.session.id<br>runtime.session.context<br>runtime.session.startTime | Exclusive | Restore memory |
| save.sh | runtime.git.uncommittedCount=0<br>runtime.git.lastCommit<br>runtime.git.lastCommitTime<br>runtime.git.lastCommitMessage | Shared | Reset commit |
| stop.sh | runtime.session.active=false<br>runtime.session.endTime<br>runtime.lastSync | Exclusive | Restore session |
| revert.sh | runtime.lastRevert<br>runtime.git.uncommittedCount | Exclusive | Restore files |

## Current Issues

### 1. Lack of State Integration

**Problem**: Wrapper scripts don't use opinions-state.sh for configuration
**Impact**: Runtime computation, inconsistent behavior
**Priority**: CRITICAL

**Fix Strategy**:
1. Source opinions-state.sh in all wrapper scripts
2. Replace hardcoded values with state lookups
3. Use pre-computed decisions from workspace.json
4. Ensure state cache is loaded with ensure_state()
5. Update runtime state ATOMICALLY with locks
6. Validate state consistency after operations

### 2. Direct Git Calls

**Problem**: Some scripts call git directly instead of version-control.sh
**Impact**: Violates single source of truth
**Priority**: CRITICAL

**Fix Strategy**:
1. Replace all git commands with version-control.sh functions
2. Use new bidirectional functions from version-control.sh:
   - `get_status_porcelain()` - Updates uncommittedCount
   - `get_branch_commit()` - Caches commit hashes
   - `list_merged_branches()` - Updates merged list
   - `checkout_branch()` - Atomic with state update
3. Ensure ALL git operations update state atomically

### 3. Direct Output Calls

**Problem**: Scripts use echo/printf instead of shell-formatting.sh
**Impact**: Inconsistent UI, no color support
**Priority**: HIGH

**Fix Strategy**:
1. Replace all echo with appropriate formatting functions
2. Use section(), step(), info(), success(), error()
3. Maintain consistent visual hierarchy

### 4. Missing Bidirectional Updates

**Problem**: Scripts don't report operations back to state
**Impact**: State becomes stale
**Priority**: HIGH

**Fix Strategy**:
1. Add update_state() calls after operations
2. Report git operations via report_git_operation()
3. Update runtime state consistently

### 5. Workflow Rule Implementation

**Problem**: Scripts don't follow workflow rules from opinions.yaml
**Impact**: Automation doesn't work as configured
**Priority**: HIGH

**Fix Strategy**:
1. Query workflow rules via get_value()
2. Implement prompts as defined
3. Follow branch creation/merge triggers

## Script-Specific Fixes

### start.sh

**Current Implementation**:
- Basic memory backup/restore
- Hardcoded context detection
- No workflow rule checking

**Required Changes**:
1. Integration with state using ATOMIC operations:
```bash
source opinions-state.sh
ensure_state

# Get workflow rules (with lock for consistency)
acquire_state_lock || die "Cannot acquire lock"
local start_behavior=$(get_value "computed.workflows.branchCreation.startBehavior")
local pull_on_start=$(get_value "computed.workflows.synchronization.pullOnStart")
release_state_lock
```

2. Implement workflow rules:
```bash
# Check if should create branch
if [[ "$start_behavior" == "check-first" ]]; then
    if ! branch_exists_for_context; then
        create_session_branch
    fi
elif [[ "$start_behavior" == "always" ]]; then
    create_session_branch
fi
```

3. Update state ATOMICALLY after operations:
```bash
# Atomic session creation
begin_atomic_operation "start:session:$SESSION_ID"

# Create session branch if needed
if create_session_branch; then
    # Update all session state atomically
    update_state "runtime.session.active" "true" && \
    update_state "runtime.session.id" "$SESSION_ID" && \
    update_state "runtime.session.context" "$WORK_CONTEXT" && \
    update_state "runtime.session.startTime" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" && \
    update_state "runtime.currentBranch" "$(get_current_branch)"
    
    if [[ $? -eq 0 ]]; then
        commit_atomic_operation
    else
        rollback_atomic_operation
        die "Failed to update session state"
    fi
else
    rollback_atomic_operation
    die "Failed to create session branch"
fi
```

### save.sh

**Current Implementation**:
- Basic memory save
- Simple git commit
- No branch protection

**Required Changes**:
1. Check protected branches:
```bash
local current=$(get_value "runtime.currentBranch")
local protected=$(get_value "computed.protectedBranches.all")

if is_protected_branch "$current" "$protected"; then
    local response=$(get_value "computed.workflows.branchCreation.protectionResponse")
    handle_protected_branch "$response"
fi
```

2. Implement auto-backup:
```bash
local auto_backup=$(get_value "computed.workflows.synchronization.autoBackup")
if [[ "$auto_backup" == "on-save" ]]; then
    push_to_remote
fi
```

3. Report operation with ATOMIC state updates:
```bash
# Atomic save operation
begin_atomic_operation "save:$current:$message"

# Perform git operations through version-control.sh
if stage_all_changes && commit_with_stats "$message"; then
    # Get updated values
    local commit_hash=$(get_last_commit_hash)
    local uncommitted=$(get_status_porcelain | wc -l)
    
    # Update all related state atomically
    update_state "runtime.git.uncommittedCount" "$uncommitted" && \
    update_state "runtime.git.lastCommit" "$commit_hash" && \
    update_state "runtime.git.lastCommitTime" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" && \
    update_state "runtime.git.lastCommitMessage" "$message" && \
    report_git_operation "save" "success" "{
        \"branch\": \"$current\",
        \"commit\": \"$commit_hash\",
        \"files\": $file_count,
        \"memory\": \"$memory_stats\"
    }"
    
    if [[ $? -eq 0 ]]; then
        commit_atomic_operation
        success "Changes saved successfully"
    else
        rollback_atomic_operation
        die "Failed to update state after commit"
    fi
else
    rollback_atomic_operation
    die "Failed to commit changes"
fi
```

### stop.sh

**Current Implementation**:
- Basic session cleanup
- Memory restoration
- No merge handling

**Required Changes**:
1. Handle session merges:
```bash
local session_merge=$(get_value "computed.workflows.merging.sessionMerge")
if [[ "$session_merge" == "on-stop" ]] && is_session_branch; then
    merge_session_to_parent
fi
```

2. Handle push on stop:
```bash
local push_on_stop=$(get_value "computed.workflows.synchronization.pushOnStop")
if should_push "$push_on_stop"; then
    push_branches
fi
```

3. Update state ATOMICALLY during cleanup:
```bash
# Atomic session cleanup
begin_atomic_operation "stop:session:$SESSION_ID"

# Save memory if needed
if [[ -n "$(get_status_porcelain)" ]]; then
    perform_atomic_save "Session end auto-save"
fi

# Handle session merge if configured
local session_merge=$(get_value "computed.workflows.merging.sessionMerge")
if [[ "$session_merge" == "on-stop" ]] && is_session_branch; then
    if merge_session_to_parent; then
        update_state "runtime.branches.merged[]" "$(get_current_branch)"
    else
        warn "Failed to merge session branch"
    fi
fi

# Update session state atomically
update_state "runtime.session.active" "false" && \
update_state "runtime.session.endTime" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" && \
update_state "runtime.lastSync" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [[ $? -eq 0 ]]; then
    commit_atomic_operation
    
    # Restore memory after state is updated
    restore_original_memory
else
    rollback_atomic_operation
    die "Failed to update session end state"
fi
```

### init.sh

**Current Implementation**:
- Basic initialization
- No state integration

**Required Changes**:
1. Create initial workspace.json
2. Initialize state system
3. Set up proper directory structure
4. Handle project vs framework initialization

### revert.sh

**Current Implementation**:
- Direct git calls
- Basic revert functionality

**Required Changes**:
1. Fix git violation (show_file_history)
2. Use state for memory paths
3. Add state updates after revert

## Common Patterns

### CRITICAL: Module Sourcing Order with Lock Management
```bash
# MUST source in this exact order
source "$SCRIPT_DIR/modules/shell-formatting.sh" || exit 1
source "$SCRIPT_DIR/modules/version-control.sh" || exit 1  
source "$SCRIPT_DIR/modules/migrate-memories.sh" || exit 1
source "$SCRIPT_DIR/modules/opinions-state.sh" || exit 1

# ALWAYS validate no direct calls
validate_no_git_calls "$(basename "$0")"
validate_no_echo_calls "$(basename "$0")"

# Initialize state with validation
ensure_state || die "State initialization failed"
validate_state_consistency || warn "State inconsistent with git"
```

### Atomic Operation Pattern
```bash
# ALL state-modifying operations MUST be atomic
perform_atomic_save() {
    local message="$1"
    
    begin_atomic_operation "save:$message"
    
    # Multiple operations as single transaction
    if stage_all_changes && \
       commit_with_stats "$message" && \
       update_state "runtime.git.uncommittedCount" "0" && \
       update_state "runtime.git.lastCommit" "$(get_last_commit_hash)"; then
        commit_atomic_operation
        return 0
    else
        rollback_atomic_operation
        return 1
    fi
}
```

### State Integration Pattern with Locks
```bash
#!/opt/homebrew/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source modules with proper error handling
source "$SCRIPT_DIR/modules/shell-formatting.sh" || exit 1
source "$SCRIPT_DIR/modules/version-control.sh" || exit 1
source "$SCRIPT_DIR/modules/opinions-state.sh" || exit 1

# Ensure state is loaded and consistent
ensure_state || die "Failed to load state"
validate_state_consistency || die "State inconsistent"

# Key paths (ALL under .aipm/):
# Memory symlink: .aipm/memory.json
# Backup location: .aipm/memory/backup.json
# Session lock: .aipm/memory/session_active
# State file: .aipm/state/workspace.json
# State lock: .aipm/state/.workspace.lock
```

### Workflow Query Pattern
```bash
# Get workflow rule
local rule=$(get_value "computed.workflows.category.rule")

# Apply rule
case "$rule" in
    "prompt")
        local prompt=$(get_value "decisions.prompts.category")
        if confirm "$prompt"; then
            perform_action
        fi
        ;;
    "auto")
        perform_action
        ;;
    "block")
        error "Operation blocked by workflow rules"
        ;;
esac
```

### State Update Pattern
```bash
# Before operation
local initial_state=$(get_value "runtime.git.uncommittedCount")

# Perform operation
perform_git_operation

# Update state
local new_state=$(count_uncommitted_files)
update_state "runtime.git.uncommittedCount" "$new_state"

# Report if changed
if [[ "$initial_state" != "$new_state" ]]; then
    report_git_operation "operation" "success" "{\"change\": \"uncommitted_files\"}"
fi
```

## Enforcement Mechanisms

### 1. Validation Functions
```bash
# Add to each wrapper script initialization
validate_no_git_calls() {
    local script="$1"
    # Override git command to detect violations
    git() {
        die "VIOLATION: Direct git call from $script. Use version-control.sh functions."
    }
}

validate_no_echo_calls() {
    local script="$1"
    # Override echo/printf to detect violations
    echo() {
        die "VIOLATION: Direct echo from $script. Use shell-formatting.sh functions."
    }
    printf() {
        die "VIOLATION: Direct printf from $script. Use shell-formatting.sh functions."
    }
}
```

### 2. Memory Operation Validation
```bash
# All memory operations MUST go through migrate-memories.sh
validate_memory_access() {
    local operation="$1"
    local file="$2"
    
    # Check file is in allowed list
    case "$file" in
        *.aipm/memory/local_memory.json|
        *.aipm/memory/backup.json|
        *.aipm/memory.json)
            # Allowed
            ;;
        *)
            die "VIOLATION: Unauthorized memory file access: $file"
            ;;
    esac
}
```

### 3. Workflow Rule Enforcement
```bash
# Query workflow rules from state
get_workflow_rule() {
    local category="$1"
    local rule="$2"
    
    local value=$(get_value "computed.workflows.$category.$rule")
    if [[ -z "$value" ]]; then
        die "Missing workflow rule: $category.$rule"
    fi
    echo "$value"
}
```

## Implementation Order

### Phase 1: Core Integration (Week 1)
1. Add state sourcing to all scripts
2. Replace hardcoded values
3. Fix output function calls
4. Add validation functions
5. Commit after each script (file reversion protocol)

### Phase 2: Git Compliance (Week 1-2)
1. Fix all direct git calls
2. Add missing version-control.sh usage
3. Ensure proper error handling

### Phase 3: Workflow Implementation (Week 2-3)
1. Implement branch creation triggers
2. Add merge triggers
3. Implement sync triggers
4. Add cleanup triggers

### Phase 4: State Updates (Week 3)
1. Add all missing state updates
2. Implement report_git_operation calls
3. Test bidirectional flow

### Phase 5: Testing & Polish (Week 4)
1. Integration tests for workflows
2. Performance optimization
3. Documentation updates

## Success Criteria

1. **Zero hardcoded values** - everything from state
2. **Zero direct git calls** - all through version-control.sh
3. **Zero direct output** - all through shell-formatting.sh
4. **Zero direct memory access** - all through migrate-memories.sh
5. **Complete workflow implementation** - all rules followed
6. **Full bidirectional updates** - state always current
7. **Validation functions** preventing violations
8. **workflow.md compliance** - following single source of truth
9. **No line numbers** in any documentation

## Testing Strategy

### Lock Management Tests
```bash
# Test concurrent wrapper script execution
test_concurrent_wrapper_access() {
    # Start multiple saves in parallel
    for i in {1..5}; do
        (./save.sh "Concurrent save $i") &
    done
    wait
    
    # Verify no state corruption
    validate_state_consistency || fail "State corrupted"
}
```

### Atomic Operation Tests
```bash
# Test rollback on save failure
test_save_rollback() {
    local initial_state=$(get_complete_runtime_state)
    
    # Force failure mid-operation
    FORCE_COMMIT_FAILURE=1 ./save.sh "Test message"
    
    # Verify state unchanged
    local final_state=$(get_complete_runtime_state)
    [[ "$initial_state" == "$final_state" ]] || fail "State changed on failure"
}
```

### State Consistency Tests
```bash
# Test state updates match git reality
test_state_git_consistency() {
    ./start.sh --project TestProject
    
    # Verify state matches git
    local git_branch=$(git rev-parse --abbrev-ref HEAD)
    local state_branch=$(get_value "runtime.currentBranch")
    [[ "$git_branch" == "$state_branch" ]] || fail "Branch mismatch"
    
    ./stop.sh --project TestProject
}
```

### Performance Tests
```bash
# Ensure operations meet targets
test_wrapper_performance() {
    # Start should complete in < 2s (including locks)
    time_operation "./start.sh --framework" 2000
    
    # Save should complete in < 1s
    time_operation "./save.sh 'Test commit'" 1000
    
    # Stop should complete in < 2s
    time_operation "./stop.sh --framework" 2000
}
```

## Next Steps (Aligned with State Management Fix Plan)

### Week 0: Foundation (MUST match state-management-fix-plan.md)
1. **Wait for lock infrastructure** from state management implementation
2. **Wait for atomic operation framework**
3. **Wait for new version-control.sh functions**

### Week 1: Wrapper Script Updates
1. **Update module loading** in all scripts:
   - Add lock validation
   - Add state consistency checks
   - Initialize with atomic framework

2. **Implement atomic patterns** in order:
   - init.sh: Full exclusive lock for initialization
   - start.sh: Atomic session creation
   - save.sh: Atomic commit with state updates
   - stop.sh: Atomic cleanup with merge
   - revert.sh: Atomic restoration

### Week 2: Integration Testing
1. **Test lock contention** between scripts
2. **Test atomic rollbacks** on failures  
3. **Verify state consistency** after all operations
4. **Performance benchmarking**

### Critical Dependencies
- **MUST use** functions from updated version-control.sh
- **MUST follow** state update matrix exactly
- **MUST acquire** locks for ALL state operations
- **MUST validate** state consistency

## Additional Fixes from .agentrules Review

### 1. Branch Protection Compliance
- Check opinions.yaml for protected branches
- Implement protection responses (prompt/block/force)
- Validate branch operations against rules

### 2. Workspace Isolation
- Ensure complete separation between workspaces
- Validate entity prefixes for memory operations
- Check branch namespace compliance

### 3. Error Recovery
- Implement proper error handling for all operations
- Add rollback mechanisms for failed operations
- Ensure state consistency after errors

### 4. Documentation Updates
- Remove ALL line number references
- Update with function names and search hints
- Add LEARNING comments for complex logic