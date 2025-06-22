# Wrapper Scripts Fix Plan

## Overview

This document outlines the fixes needed for wrapper scripts (start.sh, stop.sh, save.sh, revert.sh, init.sh) to properly integrate with the state management system and follow architectural principles.

## Current Issues

### 1. Lack of State Integration

**Problem**: Wrapper scripts don't use opinions-state.sh for configuration
**Impact**: Runtime computation, inconsistent behavior
**Priority**: CRITICAL

**Fix Strategy**:
1. Source opinions-state.sh in all wrapper scripts
2. Replace hardcoded values with state lookups
3. Use pre-computed decisions from workspace.json

### 2. Direct Git Calls

**Problem**: Some scripts call git directly instead of version-control.sh
**Impact**: Violates single source of truth
**Priority**: CRITICAL

**Fix Strategy**:
1. Replace all git commands with version-control.sh functions
2. Add missing wrapper functions if needed
3. Ensure consistent error handling

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
1. Integration with state:
```bash
source opinions-state.sh
ensure_state

# Get workflow rules
local start_behavior=$(get_value "computed.workflows.branchCreation.startBehavior")
local pull_on_start=$(get_value "computed.workflows.synchronization.pullOnStart")
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

3. Update state after operations:
```bash
update_state "runtime.session.active" "true"
update_state "runtime.session.id" "$SESSION_ID"
update_state "runtime.session.context" "$WORK_CONTEXT"
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

3. Report operation:
```bash
report_git_operation "save" "success" "{
    \"branch\": \"$current\",
    \"files\": $file_count,
    \"memory\": \"$memory_stats\"
}"
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

3. Update state:
```bash
update_state "runtime.session.active" "false"
update_state "runtime.session.endTime" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
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

### State Integration Pattern
```bash
#!/opt/homebrew/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source modules with proper error handling
source "$SCRIPT_DIR/modules/shell-formatting.sh" || exit 1
source "$SCRIPT_DIR/modules/version-control.sh" || exit 1
source "$SCRIPT_DIR/modules/opinions-state.sh" || exit 1

# Ensure state is loaded
ensure_state || die "Failed to load state"

# Key paths have changed:
# Memory symlink: .aipm/memory.json (NOT .claude/memory.json)
# Backup location: .aipm/memory/backup.json
# Session lock: .aipm/memory/session_active
# State file: .aipm/state/workspace.json
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

## Implementation Order

### Phase 1: Core Integration (Week 1)
1. Add state sourcing to all scripts
2. Replace hardcoded values
3. Fix output function calls

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
4. **Complete workflow implementation** - all rules followed
5. **Full bidirectional updates** - state always current

## Testing Strategy

### Unit Tests
- Test each workflow rule implementation
- Test state update mechanisms
- Test error paths

### Integration Tests
- Full session lifecycle (start → save → stop)
- Branch creation workflows
- Merge workflows
- Cleanup workflows

### User Acceptance Tests
- Non-technical user workflows
- Team collaboration scenarios
- Error recovery paths

## Next Steps

1. Start with start.sh as it's the entry point
2. Fix the most critical violations first
3. Test each script individually before integration
4. Document changes as you go