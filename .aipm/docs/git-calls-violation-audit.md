# Git Calls Violation Audit - opinions-state.sh

## Critical Finding

opinions-state.sh contains **20+ direct git calls**, violating the single source of truth principle. version-control.sh should be the ONLY module calling git directly.

## Mapping of Violations to Solutions

### 1. Git Config Operations
```bash
# VIOLATION (line 553):
git config user.name

# SHOULD USE:
# MISSING! Need to add to version-control.sh:
get_git_config() {
    local key="$1"
    git config "$key" 2>/dev/null
}
```

### 2. Branch Listing
```bash
# VIOLATION (line 1650):
git branch -a --no-color

# SHOULD USE:
list_branches()  # Already exists in version-control.sh
```

### 3. Get Commit Hash
```bash
# VIOLATION (line 1677):
git rev-parse "$branch"

# SHOULD USE:
# MISSING! Need to add to version-control.sh:
get_branch_commit() {
    local branch="$1"
    git rev-parse "$branch" 2>/dev/null
}
```

### 4. Log Operations
```bash
# VIOLATIONS (lines 1694, 1703, 1719, 1720, 1743):
git log --format="%H %s" "$branch"
git log -1 --format="%s" "$init_marker"
git log --format="%aI" --reverse "$branch"
git log -1 --format="%aI" "$branch"
git log --merges --format="%H %s %aI"

# PARTIALLY EXISTS:
show_log()  # Exists but not flexible enough
find_file_commits()  # Exists but file-specific

# MISSING! Need to add to version-control.sh:
get_branch_log() {
    local branch="$1"
    local format="$2"
    local options="$3"
    git log $options --format="$format" "$branch" 2>/dev/null
}
```

### 5. Merged Branches
```bash
# VIOLATION (line 1735):
git branch --merged

# SHOULD USE:
# MISSING! Need to add to version-control.sh:
list_merged_branches() {
    local branch="${1:-HEAD}"
    git branch --merged "$branch" | grep -v "^[* ]*$branch$"
}
```

### 6. Current Branch
```bash
# VIOLATION (line 1922):
git rev-parse --abbrev-ref HEAD

# SHOULD USE:
get_current_branch()  # Already exists in version-control.sh
```

### 7. Status Operations
```bash
# VIOLATIONS (lines 1937, 1940):
git status --porcelain

# PARTIALLY EXISTS:
is_working_directory_clean()  # Returns boolean, not details

# MISSING! Need to add to version-control.sh:
get_status_porcelain() {
    git status --porcelain 2>/dev/null
}
```

### 8. Stash Operations
```bash
# VIOLATION (line 1975):
git stash list | wc -l

# SHOULD USE:
list_stashes()  # Exists but returns formatted output

# MISSING! Need to add to version-control.sh:
count_stashes() {
    git stash list 2>/dev/null | wc -l
}
```

### 9. Upstream Tracking
```bash
# VIOLATION (line 1807, 1991):
git rev-parse --abbrev-ref "$branch@{upstream}"
git rev-parse --abbrev-ref "@{u}"

# SHOULD USE:
# MISSING! Need to add to version-control.sh:
get_upstream_branch() {
    local branch="${1:-HEAD}"
    git rev-parse --abbrev-ref "$branch@{upstream}" 2>/dev/null
}
```

### 10. Ahead/Behind Count
```bash
# VIOLATIONS (lines 2002, 2003):
git rev-list --count "@{u}..HEAD"
git rev-list --count "HEAD..@{u}"

# SHOULD USE:
get_commits_ahead_behind()  # Already exists in version-control.sh
```

### 11. Repository Root
```bash
# VIOLATION (line 2017):
git rev-parse --show-toplevel

# SHOULD USE:
get_repo_root()  # Already exists in version-control.sh
```

### 12. Git Directory
```bash
# VIOLATION (line 2019):
git rev-parse --git-dir

# SHOULD USE:
# MISSING! Need to add to version-control.sh:
get_git_dir() {
    git rev-parse --git-dir 2>/dev/null || echo ".git"
}
```

## Summary of Required Actions

### Functions That Already Exist (USE THESE):
1. `list_branches()` - For branch listing
2. `get_current_branch()` - For current branch
3. `get_commits_ahead_behind()` - For ahead/behind count
4. `get_repo_root()` - For repository root
5. `list_stashes()` - For stash listing (may need count variant)

### Functions That MUST Be Added to version-control.sh:
1. `get_git_config()` - Read git config values
2. `get_branch_commit()` - Get commit hash for branch
3. `get_branch_log()` - Flexible log querying
4. `list_merged_branches()` - List branches merged into target
5. `get_status_porcelain()` - Get porcelain status output
6. `count_stashes()` - Get stash count
7. `get_upstream_branch()` - Get upstream tracking branch
8. `get_git_dir()` - Get .git directory location
9. `is_branch_merged()` - Check if branch is merged

## Critical Next Steps

1. **Add missing functions to version-control.sh** - These are legitimate git operations that the framework needs
2. **Update opinions-state.sh** - Replace ALL direct git calls with version-control.sh functions
3. **Verify no other modules** have direct git calls

This is a fundamental architectural issue that must be fixed to maintain the single source of truth principle.