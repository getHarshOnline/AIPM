# AIPM Wrapper Scripts Hardening Plan

## Overview

This document outlines the comprehensive hardening plan for the AIPM wrapper scripts (start.sh, stop.sh, save.sh, revert.sh) based on thorough analysis of the implementation, documentation, and identified edge cases.

**Critical Update**: All memory operations will be centralized in a new `migrate-memories.sh` module, following the same pattern as `version-control.sh` and `shell-formatting.sh`. This ensures single source of truth, performance optimization, and modular architecture.

## Ultimate Vision: AI-Assisted Project Management Guardrails

### Core Memory Protection Principle

**CRITICAL**: Global memory (.claude/memory.json) is sacred and must be protected. It should be exactly the same before and after any AIPM session. This is achieved through:

1. **Backup on Start**: Snapshot global → backup.json
2. **Work in Global**: Load project memory into global for session
3. **Save on Stop**: Capture changes from global → local_memory.json
4. **Restore on Stop**: Restore backup.json → global

This ensures complete isolation between projects and sessions.

### Complete Workflow Vision

The AIPM framework aims to provide a seamless, automatic workflow where:

1. **Clone & Start**: User clones repo → runs `./start.sh` → Everything automatic
2. **Smart Context Detection**: Shows all detected projects, allows selection
3. **Team Memory Sync**: 
   - Pull latest local_memory.json from git
   - Merge team changes into local memory
   - Load merged local memory into global
4. **Branch-Aware Operations**: Guide users through branching strategy
5. **Atomic Operations**: Future two-commit strategy for memory/code separation

### Critical Workflow Requirements

#### 1. Seamless Start Experience
```bash
git clone <repo>
cd AIPM
./scripts/start.sh
# Everything else is automatic with visual feedback
```

#### 2. Memory Sync Operations (CLARIFIED)
Current implementation does backup/restore correctly. Enhancement needed:
- **Upstream Sync**: Pull latest local_memory.json from git
- **Memory Merge**: Merge remote changes into local_memory.json
- **Conflict Resolution**: Handle entity-level conflicts
- **Then Load**: Load merged local_memory.json into global
- **Protect Global**: Always restore global from backup at session end

#### 3. Two-Commit Strategy (FUTURE)
- Commit 1: Memory changes only
- Commit 2: All other files
- Enables: Cherry-picking memory states
- Enables: Clean memory evolution history
- Start with: Single commit (current)
- Plan for: Two-commit implementation

#### 4. Branch Management Wrapper
- Master wrapper over save/start processes
- Guide branch selection based on work context
- Follow current-focus.md branching strategy
- Opinionated flow (TBD)

#### 5. Enhanced Revert Workflow
- Show list of available states with descriptions
- Preview memory differences
- Support partial reverts

## Critical Missing Requirements (MUST ADDRESS)

### Protocol & Security Requirements

1. **Golden Rule Enforcement**
   - CRITICAL: Enforce "Do exactly what .gitignore says - everything else should be added"
   - Validate stage_all_changes() usage in save.sh
   - Ensure all untracked files are properly tracked

2. **Memory Entity Naming Conventions**
   - CRITICAL: Enforce strict prefix requirements (AIPM_ for framework, PROJECT_ for projects)
   - Validate entity names before ANY memory operation
   - Prevent cross-context contamination through naming

3. **Shell Integration Requirements**
   - CRITICAL: NEVER use echo/printf directly
   - CRITICAL: NEVER use git commands directly
   - All output through shell-formatting.sh functions only
   - All git operations through version-control.sh functions only

4. **Memory Schema Validation**
   - Validate NDJSON format (newline-delimited JSON)
   - Enforce required entity fields: type, name, entityType, observations
   - Enforce relation fields: type, from, to, relationType
   - Validate relation integrity (from/to entities must exist)
   
   **Note on printf usage**: Internal JSON processing may use printf for piping to jq.
   This is acceptable for internal operations but all user-facing output MUST use
   shell-formatting.sh functions (info, warn, error, success, etc.)

## New Architecture: migrate-memories.sh Module

### Purpose
Centralize ALL memory operations in a single, optimized module that handles:
- Atomic backup/restore operations
- Memory validation and schema preservation
- Performance-optimized merging
- MCP server coordination
- Lock-free operations
- Streaming processing for large files

### Core Functions to Implement

```bash
#!/opt/homebrew/bin/bash
# migrate-memories.sh - Memory operations module for AIPM

# Source dependencies
source "$SCRIPT_DIR/shell-formatting.sh" || exit 1

# Constants
readonly MEMORY_SCHEMA_VERSION="1.0"
readonly MAX_MEMORY_SIZE_MB=100
readonly BACKUP_SUFFIX=".backup"

# Core Operations

# 1. Backup Operations
backup_memory() {
    local source="${1:-.claude/memory.json}"
    local target="${2:-.memory/backup.json}"
    local validate="${3:-true}"
    
    step "Creating memory backup..."
    
    # Atomic copy without locking
    local temp_file="${target}.tmp.$$"
    if cp -f "$source" "$temp_file" 2>/dev/null; then
        # Validate if requested
        if [[ "$validate" == "true" ]] && [[ -s "$temp_file" ]]; then
            if ! validate_memory_stream "$temp_file" >/dev/null 2>&1; then
                rm -f "$temp_file"
                error "Source memory validation failed"
                return 1
            fi
        fi
        
        # Atomic move
        mv -f "$temp_file" "$target"
        local size=$(format_size $(stat -f%z "$target" 2>/dev/null || stat -c%s "$target"))
        success "Memory backed up ($size)"
        return 0
    else
        rm -f "$temp_file" 2>/dev/null
        [[ ! -f "$source" ]] && warn "No memory to backup - initializing empty"
        printf '{}\\n' > "$target"
        return 0
    fi
}

# 2. Restore Operations
restore_memory() {
    local source="${1:-.memory/backup.json}"
    local target="${2:-.claude/memory.json}"
    local delete_source="${3:-true}"
    
    step "Restoring memory from backup..."
    
    if [[ ! -f "$source" ]]; then
        error "Backup not found: $source"
        return 1
    fi
    
    # Atomic restore
    local temp_file="${target}.tmp.$$"
    if cp -f "$source" "$temp_file"; then
        mv -f "$temp_file" "$target"
        
        # Delete source if requested
        [[ "$delete_source" == "true" ]] && rm -f "$source"
        
        success "Memory restored"
        return 0
    else
        rm -f "$temp_file" 2>/dev/null
        error "Failed to restore memory"
        return 1
    fi
}

# 3. Load Operations
load_memory() {
    local source="${1}"
    local target="${2:-.claude/memory.json}"
    
    step "Loading memory: $(basename "$source")"
    
    if [[ ! -f "$source" ]]; then
        warn "Memory file not found: $source"
        return 1
    fi
    
    # Validate before loading
    if ! validate_memory_stream "$source" >/dev/null 2>&1; then
        error "Memory validation failed"
        return 1
    fi
    
    # Atomic load
    local temp_file="${target}.tmp.$$"
    if cp -f "$source" "$temp_file"; then
        mv -f "$temp_file" "$target"
        local count=$(count_entities_stream "$target")
        success "Memory loaded ($count entities)"
        return 0
    else
        rm -f "$temp_file" 2>/dev/null
        error "Failed to load memory"
        return 1
    fi
}

# 4. Save Operations
save_memory() {
    local source="${1:-.claude/memory.json}"
    local target="${2}"
    
    step "Saving memory to: $(basename "$target")"
    
    # Ensure target directory exists
    local target_dir=$(dirname "$target")
    mkdir -p "$target_dir"
    
    # Atomic save
    local temp_file="${target}.tmp.$$"
    if cp -f "$source" "$temp_file" 2>/dev/null; then
        # Validate saved content
        if validate_memory_stream "$temp_file" >/dev/null 2>&1; then
            mv -f "$temp_file" "$target"
            local count=$(count_entities_stream "$target")
            success "Memory saved ($count entities)"
            return 0
        else
            rm -f "$temp_file"
            error "Saved memory validation failed"
            return 1
        fi
    else
        rm -f "$temp_file" 2>/dev/null
        error "Failed to save memory"
        return 1
    fi
}

# 5. Merge Operations (Performance Optimized)
merge_memories() {
    local local_file="$1"
    local remote_file="$2"
    local output_file="$3"
    local conflict_strategy="${4:-remote-wins}"
    local temp_merged="${output_file}.merge.$$"
    
    step "Merging memory files..."
    
    # Use associative arrays for O(1) lookups
    declare -A local_entities
    declare -A remote_entities
    declare -A seen_relations
    
    # Phase 1: Index local entities (streaming)
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local type=$(printf '%s' "$line" | jq -r '.type // empty' 2>/dev/null)
        if [[ "$type" == "entity" ]]; then
            local name=$(printf '%s' "$line" | jq -r '.name // empty' 2>/dev/null)
            local_entities["$name"]="$line"
        fi
    done < "$local_file"
    
    # Phase 2: Merge with remote (streaming)
    > "$temp_merged"  # Clear output
    
    # Process remote file
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local type=$(printf '%s' "$line" | jq -r '.type // empty' 2>/dev/null)
        
        if [[ "$type" == "entity" ]]; then
            local name=$(printf '%s' "$line" | jq -r '.name // empty' 2>/dev/null)
            
            # Conflict resolution
            if [[ -n "${local_entities[$name]}" ]]; then
                if [[ "$conflict_strategy" == "remote-wins" ]]; then
                    printf '%s\n' "$line" >> "$temp_merged"
                else
                    printf '%s\n' "${local_entities[$name]}" >> "$temp_merged"
                fi
                unset local_entities["$name"]  # Mark as processed
            else
                printf '%s\n' "$line" >> "$temp_merged"
            fi
        elif [[ "$type" == "relation" ]]; then
            # Deduplicate relations
            local rel_key=$(printf '%s' "$line" | jq -r '[.from, .to, .relationType] | join(":")' 2>/dev/null)
            if [[ -z "${seen_relations[$rel_key]}" ]]; then
                seen_relations["$rel_key"]=1
                printf '%s\n' "$line" >> "$temp_merged"
            fi
        fi
    done < "$remote_file"
    
    # Phase 3: Add remaining local entities
    for name in "${!local_entities[@]}"; do
        printf '%s\n' "${local_entities[$name]}" >> "$temp_merged"
    done
    
    # Phase 4: Add local relations
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local type=$(printf '%s' "$line" | jq -r '.type // empty' 2>/dev/null)
        
        if [[ "$type" == "relation" ]]; then
            local rel_key=$(printf '%s' "$line" | jq -r '[.from, .to, .relationType] | join(":")' 2>/dev/null)
            if [[ -z "${seen_relations[$rel_key]}" ]]; then
                printf '%s\n' "$line" >> "$temp_merged"
            fi
        fi
    done < "$local_file"
    
    # Validate merged result
    if validate_memory_stream "$temp_merged" >/dev/null 2>&1; then
        mv -f "$temp_merged" "$output_file"
        local count=$(count_entities_stream "$output_file")
        success "Memories merged ($count entities)"
        return 0
    else
        rm -f "$temp_merged"
        error "Merge validation failed"
        return 1
    fi
}

# 6. Validation Operations
validate_memory_stream() {
    local file="$1"
    local context="${2:-unknown}"
    local max_size_mb=50
    
    # Quick size check first
    local size_mb=$(du -m "$file" | cut -f1)
    if [[ $size_mb -gt $max_size_mb ]]; then
        warn "Large memory file detected: ${size_mb}MB"
    fi
    
    # Determine expected prefix
    local expected_prefix="AIPM_"
    if [[ "$context" == "project" ]]; then
        expected_prefix="${PROJECT_NAME:-PRODUCT}_"
    fi
    
    # Stream validation - process line by line
    local line_num=0
    local errors=0
    
    while IFS= read -r line; do
        ((line_num++))
        
        # Skip empty lines
        [[ -z "$line" ]] && continue
        
        # Fast JSON check
        if ! printf '%s' "$line" | jq -e . >/dev/null 2>&1; then
            error "Invalid JSON at line $line_num"
            ((errors++))
            continue
        fi
        
        # Extract type and validate structure
        local type=$(printf '%s' "$line" | jq -r '.type // empty' 2>/dev/null)
        
        if [[ "$type" == "entity" ]]; then
            local name=$(printf '%s' "$line" | jq -r '.name // empty' 2>/dev/null)
            if [[ ! "$name" =~ ^$expected_prefix ]]; then
                error "Invalid prefix at line $line_num: $name"
                ((errors++))
            fi
            
            # Validate required fields
            local entityType=$(printf '%s' "$line" | jq -r '.entityType // empty' 2>/dev/null)
            if [[ -z "$entityType" ]]; then
                error "Missing entityType at line $line_num"
                ((errors++))
            fi
        elif [[ "$type" == "relation" ]]; then
            # Validate relation structure
            local from=$(printf '%s' "$line" | jq -r '.from // empty' 2>/dev/null)
            local to=$(printf '%s' "$line" | jq -r '.to // empty' 2>/dev/null)
            local relationType=$(printf '%s' "$line" | jq -r '.relationType // empty' 2>/dev/null)
            
            if [[ -z "$from" || -z "$to" || -z "$relationType" ]]; then
                error "Invalid relation at line $line_num"
                ((errors++))
            fi
        else
            error "Unknown type at line $line_num: $type"
            ((errors++))
        fi
        
        # Stop if too many errors
        if [[ $errors -gt 10 ]]; then
            error "Too many validation errors"
            return 1
        fi
    done < "$file"
    
    # Report results
    if [[ $errors -eq 0 ]]; then
        debug "Memory validation passed: $line_num lines"
        return 0
    else
        error "Memory validation failed: $errors errors"
        return 1
    fi
}

# 7. MCP Coordination
prepare_for_mcp() {
    # Ensure all file handles released
    sync
    return 0
}

release_from_mcp() {
    # Wait for safe access
    local max_wait=5
    local waited=0
    
    while [[ $waited -lt $max_wait ]]; do
        # Check if we can access memory
        if [[ -r ".claude/memory.json" ]] && [[ -w ".claude/memory.json" ]]; then
            return 0
        fi
        sleep 0.5
        ((waited++))
    done
    
    warn "Timeout waiting for MCP release"
    return 1
}

# 8. Performance Helpers
count_entities_stream() {
    local file="$1"
    local count=$(grep -c '"type":"entity"' "$file" 2>/dev/null)
    [[ -z "$count" ]] && count=0
    printf '%s' "$count"
}

# 9. Cleanup Operations
cleanup_temp_files() {
    rm -f .memory/*.tmp.* 2>/dev/null
    rm -f .claude/*.tmp.* 2>/dev/null
}

# Export all functions
export -f backup_memory restore_memory load_memory save_memory
export -f merge_memories validate_memory_stream
export -f prepare_for_mcp release_from_mcp
export -f count_entities_stream cleanup_temp_files
```

### Integration Pattern

All wrapper scripts will use migrate-memories.sh functions instead of direct file operations:

```bash
# In start.sh
source "$SCRIPT_DIR/migrate-memories.sh" || die "Required module not found"

# Instead of: cp .claude/memory.json .memory/backup.json
backup_memory || die "Failed to backup memory"

# Instead of: cp local_memory.json .claude/memory.json  
load_memory "$LOCAL_MEMORY" || die "Failed to load project memory"

# In stop.sh
# Instead of: cp .claude/memory.json local_memory.json
save_memory ".claude/memory.json" "$LOCAL_MEMORY" || die "Failed to save"

# Instead of: cp backup.json .claude/memory.json
restore_memory || die "Failed to restore backup"
```

## Critical Areas for Hardening

### 0. MCP Server Coordination (Priority: CRITICAL - NEW)

**Core Principle**: The MCP server MUST have unrestricted access to memory.json during Claude Code sessions

**Critical Design Constraints**:
- AIPM scripts must NEVER lock the global memory.json file
- All operations must be atomic and lock-free
- File handles must be released before Claude Code starts
- Resource acquisition must be POSIX-compliant
- Performance must scale with file size (streaming operations)

**MCP Coordination Flow**:
```
start.sh:
1. backup_memory() → .memory/backup.json
2. load_memory(local_memory.json) → global
3. prepare_for_mcp() - releases file handles
4. Remove session lock (metadata only)
5. Launch Claude Code (MCP takes over)

During Claude Code:
- MCP has full control of memory.json
- No AIPM operations on memory.json
- Session metadata tracks state

stop.sh:
1. Wait for Claude Code to exit
2. release_from_mcp() - ensure safe access
3. save_memory() → local_memory.json
4. restore_memory() → global from backup
5. cleanup_temp_files()
```

**Implementation Requirements**:
- [ ] All memory operations via migrate-memories.sh functions
- [ ] Atomic operations implemented in the module (cp + mv, no flock)
- [ ] Streaming operations centralized in the module
- [ ] prepare_for_mcp() handles filesystem sync
- [ ] release_from_mcp() ensures safe access
- [ ] Performance target: <1s for 10MB files (tested in module)

## Critical Areas for Hardening

### 1. Memory Flow Architecture (Priority: CRITICAL - CORRECTED)

**Core Principle**: Global memory is sacred and must be protected/restored after each session
**Current Implementation**: Backup/restore works correctly - needs enhancement for team sync

**Memory Flow Clarification (Using migrate-memories.sh)**:
```
SESSION START:
1. backup_memory() → .memory/backup.json
2. pull_latest() for git sync (version-control.sh)
3. merge_memories() if remote changes exist
4. load_memory(local_memory.json) → global
5. prepare_for_mcp() before Claude Code launch

SESSION STOP:
1. release_from_mcp() - wait for safe access
2. save_memory(global, local_memory.json)
3. restore_memory(backup.json, global)
4. cleanup_temp_files() - remove all .tmp.* files
5. Global is back to pre-session state
```

**Enhanced Team Collaboration Flow**:
```bash
# In start.sh - Using migrate-memories.sh + version-control.sh
section "Team Memory Synchronization"

# 1. Backup global memory using module
backup_memory || die "Failed to backup global memory"

# 2. Sync with remote using version-control.sh
if [[ "$WORK_CONTEXT" == "project" ]]; then
    step "Checking for team updates..."
    initialize_memory_context "--project" "$PROJECT_NAME"
    
    # Pull latest changes
    if pull_latest "$PROJECT_NAME"; then
        success "Synchronized with team repository"
        
        # 3. Merge if remote changes exist
        if [[ -f "$REMOTE_MEMORY" ]] && [[ "$REMOTE_MEMORY" -nt "$LOCAL_MEMORY" ]]; then
            merge_memories "$LOCAL_MEMORY" "$REMOTE_MEMORY" "$LOCAL_MEMORY"
        fi
    else
        warn "Failed to sync - using local version"
    fi
fi

# 4. Load project memory into global
load_memory "$LOCAL_MEMORY" || die "Failed to load project memory"

# 5. Prepare for MCP
prepare_for_mcp

# In save.sh - Using migrate-memories.sh + version-control.sh
# 1. Save session memory
save_memory ".claude/memory.json" "$LOCAL_MEMORY" || die "Failed to save"

# 2. Stage and commit with version-control.sh
if stage_all_changes; then
    commit_with_stats "Team sync: $MESSAGE" "$LOCAL_MEMORY"
else
    warn "Failed to stage changes"
fi

# 3. Restore backup
restore_memory || die "Failed to restore global memory"
```

**Critical Requirements**:
- [ ] Global memory MUST be restored exactly as it was
- [ ] Backup files (backup*.json) MUST be in .gitignore
- [ ] Only local_memory.json is version controlled
- [ ] Support incremental backups if global changed between sessions
- [ ] Validate backup integrity before restore

**Required .gitignore entries**:
```
# Memory protection
.memory/backup.json
.memory/backup*.json
.memory/.session_lock
.memory/session_*
.claude/

# Never commit global memory
.claude/memory.json
```

### 2. Dynamic NPM Cache Detection (Priority: CRITICAL)

**Current Issue**: sync-memory.sh uses hardcoded paths that may fail with different npm versions
**Impact**: Complete failure to create memory symlink

**Hardening Tasks**:
- [ ] Implement dynamic npm cache detection using `npm config get cache`
- [ ] Add fallback detection for common paths
- [ ] Validate symlink target exists and is writable
- [ ] Handle npm workspace scenarios
- [ ] Add version-specific path patterns
- [ ] Auto-install @modelcontextprotocol/server-memory if missing

**Enhanced Implementation**:
```bash
# In sync-memory.sh
NPM_CACHE=$(npm config get cache 2>/dev/null)
[[ -z "$NPM_CACHE" ]] && NPM_CACHE="$HOME/.npm"
MEMORY_PKG_PATH=$(find "$NPM_CACHE" -name "@modelcontextprotocol" -type d 2>/dev/null | head -1)

# If not found, try npm root
if [[ -z "$MEMORY_PKG_PATH" ]]; then
    NPM_ROOT=$(npm root -g)
    MEMORY_PKG_PATH="$NPM_ROOT/@modelcontextprotocol/server-memory"
fi
```

### 3. Concurrent Session Protection & MCP Coordination (Priority: CRITICAL)

**Current Issue**: Session locking must coordinate with MCP server access
**Impact**: MCP server hangs if global memory.json is locked during Claude Code session

**Critical Design Constraint**: 
- **NEVER lock the global npm cache memory.json file**
- MCP server needs read/write access during Claude Code session
- Locking should only protect our backup/restore operations
- Must use POSIX-compliant resource handling for safe operations

**Hardening Tasks**:
- [ ] Implement session metadata locking (NOT memory file locking)
- [ ] Release all file handles before Claude Code launches
- [ ] Use atomic operations for backup/restore without locking
- [ ] Implement proper resource cleanup on all exit paths
- [ ] Add MCP server health checks before operations
- [ ] Use copy-on-write semantics for safety

**Enhanced Implementation**:
```bash
# Session metadata locking (NOT memory file locking!)
# Protects session state, not the memory file itself

SESSION_LOCK=".memory/.session_lock"
SESSION_STATE=".memory/.session_state"

# Create session lock for metadata only
create_session_lock() {
    local pid=$$
    local timestamp=$(date +%s)
    
    # Lock only session metadata, never memory.json
    if mkdir "$SESSION_LOCK" 2>/dev/null; then
        cat > "$SESSION_LOCK/info" <<EOF
pid:$pid
timestamp:$timestamp
phase:initializing
EOF
        return 0
    else
        # Check if lock is stale
        if [[ -f "$SESSION_LOCK/info" ]]; then
            local lock_pid=$(grep '^pid:' "$SESSION_LOCK/info" | cut -d: -f2)
            if ! kill -0 "$lock_pid" 2>/dev/null; then
                warn "Removing stale lock from PID $lock_pid"
                rm -rf "$SESSION_LOCK"
                return create_session_lock
            fi
        fi
        return 1
    fi
}

# Memory operations are now handled by migrate-memories.sh
# which provides atomic operations without locking:
# - backup_memory() - atomic backup
# - restore_memory() - atomic restore
# - load_memory() - atomic load with validation
# - save_memory() - atomic save with validation

# MCP coordination functions are now in migrate-memories.sh:
# - prepare_for_mcp() - ensures file handles released, syncs filesystem
# - release_from_mcp() - waits for safe access to memory files

# Session lock management (for metadata only, NOT memory files)
update_session_phase() {
    local phase="$1"
    local session_file="$2"
    
    if [[ -f "$session_file/info" ]]; then
        printf '%s\n' "phase:$phase" >> "$session_file/info"
    fi
}
```

**Resource Handling Strategy**:
- All atomic operations centralized in migrate-memories.sh
- prepare_for_mcp() ensures file handle release
- Session locks for metadata only (never memory files)
- Copy-on-write semantics in all module functions
- POSIX-compliant implementation in the module

### 4. Memory File Validation & Performance (Priority: CRITICAL)

**Current Issue**: Validation must be fast and preserve schema integrity
**Impact**: Performance degradation with large files, schema corruption during merge

**Critical Requirements**:
- **NEVER tamper with MCP schema structure**
- Validation must be performance-optimized for large JSON files
- Merge operations must preserve exact NDJSON format
- Stream processing for memory operations (no full file loading)

**Hardening Tasks**:
- [ ] Implement streaming NDJSON validation
- [ ] Add schema-preserving merge algorithm
- [ ] Use jq streaming for large file processing
- [ ] Implement incremental validation during merge
- [ ] Add performance benchmarks for operations
- [ ] Cache validation results when possible
- [ ] Use memory-mapped files for large operations

**Implementation Note**: All validation and merge operations are now centralized in migrate-memories.sh module. The module provides:

- `validate_memory_stream()` - Fast streaming validation
- `merge_memories()` - Performance-optimized merge with conflict resolution
- `count_entities_stream()` - Efficient entity counting
- All operations use streaming to handle large files

Example usage in wrapper scripts:
```bash
# In start.sh - validation is automatic
if ! load_memory "$LOCAL_MEMORY"; then
    die "Memory validation failed"
fi

# Merge operation
if [[ -f "$REMOTE_MEMORY" ]]; then
    merge_memories "$LOCAL_MEMORY" "$REMOTE_MEMORY" "$LOCAL_MEMORY" "remote-wins"
fi
```

**Original Implementation (Now in migrate-memories.sh)**:
```bash
# Fast streaming validation for NDJSON format
validate_memory_stream() {
    local file="$1"
    local context="$2"
    local max_size_mb=50
    
    # Quick size check first
    local size_mb=$(du -m "$file" | cut -f1)
    if [[ $size_mb -gt $max_size_mb ]]; then
        warn "Large memory file detected: ${size_mb}MB"
    fi
    
    # Stream validation - process line by line
    local line_num=0
    local errors=0
    local expected_prefix="AIPM_"
    [[ "$context" == "project" ]] && expected_prefix="${PROJECT_NAME}_"
    
    # Use while read for streaming
    while IFS= read -r line; do
        ((line_num++))
        
        # Skip empty lines
        [[ -z "$line" ]] && continue
        
        # Fast JSON check (avoid jq for each line)
        # Fast JSON check (internal processing - printf for piping)
        if ! printf '%s' "$line" | jq -e . >/dev/null 2>&1; then
            error "Invalid JSON at line $line_num"
            ((errors++))
            continue
        fi
        
        # Extract type and name efficiently
        # Extract type and name efficiently (internal JSON processing)
        local type=$(printf '%s' "$line" | jq -r '.type // empty' 2>/dev/null)
        
        if [[ "$type" == "entity" ]]; then
            local name=$(printf '%s' "$line" | jq -r '.name // empty' 2>/dev/null)
            if [[ ! "$name" =~ ^$expected_prefix ]]; then
                error "Invalid prefix at line $line_num: $name"
                ((errors++))
            fi
        elif [[ "$type" == "relation" ]]; then
            # Validate relation structure without loading all entities
            # Validate relation structure (internal processing)
            local from=$(printf '%s' "$line" | jq -r '.from // empty' 2>/dev/null)
            local to=$(printf '%s' "$line" | jq -r '.to // empty' 2>/dev/null)
            if [[ -z "$from" || -z "$to" ]]; then
                error "Invalid relation at line $line_num"
                ((errors++))
            fi
        fi
        
        # Stop if too many errors
        [[ $errors -gt 10 ]] && die "Too many validation errors"
    done < "$file"
    
    return $errors
}

# High-performance schema-preserving merge
merge_memory_files() {
    local local_file="$1"
    local remote_file="$2"
    local output_file="$3"
    local temp_merged="${output_file}.merge.$$"
    
    # Use associative arrays for O(1) lookups
    declare -A local_entities
    declare -A remote_entities
    declare -A seen_relations
    
    # Phase 1: Index local entities (streaming)
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local type=$(printf '%s' "$line" | jq -r '.type // empty' 2>/dev/null)
        if [[ "$type" == "entity" ]]; then
            local name=$(printf '%s' "$line" | jq -r '.name // empty' 2>/dev/null)
            local_entities["$name"]="$line"
        fi
    done < "$local_file"
    
    # Phase 2: Merge with remote (streaming)
    > "$temp_merged"  # Clear output
    
    # Process remote file
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        # Extract type and name efficiently (internal JSON processing)
        local type=$(printf '%s' "$line" | jq -r '.type // empty' 2>/dev/null)
        
        if [[ "$type" == "entity" ]]; then
            local name=$(printf '%s' "$line" | jq -r '.name // empty' 2>/dev/null)
            
            # Conflict resolution: remote wins for existing entities
            if [[ -n "${local_entities[$name]}" ]]; then
                # Could implement more sophisticated merge here
                # Append to merged file (internal operation)
                printf '%s\n' "$line" >> "$temp_merged"
                unset local_entities["$name"]  # Mark as processed
            else
                # Append to merged file (internal operation)
                printf '%s\n' "$line" >> "$temp_merged"
            fi
        elif [[ "$type" == "relation" ]]; then
            # Deduplicate relations
            local rel_key=$(printf '%s' "$line" | jq -r '[.from, .to, .relationType] | join(":")' 2>/dev/null)
            if [[ -z "${seen_relations[$rel_key]}" ]]; then
                seen_relations["$rel_key"]=1
                # Append to merged file (internal operation)
                printf '%s\n' "$line" >> "$temp_merged"
            fi
        fi
    done < "$remote_file"
    
    # Phase 3: Add remaining local entities
    for name in "${!local_entities[@]}"; do
        # Add remaining local entity
        printf '%s\n' "${local_entities[$name]}" >> "$temp_merged"
    done
    
    # Phase 4: Add local relations
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local type=$(printf '%s' "$line" | jq -r '.type // empty' 2>/dev/null)
        
        if [[ "$type" == "relation" ]]; then
            local rel_key=$(printf '%s' "$line" | jq -r '[.from, .to, .relationType] | join(":")' 2>/dev/null)
            if [[ -z "${seen_relations[$rel_key]}" ]]; then
                # Append to merged file (internal operation)
                printf '%s\n' "$line" >> "$temp_merged"
            fi
        fi
    done < "$local_file"
    
    # Atomic replace
    mv -f "$temp_merged" "$output_file"
}

# Performance monitoring wrapper
time_operation() {
    local op_name="$1"
    shift
    local start_time=$(date +%s.%N)
    
    "$@"
    local result=$?
    
    local end_time=$(date +%s.%N)
    local duration=$(printf '%s' "$end_time - $start_time" | bc)
    
    debug "$op_name completed in ${duration}s"
    return $result
}
```

### 5. Platform Compatibility Enhancement (Priority: MEDIUM)

**Current Issue**: Incomplete handling of platform differences
**Impact**: Script failures on certain platforms

**Hardening Tasks**:
- [ ] Create comprehensive platform detection function
- [ ] Handle WSL (Windows Subsystem for Linux) specifically
- [ ] Abstract all platform-specific commands
- [ ] Add CI testing for multiple platforms
- [ ] Document platform requirements clearly

**Implementation**:
```bash
# Add to shell-formatting.sh or new platform-utils.sh
detect_platform() {
    # Sets PLATFORM variable instead of echoing
    case "$(uname -s)" in
        Linux*)     
            if [[ -f /proc/version ]] && grep -q Microsoft /proc/version; then
                PLATFORM="wsl"
            else
                PLATFORM="linux"
            fi
            ;;
        Darwin*)    PLATFORM="macos";;
        *)          PLATFORM="unknown";;
    esac
    
    # For debugging
    debug "Detected platform: $PLATFORM"
}
```

### 5. Session Lifecycle Management (Priority: MEDIUM)

**Current Issue**: No automatic cleanup of stale sessions
**Impact**: Confusion and potential data issues

**Hardening Tasks**:
- [ ] Add session heartbeat mechanism
- [ ] Implement stale session detection on start
- [ ] Add session recovery options
- [ ] Create session list/status command
- [ ] Add forced cleanup option

### 6. Error Recovery Enhancement (Priority: HIGH)

**Current Issue**: Inconsistent error handling and recovery
**Impact**: Users stuck without clear path forward

**Hardening Tasks**:
- [ ] Standardize all error messages with recovery hints
- [ ] Add rollback mechanisms for failed operations
- [ ] Implement transaction-like operations
- [ ] Add diagnostic mode for troubleshooting
- [ ] Create recovery script for common issues

### 7. Git Integration Hardening (Priority: MEDIUM)

**Current Issue**: Some git edge cases not fully handled
**Impact**: Potential conflicts or data loss

**Hardening Tasks**:
- [ ] Handle detached HEAD state
- [ ] Improve merge conflict detection
- [ ] Add pre-flight checks for all git operations
- [ ] Handle missing upstream branches
- [ ] Add git hook integration for memory validation

### 8. Memory Performance Optimization (Priority: CRITICAL)

**Current Issue**: Memory operations must be blazing fast as files grow
**Impact**: User experience degrades with large memory files

**Performance Requirements**:
- Sub-second operations for files up to 10MB
- Linear scaling with file size (no O(n²) operations)
- Streaming processing (never load full file into memory)
- Zero impact on MCP server performance

**Hardening Tasks**:
- [ ] Implement streaming JSON processing throughout
- [ ] Use memory-mapped files for large operations
- [ ] Add parallel processing for independent operations
- [ ] Implement incremental backups for unchanged portions
- [ ] Cache frequently accessed data (entity counts, etc.)
- [ ] Use binary search for sorted operations
- [ ] Add performance profiling hooks
- [ ] Implement copy-on-write where possible

**Performance Optimization Techniques**:
```bash
# Example: Fast entity counting without loading file
count_entities_stream() {
    local file="$1"
    # Use grep -c for raw speed
    # Use grep for speed, return 0 if no matches
    local count=$(grep -c '"type":"entity"' "$file" 2>/dev/null)
    [[ -z "$count" ]] && count=0
    printf '%s' "$count"
}

# Example: Parallel validation
validate_parallel() {
    local file="$1"
    local chunks=4
    
    # Split file for parallel processing
    split -n l/$chunks "$file" "$file.chunk."
    
    # Validate in parallel
    for chunk in "$file.chunk."*; do
        validate_chunk "$chunk" &
    done
    wait
    
    # Cleanup
    rm -f "$file.chunk."*
}

# Example: Incremental backup
incremental_backup() {
    local source="$1"
    local target="$2"
    local hash_file="$target.hash"
    
    # Check if content changed
    local current_hash=$(sha256sum "$source" | cut -d' ' -f1)
    if [[ -f "$hash_file" ]]; then
        local stored_hash=$(cat "$hash_file")
        [[ "$current_hash" == "$stored_hash" ]] && return 0
    fi
    
    # Only backup if changed
    cp -f "$source" "$target"
    # Store hash for next comparison
    printf '%s\n' "$current_hash" > "$hash_file"
}
```

## Missing Workflow & Integration Requirements

### Session Management
- Session file format specification with all required fields
- Session archival as session_${SESSION_ID}_complete
- Session log handling and format
- DID_STASH tracking for safe operations

### Team Collaboration
- Memory merge capabilities for team synchronization
- Selective memory import/export
- Branch-specific memory isolation
- Memory diff between branches

### Documentation Structure
- Validate standardized project structure
- Check for required files: CLAUDE.md, README.md, etc.
- Enforce data/ directory for project files
- Project-specific CLAUDE.md protocol loading

## Script-Specific Hardening

### start.sh - Complete Workflow Implementation

1. **Phase 1: Initial Setup**
   - [ ] Call hardened sync-memory.sh automatically
   - [ ] Use `step "Setting up memory system..."` for progress
   - [ ] Use shell-formatting.sh functions for all output
   - [ ] Validate npm cache and create symlink
   - [ ] Handle first-time setup gracefully

2. **Phase 2: Context Detection**
   - [ ] Scan for all projects with .memory/local_memory.json
   - [ ] Display interactive menu with visual formatting
   - [ ] Show project stats (last modified, memory size)
   - [ ] Support new project initialization

3. **Phase 3: Memory Synchronization**
   - [ ] Backup global memory atomically (no locking)
   - [ ] Use `pull_latest` from version-control.sh for git sync
   - [ ] If remote changes exist, merge with performance optimization
   - [ ] Validate merged memory before loading
   - [ ] Load local_memory.json into global
   - [ ] Release all file handles before MCP activation
   - [ ] Use `step`, `info`, `success` for all progress messages

4. **Phase 4: Session Initialization**
   - [ ] Create session with full metadata
   - [ ] Validate memory loaded correctly
   - [ ] Create session metadata lock (NOT memory file lock)
   - [ ] Release all file handles and locks
   - [ ] Sync filesystem to ensure writes are flushed
   - [ ] Launch: `claude code --model "opus"`
   - [ ] Session lock removed to indicate MCP is in control

**Complete Flow Example (with actual functions)**:
```bash
$ ./scripts/start.sh

# The script would source all required modules:
source "$SCRIPT_DIR/shell-formatting.sh" || exit 1
source "$SCRIPT_DIR/version-control.sh" || exit 1
source "$SCRIPT_DIR/migrate-memories.sh" || exit 1

section "AIPM Session Initialization"

# Phase 1: Setup
step "Setting up memory system..."
if [[ ! -L ".claude/memory.json" ]]; then
    "$SCRIPT_DIR/sync-memory.sh" || die "Memory setup failed"
fi
success "Memory symlink verified"

# Phase 2: Context selection
info "Available contexts:"
info "  1) Framework Development"
# ... project detection using proper functions

# Phase 3: Memory sync using migrate-memories.sh
# Backup global memory
backup_memory || die "Failed to backup global memory"

# Using version-control.sh functions for git sync
step "Checking for team updates..."
initialize_memory_context "--project" "Product"
fetch_remote "Product"

local commits_behind=$(get_commits_ahead_behind | grep -o 'behind: [0-9]*' | cut -d' ' -f2)
if [[ "$commits_behind" -gt 0 ]]; then
    success "Found $commits_behind new memory updates from team"
    pull_latest "Product"
    
    # Merge if remote is newer
    if [[ -f "$REMOTE_MEMORY" ]] && [[ "$REMOTE_MEMORY" -nt "$LOCAL_MEMORY" ]]; then
        merge_memories "$LOCAL_MEMORY" "$REMOTE_MEMORY" "$LOCAL_MEMORY"
    fi
fi

# Load project memory using module
load_memory "$LOCAL_MEMORY" || die "Failed to load project memory"

# Prepare for MCP handoff
prepare_for_mcp
success "Session ready"

info "Launching Claude Code..."
section_end

# Launch Claude Code
claude code --model "opus"
```

### stop.sh

1. **Session State Validation**
   - [ ] Use `release_from_mcp()` to wait for safe access
   - [ ] Verify all session components exist
   - [ ] Handle partial session states
   - [ ] Add emergency stop mode
   - [ ] Update session phase with metadata lock

2. **Save Integration**
   - [ ] Call save.sh with proper context
   - [ ] save.sh uses `save_memory()` from module
   - [ ] Handle failures with retry mechanism
   - [ ] Module ensures atomic operations
   - [ ] Preserve memory on critical failures

3. **Memory Restoration**
   - [ ] Use `restore_memory()` from module
   - [ ] Automatic backup cleanup after restore
   - [ ] Validate restored state
   - [ ] Call `cleanup_temp_files()` at end

### save.sh

1. **Memory Save Flow**
   - [ ] Source migrate-memories.sh module
   - [ ] Use `save_memory()` for atomic save
   - [ ] Module handles validation automatically
   - [ ] Use `restore_memory()` for backup restore
   - [ ] Module ensures no file locking
   - [ ] Performance monitoring built into module
   - [ ] All operations are streaming-enabled

2. **Git Integration**
   - [ ] Stage local_memory.json for commit
   - [ ] Use golden rule for other files
   - [ ] Support two-commit strategy (future)
   - [ ] Handle merge conflicts if needed

**Example Implementation**:
```bash
# save.sh implementation using modules
source "$SCRIPT_DIR/shell-formatting.sh" || exit 1
source "$SCRIPT_DIR/version-control.sh" || exit 1
source "$SCRIPT_DIR/migrate-memories.sh" || exit 1

# Parse context
WORK_CONTEXT="$1"
PROJECT_NAME="$2"
COMMIT_MSG="${3:-Session save}"

# Initialize context
initialize_memory_context "--$WORK_CONTEXT" ${PROJECT_NAME:+"$PROJECT_NAME"}

# Determine memory file path
if [[ "$WORK_CONTEXT" == "framework" ]]; then
    LOCAL_MEMORY=".memory/local_memory.json"
else
    LOCAL_MEMORY="$PROJECT_NAME/.memory/local_memory.json"
fi

# Save current global memory to local
save_memory ".claude/memory.json" "$LOCAL_MEMORY" || die "Failed to save memory"

# Git operations if commit requested
if [[ -n "$COMMIT_MSG" ]]; then
    stage_all_changes || die "Failed to stage changes"
    commit_with_stats "$COMMIT_MSG" "$LOCAL_MEMORY" || die "Commit failed"
fi

# Restore original global memory
restore_memory || die "Failed to restore backup"

# Cleanup
cleanup_temp_files
```

### revert.sh

1. **Safety Checks**
   - [ ] Add dry-run mode
   - [ ] Improve diff preview
   - [ ] Add multiple backup retention

2. **Commit Validation**
   - [ ] Verify commit has valid memory structure
   - [ ] Handle partial reverts
   - [ ] Add cherry-pick support

## Testing Strategy

### Unit Tests
- [ ] Create test framework using bats or similar
- [ ] Test each function in isolation
- [ ] Mock all external dependencies
- [ ] Test error paths explicitly

### Integration Tests
- [ ] Full workflow tests (start → save → stop)
- [ ] Multi-project scenarios
- [ ] Concurrent session tests
- [ ] Platform-specific tests

### Stress Tests
- [ ] Large memory files (>10MB)
- [ ] Many projects (>20)
- [ ] Rapid session creation/destruction
- [ ] Network failure scenarios

## Additional Hardening Requirements

### Memory Operations (Centralized in migrate-memories.sh)
- [ ] Implement migrate-memories.sh module with all functions
- [ ] Lock-free atomic operations in all module functions
- [ ] Streaming processing throughout the module
- [ ] Memory validation integrated into load/save operations
- [ ] Schema-preserving merge algorithm
- [ ] Performance benchmarks for module functions
- [ ] Copy-on-write semantics in module implementation
- [ ] Cleanup operations for temporary files

### Network & Authentication
- [ ] SSH key handling for private repos
- [ ] Authentication failure recovery
- [ ] Network timeout handling
- [ ] Offline mode improvements

### Advanced Features
- [ ] Memory analytics and health metrics
- [ ] Project template support
- [ ] Debug mode with diagnostic data
- [ ] Performance profiling hooks

## Implementation Priority (Revised for Complete Vision)

1. **Phase 0 - migrate-memories.sh Module** (Immediate - CRITICAL)
   - Implement complete migrate-memories.sh module
   - All memory operations in single source of truth
   - Schema-preserving merge algorithm
   - Streaming operations for performance
   - Lock-free atomic operations throughout
   - MCP coordination functions (prepare/release)
   - Performance benchmarks for all functions
   - Complete function exports for wrapper scripts
   - This is the foundation for all wrapper scripts

2. **Phase 1 - Core Protocol & Hardening** (Week 1)
   - Golden Rule enforcement
   - Entity naming validation
   - Dynamic NPM cache detection
   - Enhanced sync-memory.sh
   - Seamless start.sh workflow

3. **Phase 2 - Branch Management Wrapper** (Week 2)
   - Branch selection UI
   - Follow current-focus.md strategy
   - Memory-aware branch operations
   - Opinionated workflow implementation
   - Integration with save/start

4. **Phase 3 - Advanced Features** (Week 3)
   - Two-commit strategy planning
   - Enhanced revert with state list
   - Memory analytics
   - Platform compatibility
   - Performance optimization

5. **Phase 4 - Testing & Documentation** (Week 4)
   - Comprehensive test suite
   - User documentation
   - Video tutorials
   - Example workflows

## Branching Strategy Integration

### Workflow from current-focus.md
```
main
└─> feature_branch
    └─> test_branch
        └─> implementation_branch
```

### Wrapper Integration
- start.sh: Help select appropriate branch
- save.sh: Guide commit to right branch
- Branch-aware memory isolation
- Prevent cross-branch contamination

## Implementation Standards

### Function Patterns
- All functions must have explicit return statements
- Local variables must be declared with 'local'
- Original directory must be restored if changed
- Error codes must follow standardized set

### Testing Patterns  
- Follow component testing branch structure
- Each feature gets isolated test branch
- Full regression test suite required
- Test data generation strategies

### Code Patterns
```bash
# Example of required pattern
function_name() {
    local arg="$1"
    local original_dir=$(pwd)
    
    # Main logic
    
    # Restore directory
    [[ "$original_dir" != "$(pwd)" ]] && cd "$original_dir" >/dev/null
    
    return $EXIT_SUCCESS
}
```

## Complete User Journey (Clone to Claude)

### The Ultimate AIPM Experience
```bash
# Step 1: Clone and start
git clone https://github.com/org/aipm-project
cd aipm-project
./scripts/start.sh

# Step 2: Automatic setup (no manual steps!)
# - NPM cache detection and symlink creation
# - Project detection and interactive selection
# - Backup global memory to backup.json
# - Pull latest team changes to local_memory.json
# - Merge team changes if needed
# - Load local_memory.json into global
# - Claude Code launch

# Step 3: Work in Claude Code
# - Global memory contains project memory
# - All changes happen in global space
# - MCP updates global throughout session

# Step 4: Save and stop
./scripts/stop.sh
# - Automatic save.sh call:
#   - Save global → local_memory.json
#   - Restore backup.json → global
#   - Global is back to pre-session state
# - Clean exit
```

### Key Differentiators
1. **Zero Configuration**: Works immediately after clone
2. **Intelligent Merging**: Not just backup/restore
3. **Team Aware**: Pulls and merges team changes
4. **Branch Aware**: Guides through branching strategy
5. **Visual Feedback**: Every step shown clearly
6. **Atomic Operations**: Safe at every step

## Success Metrics

- Golden Rule compliance: 100%
- Entity naming validation: 100%
- Zero data loss scenarios
- Memory merge success rate: 95%+
- Clone-to-Claude time: < 30 seconds
- **Memory operation performance: < 1s for files up to 10MB**
- **MCP server never blocked by locks**
- **Zero schema corruption incidents**
- **Resource cleanup: 100% on all exit paths**
- Clear error messages with recovery paths
- Platform compatibility (macOS, Linux, WSL)
- Session management reliability
- Performance with large memory files (streaming)
- Team collaboration features
- Protocol compliance verification

## Modular Architecture Summary

The AIPM wrapper scripts follow a strict modular architecture:

### Module Dependencies
```
wrapper scripts (start.sh, stop.sh, save.sh, revert.sh)
    ├── shell-formatting.sh    # ALL output operations
    ├── version-control.sh     # ALL git operations  
    └── migrate-memories.sh    # ALL memory operations (NEW)
```

### Key Benefits of Modular Approach
1. **Single Source of Truth**: Each module owns its domain completely
2. **Performance Optimization**: Centralized optimization efforts
3. **Consistent Error Handling**: All modules follow same patterns
4. **Easy Testing**: Test modules in isolation
5. **Future Enhancements**: Add features in one place

### Module Responsibilities

**shell-formatting.sh**:
- All user output (info, warn, error, success, step)
- Visual formatting and sections
- Progress indicators
- Platform-specific formatting

**version-control.sh**:
- All git operations (fetch, pull, commit, etc.)
- Branch management
- Stash handling
- Memory context initialization

**migrate-memories.sh** (NEW):
- All memory file operations
- Atomic backup/restore
- Memory validation
- Performance-optimized merging
- MCP coordination
- Temporary file cleanup

### Implementation Order
1. First: Implement migrate-memories.sh module
2. Then: Update wrapper scripts to use all three modules
3. Finally: Test the complete integrated system

## Related Documents

- AIPM_Design_Docs/memory-management.md
- scripts/test/workflow.md
- scripts/test/version-control.md
- AIPM.md
- current-focus.md