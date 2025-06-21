# AIPM Wrapper Scripts Architectural Refactoring Plan

## Executive Summary

This document presents a comprehensive architectural refactoring plan for AIPM wrapper scripts based on an exhaustive audit of the current implementation. The refactoring follows strict SOLID principles with emphasis on:

1. **Atomicity**: Each function does ONE thing well
2. **Modularity**: Clear module boundaries with no overlap
3. **Configurability**: All behaviors parameterizable
4. **Maintainability**: Single source of truth for each domain
5. **Performance**: Optimized for large-scale operations

**CRITICAL**: This refactoring preserves ALL existing learnings, hardened patterns, and carefully implemented solutions while eliminating redundancy and improving architecture.

## Part 1: Exhaustive Current State Inventory

### 1.1 Module: shell-formatting.sh (1589 lines)

**Purpose**: Centralized formatting, output, and platform utilities

**Existing Functions** (MUST PRESERVE):
```bash
# Platform Detection
detect_platform()             # Sets PLATFORM variable (macos/linux/wsl/cygwin/mingw)
detect_timeout_command()      # Sets TIMEOUT_CMD and TIMEOUT_STYLE
detect_execution_context()    # Sets EXECUTION_CONTEXT (terminal/ci/pipe/claude/cron)
detect_color_support()        # Sets COLOR_SUPPORT
detect_unicode_support()      # Sets UNICODE_SUPPORT

# Output Functions (Core - Used Everywhere)
info()                       # Blue info messages
warn()                       # Yellow warning messages  
error()                      # Red error messages
success()                    # Green success messages
debug()                      # Debug output (if DEBUG set)
step()                       # Progress step indicator
section()                    # Visual section header
section_end()                # Visual section footer

# Formatting Functions
format_size()                # Human-readable file sizes
format_duration()            # Human-readable durations
format_prompt()              # Formatted input prompts
draw_line()                  # Visual separator lines
draw_box()                   # ASCII/Unicode boxes

# Progress Indicators
show_spinner()               # Animated spinner
show_progress()              # Progress bar
update_progress()            # Update progress bar

# Utility Functions
safe_execute()               # Execute with timeout/retry
confirm()                    # Yes/no confirmation prompt
die()                        # Exit with error message
cleanup_on_exit()            # Trap handler for cleanup
get_file_mtime()             # Cross-platform file modification time
make_temp_file()             # Cross-platform temp file creation

# Internal Functions (Private)
_init_color_codes()          # Initialize ANSI codes
_strip_ansi()                # Remove ANSI codes
_get_terminal_width()        # Terminal width detection
```

**Critical Learnings Preserved**:
- Platform detection caches uname result for performance
- WSL detection checks /proc/version for "microsoft"
- Timeout command detection handles gtimeout (macOS) and timeout (Linux)
- All output respects COLOR_SUPPORT and EXECUTION_CONTEXT
- Performance optimizations: cached detection, direct ANSI codes

### 1.2 Module: version-control.sh (936 lines)

**Purpose**: Centralized git operations with comprehensive error handling

**Existing Functions** (MUST PRESERVE):
```bash
# Context Management
initialize_memory_context()   # Set up paths and context for operations
get_context_display()         # Format context for display

# Repository Operations
check_git_repo()              # Verify git repository exists
is_repo_clean()               # Check for uncommitted changes
show_git_status()             # Display formatted git status

# File Operations
stage_file()                  # Stage single file
stage_all_changes()           # Stage all changes (Golden Rule)
unstage_changes()             # Unstage files
stash_if_needed()             # Smart stashing with DID_STASH tracking

# Commit Operations
commit_changes()              # Basic commit
commit_with_stats()           # Commit with memory statistics

# Remote Operations
fetch_remote()                # Fetch from remote
pull_latest()                 # Pull with stash handling
push_changes()                # Push to remote
ensure_remote_tracking()      # Set up remote tracking

# Branch Operations
get_current_branch()          # Get current branch name
branch_exists()               # Check if branch exists
create_branch()               # Create new branch
switch_branch()               # Switch branches safely

# History Operations
show_log()                    # Formatted git log
show_diff()                   # Show differences
get_commits_ahead_behind()    # Compare with remote
get_file_from_commit()        # Extract file from commit

# Validation
validate_commit()             # Verify commit exists
file_exists_in_commit()       # Check file in commit
is_file_tracked()             # Check if file is tracked

# Utilities
abs_path()                    # Get absolute path
checkout_file()               # Checkout file from commit
```

**Critical Learnings Preserved**:
- All operations handle detached HEAD state
- Stash tracking via DID_STASH prevents double stashing
- Golden Rule implementation in stage_all_changes
- Comprehensive error messages with recovery hints
- Support for different remote names (origin/upstream)

### 1.3 Module: migrate-memories.sh (821 lines)

**Purpose**: Centralized memory operations with lock-free atomicity

**Existing Functions** (MUST PRESERVE):
```bash
# Core Memory Operations
backup_memory()               # Atomic backup without locking
restore_memory()              # Atomic restore with cleanup
load_memory()                 # Load with validation
save_memory()                 # Save with validation

# Merge Operations
merge_memories()              # Performance-optimized merge

# Validation
validate_memory_stream()      # Streaming validation

# MCP Coordination
prepare_for_mcp()             # Release file handles
release_from_mcp()            # Wait for safe access

# Performance Helpers
count_entities_stream()       # Fast entity counting
count_relations_stream()      # Fast relation counting
get_memory_stats()            # Memory statistics

# Cleanup
cleanup_temp_files()          # Remove temporary files

# Advanced Operations
extract_memory_from_git()     # Get memory from git commit
memory_changed()              # Check if memory changed
initialize_empty_memory()     # Create empty memory file

# Module Info
migrate_memories_version()    # Show module version
```

**Critical Learnings Preserved**:
- All operations use atomic pattern (temp file → move)
- Platform-specific stat commands (macOS vs Linux)
- Empty memory.json is valid (MCP initial state)
- Associative array handling with ${var:-} pattern
- Streaming processing for performance
- No file locking to avoid MCP conflicts

### 1.4 Wrapper Scripts Current State

#### start.sh (324 lines)
**Current Structure**:
- Sources 3 modules correctly
- Main body does too much (260+ lines)
- Team sync hardcoded (lines 226-260)
- Direct git operations in places
- Session handling mixed with other logic

#### stop.sh (246 lines)
**Current Structure**:
- Sources 3 modules correctly
- Session detection manual (grep/cut)
- Duration calculation duplicated
- Calls save.sh properly
- Cleanup mixed with logic

#### save.sh (195 lines)
**Current Structure**:
- Sources 3 modules correctly
- Uses migrate-memories functions well
- Context detection duplicated
- Clean implementation overall

#### revert.sh (415 lines)
**Current Structure**:
- Largest script, does many things
- Partial revert logic complex (313-375)
- List mode properly implemented
- Context detection duplicated
- Direct file operations in places

#### sync-memory.sh (168 lines)
**Current Structure**:
- NPM cache detection dynamic
- MCP installation handled
- Platform differences handled
- Clean focused implementation

## Part 2: Architectural Issues Analysis

### 2.1 Single Responsibility Principle (SRP) Violations

**Critical Violations**:
1. **merge_memories() in migrate-memories.sh**:
   - Does: indexing + merging + conflict resolution + validation + I/O
   - Should be: 5 separate atomic functions

2. **Main script bodies**:
   - start.sh: 260+ lines doing 7+ different tasks
   - revert.sh: 415 lines mixing UI, git, backup, revert logic

3. **Session handling**:
   - Scattered across start.sh/stop.sh
   - Should be: dedicated session-manager.sh

### 2.2 Don't Repeat Yourself (DRY) Violations

**Critical Duplications**:
1. **Context Detection** (framework vs project):
   - Duplicated in: start.sh, save.sh, revert.sh
   - Each has different implementation

2. **Memory File Path Calculation**:
   ```bash
   # Appears in all scripts:
   if [[ "$WORK_CONTEXT" == "framework" ]]; then
       MEMORY_FILE=".aipm/memory/local_memory.json"
   else
       MEMORY_FILE="$PROJECT_NAME/.aipm/memory/local_memory.json"
   fi
   ```

3. **Session File Parsing**:
   - stop.sh uses grep/cut manually
   - Should use structured parsing

4. **Platform-Specific Operations**:
   - stat commands repeated everywhere
   - date commands duplicated
   - Should use shell-formatting.sh functions

### 2.3 Atomicity Violations

**Functions Doing Too Much**:
1. **Team sync in start.sh (226-260)**:
   - Checks origin
   - Extracts memory
   - Compares files
   - Merges memories
   - Should be: atomic sync_team_memory() function

2. **Partial revert in revert.sh (313-375)**:
   - Extracts from git
   - Filters entities
   - Filters relations
   - Merges results
   - Should be: separate filter and merge functions

### 2.4 Configuration Hardcoding

**Hardcoded Values**:
1. **Paths**:
   - `.aipm/memory/`, `.claude/` paths everywhere
   - Should be: centralized configuration

2. **Defaults**:
   - Model "opus" (start.sh:320)
   - MCP timeouts (5s, 0.1s)
   - Memory size limits (100MB)

3. **Behaviors**:
   - Team sync always automatic
   - Merge strategy always "remote-wins"
   - Should be: configurable

### 2.5 Missing Modular Components

**Required New Modules**:
1. **session-manager.sh**:
   - All session operations
   - Lock management
   - State tracking
   - Cleanup operations

2. **config-manager.sh**:
   - Centralized configuration
   - Path management
   - Default values
   - Environment variables

3. **memory-paths.sh**:
   - Path calculations
   - Context resolution
   - Directory management

### 2.6 CRITICAL: Generic Project Detection Issue

**Major Architecture Violation Found**:
The `.gitignore` file has hardcoded "Product" entries, breaking AIPM's generic nature:
- `Product/.aipm/memory/backup.json` (hardcoded project name)
- `Product/.aipm/memory/session_*` (hardcoded project name)
- This prevents AIPM from working with ANY project name

**Solution Implemented**:
```gitignore
# OLD (WRONG - hardcoded):
Product/.aipm/memory/backup.json
Product/.aipm/memory/session_*

# NEW (CORRECT - generic):
*/.aipm/memory/backup.json
*/.aipm/memory/session_*
```

**Why This Matters**:
1. AIPM must work with ANY project name (ClientWebsite, MobileApp, DataPipeline, etc.)
2. Projects are detected by presence of `.aipm/memory/local_memory.json`
3. All projects are symlinks to independent git repositories
4. The framework cannot assume any specific project names

**Key Principle**: AIPM detects projects dynamically, never hardcodes names

## Part 3: Refactoring Plan

### 3.1 New Module: config-manager.sh

**Purpose**: Centralize ALL configuration and paths

```bash
#!/opt/homebrew/bin/bash
# config-manager.sh - Centralized configuration for AIPM

# Paths
readonly MEMORY_DIR=".memory"
readonly CLAUDE_DIR=".claude"
readonly GLOBAL_MEMORY="${CLAUDE_DIR}/memory.json"
readonly BACKUP_MEMORY="${MEMORY_DIR}/backup.json"
readonly SESSION_FILE="${MEMORY_DIR}/session_active"
readonly SESSION_LOCK="${MEMORY_DIR}/.session_lock"

# Defaults
readonly DEFAULT_MODEL="opus"
readonly DEFAULT_MERGE_STRATEGY="remote-wins"
readonly MCP_SYNC_DELAY="0.1"
readonly MCP_RELEASE_TIMEOUT="5"
readonly MAX_MEMORY_SIZE_MB="100"
readonly MEMORY_SCHEMA_VERSION="1.0"

# Behaviors (can be overridden by environment)
readonly TEAM_SYNC_MODE="${AIPM_TEAM_SYNC:-ask}"  # ask|auto|skip
readonly MEMORY_MERGE_STRATEGY="${AIPM_MERGE_STRATEGY:-remote-wins}"
readonly DEBUG_MODE="${AIPM_DEBUG:-false}"

# Functions
get_memory_path() {
    local context="$1"
    local project="$2"
    
    if [[ "$context" == "framework" ]]; then
        printf "%s/local_memory.json" "$MEMORY_DIR"
    else
        printf "%s/%s/local_memory.json" "$project" "$MEMORY_DIR"
    fi
}

get_session_id() {
    printf "%s_%s" "$(date +%Y%m%d_%H%M%S)" "$$"
}

# Export all for use by other scripts
export -f get_memory_path get_session_id
```

### 3.2 New Module: session-manager.sh

**Purpose**: Centralize ALL session operations

```bash
#!/opt/homebrew/bin/bash
# session-manager.sh - Session management for AIPM

source "$SCRIPT_DIR/config-manager.sh" || exit 1
source "$SCRIPT_DIR/shell-formatting.sh" || exit 1

# Session Operations
create_session() {
    local context="$1"
    local project="$2"
    local memory_file="$3"
    local session_id=$(get_session_id)
    
    # Create session metadata (NOT file lock!)
    cat > "$SESSION_FILE" <<EOF
Session: $session_id
Context: $context
Project: ${project:-N/A}
Started: $(date)
Branch: $(get_current_branch 2>/dev/null || echo "unknown")
Memory: $memory_file
Backup: $BACKUP_MEMORY
PID: $$
EOF
    
    printf "%s" "$session_id"
}

read_session() {
    local field="$1"
    
    [[ ! -f "$SESSION_FILE" ]] && return 1
    
    grep "^${field}:" "$SESSION_FILE" | cut -d' ' -f2-
}

detect_active_session() {
    [[ -f "$SESSION_FILE" ]]
}

cleanup_session() {
    local session_id="$1"
    
    # Archive session file
    if [[ -f "$SESSION_FILE" ]]; then
        mv "$SESSION_FILE" "${MEMORY_DIR}/session_${session_id}_complete"
    fi
    
    # Cleanup temporary files
    cleanup_temp_files
}

calculate_session_duration() {
    local start_time="$1"
    local start_epoch
    
    # Platform-aware date parsing
    if command -v gdate >/dev/null 2>&1; then
        start_epoch=$(gdate -d "$start_time" +%s 2>/dev/null || date +%s)
    else
        start_epoch=$(date -d "$start_time" +%s 2>/dev/null || date +%s)
    fi
    
    local current_epoch=$(date +%s)
    local duration=$((current_epoch - start_epoch))
    
    format_duration "$duration"
}

# Export all functions
export -f create_session read_session detect_active_session
export -f cleanup_session calculate_session_duration
```

### 3.3 Enhanced migrate-memories.sh

**Add Atomic Functions**:

```bash
# Break down merge_memories into atomic functions

# 1. Index entities from file (atomic)
index_entities() {
    local file="$1"
    local -n entities_ref=$2  # nameref to associative array
    
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local type=$(printf '%s' "$line" | jq -r '.type // empty' 2>/dev/null)
        if [[ "$type" == "entity" ]]; then
            local name=$(printf '%s' "$line" | jq -r '.name // empty' 2>/dev/null)
            if [[ -n "$name" ]]; then
                entities_ref["$name"]="$line"
            fi
        fi
    done < "$file"
}

# 2. Process entity conflicts (atomic)
resolve_entity_conflict() {
    local local_entity="$1"
    local remote_entity="$2"
    local strategy="$3"
    
    case "$strategy" in
        "remote-wins") printf '%s' "$remote_entity" ;;
        "local-wins")  printf '%s' "$local_entity" ;;
        "newest-wins")
            local local_ts=$(printf '%s' "$local_entity" | jq -r '.timestamp // 0')
            local remote_ts=$(printf '%s' "$remote_entity" | jq -r '.timestamp // 0')
            [[ "$remote_ts" -gt "$local_ts" ]] && \
                printf '%s' "$remote_entity" || \
                printf '%s' "$local_entity"
            ;;
    esac
}

# 3. Filter entities by pattern (atomic)
filter_entities() {
    local file="$1"
    local pattern="$2"
    local output="$3"
    
    > "$output"
    
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local type=$(printf '%s' "$line" | jq -r '.type // empty' 2>/dev/null)
        local name=$(printf '%s' "$line" | jq -r '.name // empty' 2>/dev/null)
        
        if [[ "$type" == "entity" ]] && [[ "$name" =~ $pattern ]]; then
            printf '%s\n' "$line" >> "$output"
        fi
    done < "$file"
}

# 4. Filter relations for entities (atomic)
filter_relations_for_entities() {
    local file="$1"
    local pattern="$2"
    local output="$3"
    
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local type=$(printf '%s' "$line" | jq -r '.type // empty' 2>/dev/null)
        
        if [[ "$type" == "relation" ]]; then
            local from=$(printf '%s' "$line" | jq -r '.from // empty' 2>/dev/null)
            local to=$(printf '%s' "$line" | jq -r '.to // empty' 2>/dev/null)
            
            if [[ "$from" =~ $pattern ]] || [[ "$to" =~ $pattern ]]; then
                printf '%s\n' "$line" >> "$output"
            fi
        fi
    done < "$file"
}

# 5. Team memory sync (atomic, configurable)
sync_team_memory() {
    local memory_file="$1"
    local sync_mode="${2:-ask}"  # ask|auto|skip
    local merge_strategy="${3:-remote-wins}"
    
    step "Checking for team memory updates..."
    
    # Try to get remote version
    local remote_memory="${memory_file}.remote"
    local found_remote=false
    
    for remote in "origin/HEAD" "origin/main" "origin/master"; do
        if extract_memory_from_git "$remote" "$memory_file" "$remote_memory" 2>/dev/null; then
            found_remote=true
            break
        fi
    done
    
    if [[ "$found_remote" != "true" ]]; then
        debug "No remote memory found"
        return 0
    fi
    
    # Check if different
    if ! memory_changed "$memory_file" "$remote_memory"; then
        info "Local memory already up to date"
        rm -f "$remote_memory"
        return 0
    fi
    
    # Handle sync based on mode
    case "$sync_mode" in
        "skip")
            info "Skipping team sync (mode: skip)"
            rm -f "$remote_memory"
            return 0
            ;;
        "ask")
            if ! confirm "Merge team memory updates?"; then
                rm -f "$remote_memory"
                return 0
            fi
            ;;
        "auto")
            info "Auto-merging team updates"
            ;;
    esac
    
    # Perform merge
    if merge_memories "$memory_file" "$remote_memory" "$memory_file" "$merge_strategy"; then
        success "Team memories merged successfully"
        rm -f "$remote_memory"
        return 0
    else
        warn "Memory merge failed - using local version"
        rm -f "$remote_memory"
        return 1
    fi
}

# Export new atomic functions
export -f index_entities resolve_entity_conflict filter_entities
export -f filter_relations_for_entities sync_team_memory
```

### 3.4 CRITICAL NEW MODULE: opinions-loader.sh

**Purpose**: Complete separation of branching opinions from implementation

**CORNERSTONE PRINCIPLE**: This module enables AIPM to be a self-building, truly extensible system:
- Each workspace (framework or project) has its own opinions.json
- Organizations customize at every level: framework → org → team → project
- Scripts dynamically load opinions based on current workspace context
- Framework opinions serve as templates for new projects
- Projects can evolve independently with their own branching rules

```bash
#!/opt/homebrew/bin/bash
# opinions-loader.sh - Branching opinions loader for AIPM
#
# CRITICAL: This is the CORNERSTONE of AIPM's branching architecture
# - Complete isolation between opinions and implementation
# - Workspace-agnostic: Each project has its own opinions
# - Framework has its template opinions
# - Works across any organization, team, or project
# - Self-building and truly extensible system

source "$SCRIPT_DIR/shell-formatting.sh" || exit 1

# Workspace-aware opinions paths
get_opinions_path() {
    local context="${1:-framework}"
    local project="${2:-}"
    
    if [[ "$context" == "framework" ]]; then
        # Framework opinions
        echo ".aipm/opinions.json"
    else
        # Project-specific opinions
        echo "${project}/.aipm/opinions.json"
    fi
}

# Dynamic paths based on context
OPINIONS_FILE=""
OPINIONS_COMPILED=""
OPINIONS_CACHE="/tmp/aipm_opinions_$$"

# Cache variables (set once per session)
AIPM_BRANCH_PREFIX=""
AIPM_MAIN_BRANCH=""
AIPM_BRANCH_RULES=""

# Load and compile opinions (workspace-aware)
load_opinions() {
    local context="${1:-framework}"
    local project="${2:-}"
    local force="${3:-false}"
    
    # Determine opinions file based on context
    OPINIONS_FILE=$(get_opinions_path "$context" "$project")
    OPINIONS_COMPILED="${OPINIONS_FILE%.json}.compiled"
    
    # Check if already loaded for this context (unless forced)
    local cache_key="${context}_${project}"
    if [[ "$force" != "true" ]] && [[ -n "${AIPM_LOADED_CONTEXT:-}" ]] && [[ "${AIPM_LOADED_CONTEXT}" == "$cache_key" ]]; then
        return 0
    fi
    
    # Ensure opinions file exists (create from framework template if needed)
    if [[ ! -f "$OPINIONS_FILE" ]]; then
        if [[ "$context" == "project" ]] && [[ -f ".aipm/opinions.json" ]]; then
            # Copy framework template to project
            mkdir -p "$(dirname "$OPINIONS_FILE")"
            cp ".aipm/opinions.json" "$OPINIONS_FILE"
            info "Created project opinions from framework template: $OPINIONS_FILE"
        else
            create_default_opinions "$context" "$project"
        fi
    fi
    
    # Compile for performance (only if source is newer)
    if [[ ! -f "$OPINIONS_COMPILED" ]] || [[ "$OPINIONS_FILE" -nt "$OPINIONS_COMPILED" ]]; then
        debug "Compiling opinions for performance..."
        jq -c . < "$OPINIONS_FILE" > "$OPINIONS_COMPILED" || {
            error "Failed to compile opinions"
            return 1
        }
    fi
    
    # Load compiled opinions
    local opinions=$(cat "$OPINIONS_COMPILED")
    
    # Extract key values for fast access
    AIPM_BRANCH_PREFIX=$(echo "$opinions" | jq -r '.branching.prefix // "AIPM_"')
    AIPM_MAIN_BRANCH=$(echo "$opinions" | jq -r '.branching.main_branch // "AIPM_MAIN"')
    AIPM_BRANCH_RULES=$(echo "$opinions" | jq -c '.branching.branch_types // {}')
    
    # Cache protected patterns
    echo "$opinions" | jq -r '.branching.protected_patterns[]' > "$OPINIONS_CACHE.protected"
    
    # Export for child processes
    export AIPM_BRANCH_PREFIX AIPM_MAIN_BRANCH AIPM_BRANCH_RULES
    export AIPM_OPINIONS_LOADED=true
    export AIPM_LOADED_CONTEXT="$cache_key"
    
    debug "Opinions loaded for $context${project:+/$project}: prefix=$AIPM_BRANCH_PREFIX, main=$AIPM_MAIN_BRANCH"
    return 0
}

# Create default opinions file (context-aware)
create_default_opinions() {
    local context="${1:-framework}"
    local project="${2:-}"
    
    mkdir -p "$(dirname "$OPINIONS_FILE")"
    
    # Adjust defaults based on context
    local prefix="AIPM_"
    local main_branch="AIPM_MAIN"
    
    if [[ "$context" == "project" ]] && [[ -n "$project" ]]; then
        # Project-specific defaults
        prefix="${project^^}_"  # Uppercase project name
        main_branch="${prefix}MAIN"
    fi
    
    cat > "$OPINIONS_FILE" <<EOF
{
  "version": "1.0",
  "branching": {
    "prefix": "$prefix",
    "main_branch": "$main_branch",
    "protected_patterns": [
      "^AIPM_.*",
      "^main$",
      "^master$",
      "^develop$",
      "^production$"
    ],
    "branch_types": {
      "feature": {
        "prefix": "AIPM_feature/",
        "lifecycle": "merge_delete",
        "max_age_days": 30,
        "description": "Feature development branches"
      },
      "session": {
        "prefix": "AIPM_session/",
        "lifecycle": "auto_delete",
        "max_age_days": 7,
        "description": "Temporary session branches"
      },
      "backup": {
        "prefix": "AIPM_backup/",
        "lifecycle": "rotate",
        "max_count": 10,
        "description": "Automatic backup branches"
      },
      "sync": {
        "prefix": "AIPM_sync/",
        "lifecycle": "merge_delete",
        "max_age_days": 1,
        "description": "Team synchronization branches"
      }
    },
    "enforcement": {
      "block_direct_main_commits": true,
      "require_aipm_prefix": true,
      "auto_prune": true,
      "prune_interval_days": 7,
      "warn_on_user_branch": true
    },
    "migration": {
      "detect_existing_main": true,
      "create_aipm_main_from": "auto",
      "preserve_user_branches": true,
      "link_to_upstream": true
    }
  },
  "commit": {
    "require_prefix": true,
    "prefixes": ["feat", "fix", "docs", "style", "refactor", "test", "chore"],
    "require_issue_ref": false,
    "sign_commits": false
  }
}
EOF
    
    debug "Created default opinions for $context${project:+/$project}: $OPINIONS_FILE"
    
    if [[ "$context" == "project" ]]; then
        info "Project opinions created with prefix: $prefix"
        info "Customize $OPINIONS_FILE to adjust branching rules for this project"
    fi
}

# Get configured main branch (context-aware)
get_main_branch() {
    local context="${WORK_CONTEXT:-framework}"
    local project="${PROJECT_NAME:-}"
    
    [[ -z "$AIPM_MAIN_BRANCH" ]] && load_opinions "$context" "$project"
    printf "%s" "$AIPM_MAIN_BRANCH"
}

# Get branch prefix for type (context-aware)
get_branch_prefix() {
    local branch_type="${1:-feature}"
    local context="${WORK_CONTEXT:-framework}"
    local project="${PROJECT_NAME:-}"
    
    [[ -z "$AIPM_BRANCH_RULES" ]] && load_opinions "$context" "$project"
    
    local prefix=$(echo "$AIPM_BRANCH_RULES" | jq -r --arg type "$branch_type" '.[$type].prefix // empty')
    [[ -z "$prefix" ]] && prefix="${AIPM_BRANCH_PREFIX}${branch_type}/"
    
    printf "%s" "$prefix"
}

# Check if branch is protected (context-aware)
is_protected_branch() {
    local branch="$1"
    local context="${WORK_CONTEXT:-framework}"
    local project="${PROJECT_NAME:-}"
    
    [[ ! -f "$OPINIONS_CACHE.protected" ]] && load_opinions "$context" "$project"
    
    while IFS= read -r pattern; do
        if [[ "$branch" =~ $pattern ]]; then
            return 0
        fi
    done < "$OPINIONS_CACHE.protected"
    
    return 1
}

# Validate branch name against rules (context-aware)
validate_branch_name() {
    local branch="$1"
    local branch_type="${2:-}"
    local context="${WORK_CONTEXT:-framework}"
    local project="${PROJECT_NAME:-}"
    
    [[ -z "$AIPM_BRANCH_PREFIX" ]] && load_opinions "$context" "$project"
    
    # Check if it's an AIPM branch
    if [[ ! "$branch" =~ ^${AIPM_BRANCH_PREFIX} ]]; then
        # Non-AIPM branches are allowed but warned
        debug "Branch '$branch' is not an AIPM branch"
        return 1
    fi
    
    # If type specified, check prefix
    if [[ -n "$branch_type" ]]; then
        local expected_prefix=$(get_branch_prefix "$branch_type")
        if [[ ! "$branch" =~ ^${expected_prefix} ]]; then
            error "Branch '$branch' doesn't match expected prefix: $expected_prefix"
            return 1
        fi
    fi
    
    return 0
}

# Get branch lifecycle rules
get_branch_lifecycle() {
    local branch="$1"
    
    [[ -z "$AIPM_BRANCH_RULES" ]] && load_opinions
    
    # Determine branch type from name
    local branch_type=""
    echo "$AIPM_BRANCH_RULES" | jq -r 'keys[]' | while read -r type; do
        local prefix=$(get_branch_prefix "$type")
        if [[ "$branch" =~ ^${prefix} ]]; then
            branch_type="$type"
            break
        fi
    done
    
    if [[ -n "$branch_type" ]]; then
        echo "$AIPM_BRANCH_RULES" | jq -c --arg type "$branch_type" '.[$type]'
    else
        echo "{}"
    fi
}

# Check if branch should be auto-deleted
should_auto_delete() {
    local branch="$1"
    local lifecycle=$(get_branch_lifecycle "$branch" | jq -r '.lifecycle // "keep"')
    
    [[ "$lifecycle" == "auto_delete" ]] || [[ "$lifecycle" == "merge_delete" ]]
}

# Enforce branching rules
enforce_branch_operation() {
    local operation="$1"  # create|delete|merge|commit
    local branch="$2"
    
    [[ -z "$AIPM_BRANCH_PREFIX" ]] && load_opinions
    
    local opinions=$(cat "$OPINIONS_COMPILED")
    local enforcement=$(echo "$opinions" | jq -r '.branching.enforcement // {}')
    
    case "$operation" in
        "commit")
            # Check if direct commits to main are blocked
            if [[ "$branch" == "$(get_main_branch)" ]]; then
                if [[ "$(echo "$enforcement" | jq -r '.block_direct_main_commits // false')" == "true" ]]; then
                    error "Direct commits to $branch are not allowed"
                    info "Create a feature branch: git checkout -b ${AIPM_BRANCH_PREFIX}feature/your-feature"
                    return 1
                fi
            fi
            ;;
        "create")
            # Check if AIPM prefix is required
            if [[ "$(echo "$enforcement" | jq -r '.require_aipm_prefix // false')" == "true" ]]; then
                if ! validate_branch_name "$branch"; then
                    warn "Branch '$branch' doesn't follow AIPM naming convention"
                    info "Suggested: ${AIPM_BRANCH_PREFIX}feature/$(echo "$branch" | sed "s/^.*\///")"
                fi
            fi
            ;;
        "delete")
            # Prevent deletion of protected branches
            if is_protected_branch "$branch"; then
                error "Cannot delete protected branch: $branch"
                return 1
            fi
            ;;
    esac
    
    return 0
}

# Initialize branches for workspace (using workspace opinions)
initialize_aipm_branches() {
    local project="${1:-}"
    local source_branch="${2:-}"
    
    step "Initializing branches for ${project:-framework} workspace..."
    
    # Detect existing main if not specified
    if [[ -z "$source_branch" ]]; then
        source_branch=$(detect_existing_main)
        info "Detected existing main branch: $source_branch"
    fi
    
    # Create framework main branch if it doesn't exist
    local aipm_main=$(get_main_branch)
    if ! branch_exists "$aipm_main"; then
        info "Creating $aipm_main from $source_branch..."
        if create_branch "$aipm_main" "$source_branch"; then
            success "$aipm_main created successfully"
        else
            error "Failed to create $aipm_main"
            return 1
        fi
    else
        info "$aipm_main already exists"
    fi
    
    # Set upstream tracking
    if [[ -n "$project" ]]; then
        ensure_remote_tracking "$project"
    fi
    
    return 0
}

# Detect existing main branch
detect_existing_main() {
    # Check origin/HEAD first
    local origin_head=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    [[ -n "$origin_head" ]] && echo "$origin_head" && return 0
    
    # Check common names
    for branch in main master develop trunk; do
        if branch_exists "$branch"; then
            echo "$branch"
            return 0
        fi
    done
    
    # Default to main
    echo "main"
}

# Cleanup old AIPM branches
cleanup_aipm_branches() {
    local dry_run="${1:-false}"
    
    [[ -z "$AIPM_BRANCH_RULES" ]] && load_opinions
    
    step "Cleaning up old AIPM branches..."
    
    local count=0
    git branch --format='%(refname:short)' | grep "^${AIPM_BRANCH_PREFIX}" | while read -r branch; do
        local lifecycle=$(get_branch_lifecycle "$branch")
        local should_delete=false
        
        # Check lifecycle rules
        local lifecycle_type=$(echo "$lifecycle" | jq -r '.lifecycle // "keep"')
        case "$lifecycle_type" in
            "auto_delete")
                local max_age=$(echo "$lifecycle" | jq -r '.max_age_days // 7')
                local age_days=$(get_branch_age_days "$branch")
                [[ "$age_days" -gt "$max_age" ]] && should_delete=true
                ;;
            "rotate")
                local max_count=$(echo "$lifecycle" | jq -r '.max_count // 10')
                # Count similar branches
                local pattern=$(echo "$branch" | sed 's/[0-9]*$//')
                local similar_count=$(git branch | grep -c "^${pattern}")
                [[ "$similar_count" -gt "$max_count" ]] && should_delete=true
                ;;
        esac
        
        if [[ "$should_delete" == "true" ]]; then
            if [[ "$dry_run" == "true" ]]; then
                info "Would delete: $branch"
            else
                if git branch -d "$branch" 2>/dev/null; then
                    success "Deleted: $branch"
                    ((count++))
                else
                    warn "Cannot delete $branch (may have unmerged changes)"
                fi
            fi
        fi
    done
    
    info "Cleaned up $count branches"
}

# Get branch age in days
get_branch_age_days() {
    local branch="$1"
    local last_commit=$(git log -1 --format=%ct "$branch" 2>/dev/null || echo "0")
    local now=$(date +%s)
    local age_seconds=$((now - last_commit))
    echo $((age_seconds / 86400))
}

# Export all functions
export -f load_opinions create_default_opinions get_main_branch
export -f get_branch_prefix is_protected_branch validate_branch_name
export -f get_branch_lifecycle should_auto_delete enforce_branch_operation
export -f initialize_aipm_branches detect_existing_main cleanup_aipm_branches
export -f get_branch_age_days

# CRITICAL: Workspace Context Detection
# All wrapper scripts MUST set these variables before using opinion functions:
# - WORK_CONTEXT: "framework" or "project"
# - PROJECT_NAME: Name of project (when WORK_CONTEXT="project")
# This enables true workspace-agnostic behavior where each workspace has its own opinions
```

### 3.5 Updated version-control.sh Integration

**Critical Changes Required**:

```bash
# At the top of version-control.sh, after sourcing shell-formatting.sh:
source "$SCRIPT_DIR/opinions-loader.sh" || {
    error "Required file opinions-loader.sh not found"
    exit 1
}

# CRITICAL: version-control.sh functions rely on WORK_CONTEXT and PROJECT_NAME
# being set by the calling script to load the correct workspace opinions

# Replace hardcoded protected branch pattern (line 105):
# OLD: readonly PROTECTED_BRANCHES="^(main|master|develop|production)$"
# NEW: (removed - use is_protected_branch() instead)

# Update get_default_branch() function:
get_default_branch() {
    local dir="${1:-.}"
    local original_dir=$(pwd)
    
    cd "$dir" >/dev/null 2>&1 || return 1
    
    # First check for framework main branch (from opinions)
    local aipm_main=$(get_main_branch)
    if branch_exists "$aipm_main"; then
        echo "$aipm_main"
        cd "$original_dir" >/dev/null
        return 0
    fi
    
    # Fall back to detecting existing main
    local detected=$(detect_existing_main)
    echo "$detected"
    
    cd "$original_dir" >/dev/null
    return 0
}

# Update create_branch() to enforce naming:
create_branch() {
    local branch_name="$1"
    local base_branch="${2:-$(get_current_branch)}"
    local switch="${3:-true}"
    
    # Enforce branch naming conventions
    if ! enforce_branch_operation "create" "$branch_name"; then
        return 1
    fi
    
    # Suggest AIPM naming if not compliant
    if ! validate_branch_name "$branch_name"; then
        local suggested="${AIPM_BRANCH_PREFIX}feature/${branch_name#*/}"
        if confirm "Use suggested name: $suggested?"; then
            branch_name="$suggested"
        fi
    fi
    
    # ... rest of existing implementation
}

# Update cleanup_merged_branches() to respect AIPM branches:
cleanup_merged_branches() {
    # ... existing implementation until line checking protected branches
    
    # Replace protection check with:
    if is_protected_branch "$branch"; then
        info "  Skipping protected branch"
        continue
    fi
    
    # Add AIPM lifecycle check:
    if should_auto_delete "$branch"; then
        info "  Branch follows auto-delete lifecycle"
        # ... continue with deletion
    fi
}
```

### 3.6 Critical Branching Integration in Wrapper Scripts

**CORNERSTONE PRINCIPLE**: The opinions-loader.sh module ensures complete isolation between branching rules and their enforcement. This is CRITICAL for multi-team/multi-organization usage.

#### start.sh Branching Integration:
```bash
# Source opinions-loader FIRST (after shell-formatting)
source "$SCRIPT_DIR/shell-formatting.sh" || exit 1
source "$SCRIPT_DIR/opinions-loader.sh" || exit 1
source "$SCRIPT_DIR/version-control.sh" || exit 1

# During initialization:
main() {
    # ... existing initialization ...
    
    # Load workspace-specific opinions
    load_opinions "$WORK_CONTEXT" "$PROJECT_NAME"
    
    # Initialize branches based on loaded opinions
    if [[ "$WORK_CONTEXT" == "project" ]]; then
        initialize_aipm_branches "$PROJECT_NAME"
    fi
    
    # Create session branch (optional)
    if [[ "$(get_branch_operation_mode)" == "session_branches" ]]; then
        local session_branch="$(get_branch_prefix 'session')${SESSION_ID}"
        create_branch "$session_branch" "$(get_main_branch)"
        info "Working on session branch: $session_branch"
    fi
    
    # Record framework main branch in session
    SESSION_MAIN_BRANCH=$(get_main_branch)
}
```

#### save.sh Branching Integration:
```bash
# Enforce commit location based on opinions
prepare_commit() {
    local current_branch=$(get_current_branch)
    
    # Check if commits to main are allowed
    if ! enforce_branch_operation "commit" "$current_branch"; then
        # Auto-create feature branch
        local feature_name="save-$(date +%Y%m%d-%H%M%S)"
        local feature_branch="$(get_branch_prefix 'feature')$feature_name"
        
        info "Creating feature branch for changes..."
        create_branch "$feature_branch" "$current_branch" || die "Failed to create branch"
        current_branch="$feature_branch"
    fi
    
    # Stage and commit
    stage_all_changes || die "Failed to stage changes"
    commit_with_stats "$COMMIT_MSG" "$MEMORY_FILE" || die "Commit failed"
    
    # Offer to merge back to main if on feature branch
    if [[ "$current_branch" =~ ^${AIPM_BRANCH_PREFIX}feature/ ]]; then
        if confirm "Merge changes to $(get_main_branch)?"; then
            switch_branch "$(get_main_branch)"
            git merge --no-ff "$current_branch" -m "Merge $current_branch"
            
            # Clean up if lifecycle says so
            if should_auto_delete "$current_branch"; then
                git branch -d "$current_branch"
                success "Feature branch merged and cleaned up"
            fi
        fi
    fi
}
```

#### revert.sh Branching Integration:
```bash
# Use framework main branch for revert operations
prepare_revert() {
    # Always revert from framework main history (from opinions)
    local main_branch=$(get_main_branch)
    
    # Update remote references to use AIPM branches
    for remote in "origin/$main_branch" "origin/$(get_default_branch)"; do
        if extract_memory_from_git "$remote" "$MEMORY_FILE" "$REMOTE_MEMORY" 2>/dev/null; then
            found_remote=true
            break
        fi
    done
}
```

#### stop.sh Branching Integration:
```bash
# Handle session branch cleanup
cleanup_session() {
    local current_branch=$(get_current_branch)
    
    # If on session branch, offer to merge or discard
    if [[ "$current_branch" =~ ^${AIPM_BRANCH_PREFIX}session/ ]]; then
        if is_repo_clean; then
            info "No changes on session branch"
            switch_branch "$(get_main_branch)"
            git branch -d "$current_branch" 2>/dev/null
        else
            warn "Uncommitted changes on session branch"
            if confirm "Save changes before cleanup?"; then
                "$SCRIPT_DIR/save.sh" --$WORK_CONTEXT ${PROJECT_NAME:+"$PROJECT_NAME"} "Session end"
            fi
        fi
    fi
    
    # Run branch cleanup based on opinions
    if [[ "$(get_auto_prune_enabled)" == "true" ]]; then
        cleanup_aipm_branches
    fi
}
```

### 3.7 Refactored start.sh

**Using All Modules Atomically**:

```bash
#!/opt/homebrew/bin/bash
set -euo pipefail

# Source all modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shell-formatting.sh" || exit 1
source "$SCRIPT_DIR/version-control.sh" || exit 1
source "$SCRIPT_DIR/migrate-memories.sh" || exit 1
source "$SCRIPT_DIR/config-manager.sh" || exit 1
source "$SCRIPT_DIR/session-manager.sh" || exit 1

# Parse arguments (atomic function)
parse_start_arguments() {
    WORK_CONTEXT=""
    PROJECT_NAME=""
    TEAM_SYNC_MODE="${TEAM_SYNC_MODE:-ask}"
    claude_args=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --framework)
                WORK_CONTEXT="framework"
                shift
                ;;
            --project)
                WORK_CONTEXT="project"
                PROJECT_NAME="$2"
                shift 2
                ;;
            --sync)
                TEAM_SYNC_MODE="$2"
                shift 2
                ;;
            --model)
                claude_args+=("--model" "$2")
                shift 2
                ;;
            *)
                claude_args+=("$1")
                shift
                ;;
        esac
    done
}

# Context selection (atomic function)
select_context_interactive() {
    info "Available contexts:"
    info "  1) Framework Development"
    
    local project_num=2
    declare -A project_map
    
    for dir in */; do
        if [[ -f "${dir}${MEMORY_DIR}/local_memory.json" ]]; then
            project_map[$project_num]="${dir%/}"
            info "  $project_num) Project: ${dir%/}"
            ((project_num++))
        fi
    done
    
    read -p "$(format_prompt "Select context (1-$((project_num-1)))")" selection
    
    if [[ "$selection" == "1" ]]; then
        WORK_CONTEXT="framework"
    elif [[ -n "${project_map[$selection]:-}" ]]; then
        WORK_CONTEXT="project"
        PROJECT_NAME="${project_map[$selection]}"
    else
        die "Invalid selection"
    fi
}

# Main flow (clean and atomic)
main() {
    section "AIPM Session Initialization"
    
    # 1. Check memory symlink
    step "Checking memory symlink..."
    if [[ ! -L "$GLOBAL_MEMORY" ]]; then
        "$SCRIPT_DIR/sync-memory.sh" || die "Failed to create memory symlink"
    fi
    success "Memory symlink verified"
    
    # 2. Parse arguments
    parse_start_arguments "$@"
    
    # 3. Interactive context if needed
    if [[ -z "$WORK_CONTEXT" ]]; then
        select_context_interactive
    fi
    
    success "Context: $WORK_CONTEXT${PROJECT_NAME:+ - $PROJECT_NAME}"
    
    # 4. Get memory file path
    MEMORY_FILE=$(get_memory_path "$WORK_CONTEXT" "$PROJECT_NAME")
    
    # 5. Git sync for projects
    if [[ "$WORK_CONTEXT" == "project" ]]; then
        step "Checking project git status..."
        initialize_memory_context "--project" "$PROJECT_NAME"
        
        if check_git_repo "$PROJECT_NAME"; then
            # Offer to pull latest
            if fetch_remote "$PROJECT_NAME"; then
                local behind=$(get_commits_ahead_behind | grep -o 'behind: [0-9]*' | cut -d' ' -f2 || echo "0")
                if [[ "$behind" -gt 0 ]]; then
                    if confirm "Pull $behind commits from remote?"; then
                        pull_latest "$PROJECT_NAME" || warn "Pull failed"
                    fi
                fi
            fi
        fi
    fi
    
    # 6. Memory operations (all atomic)
    backup_memory || die "Failed to backup global memory"
    
    # 7. Team sync (configurable)
    if [[ -f "$MEMORY_FILE" ]]; then
        sync_team_memory "$MEMORY_FILE" "$TEAM_SYNC_MODE" "$MEMORY_MERGE_STRATEGY"
    fi
    
    # 8. Load memory
    load_memory "$MEMORY_FILE" || die "Failed to load project memory"
    
    # 9. Create session
    SESSION_ID=$(create_session "$WORK_CONTEXT" "$PROJECT_NAME" "$MEMORY_FILE")
    success "Session created: $SESSION_ID"
    
    # 10. Prepare for MCP
    prepare_for_mcp
    
    section_end
    
    # 11. Launch Claude
    info "Launching Claude Code..."
    info "When done, run: ./scripts/stop.sh"
    
    # Add default model if not specified
    if [[ ! " ${claude_args[@]} " =~ " --model " ]]; then
        claude_args+=("--model" "$DEFAULT_MODEL")
    fi
    
    claude code "${claude_args[@]}"
}

# Execute
main "$@"
```

### 3.5 Implementation Priority & Sequence

**Phase 1: Foundation Modules** (Do First)
1. Create config-manager.sh
2. Create session-manager.sh
3. Enhance migrate-memories.sh with atomic functions

**Phase 2: Wrapper Script Refactoring** (Do Second)
1. Refactor start.sh using new modules
2. Refactor stop.sh using new modules
3. Refactor save.sh (minimal changes needed)
4. Refactor revert.sh (biggest changes)

**Phase 3: Testing & Validation** (Do Third)
1. Test each module in isolation
2. Test integrated workflows
3. Verify all learnings preserved
4. Performance benchmarks

## Part 4: Critical Preservation Checklist

### 4.1 Learnings That MUST Be Preserved

1. **File Reversion Bug Protection**:
   - ✓ All atomic operations use temp file → move pattern
   - ✓ Never modify files in place
   - ✓ Verify operations completed

2. **Platform Compatibility**:
   - ✓ Dual stat commands (stat -f%z || stat -c%s)
   - ✓ WSL detection in platform detection
   - ✓ Timeout command detection (timeout/gtimeout)

3. **MCP Coordination**:
   - ✓ Never lock global memory.json
   - ✓ prepare_for_mcp() releases handles
   - ✓ release_from_mcp() waits safely

4. **Memory Protection**:
   - ✓ Global memory always restored
   - ✓ Atomic operations only
   - ✓ Validation before operations

5. **Performance Optimizations**:
   - ✓ Streaming processing
   - ✓ Cached platform detection
   - ✓ Associative arrays for O(1) lookups

### 4.2 Patterns That MUST Be Preserved

1. **Error Handling**:
   ```bash
   function || die "Clear error message"
   ```

2. **Resource Cleanup**:
   ```bash
   trap cleanup_on_exit EXIT
   ```

3. **Atomic Operations**:
   ```bash
   temp_file="${target}.tmp.$$"
   cp source "$temp_file" && mv -f "$temp_file" target
   ```

4. **Platform Detection**:
   ```bash
   stat -f%z file 2>/dev/null || stat -c%s file 2>/dev/null
   ```

## Part 5: Migration Strategy

### 5.1 Safe Migration Steps

1. **Create New Modules First**:
   - Don't modify existing modules initially
   - Create config-manager.sh
   - Create session-manager.sh
   - Test new modules independently

2. **Enhance Existing Modules**:
   - Add new atomic functions to migrate-memories.sh
   - Don't remove existing functions
   - Test enhanced module

3. **Refactor One Script at a Time**:
   - Start with save.sh (smallest changes)
   - Then stop.sh
   - Then start.sh
   - Finally revert.sh (most complex)

4. **Parallel Testing**:
   - Keep old scripts as .sh.backup
   - Test new scripts thoroughly
   - Compare outputs

### 5.2 Rollback Plan

1. All changes versioned in git
2. Keep backup of working scripts
3. Test in isolated environment first
4. Incremental rollout

## Part 6: Success Metrics

### 6.1 Architecture Metrics

1. **Function Atomicity**: Each function ≤ 50 lines
2. **Module Cohesion**: Clear single responsibility
3. **DRY Compliance**: Zero duplicate implementations
4. **Configuration**: All hardcoded values eliminated

### 6.2 Performance Metrics

1. **Memory Operations**: < 1s for 10MB files
2. **Session Operations**: < 100ms
3. **Platform Detection**: Cached after first call
4. **No Degradation**: Same or better performance

### 6.3 Maintainability Metrics

1. **Test Coverage**: 100% of public functions
2. **Documentation**: Every function documented
3. **Error Messages**: Clear recovery path
4. **Learning Preservation**: 100% retained

## Part 7: Detailed Function Mappings

### 7.1 Where Functions Should Move

**From scripts to config-manager.sh**:
- Memory path calculations
- Session ID generation
- All hardcoded values
- Default configurations

**From scripts to session-manager.sh**:
- Session file operations
- Session state tracking
- Duration calculations
- Session cleanup

**Stay in migrate-memories.sh**:
- All memory file operations
- Add new atomic functions
- Keep existing functions

**Stay in shell-formatting.sh**:
- All output functions
- Platform utilities
- Already well-organized

**Stay in version-control.sh**:
- All git operations
- Already well-organized

### 7.2 New Atomic Functions Needed

1. **parse_arguments()** - Standardized argument parsing
2. **detect_projects()** - Find all AIPM projects
3. **select_project_interactive()** - Interactive project selection
4. **sync_team_memory()** - Configurable team sync
5. **filter_memory_entities()** - For partial revert
6. **create_session_metadata()** - Session file creation
7. **parse_session_file()** - Structured session parsing

## Part 8: Risk Mitigation

### 8.1 High-Risk Areas

1. **Session Management**: Test concurrent sessions
2. **Memory Operations**: Verify atomicity preserved
3. **Platform Compatibility**: Test on all platforms
4. **Git Integration**: Test all edge cases

### 8.2 Testing Strategy

1. **Unit Tests**: Each atomic function
2. **Integration Tests**: Module interactions
3. **End-to-End Tests**: Complete workflows
4. **Performance Tests**: Large file handling
5. **Platform Tests**: macOS, Linux, WSL

## Part 9: CRITICAL - Branching Architecture (CORNERSTONE)

### 9.1 Why Branching Opinions Are The Cornerstone

**CRITICAL**: The branching architecture with complete opinion/implementation separation is THE CORNERSTONE of AIPM because:

1. **True Workspace Agnosticism**: Each project has its own opinions.json, not just one global config
2. **Self-Building System**: Use AIPM to improve AIPM itself with framework opinions
3. **Multi-Level Customization**: Framework → Organization → Team → Project opinions cascade
4. **Zero Conflicts**: Each workspace's prefix ensures no branch conflicts
5. **Migration Safety**: Projects adopt framework template then customize independently
6. **Extensibility**: New projects inherit and adapt opinions for their needs

### 9.2 Branching Opinion Architecture

```
ISOLATION LAYERS:
┌─────────────────────────────────────┐
│   .aipm/opinions.json (framework)   │  <- Framework template
│   Project/.aipm/opinions.json       │  <- Project-specific
│   Another/.aipm/opinions.json       │  <- Each project customizes
├─────────────────────────────────────┤
│       opinions-loader.sh            │  <- Context-aware loading
├─────────────────────────────────────┤
│       version-control.sh            │  <- Enforces loaded opinions
├─────────────────────────────────────┤
│    Wrapper Scripts (start/stop/     │  <- Set context, use opinions
│         save/revert)                │
└─────────────────────────────────────┘
```

### 9.3 Critical Design Decisions

1. **AIPM_ Prefix is Non-Negotiable**:
   - Creates protected namespace
   - Visual distinction in `git branch`
   - Enables automated cleanup
   - Prevents accidental operations on user branches

2. **Workspace Main Branch (from workspace's opinions.json)**:
   - Each workspace (framework/project) has its own main branch
   - Framework might use AIPM_MAIN, projects might use PROJECT_MAIN
   - Operations use get_main_branch() which loads correct opinions
   - User's original branches untouched
   - Complete workspace isolation

3. **Branch Types with Lifecycles**:
   - `AIPM_feature/*` - Merge and delete
   - `AIPM_session/*` - Auto-delete after inactivity
   - `AIPM_backup/*` - Rotate keeping N newest
   - `AIPM_sync/*` - Temporary for team sync

4. **Enforcement Modes**:
   - Soft: Warnings and suggestions
   - Hard: Block non-compliant operations
   - Gradual: Detect and adapt

### 9.4 Migration Strategy for Existing Projects

```bash
# Phase 1: First Run Detection
$ ./scripts/start.sh --project ExistingProject
> Loading opinions for project/ExistingProject
> No project opinions found, copying from framework template
> Created: ExistingProject/.aipm/opinions.json
> Detecting existing branch structure...
> Found main branch: master
> Creating EXISTINGPROJECT_MAIN from master...
> Project branches initialized!

# Phase 2: Each Workspace Has Its Own Branches
# Framework workspace:
AIPM_MAIN (framework main)
AIPM_feature/improve-scripts
AIPM_session/20240621_140523

# ExistingProject workspace:
main (user's original)
master (user's original)
EXISTINGPROJECT_MAIN (project's main)
EXISTINGPROJECT_feature/new-feature

# AnotherProject workspace:
ANOTHERPROJECT_MAIN (different project's main)
ANOTHERPROJECT_feature/api-update

# Phase 3: Clear Separation
- User continues work on their branches
- AIPM operations ONLY on AIPM_* branches
- No interference, no conflicts
```

### 9.5 Why This Is Critical for Success

Without proper branching isolation:
- Framework commits mix with user commits
- Branch naming conflicts arise
- Team workflows become inconsistent  
- Automation becomes impossible
- Multi-org usage fails

With opinions-based branching:
- Complete namespace isolation
- Consistent workflows across teams
- Safe automation (cleanup, rotation)
- Works in ANY git repository
- Scales to enterprise usage

### 9.6 Implementation Priority

**THIS MUST BE IMPLEMENTED FIRST** in the refactoring:

1. Create opinions-loader.sh module
2. Update version-control.sh to use opinions
3. Update ALL wrapper scripts to respect opinions
4. Test with existing repositories
5. Verify zero conflicts with user branches

## Conclusion

This refactoring plan provides a path to clean, maintainable, and performant AIPM wrapper scripts while preserving all hard-won learnings and optimizations. The workspace-agnostic branching architecture is the CORNERSTONE that enables AIPM to be a self-building, truly extensible system where:

- Each workspace (framework or project) has its own opinions
- Organizations can customize at every level
- The framework itself can be improved using AIPM
- Projects inherit and adapt from templates
- True isolation ensures no conflicts between workspaces

**Remember**: 
- Atomicity enables flexibility
- Modularity enables maintainability  
- Configuration enables adaptability
- Isolation enables universality
- Testing enables confidence

The result will be a professional-grade system that follows SOLID principles while maintaining all the robustness and performance optimizations developed through extensive hardening.