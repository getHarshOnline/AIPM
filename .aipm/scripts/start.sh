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
claude_args=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --framework) WORK_CONTEXT="framework"; shift ;;
        --project) WORK_CONTEXT="project"; PROJECT_NAME="$2"; shift 2 ;;
        --model) claude_args+=("--model" "$2"); shift 2 ;;
        -h|--help) 
            show_help "start" "Start AIPM session" \
                "--framework:Start framework session" \
                "--project NAME:Start project session" \
                "--model MODEL:Claude model to use"
            exit 0 
            ;;
        *) claude_args+=("$1"); shift ;;
    esac
done

# Welcome message
clear_screen
draw_header "Welcome to AIPM" "✨"
printf "\n"

# Setup memory system
execute_with_spinner "Preparing memory system" ensure_memory_symlink

# Auto-detect context if not specified
if [[ -z "$WORK_CONTEXT" ]]; then
    info "Select your workspace:"
    WORK_CONTEXT=$(get_project_context)
    [[ -z "$WORK_CONTEXT" ]] && die "No context selected"
fi

# Initialize context
section "Starting Session"
initialize_memory_context "$WORK_CONTEXT" "$PROJECT_NAME"
ensure_state

# Create session with visual feedback
SESSION_ID=""
if create_session "$WORK_CONTEXT" "$PROJECT_NAME"; then
    SESSION_ID=$(get_value "runtime.session.id")
    success "Session created: $SESSION_ID"
else
    die "Failed to create session"
fi

# Handle workflows
if should_create_session_branch "$(get_current_branch)"; then
    execute_with_spinner "Creating session branch" \
        "create_branch 'session' '$(generate_next_session_name)'"
fi

# Sync if configured
if [[ "$(get_workflow_rule 'synchronization.pullOnStart')" != "never" ]]; then
    execute_with_spinner "Syncing with remote" pull_latest
fi

# Prepare memory
# NOTE: .aipm/memory.json is the MCP symlink (always at workspace root)
# But backup goes to workspace-relative memory directory
backup_path="$(get_memory_path "$WORK_CONTEXT" "$PROJECT_NAME" | sed 's/local_memory.json/backup.json/')"
execute_with_spinner "Loading memory context" \
    "backup_memory '.aipm/memory.json' '$backup_path'"

# Launch Claude with style
printf "\n"
success_box "Launching Claude Code!"
info "Session: $SESSION_ID"
info "Context: $(format_context "$WORK_CONTEXT" "$PROJECT_NAME")"
info "Memory: $(get_memory_stats '.aipm/memory.json')"
printf "\n"

# Add default model and launch
[[ ! " ${claude_args[@]} " =~ " --model " ]] && claude_args+=("--model" "opus")
sleep 0.5  # Brief pause for effect
claude code "${claude_args[@]}"