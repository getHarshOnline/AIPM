#!/opt/homebrew/bin/bash
#
# save.sh - Save memory and commit changes with detailed flow
#
# Reference: AIPM_Design_Docs/memory-management.md - "Memory Flow - Session End"
#
# This script implements the core memory persistence flow:
# 1. Saves global memory to context-specific local_memory.json
# 2. Restores original memory from backup
# 3. Deletes backup to complete isolation
# 4. Optionally commits changes to git with statistics
#
# Usage: 
#   ./scripts/save.sh --framework ["commit message"]        # Framework context
#   ./scripts/save.sh --project Product ["commit message"]  # Project context
#
# Note: This is called by stop.sh but can also be used standalone
#
# CRITICAL LEARNINGS INCORPORATED:
# 1. File Reversion Bug:
#    - Must verify saves actually complete
#    - Use atomic operations via migrate-memories.sh
#    - Check git diff before committing
#
# 2. Golden Rule Implementation:
#    - stage_all_changes ensures all files are tracked
#    - .gitignore properly configured
#    - Never leave untracked files
#
# 3. Memory Protection:
#    - Always restore original memory after save
#    - Validate memory before and after operations
#    - Handle missing backups gracefully
#
# Created by: AIPM Framework
# License: Apache 2.0

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source dependencies with error handling
source "$SCRIPT_DIR/shell-formatting.sh" || {
    printf "ERROR: Required file shell-formatting.sh not found\n" >&2
    exit 1
}

source "$SCRIPT_DIR/version-control.sh" || {
    error "Required file version-control.sh not found"
    exit 1
}

source "$SCRIPT_DIR/migrate-memories.sh" || {
    error "Required file migrate-memories.sh not found"
    exit 1
}

# Start visual section
section "AIPM Memory Save"

# Context variables
WORK_CONTEXT=""
PROJECT_NAME=""
COMMIT_MSG=""
LOCAL_MEMORY=""
CONTEXT_DISPLAY=""

# Statistics
ENTITY_COUNT=0
RELATION_COUNT=0

# TASK 1: Parse Arguments
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
        *)
            # Everything else is the commit message
            COMMIT_MSG="$*"
            break
            ;;
    esac
done

if [[ -z "$WORK_CONTEXT" ]]; then
    error "Must specify --framework or --project NAME"
    info "Usage: $0 --framework [commit message]"
    info "       $0 --project NAME [commit message]"
    die "Missing required context"
fi

success "Context: $WORK_CONTEXT${PROJECT_NAME:+ - $PROJECT_NAME}"

# TASK 2: Determine Memory File Paths
step "Setting up paths..."

# Initialize version control context for path handling
initialize_memory_context "--$WORK_CONTEXT" ${PROJECT_NAME:+"$PROJECT_NAME"}

if [[ "$WORK_CONTEXT" == "framework" ]]; then
    LOCAL_MEMORY=".memory/local_memory.json"
    CONTEXT_DISPLAY="Framework"
else
    LOCAL_MEMORY="$PROJECT_NAME/.memory/local_memory.json"
    CONTEXT_DISPLAY="Project: $PROJECT_NAME"
    
    # Ensure project directory exists
    if [[ ! -d "$PROJECT_NAME" ]]; then
        die "Project directory not found: $PROJECT_NAME"
    fi
    
    # Ensure project memory directory exists
    mkdir -p "$PROJECT_NAME/.memory"
fi

success "Memory path: $LOCAL_MEMORY"

# TASK 3: Save Global Memory to Local (Using migrate-memories.sh)
# CRITICAL: This is where we capture all session learnings
# LEARNING: Use atomic save_memory function to prevent corruption
# The global memory contains all entities created during the session
if ! save_memory ".claude/memory.json" "$LOCAL_MEMORY"; then
    die "Failed to save memory to $LOCAL_MEMORY"
fi

# Get statistics for display
ENTITY_COUNT=$(count_entities_stream "$LOCAL_MEMORY")
RELATION_COUNT=$(count_relations_stream "$LOCAL_MEMORY")

# TASK 4: Restore Original Memory from Backup (Using migrate-memories.sh)
# CRITICAL: This implements the "Global Protection Principle"
# - Global memory must be restored to pre-session state
# - This ensures next session starts clean
# LEARNING: Missing backup is OK for standalone calls
if ! restore_memory; then
    warn "Failed to restore original memory"
    info "This is normal if save.sh was called standalone"
    # Don't die - memory is saved, just not isolated
fi

# TASK 5: Git Operations (Optional)
if [[ -n "$COMMIT_MSG" ]]; then
    step "Committing changes..."
    
    # LEARNING: Golden Rule implementation via version-control.sh
    # - check_git_repo validates we're in a repo
    # - stage_all_changes implements the golden rule
    # - commit_with_stats adds memory statistics to commit
    if ! check_git_repo; then
        warn "Not in a git repository - skipping commit"
    else
        # Stage all changes per golden rule
        # CRITICAL: This ensures NO untracked files remain
        if ! stage_all_changes; then
            error "Failed to stage changes"
            warn "Memory saved but not committed"
        else
            # Use commit_with_stats for memory files
            # LEARNING: Adds entity/relation counts to commit message
            if ! commit_with_stats "$COMMIT_MSG" "$LOCAL_MEMORY"; then
                error "Commit failed"
                warn "Memory saved but not committed"
            else
                success "Changes committed"
                
                # Show brief log
                show_log 1
            fi
        fi
    fi
else
    info "No commit message provided - changes saved locally only"
    info "To commit later: run save.sh with a commit message"
fi

# TASK 6: Suggest Next Steps
section_end

section "Next Steps"
if [[ "$WORK_CONTEXT" == "project" ]]; then
    info "• Push changes to share with team: use push_changes function"
    info "• Update project documentation if needed"
    info "• Run: ./scripts/start.sh --project $PROJECT_NAME to continue"
else
    info "• Test framework changes thoroughly"
    info "• Update AIPM documentation if needed"
    info "• Run: ./scripts/start.sh --framework to continue"
fi

# Clean up any temporary files
cleanup_temp_files

section_end