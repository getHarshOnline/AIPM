#!/opt/homebrew/bin/bash
#
# sync-memory.sh - Hardened script to create/verify memory.json symlink
#
# This script ensures the .claude/memory.json symlink points to the correct
# global npm cache location. It's a critical workaround for the MEMORY_FILE_PATH
# bug in @modelcontextprotocol/server-memory package.
#
# Usage: .claude/sync-memory.sh [--force]
#   --force: Force recreate symlink even if it exists
#
# Exit codes:
#   0: Success
#   1: Memory source not found
#   2: Failed to create symlink
#   3: Invalid symlink target
#
# Created by: AIPM Framework
# License: Apache 2.0

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source formatting utilities
# LEARNING: Always source shell-formatting.sh for consistent output
# This provides proper color handling, progress bars, and error management
# Updated: 2025-06-20 to use hardened formatting utilities
if [[ -f "$PROJECT_ROOT/scripts/shell-formatting.sh" ]]; then
    # Set environment for better output in scripts
    export AIPM_COLOR=true
    export AIPM_UNICODE=true
    source "$PROJECT_ROOT/scripts/shell-formatting.sh"
else
    # Minimal fallback if formatting script is missing
    printf "Warning: shell-formatting.sh not found\n" >&2
    error() { printf "ERROR: %s\n" "$*" >&2; }
    warn() { printf "WARNING: %s\n" "$*" >&2; }
    success() { printf "SUCCESS: %s\n" "$*"; }
    info() { printf "INFO: %s\n" "$*"; }
    section() { printf "\n=== %s ===\n" "$*"; }
    draw_box() { printf "\n[ %s ]\n\n" "$1"; }
fi

# Parse arguments
FORCE_MODE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_MODE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--force]"
            echo "  --force: Force recreate symlink even if it exists"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Configuration
MEMORY_TARGET="$SCRIPT_DIR/memory.json"

# LEARNING: NPM cache locations vary by platform and configuration
# - macOS: ~/.npm/_npx (most common)
# - macOS alternate: ~/Library/Caches/npm/_npx
# - Linux: ~/.cache/npm/_npx
# The MCP server creates a unique hash directory for each installation
# Discovered: 2025-06-20 during cross-platform testing prep
NPM_CACHE_PATHS=(
    ~/.npm/_npx
    ~/Library/Caches/npm/_npx
    ~/.cache/npm/_npx
)

# Use proper box drawing from shell-formatting.sh
if command -v draw_box >/dev/null 2>&1; then
    draw_box "AIPM Memory Symlink Manager" 42
else
    # Fallback header
    printf "\n=== AIPM Memory Symlink Manager ===\n\n"
fi

# Function to find memory.json in npm cache
find_memory_source() {
    local memory_source=""
    
    # LEARNING: When capturing function output with $(), any echo statements
    # get included in the captured value. We must redirect informational
    # messages to stderr (>&2) and only echo the actual return value to stdout.
    # Discovered: 2025-06-20 when function was returning messages + path
    
    # Use spinner if available and in visual mode
    if [[ "${VISUAL_MODE:-false}" == "true" ]] && command -v start_spinner >/dev/null 2>&1; then
        start_spinner "Searching for memory.json in npm cache..."
    else
        info "Searching for memory.json in npm cache..." >&2
    fi
    
    for cache_path in "${NPM_CACHE_PATHS[@]}"; do
        if [[ -d "$cache_path" ]]; then
            memory_source=$(find "$cache_path" -name "memory.json" \
                -path "*/@modelcontextprotocol/server-memory/dist/*" \
                2>/dev/null | head -1 || true)
            
            if [[ -n "$memory_source" ]]; then
                # Stop spinner if running
                if command -v stop_spinner >/dev/null 2>&1; then
                    stop_spinner
                fi
                success "Found memory.json at: $memory_source" >&2
                # Return just the path on stdout
                echo "$memory_source"
                return 0
            fi
        fi
    done
    
    # Stop spinner if running
    if command -v stop_spinner >/dev/null 2>&1; then
        stop_spinner
    fi
    
    return 1
}

# Function to validate memory.json file
validate_memory_file() {
    local file="$1"
    
    # Check if file exists
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    # LEARNING: The MCP memory server creates an empty (0 byte) memory.json file
    # initially, which would fail JSON validation. We need to handle this as a
    # valid state since it represents a fresh memory store.
    # Discovered: 2025-06-20 during initial testing
    
    # Check file size (portable between macOS and Linux)
    local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "-1")
    
    # Empty file is valid (initial state)
    if [[ "$size" -eq 0 ]]; then
        # LEARNING: MCP server creates empty memory.json initially
        # This is a valid state, not an error
        # Discovered: 2025-06-20 during testing
        debug "Memory file is empty (initial state)" 2>/dev/null || true
        return 0
    fi
    
    # For non-empty files, check if it's valid JSON
    if [[ "$size" -gt 0 ]]; then
        if ! python3 -m json.tool "$file" >/dev/null 2>&1; then
            warn "File exists but is not valid JSON"
            return 1
        fi
        # Use format_size if available
        if command -v format_size >/dev/null 2>&1; then
            debug "Memory file size: $(format_size $size)" 2>/dev/null || true
        fi
    fi
    
    return 0
}

# Function to create or update symlink
create_symlink() {
    local source="$1"
    local target="$2"
    
    # Check if symlink already exists
    if [[ -L "$target" ]]; then
        local current_source=$(readlink "$target" 2>/dev/null || true)
        
        if [[ "$current_source" == "$source" ]] && [[ "$FORCE_MODE" == false ]]; then
            success "Symlink already correct: $target → $source"
            return 0
        else
            warn "Existing symlink points to: $current_source"
            info "Updating symlink..."
        fi
    elif [[ -e "$target" ]]; then
        error "Target exists but is not a symlink: $target"
        error "Please remove it manually and run this script again"
        return 1
    fi
    
    # Create parent directory if needed
    mkdir -p "$(dirname "$target")"
    
    # Create symlink
    if ln -sf "$source" "$target"; then
        success "Created symlink: $target → $source"
        return 0
    else
        error "Failed to create symlink"
        return 1
    fi
}

# Main execution
main() {
    # Set up error handling if available
    if command -v set_error_trap >/dev/null 2>&1; then
        set_error_trap "sync-memory"
    fi
    # Step 1: Find memory.json source
    if ! MEMORY_SOURCE=$(find_memory_source); then
        error "memory.json not found in npm cache"
        error "Make sure @modelcontextprotocol/server-memory is installed"
        error "Try running: claude mcp list"
        
        # Use die function if available
        if command -v die >/dev/null 2>&1; then
            die "Failed to find memory.json source" 1
        else
            exit 1
        fi
    fi
    
    # Step 2: Validate the source file
    if command -v step >/dev/null 2>&1; then
        step "Validating memory.json file"
    fi
    
    if ! validate_memory_file "$MEMORY_SOURCE"; then
        error "Source memory.json is invalid or corrupted"
        if command -v die >/dev/null 2>&1; then
            die "Invalid memory.json file" 3
        else
            exit 3
        fi
    fi
    
    # Step 3: Create or update symlink
    if command -v step >/dev/null 2>&1; then
        step "Creating symlink to memory.json"
    fi
    
    if ! create_symlink "$MEMORY_SOURCE" "$MEMORY_TARGET"; then
        error "Failed to create symlink"
        if command -v die >/dev/null 2>&1; then
            die "Symlink creation failed" 2
        else
            exit 2
        fi
    fi
    
    # Step 4: Verify the symlink works
    if command -v step >/dev/null 2>&1; then
        step "Verifying symlink accessibility"
    else
        info "Verifying symlink..."
    fi
    
    if [[ -L "$MEMORY_TARGET" ]] && [[ -e "$MEMORY_TARGET" ]]; then
        # Test read access
        if head -1 "$MEMORY_TARGET" >/dev/null 2>&1; then
            success "Symlink verified - memory.json is accessible"
            
            # Show file info
            local size=$(wc -c < "$MEMORY_TARGET" 2>/dev/null || echo "0")
            local lines=$(wc -l < "$MEMORY_TARGET" 2>/dev/null || echo "0")
            
            # Use formatted size if available
            if command -v format_size >/dev/null 2>&1; then
                info "Memory file: $lines lines, $(format_size $size)"
            else
                info "Memory file: $lines lines, $size bytes"
            fi
            
            # Create backup location if needed
            if [[ ! -d "$PROJECT_ROOT/.memory" ]]; then
                mkdir -p "$PROJECT_ROOT/.memory"
                info "Created .memory directory for backups"
            fi
            
            # Use proper separator from shell-formatting.sh
            if command -v draw_separator >/dev/null 2>&1; then
                draw_separator 44
            else
                printf "============================================\n"
            fi
            
            success "Memory symlink setup complete!"
            printf "\n"
            
            # Use step function if available
            if command -v step >/dev/null 2>&1; then
                section "Next steps"
                step "Run: ./scripts/start.sh --framework"
                step "Or:  ./scripts/start.sh --project Product"
            else
                info "Next steps:"
                printf "  1. Run: ./scripts/start.sh --framework\n"
                printf "  2. Or:  ./scripts/start.sh --project Product\n"
            fi
            
            exit 0
        else
            error "Symlink exists but file is not readable"
            exit 3
        fi
    else
        error "Symlink verification failed"
        exit 2
    fi
}

# Run main function
main "$@"