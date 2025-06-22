
#!/opt/homebrew/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/modules/shell-formatting.sh" || exit 1
source "$SCRIPT_DIR/modules/version-control.sh" || exit 1
source "$SCRIPT_DIR/modules/migrate-memories.sh" || exit 1
source "$SCRIPT_DIR/modules/opinions-state.sh" || exit 1

# Header
section "AIPM Memory Time Machine" "↶"

# Parse arguments
WORK_CONTEXT=""
PROJECT_NAME=""
COMMIT_REF=""
LIST_MODE=false
PARTIAL_MODE=false
ENTITY_FILTER=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --framework) WORK_CONTEXT="framework"; shift ;;
        --project) WORK_CONTEXT="project"; PROJECT_NAME="$2"; shift 2 ;;
        --list) LIST_MODE=true; shift ;;
        --partial) PARTIAL_MODE=true; ENTITY_FILTER="${2:-}"; shift; shift ;;
        -h|--help) 
            show_help "revert" "Revert memory to previous state" \
                "--framework:Revert framework memory" \
                "--project NAME:Revert project memory" \
                "--list:Show memory history" \
                "--partial FILTER:Revert only matching entities"
            exit 0 
            ;;
        *) COMMIT_REF="$1"; shift ;;
    esac
done

# Check for active session using existing functions
if [[ "$(get_value 'runtime.session.active')" == "true" ]]; then
    error "Active session detected!"
    info "You have an active session that may have unsaved changes."
    printf "\n"
    
    choice=$(select_with_default "Choose action" \
        "Abort this operation" \
        "Save and stop the session first" \
        "Force continue (may lose changes)")
    
    case "$choice" in
        "Abort this operation")
            die "Operation aborted"
            ;;
        "Save and stop the session first")
            info "Saving current session..."
            create_commit "Auto-save before revert" true && success "Changes saved"
            info "Stopping session..."
            cleanup_session "$(get_value 'runtime.session.id')"
            ;;
        "Force continue (may lose changes)")
            warn "Proceeding without saving..."
            ;;
    esac
fi

# Auto-detect context if not specified
if [[ -z "$WORK_CONTEXT" ]]; then
    WORK_CONTEXT=$(get_project_context)
    [[ -z "$WORK_CONTEXT" ]] && die "No context selected"
fi

# Initialize context
initialize_memory_context "$WORK_CONTEXT" "$PROJECT_NAME"
MEMORY_FILE=$(get_memory_path "$WORK_CONTEXT" "$PROJECT_NAME")

# Handle list mode
if [[ "$LIST_MODE" == "true" ]]; then
    subsection "Memory History"
    show_file_history "$MEMORY_FILE" "--oneline --no-merges" | head -20
    printf "\n"
    info "Use commit hash with revert to restore: $(format_command "./revert.sh HASH")"
    exit 0
fi

# Validate commit
[[ -z "$COMMIT_REF" ]] && die "Commit reference required. Use --list to see history."
validate_commit "$COMMIT_REF" || die "Invalid commit: $COMMIT_REF"
file_exists_in_commit "$COMMIT_REF" "$MEMORY_FILE" || die "No memory file in commit $COMMIT_REF"

# Show preview with visual clarity
subsection "Revert Preview"
draw_line "-" 60
info "Commit: $(get_commit_info "$COMMIT_REF" "%h - %s")"
info "Author: $(get_commit_info "$COMMIT_REF" "%an")"
info "Date: $(get_commit_info "$COMMIT_REF" "%ar")"
info "Memory: $(get_file_from_commit "$COMMIT_REF" "$MEMORY_FILE" | get_memory_stats)"
draw_line "-" 60

# Confirm with clear consequences
warn "This will replace your current memory state!"
confirm "Proceed with revert?" || die "Revert cancelled"

# Perform revert with progress
if [[ "$PARTIAL_MODE" == "true" ]]; then
    execute_with_spinner "Extracting filtered entities: $ENTITY_FILTER" \
        revert_memory_partial "$COMMIT_REF" "$MEMORY_FILE" "$ENTITY_FILTER" "$MEMORY_FILE"
else
    execute_with_spinner "Reverting to $COMMIT_REF" \
        "get_file_from_commit '$COMMIT_REF' '$MEMORY_FILE' > '$MEMORY_FILE'"
fi

# Report success
report_git_operation "memory-reverted" "$COMMIT_REF"
success_box "Memory Reverted Successfully!"
info "Current state: $(get_memory_stats "$MEMORY_FILE")"