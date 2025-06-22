# AIPM Architecture Ground Truth & Specification

## Executive Summary

During the implementation of state management for AIPM, we discovered critical architectural violations that compromise the system's integrity. This document consolidates all findings and establishes the ground truth for fixing these issues.

## Core Architecture Principles

### 1. Single Source of Truth
- **RULE**: Only `version-control.sh` may call git commands directly
- **NO EXCEPTIONS**: No fallback patterns, no bypassing
- **RATIONALE**: Consistency, safety, testability, maintainability

### 2. Module Dependencies
```
opinions.yaml
    ↓
opinions-loader.sh (pure YAML→shell transformation)
    ↓
opinions-state.sh (state management + pre-computation)
    ↓
version-control.sh (ONLY module calling git)
shell-formatting.sh (ONLY module calling echo/printf)
```

### 3. Bidirectional State Management
- Wrapper scripts read state AND report changes back
- State remains consistent across all operations
- No stale data, no manual sync required

## Current Violations Summary

### Critical Violations Found
1. **opinions-state.sh**: 20+ direct git calls
2. **revert.sh**: 1 direct git call
3. **migrate-memories.sh**: Unknown (needs audit)
4. **Multiple modules**: Direct echo/printf instead of shell-formatting.sh

### Architecture Score: 4.5/10
- Single Responsibility: 6/10 (some 200+ line functions)
- Dependency Inversion: 2/10 (direct git calls everywhere)
- Documentation: 7/10 (72% complete)
- Error Handling: 6/10 (inconsistent patterns)
- State Management: 4/10 (no bidirectional updates initially)

## Missing Functions in version-control.sh

### Configuration Functions
```bash
get_git_config()              # Read git config values
```

### Status Functions
```bash
get_status_porcelain()        # Machine-readable status
count_uncommitted_files()     # Count changed files
```

### Branch Functions
```bash
get_branch_commit()           # Get commit hash for branch
list_merged_branches()        # List merged branches
is_branch_merged()            # Check if branch is merged
get_upstream_branch()         # Get tracking branch
has_upstream()                # Check if has upstream
```

### Log Functions
```bash
get_branch_log()              # Flexible log queries
find_commits_with_pattern()   # Find commits by pattern
get_branch_creation_date()    # First commit date
get_branch_last_commit_date() # Last commit date
show_file_history()           # File commit history (for revert.sh)
```

### Repository Functions
```bash
get_git_dir()                 # Get .git directory path
is_in_git_dir()               # Check if inside .git
```

### Stash Functions
```bash
count_stashes()               # Get stash count
```

## Implementation Plan

### Phase 1: Add Missing Functions to version-control.sh (Week 1)
**Priority**: CRITICAL - Blocks all other fixes

#### Day 1-2: Core Functions
1. `get_status_porcelain()` - Used 5+ times
2. `get_upstream_branch()` - Used 4+ times
3. `get_branch_commit()` - Used 3+ times
4. `get_branch_log()` - Used 5+ times

#### Day 3-4: Branch & Config Functions
5. `get_git_config()` - Used 2+ times
6. `list_merged_branches()` - Used 2+ times
7. `is_branch_merged()` - Derived function
8. `has_upstream()` - Derived function

#### Day 5: Remaining Functions
9. `count_stashes()` - Used 1 time
10. `find_commits_with_pattern()` - Used 2+ times
11. `get_branch_creation_date()` - Used 1 time
12. `get_branch_last_commit_date()` - Used 1 time
13. `show_file_history()` - For revert.sh
14. `get_git_dir()` - Used 1 time
15. `is_in_git_dir()` - Safety check
16. `count_uncommitted_files()` - Derived

### Phase 2: Fix opinions-state.sh (Week 2)
**Priority**: CRITICAL - Most violations here

#### Day 1-2: Replace High-Usage Violations
- Fix all `git config` calls → `get_git_config()`
- Fix all `git status` calls → `get_status_porcelain()`
- Fix all `git rev-parse` calls → appropriate functions

#### Day 3-4: Replace Log & Branch Operations
- Fix all `git log` calls → `get_branch_log()`
- Fix all `git branch` calls → appropriate functions
- Remove ALL fallback patterns

#### Day 5: Testing & Validation
- Verify zero direct git calls remain
- Test all state management functions
- Ensure bidirectional updates work

### Phase 3: Fix Other Modules (Week 3)
**Priority**: HIGH - Complete architecture compliance

1. Fix revert.sh (1 violation)
2. Audit migrate-memories.sh
3. Check all other modules
4. Fix any echo/printf violations

### Phase 4: Establish Enforcement (Week 3)
**Priority**: HIGH - Prevent future violations

1. Add pre-commit hook:
```bash
#!/bin/bash
# .git/hooks/pre-commit
violations=$(find .aipm/scripts -name "*.sh" -type f ! -name "version-control.sh" \
    -exec grep -l 'git[[:space:]]\+[a-z]' {} \;)

if [[ -n "$violations" ]]; then
    echo "ERROR: Direct git calls found outside version-control.sh:"
    echo "$violations"
    exit 1
fi
```

2. Update developer guidelines
3. Add CI/CD checks
4. Document architecture rules

### Phase 5: Complete Documentation (Week 4)
**Priority**: MEDIUM - Finish the job

1. Complete remaining 28% function documentation
2. Add architecture diagrams
3. Create developer onboarding guide
4. Update all README files

## Success Criteria

### Must Have (Week 1-2)
- [ ] Zero direct git calls in opinions-state.sh
- [ ] All 16 functions added to version-control.sh
- [ ] No fallback patterns anywhere
- [ ] All tests passing

### Should Have (Week 3)
- [ ] All modules architecturally compliant
- [ ] Pre-commit hooks active
- [ ] 100% function documentation
- [ ] Bidirectional state updates working

### Nice to Have (Week 4+)
- [ ] Architecture diagrams created
- [ ] Performance optimizations applied
- [ ] Advanced error handling patterns
- [ ] Comprehensive test coverage

## Code Examples

### WRONG Pattern (Never Do This)
```bash
# Direct git call with fallback
if declare -F get_branch_commit >/dev/null 2>&1; then
    commit=$(get_branch_commit "$branch")
else
    commit=$(git rev-parse "$branch" 2>/dev/null)  # VIOLATION!
fi
```

### CORRECT Pattern (Always Do This)
```bash
# Require version-control.sh
if ! declare -F get_branch_commit >/dev/null 2>&1; then
    error "version-control.sh not properly sourced"
    return 1
fi
commit=$(get_branch_commit "$branch")
```

## Key Decisions Made

1. **No Fallbacks**: If a function is missing, that's a fatal error
2. **Bidirectional Updates**: All state changes must be reported back
3. **Pure Functions**: opinions-loader.sh remains transformation-only
4. **Pre-computation**: Everything computed once, accessed instantly
5. **SOLID Principles**: Applied to all new code

## Risks & Mitigations

### Risk: Breaking Existing Functionality
**Mitigation**: Surgical refactoring, comprehensive testing

### Risk: Performance Impact
**Mitigation**: Pre-computation strategy, efficient state access

### Risk: Developer Resistance
**Mitigation**: Clear documentation, automated enforcement

### Risk: Hidden Violations
**Mitigation**: Comprehensive audit, pre-commit hooks

## Conclusion

The architecture violations discovered are critical and must be fixed before any other development. This document serves as the single source of truth for the fixes required. The implementation plan provides a clear path forward with specific tasks and timelines.

**Remember**: Architecture purity is non-negotiable for maintainability.