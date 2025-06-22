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
# - 2025-06-20: Fixed environment detection bug - removed forced AIPM_COLOR=true
#              that was defeating shell-formatting.sh's smart detection
#
# Created by: AIPM Framework
# License: Apache 2.0

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "ERROR: This script should be sourced, not executed directly\n" >&2
    printf "Usage: source %s\n" "$0" >&2
    exit 1
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source formatting utilities (required)
# LEARNING: shell-formatting.sh is now a hard dependency for consistent UX
# We want all scripts to have the same look and feel
# Updated: 2025-06-20 for better integration
#
# CRITICAL LEARNING: Never force AIPM_COLOR or AIPM_UNICODE before sourcing!
# shell-formatting.sh has smart environment detection that determines:
# - If we're in a real terminal (colors enabled)
# - If we're in a pipe/CI environment (colors disabled)
# - If we're in Claude Code REPL (special handling)
# Forcing these values defeats the detection and causes issues like
# ANSI codes appearing in non-terminal environments.
# Fixed: 2025-06-20 after discovering "Error:" prefixes in test output
if [[ -f "$SCRIPT_DIR/shell-formatting.sh" ]]; then
    # Let shell-formatting.sh detect the environment
    # Don't force colors - that defeats the smart detection!
    # Get the modules directory
    MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$MODULES_DIR/shell-formatting.sh"
else
    printf "ERROR: shell-formatting.sh not found at %s\n" "$SCRIPT_DIR" >&2
    printf "This script requires shell-formatting.sh for proper operation\n" >&2
    return $EXIT_GENERAL_ERROR 2>/dev/null || exit $EXIT_GENERAL_ERROR
fi

# ============================================================================
# STATE MANAGEMENT INTEGRATION
# ============================================================================
# LEARNING: version-control.sh must be bidirectionally integrated with
# opinions-state.sh to ensure every git operation atomically updates state.
# This is critical for maintaining consistency between git reality and
# AIPM's state cache.
#
# ARCHITECTURAL REQUIREMENT: All git operations MUST update state atomically
# to prevent desync. This module is THE ONLY module allowed to call git
# commands directly.
#
# Added: 2025-06-22 for bidirectional state integration

# Source state management (required for atomic operations)
if [[ -f "$SCRIPT_DIR/opinions-state.sh" ]]; then
    source "$SCRIPT_DIR/opinions-state.sh" || {
        printf "ERROR: Failed to source opinions-state.sh\n" >&2
        printf "State management is required for version control operations\n" >&2
        return $EXIT_GENERAL_ERROR 2>/dev/null || exit $EXIT_GENERAL_ERROR
    }
else
    printf "ERROR: opinions-state.sh not found at %s\n" "$SCRIPT_DIR" >&2
    printf "State management is required for version control operations\n" >&2
    return $EXIT_GENERAL_ERROR 2>/dev/null || exit $EXIT_GENERAL_ERROR
fi

# Validate state on load
# LEARNING: Ensure state is initialized and consistent before any operations
# This prevents operations on stale or corrupted state
if ! ensure_state; then
    printf "ERROR: State initialization failed\n" >&2
    printf "Cannot proceed without valid state\n" >&2
    return $EXIT_GENERAL_ERROR 2>/dev/null || exit $EXIT_GENERAL_ERROR
fi

# Validate state consistency with git
# LEARNING: On module load, verify state matches git reality
# If drift is detected, attempt automatic repair
if ! validate_state_consistency; then
    warn "State inconsistent with git, attempting repair..."
    if ! repair_state_inconsistency "auto"; then
        printf "ERROR: State inconsistent with git and repair failed\n" >&2
        printf "Manual intervention required\n" >&2
        return $EXIT_GENERAL_ERROR 2>/dev/null || exit $EXIT_GENERAL_ERROR
    fi
fi

# ============================================================================
# CONFIGURATION
# ============================================================================

# STRICT MODE - NO FALLBACKS ALLOWED
# LEARNING: This enforces the architectural principle that version-control.sh
# is THE ONLY module allowed to call git. If a function is missing here,
# that's a FATAL ERROR - no bypassing, no workarounds.
# Added: 2025-06-22 for architectural enforcement
readonly STRICT_MODE=true

# Exit codes (must match documentation)
readonly EXIT_SUCCESS=0
readonly EXIT_GENERAL_ERROR=1
readonly EXIT_GIT_COMMAND_FAILED=2
readonly EXIT_WORKING_DIR_NOT_CLEAN=3
readonly EXIT_MERGE_CONFLICT=4
readonly EXIT_NETWORK_ERROR=5

# Set default timeout for git operations
GIT_TIMEOUT="${AIPM_GIT_TIMEOUT:-30}"

# Auto-stash behavior
AUTO_STASH="${AIPM_AUTO_STASH:-true}"

# Stash identifier format
readonly STASH_MESSAGE_PREFIX="AIPM auto-stash"

# Track if we've stashed for cleanup
DID_STASH=false

# Protected branches pattern
readonly PROTECTED_BRANCHES="^(main|master|develop|production)$"

# ============================================================================
# STRICT MODE ENFORCEMENT
# ============================================================================

# Function to enforce no-fallback rule
# PURPOSE: Called when a required function is missing from version-control.sh
# PARAMETERS:
#   $1 - Name of the missing function (required)
# RETURNS:
#   Never returns - always dies
# SIDE EFFECTS:
#   - Writes error to stderr
#   - Exits with EXIT_GENERAL_ERROR
# EXAMPLE:
#   # In opinions-state.sh:
#   if ! type get_git_config &>/dev/null; then
#       _missing_function_fatal "get_git_config"
#   fi
# LEARNING:
#   - This enforces the architectural principle that ALL git operations
#     must go through version-control.sh
#   - NO FALLBACKS means we die immediately if a function is missing
#   - This prevents architectural drift and maintains single source of truth
_missing_function_fatal() {
    local func="${1:-unknown}"
    die "FATAL: Required function '$func' missing from version-control.sh. NO FALLBACKS ALLOWED."
}

# ============================================================================
# SECURITY & CONTEXT MANAGEMENT
# ============================================================================

# Detect if we're in a nested script execution
# CRITICAL: Prevents recursive sourcing and security issues
# TESTED: 2025-06-20 (security category)
detect_nesting_level() {
    local nesting_level="${AIPM_NESTING_LEVEL:-0}"
    export AIPM_NESTING_LEVEL=$((nesting_level + 1))
    
    if [[ $AIPM_NESTING_LEVEL -gt 3 ]]; then
        error "Script nesting level too deep: $AIPM_NESTING_LEVEL"
        error "Possible recursive sourcing detected"
        return $EXIT_GENERAL_ERROR
    fi
    
    debug "Script nesting level: $AIPM_NESTING_LEVEL"
    return $EXIT_SUCCESS
}

# Cleanup function to decrement nesting level
# TESTED: 2025-06-20
# Verifies AIPM_NESTING_LEVEL decrements correctly
cleanup_nesting_level() {
    if [[ -n "${AIPM_NESTING_LEVEL:-}" ]] && [[ $AIPM_NESTING_LEVEL -gt 0 ]]; then
        export AIPM_NESTING_LEVEL=$((AIPM_NESTING_LEVEL - 1))
        debug "Decremented nesting level to: $AIPM_NESTING_LEVEL"
    fi
}

# Set trap to cleanup on exit
trap cleanup_nesting_level EXIT

# Check nesting immediately
if ! detect_nesting_level; then
    return $EXIT_GENERAL_ERROR 2>/dev/null || exit $EXIT_GENERAL_ERROR
fi

# Resolve actual project path from potential symlink
# Arguments:
#   $1 - path to resolve
# Returns: Resolved path on stdout
# TESTED: 2025-06-20 (security category)
resolve_project_path() {
    local path="${1:-.}"
    
    # Use readlink -f for full resolution (handles nested symlinks)
    if command -v readlink >/dev/null 2>&1; then
        # macOS needs greadlink for -f flag
        if [[ "$PLATFORM" == "macos" ]] && command -v greadlink >/dev/null 2>&1; then
            greadlink -f "$path" 2>/dev/null || realpath "$path" 2>/dev/null || printf "%s\n" "$path"
        else
            readlink -f "$path" 2>/dev/null || realpath "$path" 2>/dev/null || printf "%s\n" "$path"
        fi
    else
        # Fallback
        printf "%s\n" "$path"
    fi
}

# Get project context (handles symlinked projects)
# Sets: PROJECT_ROOT, PROJECT_NAME, IS_SYMLINKED, MEMORY_FILE_PATH
# TESTED: 2025-06-20 (security category)
get_project_context() {
    local current_dir=$(pwd)
    
    # Check if we're in a symlinked directory
    local resolved_dir=$(resolve_project_path "$current_dir")
    
    if [[ "$current_dir" != "$resolved_dir" ]]; then
        export IS_SYMLINKED=true
        export PROJECT_ROOT="$resolved_dir"
        export PROJECT_NAME=$(basename "$current_dir")
        debug "Working in symlinked project: $PROJECT_NAME -> $PROJECT_ROOT"
    else
        export IS_SYMLINKED=false
        export PROJECT_ROOT="$current_dir"
        export PROJECT_NAME=$(basename "$current_dir")
        debug "Working in direct project: $PROJECT_NAME"
    fi
    
    # Detect if we're in AIPM root or a project
    if [[ -f "$PROJECT_ROOT/AIPM.md" ]]; then
        export AIPM_CONTEXT="framework"
    else
        export AIPM_CONTEXT="project"
    fi
    
    debug "Context: $AIPM_CONTEXT, Root: $PROJECT_ROOT"
}

# ============================================================================
# MEMORY MANAGEMENT INITIALIZATION
# ============================================================================

# Initialize memory file paths based on context
# This MUST be called when script is sourced with project context
# Arguments:
#   $1 - project context (optional, e.g., "--framework", "--project Product")
# Sets:
#   MEMORY_FILE_PATH - The primary memory file for this context
#   MEMORY_DIR - The directory containing memory files
#   MEMORY_FILE_NAME - Standard name for memory files
# TESTED: 2025-06-20 (memory category)
initialize_memory_context() {
    local context_arg="${1:-}"
    local project_name="${2:-}"
    
    # Standard memory file name (never changes)
    export MEMORY_FILE_NAME="local_memory.json"
    
    # Determine context from arguments or current directory
    if [[ "$context_arg" == "--framework" ]]; then
        export AIPM_CONTEXT="framework"
        export MEMORY_DIR=".memory"
        export MEMORY_FILE_PATH="$MEMORY_DIR/$MEMORY_FILE_NAME"
        export PROJECT_NAME="AIPM"
        debug "Memory context: Framework mode"
    elif [[ "$context_arg" == "--project" ]] && [[ -n "$project_name" ]]; then
        export AIPM_CONTEXT="project"
        export PROJECT_NAME="$project_name"
        export MEMORY_DIR="$project_name/.memory"
        export MEMORY_FILE_PATH="$MEMORY_DIR/$MEMORY_FILE_NAME"
        debug "Memory context: Project mode ($PROJECT_NAME)"
    else
        # Auto-detect based on current directory
        get_project_context
        if [[ "$AIPM_CONTEXT" == "framework" ]]; then
            export MEMORY_DIR=".memory"
            export MEMORY_FILE_PATH="$MEMORY_DIR/$MEMORY_FILE_NAME"
        else
            # In a project directory
            export MEMORY_DIR="$PROJECT_ROOT/.memory"
            export MEMORY_FILE_PATH="$MEMORY_DIR/$MEMORY_FILE_NAME"
        fi
        debug "Memory context: Auto-detected ($AIPM_CONTEXT)"
    fi
    
    # Ensure paths are absolute for consistency
    if [[ ! "$MEMORY_FILE_PATH" =~ ^/ ]]; then
        export MEMORY_FILE_PATH="$(pwd)/$MEMORY_FILE_PATH"
    fi
    if [[ ! "$MEMORY_DIR" =~ ^/ ]]; then
        export MEMORY_DIR="$(pwd)/$MEMORY_DIR"
    fi
    
    # Export for use by all functions
    export MEMORY_INITIALIZED=true
    
    debug "Memory configuration:"
    debug "  MEMORY_DIR: $MEMORY_DIR"
    debug "  MEMORY_FILE_PATH: $MEMORY_FILE_PATH"
    debug "  PROJECT_NAME: $PROJECT_NAME"
    debug "  AIPM_CONTEXT: $AIPM_CONTEXT"
    
    return $EXIT_SUCCESS
}

# Parse arguments passed to the script when sourced
# This allows: source version-control.sh --project Product
# TESTED: 2025-06-20
# Verifies correct AIPM_CONTEXT setting with --framework flag
_parse_source_args() {
    # Check if we were passed arguments when sourced
    if [[ -n "${1:-}" ]]; then
        initialize_memory_context "$@"
    else
        # No arguments, auto-detect
        initialize_memory_context
    fi
}

# Initialize on source (capture any arguments)
_parse_source_args "$@"

# Re-initialize memory context (useful for wrapper scripts)
# Usage: reinit_memory_context --project Product
# TESTED: 2025-06-20 (memory category)
reinit_memory_context() {
    debug "Re-initializing memory context with: $*"
    initialize_memory_context "$@"
}

# ============================================================================
# GIT CONFIGURATION
# ============================================================================

# Check if we're in a git repository
# LEARNING: Enhanced with better error messages and path info
# Updated: 2025-06-20 for better debugging
# TESTED: 2025-06-20 (git-config category)
check_git_repo() {
    local git_dir
    
    if ! git_dir=$(git rev-parse --git-dir 2>&1); then
        error "Not in a git repository"
        debug "Current directory: $(pwd)"
        debug "Git error: $git_dir"
        return $EXIT_GENERAL_ERROR
    fi
    
    # Get repo root for info
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    debug "Repository root: $repo_root"
    
    return $EXIT_SUCCESS
}

# Get current branch name
# LEARNING: Handle detached HEAD state gracefully
# Updated: 2025-06-20 for better edge case handling
# TESTED: 2025-06-20 (git-config category)
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
# TESTED: 2025-06-20 (git-config category)
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
# TESTED: 2025-06-20 (sync category)
is_working_directory_clean() {
    local verbose="${1:-false}"
    local status
    
    status=$(git status --porcelain 2>/dev/null)
    
    if [[ -z "$status" ]]; then
        [[ "$verbose" == "true" ]] && success "Working directory is clean"
        return $EXIT_SUCCESS
    else
        if [[ "$verbose" == "true" ]]; then
            warn "Working directory has uncommitted changes:"
            printf "%s\n" "$status" | while IFS= read -r line; do
                info "  $line"
            done
        fi
        return $EXIT_WORKING_DIR_NOT_CLEAN
    fi
}

# Get number of commits ahead/behind remote
# TESTED: 2025-06-20
# Verifies correct handling when no upstream exists
# Verifies ahead/behind count with actual remote
get_commits_ahead_behind() {
    local branch="${1:-$(get_current_branch)}"
    local upstream="origin/$branch"
    
    # Check if upstream exists
    if ! git rev-parse --verify "$upstream" >/dev/null 2>&1; then
        printf "No upstream branch\n"
        return $EXIT_GENERAL_ERROR
    fi
    
    local ahead=$(git rev-list --count "$upstream".."$branch" 2>/dev/null || printf "0")
    local behind=$(git rev-list --count "$branch".."$upstream" 2>/dev/null || printf "0")
    
    printf "ahead: %d, behind: %d\n" "$ahead" "$behind"
}

# Show pretty git status
# LEARNING: Use shell-formatting.sh functions for consistent output
# Updated: 2025-06-20 with visual improvements
# TESTED: 2025-06-20 (sync category)
show_git_status() {
    local project="${1:-}"
    local original_dir=$(pwd)
    
    # Change directory if project specified
    if [[ -n "$project" ]]; then
        if ! cd "$project" 2>/dev/null; then
            error "Cannot access project: $project"
            return $EXIT_GENERAL_ERROR
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
                "M "*) warn "  modified: $file_path" ;;
                "A "*) success "  added: $file_path" ;;
                "D "*) error "  deleted: $file_path" ;;
                "??"*) info "  untracked: $file_path" ;;
                *) info "  $line" ;;
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
    return $EXIT_SUCCESS
}

# ============================================================================
# STASH FUNCTIONS
# ============================================================================

# Stash changes with proper tracking
# Arguments:
#   $1 - message (optional, defaults to auto-generated)
#   $2 - include_untracked (optional, "true" to include untracked files)
# Returns:
#   0 - Success (sets DID_STASH=true)
#   1 - No changes to stash
#   2 - Stash failed
# Global Effects:
#   Sets DID_STASH=true if stash created
# TESTED: 2025-06-20 (stash category, comprehensive)
stash_changes() {
    local message="${1:-$STASH_MESSAGE_PREFIX at $(date +%Y%m%d-%H%M%S)}"
    local include_untracked="${2:-true}"
    
    # Reset global tracking
    DID_STASH=false
    
    # Check if there are changes to stash
    if is_working_directory_clean; then
        debug "No changes to stash"
        return $EXIT_GENERAL_ERROR
    fi
    
    # Build stash command
    local stash_cmd="git stash push -m \"$message\""
    [[ "$include_untracked" == "true" ]] && stash_cmd+=" --include-untracked"
    
    # Execute stash
    step "Stashing local changes"
    if eval "$stash_cmd" 2>/dev/null; then
        DID_STASH=true
        success "Changes stashed: $message"
        return $EXIT_SUCCESS
    else
        error "Failed to stash changes"
        return $EXIT_GIT_COMMAND_FAILED
    fi
}

# Restore stashed changes
# Arguments:
#   $1 - stash_ref (optional, defaults to latest)
# Returns:
#   0 - Success (resets DID_STASH=false)
#   1 - No stash to restore
#   2 - Restore failed
# Global Effects:
#   Sets DID_STASH=false after restore
# TESTED: 2025-06-20 (stash category, comprehensive)
restore_stash() {
    local stash_ref="${1:-}"
    
    # Check if we should restore
    if [[ "$DID_STASH" != "true" ]]; then
        debug "No stash to restore (DID_STASH=$DID_STASH)"
        return $EXIT_GENERAL_ERROR
    fi
    
    # Check if stash exists
    if [[ -z "$(git stash list)" ]]; then
        warn "No stashes found but DID_STASH was true"
        DID_STASH=false
        return $EXIT_GENERAL_ERROR
    fi
    
    # Restore stash
    step "Restoring stashed changes"
    if git stash pop ${stash_ref:+"$stash_ref"} 2>/dev/null; then
        DID_STASH=false
        success "Changes restored from stash"
        return $EXIT_SUCCESS
    else
        error "Failed to restore stashed changes"
        warn "Your changes are still in the stash"
        info "Use 'git stash list' to see stashes"
        info "Use 'git stash pop' to retry manually"
        return $EXIT_GIT_COMMAND_FAILED
    fi
}

# List all stashes with formatting
# Returns:
#   0 - Success
#   1 - No stashes found
# TESTED: 2025-06-20 (stash category)
list_stashes() {
    local stash_list=$(git stash list 2>/dev/null)
    
    if [[ -z "$stash_list" ]]; then
        info "No stashes found"
        return $EXIT_GENERAL_ERROR
    fi
    
    section "Git Stashes"
    printf "%s\n" "$stash_list" | while IFS= read -r line; do
        # Format: stash@{0}: On branch: message
        local stash_ref="${line%%:*}"
        local stash_info="${line#*: }"
        info "$stash_ref: $stash_info"
    done
    
    return $EXIT_SUCCESS
}

# ============================================================================
# SYNC FUNCTIONS
# ============================================================================

# Fetch remote changes
# LEARNING: Add progress indication and timeout handling
# Updated: 2025-06-20 for better UX
# TESTED: 2025-06-20
# Test uses local file:// remote to verify fetch operation
# LEARNING: Fixed missing explicit return statement that caused exit code 1
# when directory hadn't changed (from conditional cd back)
fetch_remote() {
    local project="${1:-}"
    local original_dir=$(pwd)
    
    # Change directory if needed
    if [[ -n "$project" ]]; then
        if ! cd "$project" 2>/dev/null; then
            error "Cannot access project: $project"
            return $EXIT_GENERAL_ERROR
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
        return $EXIT_NETWORK_ERROR
    fi
    
    # Return to original directory
    [[ "$original_dir" != "$(pwd)" ]] && cd "$original_dir" >/dev/null
    return $EXIT_SUCCESS
}

# Pull latest changes with rebase
# LEARNING: Enhanced with better stash handling and conflict detection
# Updated: 2025-06-20 for robust operation
# TESTED: 2025-06-20
# TESTED: 2025-06-20 (comprehensive scenarios)
# Test verifies stash handling, conflicts, and DID_STASH tracking
# LEARNING: Fixed missing explicit return statement
pull_latest() {
    local project="${1:-}"
    local force_pull="${2:-false}"
    local original_dir=$(pwd)
    
    # Change directory if needed
    if [[ -n "$project" ]]; then
        if ! cd "$project" 2>/dev/null; then
            error "Cannot access project: $project"
            return $EXIT_GENERAL_ERROR
        fi
    fi
    
    # Check if working directory is clean
    if ! is_working_directory_clean; then
        if [[ "$AUTO_STASH" == "true" ]] || [[ "$force_pull" == "true" ]]; then
            # Use our modular stash function
            if ! stash_changes "$STASH_MESSAGE_PREFIX for pull"; then
                error "Failed to stash changes"
                [[ "$original_dir" != "$(pwd)" ]] && cd "$original_dir" >/dev/null
                return $EXIT_WORKING_DIR_NOT_CLEAN
            fi
        else
            error "Working directory has uncommitted changes"
            info "Use --force to auto-stash, or commit/stash manually"
            is_working_directory_clean true  # Show what's modified
            [[ "$original_dir" != "$(pwd)" ]] && cd "$original_dir" >/dev/null
            return $EXIT_WORKING_DIR_NOT_CLEAN
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
            if ! restore_stash; then
                warn "Failed to restore stashed changes"
                [[ "$original_dir" != "$(pwd)" ]] && cd "$original_dir" >/dev/null
                return $EXIT_MERGE_CONFLICT
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
        return $EXIT_NETWORK_ERROR
    fi
    
    # Return to original directory
    [[ "$original_dir" != "$(pwd)" ]] && cd "$original_dir" >/dev/null
    return $EXIT_SUCCESS
}

# ============================================================================
# COMMIT FUNCTIONS
# ============================================================================

# Create a well-formatted commit
# Usage: create_commit "message" ["extended description"] [skip_hooks] [auto_stage]
# CRITICAL: Implements AIPM golden rule - stages ALL changes by default
# Updated: 2025-06-20 for AIPM golden rule compliance
# TESTED: 2025-06-20 (auto-staging)
# TESTED: 2025-06-20 (commit category)
create_commit() {
    local message="$1"
    local description="${2:-}"
    local skip_hooks="${3:-false}"
    local auto_stage="${4:-true}"  # GOLDEN RULE: stage everything by default
    
    # Validate message
    if [[ -z "$message" ]]; then
        error "Commit message cannot be empty"
        return $EXIT_GENERAL_ERROR
    fi
    
    # Get project context for proper handling
    get_project_context
    
    # GOLDEN RULE IMPLEMENTATION: Stage all changes first
    if [[ "$auto_stage" == "true" ]]; then
        step "Implementing golden rule: staging all changes"
        if ! stage_all_changes; then
            error "Failed to stage changes according to golden rule"
            return $EXIT_GIT_COMMAND_FAILED
        fi
    fi
    
    # Check if there are STAGED changes to commit
    if [[ -z $(git diff --cached --name-only) ]]; then
        warn "No staged changes to commit"
        return $EXIT_SUCCESS
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
        
        return $EXIT_SUCCESS
    else
        error "Failed to create commit"
        return $EXIT_GIT_COMMAND_FAILED
    fi
}

# Commit with statistics
# Usage: commit_with_stats "message" ["file_path"]
# CRITICAL: Implements golden rule - stages ALL changes first
# Note: Uses centralized MEMORY_FILE_PATH when no file specified
# TESTED: 2025-06-20 (commit category)
commit_with_stats() {
    local message="$1"
    local file_path="${2:-}"  # Optional - uses MEMORY_FILE_PATH if not specified
    local stats=""
    
    # Ensure memory is initialized
    if [[ "${MEMORY_INITIALIZED:-false}" != "true" ]]; then
        initialize_memory_context
    fi
    
    # If no file specified, use the configured memory file
    if [[ -z "$file_path" ]] && [[ -f "$MEMORY_FILE_PATH" ]]; then
        file_path="$MEMORY_FILE_PATH"
        
        # Get statistics for memory file
        local lines=$(wc -l < "$file_path" 2>/dev/null || printf "0")
        local size
        if [[ "$PLATFORM" == "macos" ]]; then
            size=$(stat -f%z "$file_path" 2>/dev/null || printf "0")
        else
            size=$(stat -c%s "$file_path" 2>/dev/null || printf "0")
        fi
        local formatted_size=$(format_size "$size" 2>/dev/null || printf "%d bytes" "$size")
        
        # Get entity and relation counts for memory files
        local entities=$(grep -c '"entityType"' "$file_path" 2>/dev/null || printf "0")
        local relations=$(grep -c '"relationType"' "$file_path" 2>/dev/null || printf "0")
        
        stats="Memory File: $file_path"$'\n'
        stats+="Lines: $lines"$'\n'
        stats+="Size: $formatted_size"$'\n'
        stats+="Entities: $entities"$'\n'
        stats+="Relations: $relations"
    elif [[ -f "$file_path" ]]; then
        # Single file statistics (non-memory file)
        local lines=$(wc -l < "$file_path" 2>/dev/null || printf "0")
        local size
        if [[ "$PLATFORM" == "macos" ]]; then
            size=$(stat -f%z "$file_path" 2>/dev/null || printf "0")
        else
            size=$(stat -c%s "$file_path" 2>/dev/null || printf "0")
        fi
        local formatted_size=$(format_size "$size" 2>/dev/null || printf "%d bytes" "$size")
        
        stats="File: $file_path"$'\n'
        stats+="Lines: $lines"$'\n'
        stats+="Size: $formatted_size"
    fi
    
    # Create commit with golden rule (auto_stage=true by default)
    create_commit "$message" "$stats"
}

# ============================================================================
# GOLDEN RULE FUNCTIONS - AIPM Core
# ============================================================================
# These functions implement the golden rule: "Do exactly what .gitignore says
# for the git repository you are tracking and everything else should be added"

# Add all untracked files that aren't gitignored
# Returns:
#   0 - Success
#   1 - Not in git repo
# Note: Critical for AIPM workflow - respects .gitignore strictly
# TESTED: 2025-06-20 (golden-rule category, comprehensive)
add_all_untracked() {
    check_git_repo || return $?
    
    # Get list of untracked files that aren't ignored
    local untracked_files=$(git ls-files -o --exclude-standard)
    
    if [[ -z "$untracked_files" ]]; then
        debug "No untracked files to add"
        return $EXIT_SUCCESS
    fi
    
    # Count files for progress
    local file_count=$(printf "%s\n" "$untracked_files" | wc -l | tr -d ' ')
    step "Adding $file_count untracked files (respecting .gitignore)"
    
    # Add each file
    printf "%s\n" "$untracked_files" | while IFS= read -r file; do
        if [[ -n "$file" ]]; then
            git add "$file" 2>/dev/null && debug "Added: $file"
        fi
    done
    
    success "Added all untracked files respecting .gitignore"
    return $EXIT_SUCCESS
}

# Ensure memory files are tracked
# Returns:
#   0 - Success
#   1 - Error
# Note: Uses centralized MEMORY_FILE_PATH for reliability
# TESTED: 2025-06-20 (golden-rule category)
ensure_memory_tracked() {
    # Ensure memory is initialized
    if [[ "${MEMORY_INITIALIZED:-false}" != "true" ]]; then
        initialize_memory_context
    fi
    
    # For AIPM framework, we track ALL project memory files
    if [[ "$AIPM_CONTEXT" == "framework" ]]; then
        # Get all memory files across all projects
        local memory_files=$(find_all_memory_files | sort -u)
        local tracked_count=0
        local added_count=0
        
        if [[ -n "$memory_files" ]]; then
            printf "%s\n" "$memory_files" | while IFS= read -r memory_file; do
                if [[ -n "$memory_file" ]] && [[ -f "$memory_file" ]]; then
                    if ! is_file_tracked "$memory_file"; then
                        if git add "$memory_file" 2>/dev/null; then
                            ((added_count++))
                            success "Memory file tracked: $memory_file"
                        fi
                    elif [[ -n $(git diff --name-only "$memory_file" 2>/dev/null) ]] || 
                         [[ -n $(git diff --cached --name-only "$memory_file" 2>/dev/null) ]]; then
                        if git add "$memory_file" 2>/dev/null; then
                            ((added_count++))
                            debug "Memory file updated: $memory_file"
                        fi
                    else
                        ((tracked_count++))
                    fi
                fi
            done
        fi
    else
        # For projects, focus on the configured memory file
        if [[ -f "$MEMORY_FILE_PATH" ]]; then
            if ! is_file_tracked "$MEMORY_FILE_PATH"; then
                step "Adding memory file: $MEMORY_FILE_PATH"
                if git add "$MEMORY_FILE_PATH" 2>/dev/null; then
                    success "Memory file tracked: $MEMORY_FILE_PATH"
                    return $EXIT_SUCCESS
                else
                    error "Failed to add memory file: $MEMORY_FILE_PATH"
                    return $EXIT_GIT_COMMAND_FAILED
                fi
            elif [[ -n $(git diff --name-only "$MEMORY_FILE_PATH" 2>/dev/null) ]] || 
                 [[ -n $(git diff --cached --name-only "$MEMORY_FILE_PATH" 2>/dev/null) ]]; then
                step "Updating memory file: $MEMORY_FILE_PATH"
                if git add "$MEMORY_FILE_PATH" 2>/dev/null; then
                    success "Memory file updated"
                    return $EXIT_SUCCESS
                else
                    error "Failed to update memory file: $MEMORY_FILE_PATH"
                    return $EXIT_GIT_COMMAND_FAILED
                fi
            else
                debug "Memory file already tracked and clean: $MEMORY_FILE_PATH"
                return $EXIT_SUCCESS
            fi
        else
            debug "Memory file not found: $MEMORY_FILE_PATH"
            return $EXIT_SUCCESS
        fi
    fi
    
    return $EXIT_SUCCESS
}

# Stage all changes (modified + untracked) respecting .gitignore
# Arguments:
#   $1 - include_memory (optional, default true)
# Returns:
#   0 - Success
#   1 - Not in git repo
# Note: Core function for AIPM save workflow
# TESTED: 2025-06-20 (golden-rule category, comprehensive)
stage_all_changes() {
    local include_memory="${1:-true}"
    
    check_git_repo || return $?
    
    section "Staging all changes"
    
    # Step 1: Add all modified tracked files
    step "Adding modified tracked files"
    local modified_count=$(git diff --name-only | wc -l | tr -d ' ')
    if [[ $modified_count -gt 0 ]]; then
        git add -u
        success "Updated $modified_count modified files"
    else
        info "No modified tracked files"
    fi
    
    # Step 2: Add all untracked files respecting .gitignore
    add_all_untracked
    
    # Step 3: Ensure memory files are tracked
    if [[ "$include_memory" == "true" ]]; then
        ensure_memory_tracked
    fi
    
    # Show summary
    local staged_count=$(git diff --cached --name-only | wc -l | tr -d ' ')
    if [[ $staged_count -gt 0 ]]; then
        success "Total files staged: $staged_count"
        return $EXIT_SUCCESS
    else
        info "No changes to stage"
        return $EXIT_SUCCESS
    fi
}

# Safe git add that respects .gitignore and handles symlinks
# Arguments:
#   $1 - path to add
# Returns:
#   0 - Success
#   1 - Path doesn't exist
#   2 - Path is gitignored
#   3 - Git add failed
# Note: Handles both symlinked and real paths
# TESTED: 2025-06-20 (golden-rule category)
safe_add() {
    local path="$1"
    
    # Check if path exists
    if [[ ! -e "$path" ]]; then
        error "Path does not exist: $path"
        return $EXIT_GENERAL_ERROR
    fi
    
    # Resolve symlinks for consistent handling
    local actual_path=$(readlink -f "$path" 2>/dev/null || printf "%s" "$path")
    debug "Actual path: $actual_path"
    
    # Check if it's ignored
    if git check-ignore "$path" 2>/dev/null; then
        warn "Path is gitignored: $path"
        info "Update .gitignore if this file should be tracked"
        return $EXIT_GIT_COMMAND_FAILED
    fi
    
    # Add the path
    if git add "$path" 2>/dev/null; then
        success "Added: $path"
        return $EXIT_SUCCESS
    else
        error "Failed to add: $path"
        return $EXIT_GIT_COMMAND_FAILED
    fi
}

# Find all memory files in the repository
# Returns: Array of memory file paths on stdout
# Note: Uses centralized MEMORY_FILE_PATH configuration
# TESTED: 2025-06-20
find_all_memory_files() {
    # Ensure memory is initialized
    if [[ "${MEMORY_INITIALIZED:-false}" != "true" ]]; then
        initialize_memory_context
    fi
    
    # In framework mode, only return the framework memory file
    if [[ "$AIPM_CONTEXT" == "framework" ]]; then
        if [[ -f "$MEMORY_FILE_PATH" ]]; then
            printf "%s\n" "$MEMORY_FILE_PATH"
        fi
        return $EXIT_SUCCESS
    fi
    
    # In project mode or when searching all
    # Use git ls-files to find all tracked memory files
    git ls-files "*/.memory/$MEMORY_FILE_NAME" 2>/dev/null || true
    
    # Also find untracked memory files that should be added
    git ls-files -o --exclude-standard "*/.memory/$MEMORY_FILE_NAME" 2>/dev/null || true
    
    # Always check the configured memory file
    if [[ -f "$MEMORY_FILE_PATH" ]] && \
       ! git ls-files "*/.memory/$MEMORY_FILE_NAME" 2>/dev/null | grep -q "^$MEMORY_FILE_PATH$"; then
        printf "%s\n" "$MEMORY_FILE_PATH"
    fi
}

# Check memory file status across branches
# Arguments:
#   $1 - branch to compare (optional, defaults to current)
# Returns:
#   0 - Memory files are in sync
#   1 - Memory files differ
#   2 - Memory files missing
# TESTED: 2025-06-20
# Test creates memory files and verifies status checking
check_memory_status() {
    local compare_branch="${1:-}"
    local status_ok=true
    
    section "Memory File Status"
    
    # Dynamically find all memory files
    local memory_files=$(find_all_memory_files | sort -u)
    
    if [[ -z "$memory_files" ]]; then
        warn "No memory files found in repository"
        return $EXIT_GENERAL_ERROR
    fi
    
    # Check each memory file
    printf "%s\n" "$memory_files" | while IFS= read -r memory_file; do
        if [[ -n "$memory_file" ]] && [[ -f "$memory_file" ]]; then
            # Check if tracked
            if ! is_file_tracked "$memory_file"; then
                warn "$memory_file: Not tracked in git"
                status_ok=false
                continue
            fi
            
            # Check for modifications
            if [[ -n $(git diff --name-only "$memory_file" 2>/dev/null) ]]; then
                warn "$memory_file: Has uncommitted changes"
                status_ok=false
            elif [[ -n $(git diff --cached --name-only "$memory_file" 2>/dev/null) ]]; then
                info "$memory_file: Staged for commit"
            else
                success "$memory_file: Clean"
            fi
            
            # Compare with branch if specified
            if [[ -n "$compare_branch" ]]; then
                if git diff "$compare_branch" --name-only | grep -q "$memory_file"; then
                    info "$memory_file: Differs from $compare_branch"
                fi
            fi
        fi
    done
    
    if [[ "$status_ok" == "true" ]]; then
        return $EXIT_SUCCESS
    else
        return $EXIT_GENERAL_ERROR
    fi
}

# ============================================================================
# BRANCH FUNCTIONS
# ============================================================================

# Create and checkout new branch
# TESTED: 2025-06-20 (branch category)
create_branch() {
    local branch_name="$1"
    local base_branch="${2:-$(get_default_branch)}"
    
    # Validate branch name
    if [[ ! "$branch_name" =~ ^[a-zA-Z0-9/_-]+$ ]]; then
        error "Invalid branch name: $branch_name"
        return $EXIT_GENERAL_ERROR
    fi
    
    # Check if branch already exists
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        error "Branch already exists: $branch_name"
        return $EXIT_GENERAL_ERROR
    fi
    
    info "Creating branch '$branch_name' from '$base_branch'"
    if git checkout -b "$branch_name" "$base_branch"; then
        success "Created and switched to branch: $branch_name"
    else
        error "Failed to create branch"
        return $EXIT_GENERAL_ERROR
    fi
}

# List branches with details
# TESTED: 2025-06-20 (branch category)
list_branches() {
    section "Local branches"
    git branch -vv | while read -r line; do
        if [[ "$line" =~ ^\* ]]; then
            # Current branch - highlight
            success "$line"
        else
            info "  $line"
        fi
    done
}

# ============================================================================
# MERGE FUNCTIONS
# ============================================================================

# Merge branch with checks
# TESTED: 2025-06-20 (integration test)
safe_merge() {
    local source_branch="$1"
    local target_branch="${2:-$(get_current_branch)}"
    
    # Check if source branch exists
    if ! git show-ref --verify --quiet "refs/heads/$source_branch"; then
        error "Source branch does not exist: $source_branch"
        return $EXIT_GENERAL_ERROR
    fi
    
    # Check for uncommitted changes
    if ! is_working_directory_clean; then
        error "Cannot merge with uncommitted changes"
        return $EXIT_GENERAL_ERROR
    fi
    
    info "Merging '$source_branch' into '$target_branch'"
    
    # Perform merge
    if git merge "$source_branch" --no-ff -m "Merge branch '$source_branch' into $target_branch"; then
        success "Merge completed successfully"
    else
        error "Merge failed - resolve conflicts and commit"
        return $EXIT_GENERAL_ERROR
    fi
}

# ============================================================================
# HISTORY FUNCTIONS
# ============================================================================

# Show pretty log
# LEARNING: Enhanced with graph view and better formatting
# Updated: 2025-06-20 for improved readability
# TESTED: 2025-06-20
# Test verifies function executes without errors
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
# TESTED: 2025-06-20
# Test verifies function executes without errors
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
# TESTED: 2025-06-20
# Test verifies function executes without errors
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
# TESTED: 2025-06-20
# Test verifies tag creation and verification
create_tag() {
    local tag_name="$1"
    local message="${2:-Release $tag_name}"
    
    # Validate tag name (semantic versioning)
    if [[ ! "$tag_name" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?$ ]]; then
        warn "Tag name doesn't follow semantic versioning: $tag_name"
        if ! confirm "Create anyway?"; then
            return $EXIT_GENERAL_ERROR
        fi
    fi
    
    info "Creating tag: $tag_name"
    if git tag -a "$tag_name" -m "$message"; then
        success "Tag created: $tag_name"
        info "Push with: git push origin $tag_name"
    else
        error "Failed to create tag"
        return $EXIT_GENERAL_ERROR
    fi
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Check if file is tracked by git
# TESTED: 2025-06-20
# Test verifies correct detection of tracked/untracked files
# TESTED: Indirectly in golden rule tests
is_file_tracked() {
    local file="$1"
    git ls-files --error-unmatch "$file" >/dev/null 2>&1
}

# Get repository root
# TESTED: 2025-06-20
# Test verifies correct repository root detection
get_repo_root() {
    git rev-parse --show-toplevel 2>/dev/null
}

# Clean up merged branches
# LEARNING: Enhanced with safety checks and batch mode
# Updated: 2025-06-20 for safer operation
# TESTED: 2025-06-20
# Test creates and merges branch, then verifies cleanup
cleanup_merged_branches() {
    local batch_mode="${1:-false}"
    local default_branch=$(get_default_branch)
    local current_branch=$(get_current_branch)
    
    # Ensure we're on default branch
    if [[ "$current_branch" != "$default_branch" ]]; then
        step "Switching to $default_branch for cleanup"
        if ! git checkout "$default_branch" 2>/dev/null; then
            error "Failed to switch to $default_branch"
            return $EXIT_GENERAL_ERROR
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
        return $EXIT_SUCCESS
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
# Supports: --sync-team flag for team memory synchronization
# TESTED: 2025-06-20
# Test verifies push with local file:// remote
push_changes() {
    local force="${1:-false}"
    local sync_team="${2:-false}"
    local branch=$(get_current_branch)
    
    # Check if upstream is set
    local upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || printf "")
    
    # Handle --sync-team flag
    if [[ "$sync_team" == "true" ]]; then
        step "Preparing team synchronization"
        
        # Ensure memory is initialized
        if [[ "${MEMORY_INITIALIZED:-false}" != "true" ]]; then
            initialize_memory_context
        fi
        
        # Ensure memory files are staged
        ensure_memory_tracked
        
        # Check if we have memory changes
        if git diff --cached --name-only | grep -q "$MEMORY_FILE_NAME"; then
            info "Memory files will be synchronized with team"
        else
            debug "No memory changes to synchronize"
        fi
    fi
    
    if [[ -z "$upstream" ]]; then
        warn "No upstream branch set for '$branch'"
        if confirm "Set upstream to 'origin/$branch' and push?"; then
            step "Setting upstream and pushing"
            if git push --set-upstream origin "$branch"; then
                success "Pushed and set upstream successfully"
                [[ "$sync_team" == "true" ]] && success "Team memory synchronized"
            else
                error "Failed to push changes"
                return $EXIT_NETWORK_ERROR
            fi
        else
            info "Push cancelled"
            return $EXIT_GENERAL_ERROR
        fi
    else
        # Normal push
        step "Pushing to $upstream"
        local push_args=()
        [[ "$force" == "true" ]] && push_args+=(--force-with-lease)
        
        if git push "${push_args[@]}"; then
            success "Changes pushed successfully"
            [[ "$sync_team" == "true" ]] && success "Team memory synchronized"
            
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
            
            return $EXIT_NETWORK_ERROR
        fi
    fi
}

# Create a backup branch before dangerous operations
# LEARNING: Safety first - always have a backup
# Added: 2025-06-20 for safer operations
# TESTED: 2025-06-20 (advanced category)
create_backup_branch() {
    local operation="${1:-backup}"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_name="backup/${operation}-$timestamp"
    
    step "Creating backup branch: $backup_name"
    
    if git branch "$backup_name" 2>/dev/null; then
        success "Backup branch created: $backup_name"
        info "Restore with: git checkout $backup_name"
        return $EXIT_SUCCESS
    else
        error "Failed to create backup branch"
        return $EXIT_GENERAL_ERROR
    fi
}

# Undo last commit (with safety)
# LEARNING: Provide safe undo with backup
# Added: 2025-06-20 for easier error recovery
# TESTED: 2025-06-20 (advanced category)
undo_last_commit() {
    local keep_changes="${1:-true}"
    
    # Check if there are commits to undo
    if ! git rev-parse HEAD~1 >/dev/null 2>&1; then
        error "No commits to undo (at initial commit)"
        return $EXIT_GENERAL_ERROR
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
# TESTED: 2025-06-20 (conflicts category)
# TESTED: 2025-06-20 (both scenarios)
# TESTED: 2025-06-20
check_conflicts() {
    local conflict_files=$(git diff --name-only --diff-filter=U)
    
    if [[ -n "$conflict_files" ]]; then
        error "Merge conflicts detected in:"
        printf "%s\n" "$conflict_files" | while IFS= read -r file; do
            printf "  %b%s%b\n" "$RED" "$file" "$NC"
        done
        return $EXIT_GENERAL_ERROR
    else
        success "No merge conflicts"
        return $EXIT_SUCCESS
    fi
}

# Interactive conflict resolution
# Added: 2025-06-20 for guided conflict resolution
# TESTED: 2025-06-20 (components and full interactive)
# Test simulates user input for all resolution strategies
# Verifies: ours/theirs/manual options, multi-file handling
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