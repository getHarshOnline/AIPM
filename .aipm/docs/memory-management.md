# Memory Management in AIPM Framework

## Overview

The AIPM framework uses a memory system to maintain persistent knowledge across Claude Code sessions. This document describes the memory architecture, challenges, and solutions implemented in the framework.

## Memory System Architecture

### Purpose
- Store protocols and patterns discovered during development
- Maintain project-specific knowledge graphs
- Enable AI to recall previous decisions and context
- Version control AI knowledge alongside code

### Technology Stack
- **MCP Server**: `@modelcontextprotocol/server-memory`
- **Storage Format**: Newline-delimited JSON
- **Integration**: Via Claude Code's MCP configuration

## The Challenge: Global Memory Pollution

### Problem Description
The `@modelcontextprotocol/server-memory` npm package has a critical limitation:
- Ignores the `MEMORY_FILE_PATH` environment variable
- Stores all memory in a global location: `~/.npm/_npx/*/node_modules/@modelcontextprotocol/server-memory/dist/memory.json`
- Results in all Claude Code projects sharing the same memory space
- Creates security risks in shared environments
- Memory persists across git branches and reverts

### Impact on AIPM
1. **No Project Isolation**: Different projects contaminate each other's memory
2. **No Version Control**: Memory changes aren't tracked with code
3. **Security Concerns**: Sensitive project data leaks between projects
4. **Branch Confusion**: Memory doesn't align with git branches

## Solution: Backup-Restore Memory Isolation

### Design Principles
1. **Complete Isolation**: Framework and Project memories never mix
2. **Local Persistence**: Each context maintains its own `local_memory.json`
3. **Session Safety**: Backup/restore ensures clean global state
4. **Git Integration**: Local memories are version controlled
5. **Multi-Project Support**: Scales to N projects with identical structure
6. **Centralized Management**: All scripts run from AIPM root directory

### Implementation Architecture

```
Directory Structure:
AIPM/                          # Framework root (all scripts run from here)
├── .aipm/                     # AIPM configuration directory
│   ├── opinions.json        # Framework branching opinions
│   └── memory/              # Framework memory storage
│       ├── local_memory.json # Persistent framework memory (tracked)
│       └── backup.json      # Single backup location (gitignored)
├── .claude/
│   └── memory.json          # Symlink to global npm cache
├── scripts/                 # Session management scripts
│   ├── start.sh            # ./scripts/start.sh --framework|--project NAME
│   ├── stop.sh             # ./scripts/stop.sh --framework|--project NAME
│   ├── save.sh             # ./scripts/save.sh --framework|--project NAME
│   └── revert.sh           # ./scripts/revert.sh --framework|--project NAME
│
├── Product/                 # Project 1 (symlinked git repository)
│   ├── .aipm/              # Project's AIPM configuration
│   │   ├── opinions.json   # Project's branching opinions
│   │   └── memory/         # Project's AI memory
│   │       └── local_memory.json
│   ├── data/               # Actual project data
│   ├── CLAUDE.md           # Project-specific AI instructions
│   ├── README.md           # Project documentation
│   ├── current-focus.md    # Active tasks
│   └── broad-focus.md      # Project vision
│
└── [ProjectName]/          # Future projects (same structure)
    ├── .aipm/              # Each project owns its AIPM config
    │   ├── opinions.json   # Project opinions
    │   └── memory/         # Each project owns its memory
    ├── data/               # Each project owns its data
    └── [standard files]    # Same structure for all projects
```

### Memory Flow

#### Session Start
```
1. Global Memory → .aipm/memory/backup.json     # Single backup location
2. Clear Global Memory                     # Clean slate
3. Load context-specific memory:
   - Framework: .aipm/memory/local_memory.json → Global
   - Project: [ProjectName]/.aipm/memory/local_memory.json → Global
```

#### During Session
```
- All operations use standard MCP tools
- Changes accumulate in global memory
- Entities use strict prefix separation
```

#### Session End
```
1. Save to context-specific location:
   - Framework: Global → .aipm/memory/local_memory.json
   - Project: Global → [ProjectName]/.aipm/memory/local_memory.json
2. Clear Global Memory                        # Clean slate
3. .aipm/memory/backup.json → Global Memory        # Restore original
4. Delete .aipm/memory/backup.json                 # Clean up
```

### Script Usage

All scripts run from AIPM root directory with explicit context:

```bash
# Framework work
./scripts/start.sh --framework
./scripts/stop.sh --framework
./scripts/save.sh --framework "Updated memory management docs"

# Project work (current)
./scripts/start.sh --project Product
./scripts/stop.sh --project Product
./scripts/save.sh --project Product "Fixed deployment issue"

# Future projects
./scripts/start.sh --project ClientWebsite
./scripts/start.sh --project MobileApp
```

## Memory Schema Specification

### File Format
The memory.json file uses **newline-delimited JSON** (NDJSON) format:
```
{"type":"entity","name":"ENTITY_1",...}\n
{"type":"entity","name":"ENTITY_2",...}\n
{"type":"relation","from":"ENTITY_1","to":"ENTITY_2",...}\n
```

### Entity Schema
```json
{
  "type": "entity",
  "name": "PREFIX_CATEGORY_NAME",
  "entityType": "PROTOCOL|WORKFLOW|DOCUMENTATION|etc",
  "observations": [
    "Fact or observation about this entity",
    "Another observation with specific details"
  ]
}
```

**Field Specifications:**
- `type`: Always "entity" for entity records
- `name`: Unique identifier following naming convention
- `entityType`: Categorization of the entity
- `observations`: Array of factual statements

### Relation Schema
```json
{
  "type": "relation",
  "from": "SOURCE_ENTITY_NAME",
  "to": "TARGET_ENTITY_NAME",
  "relationType": "implements|references|requires|etc"
}
```

**Field Specifications:**
- `type`: Always "relation" for relationship records
- `from`: Name of source entity (must exist)
- `to`: Name of target entity (must exist)
- `relationType`: Nature of the relationship

### Naming Convention
All entities must follow strict prefixing based on context:

#### Framework Entities (AIPM Development)
```
AIPM_ + CATEGORY + NAME

Examples:
- AIPM_PROTOCOL_SESSION_INIT
- AIPM_WORKFLOW_MEMORY_SYNC
- AIPM_DESIGN_MEMORY_SCHEMA
```

#### Product Entities (Project Management)
```
[PROJECT_NAME]_ + CATEGORY + NAME

Examples:
- PRODUCT_ENTITY_USER_MODEL
- PRODUCT_WORKFLOW_DEPLOYMENT
- CLIENTWEBSITE_TASK_REDESIGN
- MOBILEAPP_CONFIG_FIREBASE
```

**Critical**: NEVER mix prefixes. Framework work uses `AIPM_`, product work uses project-specific prefix.

## Example Memory Content

### Framework Memory (.aipm/memory/local_memory.json)
```json
{"type":"entity","name":"AIPM_PROTOCOL_SESSION_INIT","entityType":"PROTOCOL","observations":["Always load protocols at session start","Search for SESSION_PROTOCOL entities","No work without protocol recall"]}
{"type":"entity","name":"AIPM_WORKFLOW_MEMORY_SYNC","entityType":"WORKFLOW","observations":["Run start.sh before work","Run stop.sh after work","Commit with save.sh"]}
{"type":"relation","from":"AIPM_PROTOCOL_SESSION_INIT","to":"AIPM_WORKFLOW_MEMORY_SYNC","relationType":"requires"}
```

### Product Memory (Product/.aipm/memory/local_memory.json)
```json
{"type":"entity","name":"PRODUCT_TASK_DEPLOY","entityType":"TASK","observations":["Deploy to production server","Update DNS records","Monitor performance"]}
{"type":"entity","name":"PRODUCT_CONFIG_API","entityType":"CONFIG","observations":["API endpoint: https://api.example.com","Auth: Bearer token","Rate limit: 1000/hour"]}
{"type":"relation","from":"PRODUCT_TASK_DEPLOY","to":"PRODUCT_CONFIG_API","relationType":"uses"}
```

## Implementation Scripts

### Core Scripts (in scripts/ directory)
1. **start.sh**: Backs up global, loads local memory
2. **stop.sh**: Saves to local, restores global backup
3. **save.sh**: Commits local memory to git
4. **revert.sh**: Rolls back local memory to previous state

### Safety Features
- Automatic backup creation prevents data loss
- Context detection prevents wrong memory loading
- Prefix validation ensures clean separation
- Session tracking provides audit trail

## Best Practices

### For Framework Users
1. Always run scripts from AIPM root directory
2. Start sessions with explicit context: `./scripts/start.sh --framework` or `./scripts/start.sh --project Product`
3. Run `./scripts/stop.sh` with matching context when finishing
4. Use `./scripts/save.sh` to commit memory changes
5. Never manually edit global memory.json
6. Each project maintains its own `.aipm/` in its git repository

### For Framework Developers
1. Keep memory entities focused and atomic
2. Use clear, descriptive entity names
3. Create relations to build knowledge graphs
4. Document significant patterns in CLAUDE.md
5. Regularly review and clean up memories

## Security Benefits

This approach provides strong isolation:
1. **No Cross-Contamination**: Backup/restore ensures clean separation
2. **No Data Leakage**: Each context only sees its own memories
3. **Audit Trail**: All memory changes are git tracked
4. **Recovery Options**: Backups provide failsafe

## Gitignore Configuration

Add to `.gitignore`:
```
# Memory backups (temporary files)
.aipm/memory/backup.json          # Single backup location in AIPM root

# Global memory symlink (never commit)
.claude/memory.json

# Each project should have its own .gitignore with:
# .aipm/memory/backup.json        # If projects were to have their own backups
```

## Troubleshooting

### Memory Not Loading?
- Check if `local_memory.json` exists in `.aipm/memory/`
- Verify you're in the correct directory
- Ensure backup.json was properly cleaned up

### Conflicting Memories?
- Check entity prefixes (AIPM_ vs PROJECT_)
- Verify context isolation is working
- Review session logs for errors

### Backup Issues?
- Ensure `.aipm/memory/` directory exists
- Check file permissions
- Verify global memory symlink is valid

## Team Collaboration Features

### Memory Sharing Workflow
The backup-restore approach enables powerful team collaboration:

```
Team Member A's Session:
1. ./scripts/start.sh --project Product → Backs up personal global memory
2. Git pull in Product/ → Gets team's shared memories
3. Optional: Merge teammate's memories into session
4. Work with combined knowledge
5. ./scripts/stop.sh --project Product → Saves to Product/.aipm/memory/local_memory.json
6. Personal global memory restored intact!
```

### Benefits for Teams
1. **Personal Memory Protection**: Your global memory is never contaminated
2. **Selective Sharing**: Choose which memories to merge during session
3. **Git-Based Sync**: All team memories version controlled
4. **Conflict Resolution**: Git handles memory merge conflicts
5. **Audit Trail**: Track who contributed which memories

### Example Team Workflow
```bash
# Start session with team sync
./scripts/start.sh --project Product --sync-team

# This could:
# 1. Backup your personal global memory to .aipm/memory/backup.json
# 2. Pull latest from Product/ git repository
# 3. Merge team memories with Product/.aipm/memory/local_memory.json
# 4. Load combined memories into global
# 5. Your personal memories stay safe in backup!

# Work collaboratively...

# End session
./scripts/stop.sh --project Product

# Your changes saved to Product/.aipm/memory/local_memory.json
# Personal memory restored, team never sees other project memories!
```

## Future Enhancements

### Short Term
- Automated context detection
- Memory merge tools for branches
- Better conflict resolution
- Team memory sync features
- Selective memory import/export

### Long Term
- Custom MCP server with proper isolation
- Auto-detection of available projects
- Memory visualization tools
- Real-time team memory sharing
- Cross-project memory insights (with permission)

## Conclusion

The backup-restore memory isolation system provides a practical solution to the global memory problem while maintaining complete separation between framework and project contexts. By using local persistent files and a single temporary backup, we achieve true isolation that scales to N projects. Each project maintains its own `.aipm/` directory in its git repository, enabling portable, version-controlled AI knowledge that travels with the project. The `.aipm/` directory contains both configuration (opinions.json) and memory storage, making AIPM initialization explicit and Unix-like.