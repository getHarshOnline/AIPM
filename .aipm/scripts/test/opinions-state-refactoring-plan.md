# Comprehensive Refactoring Plan for opinions-state.sh

## Executive Summary

This document outlines a surgical refactoring of `opinions-state.sh` to achieve:
- **SOLID principles** adherence
- **Complete self-documentation** with in-place learnings
- **Consistency** across all functions
- **Maintainability** for future developers
- **Zero breaking changes** to existing functionality

## Current State Analysis

### File Statistics
- **Total Lines**: 2,611
- **Total Functions**: 78
- **Documented Functions**: 44 (56%)
- **Undocumented Functions**: 34 (44%)
- **Functions >100 lines**: 5
- **Functions >50 lines**: 12

### Critical Issues

#### 1. Documentation Gaps (34 functions missing headers)
```bash
# Functions without documentation:
- check_jq_installed()
- ensure_state_dir()
- acquire_state_lock()
- release_state_lock()
- read_state_file()
- write_state_file()
- compute_all_branch_patterns()
- compute_protected_branches_list()
- compute_complete_lifecycle_matrix()
- ... and 25 more
```

#### 2. Single Responsibility Violations
```bash
# Monolithic functions doing too much:
make_complete_decisions()        # 276 lines - handles ALL decision types
get_complete_runtime_branches()  # 241 lines - complex branch analysis
compute_complete_workflow_rules() # 176 lines - builds ALL workflows
initialize_state()               # 120 lines - orchestrates everything
refresh_state()                  # 92 lines - handles multiple refresh types
```

#### 3. Missing In-Place Learning Comments
```bash
# Complex logic without explanation:
- Why we check both flock and directory locking
- Why we pre-compute everything instead of lazy evaluation
- Why certain git operations trigger specific state updates
- Why we use specific jq patterns for JSON manipulation
```

#### 4. Code Duplication
```bash
# Repeated patterns:
- Date parsing (5 locations)
- JSON path extraction (8 locations)
- Branch type detection (4 locations)
- Error handling patterns (inconsistent)
```

## Refactoring Plan

### Phase 1: Documentation Enhancement (Week 1) - CRITICAL

#### 1.1 Add Complete Function Headers
Every function needs:
```bash
# PURPOSE: One-line description of what this function does
# PARAMETERS:
#   $1 - parameter_name (type): Description [optional/required]
#   $2 - parameter_name (type): Description [optional/required]
# RETURNS:
#   0 - Success
#   1 - Specific error condition
# OUTPUTS:
#   What this function outputs to stdout (if any)
# SIDE EFFECTS:
#   Files created/modified, global variables changed
# EXAMPLES:
#   function_name "arg1" "arg2"
#   result=$(function_name "value")
# LEARNING:
#   WHY this approach was chosen, alternatives considered
```

#### 1.2 Add In-Place Learning Comments
```bash
# Example for lock mechanism:
acquire_state_lock() {
    local timeout=30
    
    # LEARNING: We use flock when available because it's atomic and handles
    # process crashes gracefully. The file descriptor approach (200) is chosen
    # to avoid conflicts with stdin/stdout/stderr (0/1/2).
    if command -v flock &>/dev/null; then
        # ...
    else
        # LEARNING: Fallback to directory-based locking for systems without flock
        # (some Docker containers, minimal Linux distros). Directories are atomic
        # on all POSIX systems - mkdir fails if directory exists.
        # ...
    fi
}
```

### Phase 2: Function Decomposition (Week 2) - HIGH

#### 2.1 Break Down make_complete_decisions()
```bash
# Current: 276 lines doing everything
# Refactored into focused functions:
make_complete_decisions() {
    # Orchestrator only
    local runtime="$1"
    local computed="$2"
    
    local branch_decisions=$(make_branch_decisions "$runtime" "$computed")
    local merge_decisions=$(make_merge_decisions "$runtime" "$computed")
    local cleanup_decisions=$(make_cleanup_decisions "$runtime" "$computed")
    local sync_decisions=$(make_sync_decisions "$runtime" "$computed")
    local prompt_decisions=$(make_prompt_decisions "$computed")
    
    # Combine all decisions
    combine_decisions "$branch_decisions" "$merge_decisions" "$cleanup_decisions" "$sync_decisions" "$prompt_decisions"
}

# Each sub-function handles one responsibility:
make_branch_decisions() {
    # PURPOSE: Determine if branches can be created and why
    # LEARNING: We check working tree first because git won't allow
    # branch creation with uncommitted changes (data loss risk)
    # ...
}
```

#### 2.2 Extract Common Utilities
```bash
# Date utilities
parse_iso_date() {
    # PURPOSE: Parse ISO date to epoch seconds, handle platform differences
    # LEARNING: GNU date uses -d, BSD date uses -j -f. We detect and adapt.
    local iso_date="$1"
    # ...
}

# JSON utilities  
extract_json_array() {
    # PURPOSE: Safely extract JSON array from path
    # LEARNING: We use 'empty' filter to handle missing paths gracefully
    local json="$1"
    local path="$2"
    # ...
}

# Branch utilities
detect_branch_type() {
    # PURPOSE: Determine branch type from name pattern
    # LEARNING: We check patterns in priority order because some overlap
    local branch="$1"
    local patterns="$2"
    # ...
}
```

### Phase 3: Structural Improvements (Week 3) - MEDIUM

#### 3.1 Reorganize File Structure
```bash
#!/opt/homebrew/bin/bash
# ============================================================================
# opinions-state.sh - Complete runtime state management with pre-computation
# ============================================================================

# ============================================================================
# CONFIGURATION & INITIALIZATION
# ============================================================================
# [Global variables, sourcing, traps]

# ============================================================================
# UTILITY LAYER - Low-level helpers
# ============================================================================
# [Lock management, file I/O, JSON utilities, date utilities]

# ============================================================================
# COMPUTATION LAYER - Transform opinions to computed values
# ============================================================================
# [Branch patterns, lifecycle matrix, workflow rules, etc.]

# ============================================================================
# RUNTIME LAYER - Git state queries
# ============================================================================
# [Current branch, working tree, remote status, etc.]

# ============================================================================
# DECISION LAYER - Pre-computed decisions
# ============================================================================
# [Can create branch, merge targets, cleanup candidates, etc.]

# ============================================================================
# STATE MANAGEMENT LAYER - Core API
# ============================================================================
# [Initialize, refresh, get_value, ensure_state]

# ============================================================================
# UPDATE LAYER - Bidirectional updates
# ============================================================================
# [update_state, update_batch, report_git_operation, etc.]

# ============================================================================
# CONVENIENCE LAYER - Helper functions
# ============================================================================
# [get_current_branch_info, check_permission, etc.]

# ============================================================================
# DIAGNOSTIC LAYER - Testing and debugging
# ============================================================================
# [dump_state, validate_state, debug_mode]
```

### Phase 4: Error Handling Standardization (Week 4) - MEDIUM

#### 4.1 Consistent Error Patterns
```bash
# Standard error handling template:
function_name() {
    # Parameter validation
    [[ -z "$1" ]] && { error "function_name: Missing required parameter"; return 1; }
    
    # Operation with error checking
    local result
    if ! result=$(operation 2>&1); then
        error "function_name: Operation failed: $result"
        return 1
    fi
    
    # Success path
    printf "%s\n" "$result"
    return 0
}
```

#### 4.2 Validation Functions
```bash
validate_json_path() {
    # PURPOSE: Validate JSON path syntax before use
    # LEARNING: Prevents injection attacks and jq errors
    local path="$1"
    [[ "$path" =~ ^[a-zA-Z0-9_.\[\]]+$ ]] || return 1
}

validate_branch_name() {
    # PURPOSE: Ensure branch name follows git rules
    # LEARNING: Git has specific rules we must enforce
    local name="$1"
    # Check for invalid characters, reserved names, etc.
}
```

### Phase 5: Performance Optimizations (Week 5) - LOW

#### 5.1 Add Caching Layer
```bash
# Cache frequently accessed values
declare -A STATE_VALUE_CACHE=()

get_value_cached() {
    local path="$1"
    
    # Check cache first
    if [[ -n "${STATE_VALUE_CACHE[$path]:-}" ]]; then
        printf "%s\n" "${STATE_VALUE_CACHE[$path]}"
        return 0
    fi
    
    # Load and cache
    local value=$(get_value "$path")
    STATE_VALUE_CACHE[$path]="$value"
    printf "%s\n" "$value"
}
```

#### 5.2 Batch JSON Operations
```bash
# Instead of multiple jq calls:
extract_multiple_values() {
    local json="$1"
    shift
    local paths=("$@")
    
    # Build single jq query
    local query=""
    for path in "${paths[@]}"; do
        query="${query:+$query,}\"$path\": .$path"
    done
    
    # Single jq execution
    printf "%s\n" "$json" | jq "{$query}"
}
```

### Phase 6: Testing Support (Week 6) - LOW

#### 6.1 Debug Mode
```bash
# Enable detailed logging
declare -g STATE_DEBUG="${STATE_DEBUG:-false}"

debug_log() {
    [[ "$STATE_DEBUG" == "true" ]] && info "[DEBUG] $*" >&2
}

# Use throughout:
debug_log "Loading state from $STATE_FILE"
```

#### 6.2 State Validation
```bash
validate_state_integrity() {
    # PURPOSE: Ensure state file is internally consistent
    # LEARNING: Catches corruption early before it propagates
    
    # Check required sections exist
    # Validate cross-references
    # Ensure computed values match raw exports
    # Verify no circular dependencies
}
```

## Implementation Strategy

### Backward Compatibility Requirements
1. **No function signatures change** (parameters/returns)
2. **No global variable renames**
3. **No file location changes**
4. **All existing behaviors preserved**

### Testing Strategy
1. **Create comprehensive test suite first**
2. **Test after each refactoring phase**
3. **Performance benchmarks before/after**
4. **Integration tests with wrapper scripts**

### Rollout Plan
1. **Week 1**: Documentation only (no functional changes)
2. **Week 2**: Function decomposition (internal only)
3. **Week 3**: Structural reorganization
4. **Week 4**: Error handling improvements
5. **Week 5**: Performance optimizations
6. **Week 6**: Testing infrastructure
7. **Week 7**: Final validation and cleanup

## Success Metrics
1. **100% function documentation**
2. **No functions >100 lines**
3. **All complex logic has learning comments**
4. **Consistent error handling patterns**
5. **Performance maintained or improved**
6. **Zero breaking changes**

## Example: Fully Refactored Function

```bash
# PURPOSE: Acquire exclusive lock for state file operations
# PARAMETERS:
#   None
# RETURNS:
#   0 - Lock acquired successfully
#   1 - Failed to acquire lock within timeout
# SIDE EFFECTS:
#   Creates $STATE_LOCK file or $STATE_LOCK.dir directory
#   Sets up file descriptor 200 (if using flock)
# EXAMPLES:
#   acquire_state_lock || die "Could not acquire state lock"
# LEARNING:
#   We need locking because multiple AIPM operations might run concurrently
#   (e.g., save in one terminal while cleanup runs in another). Without
#   locking, we risk corrupting the JSON state file. We prefer flock because
#   it automatically releases on process exit, but provide directory-based
#   fallback for compatibility.
acquire_state_lock() {
    local timeout=30
    
    # LEARNING: Create lock file first so flock has something to lock.
    # This prevents race condition where two processes try to create it.
    touch "$STATE_LOCK" 2>/dev/null || true
    
    if command -v flock &>/dev/null; then
        # LEARNING: Use file descriptor 200 to avoid stdin/stdout/stderr.
        # Bash reserves 0-9, we use high number to avoid conflicts.
        # The 'eval' is safe here - no user input involved.
        if ! eval "exec 200>\"$STATE_LOCK\"" || ! flock -w "$timeout" 200; then
            error "Failed to acquire state lock after ${timeout}s"
            return 1
        fi
        debug_log "Acquired flock on $STATE_LOCK"
    else
        # LEARNING: mkdir is atomic on all POSIX systems - perfect for locking.
        # We spin with exponential backoff to be CPU-friendly.
        local elapsed=0
        local backoff=0.1
        
        while ! mkdir "$STATE_LOCK.dir" 2>/dev/null && [[ $elapsed -lt $timeout ]]; do
            sleep "$backoff"
            elapsed=$((elapsed + 1))
            # LEARNING: Exponential backoff reduces CPU usage under contention
            backoff=$(awk "BEGIN {print $backoff * 1.5}")
            [[ $(echo "$backoff > 2" | bc) -eq 1 ]] && backoff=2
        done
        
        if [[ ! -d "$STATE_LOCK.dir" ]]; then
            error "Failed to acquire directory lock after ${timeout}s"
            return 1
        fi
        debug_log "Acquired directory lock at $STATE_LOCK.dir"
    fi
    
    return 0
}
```

This refactoring plan ensures opinions-state.sh becomes a model of clarity, maintainability, and proper software engineering principles while preserving all existing functionality.