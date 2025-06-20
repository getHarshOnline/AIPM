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
#   ./scripts/revert.sh                              # Interactive mode
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
section "AIPM Memory Revert"

# Context variables
WORK_CONTEXT=""
PROJECT_NAME=""
COMMIT_REF=""
MEMORY_FILE=""
CONTEXT_DISPLAY=""

# Project detection map
declare -A project_map

# TASK 1: Check for Active Session
if [[ -f ".memory/session_active" ]]; then
    error "Active session detected!"
    warn "Reverting during an active session may cause data loss."
    echo ""
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

# TASK 5: Show Git History
section "Recent Memory History for $CONTEXT_DISPLAY"

# Use version-control.sh function for formatted history
show_log 10 "$MEMORY_FILE"

section_end

# TASK 6: Commit Selection
if [[ -z "$COMMIT_REF" ]]; then
    echo ""
    read -p "$(format_prompt "Enter commit hash to revert to (or 'q' to quit)")" COMMIT_REF
    [[ "$COMMIT_REF" == "q" ]] && exit 0
fi

# Validate commit
step "Validating commit..."

if ! git cat-file -e "$COMMIT_REF" 2>/dev/null; then
    die "Invalid commit reference: $COMMIT_REF"
fi

# Check if commit has the memory file
if ! git show "$COMMIT_REF:$MEMORY_FILE" &>/dev/null; then
    die "Commit $COMMIT_REF does not contain $MEMORY_FILE"
fi

# Show commit details
info "Will revert to:"
git log -1 --oneline "$COMMIT_REF"

# TASK 7: Show Changes Preview
step "Analyzing changes..."

# Show diff preview
section "Changes to be reverted"
git diff HEAD "$COMMIT_REF" -- "$MEMORY_FILE" | head -30
if [[ $(git diff HEAD "$COMMIT_REF" -- "$MEMORY_FILE" | wc -l) -gt 30 ]]; then
    info "... (showing first 30 lines)"
fi
section_end

# Confirm
if ! confirm "Proceed with revert?"; then
    info "Revert cancelled"
    exit 0
fi

# TASK 8: Perform Revert
step "Creating backup..."

# Create timestamped backup
BACKUP_NAME="$MEMORY_FILE.backup-$(date +%Y%m%d-%H%M%S)"
cp "$MEMORY_FILE" "$BACKUP_NAME"
success "Backup created: $BACKUP_NAME"

# Perform revert
step "Reverting to $COMMIT_REF..."

if git checkout "$COMMIT_REF" -- "$MEMORY_FILE"; then
    success "Memory reverted successfully"
else
    error "Revert failed"
    warn "Backup available at: $BACKUP_NAME"
    die "Git checkout failed"
fi

# If active session, need to reload
if [[ -f ".memory/session_active" ]]; then
    warn "Active session detected - restart required"
    info "Run: ./scripts/stop.sh && ./scripts/start.sh --$WORK_CONTEXT${PROJECT_NAME:+ $PROJECT_NAME}"
fi

# TASK 9: Post-Revert Summary
step "Calculating statistics..."

# Count entities and relations
ENTITY_COUNT=$(grep -c '"type":"entity"' "$MEMORY_FILE" 2>/dev/null || echo "0")
RELATION_COUNT=$(grep -c '"relationType"' "$MEMORY_FILE" 2>/dev/null || echo "0")
MEMORY_SIZE=$(format_size $(stat -f%z "$MEMORY_FILE" 2>/dev/null || stat -c%s "$MEMORY_FILE" 2>/dev/null || echo "0"))

section "Revert Summary"
info "Memory: $MEMORY_FILE"
info "Reverted to: $COMMIT_REF"
info "Entities: $ENTITY_COUNT"
info "Relations: $RELATION_COUNT"
info "Size: $MEMORY_SIZE"
info "Backup: $BACKUP_NAME"
section_end

section "Next Steps"
info "• Review reverted memory state"
info "• Update documentation if needed"
info "• Test functionality affected by revert"
info "• Create new commit to save this state: ./scripts/save.sh --$WORK_CONTEXT${PROJECT_NAME:+ $PROJECT_NAME} 'Reverted to $COMMIT_REF'"
section_end