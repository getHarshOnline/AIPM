#!/opt/homebrew/bin/bash
#
# revert.sh - Revert memory to previous git state with context awareness
#
# Reference: AIPM_Design_Docs/memory-management.md - "Memory Evolution Tracking"
#
# This script provides version control integration for memory:
# 1. Detects current session context (if active)
# 2. Shows git history for relevant memory file
# 3. Allows selection of previous version
# 4. Handles active session gracefully
# 5. Reverts memory to selected commit
#
# Usage:
#   ./scripts/revert.sh --framework [commit]         # Revert framework memory
#   ./scripts/revert.sh --project Product [commit]   # Revert project memory
#   ./scripts/revert.sh --list --framework           # List framework memory states
#   ./scripts/revert.sh --list --project Product     # List project memory states
#   ./scripts/revert.sh --partial [filter] ...       # Partial revert (specific entities)
#   ./scripts/revert.sh                              # Interactive mode
#
# Examples:
#   ./scripts/revert.sh --framework --partial "AIPM_CONFIG" abc123
#   ./scripts/revert.sh --project Product --partial "PRODUCT_USER" def456
#
# CRITICAL LEARNINGS INCORPORATED:
# 1. Active Session Safety:
#    - Warn if reverting during active session
#    - Suggest saving current state first
#    - Allow override with confirmation
#
# 2. Memory File Validation:
#    - Check commit contains the memory file
#    - Show statistics before/after revert
#    - Create timestamped backup
#
# 3. Interactive Selection:
#    - Show relevant commits with stats
#    - Allow browsing history
#    - Validate commit references
#
# 4. Partial Revert Support:
#    - Revert specific entities by filter
#    - Preserve current state for non-matching entities
#    - Merge old and current memories intelligently
#
# Created by: AIPM Framework
# License: Apache 2.0

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source dependencies with error handling
source "$SCRIPT_DIR/modules/shell-formatting.sh" || {
    printf "ERROR: Required file shell-formatting.sh not found\n" >&2
    exit 1
}

source "$SCRIPT_DIR/modules/version-control.sh" || {
    error "Required file version-control.sh not found"
    exit 1
}

source "$SCRIPT_DIR/modules/migrate-memories.sh" || {
    error "Required file migrate-memories.sh not found"
    exit 1
}

source "$SCRIPT_DIR/modules/opinions-state.sh" || {
    error "Required file opinions-state.sh not found"
    exit 1
}

# Initialize state
ensure_state || {
    error "Failed to initialize state"
    exit 1
}

# Start visual section
section "AIPM Memory Revert"

# Context variables
WORK_CONTEXT=""
PROJECT_NAME=""
COMMIT_REF=""
MEMORY_FILE=""
CONTEXT_DISPLAY=""
LIST_MODE=false
PARTIAL_MODE=false
ENTITY_FILTER=""

# Project detection map
declare -A project_map

# TASK 1: Check for Active Session
# CRITICAL: Reverting during active session can corrupt state
# LEARNING: Offer safe options to user
# - Abort is safest
# - Save first preserves current work
# - Force is dangerous but sometimes needed
if [[ -f ".memory/session_active" ]]; then
    error "Active session detected!"
    warn "Reverting during an active session may cause data loss."
    # Present options to user
    info "Options:"
    info "  1) Abort revert (recommended)"
    info "  2) Save current state first"
    info "  3) Force revert (DANGEROUS)"
    
    read -p "$(format_prompt "Choice [1-3]")" CHOICE
    case $CHOICE in
        1) 
            info "Revert aborted"
            exit 0 
            ;;
        2) 
            step "Saving current state..."
            # Read context from session file
            local session_context=$(grep "Context:" ".memory/session_active" | cut -d' ' -f2-)
            local session_project=$(grep "Project:" ".memory/session_active" | cut -d' ' -f2-)
            
            if [[ "$session_context" == "framework" ]]; then
                "$SCRIPT_DIR/save.sh" --framework "Pre-revert backup: $(date +%Y-%m-%d_%H:%M:%S)"
            else
                "$SCRIPT_DIR/save.sh" --project "$session_project" "Pre-revert backup: $(date +%Y-%m-%d_%H:%M:%S)"
            fi
            ;;
        3) 
            warn "Proceeding with force revert..."
            ;;
        *)
            die "Invalid choice"
            ;;
    esac
fi

# TASK 2: Parse Arguments
step "Parsing arguments..."

while [[ $# -gt 0 ]]; do
    case $1 in
        --framework)
            WORK_CONTEXT="framework"
            shift
            ;;
        --project)
            WORK_CONTEXT="project"
            if [[ -z "$2" ]] || [[ "$2" =~ ^-- ]]; then
                die "--project requires a project name"
            fi
            PROJECT_NAME="$2"
            shift 2
            ;;
        --list)
            LIST_MODE=true
            shift
            ;;
        --partial)
            PARTIAL_MODE=true
            if [[ -n "$2" ]] && [[ ! "$2" =~ ^-- ]]; then
                ENTITY_FILTER="$2"
                shift 2
            else
                shift
            fi
            ;;
        *)
            COMMIT_REF="$1"
            shift
            ;;
    esac
done

# TASK 3: Interactive Context Selection
if [[ -z "$WORK_CONTEXT" ]]; then
    info "Select context to revert:"
    info "  1) Framework (.memory/local_memory.json)"
    
    local project_num=2
    for dir in */; do
        if [[ -f "${dir}.memory/local_memory.json" ]]; then
            project_map[$project_num]="${dir%/}"
            info "  $project_num) Project: ${dir%/}"
            ((project_num++))
        fi
    done
    
    read -p "$(format_prompt "Choice")" CONTEXT_CHOICE
    
    if [[ "$CONTEXT_CHOICE" == "1" ]]; then
        WORK_CONTEXT="framework"
    elif [[ -n "${project_map[$CONTEXT_CHOICE]}" ]]; then
        WORK_CONTEXT="project"
        PROJECT_NAME="${project_map[$CONTEXT_CHOICE]}"
    else
        die "Invalid selection"
    fi
fi

success "Context: $WORK_CONTEXT${PROJECT_NAME:+ - $PROJECT_NAME}"

# TASK 4: Determine Memory File Path
step "Setting up paths..."

# Initialize version control context
initialize_memory_context "--$WORK_CONTEXT" ${PROJECT_NAME:+"$PROJECT_NAME"}

if [[ "$WORK_CONTEXT" == "framework" ]]; then
    MEMORY_FILE=".memory/local_memory.json"
    CONTEXT_DISPLAY="Framework"
else
    MEMORY_FILE="$PROJECT_NAME/.memory/local_memory.json"
    CONTEXT_DISPLAY="Project: $PROJECT_NAME"
fi

# Verify memory file exists in git
if ! is_file_tracked "$MEMORY_FILE"; then
    error "Memory file not tracked in git: $MEMORY_FILE"
    info "Run save.sh first to commit the memory file"
    die "Cannot revert untracked file"
fi

success "Memory file: $MEMORY_FILE"

# TASK 4.5: List Mode - Show available states and exit
if [[ "$LIST_MODE" == "true" ]]; then
    section "Available Memory States for $CONTEXT_DISPLAY"
    
    # Show last 20 commits with memory changes
    info "Recent memory commits:"
    # Use version-control.sh function for file history
    if ! show_file_history "$MEMORY_FILE" "--pretty=format:%h | %ad | %s --date=short -n 20"; then
        error "No memory history found for $MEMORY_FILE"
        exit 1
    fi
    
    section_end
    
    # Show current state statistics
    section "Current Memory State"
    if [[ -f "$MEMORY_FILE" ]]; then
        local stats=$(get_memory_stats "$MEMORY_FILE")
        info "Current: $stats"
        local modified=$(get_file_mtime "$MEMORY_FILE")
        local modified_date=$(date -r "$modified" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -d "@$modified" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "unknown")
        info "Modified: $modified_date"
    else
        warn "Memory file does not exist yet"
    fi
    section_end
    
    info "Usage: ./scripts/revert.sh --$WORK_CONTEXT${PROJECT_NAME:+ $PROJECT_NAME} <commit-hash>"
    exit 0
fi

# TASK 5: Show Git History
section "Recent Memory History for $CONTEXT_DISPLAY"

# Use version-control.sh function for formatted history
show_log 10 "$MEMORY_FILE"

section_end

# TASK 6: Commit Selection
if [[ -z "$COMMIT_REF" ]]; then
    # Prompt for commit selection
    read -p "$(format_prompt "Enter commit hash to revert to (or 'q' to quit)")" COMMIT_REF
    [[ "$COMMIT_REF" == "q" ]] && exit 0
fi

# Validate commit
# LEARNING: Use version-control.sh functions for validation
# - validate_commit checks if commit exists
# - file_exists_in_commit ensures memory file is present
step "Validating commit..."

if ! validate_commit "$COMMIT_REF"; then
    die "Invalid commit reference: $COMMIT_REF"
fi

# Check if commit has the memory file
if ! file_exists_in_commit "$COMMIT_REF" "$MEMORY_FILE"; then
    die "Commit $COMMIT_REF does not contain $MEMORY_FILE"
fi

# Show commit details
info "Will revert to:"
show_log 1 "" "$COMMIT_REF"

# TASK 7: Show Changes Preview
step "Analyzing changes..."

# Show diff preview
section "Changes to be reverted"
if [[ -f "$MEMORY_FILE" ]]; then
    # Get current stats
    local current_entities=$(count_entities_stream "$MEMORY_FILE")
    local current_relations=$(count_relations_stream "$MEMORY_FILE")
    local current_size=$(wc -c < "$MEMORY_FILE" 2>/dev/null || echo "0")
    info "Current state: $current_entities entities, $current_relations relations, $(format_size $current_size)"
fi

# Show diff
show_diff "HEAD" "$COMMIT_REF" "$MEMORY_FILE" | head -30
if [[ $(show_diff "HEAD" "$COMMIT_REF" "$MEMORY_FILE" | wc -l) -gt 30 ]]; then
    info "... (showing first 30 lines)"
fi
section_end

# Confirm
if ! confirm "Proceed with revert?"; then
    info "Revert cancelled"
    exit 0
fi

# TASK 8: Perform Revert
# CRITICAL: Always backup before destructive operations
# LEARNING: Timestamped backups prevent accidental overwrites
step "Creating backup..."

# Create timestamped backup using migrate-memories.sh
# LEARNING: Use date format that sorts chronologically
BACKUP_NAME="$MEMORY_FILE.backup-$(date +%Y%m%d-%H%M%S)"
if ! backup_memory "$MEMORY_FILE" "$BACKUP_NAME" "false"; then
    die "Failed to create backup"
fi

# Perform revert
# LEARNING: checkout_file uses git to restore specific version
step "Reverting to $COMMIT_REF..."

# Begin atomic operation for revert
begin_atomic_operation "revert:$WORK_CONTEXT:$COMMIT_REF"

# Track original uncommitted count
local original_uncommitted=$(count_uncommitted_files)

if [[ "$PARTIAL_MODE" == "true" ]]; then
    # Partial revert - merge specific entities from old version
    info "Performing partial revert${ENTITY_FILTER:+ (filter: $ENTITY_FILTER)}..."
    
    # Extract old version to temp file
    local old_memory="${MEMORY_FILE}.old.$$"
    if ! extract_memory_from_git "$COMMIT_REF" "$MEMORY_FILE" "$old_memory"; then
        rm -f "$old_memory"
        die "Failed to extract memory from commit $COMMIT_REF"
    fi
    
    # Create filtered version of old memory if filter specified
    if [[ -n "$ENTITY_FILTER" ]]; then
        local filtered_memory="${MEMORY_FILE}.filtered.$$"
        > "$filtered_memory"  # Initialize empty
        
        # Extract matching entities and their relations
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            local type=$(printf '%s' "$line" | jq -r '.type // empty' 2>/dev/null)
            
            if [[ "$type" == "entity" ]]; then
                local name=$(printf '%s' "$line" | jq -r '.name // empty' 2>/dev/null)
                if [[ "$name" =~ $ENTITY_FILTER ]]; then
                    printf '%s\n' "$line" >> "$filtered_memory"
                fi
            elif [[ "$type" == "relation" ]]; then
                # Include relations that involve filtered entities
                local from=$(printf '%s' "$line" | jq -r '.from // empty' 2>/dev/null)
                local to=$(printf '%s' "$line" | jq -r '.to // empty' 2>/dev/null)
                if [[ "$from" =~ $ENTITY_FILTER ]] || [[ "$to" =~ $ENTITY_FILTER ]]; then
                    printf '%s\n' "$line" >> "$filtered_memory"
                fi
            fi
        done < "$old_memory"
        
        # Replace old_memory with filtered version
        mv -f "$filtered_memory" "$old_memory"
        
        local filtered_count=$(count_entities_stream "$old_memory")
        info "Filtered to $filtered_count entities matching '$ENTITY_FILTER'"
    fi
    
    # Merge old entities with current (old wins for conflicts)
    if merge_memories "$MEMORY_FILE" "$old_memory" "$MEMORY_FILE" "remote-wins"; then
        rm -f "$old_memory"
        
        # Update state for successful partial revert
        local new_uncommitted=$(count_uncommitted_files)
        update_state "runtime.lastRevert" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" && \
        update_state "runtime.git.uncommittedCount" "$new_uncommitted" && \
        update_state "runtime.memory.lastRevert.type" "partial" && \
        update_state "runtime.memory.lastRevert.commit" "$COMMIT_REF" && \
        update_state "runtime.memory.lastRevert.filter" "${ENTITY_FILTER:-none}"
        
        if [[ $? -eq 0 ]]; then
            commit_atomic_operation
            success "Partial revert completed successfully"
        else
            rollback_atomic_operation
            error "Failed to update state after partial revert"
            warn "Backup available at: $BACKUP_NAME"
            die "State update failed"
        fi
    else
        rm -f "$old_memory"
        rollback_atomic_operation
        error "Partial revert failed"
        warn "Backup available at: $BACKUP_NAME"
        die "Memory merge failed"
    fi
else
    # Full revert - replace entire file
    if checkout_file "$COMMIT_REF" "$MEMORY_FILE"; then
        # Update state for successful full revert
        local new_uncommitted=$(count_uncommitted_files)
        update_state "runtime.lastRevert" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" && \
        update_state "runtime.git.uncommittedCount" "$new_uncommitted" && \
        update_state "runtime.memory.lastRevert.type" "full" && \
        update_state "runtime.memory.lastRevert.commit" "$COMMIT_REF" && \
        update_state "runtime.memory.lastRevert.file" "$MEMORY_FILE"
        
        if [[ $? -eq 0 ]]; then
            commit_atomic_operation
            success "Memory reverted successfully"
        else
            rollback_atomic_operation
            error "Failed to update state after revert"
            warn "Backup available at: $BACKUP_NAME"
            die "State update failed"
        fi
    else
        rollback_atomic_operation
        error "Revert failed"
        warn "Backup available at: $BACKUP_NAME"
        die "Git checkout failed"
    fi
fi

# If active session, need to reload
if [[ -f ".memory/session_active" ]]; then
    warn "Active session detected - restart required"
    info "Run: ./scripts/stop.sh && ./scripts/start.sh --$WORK_CONTEXT${PROJECT_NAME:+ $PROJECT_NAME}"
fi

# TASK 9: Post-Revert Summary
step "Calculating statistics..."

# Get memory statistics using migrate-memories.sh
ENTITY_COUNT=$(count_entities_stream "$MEMORY_FILE")
RELATION_COUNT=$(count_relations_stream "$MEMORY_FILE")
MEMORY_SIZE=$(wc -c < "$MEMORY_FILE" 2>/dev/null || echo "0")

section "Revert Summary"
info "Memory: $MEMORY_FILE"
info "Reverted to: $COMMIT_REF"
info "Entities: $ENTITY_COUNT"
info "Relations: $RELATION_COUNT"
info "Size: $(format_size $MEMORY_SIZE)"
info "Backup: $BACKUP_NAME"
section_end

section "Next Steps"
info "• Review reverted memory state"
info "• Update documentation if needed"
info "• Test functionality affected by revert"
info "• Create new commit to save this state: ./scripts/save.sh --$WORK_CONTEXT${PROJECT_NAME:+ $PROJECT_NAME} 'Reverted to $COMMIT_REF'"
section_end