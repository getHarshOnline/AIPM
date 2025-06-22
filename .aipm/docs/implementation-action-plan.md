# AIPM Architecture Fix - Action Plan

## 🚨 IMMEDIATE ACTIONS (Today)

### Step 1: Add Critical Functions to version-control.sh
These 4 functions block the most fixes and are used repeatedly:

```bash
# 1. get_status_porcelain() - Used 5+ times
# PURPOSE: Get machine-readable status output
# RETURNS: 0=success, 1=error
# OUTPUTS: Porcelain format status
get_status_porcelain() {
    git status --porcelain 2>/dev/null
}

# 2. get_upstream_branch() - Used 4+ times  
# PURPOSE: Get upstream tracking branch
# PARAMETERS: $1 - branch (optional, default current)
# RETURNS: 0=has upstream, 1=no upstream
# OUTPUTS: Upstream branch name or empty
get_upstream_branch() {
    local branch="${1:-HEAD}"
    git rev-parse --abbrev-ref "$branch@{upstream}" 2>/dev/null
}

# 3. get_branch_commit() - Used 3+ times
# PURPOSE: Get commit hash for a branch/ref
# PARAMETERS: $1 - branch/ref
# RETURNS: 0=success, 1=not found
# OUTPUTS: Full commit hash or empty
get_branch_commit() {
    local branch="$1"
    git rev-parse "$branch" 2>/dev/null
}

# 4. get_branch_log() - Used 5+ times
# PURPOSE: Get flexible log output
# PARAMETERS: $1=branch, $2=format, $3=options
# RETURNS: 0=success, 1=error
# OUTPUTS: Formatted log output
get_branch_log() {
    local branch="$1"
    local format="$2"
    local options="${3:-}"
    
    git log $options --format="$format" "$branch" 2>/dev/null
}
```

### Step 2: Fix Critical Sections in opinions-state.sh
Replace these high-impact violations first:

1. **User Detection (line ~553)**:
```bash
# BEFORE:
local user=$(git config user.name 2>/dev/null | tr ' ' '_')

# AFTER:
local user=$(get_git_config "user.name" | tr ' ' '_')
```

2. **Status Checks (lines ~1937-1940)**:
```bash
# BEFORE:
local changes=$(git status --porcelain 2>/dev/null | wc -l)

# AFTER:
local changes=$(get_status_porcelain | wc -l)
```

3. **Branch Operations (line ~1650)**:
```bash
# BEFORE:
all_branches=$(git branch -a --no-color | sed 's/^[* ]*//')

# AFTER:
all_branches=$(list_branches all)
```

4. **Current Branch (line ~1922)**:
```bash
# BEFORE:
current=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

# AFTER:
current=$(get_current_branch)
```

## 📋 WEEK 1: Core Functions

### Monday-Tuesday: Essential Functions
Add to version-control.sh:
- [ ] `get_status_porcelain()`
- [ ] `get_upstream_branch()`
- [ ] `get_branch_commit()`
- [ ] `get_branch_log()`

### Wednesday-Thursday: Configuration & Branch Functions
Add to version-control.sh:
- [ ] `get_git_config()`
- [ ] `list_merged_branches()`
- [ ] `is_branch_merged()`
- [ ] `has_upstream()`
- [ ] `count_uncommitted_files()`

### Friday: Remaining Functions
Add to version-control.sh:
- [ ] `count_stashes()`
- [ ] `find_commits_with_pattern()`
- [ ] `get_branch_creation_date()`
- [ ] `get_branch_last_commit_date()`
- [ ] `show_file_history()`
- [ ] `get_git_dir()`
- [ ] `is_in_git_dir()`

## 📋 WEEK 2: Fix All Violations

### Monday-Tuesday: opinions-state.sh Core Fixes
- [ ] Replace all `git config` calls
- [ ] Replace all `git status` calls
- [ ] Replace all `git rev-parse` calls
- [ ] Remove ALL fallback patterns

### Wednesday-Thursday: opinions-state.sh Complete
- [ ] Replace all `git log` calls
- [ ] Replace all `git branch` calls
- [ ] Test every function
- [ ] Verify zero git calls remain

### Friday: Other Modules
- [ ] Fix revert.sh (1 violation)
- [ ] Audit migrate-memories.sh
- [ ] Check all remaining modules

## 📋 WEEK 3: Documentation & Enforcement

### Monday-Tuesday: Complete Documentation
- [ ] Finish remaining 28% of opinions-state.sh
- [ ] Document all new version-control.sh functions
- [ ] Update architecture documentation

### Wednesday-Thursday: Enforcement
- [ ] Add pre-commit hook
- [ ] Update CI/CD pipeline
- [ ] Create developer guidelines
- [ ] Add automated checks

### Friday: Testing & Validation
- [ ] Comprehensive test suite
- [ ] Performance benchmarks
- [ ] Integration tests
- [ ] User acceptance testing

## 🎯 Quick Wins (Do First)

1. **Add the 4 critical functions** - Unblocks most work
2. **Fix user detection** - Simple, high-impact
3. **Fix status operations** - Used everywhere
4. **Remove fallback patterns** - Enforce architecture

## ⚠️ Common Pitfalls to Avoid

1. **DON'T add fallbacks** - If function missing, fail loudly
2. **DON'T skip testing** - Test after each change
3. **DON'T rush** - Surgical refactoring is key
4. **DON'T forget docs** - Document as you go

## 📊 Progress Tracking

### Version-control.sh Functions
- [ ] 0/16 functions added
- [ ] 0/16 documented
- [ ] 0/16 tested

### opinions-state.sh Violations
- [ ] 0/20+ git calls fixed
- [ ] 0/20+ fallbacks removed
- [ ] 72% documented (target 100%)

### Other Modules
- [ ] revert.sh fixed
- [ ] migrate-memories.sh audited
- [ ] All modules compliant

## 🔄 Daily Checklist

- [ ] Add at least 2 functions to version-control.sh
- [ ] Fix at least 3 violations in opinions-state.sh
- [ ] Document everything added/changed
- [ ] Test all changes
- [ ] Commit with clear message

## 📝 Commit Message Template

```
fix: Add [function_name] to version-control.sh

- Implements [what it does]
- Replaces [X] direct git calls in [module]
- Part of architecture compliance fix

Refs: #architecture-violations
```

## 🏁 Definition of Done

1. **Zero** direct git calls outside version-control.sh
2. **All** 16 functions implemented and tested
3. **100%** documentation coverage
4. **Zero** fallback patterns
5. **Active** pre-commit hooks
6. **Passing** all tests

---

*This plan turns our analysis into action. Let's fix the architecture!*