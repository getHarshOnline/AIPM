# Missing Functions in version-control.sh

Based on the audit of opinions-state.sh, these functions need to be added to version-control.sh to eliminate ALL direct git calls:

## 1. Configuration Functions

### get_git_config()
```bash
# PURPOSE: Get git configuration value
# PARAMETERS:
#   $1 - config_key (string): Git config key (e.g., "user.name")
# RETURNS:
#   0 - Success
#   1 - Config not found
# OUTPUTS:
#   Config value or empty string
get_git_config() {
    local key="$1"
    git config "$key" 2>/dev/null
}
```

## 2. Commit/Hash Functions

### get_branch_commit()
```bash
# PURPOSE: Get commit hash for a branch/ref
# PARAMETERS:
#   $1 - branch (string): Branch name or git ref
# RETURNS:
#   0 - Success
#   1 - Branch not found
# OUTPUTS:
#   Full commit hash or empty string
get_branch_commit() {
    local branch="$1"
    git rev-parse "$branch" 2>/dev/null
}
```

## 3. Log Query Functions

### get_branch_log()
```bash
# PURPOSE: Get flexible log output for a branch
# PARAMETERS:
#   $1 - branch (string): Branch name
#   $2 - format (string): Git log format string
#   $3 - options (string): Additional git log options [optional]
# RETURNS:
#   0 - Success
#   1 - Error
# OUTPUTS:
#   Formatted log output
get_branch_log() {
    local branch="$1"
    local format="$2"
    local options="${3:-}"
    
    git log $options --format="$format" "$branch" 2>/dev/null
}
```

### find_commits_with_pattern()
```bash
# PURPOSE: Find commits matching a pattern in message
# PARAMETERS:
#   $1 - pattern (string): Pattern to search for
#   $2 - branch (string): Branch to search [optional, default HEAD]
# RETURNS:
#   0 - Found matches
#   1 - No matches
# OUTPUTS:
#   Matching commits
find_commits_with_pattern() {
    local pattern="$1"
    local branch="${2:-HEAD}"
    
    git log --format="%H %s" "$branch" 2>/dev/null | grep "$pattern"
}
```

## 4. Branch Analysis Functions

### list_merged_branches()
```bash
# PURPOSE: List branches merged into target
# PARAMETERS:
#   $1 - target (string): Target branch [optional, default current]
# RETURNS:
#   0 - Success
#   1 - Error
# OUTPUTS:
#   List of merged branch names
list_merged_branches() {
    local target="${1:-HEAD}"
    git branch --merged "$target" 2>/dev/null | grep -v "^[* ]*${target}$" | sed 's/^[* ]*//'
}
```

### is_branch_merged()
```bash
# PURPOSE: Check if a branch is merged into target
# PARAMETERS:
#   $1 - branch (string): Branch to check
#   $2 - target (string): Target branch [optional, default main/master]
# RETURNS:
#   0 - Branch is merged
#   1 - Branch not merged
is_branch_merged() {
    local branch="$1"
    local target="${2:-$(get_default_branch)}"
    
    git branch --merged "$target" 2>/dev/null | grep -q "^[* ]*${branch}$"
}
```

## 5. Status Detail Functions

### get_status_porcelain()
```bash
# PURPOSE: Get machine-readable status output
# RETURNS:
#   0 - Success
#   1 - Error
# OUTPUTS:
#   Porcelain format status
get_status_porcelain() {
    git status --porcelain 2>/dev/null
}
```

### count_uncommitted_files()
```bash
# PURPOSE: Count files with uncommitted changes
# RETURNS:
#   0 - Always
# OUTPUTS:
#   Number of files with changes
count_uncommitted_files() {
    git status --porcelain 2>/dev/null | wc -l | tr -d ' '
}
```

## 6. Stash Functions

### count_stashes()
```bash
# PURPOSE: Get number of stashes
# RETURNS:
#   0 - Always
# OUTPUTS:
#   Number of stashes
count_stashes() {
    git stash list 2>/dev/null | wc -l | tr -d ' '
}
```

## 7. Remote/Upstream Functions

### get_upstream_branch()
```bash
# PURPOSE: Get upstream tracking branch
# PARAMETERS:
#   $1 - branch (string): Local branch [optional, default current]
# RETURNS:
#   0 - Has upstream
#   1 - No upstream
# OUTPUTS:
#   Upstream branch name or empty
get_upstream_branch() {
    local branch="${1:-HEAD}"
    git rev-parse --abbrev-ref "$branch@{upstream}" 2>/dev/null
}
```

### has_upstream()
```bash
# PURPOSE: Check if branch has upstream tracking
# PARAMETERS:
#   $1 - branch (string): Local branch [optional, default current]
# RETURNS:
#   0 - Has upstream
#   1 - No upstream
has_upstream() {
    local branch="${1:-HEAD}"
    git rev-parse --abbrev-ref "$branch@{upstream}" &>/dev/null
}
```

## 8. Repository Structure Functions

### get_git_dir()
```bash
# PURPOSE: Get .git directory location
# RETURNS:
#   0 - Success
#   1 - Not a git repo
# OUTPUTS:
#   Path to .git directory
get_git_dir() {
    git rev-parse --git-dir 2>/dev/null || echo ".git"
}
```

### is_in_git_dir()
```bash
# PURPOSE: Check if current directory is inside .git
# RETURNS:
#   0 - Inside .git directory
#   1 - Not inside .git directory
is_in_git_dir() {
    git rev-parse --is-inside-git-dir 2>/dev/null | grep -q "true"
}
```

## 9. Date/Time Functions

### get_branch_creation_date()
```bash
# PURPOSE: Get creation date of a branch
# PARAMETERS:
#   $1 - branch (string): Branch name
# RETURNS:
#   0 - Success
#   1 - Branch not found
# OUTPUTS:
#   ISO format date or empty
get_branch_creation_date() {
    local branch="$1"
    git log --format="%aI" --reverse "$branch" 2>/dev/null | head -1
}
```

### get_branch_last_commit_date()
```bash
# PURPOSE: Get last commit date on branch
# PARAMETERS:
#   $1 - branch (string): Branch name
# RETURNS:
#   0 - Success
#   1 - Branch not found
# OUTPUTS:
#   ISO format date or empty
get_branch_last_commit_date() {
    local branch="$1"
    git log -1 --format="%aI" "$branch" 2>/dev/null
}
```

## Implementation Priority

1. **CRITICAL** - Used multiple times:
   - `get_status_porcelain()`
   - `get_upstream_branch()`
   - `get_branch_commit()`
   - `get_branch_log()`

2. **HIGH** - Needed for functionality:
   - `list_merged_branches()`
   - `count_stashes()`
   - `get_git_config()`
   - `find_commits_with_pattern()`

3. **MEDIUM** - Nice to have:
   - `get_branch_creation_date()`
   - `get_branch_last_commit_date()`
   - `get_git_dir()`
   - `is_branch_merged()`

These functions should be added to version-control.sh to maintain architectural purity and eliminate ALL direct git calls from other modules.