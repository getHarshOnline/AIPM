# AIPM Technical Documentation Hub

This directory contains the complete technical documentation for the AIPM framework. 

## Documentation Philosophy

AIPM documentation follows these principles:
1. **Workspace Isolation**: Each workspace (framework/project) maintains its own documentation
2. **No Redundancy**: Each concept is documented once in the right place
3. **Current State**: Documentation reflects what IS, not what was or might be
4. **Clear Navigation**: Easy to find what you need

## Current Directory Structure

```
AIPM/                              # Framework workspace
├── .aipm/                         # THE AIPM HUB
│   ├── opinions.yaml             # Framework configuration (CORNERSTONE)
│   ├── memory/                   # Persistent memory storage
│   ├── scripts/                  # All AIPM scripts
│   │   ├── modules/              # Core modules
│   │   └── test/                 # Active development
│   ├── docs/                     # This directory
│   │   ├── DOCS.md              # You are here
│   │   ├── memory-management.md  # Memory architecture
│   │   ├── version-control.md    # Git operations module
│   │   └── workflow.md          # Implementation patterns
│   └── templates/                # Project templates
│
├── .agentrules                   # AI behavior rules (was CLAUDE.md)
├── AIPM.md                       # Architecture overview
├── README.md                     # Problem & solution
├── current-focus.md              # Active tasks
├── broad-focus.md                # Future vision
├── changelog.md                  # Change history
│
└── YourProject/                  # Symlinked project
    └── .aipm/                    # Project configuration
        ├── opinions.yaml         # Project-specific rules
        └── memory/               # Project memory
```

## Documentation Layers

### 1. Entry Points (Root Directory)
- **README.md**: The problem AIPM solves (organizational amnesia)
- **AIPM.md**: Gentle architectural introduction
- **.agentrules**: How AI assistants must work with AIPM

### 2. Progress Tracking (Root Directory)
- **current-focus.md**: What's being worked on now
- **broad-focus.md**: Long-term vision and future features
- **changelog.md**: What has been done

### 3. Technical Documentation (This Directory)
- **memory-management.md**: Deep dive into memory isolation
- **version-control.sh**: Module reference and functions
- **workflow.md**: Implementation patterns and guardrails
- **~~documentation-structure.md~~**: (DEPRECATED - merged into this file)

### 4. Active Development (.aipm/scripts/test/)
- **wrapper-scripts-hardening-plan.md**: Current refactoring plan

## Documentation Status

### ✅ Current and Accurate
- **.agentrules**: Updated with new structure and guardrails
- **README.md**: Reflects vision of git for all teams
- **AIPM.md**: Architecture with mermaid diagrams
- **broad-focus.md**: Expansive future vision
- **changelog.md**: Up to date through 2025-06-21

### ⚠️ Needs Update
- **memory-management.md**: Still references old .memory/ structure
- **version-control.md**: Needs to reflect opinions-loader.sh integration
- **workflow.md**: Needs to reference new .aipm/ paths

### 📝 To Be Created
- **opinions-architecture.md**: Deep dive into the cornerstone
- **module-reference.md**: Complete API for all modules
- **testing-guide.md**: How to test AIPM components

## Quick Navigation Guide

| I need to... | Read this... |
|-------------|--------------|
| Understand what AIPM solves | [README.md](../../README.md) |
| Understand the architecture | [AIPM.md](../../AIPM.md) |
| Know the AI rules | [.agentrules](../../.agentrules) |
| See current priorities | [current-focus.md](../../current-focus.md) |
| Understand memory system | [memory-management.md](./memory-management.md) |
| Implement a wrapper | [workflow.md](./workflow.md) |
| Use git operations | [version-control.md](./version-control.md) |
| See refactoring plan | `.aipm/scripts/test/wrapper-scripts-hardening-plan.md` |

## Workspace Documentation Pattern

Each workspace (framework or project) maintains these documents:

```
workspace/
├── .aipm/
│   ├── opinions.yaml      # Workspace configuration
│   └── memory/           # Workspace memory
├── .agentrules           # AI behavior rules (optional)
├── README.md             # What this workspace is
├── current-focus.md      # Active tasks
├── broad-focus.md        # Vision for this workspace
└── changelog.md          # History of changes
```

## Update Protocol

When updating documentation:

1. **Determine Workspace**: Which workspace are you in?
2. **Find Right Document**: Use the navigation guide above
3. **Update in Place**: Don't create redundant docs
4. **Cross-Reference**: Link to related documents
5. **Update Status**: Mark in this file if creating new docs

## The Cornerstone: opinions.yaml

Every workspace's behavior is driven by `.aipm/opinions.yaml`:
- Defines branch prefixes and patterns
- Sets memory categories and rules
- Controls lifecycle automation
- Enables complete workspace isolation

This is THE innovation that makes AIPM work for any team.

---

*For the current refactoring effort, see `.aipm/scripts/test/wrapper-scripts-hardening-plan.md`*