#!/opt/homebrew/bin/bash
#
# shell-formatting.sh - Hardened formatting utilities for AIPM scripts
#
# This script provides:
# - Consistent color definitions with terminal detection
# - Pretty print functions with proper error handling
# - Progress indicators and spinners
# - Platform-aware utilities (macOS, Linux, WSL)
# - Unicode support with fallbacks
# - Logging utilities
# - Command execution with timeout and retry
# - REPL environment compatibility
# - Single source of truth for all formatting
#
# USAGE:
#   source "$SCRIPT_DIR/shell-formatting.sh"
#
# BEST PRACTICES:
# 1. Always use the provided functions instead of raw ANSI codes
# 2. Use safe_execute for commands that might timeout
# 3. Use output_* functions for consistent messaging
# 4. Check EXECUTION_CONTEXT before using visual elements
# 5. Use fprint/fprintln for colored output with auto-reset
#
# PLATFORM COMPATIBILITY:
# - macOS: Requires coreutils for timeout (brew install coreutils)
# - Linux: Full support out of the box
# - WSL: Full support, detected as Linux
# - CI/CD: Automatic detection, ASCII-only output
# - Claude Code: Special handling for REPL environment
#
# ENVIRONMENT VARIABLES:
# - AIPM_COLOR: Override color detection (true/false)
# - AIPM_UNICODE: Override Unicode detection (true/false)
# - AIPM_VISUAL: Override visual mode (true/false)
# - AIPM_OUTPUT_MODE: Set output mode (visual/minimal/structured/raw/log)
# - AIPM_LOG_ONLY: Force log-only mode
# - DEBUG: Enable debug output
# - LOG_FILE: Path to log file
# - CLAUDE_CODE: Set when running in Claude Code
#
# LEARNING LOG:
# - 2025-06-20: Initial design with multi-context support
# - 2025-06-20: Added printf instead of echo -e for portability
# - 2025-06-20: Added timeout handling for REPL environments
# - 2025-06-20: Created internal functions for single source of truth
# - 2025-06-20: Added cross-platform timeout detection
# - 2025-06-20: Performance optimizations:
#   * Cached uname result to avoid subprocess calls
#   * Direct ANSI codes for static colors (faster than functions)
#   * Optimized Unicode detection (check LANG first)
#   * Cached tput existence check
#   * Combined printf format strings
#   * Pre-formatted spinner sequences
#
# Created by: AIPM Framework
# License: Apache 2.0

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "This script should be sourced, not executed directly\n"
    printf "Usage: source %s\n" "$0"
    exit 1
fi

# ============================================================================
# PLATFORM DETECTION
# ============================================================================

# LEARNING: Platform detection is critical for portable scripts
# Different platforms have different commands (stat, sed, etc.)
# Cache uname result to avoid multiple subprocess calls
# Discovered: 2025-06-20 during initial design
# Optimized: 2025-06-20 for performance

# Cache uname result
UNAME_S="${UNAME_S:-$(uname -s)}"

detect_platform() {
    case "$UNAME_S" in
        Darwin*)    PLATFORM="macos";;
        Linux*)     
            # LEARNING: WSL detection requires checking /proc/version
            # WSL1 and WSL2 both contain "microsoft" in version string
            if [[ -f /proc/version ]] && grep -qi microsoft /proc/version; then
                PLATFORM="wsl"
            else
                PLATFORM="linux"
            fi
            ;;
        CYGWIN*)    PLATFORM="cygwin";;
        MINGW*)     PLATFORM="mingw";;
        *)          PLATFORM="unknown";;
    esac
    export PLATFORM
}
detect_platform

# ============================================================================
# ENVIRONMENT DETECTION
# ============================================================================

# LEARNING: Scripts need to adapt to different execution contexts:
# - Interactive terminal (visual mode)
# - CI/CD pipelines (structured output)
# - Pipes (data processing)
# - Claude Code REPL (minimal formatting)
# - Log files (timestamped entries)
# Discovered: 2025-06-20 from user requirements

# Detect execution context
# LEARNING: Must handle socket/REPL issues gracefully
# Check terminal capabilities defensively to avoid errors
# Fixed: 2025-06-20 for REPL compatibility
detect_context() {
    # Check for CI/CD environments
    if [[ -n "${CI:-}" ]] || [[ -n "${CONTINUOUS_INTEGRATION:-}" ]] || 
       [[ -n "${GITHUB_ACTIONS:-}" ]] || [[ -n "${GITLAB_CI:-}" ]] ||
       [[ -n "${JENKINS_URL:-}" ]] || [[ -n "${TRAVIS:-}" ]]; then
        EXECUTION_CONTEXT="ci"
        return
    fi
    
    # Check if we're in Claude Code
    # LEARNING: Claude Code REPL detection is tricky, check multiple indicators
    # Fixed: 2025-06-20 for better Claude Code detection
    if [[ -n "${CLAUDE_CODE:-}" ]] || [[ "$TERM_PROGRAM" == "claude" ]] || 
       [[ "${USER:-}" == "root" && -f "/.dockerenv" ]] || 
       [[ "${ANTHROPIC_RUNTIME:-}" == "true" ]]; then
        EXECUTION_CONTEXT="claude"
        return
    fi
    
    # Check if output is piped
    # LEARNING: Use multiple checks for robustness
    # -t 1 can fail in some environments, so we check multiple conditions
    # Fixed: 2025-06-20 for socket/REPL issues
    # LEARNING: Suppress all stderr from terminal checks to avoid socket errors
    # Fixed: 2025-06-20 for Claude Code REPL
    { [[ ! -t 1 ]] || [[ -p /dev/stdout ]] || [[ ! -t 0 ]]; } 2>/dev/null && {
        EXECUTION_CONTEXT="pipe"
        return
    }
    
    # Check if we're logging only
    if [[ -n "${AIPM_LOG_ONLY:-}" ]]; then
        EXECUTION_CONTEXT="log"
        return
    fi
    
    # Default to interactive terminal
    EXECUTION_CONTEXT="terminal"
}
detect_context

# Set output modes based on context
case "$EXECUTION_CONTEXT" in
    ci)
        # CI/CD: Structured output, no colors, ASCII only
        INTERACTIVE=false
        COLOR_SUPPORT=false
        UNICODE_SUPPORT=false
        VISUAL_MODE=false
        OUTPUT_MODE="structured"
        ;;
    claude)
        # Claude Code: Enhanced support with careful terminal handling
        # LEARNING: Claude Code supports colors and progress bars
        # but needs careful handling of terminal controls
        # Updated: 2025-06-20 for better Claude Code experience
        INTERACTIVE=true
        COLOR_SUPPORT=true
        UNICODE_SUPPORT=true
        VISUAL_MODE=true  # Enable visual mode for Claude Code
        OUTPUT_MODE="visual"
        ;;
    pipe)
        # Piped: Raw data, no formatting
        INTERACTIVE=false
        COLOR_SUPPORT=false
        UNICODE_SUPPORT=false
        VISUAL_MODE=false
        OUTPUT_MODE="raw"
        ;;
    log)
        # Logging only: No visual elements
        INTERACTIVE=false
        COLOR_SUPPORT=false
        UNICODE_SUPPORT=false
        VISUAL_MODE=false
        OUTPUT_MODE="log"
        ;;
    terminal)
        # Interactive terminal: Full features
        INTERACTIVE=true
        VISUAL_MODE=true
        OUTPUT_MODE="visual"
        
        # Check actual terminal capabilities
        # LEARNING: Cache tput existence check to avoid repeated lookups
        # Optimized: 2025-06-20 for performance
        if [[ "${TERM:-dumb}" != "dumb" ]]; then
            if [[ -z "${TPUT_EXISTS+x}" ]]; then
                command -v tput >/dev/null 2>&1 && TPUT_EXISTS=true || TPUT_EXISTS=false
            fi
            
            if [[ "$TPUT_EXISTS" == true ]]; then
                # LEARNING: Wrap tput calls to handle socket errors gracefully
                # Fixed: 2025-06-20 for REPL robustness
                COLORS=$({ tput colors || printf "0"; } 2>/dev/null)
                COLOR_SUPPORT=$([[ $COLORS -ge 8 ]] && printf "true" || printf "false")
            else
                COLOR_SUPPORT=false
            fi
        else
            COLOR_SUPPORT=false
        fi
        
        # Check Unicode support
        # LEARNING: Optimize Unicode detection - check LANG first
        # Optimized: 2025-06-20 for performance
        if [[ "${LANG:-}" =~ [Uu][Tt][Ff] ]]; then
            UNICODE_SUPPORT=true
        elif [[ "${LC_ALL:-}" =~ [Uu][Tt][Ff] ]]; then
            UNICODE_SUPPORT=true
        else
            # Fallback: assume no Unicode
            UNICODE_SUPPORT=false
        fi
        ;;
esac

# Allow override via environment variables
COLOR_SUPPORT="${AIPM_COLOR:-$COLOR_SUPPORT}"
UNICODE_SUPPORT="${AIPM_UNICODE:-$UNICODE_SUPPORT}"
VISUAL_MODE="${AIPM_VISUAL:-$VISUAL_MODE}"
OUTPUT_MODE="${AIPM_OUTPUT_MODE:-$OUTPUT_MODE}"

# LEARNING: Special handling for demo/testing mode
# When FORCE_PROGRESS is set, assume we want full features
# Fixed: 2025-06-20 for demo and testing purposes
if [[ "${FORCE_PROGRESS:-}" == "true" ]]; then
    # Force interactive features for demos
    INTERACTIVE=true
    VISUAL_MODE=true
    # Keep existing color/unicode settings unless explicitly disabled
    [[ "$COLOR_SUPPORT" != "false" ]] && COLOR_SUPPORT=true
    [[ "$UNICODE_SUPPORT" != "false" ]] && UNICODE_SUPPORT=true
    # Set output mode if not already set
    [[ "$OUTPUT_MODE" == "raw" ]] && OUTPUT_MODE="visual"
fi

# ============================================================================
# INTERNAL COLOR FUNCTIONS
# ============================================================================

# LEARNING: Creating internal functions for colors provides:
# - Single source of truth for ANSI codes
# - Easy to update/maintain color schemes
# - Context-aware color application
# - Testable color logic
# Discovered: 2025-06-20 from robust usage requirements

# Set foreground color
set_color() {
    local color_name="${1:-reset}"
    local bold="${2:-false}"
    
    if [[ "$COLOR_SUPPORT" != true ]]; then
        return
    fi
    
    case "${color_name,,}" in
        black)   printf '\033[0;30m';;
        red)     printf '\033[0;31m';;
        green)   printf '\033[0;32m';;
        yellow)  printf '\033[0;33m';;
        blue)    printf '\033[0;34m';;
        magenta) printf '\033[0;35m';;
        cyan)    printf '\033[0;36m';;
        white)   printf '\033[0;37m';;
        reset|nc) printf '\033[0m';;
        *)       printf '\033[0m';;
    esac
    
    # Apply bold if requested
    if [[ "$bold" == true ]] && [[ "${color_name,,}" != "reset" ]]; then
        printf '\033[1m'
    fi
}

# Set background color
set_bg_color() {
    local color_name="${1:-reset}"
    
    if [[ "$COLOR_SUPPORT" != true ]]; then
        return
    fi
    
    case "${color_name,,}" in
        black)   printf '\033[40m';;
        red)     printf '\033[41m';;
        green)   printf '\033[42m';;
        yellow)  printf '\033[43m';;
        blue)    printf '\033[44m';;
        magenta) printf '\033[45m';;
        cyan)    printf '\033[46m';;
        white)   printf '\033[47m';;
        reset|nc) printf '\033[49m';;
        *)       printf '\033[49m';;
    esac
}

# Apply text formatting
set_format() {
    local format_name="${1:-none}"
    
    if [[ "$COLOR_SUPPORT" != true ]]; then
        return
    fi
    
    case "${format_name,,}" in
        bold)          printf '\033[1m';;
        dim)           printf '\033[2m';;
        italic)        printf '\033[3m';;
        underline)     printf '\033[4m';;
        blink)         printf '\033[5m';;
        reverse)       printf '\033[7m';;
        strikethrough) printf '\033[9m';;
        reset|none)    printf '\033[0m';;
        *)             ;;
    esac
}

# Reset all formatting
reset_format() {
    if [[ "$COLOR_SUPPORT" == true ]]; then
        printf '\033[0m'
    fi
}

# Get symbol with fallback
get_symbol() {
    local symbol_name="${1:-dot}"
    
    if [[ "$UNICODE_SUPPORT" == true ]]; then
        case "${symbol_name,,}" in
            check|success)  printf '✓';;
            cross|error)    printf '✗';;
            warning|warn)   printf '⚠';;
            info)           printf 'ℹ';;
            dot|bullet)     printf '•';;
            arrow|right)    printf '→';;
            triangle|play)  printf '▶';;
            box_tl)         printf '╔';;
            box_tr)         printf '╗';;
            box_bl)         printf '╚';;
            box_br)         printf '╝';;
            box_h)          printf '═';;
            box_v)          printf '║';;
            line_h)         printf '─';;
            line_v)         printf '│';;
            *)              printf '*';;
        esac
    else
        # ASCII fallbacks
        case "${symbol_name,,}" in
            check|success)  printf '[OK]';;
            cross|error)    printf '[X]';;
            warning|warn)   printf '[!]';;
            info)           printf '[i]';;
            dot|bullet)     printf '*';;
            arrow|right)    printf '->';;
            triangle|play)  printf '>';;
            box_tl|box_tr|box_bl|box_br) printf '+';;
            box_h)          printf '=';;
            box_v)          printf '|';;
            line_h)         printf '-';;
            line_v)         printf '|';;
            *)              printf '*';;
        esac
    fi
}

# Formatted print with automatic reset
# Usage: fprint "color" "text" [bold]
fprint() {
    local color="${1:-reset}"
    local text="${2:-}"
    local bold="${3:-false}"
    
    set_color "$color" "$bold"
    printf "%s" "$text"
    reset_format
}

# Formatted print line with automatic reset
# Usage: fprintln "color" "text" [bold]
fprintln() {
    local color="${1:-reset}"
    local text="${2:-}"
    local bold="${3:-false}"
    
    fprint "$color" "$text" "$bold"
    printf "\n"
}

# ============================================================================
# COLOR DEFINITIONS (USING INTERNAL FUNCTIONS)
# ============================================================================

# LEARNING: Need to initialize colors in a function so we can re-run
# after environment overrides are applied
# Fixed: 2025-06-20 for proper demo support
init_colors() {
    # Define colors only if supported
    # LEARNING: Direct ANSI codes are faster than function calls for static colors
    # Optimized: 2025-06-20 for performance
    if [[ "$COLOR_SUPPORT" == true ]]; then
    # Basic colors (direct ANSI codes)
    export BLACK=$'\033[0;30m'
    export RED=$'\033[0;31m'
    export GREEN=$'\033[0;32m'
    export YELLOW=$'\033[0;33m'
    export BLUE=$'\033[0;34m'
    export MAGENTA=$'\033[0;35m'
    export CYAN=$'\033[0;36m'
    export WHITE=$'\033[0;37m'
    
    # Bold colors
    export BOLD_BLACK=$'\033[1;30m'
    export BOLD_RED=$'\033[1;31m'
    export BOLD_GREEN=$'\033[1;32m'
    export BOLD_YELLOW=$'\033[1;33m'
    export BOLD_BLUE=$'\033[1;34m'
    export BOLD_MAGENTA=$'\033[1;35m'
    export BOLD_CYAN=$'\033[1;36m'
    export BOLD_WHITE=$'\033[1;37m'
    
    # Background colors
    export BG_BLACK=$'\033[40m'
    export BG_RED=$'\033[41m'
    export BG_GREEN=$'\033[42m'
    export BG_YELLOW=$'\033[43m'
    export BG_BLUE=$'\033[44m'
    export BG_MAGENTA=$'\033[45m'
    export BG_CYAN=$'\033[46m'
    export BG_WHITE=$'\033[47m'
    
    # Special effects
    export DIM=$'\033[2m'
    export ITALIC=$'\033[3m'
    export UNDERLINE=$'\033[4m'
    export BLINK=$'\033[5m'
    export REVERSE=$'\033[7m'
    export STRIKETHROUGH=$'\033[9m'
    
    # Reset
    export NC=$'\033[0m'
    export RESET=$'\033[0m'
else
    # No color support - define empty strings
    export BLACK='' RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' WHITE=''
    export BOLD_BLACK='' BOLD_RED='' BOLD_GREEN='' BOLD_YELLOW=''
    export BOLD_BLUE='' BOLD_MAGENTA='' BOLD_CYAN='' BOLD_WHITE=''
    export BG_BLACK='' BG_RED='' BG_GREEN='' BG_YELLOW=''
    export BG_BLUE='' BG_MAGENTA='' BG_CYAN='' BG_WHITE=''
    export DIM='' ITALIC='' UNDERLINE='' BLINK='' REVERSE='' STRIKETHROUGH=''
    export NC='' RESET=''
    fi
}

# Initialize colors with detected settings
init_colors

# ============================================================================
# UNICODE CHARACTERS WITH FALLBACKS (USING INTERNAL FUNCTIONS)
# ============================================================================

# LEARNING: Need to initialize symbols in a function so we can re-run
# after environment overrides are applied
# Fixed: 2025-06-20 for proper demo support
init_symbols() {
    # LEARNING: Always provide ASCII fallbacks for Unicode characters
    # Not all terminals support Unicode, especially in CI/CD environments
    # Discovered: 2025-06-20 during compatibility planning
    
    if [[ "$UNICODE_SUPPORT" == true ]]; then
    # Unicode box drawing
    export BOX_TL='╔'  # Top left
    export BOX_TR='╗'  # Top right
    export BOX_BL='╚'  # Bottom left
    export BOX_BR='╝'  # Bottom right
    export BOX_H='═'   # Horizontal
    export BOX_V='║'   # Vertical
    export BOX_T='╦'   # T junction
    export BOX_B='╩'   # Bottom junction
    export BOX_L='╠'   # Left junction
    export BOX_R='╣'   # Right junction
    export BOX_X='╬'   # Cross
    
    # Simple lines
    export LINE_H='─'  # Horizontal line
    export LINE_V='│'  # Vertical line
    
    # Symbols (direct values for performance)
    export CHECK='✓'
    export CROSS='✗'
    export WARNING='⚠'
    export INFO='ℹ'
    export DOT='•'
    export ARROW='→'
    export TRIANGLE='▶'
else
    # ASCII fallbacks
    export BOX_TL='+'
    export BOX_TR='+'
    export BOX_BL='+'
    export BOX_BR='+'
    export BOX_H='='
    export BOX_V='|'
    export BOX_T='+'
    export BOX_B='+'
    export BOX_L='+'
    export BOX_R='+'
    export BOX_X='+'
    
    export LINE_H='-'
    export LINE_V='|'
    
    # Symbols (ASCII fallbacks)
    export CHECK='[OK]'
    export CROSS='[X]'
    export WARNING='[!]'
    export INFO='[i]'
    export DOT='*'
    export ARROW='=>'
    export TRIANGLE='>'
    fi
}

# Initialize symbols with detected settings
init_symbols

# LEARNING: If FORCE_PROGRESS was set, reinitialize with new settings
# This must happen AFTER the functions are defined
# Fixed: 2025-06-20 for proper demo support
if [[ "${FORCE_PROGRESS:-}" == "true" ]]; then
    init_colors
    init_symbols
fi

# ============================================================================
# EARLY DEBUG FUNCTION
# ============================================================================

# LEARNING: Debug function needs to be defined early since it's used
# throughout the script, even before the main message functions
# Discovered: 2025-06-20 during test execution

# Minimal debug function for early use
debug() {
    if [[ -n "${DEBUG:-}" ]]; then
        printf "DEBUG: %s\n" "$*" >&2
    fi
}

# ============================================================================
# COMMAND EXECUTION WITH TIMEOUT HANDLING
# ============================================================================

# LEARNING: REPL environments (like Claude Code) often have timeout issues
# We need robust command execution with proper timeout handling and retries
# Also handle different timeout commands across platforms
# Discovered: 2025-06-20 from REPL timeout issues

# Detect available timeout command
detect_timeout_command() {
    # LEARNING: Suppress all errors during command detection for REPL safety
    # Fixed: 2025-06-20 for socket compatibility
    # Check for GNU timeout (Linux, WSL, some macOS)
    if { command -v timeout; } >/dev/null 2>&1; then
        TIMEOUT_CMD="timeout"
        TIMEOUT_STYLE="gnu"
    # Check for gtimeout (macOS with coreutils)
    elif { command -v gtimeout; } >/dev/null 2>&1; then
        TIMEOUT_CMD="gtimeout"
        TIMEOUT_STYLE="gnu"
    else
        TIMEOUT_CMD=""
        TIMEOUT_STYLE="none"
        
        # LEARNING: macOS doesn't have timeout by default
        # Users need to install coreutils: brew install coreutils
        # Discovered: 2025-06-20 during cross-platform testing
        # LEARNING: Only show debug message if DEBUG is set
        # to avoid cluttering output in production
        # Fixed: 2025-06-20 for cleaner output
        if [[ -n "${DEBUG:-}" ]] && [[ "$PLATFORM" == "macos" ]]; then
            debug "No timeout command found. Install with: brew install coreutils"
        fi
    fi
    
    export TIMEOUT_CMD
    export TIMEOUT_STYLE
}
detect_timeout_command

# Execute command with timeout and retry logic
# Usage: safe_execute "command" [timeout_seconds] [max_retries]
safe_execute() {
    local cmd="${1:-}"
    local timeout_sec="${2:-30}"
    local max_retries="${3:-3}"
    local retry_count=0
    local exit_code=0
    
    # LEARNING: Empty commands should fail gracefully
    # Discovered: 2025-06-20 during error case testing
    if [[ -z "$cmd" ]]; then
        output_error 1 "No command provided to safe_execute"
        return 1
    fi
    
    while [[ $retry_count -lt $max_retries ]]; do
        # Clear any previous errors
        exit_code=0
        
        # Execute based on available timeout command
        if [[ -n "$TIMEOUT_CMD" ]]; then
            # Use timeout command
            if [[ "$TIMEOUT_STYLE" == "gnu" ]]; then
                # GNU timeout syntax
                $TIMEOUT_CMD "$timeout_sec" bash -c "$cmd"
                exit_code=$?
            fi
        else
            # No timeout command - use background job with kill
            # LEARNING: Fallback timeout implementation for systems without timeout command
            # This is less reliable but works on all platforms
            # Discovered: 2025-06-20 for macOS compatibility
            (
                eval "$cmd" &
                local cmd_pid=$!
                local count=0
                
                while [[ $count -lt $timeout_sec ]]; do
                    if ! kill -0 $cmd_pid 2>/dev/null; then
                        wait $cmd_pid
                        exit $?
                    fi
                    sleep 1
                    ((count++))
                done
                
                # Timeout reached
                kill -TERM $cmd_pid 2>/dev/null
                sleep 1
                kill -KILL $cmd_pid 2>/dev/null
                exit 124  # GNU timeout exit code
            )
            exit_code=$?
        fi
        
        # Check exit code
        case $exit_code in
            0)
                # Success
                return 0
                ;;
            124)
                # Timeout
                ((retry_count++))
                if [[ $retry_count -lt $max_retries ]]; then
                    output_warn 0 "Command timed out after ${timeout_sec}s, retrying ($retry_count/$max_retries)..."
                    sleep 2  # Brief pause before retry
                else
                    output_error 124 "Command timed out after $max_retries attempts" "$cmd"
                    return 124
                fi
                ;;
            *)
                # Other error
                output_error $exit_code "Command failed with exit code $exit_code" "$cmd"
                return $exit_code
                ;;
        esac
    done
    
    return $exit_code
}

# Execute command with spinner and timeout
# Usage: execute_with_spinner "message" "command" [timeout]
execute_with_spinner() {
    local message="${1:-Working...}"
    local cmd="${2:-}"
    local timeout="${3:-30}"
    
    if [[ "$INTERACTIVE" == true ]] && [[ "$VISUAL_MODE" == true ]]; then
        start_spinner "$message"
        safe_execute "$cmd" "$timeout"
        local exit_code=$?
        stop_spinner
        
        if [[ $exit_code -eq 0 ]]; then
            success "$message - Done"
        else
            error "$message - Failed (exit code: $exit_code)"
        fi
        
        return $exit_code
    else
        # Non-interactive mode
        output_info "$message"
        safe_execute "$cmd" "$timeout"
    fi
}

# ============================================================================
# ROBUST ERROR HANDLING
# ============================================================================

# LEARNING: Consistent error handling across all execution contexts
# Including REPL environments which may have special requirements
# Discovered: 2025-06-20 from REPL integration needs

# Set error trap with context
set_error_trap() {
    local context="${1:-script}"
    
    trap 'handle_error $? "$BASH_COMMAND" $LINENO' ERR
    
    # LEARNING: Some REPL environments don't handle EXIT traps well
    # Only set EXIT trap in non-REPL contexts
    # Discovered: 2025-06-20 from Claude Code testing
    if [[ "$EXECUTION_CONTEXT" != "claude" ]]; then
        trap 'handle_exit $?' EXIT
    fi
    
    # Always cleanup spinners
    trap cleanup_spinner INT TERM
}

# Handle errors with context
handle_error() {
    local exit_code=$1
    local cmd="$2"
    local line=$3
    
    # Skip if error already handled
    [[ -n "${ERROR_HANDLED:-}" ]] && return
    export ERROR_HANDLED=true
    
    # Clean up any spinners
    cleanup_spinner
    
    # Output based on context
    case "$OUTPUT_MODE" in
        structured)
            output "ERROR" "$exit_code" "Command failed at line $line" "$cmd"
            ;;
        minimal)
            printf "[ERROR] Line %d: %s (exit %d)\\n" "$line" "$cmd" "$exit_code" >&2
            ;;
        *)
            error "Command failed at line $line: $cmd (exit code: $exit_code)"
            
            # Show stack trace if DEBUG
            if [[ -n "${DEBUG:-}" ]]; then
                printf "%sStack trace:%s\\n" "$DIM" "$NC" >&2
                local frame=0
                while caller $frame >&2; do
                    ((frame++))
                done
            fi
            ;;
    esac
}

# Handle script exit
handle_exit() {
    local exit_code=$1
    
    # Only show exit message in debug mode
    if [[ -n "${DEBUG:-}" ]] && [[ $exit_code -ne 0 ]] && [[ -z "${ERROR_HANDLED:-}" ]]; then
        debug "Script exited with code: $exit_code"
    fi
    
    # Cleanup
    cleanup_spinner
    
    # Reset error handling flag
    unset ERROR_HANDLED
}

# ============================================================================
# MESSAGE FUNCTIONS
# ============================================================================

# LEARNING: Use printf instead of echo -e for portability
# echo -e is not POSIX and behaves differently across shells/platforms
# printf is consistent and more reliable
# Discovered: 2025-06-20 from portability requirements

# LEARNING: Always send diagnostic messages to stderr
# This allows proper separation of output and errors
# Discovered: 2025-06-20 from sync-memory.sh experience

# Print error message
# LEARNING: Combine format strings for fewer printf calls
# Optimized: 2025-06-20 for performance
# LEARNING: Don't duplicate "ERROR:" text when using error symbol
# The symbol itself conveys the meaning, avoid redundancy
# Fixed: 2025-06-20 during comprehensive testing
# LEARNING: All message functions must have EXACTLY the same spacing
# format for consistent alignment. Using single space after symbol.
# Fixed: 2025-06-20 for alignment consistency
error() {
    printf "%b%s %s%b\n" "$BOLD_RED" "$CROSS" "$*" "$NC" >&2
}

# Print warning message  
# LEARNING: Don't duplicate "WARNING:" text when using warning symbol
# The symbol itself conveys the meaning, avoid redundancy
# Fixed: 2025-06-20 during comprehensive testing
# LEARNING: Consistent single space after symbol for alignment
# Fixed: 2025-06-20 for alignment consistency
warn() {
    printf "%b%s %s%b\n" "$YELLOW" "$WARNING" "$*" "$NC" >&2
}

# Print success message
# LEARNING: Consistent single space after symbol for alignment
# Fixed: 2025-06-20 for alignment consistency
success() {
    printf "%b%s %s%b\n" "$GREEN" "$CHECK" "$*" "$NC"
}

# Print info message
# LEARNING: Keep consistent spacing - single space after symbol
# Fixed: 2025-06-20 for consistency
info() {
    printf "%b%s %s%b\n" "$BLUE" "$INFO" "$*" "$NC"
}

# Print debug message (only if DEBUG is set)
# This is a more complete version than the early one
debug() {
    if [[ -n "${DEBUG:-}" ]]; then
        printf "%b%bDEBUG: %s%b\n" "$DIM" "$MAGENTA" "$*" "$NC" >&2
    fi
}

# Print a step message
# LEARNING: Consistent single space after symbol for alignment
# Fixed: 2025-06-20 for alignment consistency
step() {
    printf "%b%s %s%b\n" "$CYAN" "$ARROW" "$*" "$NC"
}

# Print section header
# LEARNING: Use a single printf with repeat for performance
# Optimized: 2025-06-20
section() {
    printf "\n%b%s%b\n" "$BOLD_WHITE" "$*" "$NC"
    printf "%b%*s%b\n" "$CYAN" 50 "" "$NC" | tr ' ' '─'
}

# ============================================================================
# STRUCTURED OUTPUT FUNCTIONS
# ============================================================================

# LEARNING: Different contexts need different output formats
# - CI/CD: Structured logs with codes
# - Pipes: Raw data for processing
# - Logs: Timestamped entries
# - Visual: Pretty formatted for humans
# Discovered: 2025-06-20 from multi-context requirements

# Output with context awareness
output() {
    local level="${1:-INFO}"
    local code="${2:-0}"
    local message="${3:-}"
    local details="${4:-}"
    
    case "$OUTPUT_MODE" in
        structured)
            # CI/CD format: LEVEL|CODE|MESSAGE|DETAILS
            printf "%s|%s|%s|%s\n" "$level" "$code" "$message" "$details"
            ;;
        raw)
            # Pipe format: Just the message
            printf "%s\n" "$message"
            ;;
        log)
            # Log format: Timestamp and structured data
            printf "[%s] [%s] [%03d] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$code" "$message"
            [[ -n "$details" ]] && printf "  Details: %s\n" "$details"
            ;;
        minimal)
            # Claude Code format: Simple prefix
            case "$level" in
                ERROR)   printf "[ERROR] %s\n" "$message" >&2;;
                WARN)    printf "[WARN] %s\n" "$message" >&2;;
                SUCCESS) printf "[OK] %s\n" "$message";;
                INFO)    printf "[INFO] %s\n" "$message";;
                DEBUG)   [[ -n "${DEBUG:-}" ]] && printf "[DEBUG] %s\n" "$message" >&2;;
                *)       printf "%s\n" "$message";;
            esac
            ;;
        visual|*)
            # Visual format: Full colors and symbols
            case "$level" in
                ERROR)   error "$message";;
                WARN)    warn "$message";;
                SUCCESS) success "$message";;
                INFO)    info "$message";;
                DEBUG)   debug "$message";;
                *)       printf "%s\n" "$message";;
            esac
            ;;
    esac
    
    # Return the code for script flow control
    return "$code"
}

# Standardized output functions with codes
output_error() {
    local code="${1:-1}"
    local message="$2"
    local details="${3:-}"
    output "ERROR" "$code" "$message" "$details"
    return "$code"
}

output_warn() {
    local code="${1:-0}"
    local message="$2"
    local details="${3:-}"
    output "WARN" "$code" "$message" "$details"
}

output_success() {
    local message="$1"
    local details="${2:-}"
    output "SUCCESS" "0" "$message" "$details"
}

output_info() {
    local message="$1"
    local details="${2:-}"
    output "INFO" "0" "$message" "$details"
}

output_debug() {
    local message="$1"
    local details="${2:-}"
    [[ -n "${DEBUG:-}" ]] && output "DEBUG" "0" "$message" "$details"
}

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

# LEARNING: Structured logging helps with debugging and automation
# Include timestamp and level for better tracking
# Discovered: 2025-06-20 during design phase

# Initialize log file if LOG_FILE is set
init_log() {
    if [[ -n "${LOG_FILE:-}" ]]; then
        {
            printf "=== AIPM Session Log ===\n"
            printf "Started: %s\n" "$(date)"
            printf "Platform: %s\n" "$PLATFORM"
            printf "Terminal: %s\n" "${TERM:-unknown}"
            printf "Context: %s\n" "$EXECUTION_CONTEXT"
            printf "Output Mode: %s\n" "$OUTPUT_MODE"
            printf "====================\n\n"
        } > "$LOG_FILE"
    fi
}

# Log a message to file and optionally to screen
log() {
    local level="${1:-INFO}"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log to file if enabled
    if [[ -n "${LOG_FILE:-}" ]]; then
        printf "[%s] [%s] %s\n" "$timestamp" "$level" "$message" >> "$LOG_FILE"
    fi
    
    # Also display based on output mode
    output "$level" "0" "$message"
}

# ============================================================================
# BOX DRAWING FUNCTIONS
# ============================================================================

# LEARNING: Visual elements should only appear in visual mode
# Other contexts need structured or minimal output
# Discovered: 2025-06-20 from context requirements

# Draw a box with title (context-aware)
# Usage: draw_box "Title" [width]
# LEARNING: Box drawing needs precise width calculations
# The width parameter is the INNER width, not including borders
# Fixed: 2025-06-20 for correct padding and alignment
draw_box() {
    local title="${1:-}"
    local width="${2:-50}"
    
    # Only draw boxes in visual mode
    if [[ "$VISUAL_MODE" != true ]]; then
        # In non-visual modes, just output the title
        [[ -n "$title" ]] && output_info "$title"
        return
    fi
    
    local title_len=${#title}
    # LEARNING: Account for spaces around title when calculating padding
    # Title format is " Title " (with spaces), so add 2 to length
    local title_with_spaces_len=$((title_len + 2))
    local left_padding=$(( (width - title_with_spaces_len) / 2 ))
    local right_padding=$(( width - left_padding - title_with_spaces_len ))
    
    # Top line
    printf "%b%s" "$CYAN" "$BOX_TL"
    for ((i=0; i<width; i++)); do printf "%s" "$BOX_H"; done
    printf "%s%b\n" "$BOX_TR" "$NC"
    
    # Title line (if provided)
    if [[ -n "$title" ]]; then
        printf "%b%s" "$CYAN" "$BOX_V"
        # LEARNING: Need to subtract 1 from left padding when we have a title
        # because we're adding a space before the title
        # Fixed: 2025-06-20 for correct box alignment
        for ((i=0; i<left_padding; i++)); do printf " "; done
        printf " %b%s%b " "$BOLD_WHITE" "$title" "$CYAN"
        for ((i=0; i<right_padding; i++)); do printf " "; done
        printf "%s%b\n" "$BOX_V" "$NC"
    fi
    
    # Bottom line
    printf "%b%s" "$CYAN" "$BOX_BL"
    for ((i=0; i<width; i++)); do printf "%s" "$BOX_H"; done
    printf "%s%b\n" "$BOX_BR" "$NC"
}

# Draw a separator line (context-aware)
# Usage: draw_separator [width] [color]
draw_separator() {
    local width="${1:-50}"
    local color="${2:-$CYAN}"
    
    # Only in visual mode
    if [[ "$VISUAL_MODE" != true ]]; then
        return
    fi
    
    printf "${color}"
    printf "%${width}s" "" | tr ' ' "$LINE_H"
    printf "${NC}\n"
}

# ============================================================================
# PROGRESS INDICATORS
# ============================================================================

# LEARNING: Progress indicators must handle cleanup on script exit
# Use trap to ensure cursor is restored
# Discovered: 2025-06-20 during spinner design

# Spinner PID tracking
SPINNER_PID=""

# Cleanup function for spinners
cleanup_spinner() {
    if [[ -n "$SPINNER_PID" ]] && kill -0 "$SPINNER_PID" 2>/dev/null; then
        kill "$SPINNER_PID" 2>/dev/null
        wait "$SPINNER_PID" 2>/dev/null
    fi
    # Show cursor
    # LEARNING: Only manipulate cursor in true interactive terminals
    # Avoid in pipes/redirects to prevent escape sequences in output
    # Fixed: 2025-06-20 to prevent terminal control codes in output
    # LEARNING: Must suppress stderr from tput to avoid socket errors
    # Fixed: 2025-06-20 for REPL compatibility
    # LEARNING: Wrap entire terminal check in subshell to suppress all errors
    # Fixed: 2025-06-20 for maximum REPL safety
    { [[ "$INTERACTIVE" == true ]] && [[ -t 1 ]] && tput cnorm; } 2>/dev/null || true
    
    # Clear line
    # LEARNING: Use printf instead of echo -ne for portability
    # Also only clear line in interactive mode to avoid artifacts
    # Fixed: 2025-06-20 to prevent escape sequences in output
    { [[ "$INTERACTIVE" == true ]] && [[ -t 1 ]] && printf "\r\033[K"; } 2>/dev/null || true
}

# Set trap for cleanup
trap cleanup_spinner EXIT INT TERM

# Simple spinner
# Usage: start_spinner "message"
#        do_work
#        stop_spinner
# LEARNING: Cache formatted strings to avoid repeated ANSI operations
# Optimized: 2025-06-20 for performance
start_spinner() {
    local message="${1:-Working...}"
    
    # Only show spinner in interactive mode
    if [[ "$INTERACTIVE" != true ]]; then
        printf "%s\n" "$message"
        return
    fi
    
    # Hide cursor
    # LEARNING: Only manipulate cursor in true interactive terminals
    # Fixed: 2025-06-20 to prevent terminal control codes in output
    # LEARNING: Must suppress stderr from tput to avoid socket errors
    # Fixed: 2025-06-20 for REPL compatibility
    # LEARNING: Wrap entire terminal check in subshell to suppress all errors
    # Fixed: 2025-06-20 for maximum REPL safety
    { [[ -t 1 ]] && tput civis; } 2>/dev/null || true
    
    (
        # Use simpler chars if no Unicode
        if [[ "$UNICODE_SUPPORT" == true ]]; then
            local chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
        else
            local chars='|/-\\'
        fi
        
        local delay=0.1
        # Pre-format the return sequence
        local reset_line=$'\r\033[K'
        
        while true; do
            for (( i=0; i<${#chars}; i++ )); do
                printf "%s%b%s%b %s" "$reset_line" "$BLUE" "${chars:$i:1}" "$NC" "$message"
                sleep $delay
            done
        done
    ) &
    SPINNER_PID=$!
}

stop_spinner() {
    cleanup_spinner
    SPINNER_PID=""
}

# Progress bar
# Usage: show_progress current total [message]
# LEARNING: Progress bars must use carriage return (\r) to animate on same line
# Only works properly in interactive terminals, not in pipes
# Fixed: 2025-06-20 for proper single-line animation
# LEARNING: Force interactive mode if explicitly requested via env var
# Fixed: 2025-06-20 for testing and demos
show_progress() {
    local current=$1
    local total=$2
    local message="${3:-}"
    local width=30
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    
    # Only show progress in interactive mode (unless forced)
    # LEARNING: Allow forcing progress display for demos/testing
    # Fixed: 2025-06-20 for demo purposes
    if [[ "${FORCE_PROGRESS:-}" != "true" ]] && { [[ "$INTERACTIVE" != true ]] || { [[ ! -t 1 ]] 2>/dev/null; }; }; then
        # In non-interactive mode, just show final result
        if [[ $current -eq $total ]]; then
            printf "[DONE] %s (100%%)\n" "$message"
        fi
        return
    fi
    
    # Build progress bar on single line
    # LEARNING: Must clear to end of line to handle shrinking messages
    # Use \033[K to clear from cursor to end of line
    # Fixed: 2025-06-20 for clean single-line updates
    # LEARNING: Force flush output to ensure updates are visible
    # Fixed: 2025-06-20 for REPL environments
    printf "\r[%b" "$GREEN"
    printf "%${filled}s" "" | tr ' ' '█'
    printf "%b" "$DIM"
    printf "%$((width - filled))s" "" | tr ' ' '░'
    printf "%b] %3d%% %s\033[K" "$NC" "$percent" "$message"
    
    # New line only when complete
    if [[ $current -eq $total ]]; then
        printf "\n"
    fi
    # Force flush in case of buffering
    # LEARNING: Some environments buffer stdout, force flush
    # Fixed: 2025-06-20 for progress visibility
    exec 1>&1
}

# Robust progress bar wrapper with automatic updates
# Usage: with_progress "message" command
# LEARNING: Create a high-level wrapper for common progress patterns
# This handles the loop and updates automatically
# Added: 2025-06-20 for easier usage
with_progress() {
    local message="${1:-Processing}"
    local total="${2:-100}"
    local step="${3:-10}"
    
    local current=0
    while [[ $current -lt $total ]]; do
        show_progress $current $total "$message"
        sleep 0.1  # Simulate work
        current=$((current + step))
    done
    show_progress $total $total "$message"
}

# Advanced progress display with item list
# Usage: progress_with_items current total current_item [item1 item2 ...]
# LEARNING: Advanced UX - show progress bar + rolling window of items
# In pipes, just output the items for processing
# Added: 2025-06-20 for slick terminal UX
progress_with_items() {
    local current=$1
    local total=$2
    local current_item="$3"
    shift 3
    local -a recent_items=("$@")
    local max_items=5  # Show last 5 items
    
    # In non-interactive mode, just output the current item (unless forced)
    # LEARNING: Allow forcing progress display for demos/testing
    # Fixed: 2025-06-20 for demo purposes
    if [[ "${FORCE_PROGRESS:-}" != "true" ]] && { [[ "$INTERACTIVE" != true ]] || { [[ ! -t 1 ]] 2>/dev/null; }; }; then
        printf "%s\n" "$current_item"
        return
    fi
    
    # Clear previous display area (progress + item lines)
    # LEARNING: Use cursor movement to create smooth updates
    # \033[A moves cursor up, \033[K clears line
    # Only move up if we're past the first item
    # Fixed: 2025-06-20 for clean multi-line updates
    if [[ $current -gt 1 ]]; then
        local lines_to_clear=$((max_items + 2))  # +2 for progress bar and current
        for ((i=0; i<lines_to_clear; i++)); do
            printf "\033[A\033[K"
        done
    fi
    
    # Show progress bar
    show_progress $current $total "Processing"
    
    # Show current item with highlighting
    printf "\n%b▶ %s%b\n" "$BOLD_GREEN" "$current_item" "$NC"
    
    # Show recent items (dimmed)
    local start=0
    local count=${#recent_items[@]}
    if [[ $count -gt $((max_items - 1)) ]]; then
        start=$((count - max_items + 1))
    fi
    
    for ((i=start; i<count; i++)); do
        printf "%b  ✓ %s%b\n" "$DIM" "${recent_items[$i]}" "$NC"
    done
    
    # Pad remaining lines
    local shown=$((count - start))
    for ((i=shown; i<$((max_items - 1)); i++)); do
        printf "\n"
    done
}

# Process items with progress display
# Usage: process_items_with_progress item_array command
# Example: process_items_with_progress files 'cp $item dest/'
# LEARNING: High-level function to process arrays with progress
# Handles both interactive and pipe modes elegantly
# Added: 2025-06-20 for easy progress integration
process_items_with_progress() {
    local -n items=$1  # nameref to array
    local command_template="$2"
    local total=${#items[@]}
    local current=0
    local -a completed=()
    
    # Initial empty display in interactive mode
    # LEARNING: Check for forced progress mode too
    # Fixed: 2025-06-20 for demo compatibility
    if [[ "${FORCE_PROGRESS:-}" == "true" ]] || { [[ "$INTERACTIVE" == true ]] && { [[ -t 1 ]] 2>/dev/null; }; }; then
        # Print empty lines that will be updated
        for ((i=0; i<7; i++)); do printf "\n"; done
    fi
    
    for item in "${items[@]}"; do
        ((current++))
        
        # Update progress display
        progress_with_items $current $total "$item" "${completed[@]}"
        
        # Execute the command
        local command="${command_template//\$item/$item}"
        eval "$command"
        
        # Add to completed items
        completed+=("$item")
        
        # Keep only recent items
        if [[ ${#completed[@]} -gt 5 ]]; then
            completed=("${completed[@]:1}")
        fi
        
        # Small delay for visual effect in interactive mode
        # LEARNING: Check for forced progress mode too
        # Fixed: 2025-06-20 for demo compatibility
        if [[ "${FORCE_PROGRESS:-}" == "true" ]] || [[ "$INTERACTIVE" == true ]]; then
            sleep 0.1
        fi
    done
    
    # Final newline
    # LEARNING: Check for forced progress mode too
    # Fixed: 2025-06-20 for demo compatibility
    if [[ "${FORCE_PROGRESS:-}" == "true" ]] || { [[ "$INTERACTIVE" == true ]] && { [[ -t 1 ]] 2>/dev/null; }; }; then
        printf "\n"
    fi
}

# ============================================================================
# INPUT HELPERS
# ============================================================================

# Prompt for yes/no
# Usage: if confirm "Continue?"; then ...
confirm() {
    local prompt="${1:-Continue?}"
    local default="${2:-n}"  # default n or y
    local response
    
    # Build prompt with default
    if [[ "${default,,}" == "y" ]]; then
        prompt="$prompt [Y/n] "
    else
        prompt="$prompt [y/N] "
    fi
    
    while true; do
        read -p "$prompt" -n 1 -r response
        printf "\n"  # New line after response
        
        # Handle default (just Enter)
        if [[ -z "$response" ]]; then
            response="$default"
        fi
        
        case "${response,,}" in
            y|yes) return 0;;
            n|no)  return 1;;
            *)     warn "Please answer yes or no";;
        esac
    done
}

# Prompt with validation
# Usage: prompt_value "Enter name" "default" "^[a-zA-Z]+$"
prompt_value() {
    local prompt="$1"
    local default="${2:-}"
    local pattern="${3:-.*}"  # Default: accept anything
    local value
    
    while true; do
        if [[ -n "$default" ]]; then
            read -p "$prompt [$default]: " value
            value="${value:-$default}"
        else
            read -p "$prompt: " value
        fi
        
        if [[ "$value" =~ $pattern ]]; then
            printf "%s\n" "$value"
            return 0
        else
            warn "Invalid input. Please try again."
        fi
    done
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Center text
# Usage: center_text "text" [width]
center_text() {
    local text="$1"
    local width="${2:-$(tput cols 2>/dev/null || printf "80")}"
    local text_len=${#text}
    local padding=$(( (width - text_len) / 2 ))
    
    printf "%*s%s%*s\n" $padding "" "$text" $padding ""
}

# Format file size (cross-platform)
# Usage: format_size bytes
format_size() {
    local size=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    
    # Use bc for floating point if available, otherwise integer math
    if command -v bc >/dev/null 2>&1; then
        while (( $(printf "%s > 1024\n" "$size" | bc -l) )) && (( unit < 4 )); do
            size=$(printf "scale=2; %s / 1024\n" "$size" | bc)
            ((unit++))
        done
        printf "%.2f %s" "$size" "${units[$unit]}"
    else
        while (( size > 1024 )) && (( unit < 4 )); do
            size=$((size / 1024))
            ((unit++))
        done
        printf "%d %s\n" "$size" "${units[$unit]}"
    fi
}

# Format duration
# Usage: format_duration seconds
format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(( (seconds % 3600) / 60 ))
    local secs=$((seconds % 60))
    
    if (( hours > 0 )); then
        printf "%dh %dm %ds" $hours $minutes $secs
    elif (( minutes > 0 )); then
        printf "%dm %ds" $minutes $secs
    else
        printf "%ds" $secs
    fi
}

# Get file modification time (cross-platform)
# Usage: get_file_mtime filename
get_file_mtime() {
    local file="$1"
    
    case "$PLATFORM" in
        macos)
            stat -f%m "$file" 2>/dev/null || printf "0"
            ;;
        linux|wsl)
            # LEARNING: WSL uses same stat syntax as Linux
            stat -c%Y "$file" 2>/dev/null || printf "0"
            ;;
        *)
            printf "0"
            ;;
    esac
}

# Create temporary file (cross-platform)
# Usage: tmpfile=$(make_temp_file [suffix])
make_temp_file() {
    local suffix="${1:-.tmp}"
    local template="aipm_XXXXXX$suffix"
    
    if command -v mktemp >/dev/null 2>&1; then
        mktemp -t "$template" 2>/dev/null || mktemp "/tmp/$template"
    else
        # Fallback
        local tmpfile="/tmp/aipm_$$_$(date +%s)$suffix"
        touch "$tmpfile"
        printf "%s\n" "$tmpfile"
    fi
}

# ============================================================================
# ERROR HANDLING
# ============================================================================

# LEARNING: Proper error handling with stack traces helps debugging
# Include function name and line number when possible
# Discovered: 2025-06-20 during error handling design

# Enhanced error reporting
die() {
    local message="${1:-Unknown error}"
    local code="${2:-1}"
    
    error "$message"
    
    # Show stack trace if DEBUG is set
    if [[ -n "${DEBUG:-}" ]]; then
        # LEARNING: Use printf instead of echo -e for portability
        # Fixed: 2025-06-20 for consistency
        printf "%sStack trace:%s\n" "$DIM" "$NC" >&2
        local frame=0
        while caller $frame >&2; do
            ((frame++))
        done
    fi
    
    exit "$code"
}

# Assert condition
# Usage: assert "condition" "error message"
assert() {
    local condition="$1"
    local message="${2:-Assertion failed: $condition}"
    
    if ! eval "$condition"; then
        die "$message" 2
    fi
}

# ============================================================================
# USAGE EXAMPLES AND DOCUMENTATION
# ============================================================================

# LEARNING: Providing clear examples helps maintain consistency
# across all scripts that use these utilities
# Discovered: 2025-06-20 during framework design

: <<'EXAMPLES'
# Basic colored output
fprintln "green" "Operation successful"
fprintln "red" "Error occurred" true  # Bold

# Using internal functions directly
set_color "blue"
printf "This is blue text"
reset_format
printf "\n"

# Symbol usage with fallbacks
printf "%s Task completed\n" "$(get_symbol check)"
printf "%s Warning: Check logs\n" "$(get_symbol warning)"

# Context-aware output
output_info "Starting process..."
output_success "Process completed"
output_error 1 "Process failed" "Check permissions"

# Safe command execution with timeout
safe_execute "sleep 5" 3  # Will timeout and retry
safe_execute "git fetch" 30 1  # 30s timeout, no retry

# Execute with visual feedback
execute_with_spinner "Building project" "npm run build" 60

# Error handling setup
set_error_trap "my-script"
# Your script code here - errors will be caught

# Platform-specific code
if [[ "$PLATFORM" == "macos" ]]; then
    # macOS specific
elif [[ "$PLATFORM" == "linux" ]]; then
    # Linux/WSL specific
fi

# Context-specific output
case "$EXECUTION_CONTEXT" in
    terminal)
        draw_box "Welcome" 50
        ;;
    ci)
        output "INFO" "0" "CI Build Started" "Branch: main"
        ;;
    claude)
        # Minimal output for Claude Code
        output_info "Process started"
        ;;
esac

# Logging
init_log  # If LOG_FILE is set
log "INFO" "Application started"
log "ERROR" "Failed to connect to database"

# Input helpers
if confirm "Continue with deployment?"; then
    printf "Deploying...\n"
fi

name=$(prompt_value "Enter project name" "my-project" "^[a-zA-Z0-9-]+$")

# Progress indication
# NOTE: Progress bars only animate in truly interactive terminals
# In scripts, use explicit loops:
for i in 0 20 40 60 80 100; do
    show_progress $i 100 "Processing files"
    # Your actual work here
    sleep 0.1
done

# Advanced progress with item list:
files=(*.txt)
process_items_with_progress files 'process_file "$item"'

# Manual advanced progress:
items=("file1.txt" "file2.txt" "file3.txt")
completed=()
for i in "${!items[@]}"; do
    progress_with_items $((i+1)) ${#items[@]} "${items[$i]}" "${completed[@]}"
    # Do work here
    completed+=("${items[$i]}")
done
EXAMPLES

# ============================================================================
# EXPORT SUCCESS
# ============================================================================

# LEARNING: Set a flag to indicate successful sourcing
# This helps scripts verify the utilities loaded correctly
# Discovered: 2025-06-20 during modular design
export SHELL_FORMATTING_LOADED=true

# Show debug info if requested
debug "shell-formatting.sh loaded successfully"
debug "Platform: $PLATFORM"
debug "Color support: $COLOR_SUPPORT"
debug "Unicode support: $UNICODE_SUPPORT"
debug "Interactive: $INTERACTIVE"
debug "Execution context: $EXECUTION_CONTEXT"
debug "Output mode: $OUTPUT_MODE"
debug "Timeout command: ${TIMEOUT_CMD:-none}"