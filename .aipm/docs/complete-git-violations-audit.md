# Complete Git Violations Audit - All AIPM Modules

## Summary

Found direct git calls in **3 modules** that violate the single source of truth principle:

1. **opinions-state.sh** - 20+ violations (most severe)
2. **revert.sh** - 1 violation  
3. **migrate-memories.sh** - Unknown (needs investigation)

## Detailed Violations

### 1. opinions-state.sh (20+ violations)

Most severe violator with direct calls for:
- `git config user.name`
- `git branch -a`
- `git rev-parse` (multiple variants)
- `git log` (multiple variants)
- `git branch --merged`
- `git status --porcelain`
- `git stash list`
- `git rev-list --count`

See `git-calls-violation-audit.md` for complete list.

### 2. revert.sh (1 violation)

```bash
# Line ~162:
git log --oneline --pretty=format:"%h | %ad | %s" --date=short -n 20 -- "$MEMORY_FILE"

# SHOULD USE:
# Need new function in version-control.sh:
show_file_history() {
    local file="$1"
    local count="${2:-20}"
    git log --oneline --pretty=format:"%h | %ad | %s" --date=short -n "$count" -- "$file" 2>/dev/null
}
```

### 3. migrate-memories.sh (needs investigation)

Listed as containing "git " but needs detailed analysis.

## Other Modules (CLEAN)

These modules correctly use version-control.sh or don't need git:
- **save.sh** - Uses version-control.sh functions correctly
- **start.sh** - Uses version-control.sh functions correctly  
- **shell-formatting.sh** - Just mentions "git" in text, no commands
- **test-state-updates.sh** - Test file, acceptable

## Complete List of Missing Functions for version-control.sh

### From opinions-state.sh (15 functions):
1. `get_git_config()` - Read git config values
2. `get_branch_commit()` - Get commit hash
3. `get_branch_log()` - Flexible log queries
4. `list_merged_branches()` - List merged branches
5. `get_status_porcelain()` - Machine-readable status
6. `count_stashes()` - Stash count
7. `get_upstream_branch()` - Upstream tracking
8. `get_git_dir()` - .git location
9. `find_commits_with_pattern()` - Search commits
10. `is_branch_merged()` - Check merge status
11. `count_uncommitted_files()` - Count changes
12. `has_upstream()` - Check upstream exists
13. `get_branch_creation_date()` - First commit date
14. `get_branch_last_commit_date()` - Last commit date
15. `is_in_git_dir()` - Check if in .git

### From revert.sh (1 function):
16. `show_file_history()` - Show file commit history

## Architecture Principles Being Violated

1. **Single Source of Truth** - Git operations must only exist in version-control.sh
2. **Abstraction Layer** - All modules must use the abstraction, not bypass it
3. **Consistency** - Different modules handling git differently
4. **Testability** - Can't mock git operations when directly called
5. **Safety** - Bypassing safety checks in version-control.sh

## Fix Priority

### Phase 1: Add Missing Functions (CRITICAL)
Add all 16 missing functions to version-control.sh

### Phase 2: Fix opinions-state.sh (CRITICAL)
- Remove ALL direct git calls
- Remove fallback patterns
- Require version-control.sh

### Phase 3: Fix revert.sh (HIGH)
Replace git log with show_file_history()

### Phase 4: Audit migrate-memories.sh (MEDIUM)
Check for any violations

### Phase 5: Establish Enforcement (HIGH)
- Add pre-commit hooks
- Document the rule
- Add automated checks

## Enforcement Recommendations

### 1. Pre-commit Hook
```bash
#!/bin/bash
# Check for direct git calls outside version-control.sh
violations=$(find .aipm/scripts -name "*.sh" -type f ! -name "version-control.sh" \
    -exec grep -l 'git[[:space:]]\+[a-z]' {} \;)

if [[ -n "$violations" ]]; then
    echo "ERROR: Direct git calls found outside version-control.sh:"
    echo "$violations"
    exit 1
fi
```

### 2. Clear Documentation
Add to developer guidelines:
> **CRITICAL RULE**: Only version-control.sh may call git directly. All other modules MUST use version-control.sh functions. No exceptions. No fallbacks.

### 3. Code Review Checklist
- [ ] No direct git calls outside version-control.sh
- [ ] No fallback patterns to git
- [ ] All git operations use wrapper functions
- [ ] New git needs = new function in version-control.sh

This architectural purity is essential for maintainability, consistency, and safety.