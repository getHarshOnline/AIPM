# AIPM Module Function Inventory

This document provides a COMPLETE inventory of all functions available in the AIPM module scripts. This serves as THE reference for AI/LLM to know what functions exist and how to use them.

**CRITICAL**: This inventory must be exhaustive and accurate. Every function, parameter, return value, and usage example has been documented.

## Export Pattern Design

**CRITICAL ARCHITECTURAL DECISION**: Not all modules export their functions, and this is BY DESIGN:

### Modules WITH Function Exports:
- **migrate-memories.sh**: Exports all 18 functions via `export -f` because they are utility functions that may be called from subshells or background processes

### Modules WITHOUT Function Exports:
- **opinions-state.sh**: NO exports - functions work within the same shell context after sourcing to maintain state consistency
- **shell-formatting.sh**: Only exports flag variable `SHELL_FORMATTING_LOADED=true`
- **version-control.sh**: Only exports flag variable `VERSION_CONTROL_LOADED=true`
- **opinions-loader.sh**: Exports environment variables (AIPM_*) but NOT functions
- **sync-memory.sh**: NO exports - tightly coupled to memory operations
- **cleanup-global.sh**: NO exports - specialized cleanup context

### Why This Matters:
1. **State Management**: opinions-state.sh functions maintain locks and shared state that must remain in the same shell context
2. **Direct Sourcing**: All wrapper scripts source modules directly: `source "$SCRIPT_DIR/modules/opinions-state.sh"`
3. **No Subshells**: Functions without exports are designed to run in the parent shell only
4. **Utility vs Core**: Exported functions (migrate-memories.sh) are utilities; non-exported are core state/context-dependent

**IMPLEMENTATION RULE**: When adding new functions, follow the module's existing export pattern. DO NOT add exports to modules that don't have them.

---

## Table of Contents

1. [shell-formatting.sh - Formatting and Output](#shell-formattingsh---formatting-and-output) (74 functions)
2. [version-control.sh - Git Operations](#version-controlsh---git-operations) (89 functions)
3. [migrate-memories.sh - Memory Operations](#migrate-memoriessh---memory-operations) (18 functions)
4. [opinions-state.sh - State Management](#opinions-statesh---state-management) (28 functions)
5. [opinions-loader.sh - Configuration Loading](#opinions-loadersh---configuration-loading) (46 functions)
6. [sync-memory.sh - Memory Synchronization](#sync-memorysh---memory-synchronization) (4 functions)

**Total Functions**: 259 documented functions across all modules

---

## shell-formatting.sh - Formatting and Output

### Platform Detection

#### `detect_platform()`
- **Purpose**: Detects the operating system platform
- **Parameters**: None
- **Returns**: Sets global PLATFORM variable to: macos, linux, wsl, cygwin, mingw, or unknown
- **Example**: 
  ```bash
  detect_platform
  echo "Platform: $PLATFORM"
  ```
- **Learning**: WSL detection requires checking /proc/version for "microsoft" string

### Environment Detection

#### `detect_context()`
- **Purpose**: Detects execution context (terminal, CI/CD, pipe, Claude Code, etc.)
- **Parameters**: None
- **Returns**: Sets EXECUTION_CONTEXT to: ci, claude, pipe, log, or terminal
- **Example**: 
  ```bash
  detect_context
  if [[ "$EXECUTION_CONTEXT" == "terminal" ]]; then
    # Use visual features
  fi
  ```
- **Learning**: Claude Code REPL detection checks multiple indicators for robustness

### State Directory Management

#### `ensure_state_dir()`
- **Purpose**: Ensures state directory exists with proper permissions
- **Parameters**: None (uses global $STATE_DIR)
- **Returns**: 0 on success, 1 on failure
- **Example**:
  ```bash
  ensure_state_dir || return 1
  ```

### Color Functions

#### `set_color(color_name, bold)`
- **Purpose**: Sets foreground color for text output
- **Parameters**: 
  - color_name: black, red, green, yellow, blue, magenta, cyan, white, reset
  - bold: true/false (optional)
- **Returns**: Outputs ANSI color codes
- **Example**: 
  ```bash
  set_color "red" true
  printf "Error text"
  reset_format
  ```

#### `set_bg_color(color_name)`
- **Purpose**: Sets background color
- **Parameters**: color_name (same as set_color)
- **Returns**: Outputs ANSI background color codes

#### `set_format(format_name)`
- **Purpose**: Applies text formatting
- **Parameters**: bold, dim, italic, underline, blink, reverse, strikethrough, reset
- **Returns**: Outputs ANSI format codes

#### `reset_format()`
- **Purpose**: Resets all formatting
- **Parameters**: None
- **Returns**: Outputs reset ANSI code

#### `get_symbol(symbol_name)`
- **Purpose**: Gets Unicode symbol with ASCII fallback
- **Parameters**: check, cross, warning, info, dot, arrow, triangle, box_* symbols
- **Returns**: Unicode symbol or ASCII equivalent
- **Example**: 
  ```bash
  printf "%s Task completed\n" "$(get_symbol check)"
  ```

#### `fprint(color, text, bold)`
- **Purpose**: Prints colored text with automatic reset
- **Parameters**: color name, text, bold (optional)
- **Returns**: Outputs colored text

#### `fprintln(color, text, bold)`
- **Purpose**: Same as fprint but adds newline
- **Parameters**: Same as fprint
- **Returns**: Outputs colored text with newline

### Color Initialization

#### `init_colors()`
- **Purpose**: Initialize all color variables based on terminal capabilities
- **Parameters**: None
- **Returns**: Sets global color variables (RED, GREEN, etc.)
- **Learning**: Direct ANSI codes are faster than function calls for static colors

#### `init_symbols()`
- **Purpose**: Initialize all symbol variables based on Unicode support
- **Parameters**: None
- **Returns**: Sets global symbol variables (CHECK, CROSS, etc.)

### Debug Functions

#### `debug(message)`
- **Purpose**: Outputs debug messages when DEBUG is set
- **Parameters**: Debug message
- **Returns**: Outputs to stderr if DEBUG is set
- **Example**: 
  ```bash
  DEBUG=true
  debug "Variable value: $var"
  ```

### Command Execution

#### `detect_timeout_command()`
- **Purpose**: Detects available timeout command (timeout/gtimeout)
- **Parameters**: None
- **Returns**: Sets TIMEOUT_CMD and TIMEOUT_STYLE globals
- **Learning**: macOS needs coreutils for timeout command

#### `safe_execute(cmd, timeout_seconds, max_retries)`
- **Purpose**: Execute command with timeout and retry logic
- **Parameters**: 
  - cmd: Command to execute
  - timeout_seconds: Timeout in seconds (default: 30)
  - max_retries: Max retry attempts (default: 3)
- **Returns**: Command exit code
- **Example**: 
  ```bash
  safe_execute "git fetch" 60 2
  ```

#### `execute_with_spinner(message, command, timeout)`
- **Purpose**: Execute command with visual spinner
- **Parameters**: Message, command, timeout (optional)
- **Returns**: Command exit code
- **Example**: 
  ```bash
  execute_with_spinner "Building project" "npm run build" 120
  ```

### Error Handling

#### `set_error_trap(context)`
- **Purpose**: Sets error trap with context information
- **Parameters**: Context name (e.g., "script-name")
- **Returns**: Sets ERR and EXIT traps

#### `handle_error(exit_code, cmd, line)`
- **Purpose**: Handles trapped errors
- **Parameters**: Exit code, command, line number
- **Returns**: Outputs error information

#### `handle_exit(exit_code)`
- **Purpose**: Handles script exit
- **Parameters**: Exit code
- **Returns**: Performs cleanup

### Message Functions

#### `error(message)`
- **Purpose**: Print error message with symbol
- **Parameters**: Error message
- **Returns**: Outputs to stderr
- **Learning**: All message functions use consistent single space after symbol

#### `warn(message)`
- **Purpose**: Print warning message with symbol
- **Parameters**: Warning message
- **Returns**: Outputs to stderr

#### `success(message)`
- **Purpose**: Print success message with symbol
- **Parameters**: Success message
- **Returns**: Outputs to stdout

#### `info(message)`
- **Purpose**: Print info message with symbol
- **Parameters**: Info message
- **Returns**: Outputs to stdout

#### `step(message)`
- **Purpose**: Print step message with arrow
- **Parameters**: Step description
- **Returns**: Outputs to stdout

#### `section(title)`
- **Purpose**: Print section header with separator
- **Parameters**: Section title
- **Returns**: Outputs formatted header

### Structured Output

#### `output(level, code, message, details)`
- **Purpose**: Context-aware output formatting
- **Parameters**: 
  - level: ERROR, WARN, SUCCESS, INFO, DEBUG
  - code: Exit/error code
  - message: Main message
  - details: Additional details (optional)
- **Returns**: Exit code

#### `output_error(code, message, details)`
- **Purpose**: Structured error output
- **Parameters**: Code, message, details (optional)
- **Returns**: Error code

#### `output_warn(code, message, details)`
- **Purpose**: Structured warning output
- **Parameters**: Code, message, details (optional)
- **Returns**: 0

#### `output_success(message, details)`
- **Purpose**: Structured success output
- **Parameters**: Message, details (optional)
- **Returns**: 0

#### `output_info(message, details)`
- **Purpose**: Structured info output
- **Parameters**: Message, details (optional)
- **Returns**: 0

#### `output_debug(message, details)`
- **Purpose**: Structured debug output
- **Parameters**: Message, details (optional)
- **Returns**: 0

### Logging Functions

#### `init_log()`
- **Purpose**: Initialize log file with header
- **Parameters**: None (uses LOG_FILE env var)
- **Returns**: Creates log file

#### `log(level, message)`
- **Purpose**: Log message to file and optionally screen
- **Parameters**: Log level, message
- **Returns**: Outputs to log file

### Box Drawing

#### `draw_box(title, width)`
- **Purpose**: Draw a box with optional title
- **Parameters**: Title (optional), width (default: 50)
- **Returns**: Outputs box
- **Example**: 
  ```bash
  draw_box "Welcome" 60
  ```
- **Learning**: Width parameter is inner width, not including borders

#### `draw_separator(width, color)`
- **Purpose**: Draw a horizontal line separator
- **Parameters**: Width (default: 50), color (default: CYAN)
- **Returns**: Outputs line

### Progress Indicators

#### `cleanup_spinner()`
- **Purpose**: Clean up running spinner
- **Parameters**: None
- **Returns**: Kills spinner process, shows cursor

#### `start_spinner(message)`
- **Purpose**: Start animated spinner
- **Parameters**: Message to display
- **Returns**: Sets SPINNER_PID global
- **Example**: 
  ```bash
  start_spinner "Processing..."
  # Do work
  stop_spinner
  ```

#### `stop_spinner()`
- **Purpose**: Stop running spinner
- **Parameters**: None
- **Returns**: Calls cleanup_spinner

#### `show_progress(current, total, message)`
- **Purpose**: Show progress bar
- **Parameters**: Current value, total value, message (optional)
- **Returns**: Outputs progress bar
- **Example**: 
  ```bash
  for i in {1..100}; do
    show_progress $i 100 "Processing files"
    sleep 0.1
  done
  ```
- **Learning**: Only works in interactive terminals, uses carriage return for animation

#### `with_progress(message, total, step)`
- **Purpose**: Automatic progress bar wrapper
- **Parameters**: Message, total (default: 100), step (default: 10)
- **Returns**: Shows animated progress

#### `progress_with_items(current, total, current_item, recent_items...)`
- **Purpose**: Progress bar with rolling item list
- **Parameters**: Current, total, current item, array of recent items
- **Returns**: Multi-line progress display
- **Learning**: Advanced UX showing progress + item context

#### `process_items_with_progress(items_array_name, command_template)`
- **Purpose**: Process array with automatic progress
- **Parameters**: Array name (nameref), command template with $item
- **Returns**: 0 on success
- **Example**: 
  ```bash
  files=(*.txt)
  process_items_with_progress files 'cp $item backup/'
  ```

### Input Helpers

#### `confirm(prompt, default)`
- **Purpose**: Prompt for yes/no confirmation
- **Parameters**: Prompt text, default (y/n, default: n)
- **Returns**: 0 for yes, 1 for no
- **Example**: 
  ```bash
  if confirm "Continue?"; then
    echo "Proceeding..."
  fi
  ```

#### `prompt_value(prompt, default, pattern)`
- **Purpose**: Prompt for value with validation
- **Parameters**: Prompt, default value, regex pattern
- **Returns**: Outputs validated value
- **Example**: 
  ```bash
  name=$(prompt_value "Enter name" "default" "^[a-zA-Z]+$")
  ```

### Utility Functions

#### `center_text(text, width)`
- **Purpose**: Center text within width
- **Parameters**: Text, width (default: terminal width)
- **Returns**: Outputs centered text

#### `format_size(bytes)`
- **Purpose**: Format bytes to human-readable size
- **Parameters**: Size in bytes
- **Returns**: Formatted string (e.g., "1.5 MB")
- **Example**: 
  ```bash
  size=$(format_size 1536000)  # Returns "1.50 MB"
  ```

#### `format_duration(seconds)`
- **Purpose**: Format seconds to human-readable duration
- **Parameters**: Duration in seconds
- **Returns**: Formatted string (e.g., "2h 15m 30s")

#### `get_file_mtime(filename)`
- **Purpose**: Get file modification time (cross-platform)
- **Parameters**: File path
- **Returns**: Modification time in seconds since epoch
- **Learning**: Uses different stat commands for macOS vs Linux

#### `make_temp_file(suffix)`
- **Purpose**: Create temporary file (cross-platform)
- **Parameters**: File suffix (default: .tmp)
- **Returns**: Outputs temp file path

### Error Handling

#### `die(message, code)`
- **Purpose**: Print error and exit
- **Parameters**: Error message, exit code (default: 1)
- **Returns**: Never returns (exits)
- **Example**: 
  ```bash
  [[ -f "$file" ]] || die "File not found: $file" 2
  ```

#### `assert(condition, message)`
- **Purpose**: Assert condition is true
- **Parameters**: Condition to test, error message
- **Returns**: 0 if true, exits if false
- **Example**: 
  ```bash
  assert "[[ -d $dir ]]" "Directory must exist"
  ```

---

## version-control.sh - Git Operations

### Security & Context Management

#### `detect_nesting_level()`
- **Purpose**: Detect and prevent recursive script execution
- **Parameters**: None
- **Returns**: 0 on success, 1 if nesting too deep
- **Side Effects**: Increments AIPM_NESTING_LEVEL
- **Learning**: Prevents security issues from recursive sourcing

#### `cleanup_nesting_level()`
- **Purpose**: Decrement nesting level on exit
- **Parameters**: None
- **Returns**: 0 always
- **Side Effects**: Decrements AIPM_NESTING_LEVEL

#### `resolve_project_path(path)`
- **Purpose**: Resolve symlinks to actual path
- **Parameters**: Path to resolve
- **Returns**: Resolved absolute path
- **Example**: 
  ```bash
  real_path=$(resolve_project_path ".")
  ```

#### `get_project_context()`
- **Purpose**: Detect project context and set globals
- **Parameters**: None
- **Returns**: Sets PROJECT_ROOT, PROJECT_NAME, IS_SYMLINKED, AIPM_CONTEXT
- **Example**: 
  ```bash
  get_project_context
  echo "Working in: $PROJECT_NAME ($AIPM_CONTEXT)"
  ```

### Memory Management Initialization

#### `initialize_memory_context(context_arg, project_name)`
- **Purpose**: Initialize memory file paths based on context
- **Parameters**: 
  - context_arg: "--framework" or "--project" (optional)
  - project_name: Project name if --project
- **Returns**: 0 on success
- **Side Effects**: Sets MEMORY_FILE_PATH, MEMORY_DIR, etc.
- **Example**: 
  ```bash
  initialize_memory_context --project Product
  ```

#### `reinit_memory_context(...)`
- **Purpose**: Re-initialize memory context
- **Parameters**: Same as initialize_memory_context
- **Returns**: 0 on success

### Git Configuration

#### `check_git_repo()`
- **Purpose**: Verify we're in a git repository
- **Parameters**: None
- **Returns**: 0 if in repo, 1 if not
- **Example**: 
  ```bash
  check_git_repo || die "Not in a git repository"
  ```

#### `get_current_branch()`
- **Purpose**: Get current branch name
- **Parameters**: None
- **Returns**: Branch name or "(detached:hash)" if detached
- **Example**: 
  ```bash
  branch=$(get_current_branch)
  ```
- **Learning**: Handles detached HEAD state gracefully

#### `get_default_branch()`
- **Purpose**: Get default branch (main/master)
- **Parameters**: None
- **Returns**: Default branch name
- **Example**: 
  ```bash
  default=$(get_default_branch)
  ```

### Status Functions

#### `is_working_directory_clean(verbose)`
- **Purpose**: Check if working directory has uncommitted changes
- **Parameters**: verbose: true/false (optional)
- **Returns**: 0 if clean, 3 if dirty
- **Example**: 
  ```bash
  if ! is_working_directory_clean true; then
    echo "Please commit changes first"
  fi
  ```

#### `get_commits_ahead_behind(branch)`
- **Purpose**: Get commit counts relative to remote
- **Parameters**: branch name (optional, defaults to current)
- **Returns**: "ahead: X, behind: Y" or error
- **Example**: 
  ```bash
  status=$(get_commits_ahead_behind)
  ```

#### `show_git_status(project)`
- **Purpose**: Display formatted git status
- **Parameters**: project path (optional)
- **Returns**: 0 on success
- **Side Effects**: Outputs formatted status to stdout

### Stash Functions

#### `stash_changes(message, include_untracked)`
- **Purpose**: Stash current changes with tracking
- **Parameters**: 
  - message: Stash message (optional)
  - include_untracked: true/false (default: true)
- **Returns**: 0 on success, 1 if no changes, 2 if failed
- **Side Effects**: Sets DID_STASH=true if successful
- **Example**: 
  ```bash
  stash_changes "Work in progress" true
  ```

#### `restore_stash(stash_ref)`
- **Purpose**: Restore stashed changes
- **Parameters**: stash_ref (optional, defaults to latest)
- **Returns**: 0 on success, 1 if no stash, 2 if failed
- **Side Effects**: Sets DID_STASH=false
- **Example**: 
  ```bash
  restore_stash
  ```

#### `list_stashes()`
- **Purpose**: List all stashes with formatting
- **Parameters**: None
- **Returns**: 0 if stashes exist, 1 if none

### Sync Functions

#### `fetch_remote(project)`
- **Purpose**: Fetch remote changes with progress
- **Parameters**: project path (optional)
- **Returns**: 0 on success, 5 on network error
- **Example**: 
  ```bash
  fetch_remote
  ```
- **Learning**: Uses spinner for visual feedback in terminal mode

#### `pull_latest(project, force_pull)`
- **Purpose**: Pull changes with rebase and stash handling
- **Parameters**: 
  - project: Path (optional)
  - force_pull: true/false to auto-stash
- **Returns**: 0 on success, various error codes
- **Example**: 
  ```bash
  pull_latest "" true  # Force stash if needed
  ```

### Commit Functions

#### `create_commit(message, description, skip_hooks, auto_stage)`
- **Purpose**: Create well-formatted commit
- **Parameters**: 
  - message: Commit message (required)
  - description: Extended description (optional)
  - skip_hooks: true/false (default: false)
  - auto_stage: true/false (default: true - GOLDEN RULE)
- **Returns**: 0 on success, 1 on validation error, 2 on git error
- **Example**: 
  ```bash
  create_commit "feat: Add new feature" "This adds..." false true
  ```
- **Learning**: Implements AIPM golden rule - stages ALL changes by default

#### `commit_with_stats(message, file_path)`
- **Purpose**: Commit with file statistics
- **Parameters**: 
  - message: Commit message
  - file_path: File to get stats from (optional, uses MEMORY_FILE_PATH)
- **Returns**: Same as create_commit
- **Example**: 
  ```bash
  commit_with_stats "Update memory" ".memory/local_memory.json"
  ```

### Golden Rule Functions

#### `add_all_untracked()`
- **Purpose**: Add all untracked files respecting .gitignore
- **Parameters**: None
- **Returns**: 0 on success
- **Side Effects**: Stages untracked files
- **Learning**: Critical for AIPM workflow - respects .gitignore strictly

#### `ensure_memory_tracked()`
- **Purpose**: Ensure memory files are tracked in git
- **Parameters**: None
- **Returns**: 0 on success
- **Side Effects**: Stages memory files if needed
- **Example**: 
  ```bash
  ensure_memory_tracked
  ```

#### `stage_all_changes(include_memory)`
- **Purpose**: Stage all changes (golden rule implementation)
- **Parameters**: include_memory: true/false (default: true)
- **Returns**: 0 on success
- **Side Effects**: Stages all changes
- **Example**: 
  ```bash
  stage_all_changes true
  ```

#### `safe_add(path)`
- **Purpose**: Add file with gitignore and symlink handling
- **Parameters**: File/directory path
- **Returns**: 0 on success, 1 if doesn't exist, 2 if gitignored, 3 if failed
- **Example**: 
  ```bash
  safe_add "src/newfile.js"
  ```

#### `find_all_memory_files()`
- **Purpose**: Find all memory files in repository
- **Parameters**: None
- **Returns**: List of memory file paths
- **Example**: 
  ```bash
  memory_files=$(find_all_memory_files)
  ```

#### `check_memory_status(branch)`
- **Purpose**: Check memory file status across branches
- **Parameters**: Branch to compare (optional)
- **Returns**: 0 if in sync, 1 if differ, 2 if missing

### Branch Functions

#### `create_branch(branch_name, base_branch)`
- **Purpose**: Create and checkout new branch
- **Parameters**: 
  - branch_name: New branch name
  - base_branch: Base branch (default: default branch)
- **Returns**: 0 on success, 1 on error
- **Example**: 
  ```bash
  create_branch "feature/new-thing" "main"
  ```

#### `list_branches()`
- **Purpose**: List branches with details
- **Parameters**: None
- **Returns**: 0 always
- **Side Effects**: Outputs formatted branch list

### Merge Functions

#### `safe_merge(source_branch, target_branch)`
- **Purpose**: Merge branch with safety checks
- **Parameters**: 
  - source_branch: Branch to merge from
  - target_branch: Branch to merge to (default: current)
- **Returns**: 0 on success, 1 on error
- **Example**: 
  ```bash
  safe_merge "feature/done" "main"
  ```

### History Functions

#### `show_log(count, file, show_graph)`
- **Purpose**: Display formatted git log
- **Parameters**: 
  - count: Number of entries (default: 10)
  - file: File to show history for (optional)
  - show_graph: true/false (default: true)
- **Returns**: 0 always
- **Example**: 
  ```bash
  show_log 20 "README.md" true
  ```

#### `find_file_commits(file, count)`
- **Purpose**: Find commits affecting a file
- **Parameters**: 
  - file: File path
  - count: Max commits (default: 20)
- **Returns**: 0 always

### Diff Functions

#### `show_diff_stats(ref1, ref2, file)`
- **Purpose**: Show diff statistics
- **Parameters**: 
  - ref1: First reference (default: HEAD)
  - ref2: Second reference (optional)
  - file: Specific file (optional)
- **Returns**: 0 always

### Tag Functions

#### `create_tag(tag_name, message)`
- **Purpose**: Create annotated tag
- **Parameters**: 
  - tag_name: Tag name
  - message: Tag message (default: "Release tag_name")
- **Returns**: 0 on success, 1 on error
- **Example**: 
  ```bash
  create_tag "v1.0.0" "First stable release"
  ```

### Utility Functions

#### `is_file_tracked(file)`
- **Purpose**: Check if file is tracked by git
- **Parameters**: File path
- **Returns**: 0 if tracked, 1 if not
- **Example**: 
  ```bash
  if is_file_tracked "config.json"; then
    echo "File is tracked"
  fi
  ```

#### `get_repo_root()`
- **Purpose**: Get repository root directory
- **Parameters**: None
- **Returns**: Repository root path
- **Example**: 
  ```bash
  root=$(get_repo_root)
  ```

#### `cleanup_merged_branches(batch_mode)`
- **Purpose**: Delete merged branches safely
- **Parameters**: batch_mode: true/false
- **Returns**: 0 on success
- **Learning**: Protects important branches, shows summary

### Advanced Operations

#### `push_changes(force, sync_team)`
- **Purpose**: Push with automatic upstream setup
- **Parameters**: 
  - force: true/false
  - sync_team: true/false for memory sync
- **Returns**: 0 on success, 5 on network error
- **Example**: 
  ```bash
  push_changes false true  # Normal push with team sync
  ```

#### `create_backup_branch(operation)`
- **Purpose**: Create backup before dangerous operations
- **Parameters**: operation name (default: "backup")
- **Returns**: 0 on success, 1 on error
- **Example**: 
  ```bash
  create_backup_branch "before-rebase"
  ```

#### `undo_last_commit(keep_changes)`
- **Purpose**: Undo last commit with safety
- **Parameters**: keep_changes: true/false (default: true)
- **Returns**: 0 on success
- **Example**: 
  ```bash
  undo_last_commit true  # Keep changes staged
  ```

### Conflict Resolution

#### `check_conflicts()`
- **Purpose**: Check for merge conflicts
- **Parameters**: None
- **Returns**: 0 if no conflicts, 1 if conflicts exist
- **Example**: 
  ```bash
  if ! check_conflicts; then
    resolve_conflicts
  fi
  ```

#### `resolve_conflicts()`
- **Purpose**: Interactive conflict resolution
- **Parameters**: None
- **Returns**: 0 when resolved
- **Side Effects**: Modifies conflicted files based on user choice

### State Integration Functions

#### `get_git_config(key, default)`
- **Purpose**: Read git config with state caching
- **Parameters**: 
  - key: Config key (e.g., "user.name")
  - default: Default value if not set
- **Returns**: 0 if found, 1 if using default
- **Outputs**: Config value or default
- **Example**: 
  ```bash
  username=$(get_git_config "user.name" "unknown")
  ```

#### `get_status_porcelain()`
- **Purpose**: Get machine-readable status with state updates
- **Parameters**: None
- **Returns**: 0 on success, 2 on git error
- **Outputs**: Porcelain format status
- **Side Effects**: Updates state values atomically

#### `count_uncommitted_files()`
- **Purpose**: Count files with uncommitted changes
- **Parameters**: None
- **Returns**: 0 always
- **Outputs**: Number of uncommitted files

#### `get_branch_commit(branch)`
- **Purpose**: Get commit SHA for a branch
- **Parameters**: Branch name or reference
- **Returns**: 0 if found, 1 if not
- **Outputs**: Full commit SHA

#### `list_merged_branches(target)`
- **Purpose**: List branches merged into target
- **Parameters**: Target branch (optional, default: HEAD)
- **Returns**: 0 on success, 2 on error
- **Outputs**: Merged branch names

#### `is_branch_merged(branch, target)`
- **Purpose**: Check if branch is merged
- **Parameters**: 
  - branch: Branch to check
  - target: Target branch (default: HEAD)
- **Returns**: 0 if merged, 1 if not, 2 on error

#### `get_upstream_branch(branch)`
- **Purpose**: Get upstream tracking branch
- **Parameters**: Branch name (optional, default: HEAD)
- **Returns**: 0 if has upstream, 1 if not
- **Outputs**: Upstream branch name

#### `has_upstream(branch)`
- **Purpose**: Check if branch has upstream
- **Parameters**: Branch name (optional)
- **Returns**: 0 if has upstream, 1 if not

#### `get_branch_log(branch, format, extra_opts)`
- **Purpose**: Get commit log with custom format
- **Parameters**: 
  - branch: Branch name (default: HEAD)
  - format: Format string (default: "%H %s")
  - extra_opts: Additional git log options
- **Returns**: 0 on success, 2 on error
- **Outputs**: Formatted log entries

#### `find_commits_with_pattern(pattern, branch, extra_opts)`
- **Purpose**: Search commit messages
- **Parameters**: 
  - pattern: Search pattern
  - branch: Branch to search (default: --all)
  - extra_opts: Additional options
- **Returns**: 0 if found, 1 if not, 2 on error
- **Outputs**: Matching commits

#### `get_branch_creation_date(branch)`
- **Purpose**: Get branch creation date
- **Parameters**: Branch name (optional)
- **Returns**: 0 on success, 1 if not found, 2 on error
- **Outputs**: ISO 8601 date string

#### `get_branch_last_commit_date(branch)`
- **Purpose**: Get last commit date on branch
- **Parameters**: Branch name (optional)
- **Returns**: 0 on success, 1 if not found, 2 on error
- **Outputs**: ISO 8601 date string

#### `show_file_history(file, format, extra_opts)`
- **Purpose**: Get commit history for file
- **Parameters**: 
  - file: File path (required)
  - format: Format string (default: "%h %ad %an: %s")
  - extra_opts: Additional options
- **Returns**: 0 on success, 1 if not found, 2 on error
- **Outputs**: Formatted history

#### `get_git_dir()`
- **Purpose**: Get .git directory path
- **Parameters**: None
- **Returns**: 0 on success, 1 if not in repo
- **Outputs**: Absolute path to .git
- **Side Effects**: Updates runtime.git.gitDir in state

#### `is_in_git_dir()`
- **Purpose**: Check if inside .git directory
- **Parameters**: None
- **Returns**: 0 if inside, 1 if not

#### `count_stashes()`
- **Purpose**: Count number of stashes
- **Parameters**: None
- **Returns**: 0 always
- **Outputs**: Stash count
- **Side Effects**: Updates runtime.git.stashCount in state

#### `has_remote_repository(remote)`
- **Purpose**: Check if remote exists
- **Parameters**: Remote name (default: "origin")
- **Returns**: 0 if exists, 1 if not
- **Side Effects**: Updates runtime.git.hasRemote if checking origin

---

## migrate-memories.sh - Memory Operations

### Core Memory Operations

#### `backup_memory(source, target, validate)`
- **Purpose**: Create atomic backup of memory file
- **Parameters**: 
  - source: Source file (default: .claude/memory.json)
  - target: Target file (default: .memory/backup.json)
  - validate: true/false (default: true)
- **Returns**: 0 on success, 2 on validation error, 3 on I/O error
- **Example**: 
  ```bash
  backup_memory ".claude/memory.json" ".memory/backup.json" true
  ```
- **Learning**: Uses atomic operations to prevent corruption

#### `restore_memory(source, target, delete_source)`
- **Purpose**: Restore memory from backup atomically
- **Parameters**: 
  - source: Backup file (default: .memory/backup.json)
  - target: Target file (default: .claude/memory.json)
  - delete_source: true/false (default: true)
- **Returns**: 0 on success, 3 on I/O error
- **Example**: 
  ```bash
  restore_memory ".memory/backup.json" ".claude/memory.json" true
  ```

#### `load_memory(source, target)`
- **Purpose**: Load memory file with validation
- **Parameters**: 
  - source: Source file path
  - target: Target file (default: .claude/memory.json)
- **Returns**: 0 on success, 2 on validation error, 3 on I/O error
- **Example**: 
  ```bash
  load_memory "project/.memory/local_memory.json"
  ```

#### `save_memory(source, target)`
- **Purpose**: Save memory file with validation
- **Parameters**: 
  - source: Source file (default: .claude/memory.json)
  - target: Target file path (required)
- **Returns**: 0 on success, 1 on missing target, 2 on validation error, 3 on I/O error
- **Example**: 
  ```bash
  save_memory ".claude/memory.json" ".memory/local_memory.json"
  ```

### Memory Merge Operations

#### `merge_memories(local_file, remote_file, output_file, conflict_strategy)`
- **Purpose**: Merge two memory files with conflict resolution
- **Parameters**: 
  - local_file: Local memory file
  - remote_file: Remote memory file
  - output_file: Output merged file
  - conflict_strategy: "remote-wins" (default), "local-wins", "newest-wins"
- **Returns**: 0 on success, 2 on validation error, 3 on I/O error
- **Example**: 
  ```bash
  merge_memories "local.json" "remote.json" "merged.json" "newest-wins"
  ```
- **Learning**: Uses streaming for files >10MB, associative arrays for O(1) lookups

### Validation Operations

#### `validate_memory_stream(file, context)`
- **Purpose**: Validate memory file structure and content
- **Parameters**: 
  - file: File to validate
  - context: "framework" or "project" (affects prefix validation)
- **Returns**: 0 if valid, 2 if invalid, 3 if file not found
- **Example**: 
  ```bash
  validate_memory_stream ".memory/local_memory.json" "project"
  ```
- **Learning**: Validates entity prefixes to prevent cross-contamination

### MCP Coordination Functions

#### `prepare_for_mcp()`
- **Purpose**: Prepare for MCP server handoff
- **Parameters**: None
- **Returns**: 0 always
- **Side Effects**: Flushes writes, adds small delay
- **Learning**: MCP server needs clean handoff

#### `release_from_mcp(max_wait_seconds)`
- **Purpose**: Wait for MCP to release file locks
- **Parameters**: max_wait_seconds (default: 5)
- **Returns**: 0 if released, 4 on timeout
- **Example**: 
  ```bash
  release_from_mcp 10
  ```

### Performance Helper Functions

#### `count_entities_stream(file)`
- **Purpose**: Count entities efficiently
- **Parameters**: File path
- **Returns**: Entity count as string
- **Example**: 
  ```bash
  count=$(count_entities_stream "memory.json")
  ```

#### `count_relations_stream(file)`
- **Purpose**: Count relations efficiently
- **Parameters**: File path
- **Returns**: Relation count as string

#### `get_memory_stats(file)`
- **Purpose**: Get memory file statistics
- **Parameters**: File path
- **Returns**: Formatted stats string
- **Example**: 
  ```bash
  stats=$(get_memory_stats "memory.json")
  # Output: "150 entities, 75 relations, 2.5 MB"
  ```

### Cleanup Operations

#### `cleanup_temp_files()`
- **Purpose**: Remove temporary files
- **Parameters**: None
- **Returns**: 0 always
- **Side Effects**: Removes all temp files with module's pattern
- **Learning**: Uses PID suffix to identify module's files

### Advanced Operations

#### `extract_memory_from_git(commit, file_path, output_file)`
- **Purpose**: Extract memory file from git history
- **Parameters**: 
  - commit: Git commit reference
  - file_path: Path in repository
  - output_file: Where to save
- **Returns**: 0 on success, 2 on validation error, 3 on I/O error
- **Example**: 
  ```bash
  extract_memory_from_git "HEAD~5" ".memory/local_memory.json" "old.json"
  ```

#### `memory_changed(current_file, backup_file)`
- **Purpose**: Check if memory has changed
- **Parameters**: Current file, backup file
- **Returns**: 0 if changed, 1 if unchanged
- **Example**: 
  ```bash
  if memory_changed "current.json" "backup.json"; then
    echo "Memory has been modified"
  fi
  ```

#### `initialize_empty_memory(file)`
- **Purpose**: Create empty memory file
- **Parameters**: File path
- **Returns**: 0 on success, 1 on error
- **Side Effects**: Creates directory if needed

#### `revert_memory_partial(backup_file, output_file, filter_pattern)`
- **Purpose**: Restore memory with entity filtering for partial reverts
- **Parameters**: 
  - backup_file: Source backup file to restore from
  - output_file: Target file for filtered results
  - filter_pattern: Regex pattern to match entity names
- **Returns**: 0 on success, 1 on general error, 2 on validation error, 3 on I/O error
- **Side Effects**: Creates filtered memory file with matching entities and their relations
- **Example**: 
  ```bash
  # Revert only AIPM_FEATURE entities
  revert_memory_partial ".memory/backup.json" ".memory/partial.json" "^AIPM_FEATURE"
  
  # Revert entities containing "test"
  revert_memory_partial "backup.json" "filtered.json" ".*test.*"
  ```
- **Learning**: Relations are included if either 'from' or 'to' matches an entity in the filter

### Module Information

#### `migrate_memories_version()`
- **Purpose**: Show module version and capabilities
- **Parameters**: None
- **Returns**: 0 always
- **Side Effects**: Outputs version info

---

## opinions-state.sh - State Management

### Utility Functions

#### `check_jq_installed()`
- **Purpose**: Verify jq is available
- **Parameters**: None
- **Returns**: 0 if installed, 1 if not
- **Side Effects**: Writes error if missing

#### `ensure_state_dir()`
- **Purpose**: Create state directory if needed
- **Parameters**: None (uses global STATE_DIR)
- **Returns**: 0 on success, 1 on failure

### Lock Management

#### `acquire_state_lock()`
- **Purpose**: Get exclusive lock for state operations
- **Parameters**: None (timeout from AIPM_STATE_LOCK_TIMEOUT env)
- **Returns**: 0 if acquired, 1 on timeout
- **Example**: 
  ```bash
  acquire_state_lock || die "Cannot get lock"
  # ... state operations ...
  release_state_lock
  ```
- **Learning**: Uses flock when available, directory lock as fallback

#### `release_state_lock()`
- **Purpose**: Release state lock
- **Parameters**: None
- **Returns**: 0 always
- **Side Effects**: Closes FD or removes lock directory

#### `validate_lock_held()`
- **Purpose**: Verify we hold the lock
- **Parameters**: None
- **Returns**: Dies if lock not held
- **Example**: 
  ```bash
  validate_lock_held  # Dies if no lock
  ```

### State File Operations

#### `read_state_file()`
- **Purpose**: Load state file into cache
- **Parameters**: None (uses STATE_FILE global)
- **Returns**: 0 on success, 1 if missing/invalid
- **Side Effects**: Sets STATE_CACHE and STATE_LOADED
- **Example**: 
  ```bash
  read_state_file || initialize_state
  ```

#### `write_state_file(content)`
- **Purpose**: Write state atomically with validation
- **Parameters**: JSON content
- **Returns**: 0 on success, 1 on invalid JSON or error
- **Side Effects**: Updates STATE_FILE, STATE_CACHE, STATE_HASH
- **Example**: 
  ```bash
  write_state_file "$new_state"
  ```

### Atomic Operations Framework

#### `begin_atomic_operation(op_name)`
- **Purpose**: Start atomic transaction
- **Parameters**: Operation name for tracking
- **Returns**: 0 on success, 1 on lock failure
- **Side Effects**: Acquires lock, saves rollback state
- **Example**: 
  ```bash
  begin_atomic_operation "update:branch"
  update_state "runtime.branch" "main"
  commit_atomic_operation
  ```

#### `commit_atomic_operation()`
- **Purpose**: Finalize atomic transaction
- **Parameters**: None
- **Returns**: 0 on success, 1 on validation failure
- **Side Effects**: Validates state, updates metadata, releases lock

#### `rollback_atomic_operation()`
- **Purpose**: Restore pre-transaction state
- **Parameters**: None
- **Returns**: 0 always
- **Side Effects**: Restores rollback state, releases lock

#### `validate_state_consistency()`
- **Purpose**: Check state structure and content
- **Parameters**: None (uses STATE_CACHE)
- **Returns**: 0 if valid, 1 if issues found
- **Example**: 
  ```bash
  validate_state_consistency || initialize_state
  ```

### Computation Functions

#### `resolve_pattern_variables(pattern)`
- **Purpose**: Replace pattern variables with values
- **Parameters**: Pattern string with {variables}
- **Returns**: Pattern with replacements
- **Supported Variables**: {timestamp}, {date}, {user}
- **Example**: 
  ```bash
  pattern=$(resolve_pattern_variables "feature/{user}/{date}")
  ```

#### `compute_all_branch_patterns()`
- **Purpose**: Pre-compute branch naming patterns
- **Parameters**: None
- **Returns**: JSON with pattern mappings
- **Output Format**: 
  ```json
  {
    "feature": {
      "original": "feature/{description}",
      "full": "aipm/feature/{description}",
      "glob": "aipm/feature/*",
      "regex": "^aipm/feature/(.+)$"
    }
  }
  ```
- **Learning**: Discovers patterns dynamically from AIPM_NAMING_* vars

#### `compute_protected_branches_list()`
- **Purpose**: Compute list of protected branches
- **Parameters**: None
- **Returns**: JSON with categorized branches
- **Output Format**: 
  ```json
  {
    "userBranches": ["main", "develop"],
    "aipmBranches": [{"suffix": "session", "full": "aipm/session"}],
    "all": ["main", "develop", "aipm/session"]
  }
  ```

#### `compute_complete_lifecycle_matrix()`
- **Purpose**: Compute lifecycle rules for branches
- **Parameters**: None
- **Returns**: JSON with lifecycle configuration
- **Learning**: Transforms days_to_keep into actionable timing rules

#### `compute_complete_workflow_rules()`
- **Purpose**: Compute workflow configurations
- **Parameters**: None
- **Returns**: JSON with workflow rules and prompts
- **Learning**: Includes pre-configured prompts for consistent UX

#### `compute_complete_validation_rules()`
- **Purpose**: Compute validation configuration
- **Parameters**: None
- **Returns**: JSON with validation rules
- **Learning**: Supports gradual mode for progressive enforcement

#### `compute_complete_memory_config()`
- **Purpose**: Compute memory system configuration
- **Parameters**: None
- **Returns**: JSON with memory settings

#### `compute_complete_team_config()`
- **Purpose**: Compute team collaboration settings
- **Parameters**: None
- **Returns**: JSON with team configuration

#### `compute_complete_session_config()`
- **Purpose**: Compute session management settings
- **Parameters**: None
- **Returns**: JSON with session configuration

#### `compute_loading_config()`
- **Purpose**: Compute loading and validation settings
- **Parameters**: None
- **Returns**: JSON with loading configuration

#### `compute_initialization_config()`
- **Purpose**: Compute initialization settings
- **Parameters**: None
- **Returns**: JSON with init configuration

#### `compute_defaults_and_limits()`
- **Purpose**: Compute default values and limits
- **Parameters**: None
- **Returns**: JSON with defaults
- **Learning**: Converts memory size units to bytes

#### `compute_error_handling_config()`
- **Purpose**: Compute error handling settings
- **Parameters**: None
- **Returns**: JSON with error configuration

#### `compute_settings_config()`
- **Purpose**: Compute framework settings
- **Parameters**: None
- **Returns**: JSON with settings

### Runtime State Functions

#### `get_complete_runtime_branches()`
- **Purpose**: Get comprehensive branch metadata
- **Parameters**: None
- **Returns**: JSON with branch information
- **Complexity**: High - O(n*m) where n=branches, m=commits
- **Learning**: Tracks both AIPM and protected user branches

### Session Management Functions

#### `create_session(context, project)`
- **Purpose**: Create and initialize a new AIPM session with atomic state updates
- **Parameters**: 
  - context: Either "framework" or "project" 
  - project: Project name (optional, required if context is "project")
- **Returns**: 0 on success, 1 on error
- **Side Effects**: 
  - Creates session ID and file
  - Updates multiple state values atomically
  - Creates session file at computed memory path
- **Example**: 
  ```bash
  # Framework session
  create_session "framework"
  
  # Project session
  create_session "project" "PRODUCT"
  ```
- **Learning**: Uses atomic operations to ensure all session state updates succeed or fail together

#### `cleanup_session()`
- **Purpose**: Clean up active session with proper state updates and archival
- **Parameters**: None (uses current session from state)
- **Returns**: 0 on success, 1 on error
- **Side Effects**: 
  - Updates session state to inactive
  - Archives session file with timestamp
  - Clears all session-related state values
- **Example**: 
  ```bash
  # Clean up current session
  cleanup_session
  ```
- **Learning**: Retrieves session info from state, archives to .aipm/state/sessions/

Note: The opinions-state.sh file is very large. The above covers the main utility, lock management, atomic operations, and computation functions. The file also contains many more specialized functions for state initialization, updates, and queries that follow similar patterns.

---

## opinions-loader.sh - Configuration Loading

### Default Management

#### `init_defaults()`
- **Purpose**: Initialize all default values
- **Parameters**: None
- **Returns**: Sets all AIPM_* default exports
- **Side Effects**: Exports ~160 default variables
- **Example**: 
  ```bash
  init_defaults  # Called automatically
  ```

#### `show_defaults()`
- **Purpose**: Display all default values grouped by section
- **Parameters**: None
- **Returns**: 0 always
- **Side Effects**: Outputs formatted defaults to stdout
- **Example**: 
  ```bash
  source opinions-loader.sh
  load_and_export_opinions --show-defaults
  ```

#### `generate_template_with_defaults()`
- **Purpose**: Generate YAML template with defaults
- **Parameters**: None
- **Returns**: 0 always
- **Side Effects**: Outputs complete YAML template
- **Example**: 
  ```bash
  load_and_export_opinions --generate-template > opinions.yaml
  ```

### YAML Parsing

#### `check_yq_installed()`
- **Purpose**: Verify yq is installed and version 4+
- **Parameters**: None
- **Returns**: Dies if not installed
- **Side Effects**: Warns if version < 4

#### `extract_yaml_value(path, yaml_file)`
- **Purpose**: Extract single value from YAML
- **Parameters**: 
  - path: Dot notation path (e.g., "workspace.type")
  - yaml_file: File path (optional, uses OPINIONS_FILE_PATH)
- **Returns**: Value or empty string
- **Example**: 
  ```bash
  type=$(extract_yaml_value "workspace.type")
  ```

#### `extract_yaml_array(path, yaml_file)`
- **Purpose**: Extract array as space-separated string
- **Parameters**: Same as extract_yaml_value
- **Returns**: Space-separated values
- **Example**: 
  ```bash
  categories=$(extract_yaml_array "memory.categories")
  ```

### Validation Functions

#### `validate_required_sections(yaml_file)`
- **Purpose**: Check required sections exist
- **Parameters**: YAML file path
- **Returns**: 0 if valid, 1 if missing sections

#### `validate_enum(value, field, valid_values...)`
- **Purpose**: Validate enumeration value
- **Parameters**: 
  - value: Value to check
  - field: Field name for error
  - valid_values: Allowed values
- **Returns**: 0 if valid, 1 if invalid
- **Example**: 
  ```bash
  validate_enum "$mode" "validation.mode" "strict" "relaxed" "gradual"
  ```

#### `validate_prefix_consistency(yaml_file)`
- **Purpose**: Validate prefix matches across sections
- **Parameters**: YAML file path
- **Returns**: 0 if consistent, 1 if mismatch
- **Learning**: branching.prefix must match memory.entityPrefix

#### `validate_branch_lifecycle_consistency(yaml_file)`
- **Purpose**: Check all branch types have lifecycle rules
- **Parameters**: YAML file path
- **Returns**: 0 always (warns on missing)

#### `validate_opinions(yaml_file)`
- **Purpose**: Main validation orchestrator
- **Parameters**: YAML file path
- **Returns**: 0 always (handles errors based on onError setting)

#### `load_opinions_file(yaml_path)`
- **Purpose**: Load and validate YAML file
- **Parameters**: YAML file path
- **Returns**: 0 on success
- **Side Effects**: Sets OPINIONS_FILE_PATH, OPINIONS_LOADED

### Export Functions

#### `export_workspace_section()`
- **Purpose**: Export workspace configuration
- **Parameters**: None
- **Returns**: Sets AIPM_WORKSPACE_* variables

#### `export_branching_section()`
- **Purpose**: Export branching configuration
- **Parameters**: None
- **Returns**: Sets AIPM_BRANCHING_* variables
- **Side Effects**: Computes AIPM_BRANCHING_MAINBRANCH

#### `export_naming_section()`
- **Purpose**: Export naming patterns
- **Parameters**: None
- **Returns**: Sets AIPM_NAMING_* variables

#### `export_lifecycle_section()`
- **Purpose**: Export lifecycle rules
- **Parameters**: None
- **Returns**: Sets AIPM_LIFECYCLE_* variables

#### `export_memory_section()`
- **Purpose**: Export memory configuration
- **Parameters**: None
- **Returns**: Sets AIPM_MEMORY_* variables

#### `export_team_section()`
- **Purpose**: Export team settings
- **Parameters**: None
- **Returns**: Sets AIPM_TEAM_* variables

#### `export_sessions_section()`
- **Purpose**: Export session settings
- **Parameters**: None
- **Returns**: Sets AIPM_SESSIONS_* variables

#### `export_validation_section()`
- **Purpose**: Export validation rules
- **Parameters**: None
- **Returns**: Sets AIPM_VALIDATION_* variables

#### `export_initialization_section()`
- **Purpose**: Export initialization settings
- **Parameters**: None
- **Returns**: Sets AIPM_INITIALIZATION_* variables

#### `export_defaults_section()`
- **Purpose**: Export default values
- **Parameters**: None
- **Returns**: Sets AIPM_DEFAULTS_* variables

#### `export_workflows_section()`
- **Purpose**: Export workflow configuration
- **Parameters**: None
- **Returns**: Sets AIPM_WORKFLOWS_* variables

#### `export_errorhandling_section()`
- **Purpose**: Export error handling settings
- **Parameters**: None
- **Returns**: Sets AIPM_ERRORHANDLING_* variables

#### `export_settings_section()`
- **Purpose**: Export framework settings
- **Parameters**: None
- **Returns**: Sets AIPM_SETTINGS_* variables

#### `export_metadata_section()`
- **Purpose**: Export metadata
- **Parameters**: None
- **Returns**: Sets AIPM_METADATA_* variables

#### `export_computed_values()`
- **Purpose**: Export derived values
- **Parameters**: None
- **Returns**: Sets AIPM_COMPUTED_* variables
- **Side Effects**: Computes file hash if file loaded

### Main Entry Point

#### `load_and_export_opinions(yaml_path, ...args)`
- **Purpose**: Main function to load configuration
- **Parameters**: 
  - yaml_path: Path to opinions.yaml
  - Additional flags: --defaults-only, --show-defaults, --generate-template
- **Returns**: 0 on success
- **Side Effects**: Loads and exports all configuration
- **Example**: 
  ```bash
  source opinions-loader.sh
  load_and_export_opinions
  ```

### Lookup Functions

#### `aipm_get_naming_pattern(branch_type)`
- **Purpose**: Get naming pattern for branch type
- **Parameters**: Branch type (e.g., "feature")
- **Returns**: Pattern string
- **Example**: 
  ```bash
  pattern=$(aipm_get_naming_pattern "feature")
  ```

#### `aipm_get_lifecycle_rule(branch_type, rule)`
- **Purpose**: Get lifecycle rule value
- **Parameters**: 
  - branch_type: Type of branch
  - rule: Rule name (deleteAfterMerge, daysToKeep)
- **Returns**: Rule value

#### `aipm_get_workflow(section, field)`
- **Purpose**: Get workflow setting
- **Parameters**: 
  - section: Workflow section
  - field: Field name
- **Returns**: Setting value

#### `aipm_is_protected_branch(branch)`
- **Purpose**: Check if branch is protected
- **Parameters**: Branch name
- **Returns**: "true" or "false" string, exit code 0/1

#### `aipm_get_branch_source(branch_type)`
- **Purpose**: Get source branch for type
- **Parameters**: Branch type
- **Returns**: Source branch pattern

#### `aipm_get_branch_target(branch_type)`
- **Purpose**: Get target branch for type
- **Parameters**: Branch type
- **Returns**: Target branch pattern

### Convenience Functions

#### `get_main_branch()`
- **Purpose**: Get main branch name
- **Parameters**: None
- **Returns**: Main branch name
- **Example**: 
  ```bash
  main=$(get_main_branch)
  ```

#### `get_branch_prefix()`
- **Purpose**: Get workspace prefix
- **Parameters**: None
- **Returns**: Branch prefix

#### `opinions_loaded()`
- **Purpose**: Check if opinions are loaded
- **Parameters**: None
- **Returns**: 0 if loaded, 1 if not

#### `ensure_opinions_loaded()`
- **Purpose**: Load opinions if not already loaded
- **Parameters**: None
- **Returns**: 0 on success
- **Side Effects**: Calls load_and_export_opinions if needed

---

## sync-memory.sh - Memory Synchronization

### Main Functions

#### `find_memory_source()`
- **Purpose**: Locate memory.json in npm cache
- **Parameters**: None
- **Returns**: 0 if found, 1 if not
- **Outputs**: Path to memory.json on stdout
- **Side Effects**: Shows spinner in visual mode
- **Learning**: Informational messages go to stderr, only path to stdout

#### `validate_memory_file(file)`
- **Purpose**: Validate memory.json file
- **Parameters**: File path
- **Returns**: 0 if valid, 1 if invalid
- **Learning**: Empty (0 byte) file is valid initial state

#### `create_symlink(source, target)`
- **Purpose**: Create or update symlink
- **Parameters**: 
  - source: Source file path
  - target: Target symlink path
- **Returns**: 0 on success, 1 on error
- **Example**: 
  ```bash
  create_symlink "$npm_memory" ".claude/memory.json"
  ```

#### `main(...args)`
- **Purpose**: Main execution function
- **Parameters**: Command line arguments
- **Supported Args**: 
  - --force: Force recreate symlink
  - --help/-h: Show usage
- **Returns**: Various exit codes (0-3)
- **Side Effects**: Creates symlink, may install MCP server
- **Example**: 
  ```bash
  ./sync-memory.sh --force
  ```

---

## Key Learning Points Summary

1. **Atomic Operations**: All file operations use temp file + atomic move pattern to prevent corruption
2. **Cross-Platform**: Different commands for macOS vs Linux (stat, readlink, timeout)
3. **Error Handling**: Consistent error codes and structured output across modules
4. **State Management**: Lock-based concurrency control with rollback support
5. **Memory Safety**: Empty files are valid, streaming for large files, prefix validation
6. **Git Integration**: All git operations go through version-control.sh - NO DIRECT CALLS
7. **Visual Feedback**: Context-aware output (terminal vs CI vs pipe vs Claude Code)
8. **Configuration**: Everything driven by opinions.yaml with sensible defaults

This inventory provides a complete reference for all available functions across the AIPM module system. Each function is documented with its purpose, parameters, return values, side effects, examples, and key learnings.