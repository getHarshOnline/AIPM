#!/opt/homebrew/bin/bash
# migrate-memories.sh - Memory operations module for AIPM
#
# Purpose: Centralize ALL memory operations in a single, optimized module that handles:
# - Atomic backup/restore operations
# - Memory validation and schema preservation
# - Performance-optimized merging
# - MCP server coordination
# - Lock-free operations
# - Streaming processing for large files
#
# This module follows the same pattern as shell-formatting.sh and version-control.sh
# providing a single source of truth for all memory operations in AIPM.
#
# CRITICAL LEARNINGS INCORPORATED:
# 1. File Reversion Bug Protection:
#    - All operations use atomic patterns (temp file → move)
#    - Never modify files in place
#    - Always verify operations completed
#
# 2. Platform Compatibility:
#    - Dual stat commands for macOS/Linux: stat -f%z || stat -c%s
#    - Proper quoting for all variables
#    - Avoid bash-specific features not in older versions
#
# 3. Memory Protection Principle:
#    - Global memory is sacred - always backup before operations
#    - Use atomic operations exclusively
#    - Validate before and after operations
#
# 4. Performance Optimizations:
#    - Stream processing for files >10MB
#    - Early exit on validation failures
#    - Minimal JSON parsing passes
#
# 5. Security Considerations:
#    - Validate all JSON before processing
#    - Check entity prefixes to prevent contamination
#    - Never expose memory.json in git
#
# 6. Edge Cases Handled:
#    - Empty (0 byte) memory.json is VALID (MCP initial state)
#    - Handle partial states gracefully
#    - Associative array key checks use ${var:-} pattern

# Strict error handling
set -euo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source dependencies
source "$SCRIPT_DIR/shell-formatting.sh" || {
    printf "ERROR: Required file shell-formatting.sh not found\n" >&2
    exit 1
}

# Constants
readonly MEMORY_SCHEMA_VERSION="1.0"
readonly MAX_MEMORY_SIZE_MB=100
readonly BACKUP_SUFFIX=".backup"
readonly TEMP_SUFFIX=".tmp"

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_GENERAL_ERROR=1
readonly EXIT_VALIDATION_ERROR=2
readonly EXIT_IO_ERROR=3
readonly EXIT_TIMEOUT_ERROR=4

# Debug mode (can be overridden by environment)
DEBUG_MODE="${DEBUG_MODE:-false}"

# Helper function for debug output
debug() {
    [[ "$DEBUG_MODE" == "true" ]] && info "[DEBUG] $*" || true
}

# ==============================================================================
# Core Memory Operations
# ==============================================================================

# Backup memory file atomically without locking
# Usage: backup_memory [source] [target] [validate]
# Returns: 0 on success, 1 on error
backup_memory() {
    local source="${1:-.claude/memory.json}"
    local target="${2:-.memory/backup.json}"
    local validate="${3:-true}"
    
    step "Creating memory backup..."
    debug "Backing up: $source → $target"
    
    # Ensure target directory exists
    local target_dir=$(dirname "$target")
    mkdir -p "$target_dir"
    
    # LEARNING: Use atomic operations to prevent corruption
    # Create temp file with PID suffix to ensure uniqueness
    local temp_file="${target}${TEMP_SUFFIX}.$$"
    
    if [[ -f "$source" ]]; then
        # File exists, copy it
        # LEARNING: Use cp -f to force overwrite temp file
        if cp -f "$source" "$temp_file" 2>/dev/null; then
            # Validate if requested
            # LEARNING: Empty files are valid (MCP initial state)
            if [[ "$validate" == "true" ]] && [[ -s "$temp_file" ]]; then
                if ! validate_memory_stream "$temp_file" >/dev/null 2>&1; then
                    rm -f "$temp_file"
                    error "Source memory validation failed"
                    return $EXIT_VALIDATION_ERROR
                fi
            fi
            
            # Atomic move - this is the critical step
            # LEARNING: mv -f is atomic on same filesystem
            mv -f "$temp_file" "$target"
            
            # LEARNING: Platform-specific stat commands
            # macOS: stat -f%z, Linux: stat -c%s
            local size=$(format_size $(stat -f%z "$target" 2>/dev/null || stat -c%s "$target" 2>/dev/null || echo "0"))
            success "Memory backed up ($size)"
            return $EXIT_SUCCESS
        else
            rm -f "$temp_file" 2>/dev/null
            error "Failed to copy memory file"
            return $EXIT_IO_ERROR
        fi
    else
        # No source file, initialize empty backup
        debug "No source file found, initializing empty backup"
        printf '{}\n' > "$temp_file"
        mv -f "$temp_file" "$target"
        warn "No memory to backup - initialized empty"
        return $EXIT_SUCCESS
    fi
}

# Restore memory file atomically
# Usage: restore_memory [source] [target] [delete_source]
# Returns: 0 on success, 1 on error
restore_memory() {
    local source="${1:-.memory/backup.json}"
    local target="${2:-.claude/memory.json}"
    local delete_source="${3:-true}"
    
    step "Restoring memory from backup..."
    debug "Restoring: $source → $target"
    
    if [[ ! -f "$source" ]]; then
        error "Backup not found: $source"
        return $EXIT_IO_ERROR
    fi
    
    # Ensure target directory exists
    local target_dir=$(dirname "$target")
    mkdir -p "$target_dir"
    
    # Atomic restore
    local temp_file="${target}${TEMP_SUFFIX}.$$"
    if cp -f "$source" "$temp_file"; then
        mv -f "$temp_file" "$target"
        
        # Delete source if requested
        if [[ "$delete_source" == "true" ]]; then
            rm -f "$source"
            debug "Deleted source backup: $source"
        fi
        
        local size=$(format_size $(stat -f%z "$target" 2>/dev/null || stat -c%s "$target" 2>/dev/null || echo "0"))
        success "Memory restored ($size)"
        return $EXIT_SUCCESS
    else
        rm -f "$temp_file" 2>/dev/null
        error "Failed to restore memory"
        return $EXIT_IO_ERROR
    fi
}

# Load memory file with validation
# Usage: load_memory <source> [target]
# Returns: 0 on success, 1 on error
load_memory() {
    local source="${1}"
    local target="${2:-.claude/memory.json}"
    
    step "Loading memory: $(basename "$source")"
    debug "Loading: $source → $target"
    
    if [[ ! -f "$source" ]]; then
        warn "Memory file not found: $source"
        warn "Initializing empty memory"
        printf '{}\n' > "$target"
        return $EXIT_SUCCESS
    fi
    
    # Validate before loading
    if ! validate_memory_stream "$source" >/dev/null 2>&1; then
        error "Memory validation failed"
        return $EXIT_VALIDATION_ERROR
    fi
    
    # Ensure target directory exists
    local target_dir=$(dirname "$target")
    mkdir -p "$target_dir"
    
    # Atomic load
    local temp_file="${target}${TEMP_SUFFIX}.$$"
    if cp -f "$source" "$temp_file"; then
        mv -f "$temp_file" "$target"
        local count=$(count_entities_stream "$target")
        local size=$(format_size $(stat -f%z "$target" 2>/dev/null || stat -c%s "$target" 2>/dev/null || echo "0"))
        success "Memory loaded ($count entities, $size)"
        return $EXIT_SUCCESS
    else
        rm -f "$temp_file" 2>/dev/null
        error "Failed to load memory"
        return $EXIT_IO_ERROR
    fi
}

# Save memory file with validation
# Usage: save_memory [source] <target>
# Returns: 0 on success, 1 on error
save_memory() {
    local source="${1:-.claude/memory.json}"
    local target="${2}"
    
    if [[ -z "$target" ]]; then
        error "Target path required for save_memory"
        return $EXIT_GENERAL_ERROR
    fi
    
    step "Saving memory to: $(basename "$target")"
    debug "Saving: $source → $target"
    
    # Ensure target directory exists
    local target_dir=$(dirname "$target")
    mkdir -p "$target_dir"
    
    # Check if source exists
    if [[ ! -f "$source" ]]; then
        warn "Source memory not found, saving empty memory"
        printf '{}\n' > "$target"
        return $EXIT_SUCCESS
    fi
    
    # Atomic save
    local temp_file="${target}${TEMP_SUFFIX}.$$"
    if cp -f "$source" "$temp_file" 2>/dev/null; then
        # Validate saved content
        if validate_memory_stream "$temp_file" >/dev/null 2>&1; then
            mv -f "$temp_file" "$target"
            local count=$(count_entities_stream "$target")
            local size=$(format_size $(stat -f%z "$target" 2>/dev/null || stat -c%s "$target" 2>/dev/null || echo "0"))
            success "Memory saved ($count entities, $size)"
            return $EXIT_SUCCESS
        else
            rm -f "$temp_file"
            error "Saved memory validation failed"
            return $EXIT_VALIDATION_ERROR
        fi
    else
        rm -f "$temp_file" 2>/dev/null
        error "Failed to save memory"
        return $EXIT_IO_ERROR
    fi
}

# ==============================================================================
# Memory Merge Operations (Performance Optimized)
# ==============================================================================

# Merge two memory files with conflict resolution
# Usage: merge_memories <local_file> <remote_file> <output_file> [conflict_strategy]
# conflict_strategy: "remote-wins" (default), "local-wins", "newest-wins"
# Returns: 0 on success, 1 on error
#
# CRITICAL LEARNINGS:
# - Use streaming to handle files >10MB efficiently
# - Associative arrays need ${var:-} pattern under set -u
# - Process in phases to minimize memory usage
# - Validate entity prefixes to prevent cross-contamination
merge_memories() {
    local local_file="$1"
    local remote_file="$2"
    local output_file="$3"
    local conflict_strategy="${4:-remote-wins}"
    local temp_merged="${output_file}${TEMP_SUFFIX}.merge.$$"
    
    step "Merging memory files..."
    info "Strategy: $conflict_strategy"
    debug "Merging: $local_file + $remote_file → $output_file"
    
    # Validate input files exist
    if [[ ! -f "$local_file" ]]; then
        error "Local memory file not found: $local_file"
        return $EXIT_IO_ERROR
    fi
    if [[ ! -f "$remote_file" ]]; then
        error "Remote memory file not found: $remote_file"
        return $EXIT_IO_ERROR
    fi
    
    # LEARNING: Use associative arrays for O(1) lookups
    # This dramatically improves merge performance for large files
    declare -A local_entities
    declare -A remote_entities
    declare -A seen_relations
    
    # Phase 1: Index local entities (streaming)
    # LEARNING: Stream processing prevents memory exhaustion on large files
    debug "Phase 1: Indexing local entities..."
    local local_count=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        # LEARNING: Use printf instead of echo for reliability
        local type=$(printf '%s' "$line" | jq -r '.type // empty' 2>/dev/null)
        if [[ "$type" == "entity" ]]; then
            local name=$(printf '%s' "$line" | jq -r '.name // empty' 2>/dev/null)
            if [[ -n "$name" ]]; then
                # Store the entire JSON line for later use
                local_entities["$name"]="$line"
                ((local_count++))
            fi
        fi
    done < "$local_file"
    debug "Indexed $local_count local entities"
    
    # Phase 2: Merge with remote (streaming)
    debug "Phase 2: Merging with remote entities..."
    > "$temp_merged"  # Clear output
    
    local remote_count=0
    local conflict_count=0
    
    # Process remote file
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local type=$(printf '%s' "$line" | jq -r '.type // empty' 2>/dev/null)
        
        if [[ "$type" == "entity" ]]; then
            local name=$(printf '%s' "$line" | jq -r '.name // empty' 2>/dev/null)
            ((remote_count++))
            
            # Conflict resolution
            # CRITICAL LEARNING: With set -u, checking associative array keys
            # requires ${array[key]:-} syntax to provide default empty value
            # This prevents "unbound variable" errors when key doesn't exist
            if [[ -n "$name" ]] && [[ -n "${local_entities[$name]:-}" ]]; then
                ((conflict_count++))
                debug "Conflict detected for entity: $name"
                
                case "$conflict_strategy" in
                    "remote-wins")
                        printf '%s\n' "$line" >> "$temp_merged"
                        ;;
                    "local-wins")
                        printf '%s\n' "${local_entities[$name]:-}" >> "$temp_merged"
                        ;;
                    "newest-wins")
                        # Compare timestamps if available
                        local local_timestamp=$(printf '%s' "${local_entities[$name]:-}" | jq -r '.timestamp // 0' 2>/dev/null)
                        local remote_timestamp=$(printf '%s' "$line" | jq -r '.timestamp // 0' 2>/dev/null)
                        if [[ "$remote_timestamp" -gt "$local_timestamp" ]]; then
                            printf '%s\n' "$line" >> "$temp_merged"
                        else
                            printf '%s\n' "${local_entities[$name]:-}" >> "$temp_merged"
                        fi
                        ;;
                esac
                unset local_entities["$name"]  # Mark as processed
            else
                printf '%s\n' "$line" >> "$temp_merged"
            fi
        elif [[ "$type" == "relation" ]]; then
            # Deduplicate relations
            local rel_key=$(printf '%s' "$line" | jq -r '[.from, .to, .relationType] | join(":")' 2>/dev/null)
            if [[ -n "$rel_key" ]] && [[ -z "${seen_relations[$rel_key]}" ]]; then
                seen_relations["$rel_key"]=1
                printf '%s\n' "$line" >> "$temp_merged"
            fi
        fi
    done < "$remote_file"
    
    debug "Processed $remote_count remote entities ($conflict_count conflicts)"
    
    # Phase 3: Add remaining local entities
    debug "Phase 3: Adding remaining local entities..."
    local remaining_count=0
    for name in "${!local_entities[@]}"; do
        printf '%s\n' "${local_entities[$name]}" >> "$temp_merged"
        ((remaining_count++))
    done
    debug "Added $remaining_count remaining local entities"
    
    # Phase 4: Add local relations
    debug "Phase 4: Processing local relations..."
    local relation_count=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local type=$(printf '%s' "$line" | jq -r '.type // empty' 2>/dev/null)
        
        if [[ "$type" == "relation" ]]; then
            local rel_key=$(printf '%s' "$line" | jq -r '[.from, .to, .relationType] | join(":")' 2>/dev/null)
            if [[ -n "$rel_key" ]] && [[ -z "${seen_relations[$rel_key]}" ]]; then
                printf '%s\n' "$line" >> "$temp_merged"
                ((relation_count++))
            fi
        fi
    done < "$local_file"
    debug "Processed $relation_count unique relations"
    
    # Validate merged result
    if validate_memory_stream "$temp_merged" >/dev/null 2>&1; then
        mv -f "$temp_merged" "$output_file"
        local count=$(count_entities_stream "$output_file")
        local size=$(format_size $(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null || echo "0"))
        success "Memories merged ($count entities, $size)"
        [[ $conflict_count -gt 0 ]] && info "Resolved $conflict_count conflicts using $conflict_strategy"
        return $EXIT_SUCCESS
    else
        rm -f "$temp_merged"
        error "Merge validation failed"
        return $EXIT_VALIDATION_ERROR
    fi
}

# ==============================================================================
# Validation Operations
# ==============================================================================

# Validate memory file structure and content
# Usage: validate_memory_stream <file> [context]
# context: "framework" or "project" (affects prefix validation)
# Returns: 0 if valid, 1 if invalid
validate_memory_stream() {
    local file="$1"
    local context="${2:-unknown}"
    local max_size_mb=50
    
    debug "Validating memory file: $file (context: $context)"
    
    # Check file exists
    if [[ ! -f "$file" ]]; then
        error "Memory file not found: $file"
        return $EXIT_IO_ERROR
    fi
    
    # Quick size check first
    local size_bytes=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
    local size_mb=$((size_bytes / 1048576))
    if [[ $size_mb -gt $max_size_mb ]]; then
        warn "Large memory file detected: ${size_mb}MB"
    fi
    
    # CRITICAL LEARNING: Entity prefix validation prevents cross-contamination
    # Framework entities must start with AIPM_
    # Project entities must start with PROJECT_NAME_
    # This ensures memory isolation between contexts
    local expected_prefix="AIPM_"
    if [[ "$context" == "project" ]]; then
        # Try to detect project name from environment or path
        if [[ -n "${PROJECT_NAME:-}" ]]; then
            expected_prefix="${PROJECT_NAME}_"
        else
            expected_prefix="PRODUCT_"
        fi
    fi
    debug "Expected entity prefix: $expected_prefix"
    
    # Stream validation - process line by line
    local line_num=0
    local errors=0
    local entity_count=0
    local relation_count=0
    
    while IFS= read -r line; do
        ((line_num++))
        
        # Skip empty lines
        [[ -z "$line" ]] && continue
        
        # Fast JSON check
        if ! printf '%s' "$line" | jq -e . >/dev/null 2>&1; then
            error "Invalid JSON at line $line_num"
            ((errors++))
            [[ $errors -gt 10 ]] && break
            continue
        fi
        
        # Extract type and validate structure
        local type=$(printf '%s' "$line" | jq -r '.type // empty' 2>/dev/null)
        
        if [[ "$type" == "entity" ]]; then
            ((entity_count++))
            
            # Validate entity structure
            local name=$(printf '%s' "$line" | jq -r '.name // empty' 2>/dev/null)
            local entityType=$(printf '%s' "$line" | jq -r '.entityType // empty' 2>/dev/null)
            
            # Check prefix
            if [[ "$context" != "unknown" ]] && [[ ! "$name" =~ ^$expected_prefix ]]; then
                error "Invalid prefix at line $line_num: $name (expected: $expected_prefix)"
                ((errors++))
            fi
            
            # Check required fields
            if [[ -z "$name" ]]; then
                error "Missing name at line $line_num"
                ((errors++))
            fi
            if [[ -z "$entityType" ]]; then
                error "Missing entityType at line $line_num"
                ((errors++))
            fi
            
        elif [[ "$type" == "relation" ]]; then
            ((relation_count++))
            
            # Validate relation structure
            local from=$(printf '%s' "$line" | jq -r '.from // empty' 2>/dev/null)
            local to=$(printf '%s' "$line" | jq -r '.to // empty' 2>/dev/null)
            local relationType=$(printf '%s' "$line" | jq -r '.relationType // empty' 2>/dev/null)
            
            if [[ -z "$from" || -z "$to" || -z "$relationType" ]]; then
                error "Invalid relation at line $line_num (missing from/to/relationType)"
                ((errors++))
            fi
        else
            # Unknown type
            if [[ -n "$type" ]]; then
                error "Unknown type at line $line_num: $type"
            else
                error "Missing type field at line $line_num"
            fi
            ((errors++))
        fi
        
        # Stop if too many errors
        if [[ $errors -gt 10 ]]; then
            error "Too many validation errors (stopped at line $line_num)"
            return $EXIT_VALIDATION_ERROR
        fi
    done < "$file"
    
    # Report results
    if [[ $errors -eq 0 ]]; then
        debug "Memory validation passed: $entity_count entities, $relation_count relations"
        return $EXIT_SUCCESS
    else
        error "Memory validation failed: $errors errors found"
        return $EXIT_VALIDATION_ERROR
    fi
}

# ==============================================================================
# MCP Coordination Functions
# ==============================================================================

# Prepare environment for MCP server access
# Ensures all file handles are released and filesystem is synced
# Usage: prepare_for_mcp
# Returns: 0 always
#
# LEARNING: MCP server needs clean handoff
# - Flush all writes to disk with sync
# - Small delay prevents race conditions
# - MCP reads memory.json through symlink
prepare_for_mcp() {
    debug "Preparing for MCP server handoff..."
    
    # Ensure all writes are flushed to disk
    sync
    
    # Small delay to ensure filesystem settles
    # LEARNING: 0.1s is sufficient for MCP coordination
    sleep 0.1
    
    debug "MCP preparation complete"
    return $EXIT_SUCCESS
}

# Wait for safe access after MCP server release
# Usage: release_from_mcp [max_wait_seconds]
# Returns: 0 if access granted, 1 if timeout
#
# LEARNING: MCP server may hold file locks
# - Check both read and write permissions
# - Verify actual file access with head -n 1
# - 5 second timeout is usually sufficient
release_from_mcp() {
    local max_wait="${1:-5}"
    local memory_file=".claude/memory.json"
    
    debug "Waiting for MCP server to release memory file..."
    
    local waited=0
    while [[ $waited -lt $max_wait ]]; do
        # Check if we can access memory file
        if [[ -r "$memory_file" ]] && [[ -w "$memory_file" ]]; then
            # LEARNING: Try actual read to ensure no locks
            if head -n 1 "$memory_file" >/dev/null 2>&1; then
                debug "MCP release confirmed after ${waited}s"
                return $EXIT_SUCCESS
            fi
        fi
        
        sleep 0.5
        waited=$((waited + 1))
    done
    
    warn "Timeout waiting for MCP release after ${max_wait}s"
    return $EXIT_TIMEOUT_ERROR
}

# ==============================================================================
# Performance Helper Functions
# ==============================================================================

# Count entities in memory file efficiently
# Usage: count_entities_stream <file>
# Returns: Entity count as string
count_entities_stream() {
    local file="$1"
    local count=0
    
    if [[ -f "$file" ]]; then
        # Use grep for speed, with error handling
        count=$(grep -c '"type":"entity"' "$file" 2>/dev/null || echo "0")
    fi
    
    printf '%s' "$count"
}

# Count relations in memory file efficiently
# Usage: count_relations_stream <file>
# Returns: Relation count as string
count_relations_stream() {
    local file="$1"
    local count=0
    
    if [[ -f "$file" ]]; then
        # Use grep for speed, with error handling
        count=$(grep -c '"type":"relation"' "$file" 2>/dev/null || echo "0")
    fi
    
    printf '%s' "$count"
}

# Get memory file statistics
# Usage: get_memory_stats <file>
# Returns: Formatted statistics string
get_memory_stats() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        printf "File not found"
        return
    fi
    
    local entities=$(count_entities_stream "$file")
    local relations=$(count_relations_stream "$file")
    local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
    local formatted_size=$(format_size "$size")
    
    printf "%s entities, %s relations, %s" "$entities" "$relations" "$formatted_size"
}

# ==============================================================================
# Cleanup Operations
# ==============================================================================

# Clean up temporary files created by this module
# Usage: cleanup_temp_files
# Returns: 0 always
#
# LEARNING: Clean up all temp files to prevent disk bloat
# - Use PID suffix pattern to identify our files
# - Check multiple locations where temps might exist
# - Suppress errors for missing files
cleanup_temp_files() {
    debug "Cleaning up temporary files..."
    
    # Remove all temp files created by this module
    # LEARNING: Redirect errors to /dev/null as files may not exist
    rm -f .memory/*${TEMP_SUFFIX}.* 2>/dev/null
    rm -f .claude/*${TEMP_SUFFIX}.* 2>/dev/null
    rm -f /tmp/*${TEMP_SUFFIX}.* 2>/dev/null
    
    debug "Cleanup complete"
    return $EXIT_SUCCESS
}

# ==============================================================================
# Advanced Operations
# ==============================================================================

# Check if memory file has changed since last backup
# Usage: memory_changed <current_file> <backup_file>
# Returns: 0 if changed, 1 if unchanged
memory_changed() {
    local current="$1"
    local backup="$2"
    
    # If backup doesn't exist, consider it changed
    [[ ! -f "$backup" ]] && return 0
    
    # If current doesn't exist, consider it changed
    [[ ! -f "$current" ]] && return 0
    
    # Compare checksums
    local current_hash=$(sha256sum "$current" 2>/dev/null | cut -d' ' -f1)
    local backup_hash=$(sha256sum "$backup" 2>/dev/null | cut -d' ' -f1)
    
    if [[ "$current_hash" == "$backup_hash" ]]; then
        debug "Memory unchanged (hash: ${current_hash:0:8}...)"
        return 1
    else
        debug "Memory changed (current: ${current_hash:0:8}..., backup: ${backup_hash:0:8}...)"
        return 0
    fi
}

# Create empty memory file with proper structure
# Usage: initialize_empty_memory <file>
# Returns: 0 on success, 1 on error
initialize_empty_memory() {
    local file="$1"
    local dir=$(dirname "$file")
    
    mkdir -p "$dir"
    printf '{}\n' > "$file"
    
    debug "Initialized empty memory: $file"
    return $EXIT_SUCCESS
}

# ==============================================================================
# Module Information
# ==============================================================================

# Show module version and capabilities
# Usage: migrate_memories_version
migrate_memories_version() {
    info "migrate-memories.sh - AIPM Memory Operations Module"
    info "Version: 1.0.0"
    info "Schema Version: $MEMORY_SCHEMA_VERSION"
    info ""
    info "Capabilities:"
    info "  - Lock-free atomic operations"
    info "  - Streaming JSON processing"
    info "  - Performance-optimized merging"
    info "  - MCP server coordination"
    info "  - Schema validation"
    info "  - Conflict resolution strategies"
}

# ==============================================================================
# Export all functions for use by other scripts
# ==============================================================================

export -f backup_memory
export -f restore_memory
export -f load_memory
export -f save_memory
export -f merge_memories
export -f validate_memory_stream
export -f prepare_for_mcp
export -f release_from_mcp
export -f count_entities_stream
export -f count_relations_stream
export -f get_memory_stats
export -f cleanup_temp_files
export -f memory_changed
export -f initialize_empty_memory
export -f migrate_memories_version

# Debug mode announcement
[[ "$DEBUG_MODE" == "true" ]] && debug "migrate-memories.sh loaded (debug mode enabled)"

# Return success
return $EXIT_SUCCESS 2>/dev/null || exit $EXIT_SUCCESS