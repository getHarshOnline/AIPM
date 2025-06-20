#!/opt/homebrew/bin/bash
# Script to sync memory.json from npm cache to project directory
# This is a workaround for the MEMORY_FILE_PATH bug in @modelcontextprotocol/server-memory

# Find the memory.json file in npm cache
MEMORY_SOURCE=$(find ~/.npm/_npx -name "memory.json" -path "*/@modelcontextprotocol/server-memory/dist/*" 2>/dev/null | head -1)

if [ -z "$MEMORY_SOURCE" ]; then
    echo "Warning: memory.json not found in npm cache"
    exit 1
fi

# Project memory location
MEMORY_TARGET="$(dirname "$0")/memory.json"

# Create symlink if it doesn't exist or points to wrong location
if [ ! -L "$MEMORY_TARGET" ] || [ "$(readlink "$MEMORY_TARGET")" != "$MEMORY_SOURCE" ]; then
    echo "Creating symlink: $MEMORY_TARGET -> $MEMORY_SOURCE"
    ln -sf "$MEMORY_SOURCE" "$MEMORY_TARGET"
else
    echo "Symlink already correct"
fi

# Verify the symlink works
if [ -e "$MEMORY_TARGET" ]; then
    echo "Success: memory.json is accessible at .claude/memory.json"
else
    echo "Error: Failed to create working symlink"
    exit 1
fi