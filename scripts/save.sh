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

# TASK 3: Save Global Memory to Local
step "Saving $CONTEXT_DISPLAY memory..."

# Create memory directory if needed
mkdir -p "$(dirname "$LOCAL_MEMORY")"

if [[ -f ".claude/memory.json" ]]; then
    if cp .claude/memory.json "$LOCAL_MEMORY"; then
        # Count entities and relations for statistics
        ENTITY_COUNT=$(grep -c '"type":"entity"' "$LOCAL_MEMORY" 2>/dev/null || echo "0")
        RELATION_COUNT=$(grep -c '"relationType"' "$LOCAL_MEMORY" 2>/dev/null || echo "0")
        
        # Get file size
        local memory_size=$(format_size $(stat -f%z "$LOCAL_MEMORY" 2>/dev/null || stat -c%s "$LOCAL_MEMORY" 2>/dev/null || echo "0"))
        
        success "Saved $ENTITY_COUNT entities, $RELATION_COUNT relations ($memory_size)"
    else
        die "Failed to save memory to $LOCAL_MEMORY"
    fi
else
    warn "No global memory found to save"
    echo '{}' > "$LOCAL_MEMORY"
    info "Created empty memory file"
fi

# TASK 4: Restore Original Memory from Backup
step "Restoring original memory..."

BACKUP_FILE=".memory/backup.json"
if [[ -f "$BACKUP_FILE" ]]; then
    if cp "$BACKUP_FILE" .claude/memory.json 2>/dev/null; then
        rm -f "$BACKUP_FILE"
        success "Original memory restored"
    else
        error "Failed to restore backup"
        warn "Backup preserved at: $BACKUP_FILE"
        # Don't die - memory is saved, just not isolated
    fi
else
    warn "No backup found - memory may not be isolated"
    info "This is normal if save.sh was called standalone"
fi

# TASK 5: Git Operations (Optional)
if [[ -n "$COMMIT_MSG" ]]; then
    step "Committing changes..."
    
    # Use version-control.sh golden rule
    if ! check_git_repo; then
        warn "Not in a git repository - skipping commit"
    else
        # Stage all changes per golden rule
        if ! stage_all_changes; then
            error "Failed to stage changes"
            warn "Memory saved but not committed"
        else
            # Use commit_with_stats for memory files
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
    info "To commit later: git add -A && git commit"
fi

# TASK 6: Suggest Next Steps
section_end

section "Next Steps"
if [[ "$WORK_CONTEXT" == "project" ]]; then
    info "• Push changes to share with team: git push"
    info "• Update project documentation if needed"
    info "• Run: ./scripts/start.sh --project $PROJECT_NAME to continue"
else
    info "• Test framework changes thoroughly"
    info "• Update AIPM documentation if needed"
    info "• Run: ./scripts/start.sh --framework to continue"
fi
section_end