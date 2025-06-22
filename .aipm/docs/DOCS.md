# AIPM Technical Documentation

## What is AIPM?

AIPM (AI Project Manager) is a git-powered decision tracking system that prevents organizational amnesia. It captures, preserves, and recalls every decision, discussion, and rationale across all teams - not just engineering.

## Core Architecture

### The Foundation: opinions.yaml

Every AIPM workspace is driven by `.aipm/opinions.yaml` - the cornerstone configuration that defines:
- Branch naming and lifecycle rules
- Memory categorization and persistence
- Workflow automation patterns
- Workspace isolation boundaries

### Module Architecture

```
opinions.yaml (configuration)
    ↓
opinions-loader.sh (pure YAML→shell transformation)
    ↓
opinions-state.sh (state management + pre-computation)
    ↓
Core Modules:
├── version-control.sh (ONLY module calling git)
├── shell-formatting.sh (ONLY module calling echo/printf)  
├── opinions-loader.sh (YAML to shell transformation)
├── opinions-state.sh (state management)
├── migrate-memories.sh (memory operations)
├── sync-memory.sh (memory symlink setup)
└── cleanup-global.sh (emergency memory cleanup)
    ↓
Wrapper Scripts (user interface)
```

### Key Principles

1. **Single Source of Truth**: Each operation has exactly one implementation
2. **No Direct Git Calls**: Only version-control.sh may call git
3. **No Direct Output**: Only shell-formatting.sh may call echo/printf
4. **Bidirectional State**: All changes propagate back to central state
5. **Pre-computation**: Everything computed once at startup

## Directory Structure

```
AIPM/                           # Framework workspace
├── .aipm/                      # THE AIPM HUB
│   ├── opinions.yaml          # Configuration cornerstone
│   ├── memory.json            # Symlink to MCP global memory
│   ├── memory/                # Persistent memory storage
│   ├── state/                 # State management files
│   │   └── workspace.json     # Pre-computed state
│   ├── scripts/               # All AIPM scripts
│   │   ├── init.sh           # Wrapper: Initialize workspace
│   │   ├── start.sh          # Wrapper: Start session
│   │   ├── save.sh           # Wrapper: Save decisions
│   │   ├── revert.sh         # Wrapper: Undo changes
│   │   └── stop.sh           # Wrapper: End session
│   │   └── modules/          # Core modules only
│   │       ├── opinions-loader.sh
│   │       ├── opinions-state.sh
│   │       ├── version-control.sh
│   │       ├── shell-formatting.sh
│   │       ├── migrate-memories.sh
│   │       ├── sync-memory.sh
│   │       └── cleanup-global.sh
│   ├── docs/                  # Technical documentation
│   │   ├── DOCS.md           # This file
│   │   ├── workflow.md       # Usage patterns
│   │   ├── memory-management.md  # Memory architecture
│   │   └── state-management.md   # State architecture
│   └── templates/             # Project templates
│
├── .agentrules                # AI behavior rules
├── README.md                  # Problem & solution
├── current-focus.md           # Active development
└── YourProject/               # Symlinked project
```

## How AIPM Works

### 1. Initialization
- `init.sh` creates workspace structure
- Loads opinions.yaml via opinions-loader.sh
- Pre-computes all state via opinions-state.sh
- Creates workspace.json for instant lookups

### 2. Session Management
- `start.sh` begins a new work session
- Creates session-specific branch and memory
- Tracks all decisions and rationale
- Maintains bidirectional state updates

### 3. Memory Persistence
- `save.sh` commits decisions to memory
- Categorizes by type (decision, discussion, todo, etc.)
- Never loses context or rationale
- Survives team changes

### 4. State Management
- Central workspace.json holds all computed state
- Wrapper scripts read state for configuration
- All changes report back to maintain consistency
- No runtime computation needed

## Module Reference

### Core Modules (scripts/modules/)

**version-control.sh**
- All git operations (50+ functions)
- Branch management and validation
- Commit operations and safety checks

**shell-formatting.sh**
- All output operations
- Color and formatting functions
- Error and success messaging

**opinions-loader.sh**
- Pure YAML to shell transformation
- Validates and exports all configurations
- No logic, just data transformation

**opinions-state.sh**
- Complete state management
- Pre-computes all derived values
- Bidirectional update mechanisms
- Workspace.json management

### Wrapper Scripts (scripts/)

**init.sh** - Initialize new workspace
**start.sh** - Begin work session
**save.sh** - Persist decisions
**revert.sh** - Undo changes
**stop.sh** - End work session

## Quick Start

1. **Initialize Workspace**
   ```bash
   .aipm/scripts/init.sh YourProject
   ```

2. **Start Working**
   ```bash
   aipm start "implement new feature"
   ```

3. **Save Decisions**
   ```bash
   aipm save -d "Chose PostgreSQL over MySQL because..."
   ```

4. **View History**
   ```bash
   aipm show --decisions
   ```

## For Developers

- Read `.agentrules` for AI interaction rules
- Check `current-focus.md` for active development
- See test/ for fix plans during refactoring
- All scripts have inline documentation

## Architecture Compliance

**Critical Rules:**
1. Only version-control.sh calls git
2. Only shell-formatting.sh produces output
3. All scripts must source opinions-state.sh
4. No hardcoded values - use opinions.yaml
5. All state changes must be bidirectional

---

*AIPM: Organizational memory that scales with your team.*