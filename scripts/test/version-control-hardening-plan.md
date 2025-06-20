# version-control.sh Hardening Plan

> Branch: test_version_control_core
> Priority: CRITICAL - This is the foundation of AIPM

## 🚨 Critical Issues to Fix

### 1. Missing Core Functions (BLOCKER)

#### `format_size()` - Used but not defined
```bash
# REQUIRED BY: commit_with_stats() line 488
# SOLUTION: Import from shell-formatting.sh or implement locally
format_size() {
    local size="$1"
    # Implementation needed
}
```

#### `stash_changes()` - Core requirement missing
```bash
# REQUIRED BY: save.sh, start.sh workflows
# MUST: Track state with DID_STASH variable
stash_changes() {
    local message="${1:-AIPM auto-stash}"
    # Implementation needed
}
```

#### `restore_stash()` - Companion to stash_changes
```bash
# REQUIRED BY: All stash operations
# MUST: Only restore if DID_STASH=true
restore_stash() {
    # Implementation needed
}
```

### 2. Formatting Consistency (HIGH)

Replace ALL direct printf/echo with shell-formatting.sh functions:
- Line 47-49: `printf` → `die`
- Line 65-67: `printf` → `die`
- Line 174-175: `printf` → `info`
- Line 244-250: Raw color codes → formatting functions
- Line 603: `printf` → `output`

### 3. Error Code Standardization (HIGH)

Define constants for consistent exit codes:
```bash
# Exit codes (must match documentation)
readonly EXIT_SUCCESS=0
readonly EXIT_GENERAL_ERROR=1
readonly EXIT_GIT_COMMAND_FAILED=2
readonly EXIT_WORKING_DIR_NOT_CLEAN=3
readonly EXIT_MERGE_CONFLICT=4
readonly EXIT_NETWORK_ERROR=5
```

### 4. Modularization Requirements (HIGH)

#### Break down `pull_latest()`:
```bash
# Current: Does too much
pull_latest() {
    # Stash logic
    # Pull logic
    # Restore logic
}

# Target: Modular functions
stash_if_dirty() { }
do_git_pull() { }
restore_if_stashed() { }
pull_latest() {
    stash_if_dirty || return $?
    do_git_pull || return $?
    restore_if_stashed || return $?
}
```

### 5. Platform Compatibility (MEDIUM)

Fix platform-specific issues:
```bash
# Current: macOS-specific stat command
local size=$(stat -f%z "$file" 2>/dev/null)

# Fixed: Cross-platform
local size
if [[ "$PLATFORM" == "macos" ]]; then
    size=$(stat -f%z "$file" 2>/dev/null)
else
    size=$(stat -c%s "$file" 2>/dev/null)
fi
```

### 6. Team Collaboration Support (MEDIUM)

Add --sync-team support to push_changes:
```bash
push_changes() {
    local sync_team=false
    # Parse arguments for --sync-team
    # If sync_team, include memory files
}
```

## Implementation Order

### Phase 1: Critical Fixes (Do First)
1. [ ] Import/implement `format_size()` function
2. [ ] Create `stash_changes()` and `restore_stash()` functions
3. [ ] Fix all direct printf/echo calls
4. [ ] Add exit code constants

### Phase 2: Modularization
1. [ ] Break down `pull_latest()` into atomic functions
2. [ ] Extract UI from `cleanup_merged_branches()`
3. [ ] Create `with_directory()` wrapper for cd operations
4. [ ] Separate display logic from git operations

### Phase 3: Enhancement
1. [ ] Add --sync-team support
2. [ ] Fix platform-specific commands
3. [ ] Add proper transaction/rollback support
4. [ ] Improve error messages with recovery hints

### Phase 4: Testing
1. [ ] Test each function in isolation
2. [ ] Verify error codes match documentation
3. [ ] Test cross-platform compatibility
4. [ ] Verify integration with start/stop/save/revert

## Success Criteria

- [ ] NO direct printf/echo (except in formatting functions)
- [ ] ALL functions use consistent error codes (0-5)
- [ ] Each function is independently testable
- [ ] DID_STASH properly tracks stash state
- [ ] format_size() works correctly
- [ ] Platform compatibility verified
- [ ] All critical functions have proper error handling
- [ ] Integration with wrapper scripts verified

## Code Style Requirements

1. **Every function must**:
   - Use shell-formatting.sh for ALL output
   - Return specific error codes (not just 1)
   - Have clear parameter documentation
   - Be independently callable
   - Handle errors gracefully

2. **Example of proper function**:
```bash
# Create a new branch with validation
# Arguments:
#   $1 - branch_name (required)
#   $2 - base_branch (optional, defaults to current)
# Returns:
#   0 - Success
#   1 - Invalid branch name
#   2 - Git command failed
#   3 - Working directory not clean
create_branch() {
    local branch_name="$1"
    local base_branch="${2:-}"
    
    # Validate input
    if [[ -z "$branch_name" ]]; then
        error "Branch name required"
        return $EXIT_GENERAL_ERROR
    fi
    
    # Check working directory
    if ! is_working_directory_clean; then
        error "Working directory not clean"
        info "Commit or stash changes first"
        return $EXIT_WORKING_DIR_NOT_CLEAN
    fi
    
    # Create branch
    if ! git checkout -b "$branch_name" ${base_branch:+"$base_branch"} 2>/dev/null; then
        error "Failed to create branch: $branch_name"
        return $EXIT_GIT_COMMAND_FAILED
    fi
    
    success "Created and switched to branch: $branch_name"
    return $EXIT_SUCCESS
}
```

## Notes

- This is THE FOUNDATION - no shortcuts allowed
- Every change must maintain backward compatibility
- Test thoroughly before merging to Framework_version_control
- Document all decisions and learnings