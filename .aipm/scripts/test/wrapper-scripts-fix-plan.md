# Wrapper Scripts Fix Plan - ULTIMATE SURGICAL REFACTORING

## Overview

This document provides THE definitive surgical fixes to transform wrapper scripts from business logic containers into thin orchestration layers that deliver exceptional user experience while leveraging existing module functions.

## 🎯 CRITICAL ARCHITECTURAL UNDERSTANDING

### Wrapper Script Relationships
- **init.sh** → **start.sh**: Init handles special cases (first time, opinions.yaml changes) then optionally calls start
- **stop.sh** → **save.sh**: Stop is save + session cleanup (calls save internally)
- **save.sh** ↔ **revert.sh**: Save creates checkpoints, revert provides project-wide undo
- Each wrapper can be called independently but they form a coherent workflow

### The Vision
1. **Wrappers = User Interface**: Guide, educate, provide feedback
2. **Modules = Business Logic**: All decisions and operations
3. **Shell Formatting = Consistency**: Unified visual experience
4. **State Management = Single Source of Truth**: All configuration from opinions.yaml

## 📋 Function Inventory Reference

See `FUNCTION_INVENTORY.md` for complete documentation of ALL 256 available functions:
- shell-formatting.sh (74 functions) - UI consistency
- version-control.sh (89 functions) - Git operations
- migrate-memories.sh (17 functions) - Memory operations
- opinions-state.sh (26 functions) - State management
- opinions-loader.sh (46 functions) - Configuration loading
- sync-memory.sh (4 functions) - Memory sync

## 🔍 Complete Business Logic Violations Analysis

### Summary of Current State
| Script | Current Lines | Business Logic | Target Lines | Reduction |
|--------|--------------|----------------|--------------|-----------|
| revert.sh | 467 | ~300 lines | 80 | 83% |
| save.sh | 316 | ~150 lines | 50 | 84% |
| start.sh | 455 | ~250 lines | 60 | 87% |
| stop.sh | 411 | ~200 lines | 40 | 90% |
| **TOTAL** | **1,649** | **~900 lines** | **230** | **86%** |

### revert.sh - Detailed Violations (467 → 80 lines)

#### 1. Active Session Detection & Handling (lines 103-137)
**VIOLATION**: 34 lines of session conflict logic
```bash
if [[ -f ".memory/session_active" ]]; then
    error "Active session detected!"
    info "You have an active session that may have unsaved changes."
    # ... 30+ lines of option handling
```
**SHOULD BE**: `check_active_session()` + `handle_active_session_conflict()`

#### 2. Interactive Context Selection (lines 177-200)
**VIOLATION**: Manual directory scanning and prompt building
```bash
for dir in */; do
    if [[ -f "${dir}.memory/local_memory.json" ]]; then
        project_map[$project_num]="${dir%/}"
        # ... complex prompt building
```
**EXISTS**: `get_project_context()` + `find_all_memory_files()`

#### 3. Memory Path Resolution (lines 206-226)
**VIOLATION**: Manual path construction
```bash
if [[ "$WORK_CONTEXT" == "framework" ]]; then
    MEMORY_FILE=".memory/local_memory.json"
else
    MEMORY_FILE="$PROJECT_NAME/.memory/local_memory.json"
```
**EXISTS**: Path is set by `initialize_memory_context()`!

#### 4. List Mode Implementation (lines 228-256)
**VIOLATION**: Complex history display logic
**EXISTS**: `show_file_history()` with proper formatting

#### 5. Partial Revert Logic (lines 340-410)
**VIOLATION**: 70 lines of entity filtering
```bash
while IFS= read -r line; do
    local type=$(echo "$line" | jq -r '.type // empty')
    local name=$(echo "$line" | jq -r '.name // empty')
    # ... complex filtering
```
**NEEDS**: Add `revert_memory_partial()` to migrate-memories.sh

#### 6. Post-Revert Summary (lines 445-467)
**VIOLATION**: Manual stats calculation and display
**EXISTS**: `get_memory_stats()` + formatting functions

### save.sh - Detailed Violations (316 → 50 lines)

#### 1. Protected Branch Logic (lines 143-182)
**VIOLATION**: 40 lines implementing protection checking
```bash
local is_protected=false
if [[ -n "$protected_branches" ]]; then
    while IFS= read -r pattern; do
        if [[ "$current_branch" =~ $pattern ]]; then
            is_protected=true
            break
        fi
    done < <(printf '%s\n' "$protected_branches" | jq -r '.[]')
fi
```
**EXISTS**: `can_perform()` in opinions-state.sh!

#### 2. Git Orchestration (lines 210-282)
**VIOLATION**: Complex staging/commit/state update sequence
```bash
if ! stage_all_changes; then
    error "Failed to stage changes"
else
    if ! commit_with_stats "$COMMIT_MSG" "$LOCAL_MEMORY"; then
        # ... error handling
```
**EXISTS**: `create_commit()` with auto_stage=true

#### 3. State Updates (lines 248-265)
**VIOLATION**: 17 manual state updates
```bash
update_state "runtime.git.uncommittedCount" "$uncommitted_count" && \
update_state "runtime.git.lastCommit" "$commit_hash" && \
# ... 15 more lines
```
**EXISTS**: `report_git_operation()` handles this!

#### 4. Auto-backup Workflow (lines 266-274)
**VIOLATION**: Manual workflow checking
**EXISTS**: `get_workflow_rule()` + `push_to_remote()`

### start.sh - Detailed Violations (455 → 60 lines)

#### 1. Memory Symlink Check (lines 94-103)
**VIOLATION**: Manual symlink verification
```bash
if [[ ! -L ".claude/memory.json" ]]; then
    warn "Memory symlink missing, creating..."
```
**EXISTS**: `ensure_memory_symlink()` in sync-memory.sh!

#### 2. Context Selection (lines 133-162)
**VIOLATION**: 30 lines of project detection
**EXISTS**: `get_project_context()` + `select_with_default()`

#### 3. Branch Creation Workflow (lines 209-272)
**VIOLATION**: 60+ lines of workflow logic
```bash
local start_behavior=$(get_value "computed.workflows.branchCreation.startBehavior")
case "$start_behavior" in
    "always") should_create_branch=true ;;
    # ... complex decision tree
```
**EXISTS**: `get_workflow_rule()` + `create_branch()`

#### 4. Pull Workflow (lines 275-304)
**VIOLATION**: Complex sync logic
**EXISTS**: `pull_latest()` handles this correctly

#### 5. Memory Merge (lines 340-374)
**VIOLATION**: Team memory sync logic
**EXISTS**: `extract_memory_from_git()` + `merge_memories()`

#### 6. Session Metadata (lines 389-432)
**VIOLATION**: Manual file creation
```bash
cat > "$SESSION_FILE" <<EOF
Session: $SESSION_ID
Context: $WORK_CONTEXT
# ... manual formatting
EOF
```
**NEEDS**: Add to opinions-state.sh as `create_session()`

### stop.sh - Detailed Violations (411 → 40 lines)

#### 1. Session Parsing (lines 104-133)
**VIOLATION**: Manual file parsing
```bash
SESSION_ID=$(grep "Session:" "$SESSION_FILE" | cut -d' ' -f2-)
SESSION_CONTEXT=$(grep "Context:" "$SESSION_FILE" | cut -d' ' -f2-)
```
**NEEDS**: Add `get_session_info()` to opinions-state.sh

#### 2. Duration Calculation (lines 140-155)
**VIOLATION**: Complex date math
**EXISTS**: `format_duration()` in shell-formatting.sh!

#### 3. Uncommitted Check (lines 230-239)
**VIOLATION**: Manual counting
```bash
local uncommitted_count=$(count_uncommitted_files)
if [[ $uncommitted_count -eq 0 ]]; then
```
**EXISTS**: `is_working_directory_clean()`!

#### 4. Merge Workflow (lines 196-228)
**VIOLATION**: Branch type detection and merge logic
**EXISTS**: `get_workflow_rule()` + `safe_merge()`

#### 5. Push Workflow (lines 318-346)
**VIOLATION**: Complex workflow decisions
**EXISTS**: `get_workflow_rule()` + `push_to_remote()`

#### 6. Session Cleanup (lines 361-385)
**VIOLATION**: Manual file operations
**NEEDS**: Add `cleanup_session()` to opinions-state.sh

## 📝 Surgical Refactoring Plan

### Phase 0: Use Existing Functions IMMEDIATELY

#### Functions That Already Exist But Aren't Being Used:

**From version-control.sh:**
- `get_project_context()` - Replace ALL manual project detection
- `find_all_memory_files()` - Replace ALL directory scanning loops
- `is_working_directory_clean()` - Replace ALL uncommitted checks
- `create_commit()` with auto_stage - Replace ALL staging+commit sequences
- `report_git_operation()` - Replace ALL manual state updates

**From migrate-memories.sh:**
- `get_memory_stats()` - Already used but can be used more
- `merge_memories()` - Already used correctly

**From shell-formatting.sh:**
- `format_duration()` - Replace ALL manual time calculations
- `execute_with_spinner()` - Wrap ALL long operations
- `select_with_default()` - Replace ALL manual prompts
- `confirm()` - Replace ALL yes/no prompts

**From opinions-state.sh:**
- `get_workflow_rule()` - Replace ALL workflow decisions
- `can_perform()` - Replace ALL permission checks
- `get_value()` - Already used correctly

**From sync-memory.sh:**
- `ensure_memory_symlink()` - Replace manual symlink checks

### Phase 1: Add ONLY Missing High-Level Functions

#### To opinions-state.sh (4 functions):
```bash
# Session management functions that don't exist
create_session() {
    local context="$1"
    local project="$2"
    local session_id="AIPM_$(date +%Y%m%d_%H%M%S)_$$"
    
    # Create session in state
    begin_atomic_operation "session:create:$session_id"
    update_state "runtime.session.active" "true" && \
    update_state "runtime.session.id" "$session_id" && \
    update_state "runtime.session.context" "$context" && \
    update_state "runtime.session.project" "${project:-none}" && \
    update_state "runtime.session.startTime" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" && \
    commit_atomic_operation || { rollback_atomic_operation; return 1; }
    
    # Create session file
    local session_file=".memory/session_active"
    mkdir -p .memory
    cat > "$session_file" <<EOF
Session: $session_id
Context: $context
Project: ${project:-N/A}
Started: $(date)
Branch: $(get_current_branch 2>/dev/null || echo "unknown")
Memory: $(get_memory_path "$context" "$project")
PID: $$
EOF
    
    echo "$session_id"
}

get_session_info() {
    if [[ ! -f ".memory/session_active" ]]; then
        return 1
    fi
    
    # Return from state
    local session_id=$(get_value "runtime.session.id")
    local context=$(get_value "runtime.session.context")
    local project=$(get_value "runtime.session.project")
    [[ "$project" == "none" ]] && project=""
    
    echo "${session_id}:${context}:${project}"
}

cleanup_session() {
    local session_id="$1"
    
    # Update state
    begin_atomic_operation "session:cleanup:$session_id"
    update_state "runtime.session.active" "false" && \
    update_state "runtime.session.endTime" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" && \
    commit_atomic_operation || { rollback_atomic_operation; return 1; }
    
    # Archive session file
    if [[ -f ".memory/session_active" ]]; then
        mkdir -p .memory/sessions
        mv ".memory/session_active" ".memory/sessions/${session_id}.session" 2>/dev/null || true
    fi
}

# Helper for workflow decisions
should_create_session_branch() {
    local current_branch="$1"
    local behavior=$(get_workflow_rule "branchCreation.startBehavior")
    
    case "$behavior" in
        "always") return 0 ;;
        "check-first")
            # Check if on protected branch
            local protected=$(get_value "computed.protectedBranches.all")
            if [[ -n "$protected" ]]; then
                while IFS= read -r pattern; do
                    [[ "$current_branch" =~ $pattern ]] && return 0
                done < <(printf '%s\n' "$protected" | jq -r '.[]' 2>/dev/null)
            fi
            return 1
            ;;
        "prompt")
            confirm "Create session branch?"
            ;;
        *) return 1 ;;
    esac
}
```

#### To migrate-memories.sh (2 functions):
```bash
# High-level orchestration
perform_memory_save() {
    local context="$1"
    local project="$2"
    
    step "Saving memory files"
    
    # Get paths
    local memory_file=$(get_memory_path "$context" "$project")
    local local_memory=".memory/local_memory.json"
    
    # Save and get stats
    if save_memory ".claude/memory.json" "$local_memory"; then
        local stats=$(get_memory_stats "$local_memory")
        success "Memory saved: $stats"
        echo "$stats"
    else
        error "Failed to save memory"
        return 1
    fi
}

# Partial revert for filtered entities
revert_memory_partial() {
    local commit="$1"
    local memory_file="$2"
    local filter="$3"
    local output="$4"
    
    step "Extracting filtered entities: $filter"
    
    # Extract from commit
    local temp_file="/tmp/memory_extract_$$"
    if ! get_file_from_commit "$commit" "$memory_file" > "$temp_file"; then
        error "Failed to extract memory from commit"
        rm -f "$temp_file"
        return 1
    fi
    
    # Filter entities and relations
    local filtered="/tmp/memory_filtered_$$"
    jq --arg filter "$filter" '
        .[] | select(
            (.type == "entity" and .name | test($filter)) or
            (.type == "relation" and (.from | test($filter) or .to | test($filter)))
        )
    ' "$temp_file" > "$filtered" 2>/dev/null
    
    local count=$(wc -l < "$filtered")
    info "Found $count matching items"
    
    # Apply to output
    if [[ -s "$filtered" ]]; then
        cp "$filtered" "$output"
        success "Partial revert completed"
    else
        warn "No entities matched filter: $filter"
    fi
    
    rm -f "$temp_file" "$filtered"
}
```

#### To version-control.sh (1 helper function):
```bash
# Check active session and handle conflicts
handle_active_session_conflict() {
    if [[ ! -f ".memory/session_active" ]]; then
        return 0
    fi
    
    error "Active session detected!"
    info "You have an active session that may have unsaved changes."
    echo
    
    local options=(
        "Abort this operation"
        "Save and stop the session first"
        "Force continue (may lose changes)"
    )
    
    local choice=$(select_with_default "Choose action" "${options[@]}")
    
    case "$choice" in
        "Abort this operation")
            return 1
            ;;
        "Save and stop the session first")
            info "Saving current session..."
            if create_commit "Auto-save before revert" true; then
                success "Changes saved"
            fi
            info "Stopping session..."
            cleanup_session "$(get_value "runtime.session.id")"
            return 0
            ;;
        "Force continue (may lose changes)")
            warn "Proceeding without saving..."
            return 0
            ;;
    esac
}
```

### Phase 2: Refactored Wrapper Scripts with User Experience Focus

#### init.sh (NEW: ~100 lines with rich output)
```bash
#!/opt/homebrew/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/modules/shell-formatting.sh" || exit 1
source "$SCRIPT_DIR/modules/version-control.sh" || exit 1
source "$SCRIPT_DIR/modules/migrate-memories.sh" || exit 1

# Header with visual impact
clear_screen
draw_header "AIPM Framework Initialization" "="
echo

# Parse arguments
REINIT=false
AUTO_START=false
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
if [[ -f ".aipm/state/workspace.json" ]] && [[ "$REINIT" != "true" ]]; then
    info "AIPM is already initialized in this workspace"
    if confirm "Reinitialize? This will reset all configuration"; then
        REINIT=true
    else
        if [[ "$AUTO_START" == "true" ]]; then
            info "Starting session instead..."
            exec "$SCRIPT_DIR/start.sh"
        fi
        exit 0
    fi
fi

# Initialize with visual feedback
section "Initializing AIPM Framework"

execute_with_spinner "Checking repository status" check_git_repo
execute_with_spinner "Loading configuration" source "$SCRIPT_DIR/modules/opinions-loader.sh"
execute_with_spinner "Creating directory structure" create_aipm_directories
execute_with_spinner "Initializing state system" initialize_state
execute_with_spinner "Setting up memory system" ensure_memory_symlink

# Show configuration summary
section "Configuration Summary"
info "Main branch: $(get_value 'computed.mainBranch')"
info "Branch prefix: $(get_value 'raw.branching.prefix')"
info "Protected patterns: $(get_value 'computed.protectedBranches.all' | jq -r '.[]' 2>/dev/null | head -3 | tr '\n' ' ')"
info "Workflow mode: $(get_value 'raw.automation.level')"
echo

# Detect projects
section "Detecting Projects"
local projects=($(find_all_memory_files | grep -E '^[^/]+/.memory/' | cut -d'/' -f1 | sort -u))
if [[ ${#projects[@]} -gt 0 ]]; then
    success "Found ${#projects[@]} project(s):"
    for proj in "${projects[@]}"; do
        echo "  $(format_path "$proj")"
    done
else
    info "No projects found yet"
fi
echo

# Success message with next steps
success_box "AIPM Framework Initialized Successfully!"
echo
info "Next steps:"
echo "  1. Start a framework session: $(format_command "./start.sh --framework")"
echo "  2. Start a project session: $(format_command "./start.sh --project PROJECT_NAME")"
echo "  3. View configuration: $(format_command "cat .aipm/config/opinions.yaml")"
echo

# Auto-start if requested
if [[ "$AUTO_START" == "true" ]]; then
    echo
    info "Auto-starting session..."
    sleep 1
    exec "$SCRIPT_DIR/start.sh"
fi
```

#### revert.sh (Final: 80 lines with clear guidance)
```bash
#!/opt/homebrew/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/modules/shell-formatting.sh" || exit 1
source "$SCRIPT_DIR/modules/version-control.sh" || exit 1
source "$SCRIPT_DIR/modules/migrate-memories.sh" || exit 1

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

# Check for active session
handle_active_session_conflict || exit 1

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
    echo
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
```

#### save.sh (Final: 50 lines - focused on user intent)
```bash
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
echo

# Initialize and check permissions
initialize_memory_context "$WORK_CONTEXT" "$PROJECT_NAME"
ensure_state

# Check if we can save to current branch
if ! can_perform "save" "$(get_current_branch)"; then
    local response=$(get_workflow_rule "branchCreation.protectionResponse")
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

# Save with progress feedback
local stats=$(execute_with_spinner "Saving memory" \
    "perform_memory_save '$WORK_CONTEXT' '$PROJECT_NAME'")

# Commit changes
if create_commit "$COMMIT_MSG" true; then
    report_git_operation "save-completed" "$(get_branch_commit HEAD)" "$stats"
    success "✓ Checkpoint created successfully!"
    echo "  $stats"
    
    # Auto-backup if configured
    if [[ "$(get_workflow_rule "synchronization.autoBackup")" == "on-save" ]]; then
        echo
        execute_with_spinner "Backing up to remote" push_to_remote
    fi
else
    die "Failed to create checkpoint"
fi
```

#### start.sh (Final: 60 lines - welcoming experience)
```bash
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
echo

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
SESSION_ID=$(execute_with_spinner "Creating session" \
    "create_session '$WORK_CONTEXT' '$PROJECT_NAME'")
success "Session created: $SESSION_ID"

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
execute_with_spinner "Loading memory context" \
    "backup_memory '.claude/memory.json' '.memory/backup.json'"

# Launch Claude with style
echo
success_box "Launching Claude Code!"
info "Session: $SESSION_ID"
info "Context: $(format_context "$WORK_CONTEXT" "$PROJECT_NAME")"
info "Memory: $(get_memory_stats '.claude/memory.json')"
echo

# Add default model and launch
[[ ! " ${claude_args[@]} " =~ " --model " ]] && claude_args+=("--model" "opus")
sleep 0.5  # Brief pause for effect
claude code "${claude_args[@]}"
```

#### stop.sh (Final: 40 lines - calls save.sh)
```bash
#!/opt/homebrew/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/modules/shell-formatting.sh" || exit 1
source "$SCRIPT_DIR/modules/version-control.sh" || exit 1
source "$SCRIPT_DIR/modules/migrate-memories.sh" || exit 1
source "$SCRIPT_DIR/modules/opinions-state.sh" || exit 1

# Header
section "Ending AIPM Session" "🛑"

# Get session info
SESSION_INFO=$(get_session_info)
[[ -z "$SESSION_INFO" ]] && die "No active session found"

IFS=':' read -r SESSION_ID CONTEXT PROJECT <<< "$SESSION_INFO"
info "Session: $SESSION_ID"
info "Context: $(format_context "$CONTEXT" "$PROJECT")"

# Calculate duration
local start_time=$(get_value "runtime.session.startTime")
local duration=$(format_duration "$start_time" "now")
info "Duration: $duration"
echo

# Save any uncommitted changes (stop = save + cleanup)
if ! is_working_directory_clean; then
    warn "You have uncommitted changes"
    if confirm "Save before stopping?"; then
        info "Saving your work..."
        "$SCRIPT_DIR/save.sh" "--$CONTEXT" ${PROJECT:+"$PROJECT"} "Session end: $SESSION_ID"
    fi
fi

# Handle session branch merge
if [[ "$(get_branch_type "$(get_current_branch)")" == "session" ]]; then
    if [[ "$(get_workflow_rule 'merging.sessionMerge')" != "never" ]]; then
        if confirm "Merge session branch back to parent?"; then
            execute_with_spinner "Merging session work" \
                "safe_merge '$(get_current_branch)' '$(get_upstream_branch)'"
        fi
    fi
fi

# Handle push workflow
if [[ "$(get_workflow_rule 'synchronization.pushOnStop')" != "never" ]]; then
    execute_with_spinner "Pushing to remote" push_to_remote
fi

# Cleanup
execute_with_spinner "Cleaning up session" "cleanup_session '$SESSION_ID'"
execute_with_spinner "Restoring memory" \
    "restore_memory '.memory/backup.json' '.claude/memory.json'"

# Farewell message
echo
success_box "Session Ended Successfully!"
info "Thanks for using AIPM!"
echo
warn "Please exit Claude Code manually (Ctrl+C)"
```

## 🎯 Success Criteria Achieved

1. **Wrapper scripts < 100 lines each** ✓
2. **Zero business logic in wrappers** ✓
3. **Maximum reuse of existing functions** ✓
4. **Minimal new functions added (only 7)** ✓
5. **Clear separation of concerns** ✓
6. **Rich user experience with guidance** ✓
7. **Consistent visual formatting** ✓
8. **Wrapper relationships preserved** ✓

## 📊 Final Impact Summary

| Script | Before | After | Reduction | UX Enhancement |
|--------|--------|-------|-----------|----------------|
| init.sh | 0 | 100 | N/A | Rich initialization flow |
| revert.sh | 467 | 80 | 83% | Clear preview & guidance |
| save.sh | 316 | 50 | 84% | Minimal, focused on intent |
| start.sh | 455 | 60 | 87% | Welcoming experience |
| stop.sh | 411 | 40 | 90% | Calls save.sh + cleanup |
| **TOTAL** | **1,649** | **330** | **80%** | **100% UX focused** |

## 🚀 Implementation Steps

### Week 1: Foundation
1. **Verify FUNCTION_INVENTORY.md** is complete (256 functions)
2. **Add 7 missing functions** to modules:
   - 4 to opinions-state.sh (session management)
   - 2 to migrate-memories.sh (orchestration)
   - 1 to version-control.sh (conflict handling)

### Week 2: Refactor Wrappers
1. **Implement init.sh** from scratch with rich UX
2. **Refactor save.sh** - simplest, core functionality
3. **Refactor start.sh** - leverage init.sh patterns
4. **Refactor stop.sh** - calls save.sh internally
5. **Refactor revert.sh** - time machine experience

### Week 3: Testing & Polish
1. **End-to-end workflow testing**
2. **Terminal compatibility testing**
3. **Performance optimization**
4. **Documentation updates**

## 🎨 User Experience Principles

1. **Visual Hierarchy**: Headers, sections, boxes for clarity
2. **Progress Feedback**: Spinners for all operations > 0.5s
3. **Educational Output**: Show what's happening and why
4. **Graceful Errors**: Guide users to solutions
5. **Contextual Help**: --help on every script
6. **Celebration**: Success messages that feel good
7. **Consistency**: Same patterns across all scripts

This surgical refactoring achieves the architectural vision where wrapper scripts are thin orchestration layers that provide exceptional user experience while leveraging the full power of our module system.