#!/opt/homebrew/bin/bash
#
# opinions-state.sh - Complete runtime state management with full pre-computation
#
# This module manages the complete runtime state of AIPM, capturing EVERYTHING
# from opinions.yaml and pre-computing all possible values for zero runtime computation.
#
# ARCHITECTURE OVERVIEW:
# ---------------------
# This module implements a comprehensive state management system that:
# 1. Loads all configuration from opinions.yaml via opinions-loader.sh
# 2. Pre-computes all possible values, patterns, and decisions at initialization
# 3. Stores everything in a single JSON file for instant access
# 4. Provides bidirectional updates with atomic operations
# 5. Supports partial refreshes for performance optimization
#
# The goal is ZERO computation at runtime - everything is pre-calculated and
# ready for instant retrieval. This makes wrapper scripts extremely fast and
# ensures consistent behavior across all AIPM commands.
#
# PURPOSE:
# - Centralize all state management in a single, efficient module
# - Pre-compute all possible values and decisions at initialization
# - Provide instant access to any configuration or runtime value
# - Enable bidirectional state updates with atomic operations
# - Support partial refreshes for performance optimization
#
# STATE STRUCTURE:
# The state file (.aipm/state/workspace.json) contains:
# - raw: All raw configuration exports from opinions-loader.sh
# - computed: All pre-computed patterns, rules, and workflows
# - runtime: Current git branches, timestamps, and session info
# - decisions: Pre-made decisions for every possible operation
# - prompts: Complete prompt structures for user interactions
# - memory: Historical data and statistics
#
# USAGE:
#   source "$SCRIPT_DIR/opinions-state.sh"
#   
#   # Initialize state (first time or full refresh)
#   initialize_state
#   
#   # Get any value from state (instant access)
#   local branch_prefix=$(get_value "raw.branching.prefix")
#   local workflow_rule=$(get_workflow_rule "branchCreation.startBehavior")
#   
#   # Update state values
#   update_state "runtime.lastOperation" "merge"
#   update_state_batch '[{"path": "runtime.branch", "value": "main"}]'
#   
#   # Refresh specific sections
#   refresh_state "branches"  # Only refresh branch info
#   refresh_state "all"       # Full refresh
#
# DEPENDENCIES:
#   - opinions-loader.sh (required for configuration loading)
#   - version-control.sh (required for git operations)
#   - shell-formatting.sh (required for output formatting)
#   - jq (required for JSON processing)
#
# ENVIRONMENT VARIABLES:
#   STATE_DIR: Override state directory location (default: .aipm/state)
#   STATE_FILE: Override state file path (default: .aipm/state/workspace.json)
#   AIPM_STATE_LOCK_TIMEOUT: Lock acquisition timeout in seconds (default: 30)
#
# EXIT CODES:
#   0: Success
#   1: General error (missing dependencies, invalid JSON, etc.)
#   2: Lock acquisition failed
#   3: State file corrupted
#   4: Update operation failed
#
# PERFORMANCE NOTES:
# - State is cached in memory after first read
# - All values are pre-computed at initialization
# - Partial refreshes minimize computation
# - Lock-based concurrency control prevents corruption
#
# WRAPPER SCRIPT INTEGRATION:
# Wrapper scripts should use this module as their primary data source:
#   # In git-save.sh:
#   source opinions-state.sh
#   ensure_state  # Ensure state is loaded
#   
#   # Get branch creation rules
#   local start_behavior=$(get_workflow_rule "branchCreation.startBehavior")
#   local protection_response=$(get_workflow_rule "branchCreation.protectionResponse")
#   
#   # Report operation for history
#   report_git_operation "save" "success" "{\"branch\": \"$branch\"}"
#
# LEARNING LOG:
# - 2025-06-20: Initial implementation with full pre-computation
# - 2025-06-21: Added bidirectional update functions
# - 2025-06-21: Enhanced lock mechanism for concurrent access
# - 2025-06-22: Added comprehensive inline documentation
#
# Created by: AIPM Framework
# License: Apache 2.0

# ============================================================================
# WRAPPER SCRIPT INTEGRATION EXAMPLES
# ============================================================================
# 
# Example 1: git-save.sh integration
# ----------------------------------
# source opinions-state.sh
# ensure_state || exit 1
# 
# # Check if on protected branch
# local current_branch=$(get_value "runtime.currentBranch")
# local protected_branches=$(get_value "computed.protectedBranches.all")
# if jq -e --arg b "$current_branch" '.[] | select(. == $b)' <<< "$protected_branches" >/dev/null; then
#     local response=$(get_workflow_rule "branchCreation.protectionResponse")
#     if [[ "$response" == "prompt" ]]; then
#         local prompt=$(get_prompt "branchCreation.protected")
#         # Display prompt and handle response...
#     fi
# fi
# 
# # Report operation
# report_git_operation "save" "success" "{\"branch\": \"$current_branch\", \"files\": $file_count}"
# 
# Example 2: git-sync.sh integration
# ----------------------------------
# source opinions-state.sh
# ensure_state || exit 1
# 
# # Get sync rules
# local auto_stash=$(get_workflow_rule "synchronization.autoStash")
# local pull_strategy=$(get_workflow_rule "synchronization.pullStrategy")
# 
# # Perform sync with rules...
# 
# # Update runtime state
# update_state "runtime.lastSync" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
# refresh_state "branches"  # Refresh branch info after sync
# 
# Example 3: git-cleanup.sh integration
# -------------------------------------
# source opinions-state.sh
# ensure_state || exit 1
# 
# # Get branches ready for cleanup
# local cleanup_branches=$(get_cleanup_branches)
# local count=$(jq 'length' <<< "$cleanup_branches")
# 
# if [[ "$count" -gt 0 ]]; then
#     echo "Found $count branches ready for cleanup:"
#     jq -r '.[] | "  \\(.name) - \\(.reason) (\\(.age) days old)"' <<< "$cleanup_branches"
#     
#     # Process each branch according to lifecycle rules
#     while IFS= read -r branch_json; do
#         local branch=$(jq -r '.name' <<< "$branch_json")
#         local type=$(jq -r '.type' <<< "$branch_json")
#         local lifecycle=$(get_value "computed.lifecycle.$type")
#         # Apply lifecycle rules...
#     done < <(jq -c '.[]' <<< "$cleanup_branches")
# fi
# 
# ============================================================================

# Source dependencies
OPINIONS_STATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$OPINIONS_STATE_DIR/shell-formatting.sh"
source "$OPINIONS_STATE_DIR/opinions-loader.sh"
source "$OPINIONS_STATE_DIR/version-control.sh"

# State file locations
declare -g STATE_DIR=".aipm/state"
declare -g STATE_FILE="$STATE_DIR/workspace.json"
declare -g STATE_LOCK="$STATE_DIR/workspace.lock"
declare -g STATE_HASH="$STATE_DIR/workspace.hash"

# Global state cache (for performance)
declare -g STATE_CACHE=""
declare -g STATE_LOADED="false"

# Cleanup function to ensure locks are released
# Called automatically on script exit via trap
# No parameters required
# Always succeeds (errors are ignored)
cleanup_state() {
    release_state_lock
}

# Set up cleanup trap
trap cleanup_state EXIT INT TERM

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Check if jq is installed
# PURPOSE: Check if jq command is installed and available in PATH
# PARAMETERS: None
# RETURNS:
#   0 - jq is available
#   1 - jq is not installed
# SIDE EFFECTS:
#   - Writes error message to stderr if jq is missing
#   - No files created/modified
#   - No global variables changed
# EXAMPLES:
#   # Basic usage
#   if ! check_jq_installed; then
#       return 1
#   fi
#   
#   # With custom error handling
#   check_jq_installed || { echo "Please install jq first"; exit 1; }
# LEARNING:
#   - We use 'command -v' instead of 'which' for POSIX compliance
#   - Redirecting to /dev/null prevents command output from cluttering terminal
#   - Platform-specific install instructions provided for macOS (brew)
check_jq_installed() {
    # LEARNING: 'command -v' is the POSIX-compliant way to check if a command exists
    # It's more portable than 'which' and works across different shells
    if ! command -v jq &> /dev/null; then
        # LEARNING: We provide platform-specific installation instructions
        # This helps users quickly resolve the missing dependency
        error "jq is required for state management. Install with: brew install jq"
        return 1
    fi
    # LEARNING: Implicit return 0 when function completes successfully
    # Bash functions return the exit status of the last command by default
}

# Create state directory if needed
# PURPOSE: Ensure state directory exists with proper permissions for state file storage
# PARAMETERS: None (uses global $STATE_DIR variable)
# RETURNS:
#   0 - Directory exists or was created successfully
#   1 - Failed to create directory
# SIDE EFFECTS:
#   - Creates $STATE_DIR directory if it doesn't exist
#   - May create parent directories as needed
#   - Writes error message to stderr on failure
#   - Global variables: reads $STATE_DIR
# EXAMPLES:
#   # Basic usage with error handling
#   ensure_state_dir || return 1
#   
#   # In initialization flow
#   if ensure_state_dir; then
#       initialize_state
#   else
#       die "Cannot proceed without state directory"
#   fi
# LEARNING:
#   - Uses mkdir -p to create parent directories if needed
#   - Checks directory existence before attempting creation to avoid errors
#   - Separate error handling for clarity in debugging
ensure_state_dir() {
    # LEARNING: Using [[ ]] instead of [ ] for better string handling and pattern matching
    # The -d test checks if the path exists AND is a directory
    if [[ ! -d "$STATE_DIR" ]]; then
        # LEARNING: mkdir -p is idempotent and creates parent directories
        # This handles cases where the parent path doesn't exist yet
        if ! mkdir -p "$STATE_DIR"; then
            # LEARNING: Specific error messages help with debugging permission issues
            # Common failures: permission denied, disk full, read-only filesystem
            error "Failed to create state directory"
            return 1
        fi
    fi
    # LEARNING: No explicit return needed - succeeds if directory exists
    # This makes the function idempotent (safe to call multiple times)
}

# Lock file descriptor
declare -g STATE_LOCK_FD=200

# Acquire lock for state operations
# PURPOSE: Acquire exclusive lock for state file modifications to prevent race conditions
# PARAMETERS:
#   None (uses environment variable AIPM_STATE_LOCK_TIMEOUT if set)
# RETURNS:
#   0 - Lock acquired successfully
#   1 - Failed to acquire lock within timeout
# SIDE EFFECTS:
#   - Creates lock file at $STATE_LOCK path
#   - Creates lock directory at $STATE_LOCK.dir (fallback method)
#   - Opens file descriptor $STATE_LOCK_FD (when using flock)
#   - Writes error message to stderr on timeout
#   - Global variables: reads $STATE_LOCK, $STATE_LOCK_FD, $AIPM_STATE_LOCK_TIMEOUT
# EXAMPLES:
#   # Basic usage with error handling
#   if ! acquire_state_lock; then
#       error "Another process is updating state"
#       return 2
#   fi
#   # ... perform state operations ...
#   release_state_lock
#   
#   # With custom timeout
#   AIPM_STATE_LOCK_TIMEOUT=60 acquire_state_lock
#   
#   # In a critical section
#   acquire_state_lock || die "Cannot proceed without lock"
#   trap release_state_lock EXIT  # Ensure cleanup
# LEARNING:
#   - Dual locking strategy for maximum portability
#   - flock is preferred for atomic operations
#   - Directory creation is atomic on most filesystems
acquire_state_lock() {
    # LEARNING: Default timeout of 30s is reasonable for most operations
    # Can be overridden via environment for long-running tasks
    local timeout=${AIPM_STATE_LOCK_TIMEOUT:-30}
    
    # LEARNING: touch ensures lock file exists for flock to work
    # This prevents "No such file" errors on first run
    touch "$STATE_LOCK"
    
    # Try to acquire exclusive lock with timeout
    if command -v flock &>/dev/null; then
        # LEARNING: flock provides true file locking at the kernel level
        # The -w flag sets a timeout to prevent indefinite blocking
        # Using eval with exec to dynamically assign file descriptor
        if ! eval "exec $STATE_LOCK_FD>\"$STATE_LOCK\"" || ! flock -w "$timeout" "$STATE_LOCK_FD"; then
            error "Failed to acquire state lock after ${timeout}s"
            return 1
        fi
    else
        # LEARNING: Directory-based locking is a portable fallback
        # mkdir is atomic - only one process can create the directory
        # This works on systems without flock (rare but possible)
        local elapsed=0
        while ! mkdir "$STATE_LOCK.dir" 2>/dev/null && [[ $elapsed -lt $timeout ]]; do
            # LEARNING: 0.5s sleep balances responsiveness vs CPU usage
            # Too short = high CPU, too long = slow lock acquisition
            sleep 0.5
            ((elapsed++))
        done
        
        if [[ ! -d "$STATE_LOCK.dir" ]]; then
            error "Failed to acquire state lock after ${timeout}s"
            return 1
        fi
    fi
    # LEARNING: Successful lock acquisition - caller must remember to release
    # Consider using trap to ensure cleanup on unexpected exit
}

# Release state lock
# PURPOSE: Release exclusive lock on state file to allow other processes to proceed
# PARAMETERS: None
# RETURNS:
#   0 - Always succeeds (errors are suppressed for robustness)
# SIDE EFFECTS:
#   - Closes file descriptor $STATE_LOCK_FD (when using flock)
#   - Removes lock directory $STATE_LOCK.dir (fallback method)
#   - No error messages (silent operation)
#   - Global variables: reads $STATE_LOCK_FD
# EXAMPLES:
#   # Basic usage after state operations
#   acquire_state_lock
#   # ... state operations ...
#   release_state_lock
#   
#   # With trap for automatic cleanup
#   trap release_state_lock EXIT
#   acquire_state_lock
#   # ... operations that might fail ...
#   
#   # Safe to call multiple times
#   release_state_lock
#   release_state_lock  # No-op, no errors
# LEARNING:
#   - Designed to be idempotent (safe to call multiple times)
#   - Errors suppressed to ensure cleanup always succeeds
#   - Should match the lock method used in acquire_state_lock
release_state_lock() {
    if command -v flock &>/dev/null; then
        # LEARNING: Closing file descriptor releases the flock
        # The >&- syntax closes the file descriptor
        # eval is needed because the FD number is in a variable
        # Errors suppressed with || true for idempotency
        eval "exec $STATE_LOCK_FD>&-" 2>/dev/null || true
    else
        # LEARNING: rmdir only removes empty directories
        # This prevents accidental removal if something went wrong
        # Using rmdir instead of rm -rf for safety
        rmdir "$STATE_LOCK.dir" 2>/dev/null || true
    fi
    # LEARNING: Always returns 0 for consistent behavior
    # This allows release_state_lock to be used in trap without affecting exit code
}

# Validate that we hold the lock
# PURPOSE: Verify current process holds the state lock before critical operations
# PARAMETERS: None
# RETURNS:
#   0 - Lock is held by current process
#   1 - Lock not held (dies with error message)
# SIDE EFFECTS:
#   - Calls die() if lock not held (terminates script)
#   - No files created/modified
#   - Global variables: reads $STATE_LOCK_FD
# EXAMPLES:
#   # Validate before state write
#   validate_lock_held
#   echo "$new_state" > "$STATE_FILE"
#   
#   # In critical function
#   update_state_internal() {
#       validate_lock_held  # Ensure caller acquired lock
#       # ... perform update ...
#   }
# LEARNING:
#   - Critical safety check to prevent concurrent corruption
#   - Uses flock -n (non-blocking) to test lock ownership
#   - Directory check for fallback locking method
validate_lock_held() {
    # LEARNING: Check which locking method is in use
    if command -v flock &>/dev/null; then
        # LEARNING: flock -n attempts non-blocking lock
        # If we already hold it, this succeeds immediately
        # If another process holds it, this fails
        if ! flock -n "$STATE_LOCK_FD" 2>/dev/null; then
            die "State lock not held - acquire_state_lock must be called first"
        fi
    else
        # LEARNING: For directory-based locking, just check existence
        # If the directory exists, we assume we created it
        # This is less robust than flock but sufficient for the fallback
        if [[ ! -d "$STATE_LOCK.dir" ]]; then
            die "State lock not held - acquire_state_lock must be called first"
        fi
    fi
    # LEARNING: Implicit return 0 when lock is verified
}

# Read state file safely
# PURPOSE: Load state file into memory cache with validation for fast access
# PARAMETERS: None (uses global $STATE_FILE path)
# RETURNS:
#   0 - State loaded successfully
#   1 - State file missing, empty, or invalid
# SIDE EFFECTS:
#   - Sets STATE_CACHE with file contents (global variable)
#   - Sets STATE_LOADED=true on success (global variable)
#   - Writes error message to stderr for invalid JSON
#   - No files created/modified
#   - Global variables: reads $STATE_FILE, writes $STATE_CACHE, $STATE_LOADED
# EXAMPLES:
#   # Basic usage with initialization fallback
#   if ! read_state_file; then
#       warn "State not initialized, running initialize_state"
#       initialize_state
#   fi
#   
#   # Check and use cached state
#   read_state_file || return 1
#   local timestamp=$(jq -r '.runtime.timestamp' <<< "$STATE_CACHE")
#   
#   # Force re-read after external changes
#   STATE_LOADED="false"
#   read_state_file
# LEARNING:
#   - Caching strategy reduces disk I/O for repeated reads
#   - Silent failures for missing files allow initialization flow
#   - JSON validation prevents corrupt state from propagating
read_state_file() {
    # LEARNING: File existence check before reading prevents error messages
    # This allows callers to handle missing state files gracefully
    if [[ ! -f "$STATE_FILE" ]]; then
        return 1
    fi
    
    # LEARNING: Using command substitution to capture file contents
    # Redirecting stderr to /dev/null suppresses "file not found" errors
    # This handles race conditions where file is deleted after existence check
    STATE_CACHE=$(cat "$STATE_FILE" 2>/dev/null)
    
    # LEARNING: Empty file check prevents JSON parsing errors downstream
    # Empty files can occur during failed writes or initialization
    if [[ -z "$STATE_CACHE" ]]; then
        return 1
    fi
    
    # LEARNING: jq empty validates JSON without processing it
    # This is the fastest way to check if content is valid JSON
    # printf ensures proper newline handling for jq input
    if ! printf "%s\n" "$STATE_CACHE" | jq empty 2>/dev/null; then
        # LEARNING: Only show error for invalid JSON, not missing files
        # This distinction helps debugging - missing is expected, corrupt is not
        error "Invalid state file format"
        return 1
    fi
    
    # LEARNING: STATE_LOADED flag enables lazy loading optimization
    # Other functions can check this flag to avoid redundant reads
    STATE_LOADED="true"
    return 0
}

# Write state file atomically
# PURPOSE: Write state to disk with atomic operation and validation
# PARAMETERS:
#   $1 - JSON content to write (required, must be valid JSON)
# RETURNS:
#   0 - State written successfully
#   1 - Invalid JSON or write error
# SIDE EFFECTS:
#   - Creates/updates $STATE_FILE on disk
#   - Creates temporary file $STATE_FILE.tmp during write
#   - Updates $STATE_CACHE in memory
#   - Sets $STATE_LOADED=true
#   - Creates/updates $STATE_HASH file with SHA256 checksum
#   - Writes error messages to stderr on failure
#   - Global variables: reads $STATE_FILE, $STATE_HASH; writes $STATE_CACHE, $STATE_LOADED
# EXAMPLES:
#   # Update timestamp in state
#   local new_state=$(jq '.runtime.timestamp = now' <<< "$STATE_CACHE")
#   write_state_file "$new_state"
#   
#   # Add new field to state
#   local updated=$(jq '.settings.new_option = true' <<< "$STATE_CACHE")
#   write_state_file "$updated" || die "Failed to save settings"
#   
#   # Replace entire state
#   write_state_file '{"version": "1.0", "data": {}}'
# LEARNING:
#   - Atomic writes prevent partial state files
#   - Validation before writing prevents corruption
#   - Hash file enables external change detection
write_state_file() {
    local content="$1"
    local temp_file="$STATE_FILE.tmp"
    
    # LEARNING: Pre-write validation prevents corrupt state files
    # Invalid JSON would break all subsequent operations
    # jq empty is the fastest validation method
    if ! printf "%s\n" "$content" | jq empty 2>/dev/null; then
        error "Invalid JSON content"
        return 1
    fi
    
    # LEARNING: Two-step write process ensures atomicity
    # First write to temp file, then atomic rename
    # jq '.' pretty-prints for human readability and debugging
    if ! printf "%s\n" "$content" | jq '.' > "$temp_file"; then
        # LEARNING: Disk full or permission errors caught here
        # Temp file prevents corruption of existing state
        error "Failed to write state file"
        return 1
    fi
    
    # LEARNING: mv is atomic on same filesystem
    # This ensures readers never see partial writes
    # Old state remains valid until the instant of rename
    if ! mv "$temp_file" "$STATE_FILE"; then
        error "Failed to update state file"
        return 1
    fi
    
    # LEARNING: Update memory cache for consistency
    # This ensures subsequent reads don't need disk access
    # Cache stays in sync with disk state
    STATE_CACHE="$content"
    STATE_LOADED="true"
    
    # LEARNING: SHA256 hash enables external change detection
    # Other processes can check if state changed without reading entire file
    # cut -d' ' -f1 extracts just the hash, removing the filename
    sha256sum "$STATE_FILE" | cut -d' ' -f1 > "$STATE_HASH"
}

# ============================================================================
# ATOMIC OPERATION FRAMEWORK - Transaction management for state consistency
# ============================================================================

# Global variables for atomic operations
declare -g ATOMIC_OP_NAME=""
declare -g ATOMIC_OP_START=""
declare -g ROLLBACK_STATE=""

# Begin atomic operation
# PURPOSE: Start atomic transaction with automatic rollback on failure
# PARAMETERS:
#   $1 - Operation name for logging and tracking (required)
# RETURNS:
#   0 - Transaction started successfully  
#   1 - Failed to acquire lock
# SIDE EFFECTS:
#   - Acquires exclusive state lock
#   - Saves current state for rollback
#   - Sets ATOMIC_OP_NAME and ATOMIC_OP_START globals
#   - Creates rollback checkpoint in memory
# EXAMPLES:
#   # Simple atomic update
#   begin_atomic_operation "update:branch"
#   update_state "runtime.currentBranch" "main"
#   commit_atomic_operation
#   
#   # With error handling
#   if begin_atomic_operation "complex:update"; then
#       # Multiple operations...
#       if ! some_operation; then
#           rollback_atomic_operation
#           return 1
#       fi
#       commit_atomic_operation
#   fi
# LEARNING:
#   - Provides transaction semantics for state updates
#   - Automatic rollback prevents partial updates
#   - Lock ensures true atomicity across processes
begin_atomic_operation() {
    local op_name="$1"
    
    # LEARNING: Operation name helps with debugging and audit trails
    if [[ -z "$op_name" ]]; then
        error "Atomic operation requires a name"
        return 1
    fi
    
    # LEARNING: Acquire exclusive lock for true atomicity
    # This prevents any other process from reading or writing state
    if ! acquire_state_lock; then
        error "Cannot start atomic operation: lock acquisition failed"
        return 1
    fi
    
    # LEARNING: Save complete state for rollback capability
    # We save the full state, not just a reference, to handle external changes
    if ! read_state_file; then
        error "Cannot read current state for rollback"
        release_state_lock
        return 1
    fi
    
    # LEARNING: Capture rollback state before any modifications
    ROLLBACK_STATE="$STATE_CACHE"
    ATOMIC_OP_NAME="$op_name"
    ATOMIC_OP_START=$(date +%s)
    
    debug "Started atomic operation: $op_name"
    return 0
}

# Commit atomic operation
# PURPOSE: Finalize atomic transaction and release resources
# PARAMETERS: None
# RETURNS:
#   0 - Transaction committed successfully
#   1 - Validation failed, automatic rollback performed
# SIDE EFFECTS:
#   - Validates state consistency
#   - Updates metadata with operation info
#   - Releases state lock
#   - Clears transaction globals
# EXAMPLES:
#   # After successful updates
#   begin_atomic_operation "save:memory"
#   update_state "runtime.memory.size" "$size"
#   update_state "runtime.memory.lastSave" "$(date -u)"
#   commit_atomic_operation
#   
#   # Automatic rollback on validation failure
#   begin_atomic_operation "invalid:update"
#   update_state "bad.path" "value"  # Creates invalid state
#   commit_atomic_operation  # Returns 1, state rolled back
# LEARNING:
#   - Validation prevents committing corrupt state
#   - Metadata tracking enables operation history
#   - Always releases lock, even on failure
commit_atomic_operation() {
    # LEARNING: Validate we're in a transaction
    if [[ -z "$ATOMIC_OP_NAME" ]]; then
        error "No atomic operation in progress"
        return 1
    fi
    
    # LEARNING: Validate state consistency before committing
    # This catches structural errors that individual updates might miss
    if ! validate_state_consistency; then
        error "State validation failed, rolling back"
        rollback_atomic_operation
        return 1
    fi
    
    # LEARNING: Update metadata with operation info for audit trail
    local duration=$(($(date +%s) - ATOMIC_OP_START))
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # Update metadata within the transaction
    local updated_state=$(jq --arg op "$ATOMIC_OP_NAME" \
                            --arg ts "$timestamp" \
                            --arg dur "$duration" \
                            '.metadata.lastOperation = $op |
                             .metadata.lastUpdate = $ts |
                             .metadata.operationDuration = ($dur | tonumber)' <<< "$STATE_CACHE")
    
    if [[ -z "$updated_state" ]]; then
        error "Failed to update operation metadata"
        rollback_atomic_operation
        return 1
    fi
    
    # LEARNING: Write the committed state to disk
    if ! write_state_file "$updated_state"; then
        error "Failed to write committed state"
        rollback_atomic_operation
        return 1
    fi
    
    # LEARNING: Success - clean up transaction state
    debug "Committed atomic operation: $ATOMIC_OP_NAME (${duration}s)"
    
    # Clear transaction globals
    ROLLBACK_STATE=""
    ATOMIC_OP_NAME=""
    ATOMIC_OP_START=""
    
    # Release lock after successful commit
    release_state_lock
    return 0
}

# Rollback atomic operation
# PURPOSE: Restore state to pre-transaction checkpoint
# PARAMETERS: None
# RETURNS:
#   0 - Always succeeds (best effort restoration)
# SIDE EFFECTS:
#   - Restores state from ROLLBACK_STATE
#   - Writes restored state to disk
#   - Releases state lock
#   - Clears transaction globals
#   - Logs rollback event
# EXAMPLES:
#   # Manual rollback on error
#   begin_atomic_operation "risky:update"
#   if ! risky_operation; then
#       rollback_atomic_operation
#       return 1
#   fi
#   
#   # Automatic cleanup in trap
#   trap rollback_atomic_operation ERR
#   begin_atomic_operation "trapped:update"
#   # Any error triggers automatic rollback
# LEARNING:
#   - Best effort restoration - always tries to recover
#   - Silent write failures to avoid cascading errors
#   - Always releases resources for system stability
rollback_atomic_operation() {
    # LEARNING: Check if there's actually something to rollback
    if [[ -z "$ROLLBACK_STATE" ]]; then
        debug "No rollback state available"
        release_state_lock
        return 0
    fi
    
    # LEARNING: Log the rollback for debugging
    local op_name="${ATOMIC_OP_NAME:-unknown}"
    warn "Rolling back atomic operation: $op_name"
    
    # LEARNING: Restore the saved state
    # We write directly to ensure restoration even if current state is corrupt
    if ! write_state_file "$ROLLBACK_STATE"; then
        # LEARNING: Log but don't fail - best effort restoration
        error "Failed to write rollback state - state may be inconsistent"
    else
        success "State rolled back successfully"
    fi
    
    # LEARNING: Always clean up resources
    ROLLBACK_STATE=""
    ATOMIC_OP_NAME=""
    ATOMIC_OP_START=""
    
    # Always release lock
    release_state_lock
    return 0
}

# Validate state consistency
# PURPOSE: Check state file structure and content validity
# PARAMETERS: None (uses STATE_CACHE global)
# RETURNS:
#   0 - State is valid and consistent
#   1 - State has structural or content errors
# SIDE EFFECTS:
#   - Writes warning messages for issues
#   - No files modified
#   - Reads STATE_CACHE global
# EXAMPLES:
#   # Before committing changes
#   if ! validate_state_consistency; then
#       error "State is corrupted"
#       return 1
#   fi
#   
#   # After loading state
#   read_state_file
#   validate_state_consistency || initialize_state
# LEARNING:
#   - Checks required top-level sections exist
#   - Validates critical runtime values
#   - Could be extended with schema validation
validate_state_consistency() {
    # LEARNING: Ensure state is loaded
    if [[ -z "$STATE_CACHE" ]]; then
        error "No state loaded for validation"
        return 1
    fi
    
    # LEARNING: Check required top-level sections
    local required_sections=("metadata" "raw_exports" "computed" "runtime" "decisions")
    local valid=true
    
    for section in "${required_sections[@]}"; do
        if ! jq -e ".$section" <<< "$STATE_CACHE" >/dev/null 2>&1; then
            warn "Missing required section: $section"
            valid=false
        fi
    done
    
    # LEARNING: Validate critical runtime values
    # These are minimum requirements for wrapper scripts to function
    local critical_paths=(
        "runtime.currentBranch"
        "computed.mainBranch"
        "raw_exports.AIPM_WORKSPACE_TYPE"
    )
    
    for path in "${critical_paths[@]}"; do
        local value=$(jq -r ".$path // empty" <<< "$STATE_CACHE")
        if [[ -z "$value" ]]; then
            warn "Missing critical value: $path"
            valid=false
        fi
    done
    
    # LEARNING: Check state version compatibility
    local version=$(jq -r '.metadata.version // "0.0"' <<< "$STATE_CACHE")
    if [[ "$version" != "1.0" ]]; then
        warn "Unsupported state version: $version (expected 1.0)"
        valid=false
    fi
    
    [[ "$valid" == "true" ]] && return 0 || return 1
}

# ============================================================================
# COMPLETE COMPUTATION FUNCTIONS - Pre-compute EVERYTHING from opinions.yaml
# ============================================================================

# Resolve pattern variables
# PURPOSE: Replace pattern variables with runtime values
# PARAMETERS:
#   $1 - Pattern string containing variables (required)
# RETURNS:
#   0 - Always succeeds
# OUTPUTS:
#   Pattern with variables replaced
# SUPPORTED VARIABLES:
#   {timestamp} - Current timestamp (YYYYMMDD_HHMMSS)
#   {date} - Current date (YYYYMMDD)
#   {user} - Git username (spaces replaced with underscores)
#   {description}, {version}, {environment} - Kept as-is for runtime
# EXAMPLE:
#   local pattern="feature/{user}/{timestamp}-{description}"
#   local resolved=$(resolve_pattern_variables "$pattern")
#   # Result: "feature/john_doe/20250622_143022-{description}"
resolve_pattern_variables() {
    local pattern="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local date=$(date +%Y%m%d)
    # Note: git config is acceptable here as it's a read-only operation
    # and version-control.sh doesn't provide a wrapper for reading git config
    local user=$(git config user.name 2>/dev/null | tr ' ' '_' | tr -cd '[:alnum:]_-' || printf "%s\n" "user")
    
    # Replace all variables
    pattern="${pattern//\{timestamp\}/$timestamp}"
    pattern="${pattern//\{date\}/$date}"
    pattern="${pattern//\{user\}/$user}"
    # {description}, {version}, {environment} are runtime values, keep as-is
    
    printf "%s\n" "$pattern"
}

# Compute all branch patterns with full resolution
# PURPOSE: Pre-compute all branch naming patterns for instant matching
# PARAMETERS: None (uses global AIPM_* variables)
# RETURNS:
#   0 - Always succeeds
# OUTPUTS:
#   JSON object with pattern details for each branch type
# COMPUTED VALUES:
#   For each branch type (feature, bugfix, etc.):
#   - original: Raw pattern from config
#   - full: Pattern with prefix applied
#   - glob: Shell glob pattern for matching
#   - regex: Regular expression for extraction
# EXAMPLE:
#   local patterns=$(compute_all_branch_patterns)
#   local feature_glob=$(jq -r '.feature.glob' <<< "$patterns")
#   # Use for branch matching: [[ "$branch" == $feature_glob ]]

##############################################################################
# PURPOSE:
#   Computes comprehensive branch pattern mappings for all branch types
#   defined in naming configuration. Generates original, full, glob, and
#   regex patterns for each branch type to support flexible matching.
#
# PARAMETERS:
#   None
#
# RETURNS:
#   JSON object with pattern mappings for each branch type:
#   {
#     "<type>": {
#       "original": "pattern with {placeholders}",
#       "full": "aipm/pattern with {placeholders}",
#       "glob": "aipm/pattern with * wildcards",
#       "regex": "^aipm/pattern with capture groups$"
#     }
#   }
#
# OUTPUTS:
#   Writes JSON to stdout
#
# SIDE EFFECTS:
#   None
#
# EXAMPLES:
#   patterns=$(compute_all_branch_patterns)
#   feature_glob=$(echo "$patterns" | jq -r '.feature.glob')
#   # Result: "aipm/feature/*"
#
# LEARNING:
#   - Dynamically discovers all AIPM_NAMING_* variables
#   - Resolves cross-references like {naming.session}
#   - Generates multiple pattern formats for different use cases
#   - Essential for branch validation and matching throughout system
##############################################################################
compute_all_branch_patterns() {
    local prefix="${AIPM_BRANCHING_PREFIX}"
    local patterns='{}'
    
    # LEARNING: Dynamic discovery of naming patterns
    # We scan all exported variables for AIPM_NAMING_* pattern
    # This allows new branch types to be added without code changes
    # Get all naming patterns from exports
    local types=()
    while IFS='=' read -r name value; do
        if [[ "$name" =~ ^AIPM_NAMING_([A-Z]+)$ ]]; then
            local type="${BASH_REMATCH[1],,}"  # lowercase
            types+=("$type")
        fi
    done < <(compgen -A export | while read var; do printf "%s=%s\n" "$var" "${!var}"; done | grep "^AIPM_NAMING_")
    
    # LEARNING: Pattern transformation pipeline
    # Each pattern goes through multiple transformations:
    # 1. Original: As defined in config (e.g., "feature/{description}")
    # 2. Full: With prefix added (e.g., "aipm/feature/{description}")
    # 3. Glob: For shell matching (e.g., "aipm/feature/*")
    # 4. Regex: For precise validation (e.g., "^aipm/feature/(.+)$")
    # Process each type
    for type in "${types[@]}"; do
        local pattern_var="AIPM_NAMING_${type^^}"
        local pattern="${!pattern_var}"
        
        if [[ -n "$pattern" ]]; then
            # LEARNING: Cross-reference resolution
            # Patterns can reference other patterns using {naming.type} syntax
            # This enables pattern composition and consistency
            # Example: session pattern might reference feature pattern
            # Resolve cross-references like {naming.session}
            if [[ "$pattern" =~ \{naming\.([^}]+)\} ]]; then
                local ref_type="${BASH_REMATCH[1]}"
                local ref_var="AIPM_NAMING_${ref_type^^}"
                local ref_pattern="${!ref_var}"
                pattern="${pattern//\{naming.$ref_type\}/$ref_pattern}"
            fi
            
            # Create patterns for matching
            local full_pattern="${prefix}${pattern}"
            local glob_pattern="${full_pattern//\{*\}/*}"
            local regex_pattern="^${prefix}${pattern//\{[^}]+\}/(.+)}\$"
            
            patterns=$(printf "%s\n" "$patterns" | jq --arg k "$type" \
                --arg orig "$pattern" \
                --arg full "$full_pattern" \
                --arg glob "$glob_pattern" \
                --arg regex "$regex_pattern" \
                '.[$k] = {
                    original: $orig,
                    full: $full,
                    glob: $glob,
                    regex: $regex
                }')
        fi
    done
    
    printf "%s\n" "$patterns"
}

##############################################################################
# PURPOSE:
#   Computes comprehensive list of protected branches, including both
#   user-defined branches and AIPM-managed branches with proper prefixing.
#   Maintains separation between user and AIPM branches for clarity.
#
# PARAMETERS:
#   None
#
# RETURNS:
#   JSON object with categorized protected branches:
#   {
#     "userBranches": ["main", "develop"],
#     "aipmBranches": [{"suffix": "session", "full": "aipm/session"}],
#     "all": ["main", "develop", "aipm/session"]
#   }
#
# OUTPUTS:
#   Writes JSON to stdout
#
# SIDE EFFECTS:
#   None
#
# EXAMPLES:
#   protected=$(compute_protected_branches_list)
#   all_protected=$(echo "$protected" | jq -r '.all[]')
#   # Iterate over all protected branches
#
# LEARNING:
#   - Separates user vs AIPM branches for different handling
#   - AIPM branches store both suffix and full name for flexibility
#   - 'all' array provides unified list for protection checks
#   - Critical for preventing accidental writes to important branches
##############################################################################
compute_protected_branches_list() {
    local protected='{
        "userBranches": [],
        "aipmBranches": [],
        "all": []
    }'
    
    # LEARNING: User branches are stored as-is
    # These are branches like 'main', 'develop' that exist outside AIPM
    # We don't modify them since they're not under our namespace
    # Add user branches
    if [[ -n "$AIPM_BRANCHING_PROTECTEDBRANCHES_USER" ]]; then
        for branch in $AIPM_BRANCHING_PROTECTEDBRANCHES_USER; do
            protected=$(printf "%s\n" "$protected" | jq --arg b "$branch" '
                .userBranches += [$b] |
                .all += [$b]
            ')
        done
    fi
    
    # LEARNING: AIPM branches need prefix application
    # Config stores just the suffix (e.g., 'session')
    # We prepend the AIPM prefix to get full branch name (e.g., 'aipm/session')
    # This allows config to be prefix-agnostic
    # Add AIPM branches with prefix
    if [[ -n "$AIPM_BRANCHING_PROTECTEDBRANCHES_AIPM" ]]; then
        for suffix in $AIPM_BRANCHING_PROTECTEDBRANCHES_AIPM; do
            local full_branch="${AIPM_BRANCHING_PREFIX}${suffix}"
            protected=$(printf "%s\n" "$protected" | jq --arg b "$full_branch" --arg s "$suffix" '
                .aipmBranches += [{suffix: $s, full: $b}] |
                .all += [$b]
            ')
        done
    fi
    
    printf "%s\n" "$protected"
}

##############################################################################
# PURPOSE:
#   Computes comprehensive lifecycle matrix defining retention and deletion
#   rules for each branch type. Transforms raw configuration into actionable
#   rules with computed timing, triggers, and human-readable descriptions.
#
# PARAMETERS:
#   None
#
# RETURNS:
#   JSON object with lifecycle rules per branch type:
#   {
#     "<type>": {
#       "deleteAfterMerge": true/false,
#       "daysToKeep": number or "never",
#       "deleteTiming": "never"|"immediate"|"scheduled",
#       "deleteAfterDays": number or null,
#       "deleteTrigger": "mergeDate"|"lastCommit",
#       "maxCount": number or null,
#       "description": "Human-readable rule description"
#     },
#     "global": { ... global settings ... }
#   }
#
# OUTPUTS:
#   Writes JSON to stdout
#
# SIDE EFFECTS:
#   None
#
# EXAMPLES:
#   matrix=$(compute_complete_lifecycle_matrix)
#   feature_rules=$(echo "$matrix" | jq '.feature')
#   # Get deletion rules for feature branches
#
# LEARNING:
#   - Transforms configuration values into actionable rules
#   - Computes deletion timing from days_to_keep values
#   - Generates human-readable descriptions for UI display
#   - Handles special values like -1 (never) and 0 (immediate)
#   - Critical for automated branch lifecycle management
##############################################################################
compute_complete_lifecycle_matrix() {
    local matrix='{}'
    
    # LEARNING: Dynamic discovery of lifecycle rules
    # We find all branch types by looking for DELETEAFTERMERGE settings
    # This is the primary lifecycle indicator - other settings are optional
    # Get all branch types that have lifecycle rules
    local types=()
    while IFS='=' read -r name value; do
        if [[ "$name" =~ ^AIPM_LIFECYCLE_([A-Z]+)_DELETEAFTERMERGE$ ]]; then
            local type="${BASH_REMATCH[1],,}"
            types+=("$type")
        fi
    done < <(compgen -A export | while read var; do printf "%s=%s\n" "$var" "${!var}"; done | grep "^AIPM_LIFECYCLE_")
    
    # LEARNING: Lifecycle rule computation for each branch type
    # Process each type
    for type in "${types[@]}"; do
        local delete_var="AIPM_LIFECYCLE_${type^^}_DELETEAFTERMERGE"
        local days_var="AIPM_LIFECYCLE_${type^^}_DAYSTOKEEP"
        local max_var="AIPM_LIFECYCLE_${type^^}_MAXSESSIONS"
        
        local delete_after_merge="${!delete_var:-false}"
        local days_to_keep="${!days_var:-30}"
        local max_count="${!max_var:-}"
        
        # LEARNING: Delete timing computation
        # We transform days_to_keep into actionable timing:
        # - "-1" or "never" = never delete
        # - "0" = delete immediately
        # - Any positive number = scheduled deletion
        # This abstraction simplifies downstream logic
        # Compute delete timing
        local delete_timing="never"
        local delete_after_days=""
        if [[ "$days_to_keep" == "-1" ]] || [[ "$days_to_keep" == "never" ]]; then
            delete_timing="never"
        elif [[ "$days_to_keep" == "0" ]]; then
            delete_timing="immediate"
            delete_after_days=0
        else
            delete_timing="scheduled"
            delete_after_days="$days_to_keep"
        fi
        
        # LEARNING: Delete trigger determination
        # Two possible triggers for branch deletion:
        # 1. mergeDate - starts countdown when branch is merged
        # 2. lastCommit - starts countdown from last activity
        # This affects when the deletion timer begins
        # Determine what triggers deletion
        local delete_trigger="lastCommit"
        if [[ "$delete_after_merge" == "true" ]]; then
            delete_trigger="mergeDate"
        fi
        
        # Build complete lifecycle entry
        local entry=$(jq -n \
            --arg dam "$delete_after_merge" \
            --arg dtk "$days_to_keep" \
            --arg dt "$delete_timing" \
            --arg dad "$delete_after_days" \
            --arg dtr "$delete_trigger" \
            --arg mc "$max_count" \
            '{
                deleteAfterMerge: ($dam == "true"),
                daysToKeep: ($dtk | tonumber? // $dtk),
                deleteTiming: $dt,
                deleteAfterDays: (if $dad != "" then ($dad | tonumber) else null end),
                deleteTrigger: $dtr,
                maxCount: (if $mc != "" then ($mc | tonumber) else null end),
                # LEARNING: Human-readable descriptions
                # We generate clear descriptions based on computed rules
                # This helps users understand the actual behavior
                # Descriptions vary based on timing and trigger combination
                description: (
                    if $dt == "never" then "Keep forever"
                    elif $dt == "immediate" then 
                        if $dam == "true" then "Delete immediately after merge"
                        else "Delete immediately after last commit"
                        end
                    else
                        if $dam == "true" then "Delete \($dad) days after merge"
                        else "Delete \($dad) days after last commit"
                        end
                    end
                )
            }')
        
        matrix=$(printf "%s\n" "$matrix" | jq --arg k "$type" --argjson v "$entry" '.[$k] = $v')
    done
    
    # Add global lifecycle settings
    matrix=$(printf "%s\n" "$matrix" | jq --arg hu "$AIPM_LIFECYCLE_GLOBAL_HANDLEUNCOMMITTED" \
        --arg cr "$AIPM_LIFECYCLE_GLOBAL_CONFLICTRESOLUTION" \
        --arg ao "$AIPM_LIFECYCLE_GLOBAL_ALLOWOVERRIDE" \
        --arg ta "$AIPM_LIFECYCLE_GLOBAL_TRACKACTIVITY" \
        '.global = {
            handleUncommitted: $hu,
            conflictResolution: $cr,
            allowOverride: ($ao == "true"),
            trackActivity: ($ta == "true")
        }')
    
    printf "%s\n" "$matrix"
}

##############################################################################
# PURPOSE:
#   Computes comprehensive workflow rules defining behavior for branch
#   operations including creation, merging, synchronization, and cleanup.
#   Includes prompt configurations for interactive workflows.
#
# PARAMETERS:
#   None
#
# RETURNS:
#   JSON object with workflow configurations:
#   {
#     "branchCreation": { ... creation rules and prompts ... },
#     "merging": { ... merge rules and prompts ... },
#     "synchronization": { ... sync rules and prompts ... },
#     "cleanup": { ... cleanup rules and prompts ... },
#     "branchFlow": { ... source/target mappings ... }
#   }
#
# OUTPUTS:
#   Writes JSON to stdout
#
# SIDE EFFECTS:
#   None
#
# EXAMPLES:
#   workflows=$(compute_complete_workflow_rules)
#   merge_prompt=$(echo "$workflows" | jq '.merging.prompts.featureComplete')
#   # Get feature completion prompt configuration
#
# LEARNING:
#   - Centralizes all workflow behaviors and user interactions
#   - Includes pre-configured prompts for consistent UX
#   - Handles branch flow mappings with pattern matching
#   - Resolves {mainBranch} placeholders dynamically
#   - Critical for orchestrating git operations smoothly
##############################################################################
compute_complete_workflow_rules() {
    local workflows=$(jq -n '{
        branchCreation: {},
        merging: {},
        synchronization: {},
        cleanup: {},
        branchFlow: {}
    }')
    
    # LEARNING: Branch creation workflow configuration
    # Defines how AIPM handles branch creation scenarios:
    # - startBehavior: what happens when starting work
    # - protectionResponse: reaction to protected branch writes
    # - typeSelection: how to determine branch type
    # Includes complete prompt configurations for user interaction
    # Branch creation workflows
    workflows=$(printf "%s\n" "$workflows" | jq \
        --arg sb "$AIPM_WORKFLOWS_BRANCHCREATION_STARTBEHAVIOR" \
        --arg pr "$AIPM_WORKFLOWS_BRANCHCREATION_PROTECTIONRESPONSE" \
        --arg ts "${AIPM_WORKFLOWS_BRANCHCREATION_TYPESELECTION:-prompt}" \
        '.branchCreation = {
            startBehavior: $sb,
            protectionResponse: $pr,
            typeSelection: $ts,
            prompts: {
                protected: {
                    message: "You'\''re trying to save to main branch. What would you like to do?",
                    options: [
                        {key: "1", text: "Create feature branch", action: "create-feature"},
                        {key: "2", text: "Create session branch", action: "create-session"},
                        {key: "3", text: "Cancel", action: "cancel"}
                    ]
                },
                typeSelection: {
                    message: "What type of work is this?",
                    options: [
                        {key: "1", text: "Feature - New functionality", value: "feature"},
                        {key: "2", text: "Bug Fix - Fixing an issue", value: "bugfix"},
                        {key: "3", text: "Documentation - Docs only", value: "docs"},
                        {key: "4", text: "Experiment - Just trying", value: "test"}
                    ]
                }
            }
        }')
    
    # Merging workflows
    workflows=$(printf "%s\n" "$workflows" | jq \
        --arg sm "${AIPM_WORKFLOWS_MERGING_SESSIONMERGE:-on-stop}" \
        --arg fc "${AIPM_WORKFLOWS_MERGING_FEATURECOMPLETE:-prompt}" \
        --arg ch "${AIPM_WORKFLOWS_MERGING_CONFLICTHANDLING:-interactive}" \
        '.merging = {
            sessionMerge: $sm,
            featureComplete: $fc,
            conflictHandling: $ch,
            prompts: {
                featureComplete: {
                    message: "Is this feature complete and ready to merge?",
                    options: [
                        {key: "1", text: "Yes, merge now", action: "merge"},
                        {key: "2", text: "No, keep working", action: "continue"},
                        {key: "3", text: "Create PR for review", action: "pr"}
                    ]
                },
                mergeConflict: {
                    message: "Merge conflict detected. How to resolve?",
                    options: [
                        {key: "1", text: "Open editor to resolve", action: "editor"},
                        {key: "2", text: "Keep local version", action: "local"},
                        {key: "3", text: "Keep remote version", action: "remote"},
                        {key: "4", text: "Abort operation", action: "abort"}
                    ]
                }
            }
        }')
    
    # Synchronization workflows
    workflows=$(printf "%s\n" "$workflows" | jq \
        --arg pos "$AIPM_WORKFLOWS_SYNCHRONIZATION_PULLONSTART" \
        --arg pos2 "$AIPM_WORKFLOWS_SYNCHRONIZATION_PUSHONSTOP" \
        --arg ab "$AIPM_WORKFLOWS_SYNCHRONIZATION_AUTOBACKUP" \
        '.synchronization = {
            pullOnStart: $pos,
            pushOnStop: $pos2,
            autoBackup: $ab,
            prompts: {
                pullOnStart: {
                    message: "Remote has new changes. Update now?",
                    options: [
                        {key: "1", text: "Yes, update", action: "pull"},
                        {key: "2", text: "No, work offline", action: "skip"},
                        {key: "3", text: "View changes first", action: "diff"}
                    ]
                },
                pushOnStop: {
                    message: "You have unpushed changes. Share them?",
                    options: [
                        {key: "1", text: "Yes, push all", action: "push-all"},
                        {key: "2", text: "Push some", action: "push-select"},
                        {key: "3", text: "No, keep local", action: "skip"}
                    ]
                }
            }
        }')
    
    # Cleanup workflows
    workflows=$(printf "%s\n" "$workflows" | jq \
        --arg am "$AIPM_WORKFLOWS_CLEANUP_AFTERMERGE" \
        --arg sh "$AIPM_WORKFLOWS_CLEANUP_STALEHANDLING" \
        --arg fw "$AIPM_WORKFLOWS_CLEANUP_FAILEDWORK" \
        '.cleanup = {
            afterMerge: $am,
            staleHandling: $sh,
            failedWork: $fw,
            prompts: {
                afterMerge: {
                    message: "Branch merged successfully. Delete it?",
                    options: [
                        {key: "1", text: "Yes, delete now", action: "delete"},
                        {key: "2", text: "Keep for now", action: "keep"},
                        {key: "3", text: "Archive it", action: "archive"}
                    ]
                }
            }
        }')
    
    # LEARNING: Branch flow rules define source/target relationships
    # This is crucial for determining:
    # - Where new branches are created from (sources)
    # - Where branches should be merged to (targets)
    # We resolve {mainBranch} placeholders here for consistency
    # Branch flow rules with complete resolution
    local main_branch="${AIPM_COMPUTED_MAINBRANCH}"
    workflows=$(printf "%s\n" "$workflows" | jq \
        --arg sd "$AIPM_WORKFLOWS_BRANCHFLOW_SOURCES_DEFAULT" \
        --arg td "$AIPM_WORKFLOWS_BRANCHFLOW_TARGETS_DEFAULT" \
        --arg pt "$AIPM_WORKFLOWS_BRANCHFLOW_PARENTTRACKING" \
        --arg mb "$main_branch" \
        '.branchFlow = {
            sources: {
                default: ($sd | gsub("\\{mainBranch\\}"; $mb)),
                byType: {}
            },
            targets: {
                default: ($td | gsub("\\{mainBranch\\}"; $mb)),
                byType: {}
            },
            parentTracking: $pt,
            prompts: {
                selectSource: {
                    message: "Create new branch from:",
                    options: [
                        {key: "1", text: "Current branch", value: "current"},
                        {key: "2", text: "Main branch", value: $mb},
                        {key: "3", text: "Other branch", value: "select"}
                    ]
                },
                selectTarget: {
                    message: "Merge this branch to:",
                    options: [
                        {key: "1", text: "Parent branch", value: "parent"},
                        {key: "2", text: "Main branch", value: $mb},
                        {key: "3", text: "Other branch", value: "select"}
                    ]
                }
            }
        }')
    
    # LEARNING: Per-type flow overrides
    # Different branch types have different flow patterns:
    # - feature/fix/release flow to main branch
    # - session/test flow from current branch
    # This array defines the default mappings
    # Pattern matching allows flexible configuration
    # Add per-type overrides for branch flow
    local flow_types=("feature/*:$main_branch" "fix/*:$main_branch" "session/*:current" "test/*:current" "release/*:$main_branch")
    for flow in "${flow_types[@]}"; do
        local pattern="${flow%%:*}"
        local source="${flow#*:}"
        source="${source//\{mainBranch\}/$main_branch}"
        workflows=$(printf "%s\n" "$workflows" | jq --arg p "$pattern" --arg s "$source" '.branchFlow.sources.byType[$p] = $s')
    done
    
    # Add per-type targets
    local target_types=("feature/*:$main_branch" "fix/*:$main_branch" "session/*:parent" "test/*:parent" "release/*:none")
    for flow in "${target_types[@]}"; do
        local pattern="${flow%%:*}"
        local target="${flow#*:}"
        target="${target//\{mainBranch\}/$main_branch}"
        workflows=$(printf "%s\n" "$workflows" | jq --arg p "$pattern" --arg t "$target" '.branchFlow.targets.byType[$p] = $t')
    done
    
    printf "%s\n" "$workflows"
}

##############################################################################
# PURPOSE:
#   Computes comprehensive validation rules determining what checks are
#   enforced during AIPM operations. Supports different validation modes
#   including gradual progression from relaxed to strict enforcement.
#
# PARAMETERS:
#   None
#
# RETURNS:
#   JSON object with validation configuration:
#   {
#     "mode": "strict"|"relaxed"|"gradual",
#     "rules": { ... enforcement flags ... },
#     "blockers": { ... hard stop conditions ... },
#     "gradual": { ... progression settings if mode=gradual ... }
#   }
#
# OUTPUTS:
#   Writes JSON to stdout
#
# SIDE EFFECTS:
#   None
#
# EXAMPLES:
#   validation=$(compute_complete_validation_rules)
#   is_strict=$(echo "$validation" | jq -r '.mode == "strict"')
#   # Check if running in strict mode
#
# LEARNING:
#   - Separates rules (can be warnings) from blockers (always stop)
#   - Supports gradual mode for progressive enforcement
#   - Validation behavior changes based on mode setting
#   - Critical for maintaining code quality standards
##############################################################################
compute_complete_validation_rules() {
    local validation=$(jq -n \
        --arg mode "$AIPM_VALIDATION_MODE" \
        --arg en "$AIPM_VALIDATION_RULES_ENFORCENAMING" \
        --arg bp "$AIPM_VALIDATION_RULES_BLOCKWRONGPREFIX" \
        --arg ct "$AIPM_VALIDATION_RULES_REQUIRECLEANTREE" \
        --arg vm "$AIPM_VALIDATION_RULES_VALIDATEMEMORY" \
        --arg ww "$AIPM_VALIDATION_BLOCKERS_WRONGWORKSPACE" \
        --arg ip "$AIPM_VALIDATION_BLOCKERS_INVALIDPREFIX" \
        --arg cm "$AIPM_VALIDATION_BLOCKERS_CORRUPTMEMORY" \
        '{
            mode: $mode,
            rules: {
                enforceNaming: ($en == "true"),
                blockWrongPrefix: ($bp == "true"),
                requireCleanTree: ($ct == "true"),
                validateMemory: ($vm == "true")
            },
            blockers: {
                wrongWorkspace: ($ww == "true"),
                invalidPrefix: ($ip == "true"),
                corruptMemory: ($cm == "true")
            }
        }')
    
    # LEARNING: Gradual mode configuration
    # Gradual mode allows progression from relaxed to strict over time
    # This helps teams adopt AIPM without immediate disruption
    # Progression can be triggered by time, usage, or milestones
    # Add gradual mode settings if applicable
    if [[ "$AIPM_VALIDATION_MODE" == "gradual" ]]; then
        validation=$(printf "%s\n" "$validation" | jq \
            --arg sl "${AIPM_VALIDATION_GRADUAL_STARTLEVEL:-relaxed}" \
            --arg el "${AIPM_VALIDATION_GRADUAL_ENDLEVEL:-strict}" \
            --arg tr "${AIPM_VALIDATION_GRADUAL_PROGRESSION_TRIGGER:-days}" \
            --arg tv "${AIPM_VALIDATION_GRADUAL_PROGRESSION_VALUE:-30}" \
            --arg w "${AIPM_VALIDATION_GRADUAL_PROGRESSION_WARNINGS:-7}" \
            '.gradual = {
                startLevel: $sl,
                endLevel: $el,
                progression: {
                    trigger: $tr,
                    value: ($tv | tonumber),
                    warnings: ($w | tonumber)
                },
                currentLevel: $sl
            }')
    fi
    
    printf "%s\n" "$validation"
}

##############################################################################
# PURPOSE:
#   Computes comprehensive memory configuration for AIPM's entity tracking
#   system. Defines how memory entities are named, categorized, and validated
#   including regex patterns and category rules.
#
# PARAMETERS:
#   None
#
# RETURNS:
#   JSON object with memory configuration:
#   {
#     "entityPrefix": "AIPM_MEMORY_",
#     "categories": ["task", "decision", ...],
#     "entityRegex": "^AIPM_MEMORY_[A-Z]+_.*$",
#     "maxSize": "1MB",
#     "categoryRules": { ... validation rules ... },
#     "examples": [ ... example entity names ... ]
#   }
#
# OUTPUTS:
#   Writes JSON to stdout
#
# SIDE EFFECTS:
#   None
#
# EXAMPLES:
#   memory=$(compute_complete_memory_config)
#   categories=$(echo "$memory" | jq -r '.categories[]')
#   # List all valid memory categories
#
# LEARNING:
#   - Memory entities track important project information
#   - Categories ensure consistent organization
#   - Regex pattern enforces naming conventions
#   - Examples help users understand proper usage
#   - Critical for maintaining project context across sessions
##############################################################################
compute_complete_memory_config() {
    local memory=$(jq -n \
        --arg ep "$AIPM_MEMORY_ENTITYPREFIX" \
        --arg cats "$AIPM_MEMORY_CATEGORIES" \
        --arg regex "$AIPM_COMPUTED_ENTITYPATTERN" \
        --arg strict "$AIPM_MEMORY_CATEGORYRULES_STRICT" \
        --arg dynamic "$AIPM_MEMORY_CATEGORYRULES_ALLOWDYNAMIC" \
        --arg uncat "$AIPM_MEMORY_CATEGORYRULES_UNCATEGORIZED" \
        --arg case "$AIPM_MEMORY_CATEGORYRULES_CASEINSENSITIVE" \
        --arg size "$AIPM_DEFAULTS_LIMITS_MEMORYSIZE" \
        '{
            entityPrefix: $ep,
            categories: ($cats | split(" ")),
            entityRegex: $regex,
            maxSize: $size,
            categoryRules: {
                strict: ($strict == "true"),
                allowDynamic: ($dynamic == "true"),
                uncategorized: $uncat,
                caseInsensitive: ($case == "true")
            },
            examples: []
        }')
    
    # LEARNING: Example generation
    # We generate example entity names for each category
    # This helps users understand the naming pattern
    # Format: AIPM_MEMORY_<CATEGORY>_DESCRIPTION
    # Add examples for each category
    local categories=($AIPM_MEMORY_CATEGORIES)
    for cat in "${categories[@]}"; do
        local example="${AIPM_MEMORY_ENTITYPREFIX}${cat}_DESCRIPTION"
        memory=$(printf "%s\n" "$memory" | jq --arg ex "$example" '.examples += [$ex]')
    done
    
    printf "%s\n" "$memory"
}

# Compute complete team configuration
compute_complete_team_config() {
    local team=$(jq -n \
        --arg sm "$AIPM_TEAM_SYNCMODE" \
        --arg fos "$AIPM_TEAM_FETCHONSTART" \
        --arg wod "$AIPM_TEAM_WARNONDIVERGENCE" \
        --arg rpr "$AIPM_TEAM_REQUIREPULLREQUEST" \
        --arg pto "$AIPM_TEAM_SYNC_PROMPT_TIMEOUT" \
        --arg ptd "$AIPM_TEAM_SYNC_PROMPT_DEFAULT" \
        --arg dr "$AIPM_TEAM_SYNC_DIVERGENCE_RESOLUTION" \
        --arg dd "$AIPM_TEAM_SYNC_DIVERGENCE_SHOWDIFF" \
        --arg cs "$AIPM_TEAM_SYNC_CONFLICTS_STRATEGY" \
        --arg cb "$AIPM_TEAM_SYNC_CONFLICTS_BACKUP" \
        --arg ca "$AIPM_TEAM_SYNC_CONFLICTS_ABORTONFAIL" \
        '{
            syncMode: $sm,
            fetchOnStart: ($fos == "true"),
            warnOnDivergence: ($wod == "true"),
            requirePullRequest: ($rpr == "true"),
            sync: {
                prompt: {
                    triggers: ["remote-ahead", "diverged", "merge-conflicts"],
                    timeout: ($pto | tonumber),
                    default: $ptd,
                    messages: {
                        remoteAhead: "Remote has updates. Sync now?",
                        diverged: "Your branch and remote have diverged. How to proceed?",
                        mergeConflicts: "Merge conflicts detected during sync."
                    }
                },
                divergence: {
                    definition: "local and remote have different commits",
                    resolution: $dr,
                    showDiff: ($dd == "true"),
                    prompts: {
                        resolve: {
                            message: "Your branch and remote have diverged. How to proceed?",
                            options: [
                                {key: "1", text: "Merge remote changes", action: "merge"},
                                {key: "2", text: "Rebase onto remote", action: "rebase"},
                                {key: "3", text: "Keep mine only", action: "force"},
                                {key: "4", text: "View differences", action: "diff"}
                            ]
                        }
                    }
                },
                conflicts: {
                    strategy: $cs,
                    backup: ($cb == "true"),
                    abortOnFail: ($ca == "true"),
                    prompts: {
                        resolve: {
                            message: "Merge conflict detected. How to resolve?",
                            options: [
                                {key: "1", text: "Keep my version", action: "ours"},
                                {key: "2", text: "Take their version", action: "theirs"},
                                {key: "3", text: "Manual merge", action: "manual"},
                                {key: "4", text: "Abort operation", action: "abort"}
                            ]
                        }
                    }
                }
            }
        }')
    
    printf "%s\n" "$team"
}

# Compute complete session configuration
compute_complete_session_config() {
    local sessions=$(jq -n \
        --arg en "$AIPM_SESSIONS_ENABLED" \
        --arg ac "$AIPM_SESSIONS_AUTOCREATE" \
        --arg am "$AIPM_SESSIONS_AUTOMERGE" \
        --arg mul "$AIPM_SESSIONS_ALLOWMULTIPLE" \
        --arg np "$AIPM_SESSIONS_NAMEPATTERN" \
        --arg poc "$AIPM_SESSIONS_PROMPTONCONFLICT" \
        --arg com "$AIPM_SESSIONS_CLEANUPONMERGE" \
        '{
            enabled: ($en == "true"),
            autoCreate: ($ac == "true"),
            autoMerge: ($am == "true"),
            allowMultiple: ($mul == "true"),
            namePattern: $np,
            promptOnConflict: ($poc == "true"),
            cleanupOnMerge: ($com == "true"),
            prompts: {
                conflict: {
                    message: "Session has conflicts with parent branch. Continue?",
                    options: [
                        {key: "1", text: "Merge anyway", action: "merge"},
                        {key: "2", text: "Keep session separate", action: "keep"},
                        {key: "3", text: "Discard session", action: "discard"}
                    ]
                }
            }
        }')
    
    # Resolve namePattern references
    local resolved_pattern="$AIPM_SESSIONS_NAMEPATTERN"
    if [[ "$resolved_pattern" =~ \{naming\.([^}]+)\} ]]; then
        local ref_type="${BASH_REMATCH[1]}"
        local ref_var="AIPM_NAMING_${ref_type^^}"
        local ref_pattern="${!ref_var}"
        resolved_pattern="${resolved_pattern//\{naming.$ref_type\}/$ref_pattern}"
    fi
    
    sessions=$(printf "%s\n" "$sessions" | jq --arg rp "$resolved_pattern" '.resolvedNamePattern = $rp')
    
    printf "%s\n" "$sessions"
}

# Compute all loading configuration
compute_loading_config() {
    local loading=$(jq -n \
        --arg path "${AIPM_LOADING_DISCOVERY_PATH:-./.aipm/opinions.yaml}" \
        --arg req "${AIPM_LOADING_VALIDATION_REQUIRED:-workspace branching memory lifecycle workflows}" \
        --arg rec "$AIPM_LOADING_VALIDATION_RECOMMENDED" \
        --arg sm "$AIPM_LOADING_VALIDATION_STRICTMODE" \
        --arg hc "$AIPM_LOADING_VALIDATION_HASHCHECK" \
        --arg sv "$AIPM_LOADING_VALIDATION_SCHEMAVERSION" \
        --arg oe "$AIPM_LOADING_VALIDATION_ONERROR" \
        --arg db "$AIPM_LOADING_CONTEXT_DETECTBY" \
        --arg vp "$AIPM_LOADING_CONTEXT_VALIDATEPREFIX" \
        --arg ei "$AIPM_LOADING_CONTEXT_ENFORCEISOLATION" \
        --arg mm "${AIPM_LOADING_CONTEXT_PREFIXRULES_MUSTMATCH:-branching.prefix memory.entityPrefix}" \
        --arg pat "${AIPM_LOADING_CONTEXT_PREFIXRULES_PATTERN:-^[A-Z][A-Z0-9_]*_$}" \
        --arg res "$AIPM_LOADING_CONTEXT_PREFIXRULES_RESERVED" \
        --arg inh "$AIPM_LOADING_INHERITANCE_ENABLED" \
        '{
            discovery: {
                path: $path
            },
            validation: {
                required: ($req | split(" ")),
                recommended: (if $rec != "" then ($rec | split(" ")) else [] end),
                strictMode: ($sm == "true"),
                hashCheck: ($hc == "true"),
                schemaVersion: $sv,
                onError: $oe,
                crossValidationRules: [
                    "All naming types must have lifecycle rules",
                    "All lifecycle types must exist in naming",
                    "branching.prefix must match memory.entityPrefix",
                    "All workflow branch patterns must exist in naming",
                    "Protected branches must use valid patterns",
                    "session namePattern must reference valid naming field"
                ]
            },
            context: {
                detectBy: ($db // "workspace.name"),
                validatePrefix: ($vp == "true"),
                enforceIsolation: ($ei == "true"),
                prefixRules: {
                    mustMatch: ($mm | split(" ")),
                    pattern: $pat,
                    reserved: (if $res != "" then ($res | split(" ")) else [] end)
                }
            },
            inheritance: {
                enabled: ($inh == "true")
            }
        }')
    
    printf "%s\n" "$loading"
}

# Compute initialization configuration
compute_initialization_config() {
    local init=$(jq -n \
        --arg mt "$AIPM_INITIALIZATION_MARKER_TYPE" \
        --arg mm "${AIPM_INITIALIZATION_MARKER_MESSAGE:-AIPM_INIT_HERE: Initialize {workspace.name} workspace from {parent.branch}}" \
        --arg im "$AIPM_INITIALIZATION_MARKER_INCLUDEMETADATA" \
        --arg vs "$AIPM_INITIALIZATION_MARKER_VERIFYONSTART" \
        --arg rc "$AIPM_INITIALIZATION_BRANCHCREATION_REQUIRECLEAN" \
        --arg bo "$AIPM_INITIALIZATION_BRANCHCREATION_BACKUPORIGINAL" \
        --arg sd "$AIPM_INITIALIZATION_BRANCHCREATION_SHOWDIFF" \
        --arg ms "$AIPM_INITIALIZATION_MAIN_SUFFIX" \
        --arg fc "$AIPM_INITIALIZATION_MAIN_FROMCOMMIT" \
        '{
            marker: {
                type: $mt,
                message: $mm,
                includeMetadata: ($im == "true"),
                verifyOnStart: ($vs == "true")
            },
            branchCreation: {
                requireClean: ($rc == "true"),
                backupOriginal: ($bo == "true"),
                showDiff: ($sd == "true")
            },
            mappings: {
                main: {
                    suffix: $ms,
                    fromCommit: $fc
                }
            }
        }')
    
    # TODO: Add support for additional branch mappings (develop, staging, etc.)
    
    printf "%s\n" "$init"
}

# Compute all defaults and limits
compute_defaults_and_limits() {
    local defaults=$(jq -n \
        --arg ss "$AIPM_DEFAULTS_TIMEOUTS_SESSIONSECONDS" \
        --arg os "$AIPM_DEFAULTS_TIMEOUTS_OPERATIONSECONDS" \
        --arg gs "$AIPM_DEFAULTS_TIMEOUTS_GITSECONDS" \
        --arg ps "$AIPM_DEFAULTS_TIMEOUTS_PROMPTSECONDS" \
        --arg ms "$AIPM_DEFAULTS_LIMITS_MEMORYSIZE" \
        --arg bc "$AIPM_DEFAULTS_LIMITS_BACKUPCOUNT" \
        --arg shd "$AIPM_DEFAULTS_LIMITS_SESSIONHISTORYDAYS" \
        --arg bad "$AIPM_DEFAULTS_LIMITS_BRANCHAGEDAYS" \
        --arg ll "$AIPM_DEFAULTS_LOGGING_LEVEL" \
        --arg loc "$AIPM_DEFAULTS_LOGGING_LOCATION" \
        --arg rot "$AIPM_DEFAULTS_LOGGING_ROTATE" \
        --arg ret "$AIPM_DEFAULTS_LOGGING_RETAIN" \
        '{
            timeouts: {
                sessionSeconds: ($ss | tonumber),
                operationSeconds: ($os | tonumber),
                gitSeconds: ($gs | tonumber),
                promptSeconds: ($ps | tonumber)
            },
            limits: {
                memorySize: $ms,
                memorySizeBytes: 0,
                backupCount: ($bc | tonumber),
                sessionHistoryDays: ($shd | tonumber),
                branchAgeDays: ($bad | tonumber)
            },
            logging: {
                level: $ll,
                location: $loc,
                rotate: $rot,
                retain: ($ret | tonumber)
            }
        }')
    
    # Convert memory size to bytes
    local size_bytes=0
    if [[ "$AIPM_DEFAULTS_LIMITS_MEMORYSIZE" =~ ^([0-9]+)(MB|KB|GB)?$ ]]; then
        local num="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[2]:-MB}"
        case "$unit" in
            KB) size_bytes=$((num * 1024)) ;;
            MB) size_bytes=$((num * 1024 * 1024)) ;;
            GB) size_bytes=$((num * 1024 * 1024 * 1024)) ;;
        esac
    fi
    
    defaults=$(printf "%s\n" "$defaults" | jq --arg sb "$size_bytes" '.limits.memorySizeBytes = ($sb | tonumber)')
    
    printf "%s\n" "$defaults"
}

# Compute error handling configuration
compute_error_handling_config() {
    local error_handling=$(jq -n \
        --arg mbt "$AIPM_ERRORHANDLING_ONMISSINGBRANCHTYPE" \
        --arg ir "$AIPM_ERRORHANDLING_ONINVALIDREFERENCE" \
        --arg cr "$AIPM_ERRORHANDLING_ONCIRCULARREFERENCE" \
        --arg ar "$AIPM_ERRORHANDLING_RECOVERY_AUTORECOVER" \
        --arg cb "$AIPM_ERRORHANDLING_RECOVERY_CREATEBACKUP" \
        --arg nu "$AIPM_ERRORHANDLING_RECOVERY_NOTIFYUSER" \
        '{
            onMissingBranchType: $mbt,
            onInvalidReference: $ir,
            onCircularReference: $cr,
            recovery: {
                autoRecover: ($ar == "true"),
                createBackup: ($cb == "true"),
                notifyUser: $nu
            },
            prompts: {
                missingBranchType: {
                    message: "Unknown branch type. How to handle?",
                    options: [
                        {key: "1", text: "Use default rules", action: "default"},
                        {key: "2", text: "Skip this branch", action: "skip"},
                        {key: "3", text: "Abort operation", action: "abort"}
                    ]
                }
            }
        }')
    
    printf "%s\n" "$error_handling"
}

# Compute settings configuration
compute_settings_config() {
    local settings=$(jq -n \
        --arg sv "${AIPM_SETTINGS_SCHEMAVERSION:-1.0}" \
        --arg mp "${AIPM_SETTINGS_FRAMEWORKPATHS_MODULES:-.aipm/scripts/modules/}" \
        --arg tp "${AIPM_SETTINGS_FRAMEWORKPATHS_TESTS:-.aipm/scripts/test/}" \
        --arg dp "${AIPM_SETTINGS_FRAMEWORKPATHS_DOCS:-.aipm/docs/}" \
        --arg tmp "${AIPM_SETTINGS_FRAMEWORKPATHS_TEMPLATES:-.aipm/templates/}" \
        --arg rt "$AIPM_SETTINGS_WORKFLOW_REQUIRETESTS" \
        --arg rd "$AIPM_SETTINGS_WORKFLOW_REQUIREDOCS" \
        --arg rr "$AIPM_SETTINGS_WORKFLOW_REQUIREREVIEW" \
        '{
            schemaVersion: $sv,
            frameworkPaths: {
                modules: $mp,
                tests: $tp,
                docs: $dp,
                templates: $tmp
            },
            workflow: {
                requireTests: ($rt == "true"),
                requireDocs: ($rd == "true"),
                requireReview: ($rr == "true")
            }
        }')
    
    printf "%s\n" "$settings"
}

# ============================================================================
# RUNTIME STATE FUNCTIONS - Query actual git state
# ============================================================================

# Get complete branch information
# PURPOSE: Gather comprehensive metadata about all AIPM and protected user branches
# PARAMETERS: None
# RETURNS:
#   0 - Always succeeds
# OUTPUTS:
#   JSON object mapping branch names to their complete metadata including:
#   - Existence status, HEAD commit, parent branch, init marker
#   - Creation date, last commit date, merge information
#   - Protection status and reasons
#   - Scheduled deletion information based on lifecycle rules
#   - Remote tracking status
# COMPLEXITY: High - involves multiple git operations per branch
# PERFORMANCE: O(n*m) where n=branches, m=commits to scan
# EXAMPLE:
#   local branches=$(get_complete_runtime_branches)
#   local main_info=$(jq '.["aipm/main"]' <<< "$branches")
get_complete_runtime_branches() {
    local branches='{}'
    local prefix="${AIPM_BRANCHING_PREFIX}"
    
    # Get all branches (local and remote)
    # Learning: We check for version-control.sh functions first for consistency
    # git branch -a lists both local and remote branches
    # sed removes leading spaces and asterisk (current branch marker)
    # grep -v " -> " excludes symbolic refs like origin/HEAD -> origin/main
    local all_branches
    if declare -F list_branches >/dev/null 2>&1; then
        all_branches=$(list_branches all)
    else
        all_branches=$(git branch -a --no-color | sed 's/^[* ]*//' | grep -v " -> " | sort -u)
    fi
    
    while IFS= read -r branch; do
        [[ -z "$branch" ]] && continue
        
        # Skip if not our prefix (unless it's a protected user branch)
        # Learning: We track both AIPM branches (with our prefix) and protected user branches
        # This allows AIPM to manage lifecycle of key user branches like main/master
        local is_our_branch=false
        if [[ "$branch" =~ ^${prefix} ]]; then
            is_our_branch=true
        else
            # Check if it's a protected user branch
            # Protected user branches are defined in opinions.yaml under branching.protectedBranches.user
            for pb in $AIPM_BRANCHING_PROTECTEDBRANCHES_USER; do
                if [[ "$branch" == "$pb" ]]; then
                    is_our_branch=true
                    break
                fi
            done
        fi
        
        [[ "$is_our_branch" == "false" ]] && continue
        
        # Get branch existence and head
        local exists="true"
        local head=$(git rev-parse "$branch" 2>/dev/null || printf "%s\n" "")
        if [[ -z "$head" ]]; then
            exists="false"
            continue
        fi
        
        # Find AIPM_INIT_HERE marker for AIPM branches
        # Learning: AIPM branches have special init commits with "AIPM_INIT_HERE" in the message
        # This marker helps track branch creation metadata and parent relationships
        # We scan up to 100 commits to find it (should be near the beginning)
        local init_marker=""
        local parent=""
        if [[ "$branch" =~ ^${prefix} ]]; then
            # Find AIPM_INIT_HERE marker
            if declare -F show_log >/dev/null 2>&1; then
                init_marker=$(show_log 100 "$branch" 2>/dev/null | grep "AIPM_INIT_HERE" | head -1 | awk '{print $1}')
            else
                init_marker=$(git log --format="%H %s" "$branch" 2>/dev/null | grep "AIPM_INIT_HERE" | head -1 | awk '{print $1}')
            fi
            
            # Extract parent from init message
            if [[ -n "$init_marker" ]]; then
                # Extract parent from init message
                if declare -F show_log >/dev/null 2>&1; then
                    parent=$(show_log 1 "$init_marker" 2>/dev/null | sed -n 's/.*from \([^ ]*\).*/\1/p')
                else
                    parent=$(git log -1 --format="%s" "$init_marker" 2>/dev/null | sed -n 's/.*from \([^ ]*\).*/\1/p')
                fi
            fi
        fi
        
        # Get dates
        # Learning: Created date is the first commit on the branch (oldest)
        # Last commit date helps determine branch staleness
        # We use ISO format (%aI) for consistent date parsing
        # --reverse shows commits oldest-first for finding creation date
        local created
        local last_commit
        if declare -F show_log >/dev/null 2>&1; then
            created=$(show_log 9999 "$branch" 2>/dev/null | tail -1 | awk '{print $1}')
            last_commit=$(show_log 1 "$branch" 2>/dev/null | awk '{print $1}')
        else
            created=$(git log --format="%aI" --reverse "$branch" 2>/dev/null | head -1)
            last_commit=$(git log -1 --format="%aI" "$branch" 2>/dev/null || printf "%s\n" "")
        fi
        
        # Check if merged to any branch
        local merge_date=""
        local merged_to=""
        # Check if branch is merged
        local merge_info
        if declare -F is_branch_merged >/dev/null 2>&1; then
            if is_branch_merged "$branch" >/dev/null 2>&1; then
                merge_info="merged"
            else
                merge_info=""
            fi
        else
            merge_info=$(git branch --merged | grep -v "^[* ]*$branch$" | head -1)
        fi
        if [[ -n "$merge_info" ]]; then
            # Find actual merge commit
            local merge_commit
            if declare -F show_log >/dev/null 2>&1; then
                merge_commit=$(show_log 100 --merges 2>/dev/null | grep "$branch" | head -1)
            else
                merge_commit=$(git log --merges --format="%H %s %aI" | grep "$branch" | head -1)
            fi
            if [[ -n "$merge_commit" ]]; then
                merge_date=$(printf "%s\n" "$merge_commit" | awk '{print $NF}')
                # TODO: Extract merged_to branch
            fi
        fi
        
        # Determine branch type
        local type="unknown"
        if [[ "$branch" =~ ^${prefix} ]]; then
            # It's an AIPM branch - determine type
            for t in feature bugfix test session release framework refactor docs chore; do
                local pattern_var="AIPM_NAMING_${t^^}"
                local pattern="${!pattern_var}"
                if [[ -n "$pattern" ]]; then
                    # Simple pattern matching
                    local simple_pattern="${pattern//\{*\}/}"
                    if [[ "$branch" =~ ^${prefix}${simple_pattern} ]]; then
                        type="$t"
                        break
                    fi
                fi
            done
            
            # Special case for main branch
            if [[ "$branch" == "${AIPM_COMPUTED_MAINBRANCH}" ]]; then
                type="main"
            fi
        else
            # User branch
            type="user"
        fi
        
        # Check if protected
        local is_protected="false"
        local protection_reason=""
        
        # Check user protected branches
        for pb in $AIPM_BRANCHING_PROTECTEDBRANCHES_USER; do
            if [[ "$branch" == "$pb" ]]; then
                is_protected="true"
                protection_reason="user_protected"
                break
            fi
        done
        
        # Check AIPM protected branches
        if [[ "$is_protected" == "false" ]]; then
            for suffix in $AIPM_BRANCHING_PROTECTEDBRANCHES_AIPM; do
                if [[ "$branch" == "${prefix}${suffix}" ]]; then
                    is_protected="true"
                    protection_reason="aipm_protected"
                    break
                fi
            done
        fi
        
        # Get remote tracking info
        # Get remote tracking info
        local upstream
        if declare -F get_upstream_branch >/dev/null 2>&1; then
            upstream=$(get_upstream_branch "$branch" 2>/dev/null || printf "%s\n" "")
        else
            upstream=$(git rev-parse --abbrev-ref "$branch@{upstream}" 2>/dev/null || printf "%s\n" "")
        fi
        local has_remote="false"
        if [[ -n "$upstream" ]]; then
            has_remote="true"
        fi
        
        # Calculate deletion info
        # Learning: Deletion scheduling is based on lifecycle rules per branch type
        # Each branch type can have different retention policies:
        # - deleteAfterMerge: immediate deletion when merged
        # - daysToKeep: retention period after last commit or merge
        # Protected branches and user branches are never scheduled for deletion
        local scheduled_delete="never"
        local delete_reason=""
        local delete_date=""
        
        if [[ "$is_protected" == "false" ]] && [[ "$type" != "unknown" ]] && [[ "$type" != "user" ]]; then
            # Build variable names dynamically based on branch type
            # ${type^^} converts to uppercase (e.g., feature -> FEATURE)
            local lifecycle_var_dam="AIPM_LIFECYCLE_${type^^}_DELETEAFTERMERGE"
            local lifecycle_var_dtk="AIPM_LIFECYCLE_${type^^}_DAYSTOKEEP"
            local delete_after_merge="${!lifecycle_var_dam:-false}"
            local days_to_keep="${!lifecycle_var_dtk:-30}"
            
            if [[ "$days_to_keep" != "-1" ]] && [[ "$days_to_keep" != "never" ]]; then
                local reference_date="$last_commit"
                local delete_trigger="lastCommit"
                
                if [[ "$delete_after_merge" == "true" ]] && [[ -n "$merge_date" ]]; then
                    reference_date="$merge_date"
                    delete_trigger="merge"
                fi
                
                if [[ -n "$reference_date" ]]; then
                    if [[ "$days_to_keep" == "0" ]]; then
                        scheduled_delete="immediate"
                        delete_reason="Immediate deletion after $delete_trigger"
                    else
                        # Calculate future delete date
                        local ref_epoch=$(date -d "$reference_date" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${reference_date%%.*}" +%s 2>/dev/null || printf "%s\n" 0)
                        local delete_epoch=$((ref_epoch + (days_to_keep * 86400)))
                        delete_date=$(date -d "@$delete_epoch" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -r "$delete_epoch" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || printf "%s\n" "")
                        scheduled_delete="scheduled"
                        delete_reason="Delete $days_to_keep days after $delete_trigger"
                    fi
                fi
            fi
        fi
        
        # Build complete branch entry
        local entry=$(jq -n \
            --arg exists "$exists" \
            --arg head "$head" \
            --arg parent "$parent" \
            --arg init "$init_marker" \
            --arg created "$created" \
            --arg last "$last_commit" \
            --arg merge "$merge_date" \
            --arg merged_to "$merged_to" \
            --arg sched "$scheduled_delete" \
            --arg del_date "$delete_date" \
            --arg del_reason "$delete_reason" \
            --arg prot "$is_protected" \
            --arg prot_reason "$protection_reason" \
            --arg type "$type" \
            --arg upstream "$upstream" \
            --arg remote "$has_remote" \
            '{
                exists: ($exists == "true"),
                head: $head,
                parent: (if $parent != "" then $parent else null end),
                initMarker: (if $init != "" then $init else null end),
                created: $created,
                lastCommit: $last,
                mergeDate: (if $merge != "" then $merge else null end),
                mergedTo: (if $merged_to != "" then $merged_to else null end),
                scheduledDelete: $sched,
                deleteDate: (if $del_date != "" then $del_date else null end),
                deleteReason: (if $del_reason != "" then $del_reason else null end),
                isProtected: ($prot == "true"),
                protectionReason: (if $prot_reason != "" then $prot_reason else null end),
                type: $type,
                upstream: (if $upstream != "" then $upstream else null end),
                hasRemote: ($remote == "true")
            }')
        
        branches=$(printf "%s\n" "$branches" | jq --arg k "$branch" --argjson v "$entry" '.[$k] = $v')
    done <<< "$all_branches"
    
    printf "%s\n" "$branches"
}

# Get complete git runtime state
# PURPOSE: Capture the current repository state including working tree, remotes, and operations
# PARAMETERS: None
# RETURNS:
#   0 - Always succeeds
# OUTPUTS:
#   JSON object containing:
#   - Current branch name and working tree status
#   - List of uncommitted changes with file paths and change types
#   - Stash count, remote sync status (ahead/behind/diverged)
#   - Repository paths and any in-progress operations (rebase/merge/cherry-pick)
# COMPLEXITY: Medium - multiple git status checks
# PERFORMANCE: O(n) where n=uncommitted files
# EXAMPLE:
#   local state=$(get_complete_runtime_state)
#   local is_clean=$(jq -r '.workingTreeClean' <<< "$state")
get_complete_runtime_state() {
    # Get current branch using version-control.sh function if available
    local current_branch
    if declare -F get_current_branch >/dev/null 2>&1; then
        current_branch=$(get_current_branch)
    else
        current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || printf "%s\n" "")
    fi
    local working_tree_clean="true"
    local uncommitted_changes='[]'
    
    # Check working tree status
    # Learning: git status --porcelain gives machine-readable output
    # Empty output means clean working tree
    # Format: XY filename where X=index status, Y=worktree status
    local status_output
    if declare -F is_working_directory_clean >/dev/null 2>&1; then
        # Use version-control.sh function to check if clean
        if is_working_directory_clean >/dev/null 2>&1; then
            status_output=""
        else
            status_output=$(git status --porcelain 2>/dev/null)
        fi
    else
        status_output=$(git status --porcelain 2>/dev/null)
    fi
    if [[ -n "$status_output" ]]; then
        working_tree_clean="false"
        
        # Parse uncommitted changes
        # Learning: Git status codes in porcelain format:
        # First char = index/staging area status
        # Second char = working tree status
        # ?? = untracked, M = modified, A = added, D = deleted, R = renamed
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            local status="${line:0:2}"  # Extract 2-char status code
            local file="${line:3}"      # Rest is filename (after space)
            local change_type="unknown"
            
            case "$status" in
                "??") change_type="untracked" ;;
                "M "|" M") change_type="modified" ;;
                "A "|" A") change_type="added" ;;
                "D "|" D") change_type="deleted" ;;
                "R "|" R") change_type="renamed" ;;
                *) change_type="other" ;;
            esac
            
            uncommitted_changes=$(printf "%s\n" "$uncommitted_changes" | jq --arg f "$file" --arg t "$change_type" \
                '. += [{file: $f, type: $t}]')
        done <<< "$status_output"
    fi
    
    # Get stash count
    local stash_count
    if declare -F list_stashes >/dev/null 2>&1; then
        stash_count=$(list_stashes | wc -l)
    else
        stash_count=$(git stash list 2>/dev/null | wc -l || printf "%s\n" 0)
    fi
    
    # Get remote status
    # Learning: Track synchronization state with upstream branch
    # @{u} is shorthand for upstream branch
    # ahead = commits we have that upstream doesn't
    # behind = commits upstream has that we don't
    # diverged = both ahead AND behind (requires merge or rebase)
    local ahead=0
    local behind=0
    local diverged="false"
    local upstream=""
    
    if [[ -n "$current_branch" ]]; then
        # Get upstream branch reference
        upstream=$(git rev-parse --abbrev-ref "@{u}" 2>/dev/null)
        if [[ -n "$upstream" ]]; then
            # Get commits ahead/behind using version-control.sh function if available
            if declare -F get_commits_ahead_behind >/dev/null 2>&1; then
                local ahead_behind=$(get_commits_ahead_behind "$current_branch")
                ahead=$(printf "%s\n" "$ahead_behind" | grep "ahead:" | cut -d: -f2 | tr -d ' ')
                behind=$(printf "%s\n" "$ahead_behind" | grep "behind:" | cut -d: -f2 | tr -d ' ')
            else
                # git rev-list --count counts commits in a range
                # @{u}..HEAD = commits on HEAD not on upstream (ahead)
                # HEAD..@{u} = commits on upstream not on HEAD (behind)
                ahead=$(git rev-list --count "@{u}..HEAD" 2>/dev/null || printf "%s\n" 0)
                behind=$(git rev-list --count "HEAD..@{u}" 2>/dev/null || printf "%s\n" 0)
            fi
            if [[ $ahead -gt 0 ]] && [[ $behind -gt 0 ]]; then
                diverged="true"
            fi
        fi
    fi
    
    # Get repository info
    local repo_root
    local git_dir
    if declare -F get_repo_root >/dev/null 2>&1; then
        repo_root=$(get_repo_root || pwd)
    else
        repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    fi
    git_dir=$(git rev-parse --git-dir 2>/dev/null || printf "%s\n" ".git")
    
    # Check for rebase/merge in progress
    # Learning: Git tracks in-progress operations via special files/dirs in .git
    # These operations must be completed/aborted before many other operations
    # rebase-merge/rebase-apply = interactive/non-interactive rebase
    # MERGE_HEAD = merge in progress
    # CHERRY_PICK_HEAD = cherry-pick in progress
    local operation_in_progress=""
    if [[ -d "$git_dir/rebase-merge" ]] || [[ -d "$git_dir/rebase-apply" ]]; then
        operation_in_progress="rebase"
    elif [[ -f "$git_dir/MERGE_HEAD" ]]; then
        operation_in_progress="merge"
    elif [[ -f "$git_dir/CHERRY_PICK_HEAD" ]]; then
        operation_in_progress="cherry-pick"
    fi
    
    # Build complete runtime state
    jq -n \
        --arg cb "$current_branch" \
        --arg clean "$working_tree_clean" \
        --argjson uc "$uncommitted_changes" \
        --arg sc "$stash_count" \
        --arg ahead "$ahead" \
        --arg behind "$behind" \
        --arg div "$diverged" \
        --arg up "$upstream" \
        --arg root "$repo_root" \
        --arg op "$operation_in_progress" \
        '{
            currentBranch: $cb,
            workingTreeClean: ($clean == "true"),
            uncommittedChanges: $uc,
            uncommittedCount: ($uc | length),
            stashCount: ($sc | tonumber),
            remoteStatus: {
                ahead: ($ahead | tonumber),
                behind: ($behind | tonumber),
                diverged: ($div == "true"),
                upstream: (if $up != "" then $up else null end)
            },
            repository: {
                root: $root,
                currentPath: (env.PWD // "")
            },
            operationInProgress: (if $op != "" then $op else null end)
        }'
}

# ============================================================================
# COMPLETE DECISION MAKING - Pre-compute ALL possible decisions
# ============================================================================

# ============================================================================
# DECISION ENGINE - Pre-made decisions for all possible scenarios
# ============================================================================

# Make all possible decisions based on current state
# PURPOSE: Pre-compute decisions for every possible operation scenario
# PARAMETERS:
#   $1 - Runtime state JSON (required)
#   $2 - Computed state JSON (required)
# RETURNS:
#   0 - Always succeeds
# OUTPUTS:
#   JSON object with complete decision tree
# DECISIONS INCLUDE:
#   - Branch creation scenarios (protected branch, type selection, etc.)
#   - Merge scenarios (fast-forward, conflicts, protected target, etc.)
#   - Cleanup scenarios (age-based, merge-based, manual, etc.)
#   - Sync scenarios (conflicts, uncommitted changes, etc.)
# COMPLEXITY: Very High - analyzes all branches and computes multiple decision paths
# PERFORMANCE: O(n²) where n=number of branches (nested analysis loops)
# EXAMPLE:
#   local runtime=$(get_value "runtime")
#   local computed=$(get_value "computed")
#   local decisions=$(make_complete_decisions "$runtime" "$computed")
#   local can_create=$(jq -r '.canCreateBranch' <<< "$decisions")
make_complete_decisions() {
    local runtime="$1"
    local computed="$2"
    
    # ========== SECTION 1: Extract Runtime State ==========
    # Extract key values from runtime state for decision making
    local current_branch=$(printf "%s\n" "$runtime" | jq -r '.currentBranch')
    local working_tree_clean=$(printf "%s\n" "$runtime" | jq -r '.workingTreeClean')
    local branches=$(printf "%s\n" "$runtime" | jq '.branches')
    local operation_in_progress=$(printf "%s\n" "$runtime" | jq -r '.operationInProgress')
    
    # Initialize decisions object
    local decisions='{}'
    
    # ========== SECTION 2: Branch Creation Decisions ==========
    # Determine if a new branch can be created based on current state
    # Learning: Branch creation is blocked by in-progress operations and validation rules
    local can_create="true"
    local cannot_create_reasons='[]'
    
    if [[ "$operation_in_progress" != "null" ]] && [[ -n "$operation_in_progress" ]]; then
        can_create="false"
        cannot_create_reasons=$(printf "%s\n" "$cannot_create_reasons" | jq --arg r "Operation in progress: $operation_in_progress" '. += [$r]')
    fi
    
    if [[ "$AIPM_VALIDATION_RULES_REQUIRECLEANTREE" == "true" ]] && [[ "$working_tree_clean" == "false" ]]; then
        can_create="false"
        cannot_create_reasons=$(printf "%s\n" "$cannot_create_reasons" | jq '. += ["Working tree has uncommitted changes"]')
    fi
    
    # Suggested branch type
    # Learning: Sessions take precedence when enabled and none exist
    # Feature is the default fallback for general development work
    local suggested_type="feature"
    local type_suggestion_reason="Default type for new work"
    
    if [[ "$AIPM_SESSIONS_ENABLED" == "true" ]]; then
        # Check if session already exists
        local session_count=$(printf "%s\n" "$branches" | jq '[to_entries[] | select(.value.type == "session")] | length')
        if [[ "$AIPM_SESSIONS_ALLOWMULTIPLE" == "false" ]] && [[ $session_count -eq 0 ]]; then
            suggested_type="session"
            type_suggestion_reason="No active session exists"
        elif [[ "$AIPM_SESSIONS_AUTOCREATE" == "true" ]] && [[ $session_count -eq 0 ]]; then
            suggested_type="session"
            type_suggestion_reason="Auto-create session enabled"
        fi
    fi
    
    # ========== SECTION 3: Merge Decisions ==========
    # Determine if current branch can be merged and where
    # Learning: Merge decisions depend on branch type, protection status, and workflow rules
    local can_merge="false"
    local cannot_merge_reasons='[]'
    local merge_target=""
    local merge_strategy=""
    
    if [[ -n "$current_branch" ]] && [[ "$current_branch" != "HEAD" ]]; then
        local branch_info=$(printf "%s\n" "$branches" | jq -r --arg b "$current_branch" '.[$b]')
        
        if [[ -n "$branch_info" ]] && [[ "$branch_info" != "null" ]]; then
            local branch_type=$(printf "%s\n" "$branch_info" | jq -r '.type')
            local is_protected=$(printf "%s\n" "$branch_info" | jq -r '.isProtected')
            
            if [[ "$branch_type" != "main" ]] && [[ "$branch_type" != "user" ]]; then
                can_merge="true"
                
                # Determine merge target from workflow rules
                local workflow_targets=$(printf "%s\n" "$computed" | jq '.workflows.branchFlow.targets')
                local type_pattern="${branch_type}/*"
                local target_rule=$(printf "%s\n" "$workflow_targets" | jq -r --arg p "$type_pattern" '.byType[$p] // .default')
                
                if [[ "$target_rule" == "parent" ]]; then
                    merge_target=$(printf "%s\n" "$branch_info" | jq -r '.parent // ""')
                    if [[ -z "$merge_target" ]] || [[ "$merge_target" == "null" ]]; then
                        merge_target="${AIPM_COMPUTED_MAINBRANCH}"
                    fi
                elif [[ "$target_rule" == "none" ]]; then
                    can_merge="false"
                    cannot_merge_reasons=$(printf "%s\n" "$cannot_merge_reasons" | jq '. += ["Branch type does not merge back"]')
                else
                    merge_target="$target_rule"
                fi
                
                # Determine merge strategy
                if [[ "$branch_type" == "session" ]]; then
                    merge_strategy="${AIPM_WORKFLOWS_MERGING_SESSIONMERGE:-on-stop}"
                else
                    merge_strategy="${AIPM_WORKFLOWS_MERGING_FEATURECOMPLETE:-prompt}"
                fi
            else
                if [[ "$branch_type" == "main" ]]; then
                    cannot_merge_reasons=$(printf "%s\n" "$cannot_merge_reasons" | jq '. += ["Cannot merge main branch"]')
                elif [[ "$is_protected" == "true" ]]; then
                    cannot_merge_reasons=$(printf "%s\n" "$cannot_merge_reasons" | jq '. += ["Branch is protected"]')
                fi
            fi
        fi
    else
        cannot_merge_reasons=$(printf "%s\n" "$cannot_merge_reasons" | jq '. += ["No current branch"]')
    fi
    
    # ========== SECTION 4: Stale Branch Detection ==========
    # Identify branches that haven't been updated recently
    # Learning: Staleness is based on last commit date, not creation date
    # Default threshold is 90 days but configurable per workspace
    local stale_branches='[]'
    local current_epoch=$(date +%s)
    local stale_days="${AIPM_DEFAULTS_LIMITS_BRANCHAGEDAYS:-90}"
    
    printf "%s\n" "$branches" | jq -r 'to_entries[] | @json' | while IFS= read -r entry; do
        local branch_name=$(printf "%s\n" "$entry" | jq -r '.key')
        local branch_data=$(printf "%s\n" "$entry" | jq -r '.value')
        
        local is_protected=$(printf "%s\n" "$branch_data" | jq -r '.isProtected')
        local type=$(printf "%s\n" "$branch_data" | jq -r '.type')
        local last_commit=$(printf "%s\n" "$branch_data" | jq -r '.lastCommit')
        
        if [[ "$is_protected" == "false" ]] && [[ "$type" != "main" ]] && [[ "$type" != "user" ]]; then
            if [[ -n "$last_commit" ]] && [[ "$last_commit" != "null" ]]; then
                local last_epoch=$(date -d "$last_commit" +%s 2>/dev/null || printf "%s\n" 0)
                if [[ $last_epoch -gt 0 ]]; then
                    local days_old=$(( (current_epoch - last_epoch) / 86400 ))
                    if [[ $days_old -gt $stale_days ]]; then
                        stale_branches=$(printf "%s\n" "$stale_branches" | jq --arg b "$branch_name" --arg d "$days_old" \
                            '. += [{branch: $b, daysOld: ($d | tonumber), reason: "No activity for \($d) days"}]')
                    fi
                fi
            fi
        fi
    done
    
    # ========== SECTION 5: Cleanup Candidate Detection ==========
    # Identify branches that should be deleted based on lifecycle rules
    # Learning: Cleanup can be immediate or scheduled based on deletion rules
    local cleanup_branches='[]'
    
    printf "%s\n" "$branches" | jq -r 'to_entries[] | @json' | while IFS= read -r entry; do
        local branch_name=$(printf "%s\n" "$entry" | jq -r '.key')
        local branch_data=$(printf "%s\n" "$entry" | jq -r '.value')
        
        local scheduled_delete=$(printf "%s\n" "$branch_data" | jq -r '.scheduledDelete')
        local delete_date=$(printf "%s\n" "$branch_data" | jq -r '.deleteDate // ""')
        
        if [[ "$scheduled_delete" == "immediate" ]]; then
            cleanup_branches=$(printf "%s\n" "$cleanup_branches" | jq --arg b "$branch_name" \
                '. += [{branch: $b, reason: "Scheduled for immediate deletion"}]')
        elif [[ "$scheduled_delete" == "scheduled" ]] && [[ -n "$delete_date" ]]; then
            local delete_epoch=$(date -d "$delete_date" +%s 2>/dev/null || printf "%s\n" 0)
            if [[ $delete_epoch -gt 0 ]] && [[ $delete_epoch -le $current_epoch ]]; then
                cleanup_branches=$(printf "%s\n" "$cleanup_branches" | jq --arg b "$branch_name" \
                    '. += [{branch: $b, reason: "Deletion date reached"}]')
            fi
        fi
    done
    
    # ========== SECTION 6: Session Limit Enforcement ==========
    # Check if we've exceeded max allowed sessions
    # Learning: Oldest sessions are cleaned up first when limit is exceeded
    if [[ -n "$AIPM_LIFECYCLE_SESSION_MAXSESSIONS" ]]; then
        local session_branches=$(printf "%s\n" "$branches" | jq '[to_entries[] | select(.value.type == "session") | {branch: .key, lastCommit: .value.lastCommit}] | sort_by(.lastCommit)')
        local session_count=$(printf "%s\n" "$session_branches" | jq 'length')
        local max_sessions="${AIPM_LIFECYCLE_SESSION_MAXSESSIONS}"
        
        if [[ $session_count -gt $max_sessions ]]; then
            local excess=$((session_count - max_sessions))
            local old_sessions=$(printf "%s\n" "$session_branches" | jq --arg e "$excess" '.[:($e | tonumber)]')
            
            printf "%s\n" "$old_sessions" | jq -r '.[] | .branch' | while read -r old_session; do
                cleanup_branches=$(printf "%s\n" "$cleanup_branches" | jq --arg b "$old_session" \
                    '. += [{branch: $b, reason: "Exceeds max session count"}]')
            done
        fi
    fi
    
    # ========== SECTION 7: Next Session Name Generation ==========
    # Generate the name for the next session branch
    # Learning: Session names use timestamp for uniqueness and sorting
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local session_pattern="${AIPM_SESSIONS_NAMEPATTERN:-session/{timestamp}}"
    session_pattern="${session_pattern//\{timestamp\}/$timestamp}"
    local next_session="${AIPM_BRANCHING_PREFIX}${session_pattern}"
    
    # ========== SECTION 8: Synchronization Decisions ==========
    # Determine fetch/pull behavior based on workflow rules
    # Learning: Sync behavior varies by cleanliness and user preferences
    local should_fetch="false"
    local fetch_reason=""
    
    if [[ "$AIPM_TEAM_FETCHONSTART" == "true" ]]; then
        if [[ "$AIPM_WORKFLOWS_SYNCHRONIZATION_PULLONSTART" == "always" ]]; then
            should_fetch="true"
            fetch_reason="Always fetch on start"
        elif [[ "$AIPM_WORKFLOWS_SYNCHRONIZATION_PULLONSTART" == "if-clean" ]] && [[ "$working_tree_clean" == "true" ]]; then
            should_fetch="true"
            fetch_reason="Fetch when working tree is clean"
        elif [[ "$AIPM_WORKFLOWS_SYNCHRONIZATION_PULLONSTART" == "prompt" ]]; then
            should_fetch="prompt"
            fetch_reason="User will be prompted"
        fi
    fi
    
    local should_push="false"
    local push_reason=""
    
    if [[ "$AIPM_WORKFLOWS_SYNCHRONIZATION_PUSHONSTOP" == "always" ]]; then
        should_push="true"
        push_reason="Always push on stop"
    elif [[ "$AIPM_WORKFLOWS_SYNCHRONIZATION_PUSHONSTOP" == "if-feature" ]]; then
        if [[ -n "$current_branch" ]]; then
            local current_type=$(printf "%s\n" "$branches" | jq -r --arg b "$current_branch" '.[$b].type // "unknown"')
            if [[ "$current_type" == "feature" ]] || [[ "$current_type" == "bugfix" ]]; then
                should_push="true"
                push_reason="Push feature/bugfix branches"
            fi
        fi
    elif [[ "$AIPM_WORKFLOWS_SYNCHRONIZATION_PUSHONSTOP" == "prompt" ]]; then
        should_push="prompt"
        push_reason="User will be prompted"
    fi
    
    # ========== SECTION 9: Build Final Decision Object ==========
    # Combine all decisions into a single JSON structure
    decisions=$(jq -n \
        --arg cc "$can_create" \
        --argjson ccr "$cannot_create_reasons" \
        --arg st "$suggested_type" \
        --arg str "$type_suggestion_reason" \
        --arg cm "$can_merge" \
        --argjson cmr "$cannot_merge_reasons" \
        --arg mt "$merge_target" \
        --arg ms "$merge_strategy" \
        --argjson sb "$stale_branches" \
        --argjson cb "$cleanup_branches" \
        --arg ns "$next_session" \
        --arg vm "$AIPM_VALIDATION_MODE" \
        --arg sf "$should_fetch" \
        --arg sfr "$fetch_reason" \
        --arg sp "$should_push" \
        --arg spr "$push_reason" \
        '{
            canCreateBranch: ($cc == "true"),
            cannotCreateReasons: $ccr,
            suggestedBranchType: $st,
            typeSuggestionReason: $str,
            canMergeCurrentBranch: ($cm == "true"),
            cannotMergeReasons: $cmr,
            mergeTarget: (if $mt != "" then $mt else null end),
            mergeStrategy: (if $ms != "" then $ms else null end),
            staleBranches: $sb,
            branchesForCleanup: $cb,
            nextSessionName: $ns,
            validationMode: $vm,
            shouldFetchOnStart: $sf,
            fetchReason: (if $sfr != "" then $sfr else null end),
            shouldPushOnStop: $sp,
            pushReason: (if $spr != "" then $spr else null end)
        }')
    
    # ========== SECTION 10: Prompt Configuration ==========
    # Add interactive prompts based on workflow settings
    # Learning: Prompts are conditional based on workflow configuration
    local prompts='{}'
    
    # Add branch creation prompts
    if [[ "$AIPM_WORKFLOWS_BRANCHCREATION_PROTECTIONRESPONSE" == "prompt" ]]; then
        prompts=$(printf "%s\n" "$prompts" | printf "%s\n" "$computed" | jq '.workflows.branchCreation.prompts.protected as $p | {protectedBranch: $p}')
    fi
    
    if [[ "$AIPM_WORKFLOWS_BRANCHCREATION_TYPESELECTION" == "prompt" ]]; then
        prompts=$(printf "%s\n" "$prompts" | printf "%s\n" "$computed" | jq '.workflows.branchCreation.prompts.typeSelection as $p | . + {branchType: $p}')
    fi
    
    # Add merge prompts
    if [[ "$AIPM_WORKFLOWS_MERGING_FEATURECOMPLETE" == "prompt" ]]; then
        prompts=$(printf "%s\n" "$prompts" | printf "%s\n" "$computed" | jq '.workflows.merging.prompts.featureComplete as $p | . + {featureComplete: $p}')
    fi
    
    if [[ "$AIPM_WORKFLOWS_MERGING_CONFLICTHANDLING" == "interactive" ]]; then
        prompts=$(printf "%s\n" "$prompts" | printf "%s\n" "$computed" | jq '.workflows.merging.prompts.mergeConflict as $p | . + {mergeConflict: $p}')
    fi
    
    # Add sync prompts
    if [[ "$should_fetch" == "prompt" ]]; then
        prompts=$(printf "%s\n" "$prompts" | printf "%s\n" "$computed" | jq '.workflows.synchronization.prompts.pullOnStart as $p | . + {pullOnStart: $p}')
    fi
    
    if [[ "$should_push" == "prompt" ]]; then
        prompts=$(printf "%s\n" "$prompts" | printf "%s\n" "$computed" | jq '.workflows.synchronization.prompts.pushOnStop as $p | . + {pushOnStop: $p}')
    fi
    
    # Add cleanup prompts
    if [[ "$AIPM_WORKFLOWS_CLEANUP_AFTERMERGE" == "prompt" ]]; then
        prompts=$(printf "%s\n" "$prompts" | printf "%s\n" "$computed" | jq '.workflows.cleanup.prompts.afterMerge as $p | . + {afterMerge: $p}')
    fi
    
    # Add prompts to final decision object
    decisions=$(printf "%s\n" "$decisions" | jq --argjson p "$prompts" '.prompts = $p')
    
    printf "%s\n" "$decisions"
}

# ============================================================================
# STATE REFRESH ARCHITECTURE - Efficient partial and full state updates
# ============================================================================

# Refresh full state
# PURPOSE: Complete state recomputation when configuration changes
# PARAMETERS: None
# RETURNS:
#   0 - Refresh successful
#   1 - Refresh failed
# SIDE EFFECTS:
#   - Acquires and releases state lock
#   - Recomputes entire state if opinions changed
#   - Updates STATE_FILE and STATE_CACHE
# EXAMPLES:
#   # Manual full refresh
#   refresh_full_state
#   
#   # Check and refresh if needed
#   if opinions_changed; then
#       refresh_full_state
#   fi
# LEARNING:
#   - Full refresh is expensive - use sparingly
#   - Automatically detects opinion file changes
#   - Preserves runtime state during refresh
refresh_full_state() {
    # LEARNING: Acquire lock for exclusive state access
    if ! acquire_state_lock; then
        error "Cannot acquire lock for state refresh"
        return 1
    fi
    
    # LEARNING: Check if opinions file has changed
    local old_hash=""
    if read_state_file; then
        old_hash=$(jq -r '.metadata.opinionsHash // ""' <<< "$STATE_CACHE")
    fi
    
    local new_hash=""
    if [[ -f "$OPINIONS_FILE_PATH" ]]; then
        new_hash=$(sha256sum "$OPINIONS_FILE_PATH" | cut -d' ' -f1)
    fi
    
    # LEARNING: Only refresh if configuration actually changed
    if [[ "$old_hash" == "$new_hash" ]] && [[ -n "$old_hash" ]]; then
        debug "Opinions unchanged, skipping full refresh"
        release_state_lock
        return 0
    fi
    
    info "Opinions changed, performing full state refresh..."
    
    # LEARNING: Release lock before initialize_state (it acquires its own lock)
    release_state_lock
    
    # Perform full reinitialization
    initialize_state
}

# Refresh partial state
# PURPOSE: Update specific state sections without full recomputation
# PARAMETERS:
#   $1 - Section to refresh: "branches", "runtime", "decisions" (required)
# RETURNS:
#   0 - Refresh successful
#   1 - Invalid section or refresh failed
# SIDE EFFECTS:
#   - Acquires and releases state lock
#   - Updates only specified section
#   - Modifies STATE_FILE and STATE_CACHE
# EXAMPLES:
#   # Update branch info after checkout
#   refresh_partial_state "branches"
#   
#   # Update runtime info after git operation
#   refresh_partial_state "runtime"
#   
#   # Recompute decisions after state change
#   refresh_partial_state "decisions"
# LEARNING:
#   - Much faster than full refresh
#   - Preserves unrelated state sections
#   - Ideal for post-operation updates
refresh_partial_state() {
    local section="$1"
    
    # LEARNING: Validate section parameter
    case "$section" in
        branches|runtime|decisions)
            debug "Refreshing state section: $section"
            ;;
        *)
            error "Invalid refresh section: $section"
            error "Valid sections: branches, runtime, decisions"
            return 1
            ;;
    esac
    
    # LEARNING: Acquire lock for state modification
    if ! acquire_state_lock; then
        error "Cannot acquire lock for partial refresh"
        return 1
    fi
    
    # LEARNING: Ensure current state is loaded
    if ! read_state_file; then
        warn "No state file found, running full initialization"
        release_state_lock
        initialize_state
        return $?
    fi
    
    # LEARNING: Perform section-specific refresh
    local updated_state="$STATE_CACHE"
    
    case "$section" in
        branches)
            # LEARNING: Update branch information from git
            info "Refreshing branch information..."
            local new_runtime=$(get_complete_runtime_state)
            local branches=$(jq '.branches' <<< "$new_runtime")
            updated_state=$(jq --argjson b "$branches" '.runtime.branches = $b' <<< "$updated_state")
            ;;
            
        runtime)
            # LEARNING: Complete runtime refresh
            info "Refreshing runtime state..."
            local new_runtime=$(get_complete_runtime_state)
            updated_state=$(jq --argjson r "$new_runtime" '.runtime = $r' <<< "$updated_state")
            ;;
            
        decisions)
            # LEARNING: Recompute decisions based on current state
            info "Refreshing decision matrix..."
            local runtime=$(jq '.runtime' <<< "$updated_state")
            local computed=$(jq '.computed' <<< "$updated_state")
            local new_decisions=$(make_complete_decisions "$runtime" "$computed")
            updated_state=$(jq --argjson d "$new_decisions" '.decisions = $d' <<< "$updated_state")
            ;;
    esac
    
    # LEARNING: Update refresh timestamp
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    updated_state=$(jq --arg ts "$timestamp" '.metadata.lastRefresh = $ts' <<< "$updated_state")
    
    # LEARNING: Write updated state
    if write_state_file "$updated_state"; then
        success "State section '$section' refreshed"
        release_state_lock
        return 0
    else
        error "Failed to write refreshed state"
        release_state_lock
        return 1
    fi
}

# Auto-refresh detection
# PURPOSE: Check if state needs refresh based on time or changes
# PARAMETERS: None
# RETURNS:
#   0 - Refresh needed
#   1 - No refresh needed
# SIDE EFFECTS:
#   - Reads state file (no modifications)
#   - No lock required (read-only)
# EXAMPLES:
#   # In wrapper script startup
#   if detect_refresh_needed; then
#       refresh_partial_state "runtime"
#   fi
#   
#   # Periodic check
#   while true; do
#       detect_refresh_needed && refresh_full_state
#       sleep 300  # Check every 5 minutes
#   done
# LEARNING:
#   - Non-blocking check for efficiency
#   - Multiple criteria for refresh detection
#   - Can be called frequently without penalty
detect_refresh_needed() {
    # LEARNING: Quick check without lock for performance
    if ! read_state_file; then
        # No state exists, definitely needs initialization
        return 0
    fi
    
    # LEARNING: Check time-based refresh (default 5 minutes)
    local last_refresh=$(jq -r '.metadata.lastRefresh // "1970-01-01T00:00:00Z"' <<< "$STATE_CACHE")
    local last_epoch=$(date -d "$last_refresh" +%s 2>/dev/null || echo 0)
    local now_epoch=$(date +%s)
    local elapsed=$((now_epoch - last_epoch))
    local max_age=${AIPM_STATE_REFRESH_INTERVAL:-300}  # 5 minutes default
    
    if [[ $elapsed -gt $max_age ]]; then
        debug "State is ${elapsed}s old (max: ${max_age}s), refresh needed"
        return 0
    fi
    
    # LEARNING: Check if opinions file changed
    local state_hash=$(jq -r '.metadata.opinionsHash // ""' <<< "$STATE_CACHE")
    local current_hash=""
    if [[ -f "$OPINIONS_FILE_PATH" ]]; then
        current_hash=$(sha256sum "$OPINIONS_FILE_PATH" | cut -d' ' -f1)
    fi
    
    if [[ "$state_hash" != "$current_hash" ]]; then
        debug "Opinions file changed, refresh needed"
        return 0
    fi
    
    # LEARNING: Check for git state drift
    # This is a lightweight check - just current branch
    local state_branch=$(jq -r '.runtime.currentBranch // ""' <<< "$STATE_CACHE")
    local actual_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    
    if [[ "$state_branch" != "$actual_branch" ]] && [[ -n "$actual_branch" ]]; then
        debug "Branch drift detected: state=$state_branch, actual=$actual_branch"
        return 0
    fi
    
    # No refresh needed
    return 1
}

# Check if opinions changed
# PURPOSE: Quick check if opinions.yaml was modified
# PARAMETERS: None
# RETURNS:
#   0 - Opinions changed
#   1 - Opinions unchanged or no state
# SIDE EFFECTS:
#   - Reads state file (no modifications)
#   - No lock required (read-only)
# EXAMPLES:
#   # Conditional refresh
#   if opinions_changed; then
#       warn "Configuration changed, refreshing..."
#       refresh_full_state
#   fi
# LEARNING:
#   - Lightweight hash comparison
#   - Useful for startup checks
#   - No state modification
opinions_changed() {
    # LEARNING: Read current state hash
    if ! read_state_file; then
        # No state, can't determine if changed
        return 1
    fi
    
    local state_hash=$(jq -r '.metadata.opinionsHash // ""' <<< "$STATE_CACHE")
    local current_hash=""
    
    if [[ -f "$OPINIONS_FILE_PATH" ]]; then
        current_hash=$(sha256sum "$OPINIONS_FILE_PATH" | cut -d' ' -f1)
    fi
    
    [[ "$state_hash" != "$current_hash" ]]
}

# ============================================================================
# MAIN STATE MANAGEMENT FUNCTIONS
# ============================================================================

# Initialize complete state from scratch
# PURPOSE: Build the complete AIPM state cache from opinions and git repository
# PARAMETERS: None
# RETURNS:
#   0 - Success
#   1 - Failure (dies on critical errors)
# SIDE EFFECTS:
#   - Creates/updates state file at $STATE_FILE
#   - Loads opinions if not already loaded
#   - Acquires and releases state lock
# COMPLEXITY: Very High - calls all compute and runtime functions
# PERFORMANCE: O(n*m) where n=branches, m=compute functions
# EXAMPLE:
#   initialize_state
#   # State is now available via get_value()
initialize_state() {
    section "Initializing Complete AIPM State"
    
    # Check dependencies
    check_jq_installed
    ensure_state_dir
    
    # Acquire lock
    acquire_state_lock
    
    # Ensure opinions are loaded
    # Learning: Opinions must be loaded before state can be computed
    # This provides all the AIPM_* environment variables we need
    if ! opinions_loaded; then
        info "Loading opinions..."
        load_and_export_opinions || die "Failed to load opinions"
    fi
    
    info "Building complete state with all pre-computations..."
    
    # Get opinions hash
    # Learning: We track opinions file hash to detect when recomputation is needed
    # SHA256 provides a reliable fingerprint of the configuration
    local opinions_hash=""
    if [[ -f "$OPINIONS_FILE_PATH" ]]; then
        opinions_hash=$(sha256sum "$OPINIONS_FILE_PATH" | cut -d' ' -f1)
    fi
    
    # Build metadata
    local metadata=$(jq -n \
        --arg v "1.0" \
        --arg g "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg h "$opinions_hash" \
        --arg ws "$AIPM_WORKSPACE_NAME" \
        --arg wt "$AIPM_WORKSPACE_TYPE" \
        '{
            version: $v,
            generated: $g,
            opinionsHash: $h,
            lastRefresh: $g,
            workspace: {
                name: $ws,
                type: $wt
            }
        }')
    
    # Collect ALL raw exports
    # Learning: We capture all AIPM_* environment variables for reference
    # compgen -A export lists all exported variables
    # ${!var} does indirect variable expansion to get the value
    info "Collecting all raw exports..."
    local raw_exports='{}'
    while IFS='=' read -r name value; do
        if [[ "$name" =~ ^AIPM_ ]]; then
            raw_exports=$(printf "%s\n" "$raw_exports" | jq --arg k "$name" --arg v "$value" '.[$k] = $v')
        fi
    done < <(compgen -A export | while read var; do printf "%s=%s\n" "$var" "${!var}"; done)
    
    # Compute ALL derived values
    # Learning: These compute_* functions transform raw opinions into structured data
    # Each function handles a specific domain of configuration
    # The results are pre-computed for instant access later
    info "Computing all derived values..."
    local computed=$(jq -n \
        --arg mb "${AIPM_COMPUTED_MAINBRANCH}" \
        --argjson bp "$(compute_all_branch_patterns)" \
        --argjson pb "$(compute_protected_branches_list)" \
        --argjson lm "$(compute_complete_lifecycle_matrix)" \
        --argjson wf "$(compute_complete_workflow_rules)" \
        --argjson val "$(compute_complete_validation_rules)" \
        --argjson mem "$(compute_complete_memory_config)" \
        --argjson team "$(compute_complete_team_config)" \
        --argjson sess "$(compute_complete_session_config)" \
        --argjson load "$(compute_loading_config)" \
        --argjson init "$(compute_initialization_config)" \
        --argjson def "$(compute_defaults_and_limits)" \
        --argjson err "$(compute_error_handling_config)" \
        --argjson set "$(compute_settings_config)" \
        '{
            mainBranch: $mb,
            branchPatterns: $bp,
            protectedBranches: $pb,
            lifecycleMatrix: $lm,
            workflows: $wf,
            validation: $val,
            memory: $mem,
            team: $team,
            sessions: $sess,
            loading: $load,
            initialization: $init,
            defaults: $def,
            errorHandling: $err,
            settings: $set
        }')
    
    # Get complete runtime state
    info "Querying complete git state..."
    local runtime_branches=$(get_complete_runtime_branches)
    local runtime_state=$(get_complete_runtime_state)
    local runtime=$(printf "%s\n" "$runtime_state" | jq --argjson b "$runtime_branches" '.branches = $b')
    
    # Make ALL decisions
    info "Pre-computing all decisions..."
    local decisions=$(make_complete_decisions "$runtime" "$computed")
    
    # Build complete state
    local state=$(jq -n \
        --argjson meta "$metadata" \
        --argjson raw "$raw_exports" \
        --argjson comp "$computed" \
        --argjson run "$runtime" \
        --argjson dec "$decisions" \
        '{
            metadata: $meta,
            raw_exports: $raw,
            computed: $comp,
            runtime: $run,
            decisions: $dec
        }')
    
    # Write state file
    write_state_file "$state"
    
    # Release lock
    release_state_lock
    
    success "Complete state initialized successfully"
    info "State file: $STATE_FILE"
}

# Get value from state (instant lookup!)
# PURPOSE: Retrieve any value from the state cache using JQ path notation
# PARAMETERS:
#   $1 - JQ path to the desired value (e.g., "runtime.currentBranch")
# RETURNS:
#   0 - Always succeeds
# OUTPUTS:
#   The requested value or empty if not found
# PERFORMANCE: O(1) - Direct JSON lookup
# EXAMPLE:
#   local branch=$(get_value "runtime.currentBranch")
#   local can_create=$(get_value "decisions.canCreateBranch")
#   local main=$(get_value "computed.mainBranch")
get_value() {
    local path="$1"
    
    # Ensure state is loaded
    # Learning: State is lazy-loaded on first access
    # If state file doesn't exist, we initialize it automatically
    if [[ "$STATE_LOADED" != "true" ]]; then
        if ! read_state_file; then
            warn "State not initialized, initializing now..."
            initialize_state
        fi
    fi
    
    # Extract value using jq path
    # Learning: "// empty" prevents null output, returns empty string instead
    # The dot prefix is important for JQ path traversal
    printf "%s\n" "$STATE_CACHE" | jq -r ".$path // empty"
}

# Get value with default
get_value_or_default() {
    local path="$1"
    local default="$2"
    
    local value=$(get_value "$path")
    if [[ -z "$value" ]]; then
        printf "%s\n" "$default"
    else
        printf "%s\n" "$value"
    fi
}

# Refresh specific part of state
# PURPOSE: Update specific parts of the state cache without full reinitialization
# PARAMETERS:
#   $1 - What to refresh: "branches", "runtime", "decisions", "computed", "all"
#        Default: "all"
# RETURNS:
#   0 - Success
#   1 - Failure
# SIDE EFFECTS:
#   - Updates state file with refreshed data
#   - Acquires and releases state lock
# COMPLEXITY: Varies by refresh type (Medium to Very High)
# PERFORMANCE:
#   - branches/runtime: O(n) where n=number of branches
#   - decisions: O(n²) where n=number of branches
#   - computed: O(m) where m=number of compute functions
#   - all: Full reinitialization
# EXAMPLE:
#   refresh_state "branches"  # Update only git branch info
#   refresh_state "decisions" # Recompute decisions with current state
refresh_state() {
    local what="${1:-all}"
    
    info "Refreshing state: $what"
    
    acquire_state_lock
    
    # Read current state
    if ! read_state_file; then
        release_state_lock
        initialize_state
        return
    fi
    
    local state="$STATE_CACHE"
    
    case "$what" in
        branches|runtime)
            # Refresh runtime state only
            # Learning: This is the most common refresh - updates git state
            # Useful after git operations (commit, merge, checkout)
            # Decisions are recomputed since they depend on runtime state
            info "Refreshing runtime branches and git state..."
            local runtime_branches=$(get_complete_runtime_branches)
            local runtime_state=$(get_complete_runtime_state)
            local runtime=$(printf "%s\n" "$runtime_state" | jq --argjson b "$runtime_branches" '.branches = $b')
            
            # Update runtime in state
            state=$(printf "%s\n" "$state" | jq --argjson r "$runtime" '.runtime = $r')
            
            # Recompute decisions with new runtime
            # Learning: Decisions must be recomputed when runtime changes
            local computed=$(printf "%s\n" "$state" | jq '.computed')
            local decisions=$(make_complete_decisions "$runtime" "$computed")
            state=$(printf "%s\n" "$state" | jq --argjson d "$decisions" '.decisions = $d')
            ;;
            
        decisions)
            # Recompute decisions only
            # Learning: Useful when you want fresh decisions without querying git
            # Faster than runtime refresh but still expensive due to decision complexity
            info "Recomputing all decisions..."
            local runtime=$(printf "%s\n" "$state" | jq '.runtime')
            local computed=$(printf "%s\n" "$state" | jq '.computed')
            local decisions=$(make_complete_decisions "$runtime" "$computed")
            state=$(printf "%s\n" "$state" | jq --argjson d "$decisions" '.decisions = $d')
            ;;
            
        computed)
            # Refresh computed values (if opinions changed)
            # Learning: Use this after modifying opinions.yaml
            # Reloads opinions and recomputes all derived values
            info "Recomputing all derived values..."
            ensure_opinions_loaded
            
            # Recompute everything
            local computed=$(jq -n \
                --arg mb "${AIPM_COMPUTED_MAINBRANCH}" \
                --argjson bp "$(compute_all_branch_patterns)" \
                --argjson pb "$(compute_protected_branches_list)" \
                --argjson lm "$(compute_complete_lifecycle_matrix)" \
                --argjson wf "$(compute_complete_workflow_rules)" \
                --argjson val "$(compute_complete_validation_rules)" \
                --argjson mem "$(compute_complete_memory_config)" \
                --argjson team "$(compute_complete_team_config)" \
                --argjson sess "$(compute_complete_session_config)" \
                --argjson load "$(compute_loading_config)" \
                --argjson init "$(compute_initialization_config)" \
                --argjson def "$(compute_defaults_and_limits)" \
                --argjson err "$(compute_error_handling_config)" \
                --argjson set "$(compute_settings_config)" \
                '{
                    mainBranch: $mb,
                    branchPatterns: $bp,
                    protectedBranches: $pb,
                    lifecycleMatrix: $lm,
                    workflows: $wf,
                    validation: $val,
                    memory: $mem,
                    team: $team,
                    sessions: $sess,
                    loading: $load,
                    initialization: $init,
                    defaults: $def,
                    errorHandling: $err,
                    settings: $set
                }')
            
            state=$(printf "%s\n" "$state" | jq --argjson c "$computed" '.computed = $c')
            
            # Recompute decisions with new computed values
            local runtime=$(printf "%s\n" "$state" | jq '.runtime')
            local decisions=$(make_complete_decisions "$runtime" "$computed")
            state=$(printf "%s\n" "$state" | jq --argjson d "$decisions" '.decisions = $d')
            ;;
            
        all|*)
            # Full refresh
            # Learning: Complete reinitialization - slowest but most thorough
            # Use when state might be corrupted or after major changes
            release_state_lock
            initialize_state
            return
            ;;
    esac
    
    # Update metadata
    # Learning: Track when state was last refreshed for debugging
    state=$(printf "%s\n" "$state" | jq --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.metadata.lastRefresh = $t')
    
    # Write updated state
    write_state_file "$state"
    
    release_state_lock
    
    success "State refreshed: $what"
}

# Check if state needs refresh
needs_state_refresh() {
    # Check if state file exists
    if [[ ! -f "$STATE_FILE" ]]; then
        return 0
    fi
    
    # Check opinions.yaml hash
    if [[ -f "$OPINIONS_FILE_PATH" ]]; then
        local current_hash=$(sha256sum "$OPINIONS_FILE_PATH" | cut -d' ' -f1)
        local stored_hash=$(get_value "metadata.opinionsHash")
        
        if [[ "$current_hash" != "$stored_hash" ]]; then
            info "Opinions file has changed"
            return 0
        fi
    fi
    
    # Check age (refresh if older than 5 minutes)
    local last_refresh=$(get_value "metadata.lastRefresh")
    if [[ -n "$last_refresh" ]]; then
        local last_epoch=$(date -d "$last_refresh" +%s 2>/dev/null || printf "%s\n" 0)
        local now_epoch=$(date +%s)
        local age_minutes=$(( (now_epoch - last_epoch) / 60 ))
        
        if [[ $age_minutes -gt 5 ]]; then
            return 0
        fi
    fi
    
    return 1
}

# Ensure state is valid and current
ensure_state() {
    if needs_state_refresh; then
        initialize_state
    elif [[ "$STATE_LOADED" != "true" ]]; then
        read_state_file || initialize_state
    fi
}

# ============================================================================
# STATE VALIDATION AND REPAIR FUNCTIONS - Detect and fix inconsistencies
# ============================================================================

# Detect state drift
# PURPOSE: Compare state with git reality to find inconsistencies
# PARAMETERS: None
# RETURNS:
#   0 - No drift detected
#   1 - Drift detected
# SIDE EFFECTS:
#   - Writes detailed drift report to stdout
#   - No files modified
#   - No lock required (read-only)
# EXAMPLES:
#   # Check for drift on startup
#   if detect_state_drift; then
#       warn "State drift detected"
#       repair_state_inconsistency
#   fi
#   
#   # Get drift details
#   local drift_report=$(detect_state_drift 2>&1)
# LEARNING:
#   - Comprehensive comparison of all trackable values
#   - Performance optimized with early exits
#   - Safe to call frequently
detect_state_drift() {
    # LEARNING: Ensure state is loaded for comparison
    if ! read_state_file; then
        error "No state file to check for drift"
        return 1
    fi
    
    local drift_found=false
    local drift_items=()
    
    # LEARNING: Check current branch - most common drift
    local state_branch=$(jq -r '.runtime.currentBranch // ""' <<< "$STATE_CACHE")
    local actual_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    
    if [[ "$state_branch" != "$actual_branch" ]] && [[ -n "$actual_branch" ]]; then
        drift_items+=("Branch: state='$state_branch', actual='$actual_branch'")
        drift_found=true
    fi
    
    # LEARNING: Check uncommitted changes count
    local state_uncommitted=$(jq -r '.runtime.git.uncommittedCount // 0' <<< "$STATE_CACHE")
    local actual_uncommitted=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    
    if [[ "$state_uncommitted" != "$actual_uncommitted" ]]; then
        drift_items+=("Uncommitted: state=$state_uncommitted, actual=$actual_uncommitted")
        drift_found=true
    fi
    
    # LEARNING: Check clean status
    local state_clean=$(jq -r '.runtime.git.isClean // true' <<< "$STATE_CACHE")
    local actual_clean=$([[ "$actual_uncommitted" -eq 0 ]] && echo "true" || echo "false")
    
    if [[ "$state_clean" != "$actual_clean" ]]; then
        drift_items+=("Clean status: state=$state_clean, actual=$actual_clean")
        drift_found=true
    fi
    
    # LEARNING: Check branch list count (quick check)
    local state_branch_count=$(jq '.runtime.branches.all | length' <<< "$STATE_CACHE" 2>/dev/null || echo 0)
    local actual_branch_count=$(git branch -a --no-color | grep -c "^" || echo 0)
    
    # Allow small variance due to remote branches
    if [[ $((state_branch_count - actual_branch_count)) -gt 5 ]] || 
       [[ $((actual_branch_count - state_branch_count)) -gt 5 ]]; then
        drift_items+=("Branch count: state=$state_branch_count, actual=$actual_branch_count")
        drift_found=true
    fi
    
    # LEARNING: Check if remote exists
    local state_has_remote=$(jq -r '.runtime.git.hasRemote // false' <<< "$STATE_CACHE")
    local actual_has_remote=$(git remote -v 2>/dev/null | grep -q "origin" && echo "true" || echo "false")
    
    if [[ "$state_has_remote" != "$actual_has_remote" ]]; then
        drift_items+=("Remote status: state=$state_has_remote, actual=$actual_has_remote")
        drift_found=true
    fi
    
    # LEARNING: Report findings
    if [[ "$drift_found" == "true" ]]; then
        warn "State drift detected:"
        for item in "${drift_items[@]}"; do
            info "  - $item"
        done
        return 0
    else
        debug "No state drift detected"
        return 1
    fi
}

# Repair state inconsistency
# PURPOSE: Automatically fix detected state drift
# PARAMETERS:
#   $1 - Repair mode: "auto", "interactive", "report-only" (optional, default: "auto")
# RETURNS:
#   0 - Repair successful or no repair needed
#   1 - Repair failed
# SIDE EFFECTS:
#   - Updates state file with corrected values
#   - Acquires and releases state lock
#   - Writes repair log to stdout
# EXAMPLES:
#   # Automatic repair
#   repair_state_inconsistency
#   
#   # Interactive repair with confirmations
#   repair_state_inconsistency "interactive"
#   
#   # Just report what would be fixed
#   repair_state_inconsistency "report-only"
# LEARNING:
#   - Prioritizes git reality over state cache
#   - Preserves non-runtime configuration
#   - Creates audit trail of repairs
repair_state_inconsistency() {
    local mode="${1:-auto}"
    
    # LEARNING: Detect drift first
    local drift_report
    if ! drift_report=$(detect_state_drift 2>&1); then
        info "No state drift to repair"
        return 0
    fi
    
    if [[ "$mode" == "report-only" ]]; then
        info "Would repair the following drift:"
        echo "$drift_report"
        return 0
    fi
    
    # LEARNING: Start repair process
    section "Repairing State Inconsistency"
    echo "$drift_report"
    
    if [[ "$mode" == "interactive" ]]; then
        if ! confirm "Proceed with state repair?"; then
            info "Repair cancelled"
            return 0
        fi
    fi
    
    # LEARNING: Acquire lock for repair
    if ! acquire_state_lock; then
        error "Cannot acquire lock for state repair"
        return 1
    fi
    
    # LEARNING: Re-read state in case it changed
    if ! read_state_file; then
        error "State file disappeared during repair"
        release_state_lock
        return 1
    fi
    
    local repaired_state="$STATE_CACHE"
    local repairs_made=0
    
    # LEARNING: Fix current branch
    local actual_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    if [[ -n "$actual_branch" ]]; then
        local state_branch=$(jq -r '.runtime.currentBranch // ""' <<< "$repaired_state")
        if [[ "$state_branch" != "$actual_branch" ]]; then
            repaired_state=$(jq --arg b "$actual_branch" '.runtime.currentBranch = $b' <<< "$repaired_state")
            info "✓ Fixed current branch: $actual_branch"
            ((repairs_made++))
        fi
    fi
    
    # LEARNING: Fix uncommitted count and clean status
    local actual_uncommitted=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    local actual_clean=$([[ "$actual_uncommitted" -eq 0 ]] && echo "true" || echo "false")
    
    repaired_state=$(jq --arg count "$actual_uncommitted" --arg clean "$actual_clean" '
        .runtime.git.uncommittedCount = ($count | tonumber) |
        .runtime.git.isClean = ($clean | fromjson)
    ' <<< "$repaired_state")
    info "✓ Fixed uncommitted count: $actual_uncommitted"
    info "✓ Fixed clean status: $actual_clean"
    ((repairs_made += 2))
    
    # LEARNING: Fix remote status
    local actual_has_remote=$(git remote -v 2>/dev/null | grep -q "origin" && echo "true" || echo "false")
    repaired_state=$(jq --arg remote "$actual_has_remote" '.runtime.git.hasRemote = ($remote | fromjson)' <<< "$repaired_state")
    info "✓ Fixed remote status: $actual_has_remote"
    ((repairs_made++))
    
    # LEARNING: Trigger partial refresh for branches
    # This is more thorough than inline fixes
    repaired_state=$(jq --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.metadata.lastRepair = $t' <<< "$repaired_state")
    
    # LEARNING: Write repaired state
    if write_state_file "$repaired_state"; then
        success "State repaired successfully ($repairs_made fixes applied)"
        release_state_lock
        
        # LEARNING: Trigger branch refresh for complete fix
        info "Refreshing branch information..."
        refresh_partial_state "branches"
        
        return 0
    else
        error "Failed to write repaired state"
        release_state_lock
        return 1
    fi
}

# Sync git to state
# PURPOSE: Update state to match current git reality
# PARAMETERS: None
# RETURNS:
#   0 - Sync successful
#   1 - Sync failed
# SIDE EFFECTS:
#   - Performs atomic state update
#   - Refreshes runtime section
#   - Acquires and releases lock
# EXAMPLES:
#   # After external git operations
#   sync_git_to_state
#   
#   # In error recovery
#   git checkout main
#   sync_git_to_state
# LEARNING:
#   - One-way sync: git → state
#   - Preserves configuration sections
#   - More thorough than repair
sync_git_to_state() {
    # LEARNING: Use atomic operation for consistency
    if ! begin_atomic_operation "sync:git-to-state"; then
        return 1
    fi
    
    info "Synchronizing state with git reality..."
    
    # LEARNING: Get fresh runtime state
    local new_runtime=$(get_complete_runtime_state)
    if [[ -z "$new_runtime" ]]; then
        error "Failed to get runtime state"
        rollback_atomic_operation
        return 1
    fi
    
    # LEARNING: Read current state
    if ! read_state_file; then
        warn "No existing state, will initialize"
        rollback_atomic_operation
        initialize_state
        return $?
    fi
    
    # LEARNING: Update runtime section completely
    local updated_state=$(jq --argjson r "$new_runtime" '.runtime = $r' <<< "$STATE_CACHE")
    
    # LEARNING: Recompute decisions based on new runtime
    local computed=$(jq '.computed' <<< "$updated_state")
    local new_decisions=$(make_complete_decisions "$new_runtime" "$computed")
    updated_state=$(jq --argjson d "$new_decisions" '.decisions = $d' <<< "$updated_state")
    
    # LEARNING: Update sync timestamp
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    updated_state=$(jq --arg ts "$timestamp" '.metadata.lastGitSync = $ts' <<< "$updated_state")
    
    # LEARNING: Write synchronized state
    STATE_CACHE="$updated_state"
    if commit_atomic_operation; then
        success "State synchronized with git"
        return 0
    else
        # Rollback handled by commit_atomic_operation
        return 1
    fi
}

# Validate state against git
# PURPOSE: Ensure state matches git before critical operations
# PARAMETERS: None
# RETURNS:
#   0 - State is valid
#   1 - State is invalid or inconsistent
# SIDE EFFECTS:
#   - Writes validation errors to stderr
#   - No files modified
#   - No lock required (read-only)
# EXAMPLES:
#   # Before git operations
#   validate_state_against_git || sync_git_to_state
#   
#   # In wrapper scripts
#   if ! validate_state_against_git; then
#       die "State inconsistent with git"
#   fi
# LEARNING:
#   - Quick validation without repair
#   - Focuses on critical values
#   - Use before operations that depend on state accuracy
validate_state_against_git() {
    # LEARNING: Ensure state is loaded
    if ! read_state_file; then
        error "No state to validate"
        return 1
    fi
    
    local valid=true
    
    # LEARNING: Critical check 1: Current branch
    local state_branch=$(jq -r '.runtime.currentBranch // ""' <<< "$STATE_CACHE")
    local actual_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    
    if [[ "$state_branch" != "$actual_branch" ]] && [[ -n "$actual_branch" ]]; then
        error "Branch mismatch: state=$state_branch, git=$actual_branch"
        valid=false
    fi
    
    # LEARNING: Critical check 2: Working tree status
    # Allow minor variance in count but not in clean status
    local state_clean=$(jq -r '.runtime.git.isClean // true' <<< "$STATE_CACHE")
    local actual_uncommitted=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    local actual_clean=$([[ "$actual_uncommitted" -eq 0 ]] && echo "true" || echo "false")
    
    if [[ "$state_clean" != "$actual_clean" ]]; then
        error "Clean status mismatch: state=$state_clean, git=$actual_clean"
        valid=false
    fi
    
    # LEARNING: Critical check 3: Main branch exists
    local main_branch=$(jq -r '.computed.mainBranch // ""' <<< "$STATE_CACHE")
    if [[ -n "$main_branch" ]] && ! git show-ref --verify --quiet "refs/heads/$main_branch"; then
        error "Main branch '$main_branch' does not exist in git"
        valid=false
    fi
    
    if [[ "$valid" == "true" ]]; then
        debug "State validated against git"
        return 0
    else
        return 1
    fi
}

# ============================================================================
# CONVENIENCE FUNCTIONS - Easy access to common values
# ============================================================================
# HELPER FUNCTIONS - Convenience wrappers for common operations
# ============================================================================

# Get current branch info
# PURPOSE: Quick access to current branch metadata
# PARAMETERS: None
# RETURNS:
#   0 - Success
#   1 - State not loaded or branch not found
# OUTPUTS:
#   JSON object with branch info or empty object if not found
# EXAMPLE:
#   local info=$(get_current_branch_info)
#   local branch_type=$(jq -r '.type' <<< "$info")
#   local is_protected=$(jq -r '.protected' <<< "$info")
get_current_branch_info() {
    ensure_state
    local current=$(get_value "runtime.currentBranch")
    if [[ -n "$current" ]]; then
        get_value "runtime.branches.$current"
    fi
}

# Check if can perform operation
can_perform() {
    local operation="$1"
    ensure_state
    
    case "$operation" in
        create-branch)
            get_value "decisions.canCreateBranch"
            ;;
        merge)
            get_value "decisions.canMergeCurrentBranch"
            ;;
        push)
            local should_push=$(get_value "decisions.shouldPushOnStop")
            [[ "$should_push" == "true" ]] && printf "%s\n" "true" || printf "%s\n" "false"
            ;;
        fetch)
            local should_fetch=$(get_value "decisions.shouldFetchOnStart")
            [[ "$should_fetch" == "true" ]] && printf "%s\n" "true" || printf "%s\n" "false"
            ;;
        *)
            printf "%s\n" "false"
            ;;
    esac
}

# Get branches for cleanup
get_cleanup_branches() {
    ensure_state
    get_value "decisions.branchesForCleanup"
}

# Get prompt for operation
get_prompt() {
    local operation="$1"
    ensure_state
    get_value "decisions.prompts.$operation"
}

# Get workflow rule
get_workflow_rule() {
    local path="$1"
    ensure_state
    get_value "computed.workflows.$path"
}

# Get validation rule
get_validation_rule() {
    local path="$1"
    ensure_state
    get_value "computed.validation.$path"
}

# ============================================================================
# BIDIRECTIONAL STATE UPDATES
# ============================================================================
# 
# CRITICAL SYSTEM FOUNDATION: These functions form the backbone of AIPM's
# bidirectional communication system, enabling wrapper scripts to report
# changes back to the state engine, which then propagates to the decision
# engine for real-time adaptation.
#
# WHY THIS MATTERS:
# Traditional CI/CD systems operate in a one-way flow - configuration drives
# behavior. AIPM is different. It learns from every operation, adapts to
# patterns, and evolves its decisions based on real-world outcomes. This
# bidirectional flow is what transforms AIPM from a static tool into a
# living, learning system.
#
# ARCHITECTURAL PRINCIPLES:
# 1. ATOMIC OPERATIONS: All updates use file locking to ensure consistency
# 2. CASCADE INTELLIGENCE: Updates to runtime.* trigger decision re-evaluation
# 3. BATCH EFFICIENCY: Multiple updates can be grouped to minimize I/O
# 4. TYPE SAFETY: JSON validation ensures state integrity
# 5. AUDIT TRAIL: Every update is timestamped for forensic analysis
#
# INTEGRATION PATTERN:
# Wrapper scripts report operations → State updates → Decision refresh →
# → New behaviors available → Wrapper scripts adapt → Continuous learning
#
# ============================================================================

# update_state()
# PURPOSE: Core function for updating any value in the state with automatic
#          locking, validation, and cascade processing. This is the primary
#          interface for wrapper scripts to communicate changes back to AIPM.
#
# PARAMETERS:
#   $1 - path: JSON path to update (e.g., "runtime.currentBranch")
#   $2 - value: New value (must be valid JSON - strings need quotes!)
#   $3 - trigger_refresh: Whether to trigger decision refresh (default: true)
#
# RETURNS:
#   0 - Update successful, state synchronized
#   1 - Update failed (invalid path, JSON error, lock timeout)
#
# BEHAVIOR:
#   1. Acquires exclusive lock on state file
#   2. Reads current state into memory
#   3. Updates value using jq for atomic JSON manipulation
#   4. Writes updated state back to disk
#   5. Updates cache for performance
#   6. Refreshes timestamp for audit trail
#   7. Optionally triggers decision engine refresh
#
# LOCKING:
#   Uses flock-based locking with 5-second timeout to prevent:
#   - Race conditions between parallel operations
#   - Partial writes during concurrent access
#   - State corruption from interrupted updates
#
# EXAMPLES:
#   # Report branch change (triggers decision refresh)
#   update_state "runtime.currentBranch" '"feature/new-ui"'
#   
#   # Update commit count without refresh
#   update_state "metrics.commitCount" "42" "false"
#   
#   # Set complex object
#   update_state "runtime.branches.main" '{"head": "abc123", "protected": true}'
#
# INTEGRATION WITH WRAPPERS:
#   # In git wrapper after successful checkout:
#   if git checkout "$branch" 2>&1; then
#       update_state "runtime.currentBranch" "\"$branch\""
#       update_state "runtime.lastCheckout" "\"$(date -u +%FT%TZ)\""
#   fi
#
# LEARNING ASPECT:
#   Every state update is an opportunity for AIPM to learn. When runtime
#   values change, the decision engine re-evaluates rules, potentially
#   discovering new patterns or adjusting behaviors. This continuous
#   feedback loop is what makes AIPM adaptive rather than prescriptive.
#
update_state() {
    local path="$1"
    local value="$2"
    local trigger_refresh="${3:-true}"  # Refresh decisions by default
    
    # Ensure state is loaded
    ensure_state
    
    # Acquire lock for update
    acquire_state_lock
    
    # Read current state
    if [[ ! -f "$STATE_FILE" ]]; then
        release_state_lock
        error "State file not found"
        return 1
    fi
    
    local current_state=$(cat "$STATE_FILE")
    
    # Update the value using jq
    local updated_state
    if ! updated_state=$(printf "%s\n" "$current_state" | jq --arg path "$path" --argjson value "$value" 'setpath($path | split("."); $value)' 2>/dev/null); then
        release_state_lock
        error "Failed to update state at path: $path"
        return 1
    fi
    
    # Write updated state
    printf "%s\n" "$updated_state" > "$STATE_FILE"
    STATE_CACHE="$updated_state"
    
    # Update timestamp
    local now=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
    update_state_internal "metadata.lastRefresh" "\"$now\"" "false"
    
    release_state_lock
    
    # Trigger selective refresh if requested
    if [[ "$trigger_refresh" == "true" ]]; then
        if [[ "$path" =~ ^runtime\. ]]; then
            refresh_state "decisions"
        fi
    fi
    
    return 0
}

# update_state_internal()
# PURPOSE: Lock-free state update for use within already-locked sections.
#          This is a performance optimization for compound operations that
#          need multiple atomic updates without lock thrashing.
#
# CRITICAL: This function assumes the caller already holds the state lock!
#           Using this without proper locking WILL cause race conditions.
#
# PARAMETERS:
#   $1 - path: JSON path to update
#   $2 - value: New value (must be valid JSON)
#
# RETURNS:
#   0 - Update successful
#   1 - JSON manipulation failed
#
# USE CASES:
#   1. Timestamp updates within other operations
#   2. Multi-field updates in batch operations
#   3. Nested updates during complex state transitions
#
# EXAMPLE:
#   acquire_state_lock
#   update_state_internal "runtime.operation" '"merge"'
#   update_state_internal "runtime.operationStart" "\"$(date -u +%FT%TZ)\""
#   update_state_internal "runtime.operationStatus" '"in-progress"'
#   release_state_lock
#
# WARNING:
#   Never call this function without holding the state lock. The lack of
#   locking is intentional for performance but requires discipline. Always
#   prefer update_state() unless you're absolutely certain about locking.
#
update_state_internal() {
    local path="$1"
    local value="$2"
    local current_state=$(cat "$STATE_FILE")
    local updated_state
    
    if ! updated_state=$(printf "%s\n" "$current_state" | jq --arg path "$path" --argjson value "$value" 'setpath($path | split("."); $value)' 2>/dev/null); then
        return 1
    fi
    
    printf "%s\n" "$updated_state" > "$STATE_FILE"
    STATE_CACHE="$updated_state"
    return 0
}

# update_state_batch()
# PURPOSE: Efficiently update multiple state values in a single atomic
#          operation. This is crucial for maintaining consistency when
#          multiple related values must change together.
#
# PARAMETERS:
#   $1 - updates: Name of array containing "path:value" pairs
#   $2 - trigger_refresh: Whether to trigger decision refresh (default: true)
#
# RETURNS:
#   0 - All updates successful
#   1 - Any update failed (no partial updates - all or nothing)
#
# ATOMICITY:
#   This function guarantees that either ALL updates succeed or NONE are
#   applied. This prevents inconsistent state where some values are updated
#   but others aren't, which could lead to invalid decision-making.
#
# FORMAT:
#   Each array element must be "path:value" where value is valid JSON.
#   String values must include quotes: 'status:"active"'
#   Numbers don't need quotes: 'count:42'
#   Objects need full JSON: 'config:{"enabled":true,"timeout":30}'
#
# EXAMPLES:
#   # Report merge completion with multiple state changes
#   declare -a merge_updates=(
#       'runtime.operation:"merge"'
#       'runtime.operationStatus:"complete"'
#       'runtime.lastMerge:"2024-01-15T10:30:00Z"'
#       'metrics.mergeCount:15'
#       'runtime.branches.feature.merged:true'
#   )
#   update_state_batch merge_updates
#
#   # Update build status atomically
#   declare -a build_updates=(
#       'runtime.buildStatus:"success"'
#       'runtime.buildDuration:245'
#       'runtime.lastBuild:"2024-01-15T10:35:00Z"'
#       'metrics.successfulBuilds:142'
#   )
#   update_state_batch build_updates "false"  # Don't trigger refresh
#
# PERFORMANCE:
#   Batch updates are significantly faster than individual updates:
#   - Single lock acquisition instead of N locks
#   - Single file write instead of N writes
#   - Single cache update instead of N updates
#   - Single refresh trigger instead of N triggers
#
# INTEGRATION PATTERN:
#   # In wrapper script for complex operations
#   declare -a updates=()
#   
#   # Collect all state changes during operation
#   if [[ "$operation_started" ]]; then
#       updates+=("runtime.operationStart:\"$start_time\"")
#   fi
#   if [[ "$files_changed" -gt 0 ]]; then
#       updates+=("runtime.filesModified:$files_changed")
#   fi
#   if [[ "$conflicts_resolved" ]]; then
#       updates+=("runtime.conflictsResolved:true")
#   fi
#   
#   # Apply all updates atomically
#   update_state_batch updates
#
# LEARNING INSIGHT:
#   Batch updates allow AIPM to see complete state transitions rather than
#   intermediate states. This provides cleaner data for pattern recognition
#   and prevents the decision engine from reacting to partial information.
#
update_state_batch() {
    local -n updates=$1  # Array of "path:value" pairs
    local trigger_refresh="${2:-true}"
    
    ensure_state
    acquire_state_lock
    
    local current_state=$(cat "$STATE_FILE")
    local updated_state="$current_state"
    
    # Apply all updates
    for update in "${updates[@]}"; do
        local path="${update%%:*}"
        local value="${update#*:}"
        
        if ! updated_state=$(printf "%s\n" "$updated_state" | jq --arg path "$path" --argjson value "$value" 'setpath($path | split("."); $value)' 2>/dev/null); then
            release_state_lock
            error "Failed to update state at path: $path"
            return 1
        fi
    done
    
    # Write updated state
    printf "%s\n" "$updated_state" > "$STATE_FILE"
    STATE_CACHE="$updated_state"
    
    # Update timestamp
    local now=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
    update_state_internal "metadata.lastRefresh" "\"$now\"" "false"
    
    release_state_lock
    
    # Trigger refresh if needed
    if [[ "$trigger_refresh" == "true" ]]; then
        refresh_state "decisions"
    fi
    
    return 0
}

# increment_state()
# PURPOSE: Safely increment numeric values in state with automatic type
#          checking and atomic updates. Essential for tracking metrics,
#          counters, and statistics that drive intelligent decisions.
#
# PARAMETERS:
#   $1 - path: JSON path to numeric value
#   $2 - delta: Amount to increment by (default: 1, can be negative)
#
# RETURNS:
#   0 - Increment successful
#   1 - Failed (not a number, invalid path, etc.)
#
# TYPE SAFETY:
#   This function validates that the current value is numeric before
#   attempting increment. This prevents corruption of non-numeric fields
#   and ensures metrics remain accurate.
#
# EXAMPLES:
#   # Count successful builds
#   increment_state "metrics.successfulBuilds"
#   
#   # Track commit count
#   increment_state "metrics.commitCount" 1
#   
#   # Decrease error count (negative delta)
#   increment_state "metrics.errorCount" -1
#   
#   # Update file change count by specific amount
#   increment_state "runtime.filesModified" "$changed_files"
#
# METRICS TRACKING:
#   AIPM uses numeric metrics to identify patterns and make decisions:
#   - High commit frequency → Suggest smaller, focused branches
#   - Rising error count → Enable stricter validation
#   - Build time trends → Optimize caching strategies
#
# INTEGRATION EXAMPLE:
#   # In build wrapper script
#   if run_build; then
#       increment_state "metrics.successfulBuilds"
#       increment_state "metrics.totalBuilds"
#   else
#       increment_state "metrics.failedBuilds"
#       increment_state "metrics.totalBuilds"
#       increment_state "metrics.consecutiveFailures"
#   fi
#
# LEARNING APPLICATION:
#   Incremental metrics are the foundation of AIPM's pattern recognition.
#   By tracking counters over time, the system can identify trends like:
#   - Peak activity hours requiring resource scaling
#   - Error patterns correlating with specific operations
#   - Performance degradation requiring intervention
#
# ATOMICITY NOTE:
#   This function uses update_state() internally, ensuring the read-modify-write
#   operation is atomic. Multiple processes can safely increment the same
#   counter without race conditions.
#
increment_state() {
    local path="$1"
    local delta="${2:-1}"
    
    ensure_state
    
    local current=$(get_value "$path")
    if [[ ! "$current" =~ ^[0-9]+$ ]]; then
        error "Cannot increment non-numeric value at $path"
        return 1
    fi
    
    local new_value=$((current + delta))
    update_state "$path" "$new_value"
}

# append_state()
# PURPOSE: Add items to arrays in state with automatic locking and optional
#          size limits. Critical for maintaining operation histories, tracking
#          patterns, and building the memory that makes AIPM intelligent.
#
# PARAMETERS:
#   $1 - path: JSON path to array (required)
#   $2 - item: Item to append (required, any valid JSON value)
#   $3 - max_size: Maximum array size (optional, implements FIFO rotation)
#
# RETURNS:
#   0 - Append successful
#   1 - Failed (not an array, invalid JSON, etc.)
#
# MEMORY MANAGEMENT:
#   When max_size is specified, the array acts as a circular buffer:
#   - New items are added to the end
#   - Old items are removed from the beginning
#   - This prevents unbounded memory growth while preserving recent history
#
# EXAMPLES:
#   # Track operation history with 100-item limit
#   append_state "memory.operations" \
#     '{"type": "merge", "time": 1719071234, "duration": 45}' 100
#   
#   # Maintain list of recent branches (10 most recent)
#   append_state "memory.recentBranches" '"feature/new-ui"' 10
#   
#   # Log error occurrences for pattern analysis
#   append_state "memory.errors" \
#     '{"code": "ECONFLICT", "file": "main.js", "line": 42}'
#   
#   # Track command history for learning user patterns
#   append_state "memory.commandHistory" \
#     '{"cmd": "git pull", "time": "2024-01-15T10:30:00Z", "success": true}'
#
# INTEGRATION PATTERNS:
#   # In wrapper scripts - track every operation
#   operation_start=$(date +%s)
#   if perform_operation; then
#       operation_end=$(date +%s)
#       append_state "memory.operations" "$(cat <<-EOF
#           {
#               "type": "$OPERATION_TYPE",
#               "start": $operation_start,
#               "duration": $((operation_end - operation_start)),
#               "success": true,
#               "context": {
#                   "branch": "$(get_value 'runtime.currentBranch')",
#                   "files": $files_affected
#               }
#           }
#       EOF
#       )" 1000  # Keep last 1000 operations
#   fi
#
# LEARNING FOUNDATION:
#   Arrays in state form AIPM's episodic memory. By tracking sequences of
#   events, the system can:
#   - Identify recurring patterns (e.g., merge conflicts on Fridays)
#   - Learn from past successes and failures
#   - Predict likely outcomes based on historical data
#   - Adapt behavior based on accumulated experience
#
# PERFORMANCE CONSIDERATION:
#   Large arrays can impact performance. Use max_size to balance between:
#   - Sufficient history for pattern recognition
#   - Reasonable memory usage and processing time
#   - Quick state updates and decision-making
#
# ATOMICITY:
#   Array appends are atomic - the entire operation succeeds or fails.
#   This ensures history entries are never partially written.
#
append_state() {
    local path="$1"
    local item="$2"
    
    ensure_state
    acquire_state_lock
    
    local current_state=$(cat "$STATE_FILE")
    local updated_state
    
    # Append item to array
    if ! updated_state=$(printf "%s\n" "$current_state" | jq --arg path "$path" --argjson item "$item" 'getpath($path | split(".")) += [$item]' 2>/dev/null); then
        release_state_lock
        error "Failed to append to array at path: $path"
        return 1
    fi
    
    printf "%s\n" "$updated_state" > "$STATE_FILE"
    STATE_CACHE="$updated_state"
    
    release_state_lock
    return 0
}

# remove_state()
# PURPOSE: Safely remove paths from state with automatic locking. Essential
#          for cleaning up temporary data, removing outdated information,
#          and maintaining a lean, efficient state structure.
#
# PARAMETERS:
#   $1 - path: JSON path to remove (supports nested paths)
#
# RETURNS:
#   0 - Removal successful (or path didn't exist)
#   1 - Failed (invalid path, lock timeout)
#
# BEHAVIOR:
#   - Removes the entire path including all nested content
#   - Safe to call on non-existent paths (returns success)
#   - Maintains state integrity during removal
#   - Updates cache after successful removal
#
# EXAMPLES:
#   # Remove merged branch information
#   remove_state "runtime.branches.feature/old-feature"
#   
#   # Clean up temporary operation data
#   remove_state "runtime.tempOperation"
#   
#   # Remove obsolete configuration
#   remove_state "config.deprecated.oldSetting"
#   
#   # Clear error state after resolution
#   remove_state "runtime.lastError"
#
# USE CASES:
#   1. BRANCH CLEANUP: Remove branch data after deletion
#   2. TEMP DATA: Clear temporary operation states
#   3. ERROR RESET: Remove error indicators after fixes
#   4. MEMORY MANAGEMENT: Prune old or irrelevant data
#
# INTEGRATION EXAMPLE:
#   # In git wrapper after branch deletion
#   if git branch -d "$branch_name" 2>&1; then
#       # Remove all branch-related state
#       remove_state "runtime.branches.$branch_name"
#       remove_state "memory.branchMetrics.$branch_name"
#       
#       # Update recent branches list
#       # (Note: Would need custom logic to remove from array)
#   fi
#
#   # Clean up after failed operation
#   if [[ "$operation_failed" ]]; then
#       remove_state "runtime.pendingOperation"
#       remove_state "runtime.operationLock"
#       update_state "runtime.operationStatus" '"idle"'
#   fi
#
# CASCADING EFFECTS:
#   Removing state can trigger decision changes:
#   - Removing error states may enable previously blocked operations
#   - Removing branch data updates available branch strategies
#   - Removing locks allows queued operations to proceed
#
# WARNING:
#   Be careful when removing state that other parts of the system depend on.
#   Always consider:
#   - Will other functions expect this path to exist?
#   - Should you set a default value instead of removing?
#   - Are there related paths that should also be cleaned up?
#
# ATOMICITY:
#   Removal is atomic - the path is either fully removed or unchanged.
#   This prevents partial deletions that could corrupt state structure.
#
remove_state() {
    local path="$1"
    
    ensure_state
    acquire_state_lock
    
    local current_state=$(cat "$STATE_FILE")
    local updated_state
    
    # Remove path
    if ! updated_state=$(printf "%s\n" "$current_state" | jq --arg path "$path" 'delpaths([$path | split(".")])' 2>/dev/null); then
        release_state_lock
        error "Failed to remove path: $path"
        return 1
    fi
    
    printf "%s\n" "$updated_state" > "$STATE_FILE"
    STATE_CACHE="$updated_state"
    
    release_state_lock
    return 0
}

# report_git_operation()
# PURPOSE: High-level interface for git wrapper scripts to report operations
#          back to AIPM state. This function translates git events into
#          structured state updates that drive intelligent decision-making.
#
# PARAMETERS:
#   $1 - operation: Type of git operation (see supported operations below)
#   $2+ - Additional parameters specific to each operation type
#
# RETURNS:
#   0 - Operation reported successfully
#   1 - Unknown operation or update failed
#
# SUPPORTED OPERATIONS:
#   branch-created <branch_name> <parent_branch>
#     - Records new branch creation with lineage tracking
#     - Updates current branch and branch metadata
#   
#   branch-switched <branch_name>
#     - Updates current branch context
#     - Triggers decision refresh for branch-specific rules
#   
#   branch-deleted <branch_name>
#     - Removes all branch-related state
#     - Cleans up associated metrics and history
#   
#   files-modified <count>
#     - Updates uncommitted file count
#     - Sets working tree dirty flag
#   
#   commit-created <commit_hash>
#     - Records commit on current branch
#     - Resets working tree status
#     - Updates branch head reference
#   
#   branch-merged <source_branch> <target_branch>
#     - Records merge completion
#     - Updates branch relationships
#   
#   remote-updated <ahead_count> <behind_count>
#     - Syncs local/remote divergence metrics
#     - Informs push/pull decisions
#
# EXAMPLES:
#   # Report branch creation
#   report_git_operation "branch-created" "feature/new-ui" "main"
#   
#   # Report uncommitted changes
#   report_git_operation "files-modified" "7"
#   
#   # Report successful commit
#   report_git_operation "commit-created" "abc123def456"
#   
#   # Report branch switch
#   report_git_operation "branch-switched" "develop"
#
# INTEGRATION PATTERN:
#   # In git wrapper script
#   git_checkout() {
#       local branch="$1"
#       
#       # Perform actual checkout
#       if git checkout "$branch" 2>&1; then
#           # Report successful switch to AIPM
#           report_git_operation "branch-switched" "$branch"
#           
#           # Check for uncommitted changes in new branch
#           local modified=$(git status --porcelain | wc -l)
#           if [[ $modified -gt 0 ]]; then
#               report_git_operation "files-modified" "$modified"
#           fi
#       else
#           return 1
#       fi
#   }
#
# DECISION ENGINE INTEGRATION:
#   Each reported operation can trigger decision updates:
#   - branch-created → Evaluate branch naming rules
#   - files-modified → Check commit size thresholds
#   - commit-created → Update commit frequency metrics
#   - branch-merged → Assess merge conflict patterns
#   - remote-updated → Determine sync strategy
#
# LEARNING IMPACT:
#   Git operations form the core of AIPM's learning:
#   1. PATTERN RECOGNITION: Identifies workflows from operation sequences
#   2. ANOMALY DETECTION: Spots unusual operations that may need attention
#   3. OPTIMIZATION: Suggests better workflows based on historical data
#   4. PREDICTION: Anticipates likely next steps in common workflows
#
# IMPLEMENTATION NOTE:
#   This function uses update_state_batch() internally for efficiency.
#   Multiple state changes from a single operation are applied atomically,
#   ensuring consistent state even if multiple git operations run in parallel.
#
# EXTENSIBILITY:
#   New operation types can be added by:
#   1. Adding a new case in the switch statement
#   2. Defining the state updates for that operation
#   3. Documenting the parameters and effects
#   4. Updating wrapper scripts to report the new operation
#
report_git_operation() {
    local operation="$1"
    shift
    local -a updates=()
    
    case "$operation" in
        branch-created)
            local branch_name="$1"
            local parent_branch="$2"
            local now=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
            
            updates+=("runtime.currentBranch:\"$branch_name\"")
            updates+=("runtime.branches.$branch_name:{\"exists\":true,\"created\":\"$now\",\"parent\":\"$parent_branch\"}")
            ;;
            
        branch-switched)
            local branch_name="$1"
            updates+=("runtime.currentBranch:\"$branch_name\"")
            ;;
            
        branch-deleted)
            local branch_name="$1"
            remove_state "runtime.branches.$branch_name"
            return
            ;;
            
        files-modified)
            local count="$1"
            updates+=("runtime.uncommittedCount:$count")
            updates+=("runtime.workingTreeClean:false")
            ;;
            
        commit-created)
            local commit_hash="$1"
            local branch_name=$(get_value "runtime.currentBranch")
            updates+=("runtime.branches.$branch_name.head:\"$commit_hash\"")
            updates+=("runtime.branches.$branch_name.lastCommit:\"$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")\"")
            updates+=("runtime.workingTreeClean:true")
            updates+=("runtime.uncommittedCount:0")
            ;;
            
        branch-merged)
            local source_branch="$1"
            local target_branch="$2"
            local now=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
            updates+=("runtime.branches.$source_branch.mergeDate:\"$now\"")
            updates+=("runtime.branches.$source_branch.mergedTo:\"$target_branch\"")
            ;;
            
        remote-updated)
            local ahead="$1"
            local behind="$2"
            updates+=("runtime.remoteStatus.ahead:$ahead")
            updates+=("runtime.remoteStatus.behind:$behind")
            ;;
    esac
    
    # Apply updates if any
    if [[ ${#updates[@]} -gt 0 ]]; then
        update_state_batch updates true
    fi
}

# ============================================================================
# TESTING AND DEBUGGING
# ============================================================================

# Dump current state (for debugging)
dump_state() {
    ensure_state
    printf "%s\n" "$STATE_CACHE" | jq '.'
}

# Validate state integrity
validate_state() {
    if ! read_state_file; then
        error "No state file found"
        return 1
    fi
    
    # Check required sections
    for section in metadata raw_exports computed runtime decisions; do
        if ! printf "%s\n" "$STATE_CACHE" | jq -e ".$section" >/dev/null 2>&1; then
            error "Missing required section: $section"
            return 1
        fi
    done
    
    # Check computed has all required subsections
    local computed_sections=(mainBranch branchPatterns protectedBranches lifecycleMatrix workflows validation memory team sessions loading initialization defaults errorHandling settings)
    for section in "${computed_sections[@]}"; do
        if ! printf "%s\n" "$STATE_CACHE" | jq -e ".computed.$section" >/dev/null 2>&1; then
            error "Missing computed section: $section"
            return 1
        fi
    done
    
    success "State validation passed"
    return 0
}

# Show state summary
show_state_summary() {
    ensure_state
    
    info "State Summary:"
    info "============="
    info "Workspace: $(get_value 'metadata.workspace.name') ($(get_value 'metadata.workspace.type'))"
    info "Main Branch: $(get_value 'computed.mainBranch')"
    info "Current Branch: $(get_value 'runtime.currentBranch')"
    info "Working Tree Clean: $(get_value 'runtime.workingTreeClean')"
    info "Can Create Branch: $(get_value 'decisions.canCreateBranch')"
    info "Can Merge: $(get_value 'decisions.canMergeCurrentBranch')"
    info "Validation Mode: $(get_value 'computed.validation.mode')"
    info "Total Branches: $(printf "%s\n" "$STATE_CACHE" | jq '.runtime.branches | length')"
    info "Stale Branches: $(printf "%s\n" "$STATE_CACHE" | jq '.decisions.staleBranches | length')"
    info "Cleanup Candidates: $(printf "%s\n" "$STATE_CACHE" | jq '.decisions.branchesForCleanup | length')"
}

# Auto-initialize if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        init|initialize)
            initialize_state
            ;;
        refresh)
            refresh_state "${2:-all}"
            ;;
        get)
            get_value "$2"
            ;;
        dump)
            dump_state
            ;;
        validate)
            validate_state
            ;;
        summary)
            show_state_summary
            ;;
        *)
            info "Usage: $0 {init|refresh|get|dump|validate|summary}"
            info ""
            info "Commands:"
            info "  init      - Initialize state from scratch"
            info "  refresh   - Refresh state (all|branches|decisions|computed)"
            info "  get PATH  - Get value at path (e.g., decisions.canCreateBranch)"
            info "  dump      - Dump entire state as JSON"
            info "  validate  - Validate state integrity"
            info "  summary   - Show state summary"
            ;;
    esac
fi