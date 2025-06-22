# Git Architecture Fix Plan

## The Problem

opinions-state.sh violates the fundamental architecture principle by calling git directly instead of using version-control.sh as the single source of truth. This breaks:

1. **Single Source of Truth** - Git operations scattered across modules
2. **Consistency** - Different modules might handle git differently  
3. **Error Handling** - Bypasses hardened error handling in version-control.sh
4. **Testing** - Can't mock/test git operations centrally
5. **Security** - Bypasses safety checks in version-control.sh

## Current State

- **version-control.sh**: Has 50+ functions but missing 15+ needed operations
- **opinions-state.sh**: Has 20+ direct git calls with "fallback" patterns
- **Fallback Pattern**: WRONG approach - encourages architectural bypass

```bash
# CURRENT WRONG PATTERN:
if declare -F list_branches >/dev/null 2>&1; then
    all_branches=$(list_branches all)
else
    # ARCHITECTURAL VIOLATION!
    all_branches=$(git branch -a --no-color | sed 's/^[* ]*//')
fi
```

## The Solution

### Phase 1: Enhance version-control.sh (CRITICAL)

Add these missing functions to version-control.sh:

#### Configuration Functions
- `get_git_config()` - Read git configuration values

#### Status Functions  
- `get_status_porcelain()` - Machine-readable status
- `count_uncommitted_files()` - Count changed files

#### Branch Functions
- `get_branch_commit()` - Get commit hash for branch
- `list_merged_branches()` - List merged branches
- `is_branch_merged()` - Check if branch is merged
- `get_upstream_branch()` - Get tracking branch
- `has_upstream()` - Check if has upstream

#### Log Functions
- `get_branch_log()` - Flexible log queries
- `find_commits_with_pattern()` - Find commits by pattern
- `get_branch_creation_date()` - First commit date
- `get_branch_last_commit_date()` - Last commit date

#### Repository Functions
- `get_git_dir()` - Get .git directory path
- `is_in_git_dir()` - Check if inside .git

#### Stash Functions
- `count_stashes()` - Get stash count

### Phase 2: Fix opinions-state.sh (CRITICAL)

Remove ALL direct git calls and fallback patterns:

```bash
# CORRECT PATTERN - NO FALLBACK:
# If version-control.sh isn't sourced, that's a fatal error
if ! declare -F list_branches >/dev/null 2>&1; then
    error "version-control.sh not sourced - cannot proceed"
    return 1
fi

all_branches=$(list_branches all)
```

### Phase 3: Audit Other Modules (HIGH)

Check ALL other modules for direct git calls:
```bash
find .aipm/scripts -name "*.sh" -exec grep -l "git " {} \; | 
    grep -v version-control.sh
```

### Phase 4: Establish Policy (HIGH)

1. **Document the rule**: "ONLY version-control.sh may call git directly"
2. **Add pre-commit hook**: Reject commits with git calls outside version-control.sh
3. **Update developer guidelines**: Explain the architecture

## Implementation Order

### Step 1: Add Critical Functions First
These are used multiple times and block the most fixes:
1. `get_status_porcelain()`
2. `get_upstream_branch()` 
3. `get_branch_commit()`
4. `get_branch_log()`

### Step 2: Fix High-Usage Violations
Update opinions-state.sh sections that use the above functions

### Step 3: Add Remaining Functions
Add the rest of the missing functions to version-control.sh

### Step 4: Complete opinions-state.sh Fix
Remove ALL remaining git calls and fallback patterns

### Step 5: Verify Architecture
- No direct git calls outside version-control.sh
- No fallback patterns
- All git operations go through the single source of truth

## Success Criteria

1. **Zero direct git calls** in opinions-state.sh
2. **No fallback patterns** - if function missing, that's an error
3. **version-control.sh** has all needed git operations
4. **Clear error messages** when version-control.sh not sourced
5. **Documentation** updated to reflect architecture

## Why This Matters

1. **Consistency**: All git operations behave the same way
2. **Safety**: All operations get version-control.sh's safety features
3. **Debugging**: One place to add git operation logging
4. **Testing**: Can mock version-control.sh for testing
5. **Evolution**: Can enhance git operations in one place

## Example Fix

```bash
# BEFORE (opinions-state.sh):
local user=$(git config user.name 2>/dev/null | tr ' ' '_')

# AFTER:
if ! declare -F get_git_config >/dev/null 2>&1; then
    error "version-control.sh not properly sourced"
    return 1
fi
local user=$(get_git_config "user.name" | tr ' ' '_')
```

This architectural purity is non-negotiable for a well-designed system.