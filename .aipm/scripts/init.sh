#!/opt/homebrew/bin/bash
#
# init.sh - AIPM Framework Initializer (Thin Orchestration Layer)
#
# PURPOSE:
# --------
# Initializes AIPM framework in a workspace (framework or project).
# This is a THIN WRAPPER that orchestrates existing module functions.
#
# ARCHITECTURE PRINCIPLES:
# -----------------------
# 1. NO BUSINESS LOGIC: All logic lives in modules, not here
# 2. ORCHESTRATION ONLY: We coordinate module function calls
# 3. USER EXPERIENCE: Rich visual feedback during initialization
# 4. IDEMPOTENT: Can be run multiple times safely
# 5. RELATIONSHIP AWARE: Can optionally call start.sh after init
#
# WHAT THIS SCRIPT DOES:
# ---------------------
# - Checks if already initialized (offers reinit)
# - Verifies we're in a git repository
# - Loads opinions configuration
# - Creates required directories (.aipm/state, .aipm/memory)
# - Initializes state system
# - Sets up memory symlink for MCP
# - Shows configuration summary
# - Detects existing projects
# - Optionally starts a session
#
# WHAT THIS SCRIPT DOES NOT DO:
# -----------------------------
# - Direct git operations (use version-control.sh)
# - Create opinions.yaml (must exist already)
# - Modify existing configuration
# - Install to other projects (future feature)
# - Handle project symlinking (future feature)
#
# USAGE EXAMPLES:
# --------------
# ./init.sh                    # Initialize framework
# ./init.sh --reinit          # Force reinitialization
# ./init.sh --start           # Initialize and start session
#
# CRITICAL LEARNINGS:
# ------------------
# 1. State Check: .aipm/state/workspace.json indicates initialization
# 2. Reinit Safety: Always confirm before reinitializing
# 3. Directory Creation: Must create .aipm/state and .aipm/memory
# 4. Configuration: opinions.yaml must exist before init
# 5. Auto-start: Can chain to start.sh for convenience
#
# MAINTENANCE NOTES:
# -----------------
# - Keep this script under 150 lines
# - Test reinitialization behavior carefully
# - Verify directory creation permissions
# - Check project detection logic
# - Test auto-start functionality
#
# FUTURE ENHANCEMENTS:
# -------------------
# - Project installation (copy framework to projects)
# - Symlink management for multi-project setup
# - Template selection for different project types
# - Migration from older AIPM versions
#
# WHY IT'S DONE THIS WAY:
# ----------------------
# This is a new script created during the refactoring.
# It provides a clean initialization experience that:
# - Sets up all required structure
# - Gives clear feedback
# - Handles common cases (reinit, auto-start)
# - Prepares for future multi-project features
#
# Dependencies: shell-formatting, version-control, migrate-memories, opinions-state, opinions-loader
# Exit codes: 0 (success), 1 (error), uses die() for fatal errors

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/modules/shell-formatting.sh" || exit 1
source "$SCRIPT_DIR/modules/version-control.sh" || exit 1
source "$SCRIPT_DIR/modules/migrate-memories.sh" || exit 1

# Header with visual impact - First impressions matter
clear_screen
draw_header "AIPM - AI Project Manager" "🚀"
info "🧠 Team memory synchronization through MCP server"
info "🤝 Your AI remembers what your teammates discovered"
info "📝 Decisions & context travel with your project"
printf "\n"

# Parse arguments
REINIT=false         # Force reinitialization
AUTO_START=false     # Start session after init

while [[ $# -gt 0 ]]; do
    case $1 in
        --reinit) REINIT=true; shift ;;
        --start) AUTO_START=true; shift ;;
        -h|--help) 
            show_help "init" "Initialize AIPM framework" \
                "--reinit:Force reinitialization" \
                "--start:Start session after init"
            exit 0 
            ;;
        *) die "Unknown option: $1" ;;
    esac
done

# Check if already initialized
# LEARNING: State file indicates successful initialization
if [[ -f ".aipm/state/workspace.json" ]] && [[ "$REINIT" != "true" ]]; then
    info "AIPM is already initialized in this workspace"
    if confirm "Reinitialize? This will reset all configuration"; then
        REINIT=true
    else
        # If not reinitializing but auto-start requested, just start
        if [[ "$AUTO_START" == "true" ]]; then
            info "Starting session instead..."
            exec "$SCRIPT_DIR/start.sh"  # exec replaces this process
        fi
        exit 0
    fi
fi

# Initialize with visual feedback
section "Initializing AIPM Framework"

# Step 1: Verify we're in a git repo
# LEARNING: AIPM requires git for memory management
info "💡 Git + MCP = Your team's collective intelligence"
info "   Every commit captures decisions AND their context"
execute_with_spinner "Verifying git repository" check_git_repo

# Step 2: Load configuration
# LEARNING: Must source opinions-loader.sh to load configuration
printf "\n"
info "📋 Loading workspace configuration"
info "   This defines how your team works together"
execute_with_spinner "Reading opinions.yaml configuration" \
    'source "$SCRIPT_DIR/modules/opinions-loader.sh"'

# Step 3: Create directory structure
# LEARNING: We need to create directories manually since function doesn't exist
printf "\n"
info "🏗️  Creating workspace structure for team collaboration"
info "   State tracking + memory synchronization infrastructure"
execute_with_spinner "Creating state and memory directories" \
    'mkdir -p .aipm/state .aipm/memory .aipm/state/locks .aipm/state/sessions'

# Step 4: Initialize state system
# LEARNING: Must also source opinions-state.sh first
printf "\n"
info "⚡ Initializing real-time state management"
info "   Tracks who's working on what, preventing conflicts"
execute_with_spinner "Initializing state management" \
    'source "$SCRIPT_DIR/modules/opinions-state.sh" && initialize_state'

# Step 5: Setup memory system
# LEARNING: ensure_memory_symlink creates .aipm/memory.json symlink
printf "\n"
info "🔗 Connecting to MCP memory server"
info "   This is where the magic happens - shared AI memory!"
execute_with_spinner "Creating memory symlink" \
    'source "$SCRIPT_DIR/modules/sync-memory.sh" && ensure_memory_symlink'

# Show configuration summary
# LEARNING: Display key configuration to confirm setup
section "Configuration Summary"
# Source opinions-state.sh if not already (for get_value)
source "$SCRIPT_DIR/modules/opinions-state.sh" 2>/dev/null || true
info "Main branch: $(get_value 'computed.mainBranch' || echo 'Not configured')"
info "Branch prefix: $(get_value 'raw.branching.prefix' || echo 'Not configured')"
info "Protected patterns: $(get_value 'computed.protectedBranches.all' 2>/dev/null | jq -r '.[]' 2>/dev/null | head -3 | tr '\n' ' ' || echo 'None')"
info "Workflow mode: $(get_value 'raw.workflows.automation.level' || echo 'Not configured')"
printf "\n"

# Detect projects
# LEARNING: Look for existing .aipm/memory directories in subdirectories
section "Detecting Projects"
projects=()
if [[ -d . ]]; then
    # Find directories with .aipm/memory (indicates AIPM project)
    while IFS= read -r -d '' proj; do
        proj_name=$(dirname "$proj" | sed 's|^\./||' | cut -d'/' -f1)
        [[ "$proj_name" != "." && "$proj_name" != ".aipm" ]] && projects+=("$proj_name")
    done < <(find . -maxdepth 3 -type d -name ".aipm" -print0 2>/dev/null)
fi

# Remove duplicates and sort
if [[ ${#projects[@]} -gt 0 ]]; then
    projects=($(printf '%s\n' "${projects[@]}" | sort -u))
    success "Found ${#projects[@]} project(s):"
    for proj in "${projects[@]}"; do
        info "  $(format_path "$proj")"
    done
else
    info "No projects found yet"
    info "To add projects, symlink them into this directory"
fi
printf "\n"

# Success message with next steps
success_box "AIPM Framework Initialized Successfully!"
printf "\n"
info "🎉 Your team now has a shared memory that:"
info "   • Survives between AI sessions"
info "   • Syncs across all team members"
info "   • Travels with your project"
printf "\n"
info "Next steps:"
info "  1. Start a framework session: $(format_command "./scripts/start.sh --framework")"
if [[ ${#projects[@]} -gt 0 ]]; then
    info "  2. Start a project session: $(format_command "./scripts/start.sh --project ${projects[0]}")"
else
    info "  2. Add a project: $(format_command "ln -s /path/to/project .")"
fi
info "  3. View configuration: $(format_command "cat .aipm/opinions.yaml")"
printf "\n"

# Auto-start if requested
# LEARNING: Convenience feature to chain init → start
if [[ "$AUTO_START" == "true" ]]; then
    printf "\n"
    info "Auto-starting session..."
    sleep 1  # Brief pause for user to see message
    exec "$SCRIPT_DIR/start.sh"
fi

# END OF SCRIPT - Clean initialization experience!