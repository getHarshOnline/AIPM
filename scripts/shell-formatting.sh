#!/opt/homebrew/bin/bash
#
# shell-formatting.sh - Common formatting utilities for AIPM scripts
#
# This script provides:
# - Consistent color definitions
# - Pretty print functions
# - Progress indicators
# - Error/warning/success messages
# - Box drawing utilities
#
# Usage: source this file in other scripts
#   source "$SCRIPT_DIR/shell-formatting.sh"
#
# Created by: AIPM Framework
# License: Apache 2.0

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script should be sourced, not executed directly"
    echo "Usage: source $0"
    exit 1
fi

# ============================================================================
# COLOR DEFINITIONS
# ============================================================================

# Basic colors
export BLACK='\033[0;30m'
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[0;37m'

# Bold colors
export BOLD_BLACK='\033[1;30m'
export BOLD_RED='\033[1;31m'
export BOLD_GREEN='\033[1;32m'
export BOLD_YELLOW='\033[1;33m'
export BOLD_BLUE='\033[1;34m'
export BOLD_MAGENTA='\033[1;35m'
export BOLD_CYAN='\033[1;36m'
export BOLD_WHITE='\033[1;37m'

# Background colors
export BG_BLACK='\033[40m'
export BG_RED='\033[41m'
export BG_GREEN='\033[42m'
export BG_YELLOW='\033[43m'
export BG_BLUE='\033[44m'
export BG_MAGENTA='\033[45m'
export BG_CYAN='\033[46m'
export BG_WHITE='\033[47m'

# Reset
export NC='\033[0m' # No Color
export RESET='\033[0m'

# ============================================================================
# BOX DRAWING CHARACTERS
# ============================================================================

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

# Simple line drawing
export LINE_H='─'  # Horizontal line
export LINE_V='│'  # Vertical line
export DOT='•'     # Bullet point
export ARROW='→'   # Arrow

# ============================================================================
# MESSAGE FUNCTIONS
# ============================================================================

# Print error message
error() {
    echo -e "${RED}✗ ERROR: $*${NC}" >&2
}

# Print warning message
warn() {
    echo -e "${YELLOW}⚠️  WARNING: $*${NC}" >&2
}

# Print success message
success() {
    echo -e "${GREEN}✓ $*${NC}"
}

# Print info message
info() {
    echo -e "${BLUE}ℹ️  $*${NC}"
}

# Print debug message (only if DEBUG is set)
debug() {
    if [[ -n "${DEBUG:-}" ]]; then
        echo -e "${MAGENTA}DEBUG: $*${NC}" >&2
    fi
}

# ============================================================================
# BOX DRAWING FUNCTIONS
# ============================================================================

# Draw a box with title
# Usage: draw_box "Title" "width"
draw_box() {
    local title="${1:-}"
    local width="${2:-50}"
    local title_len=${#title}
    local padding=$(( (width - title_len - 2) / 2 ))
    
    # Top line
    echo -ne "${CYAN}${BOX_TL}"
    for ((i=0; i<width; i++)); do
        echo -ne "${BOX_H}"
    done
    echo -e "${BOX_TR}${NC}"
    
    # Title line
    if [[ -n "$title" ]]; then
        echo -ne "${CYAN}${BOX_V}"
        printf "%*s" $padding ""
        echo -ne " $title "
        printf "%*s" $((width - padding - title_len - 2)) ""
        echo -e "${BOX_V}${NC}"
    fi
    
    # Bottom line
    echo -ne "${CYAN}${BOX_BL}"
    for ((i=0; i<width; i++)); do
        echo -ne "${BOX_H}"
    done
    echo -e "${BOX_BR}${NC}"
}

# Draw a separator line
# Usage: draw_separator [width] [color]
draw_separator() {
    local width="${1:-50}"
    local color="${2:-$CYAN}"
    
    echo -ne "${color}"
    for ((i=0; i<width; i++)); do
        echo -ne "${LINE_H}"
    done
    echo -e "${NC}"
}

# ============================================================================
# PROGRESS INDICATORS
# ============================================================================

# Simple spinner
# Usage: spinner & SPINNER_PID=$!
# ... do work ...
# kill $SPINNER_PID
spinner() {
    local chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local delay=0.1
    while true; do
        for (( i=0; i<${#chars}; i++ )); do
            echo -ne "\r${BLUE}${chars:$i:1}${NC} "
            sleep $delay
        done
    done
}

# Progress bar
# Usage: progress_bar current total
progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    
    echo -ne "\r["
    printf "%${filled}s" | tr ' ' '='
    echo -ne ">"
    printf "%$((width - filled))s" | tr ' ' '-'
    echo -ne "] $percent%"
    
    if [[ $current -eq $total ]]; then
        echo
    fi
}

# ============================================================================
# INPUT HELPERS
# ============================================================================

# Prompt for yes/no
# Usage: if confirm "Continue?"; then ...
confirm() {
    local prompt="${1:-Continue?}"
    local response
    
    while true; do
        read -p "$prompt [y/N] " -n 1 -r response
        echo
        case "$response" in
            [yY]) return 0 ;;
            [nN]|"") return 1 ;;
            *) echo "Please answer y or n" ;;
        esac
    done
}

# Select from menu
# Usage: options=("opt1" "opt2" "opt3")
#        select_option "Choose:" "${options[@]}"
#        choice=$?
select_option() {
    local prompt="$1"
    shift
    local options=("$@")
    local selected=0
    local key
    
    # Hide cursor
    tput civis
    
    while true; do
        clear
        echo -e "${CYAN}$prompt${NC}"
        echo
        
        for i in "${!options[@]}"; do
            if [[ $i -eq $selected ]]; then
                echo -e "${GREEN}${ARROW} ${options[$i]}${NC}"
            else
                echo -e "  ${options[$i]}"
            fi
        done
        
        # Read single character
        read -rsn1 key
        
        case "$key" in
            A) # Up arrow
                ((selected--))
                if [[ $selected -lt 0 ]]; then
                    selected=$((${#options[@]} - 1))
                fi
                ;;
            B) # Down arrow
                ((selected++))
                if [[ $selected -ge ${#options[@]} ]]; then
                    selected=0
                fi
                ;;
            "") # Enter
                break
                ;;
        esac
    done
    
    # Show cursor
    tput cnorm
    
    return $selected
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Center text
# Usage: center_text "text" [width]
center_text() {
    local text="$1"
    local width="${2:-$(tput cols)}"
    local padding=$(( (width - ${#text}) / 2 ))
    printf "%*s%s%*s\n" $padding "" "$text" $padding ""
}

# Format file size
# Usage: format_size 1234567
format_size() {
    local size=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    
    while [[ $size -gt 1024 && $unit -lt 4 ]]; do
        size=$((size / 1024))
        ((unit++))
    done
    
    echo "$size ${units[$unit]}"
}

# Format duration
# Usage: format_duration $seconds
format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(( (seconds % 3600) / 60 ))
    local secs=$((seconds % 60))
    
    printf "%02d:%02d:%02d" $hours $minutes $secs
}

# ============================================================================
# EXPORT SUCCESS
# ============================================================================

# Indicate successful sourcing
debug "shell-formatting.sh loaded successfully"