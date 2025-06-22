#!/opt/homebrew/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/modules/shell-formatting.sh" || exit 1
source "$SCRIPT_DIR/modules/version-control.sh" || exit 1
source "$SCRIPT_DIR/modules/migrate-memories.sh" || exit 1
source "$SCRIPT_DIR/modules/opinions-state.sh" || exit 1

# Parse arguments
WORK_CONTEXT=""
PROJECT_NAME=""
COMMIT_MSG=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --framework) WORK_CONTEXT="framework"; shift ;;
        --project) WORK_CONTEXT="project"; PROJECT_NAME="$2"; shift 2 ;;
        -h|--help) 
            show_help "save" "Save memory checkpoint" \
                "--framework:Save framework memory" \
                "--project NAME:Save project memory"
            exit 0 
            ;;
        *) COMMIT_MSG="$*"; break ;;
    esac
done

# Validate
[[ -z "$WORK_CONTEXT" ]] && die "Must specify --framework or --project NAME"
[[ -z "$COMMIT_MSG" ]] && COMMIT_MSG="Checkpoint: $(date +%Y-%m-%d\ %H:%M:%S)"

# Show what we're saving
section "Creating Memory Checkpoint" "💾"
info "Context: $(format_context "$WORK_CONTEXT" "$PROJECT_NAME")"
info "Message: $COMMIT_MSG"
printf "\n"

# Initialize and check permissions
initialize_memory_context "$WORK_CONTEXT" "$PROJECT_NAME"
ensure_state

# Check if we can save to current branch
if ! can_perform "save" "$(get_current_branch)"; then
    response=$(get_workflow_rule "branchCreation.protectionResponse")
    case "$response" in
        "prompt")
            warn "You're on a protected branch: $(get_current_branch)"
            confirm "Continue anyway?" || die "Save cancelled"
            ;;
        "create-feature")
            info "Creating feature branch for save..."
            create_branch "feature" "save-$(date +%Y%m%d-%H%M%S)"
            ;;
        *) die "Cannot save to protected branch" ;;
    esac
fi

# Get memory path and ensure it's tracked
MEMORY_FILE=$(get_memory_path "$WORK_CONTEXT" "$PROJECT_NAME")
ensure_memory_tracked

# Stage all changes and memory files
execute_with_spinner "Staging all changes" stage_all_changes true

# Get memory stats for reporting
stats=$(get_memory_stats "$MEMORY_FILE")

# Commit changes
if create_commit "$COMMIT_MSG" true; then
    report_git_operation "save-completed" "$(get_branch_commit HEAD)" "{\"stats\": \"$stats\"}"
    success "✓ Checkpoint created successfully!"
    info "  $stats"
    
    # Auto-backup if configured
    if [[ "$(get_workflow_rule "synchronization.autoBackup")" == "on-save" ]]; then
        printf "\n"
        execute_with_spinner "Backing up to remote" push_to_remote
    fi
else
    die "Failed to create checkpoint"
fi