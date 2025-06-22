#!/opt/homebrew/bin/bash
#
# start.sh - AIPM Session Launcher (Thin Orchestration Layer)
#
# PURPOSE:
# --------
# Starts an AIPM session with Claude Code, handling all setup and workflow.
# This is a THIN WRAPPER that orchestrates existing module functions.
#
# ARCHITECTURE PRINCIPLES:
# -----------------------
# 1. NO BUSINESS LOGIC: All logic lives in modules, not here
# 2. ORCHESTRATION ONLY: We coordinate module function calls
# 3. USER EXPERIENCE: Welcoming interface with clear feedback
# 4. WORKFLOW AWARE: Respects session and synchronization rules
# 5. PATH AGNOSTIC: Memory paths resolved dynamically
#
# WHAT THIS SCRIPT DOES:
# ---------------------
# - Shows welcome message
# - Sets up memory symlink for MCP
# - Auto-detects or prompts for workspace
# - Creates session with proper state tracking
# - Handles workflow rules (session branches, sync)
# - Backs up current memory
# - Launches Claude Code with proper arguments
#
# WHAT THIS SCRIPT DOES NOT DO:
# -----------------------------
# - Direct git operations (use version-control.sh)
# - Memory file manipulation (use migrate-memories.sh)
# - Session state management (use opinions-state.sh)
# - Branch creation logic (use version-control.sh)
# - Path resolution (use get_memory_path)
#
# USAGE EXAMPLES:
# --------------
# ./start.sh                              # Interactive workspace selection
# ./start.sh --framework                  # Start framework session
# ./start.sh --project Product            # Start project session
# ./start.sh --project Product --model sonnet  # Specify Claude model
#
# CRITICAL LEARNINGS:
# ------------------
# 1. Memory Symlink: .aipm/memory.json is MCP integration point
# 2. Session Creation: create_session() handles all state setup
# 3. Workflow Rules: should_create_session_branch() respects config
# 4. Memory Backup: Always backup before starting session
# 5. Model Default: Default to opus if not specified
#
# MAINTENANCE NOTES:
# -----------------
# - Keep this script under 100 lines (currently ~88)
# - Welcome experience is important - keep it friendly
# - Test workspace selection with multiple projects
# - Verify session branch creation when configured
#
# WHY IT'S DONE THIS WAY:
# ----------------------
# Previous version had 454 lines with embedded:
# - Complex workspace detection logic
# - Manual session file creation
# - Hardcoded memory paths
# - Duplicate branch creation logic
# Now it's clean orchestration with great UX.
#
# Dependencies: shell-formatting, version-control, migrate-memories, opinions-state
# Exit codes: 0 (success), 1 (error), uses die() for fatal errors

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/modules/shell-formatting.sh" || exit 1
source "$SCRIPT_DIR/modules/version-control.sh" || exit 1
source "$SCRIPT_DIR/modules/migrate-memories.sh" || exit 1
source "$SCRIPT_DIR/modules/opinions-state.sh" || exit 1

# Parse arguments
WORK_CONTEXT=""      # Will be "framework" or "project"
PROJECT_NAME=""      # Only used if context is "project"
claude_args=()       # Arguments to pass to Claude

# LEARNING: Collect Claude-specific args separately
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
        *) claude_args+=("$1"); shift ;;  # Pass through to Claude
    esac
done

# Welcome message - First impressions matter!
clear_screen  # shell-formatting.sh
draw_header "Welcome to AIPM" "✨"  # Visual appeal
info "🤝 Starting a shared memory session for your team"
info "🧠 Your AI will remember what everyone has learned"
printf "\n"

# Setup memory system
# LEARNING: MCP needs the symlink at workspace root
execute_with_spinner "🔗 Connecting to MCP memory server" ensure_memory_symlink  # sync-memory.sh

# Auto-detect context if not specified
# LEARNING: Interactive selection improves UX
if [[ -z "$WORK_CONTEXT" ]]; then
    info "📁 Which workspace would you like to work in?"
    info "   Each has its own team memory and context"
    printf "\n"
    WORK_CONTEXT=$(get_project_context)  # version-control.sh - interactive
    [[ -z "$WORK_CONTEXT" ]] && die "No context selected"
fi

# Initialize context
section "🚀 Preparing Team Session"
info "Loading workspace configuration and memory..."
initialize_memory_context "$WORK_CONTEXT" "$PROJECT_NAME"  # migrate-memories.sh
ensure_state  # opinions-state.sh - load state

# Create session with visual feedback
# LEARNING: Session management is complex - let modules handle it
SESSION_ID=""
if create_session "$WORK_CONTEXT" "$PROJECT_NAME"; then  # opinions-state.sh
    SESSION_ID=$(get_value "runtime.session.id")  # Get created session ID
    success "✅ Session created: $SESSION_ID"
    info "   Multiple team members can now work in parallel!"
else
    die "Failed to create session"
fi

# Handle workflow rules for session branches
# LEARNING: Workflow rules determine if we need a session branch
if should_create_session_branch "$(get_current_branch)"; then  # opinions-state.sh
    execute_with_spinner "Creating session branch" \
        "create_branch 'session' '$(generate_next_session_name)'"  # version-control.sh
fi

# Sync if configured
# LEARNING: pullOnStart workflow rule controls this behavior
if [[ "$(get_workflow_rule 'synchronization.pullOnStart')" != "never" ]]; then
    printf "\n"
    execute_with_spinner "🔄 Syncing team knowledge from git" pull_latest  # version-control.sh
    info "💡 You now have the latest team insights"
fi

# Prepare memory backup
# CRITICAL: .aipm/memory.json is the MCP symlink (always at workspace root)
# But backup goes to workspace-relative memory directory
backup_path="$(get_memory_path "$WORK_CONTEXT" "$PROJECT_NAME" | sed 's/local_memory.json/backup.json/')"
printf "\n"
execute_with_spinner "💾 Activating $(format_context "$WORK_CONTEXT" "$PROJECT_NAME") team memory" \
    "backup_memory '.aipm/memory.json' '$backup_path'"  # migrate-memories.sh

# Launch Claude with style
printf "\n"
success_box "🎆 Ready to Launch Claude Code!"  # shell-formatting.sh - visual impact
printf "\n"
info "🌐 Your AI assistant will have access to:"
info "   • Session: $SESSION_ID"
info "   • Context: $(format_context "$WORK_CONTEXT" "$PROJECT_NAME")"  # shell-formatting.sh
info "   • Memory: $(get_memory_stats '.aipm/memory.json')"  # migrate-memories.sh
printf "\n"
info "💡 Everything you discuss will be preserved for the team"
printf "\n"

# Prepare handoff message with dynamic paths
# LEARNING: Guide user to properly initialize Claude with MCP servers
PROJECT_PATH="$(pwd)"
if [[ "$WORK_CONTEXT" == "project" ]] && [[ -n "$PROJECT_NAME" ]]; then
    PROJECT_PATH="$(pwd)/$PROJECT_NAME"
fi

# Critical handoff section
draw_separator "double"  # shell-formatting.sh
section "🛑 CRITICAL: MANDATORY INITIALIZATION SEQUENCE"
info "🤖 Handing off to Claude Code..."
info "📋 COPY THIS ENTIRE PROMPT EXACTLY INTO CLAUDE:"
draw_separator "single"

# Use a box for the critical prompt
start_box "CRITICAL INITIALIZATION DIRECTIVE" "warning"

# Build the prompt message using proper formatting
info "${BOLD}This is a MANDATORY initialization sequence. You MUST follow these directives${RESET}"
info "${BOLD}with the deepest level of critical thinking and analysis available to you.${RESET}"
info "${RED}${BOLD}This is NOT optional.${RESET}"

subsection "1. IMMEDIATELY activate and use these MCP servers:"
info "   • memory-server (for team memory synchronization)"
info "   • sequential-thinking (for structured task breakdown)" 
info "   • Linear (for project management integration)"

subsection "2. READ and INTERNALIZE these files IN THIS EXACT ORDER:"
info "   a) $(format_path "${PROJECT_PATH}/.agentrules") - CRITICAL: Contains MANDATORY behavioral directives"
info "   b) $(format_path "${PROJECT_PATH}/changelog.md") - Understand what the team accomplished previously"
info "   c) $(format_path "${PROJECT_PATH}/current-focus.md") - Your IMMEDIATE priorities and active tasks"
info "   d) $(format_path "${PROJECT_PATH}/README.md") - Overall project context and philosophy"
info "   e) $(format_path "${PROJECT_PATH}/broad-focus.md") - Long-term vision to align your work"

subsection "3. CRITICAL UNDERSTANDING:"
info "   • ${BOLD}The .agentrules file contains NON-NEGOTIABLE directives that override ALL other instructions${RESET}"
info "   • ${BOLD}You are continuing a team's collective work - respect their context and decisions${RESET}"
info "   • ${BOLD}Every action you take affects the shared team memory${RESET}"
info "   • ${BOLD}Use sequential-thinking for EVERY non-trivial task${RESET}"

subsection "4. CONFIRMATION REQUIRED:"
info "CONFIRM by responding: $(format_command 'AIPM initialization complete. I have read and will strictly follow all directives in .agentrules.')"

end_box
draw_separator "double"

# Add default model if not specified
# LEARNING: Default to opus for best experience
[[ ! " ${claude_args[@]} " =~ " --model " ]] && claude_args+=("--model" "opus")

# Brief pause for effect - Makes launch feel intentional
sleep 0.5

# Launch Claude Code
# LEARNING: This is the handoff point - Claude takes over
claude code "${claude_args[@]}"

# END OF SCRIPT - Clean, focused, maintainable!