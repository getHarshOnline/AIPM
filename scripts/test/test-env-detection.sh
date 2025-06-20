#!/opt/homebrew/bin/bash
#
# test-env-detection.sh - Debug environment detection in shell-formatting.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIPM_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "Environment Detection Debug"
echo "=========================="
echo

# Show environment variables
echo "Environment variables:"
echo "  TERM: '${TERM:-unset}'"
echo "  TERM_PROGRAM: '${TERM_PROGRAM:-unset}'"
echo "  CI: '${CI:-unset}'"
echo "  CLAUDE_CODE: '${CLAUDE_CODE:-unset}'"
echo "  ANTHROPIC_RUNTIME: '${ANTHROPIC_RUNTIME:-unset}'"
echo "  USER: '${USER:-unset}'"
echo "  TTY test: $([ -t 1 ] && echo "YES" || echo "NO")"
echo "  Is stdout a terminal: $([ -t 1 ] && echo "YES" || echo "NO")"
echo "  Is stderr a terminal: $([ -t 2 ] && echo "YES" || echo "NO")"
echo

# Source shell-formatting and show detection results
cd "$AIPM_ROOT"
source scripts/shell-formatting.sh

echo "Detection results:"
echo "  EXECUTION_CONTEXT: '$EXECUTION_CONTEXT'"
echo "  INTERACTIVE: '$INTERACTIVE'"
echo "  COLOR_SUPPORT: '$COLOR_SUPPORT'"
echo "  UNICODE_SUPPORT: '$UNICODE_SUPPORT'"
echo "  VISUAL_MODE: '$VISUAL_MODE'"
echo "  OUTPUT_MODE: '$OUTPUT_MODE'"
echo

# Test actual output
echo "Output test:"
success "Success message"
error "Error message"
warn "Warning message"
info "Info message"

# Show what set_color is doing
echo
echo "Direct color test:"
set_color green
echo "This text should be green if colors are enabled"
set_color reset
echo "This text should be normal"