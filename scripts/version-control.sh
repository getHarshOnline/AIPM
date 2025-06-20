#!/opt/homebrew/bin/bash
#
# version-control.sh - Hardened Git wrapper utilities for AIPM framework
#
# This script provides:
# - Opinionated git workflow functions with error handling
# - Branch management utilities with validation
# - Commit formatting helpers with statistics
# - Sync and merge utilities with conflict detection
# - Status checking functions with visual feedback
# - Integration with shell-formatting.sh for consistent output
# - Progress indicators for long operations
# - Atomic operations with rollback support
#
# USAGE:
#   source "$SCRIPT_DIR/version-control.sh"
#
# DEPENDENCIES:
#   - git (required)
#   - shell-formatting.sh (required for full functionality)
#
# EXIT CODES:
#   0: Success
#   1: General error
#   2: Git command failed
#   3: Working directory not clean
#   4: Merge conflict
#   5: Network/remote error
#
# ENVIRONMENT VARIABLES:
#   GIT_AUTHOR_NAME: Override git author name
#   GIT_AUTHOR_EMAIL: Override git author email
#   AIPM_GIT_TIMEOUT: Timeout for git operations (default: 30s)
#   AIPM_AUTO_STASH: Auto-stash changes (default: true)
#
# LEARNING LOG:
# - 2025-06-20: Initial hardened version with full shell-formatting integration
# - 2025-06-20: Added progress indicators for fetch/pull operations
# - 2025-06-20: Added atomic operations with rollback support
# - 2025-06-20: Enhanced error handling with specific exit codes
#
# Created by: AIPM Framework
# License: Apache 2.0

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "This script should be sourced, not executed directly\n"
    printf "Usage: source %s\n" "$0"
    exit 1
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source formatting utilities (required)
# LEARNING: shell-formatting.sh is now a hard dependency for consistent UX
# We want all scripts to have the same look and feel
# Updated: 2025-06-20 for better integration
if [[ -f "$SCRIPT_DIR/shell-formatting.sh" ]]; then
    # Ensure colors and unicode for git output
    export AIPM_COLOR=true
    export AIPM_UNICODE=true
    source "$SCRIPT_DIR/shell-formatting.sh"
else
    printf "ERROR: shell-formatting.sh not found at %s\n" "$SCRIPT_DIR" >&2
    printf "This script requires shell-formatting.sh for proper operation\n" >&2
    return 1 2>/dev/null || exit 1
fi

# ============================================================================
# CONFIGURATION
# ============================================================================

# Set default timeout for git operations
GIT_TIMEOUT="${AIPM_GIT_TIMEOUT:-30}"

# Auto-stash behavior
AUTO_STASH="${AIPM_AUTO_STASH:-true}"

# Stash identifier for auto-stashing
STASH_MESSAGE="AIPM auto-stash at $(date +%Y%m%d-%H%M%S)"

# Track if we've stashed for cleanup
DID_STASH=false

# ============================================================================
# GIT CONFIGURATION
# ============================================================================

# Check if we're in a git repository
# LEARNING: Enhanced with better error messages and path info
# Updated: 2025-06-20 for better debugging
check_git_repo() {
    local git_dir
    
    if ! git_dir=$(git rev-parse --git-dir 2>&1); then
        error "Not in a git repository"
        debug "Current directory: $(pwd)"
        debug "Git error: $git_dir"
        return 1
    fi
    
    # Get repo root for info
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    debug "Repository root: $repo_root"
    
    return 0
}

# Get current branch name
# LEARNING: Handle detached HEAD state gracefully
# Updated: 2025-06-20 for better edge case handling
get_current_branch() {
    local branch
    
    # Try modern method first
    branch=$(git branch --show-current 2>/dev/null)
    
    if [[ -z "$branch" ]]; then
        # Fallback for older git or detached HEAD
        branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
        
        if [[ "$branch" == "HEAD" ]]; then
            # Detached HEAD state
            local commit=$(git rev-parse --short HEAD 2>/dev/null || printf "unknown")
            printf "(detached:%s)\n" "$commit"
            return
        fi
    fi
    
    printf "%s\n" "${branch:-unknown}"
}

# Get default branch (main/master)
get_default_branch() {
    local default_branch
    default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    
    if [[ -z "$default_branch" ]]; then
        # Try common defaults
        if git show-ref --verify --quiet refs/heads/main; then
            printf "main\n"
        elif git show-ref --verify --quiet refs/heads/master; then
            printf "master\n"
        else
            printf "main\n"  # Default fallback
        fi
    else
        printf "%s\n" "$default_branch"
    fi
}

# ============================================================================
# STATUS FUNCTIONS
# ============================================================================

# Check if working directory is clean
# LEARNING: Enhanced with optional verbose output
# Updated: 2025-06-20 for better status reporting
is_working_directory_clean() {
    local verbose="${1:-false}"
    local status
    
    status=$(git status --porcelain 2>/dev/null)
    
    if [[ -z "$status" ]]; then
        [[ "$verbose" == "true" ]] && success "Working directory is clean"
        return 0
    else
        if [[ "$verbose" == "true" ]]; then
            warn "Working directory has uncommitted changes:"
            printf "%s\n" "$status" | while IFS= read -r line; do
                printf "  %s\n" "$line"
            done
        fi
        return 1
    fi
}

# Get number of commits ahead/behind remote
get_commits_ahead_behind() {
    local branch="${1:-$(get_current_branch)}"
    local upstream="origin/$branch"
    
    # Check if upstream exists
    if ! git rev-parse --verify "$upstream" >/dev/null 2>&1; then
        printf "No upstream branch\n"
        return 1
    fi
    
    local ahead=$(git rev-list --count "$upstream".."$branch" 2>/dev/null || printf "0")
    local behind=$(git rev-list --count "$branch".."$upstream" 2>/dev/null || printf "0")
    
    printf "ahead: %d, behind: %d\n" "$ahead" "$behind"
}

# Show pretty git status
# LEARNING: Use shell-formatting.sh functions for consistent output
# Updated: 2025-06-20 with visual improvements
show_git_status() {
    local project="${1:-}"
    local original_dir=$(pwd)
    
    # Change directory if project specified
    if [[ -n "$project" ]]; then
        if ! cd "$project" 2>/dev/null; then
            error "Cannot access project: $project"
            return 1
        fi
        section "Git Status: $project"
    else
        section "Git Status"
    fi
    
    # Get branch info
    local branch=$(get_current_branch)
    local remote_status=$(get_commits_ahead_behind)
    
    # Display branch info
    if [[ "$branch" =~ ^\(detached ]]; then
        warn "Branch: $branch"
    else
        info "Branch: $branch"
    fi
    
    # Display remote status
    if [[ "$remote_status" != "No upstream branch" ]]; then
        info "Remote: $remote_status"
    else
        warn "Remote: No upstream branch configured"
    fi
    
    # Display working directory status
    if is_working_directory_clean; then
        success "Working directory: Clean"
    else
        warn "Working directory: Modified"
        # Show changed files with better formatting
        git status --short | while IFS= read -r line; do
            local status_code="${line:0:2}"
            local file_path="${line:3}"
            
            case "$status_code" in
                "M "*) printf "  %b%s %s%b\n" "$YELLOW" "modified:" "$file_path" "$NC" ;;
                "A "*) printf "  %b%s %s%b\n" "$GREEN" "added:" "$file_path" "$NC" ;;
                "D "*) printf "  %b%s %s%b\n" "$RED" "deleted:" "$file_path" "$NC" ;;
                "??"*) printf "  %b%s %s%b\n" "$DIM" "untracked:" "$file_path" "$NC" ;;
                *) printf "  %s\n" "$line" ;;
            esac
        done
    fi
    
    # Show stash info if any
    local stash_count=$(git stash list | wc -l | tr -d ' ')
    if [[ "$stash_count" -gt 0 ]]; then
        info "Stashes: $stash_count"
    fi
    
    # Return to original directory
    [[ "$original_dir" != "$(pwd)" ]] && cd "$original_dir" >/dev/null
}

# ============================================================================
# SYNC FUNCTIONS
# ============================================================================

# Fetch remote changes
# LEARNING: Add progress indication and timeout handling
# Updated: 2025-06-20 for better UX
fetch_remote() {
    local project="${1:-}"
    local original_dir=$(pwd)
    
    # Change directory if needed
    if [[ -n "$project" ]]; then
        if ! cd "$project" 2>/dev/null; then
            error "Cannot access project: $project"
            return 1
        fi
    fi
    
    # Use spinner for fetch operation
    if [[ "$VISUAL_MODE" == "true" ]]; then
        execute_with_spinner "Fetching remote changes" \
            "git fetch --all --prune --progress 2>&1" \
            "$GIT_TIMEOUT"
        local result=$?
    else
        step "Fetching remote changes"
        if safe_execute "git fetch --all --prune --progress 2>&1" "$GIT_TIMEOUT"; then
            local result=0
        else
            local result=1
        fi
    fi
    
    if [[ $result -eq 0 ]]; then
        success "Remote changes fetched successfully"
        
        # Show what was fetched
        local new_branches=$(git branch -r | grep -v '\->' | wc -l | tr -d ' ')
        info "Remote branches: $new_branches"
    else
        error "Failed to fetch remote changes"
        [[ "$original_dir" != "$(pwd)" ]] && cd "$original_dir" >/dev/null
        return 5  # Network error
    fi
    
    # Return to original directory
    [[ "$original_dir" != "$(pwd)" ]] && cd "$original_dir" >/dev/null
}

# Pull latest changes with rebase
# LEARNING: Enhanced with better stash handling and conflict detection
# Updated: 2025-06-20 for robust operation
pull_latest() {
    local project="${1:-}"
    local force_pull="${2:-false}"
    local original_dir=$(pwd)
    
    # Change directory if needed
    if [[ -n "$project" ]]; then
        if ! cd "$project" 2>/dev/null; then
            error "Cannot access project: $project"
            return 1
        fi
    fi
    
    # Reset stash tracking
    DID_STASH=false
    
    # Check if working directory is clean
    if ! is_working_directory_clean; then
        if [[ "$AUTO_STASH" == "true" ]] || [[ "$force_pull" == "true" ]]; then
            warn "Working directory has uncommitted changes"
            step "Stashing local changes"
            
            if git stash push -m "$STASH_MESSAGE" --include-untracked; then
                DID_STASH=true
                success "Changes stashed successfully"
            else
                error "Failed to stash changes"
                [[ "$original_dir" != "$(pwd)" ]] && cd "$original_dir" >/dev/null
                return 3  # Working directory not clean
            fi
        else
            error "Working directory has uncommitted changes"
            info "Use --force to auto-stash, or commit/stash manually"
            is_working_directory_clean true  # Show what's modified
            [[ "$original_dir" != "$(pwd)" ]] && cd "$original_dir" >/dev/null
            return 3  # Working directory not clean
        fi
    fi
    
    # Perform pull with rebase
    if [[ "$VISUAL_MODE" == "true" ]]; then
        execute_with_spinner "Pulling latest changes" \
            "git pull --rebase --progress 2>&1" \
            "$GIT_TIMEOUT"
        local result=$?
    else
        step "Pulling latest changes"
        if safe_execute "git pull --rebase --progress 2>&1" "$GIT_TIMEOUT"; then
            local result=0
        else
            local result=1
        fi
    fi
    
    if [[ $result -eq 0 ]]; then
        success "Successfully pulled latest changes"
        
        # Show what was updated
        local commits_pulled=$(git rev-list HEAD@{1}..HEAD 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$commits_pulled" -gt 0 ]]; then
            info "Pulled $commits_pulled new commits"
        fi
        
        # Restore stashed changes if any
        if [[ "$DID_STASH" == "true" ]]; then
            step "Restoring stashed changes"
            
            if git stash list | grep -q "$STASH_MESSAGE"; then
                if git stash pop --quiet; then
                    success "Stashed changes restored"
                else
                    error "Failed to restore stashed changes"
                    warn "Your changes are still in the stash"
                    info "Run 'git stash pop' manually to restore"
                    [[ "$original_dir" != "$(pwd)" ]] && cd "$original_dir" >/dev/null
                    return 4  # Merge conflict
                fi
            fi
        fi
    else
        error "Failed to pull changes"
        
        # Check if it's a rebase conflict
        if git status | grep -q "rebase in progress"; then
            error "Rebase conflict detected"
            info "Resolve conflicts and run: git rebase --continue"
            info "Or abort with: git rebase --abort"
        fi
        
        [[ "$original_dir" != "$(pwd)" ]] && cd "$original_dir" >/dev/null
        return 5  # Network error or conflict
    fi
    
    # Return to original directory
    [[ "$original_dir" != "$(pwd)" ]] && cd "$original_dir" >/dev/null
}

# ============================================================================
# COMMIT FUNCTIONS
# ============================================================================

# Create a well-formatted commit
# Usage: create_commit "message" ["extended description"]
# LEARNING: Enhanced with validation and better formatting
# Updated: 2025-06-20 for better commit messages
create_commit() {
    local message="$1"
    local description="${2:-}"
    local skip_hooks="${3:-false}"
    
    # Validate message
    if [[ -z "$message" ]]; then
        error "Commit message cannot be empty"
        return 1
    fi
    
    # Check if there are changes to commit
    if [[ -z $(git status --porcelain) ]]; then
        warn "No changes to commit"
        return 0
    fi
    
    # Build commit message
    local commit_msg="$message"
    
    if [[ -n "$description" ]]; then
        commit_msg="$message"$'\n\n'"$description"
    fi
    
    # Add AIPM footer with timestamp
    commit_msg+=$'\n\n'"Created with AIPM Framework"
    commit_msg+=$'\n'"Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    
    # Add co-author if in collaborative mode
    if [[ -n "${AIPM_CO_AUTHOR:-}" ]]; then
        commit_msg+=$'\n\n'"Co-authored-by: $AIPM_CO_AUTHOR"
    fi
    
    # Show what will be committed
    step "Creating commit: $message"
    
    # Perform commit
    local commit_args=(-m "$commit_msg")
    [[ "$skip_hooks" == "true" ]] && commit_args+=(--no-verify)
    
    if git commit "${commit_args[@]}"; then
        success "Commit created successfully"
        
        # Show commit info
        local commit_hash=$(git rev-parse --short HEAD)
        local files_changed=$(git diff HEAD~1 --name-only | wc -l | tr -d ' ')
        info "Commit: $commit_hash ($files_changed files changed)"
        
        return 0
    else
        error "Failed to create commit"
        return 2  # Git command failed
    fi
}

# Commit with statistics
# Usage: commit_with_stats "message" "file_path"
commit_with_stats() {
    local message="$1"
    local file_path="$2"
    local stats=""
    
    # Get file statistics
    if [[ -f "$file_path" ]]; then
        local lines=$(wc -l < "$file_path" 2>/dev/null || printf "0")
        local size=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null || printf "0")
        local formatted_size=$(format_size "$size" 2>/dev/null || printf "%d bytes" "$size")
        
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
    section "Local branches"
    git branch -vv | while read -r line; do
        if [[ "$line" =~ ^\* ]]; then
            # Current branch - highlight in green
            printf "%b%s%b\n" "$GREEN" "$line" "$NC"
        else
            printf "  %s\n" "$line"
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
# LEARNING: Enhanced with graph view and better formatting
# Updated: 2025-06-20 for improved readability
show_log() {
    local count="${1:-10}"
    local file="${2:-}"
    local show_graph="${3:-true}"
    
    # Build log command
    local log_args=()
    log_args+=(--date=short)
    log_args+=(--pretty=format:'%C(yellow)%h%C(reset) - %C(green)%ad%C(reset) %C(blue)%an%C(reset): %s')
    log_args+=(-n "$count")
    
    [[ "$show_graph" == "true" ]] && log_args+=(--graph)
    
    # Show section header
    if [[ -n "$file" ]]; then
        section "Git History: $file"
        log_args+=(-- "$file")
    else
        section "Git History"
    fi
    
    # Execute log command
    git log "${log_args[@]}"
    printf "\n"  # New line after log
    
    # Show summary
    local total_commits=$(git rev-list --count HEAD 2>/dev/null || printf "0")
    info "Total commits in repository: $total_commits"
}

# Find commits affecting a file
find_file_commits() {
    local file="$1"
    local count="${2:-20}"
    
    section "Commits affecting $file"
    git log --oneline --follow -n "$count" -- "$file" | while read -r line; do
        printf "  %b%s%b\n" "$YELLOW" "$line" "$NC"
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
        section "Diff between $ref1 and $ref2"
        if [[ -n "$file" ]]; then
            git diff --stat "$ref1" "$ref2" -- "$file"
        else
            git diff --stat "$ref1" "$ref2"
        fi
    else
        section "Uncommitted changes"
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
        info "Push with: git push origin $tag_name"
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
# LEARNING: Enhanced with safety checks and batch mode
# Updated: 2025-06-20 for safer operation
cleanup_merged_branches() {
    local batch_mode="${1:-false}"
    local default_branch=$(get_default_branch)
    local current_branch=$(get_current_branch)
    
    # Ensure we're on default branch
    if [[ "$current_branch" != "$default_branch" ]]; then
        step "Switching to $default_branch for cleanup"
        if ! git checkout "$default_branch" 2>/dev/null; then
            error "Failed to switch to $default_branch"
            return 1
        fi
    fi
    
    # Find merged branches
    local merged_branches=()
    while IFS= read -r branch; do
        # Skip protected branches
        [[ -z "$branch" ]] && continue
        [[ "$branch" =~ ^[[:space:]]*\* ]] && continue
        [[ "$branch" =~ (main|master|develop|staging|production) ]] && continue
        
        # Clean up branch name
        branch=$(printf "%s" "$branch" | xargs)
        merged_branches+=("$branch")
    done < <(git branch --merged)
    
    if [[ ${#merged_branches[@]} -eq 0 ]]; then
        info "No merged branches to clean up"
        return 0
    fi
    
    # Show branches to be deleted
    section "Merged branches found"
    printf "\n"
    for branch in "${merged_branches[@]}"; do
        printf "  %b%s%b\n" "$YELLOW" "$branch" "$NC"
    done
    printf "\n"
    
    # Confirm deletion
    if [[ "$batch_mode" == "true" ]] || confirm "Delete all ${#merged_branches[@]} merged branches?"; then
        local deleted=0
        local failed=0
        
        # Delete branches with progress
        for branch in "${merged_branches[@]}"; do
            step "Deleting branch: $branch"
            if git branch -d "$branch" 2>/dev/null; then
                ((deleted++))
            else
                warn "Failed to delete: $branch"
                ((failed++))
            fi
        done
        
        # Show summary
        success "Cleanup complete: $deleted deleted, $failed failed"
        
        # Prune remote tracking branches
        if confirm "Also prune remote tracking branches?"; then
            step "Pruning remote tracking branches"
            git remote prune origin
            success "Remote tracking branches pruned"
        fi
    else
        info "Cleanup cancelled"
    fi
}

# ============================================================================
# ADVANCED GIT OPERATIONS
# ============================================================================

# Push changes with automatic upstream setup
# LEARNING: Smart push that handles upstream configuration
# Added: 2025-06-20 for easier pushing
push_changes() {
    local force="${1:-false}"
    local branch=$(get_current_branch)
    
    # Check if upstream is set
    local upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || printf "")
    
    if [[ -z "$upstream" ]]; then
        warn "No upstream branch set for '$branch'"
        if confirm "Set upstream to 'origin/$branch' and push?"; then
            step "Setting upstream and pushing"
            if git push --set-upstream origin "$branch"; then
                success "Pushed and set upstream successfully"
            else
                error "Failed to push changes"
                return 5  # Network error
            fi
        else
            info "Push cancelled"
            return 1
        fi
    else
        # Normal push
        step "Pushing to $upstream"
        local push_args=()
        [[ "$force" == "true" ]] && push_args+=(--force-with-lease)
        
        if git push "${push_args[@]}"; then
            success "Changes pushed successfully"
            
            # Show what was pushed
            local commits_pushed=$(git rev-list "$upstream"..HEAD | wc -l | tr -d ' ')
            if [[ "$commits_pushed" -gt 0 ]]; then
                info "Pushed $commits_pushed commits"
            fi
        else
            error "Failed to push changes"
            
            # Check for common issues
            if git status | grep -q "Your branch is behind"; then
                warn "Your branch is behind the remote"
                info "Pull latest changes first: git pull --rebase"
            fi
            
            return 5  # Network error
        fi
    fi
}

# Create a backup branch before dangerous operations
# LEARNING: Safety first - always have a backup
# Added: 2025-06-20 for safer operations
create_backup_branch() {
    local operation="${1:-backup}"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_name="backup/${operation}-$timestamp"
    
    step "Creating backup branch: $backup_name"
    
    if git branch "$backup_name" 2>/dev/null; then
        success "Backup branch created: $backup_name"
        info "Restore with: git checkout $backup_name"
        return 0
    else
        error "Failed to create backup branch"
        return 1
    fi
}

# Undo last commit (with safety)
# LEARNING: Provide safe undo with backup
# Added: 2025-06-20 for easier error recovery
undo_last_commit() {
    local keep_changes="${1:-true}"
    
    # Check if there are commits to undo
    if ! git rev-parse HEAD~1 >/dev/null 2>&1; then
        error "No commits to undo (at initial commit)"
        return 1
    fi
    
    # Get commit info
    local last_commit=$(git log -1 --oneline)
    warn "Will undo commit: $last_commit"
    
    if confirm "Proceed with undo?"; then
        # Create backup first
        if create_backup_branch "undo-commit"; then
            step "Undoing last commit"
            
            if [[ "$keep_changes" == "true" ]]; then
                # Soft reset - keep changes
                if git reset --soft HEAD~1; then
                    success "Commit undone, changes kept in staging"
                else
                    error "Failed to undo commit"
                    return 2
                fi
            else
                # Hard reset - discard changes
                if git reset --hard HEAD~1; then
                    success "Commit undone, changes discarded"
                else
                    error "Failed to undo commit"
                    return 2
                fi
            fi
        fi
    else
        info "Undo cancelled"
    fi
}

# ============================================================================
# CONFLICT RESOLUTION HELPERS
# ============================================================================

# Check for merge conflicts
# Added: 2025-06-20 for better conflict handling
check_conflicts() {
    local conflict_files=$(git diff --name-only --diff-filter=U)
    
    if [[ -n "$conflict_files" ]]; then
        error "Merge conflicts detected in:"
        printf "%s\n" "$conflict_files" | while IFS= read -r file; do
            printf "  %b%s%b\n" "$RED" "$file" "$NC"
        done
        return 1
    else
        success "No merge conflicts"
        return 0
    fi
}

# Interactive conflict resolution
# Added: 2025-06-20 for guided conflict resolution
resolve_conflicts() {
    if ! check_conflicts; then
        section "Conflict Resolution"
        
        # Get list of conflicted files
        local conflict_files=()
        while IFS= read -r file; do
            [[ -n "$file" ]] && conflict_files+=("$file")
        done < <(git diff --name-only --diff-filter=U)
        
        info "Found ${#conflict_files[@]} files with conflicts"
        
        # Process each file
        for file in "${conflict_files[@]}"; do
            step "Resolving: $file"
            
            # Show options
            printf "  1) Keep current (ours)\n"
            printf "  2) Keep incoming (theirs)\n"
            printf "  3) Edit manually\n"
            printf "  4) Skip this file\n"
            
            read -p "Choice [1-4]: " choice
            
            case "$choice" in
                1)
                    git checkout --ours "$file"
                    git add "$file"
                    success "Kept current version"
                    ;;
                2)
                    git checkout --theirs "$file"
                    git add "$file"
                    success "Kept incoming version"
                    ;;
                3)
                    info "Edit the file and run: git add $file"
                    ;;
                4)
                    info "Skipped"
                    ;;
                *)
                    warn "Invalid choice, skipping"
                    ;;
            esac
        done
        
        # Check status after resolution
        if check_conflicts; then
            success "All conflicts resolved!"
            info "Continue with: git rebase --continue (or git merge --continue)"
        else
            warn "Some conflicts remain unresolved"
        fi
    fi
}

# ============================================================================
# EXPORT SUCCESS
# ============================================================================

# Set flag to indicate successful load
export VERSION_CONTROL_LOADED=true

# Show load status
debug "version-control.sh loaded successfully"
debug "Git timeout: ${GIT_TIMEOUT}s"
debug "Auto-stash: $AUTO_STASH"