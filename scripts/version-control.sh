#!/opt/homebrew/bin/bash
#
# version-control.sh - Git wrapper utilities for AIPM framework
#
# This script provides:
# - Opinionated git workflow functions
# - Branch management utilities
# - Commit formatting helpers
# - Sync and merge utilities
# - Status checking functions
#
# Usage: source this file in other scripts
#   source "$SCRIPT_DIR/version-control.sh"
#
# Created by: AIPM Framework
# License: Apache 2.0

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script should be sourced, not executed directly"
    echo "Usage: source $0"
    exit 1
fi

# Source formatting utilities if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/shell-formatting.sh" ]]; then
    source "$SCRIPT_DIR/shell-formatting.sh"
else
    # Fallback colors if formatting not available
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
fi

# ============================================================================
# GIT CONFIGURATION
# ============================================================================

# Check if we're in a git repository
check_git_repo() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        error "Not in a git repository"
        return 1
    fi
    return 0
}

# Get current branch name
get_current_branch() {
    git branch --show-current 2>/dev/null || echo "unknown"
}

# Get default branch (main/master)
get_default_branch() {
    local default_branch
    default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    
    if [[ -z "$default_branch" ]]; then
        # Try common defaults
        if git show-ref --verify --quiet refs/heads/main; then
            echo "main"
        elif git show-ref --verify --quiet refs/heads/master; then
            echo "master"
        else
            echo "main"  # Default fallback
        fi
    else
        echo "$default_branch"
    fi
}

# ============================================================================
# STATUS FUNCTIONS
# ============================================================================

# Check if working directory is clean
is_working_directory_clean() {
    [[ -z $(git status --porcelain 2>/dev/null) ]]
}

# Get number of commits ahead/behind remote
get_commits_ahead_behind() {
    local branch="${1:-$(get_current_branch)}"
    local upstream="origin/$branch"
    
    # Check if upstream exists
    if ! git rev-parse --verify "$upstream" >/dev/null 2>&1; then
        echo "No upstream branch"
        return 1
    fi
    
    local ahead=$(git rev-list --count "$upstream".."$branch" 2>/dev/null || echo 0)
    local behind=$(git rev-list --count "$branch".."$upstream" 2>/dev/null || echo 0)
    
    echo "ahead: $ahead, behind: $behind"
}

# Show pretty git status
show_git_status() {
    local project="${1:-}"
    
    if [[ -n "$project" ]]; then
        echo -e "${CYAN}Git status for $project:${NC}"
        cd "$project" || return 1
    else
        echo -e "${CYAN}Git status:${NC}"
    fi
    
    local branch=$(get_current_branch)
    local status=$(get_commits_ahead_behind)
    
    echo -e "  Branch: ${GREEN}$branch${NC}"
    echo -e "  Remote: ${BLUE}$status${NC}"
    
    if is_working_directory_clean; then
        echo -e "  Status: ${GREEN}Clean${NC}"
    else
        echo -e "  Status: ${YELLOW}Modified${NC}"
        git status --short
    fi
    
    [[ -n "$project" ]] && cd - >/dev/null
}

# ============================================================================
# SYNC FUNCTIONS
# ============================================================================

# Fetch remote changes
fetch_remote() {
    local project="${1:-}"
    
    if [[ -n "$project" ]]; then
        cd "$project" || return 1
    fi
    
    info "Fetching remote changes..."
    if git fetch --all --prune; then
        success "Remote changes fetched"
    else
        error "Failed to fetch remote changes"
        [[ -n "$project" ]] && cd - >/dev/null
        return 1
    fi
    
    [[ -n "$project" ]] && cd - >/dev/null
}

# Pull latest changes with rebase
pull_latest() {
    local project="${1:-}"
    
    if [[ -n "$project" ]]; then
        cd "$project" || return 1
    fi
    
    # Check if working directory is clean
    if ! is_working_directory_clean; then
        warn "Working directory has uncommitted changes"
        if confirm "Stash changes and continue?"; then
            git stash push -m "AIPM auto-stash before pull"
        else
            [[ -n "$project" ]] && cd - >/dev/null
            return 1
        fi
    fi
    
    info "Pulling latest changes..."
    if git pull --rebase; then
        success "Successfully pulled latest changes"
        
        # Pop stash if we stashed
        if git stash list | grep -q "AIPM auto-stash before pull"; then
            info "Restoring stashed changes..."
            git stash pop
        fi
    else
        error "Failed to pull changes"
        [[ -n "$project" ]] && cd - >/dev/null
        return 1
    fi
    
    [[ -n "$project" ]] && cd - >/dev/null
}

# ============================================================================
# COMMIT FUNCTIONS
# ============================================================================

# Create a well-formatted commit
# Usage: create_commit "message" ["extended description"]
create_commit() {
    local message="$1"
    local description="${2:-}"
    local commit_msg="$message"
    
    if [[ -n "$description" ]]; then
        commit_msg="$message"$'\n\n'"$description"
    fi
    
    # Add AIPM footer
    commit_msg+=$'\n\n'"Created with AIPM Framework"
    
    git commit -m "$commit_msg"
}

# Commit with statistics
# Usage: commit_with_stats "message" "file_path"
commit_with_stats() {
    local message="$1"
    local file_path="$2"
    local stats=""
    
    # Get file statistics
    if [[ -f "$file_path" ]]; then
        local lines=$(wc -l < "$file_path" 2>/dev/null || echo "0")
        local size=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null || echo "0")
        local formatted_size=$(format_size "$size" 2>/dev/null || echo "$size bytes")
        
        stats="File: $file_path"$'\n'
        stats+="Lines: $lines"$'\n'
        stats+="Size: $formatted_size"
    fi
    
    create_commit "$message" "$stats"
}

# ============================================================================
# BRANCH FUNCTIONS
# ============================================================================

# Create and checkout new branch
create_branch() {
    local branch_name="$1"
    local base_branch="${2:-$(get_default_branch)}"
    
    # Validate branch name
    if [[ ! "$branch_name" =~ ^[a-zA-Z0-9/_-]+$ ]]; then
        error "Invalid branch name: $branch_name"
        return 1
    fi
    
    # Check if branch already exists
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        error "Branch already exists: $branch_name"
        return 1
    fi
    
    info "Creating branch '$branch_name' from '$base_branch'"
    if git checkout -b "$branch_name" "$base_branch"; then
        success "Created and switched to branch: $branch_name"
    else
        error "Failed to create branch"
        return 1
    fi
}

# List branches with details
list_branches() {
    echo -e "${CYAN}Local branches:${NC}"
    git branch -vv | while read -r line; do
        if [[ "$line" =~ ^\* ]]; then
            echo -e "${GREEN}$line${NC}"
        else
            echo "  $line"
        fi
    done
}

# ============================================================================
# MERGE FUNCTIONS
# ============================================================================

# Merge branch with checks
safe_merge() {
    local source_branch="$1"
    local target_branch="${2:-$(get_current_branch)}"
    
    # Check if source branch exists
    if ! git show-ref --verify --quiet "refs/heads/$source_branch"; then
        error "Source branch does not exist: $source_branch"
        return 1
    fi
    
    # Check for uncommitted changes
    if ! is_working_directory_clean; then
        error "Cannot merge with uncommitted changes"
        return 1
    fi
    
    info "Merging '$source_branch' into '$target_branch'"
    
    # Perform merge
    if git merge "$source_branch" --no-ff -m "Merge branch '$source_branch' into $target_branch"; then
        success "Merge completed successfully"
    else
        error "Merge failed - resolve conflicts and commit"
        return 1
    fi
}

# ============================================================================
# HISTORY FUNCTIONS
# ============================================================================

# Show pretty log
show_log() {
    local count="${1:-10}"
    local file="${2:-}"
    
    local log_format="%C(yellow)%h%C(reset) - %C(green)%ad%C(reset) %C(blue)%an%C(reset): %s"
    
    if [[ -n "$file" ]]; then
        git log --date=short --pretty=format:"$log_format" -n "$count" -- "$file"
    else
        git log --date=short --pretty=format:"$log_format" -n "$count"
    fi
    echo  # New line after log
}

# Find commits affecting a file
find_file_commits() {
    local file="$1"
    local count="${2:-20}"
    
    echo -e "${CYAN}Commits affecting $file:${NC}"
    git log --oneline --follow -n "$count" -- "$file" | while read -r line; do
        echo -e "  ${YELLOW}$line${NC}"
    done
}

# ============================================================================
# DIFF FUNCTIONS
# ============================================================================

# Show diff statistics
show_diff_stats() {
    local ref1="${1:-HEAD}"
    local ref2="${2:-}"
    local file="${3:-}"
    
    if [[ -n "$ref2" ]]; then
        echo -e "${CYAN}Diff between $ref1 and $ref2:${NC}"
        if [[ -n "$file" ]]; then
            git diff --stat "$ref1" "$ref2" -- "$file"
        else
            git diff --stat "$ref1" "$ref2"
        fi
    else
        echo -e "${CYAN}Uncommitted changes:${NC}"
        if [[ -n "$file" ]]; then
            git diff --stat -- "$file"
        else
            git diff --stat
        fi
    fi
}

# ============================================================================
# TAG FUNCTIONS
# ============================================================================

# Create annotated tag
create_tag() {
    local tag_name="$1"
    local message="${2:-Release $tag_name}"
    
    # Validate tag name (semantic versioning)
    if [[ ! "$tag_name" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?$ ]]; then
        warn "Tag name doesn't follow semantic versioning: $tag_name"
        if ! confirm "Create anyway?"; then
            return 1
        fi
    fi
    
    info "Creating tag: $tag_name"
    if git tag -a "$tag_name" -m "$message"; then
        success "Tag created: $tag_name"
        echo "Push with: git push origin $tag_name"
    else
        error "Failed to create tag"
        return 1
    fi
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Check if file is tracked by git
is_file_tracked() {
    local file="$1"
    git ls-files --error-unmatch "$file" >/dev/null 2>&1
}

# Get repository root
get_repo_root() {
    git rev-parse --show-toplevel 2>/dev/null
}

# Clean up merged branches
cleanup_merged_branches() {
    local default_branch=$(get_default_branch)
    local current_branch=$(get_current_branch)
    
    if [[ "$current_branch" != "$default_branch" ]]; then
        warn "Switching to $default_branch for cleanup"
        git checkout "$default_branch"
    fi
    
    info "Cleaning up merged branches..."
    git branch --merged | grep -v "\*\|$default_branch\|main\|master" | while read -r branch; do
        if confirm "Delete merged branch: $branch?"; then
            git branch -d "$branch"
        fi
    done
    
    success "Cleanup complete"
}

# ============================================================================
# EXPORT SUCCESS
# ============================================================================

# Indicate successful sourcing
debug "version-control.sh loaded successfully"