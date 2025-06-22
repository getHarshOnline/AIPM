# State Management Fix Plan

## Overview

This document outlines the fixes needed for the state management system based on architectural violations discovered during implementation review.

## Critical Issues to Fix

### 1. Git Command Violations in opinions-state.sh

**Problem**: 20+ direct git calls instead of using version-control.sh
**Impact**: Violates single source of truth principle
**Priority**: CRITICAL

**Fix Strategy**:
1. Add 16 missing functions to version-control.sh (see list below)
2. Replace ALL direct git calls with version-control.sh functions
3. Remove ALL fallback patterns - if function missing, that's a fatal error

**Missing Functions to Add**:
```bash
# Configuration
get_git_config()              # Read git config values

# Status
get_status_porcelain()        # Machine-readable status
count_uncommitted_files()     # Count changed files

# Branch Operations
get_branch_commit()           # Get commit hash for branch
list_merged_branches()        # List merged branches
is_branch_merged()            # Check if branch is merged
get_upstream_branch()         # Get tracking branch
has_upstream()                # Check if has upstream

# Log Operations
get_branch_log()              # Flexible log queries
find_commits_with_pattern()   # Find commits by pattern
get_branch_creation_date()    # First commit date
get_branch_last_commit_date() # Last commit date
show_file_history()           # File commit history

# Repository
get_git_dir()                 # Get .git directory path
is_in_git_dir()               # Check if inside .git
count_stashes()               # Get stash count
```

### 2. Documentation Gaps

**Problem**: 28% of functions undocumented
**Impact**: Maintainability and learning curve
**Priority**: HIGH

**Fix Strategy**:
1. Add comprehensive inline documentation for all functions
2. Include LEARNING comments for complex logic
3. Add parameter descriptions and examples

### 3. Large Function Decomposition

**Problem**: Some functions exceed 200+ lines (e.g., make_complete_decisions)
**Impact**: Violates SOLID principles, hard to test
**Priority**: MEDIUM

**Fix Strategy**:
1. Break down large functions into smaller, focused functions
2. Extract decision logic into separate functions
3. Improve testability

### 4. Incomplete Bidirectional Updates

**Problem**: Not all wrapper scripts report state changes back
**Impact**: State becomes stale, inconsistent behavior
**Priority**: HIGH

**Fix Strategy**:
1. Ensure all git operations update runtime state
2. Add report_git_operation() calls in wrapper scripts
3. Implement state subscriptions for automatic updates

## Implementation Order

### Phase 1: Add Missing Functions (Week 1)
1. Implement all 16 functions in version-control.sh
2. Add comprehensive documentation
3. Write tests for each function

### Phase 2: Fix Git Violations (Week 1-2)
1. Replace all direct git calls in opinions-state.sh
2. Remove fallback patterns
3. Update error handling

### Phase 3: Complete Documentation (Week 2)
1. Document remaining 28% of functions
2. Add LEARNING comments
3. Update examples

### Phase 4: Refactor Large Functions (Week 3)
1. Decompose make_complete_decisions()
2. Extract decision logic
3. Improve modularity

### Phase 5: Enhance Bidirectional Updates (Week 3-4)
1. Audit all wrapper scripts
2. Add missing state updates
3. Implement subscriptions

## Testing Strategy

### Unit Tests
- Test each new version-control.sh function
- Test state update mechanisms
- Test lock handling

### Integration Tests
- Test complete state initialization
- Test bidirectional updates
- Test concurrent access

### Performance Tests
- Measure pre-computation time
- Test state access speed
- Monitor memory usage

## Success Criteria

1. **Zero direct git calls** outside version-control.sh
2. **100% function documentation**
3. **No functions over 100 lines**
4. **All state changes reported**
5. **All tests passing**

## Risk Mitigation

### Risk: Breaking Existing Functionality
**Mitigation**: Incremental changes with thorough testing

### Risk: Performance Degradation
**Mitigation**: Benchmark before and after changes

### Risk: State Corruption
**Mitigation**: Enhanced locking and validation

## Timeline

- Week 1: Functions and git violations
- Week 2: Documentation and initial refactoring
- Week 3: Complete refactoring and bidirectional updates
- Week 4: Testing and optimization

## Next Steps

1. Start with adding the 4 most critical functions:
   - get_status_porcelain()
   - get_upstream_branch()
   - get_branch_commit()
   - get_branch_log()

2. Fix the highest-usage violations first

3. Test incrementally to ensure stability