# AIPM Documentation Structure Guide

## Purpose
This guide ensures consistent understanding of the dual-track documentation structure in AIPM.

## Core Principle: Separation of Concerns

AIPM maintains strict separation between:
1. **Framework Documentation** - How AIPM works
2. **Product Documentation** - What is being managed using AIPM

## Directory Structure

```
AIPM/                           # Framework root
├── CLAUDE.md                   # Entry point - routing document
├── README.md                   # Framework overview
├── AIPM.md                    # Detailed framework documentation
├── current-focus.md           # Framework development tasks
├── broad-focus.md             # Framework vision
├── changelog.md               # Framework changes
├── AIPM_Design_Docs/          # Technical documentation
│   ├── memory-management.md
│   └── documentation-structure.md  # This file
├── scripts/                   # Session management tools
└── Product/                   # Symlink to product directory
    ├── CLAUDE.md             # Product-specific instructions
    ├── README.md             # Product overview
    ├── current-focus.md      # Product tasks
    ├── broad-focus.md        # Product vision
    └── changelog.md          # Product changes
```

## Documentation Rules for LLMs

### 1. Context Determination
Before ANY action, determine:
- **Where am I?** (AIPM root or Product/)
- **What am I doing?** (Framework development or Product management)
- **Which docs apply?** (Framework docs or Product docs)

### 2. Update Rules
| If working on... | Update these docs | NEVER update these |
|-----------------|-------------------|-------------------|
| Framework features | AIPM root docs | Product/ docs |
| Product management | Product/ docs | AIPM root docs |

### 3. Memory Prefixes
| Context | Memory Prefix | Example |
|---------|--------------|---------|
| Framework | `AIPM_` | AIPM_PROTOCOL_SESSION |
| Product | Project-specific | MYPROJECT_TASK_CREATE |

### 4. Session Workflow
Regardless of context:
1. Start: `./scripts/start.sh` (from AIPM root)
2. Work: In appropriate directory
3. End: `./scripts/stop.sh` (from AIPM root)
4. Save: `./scripts/save.sh` (from AIPM root)

## Reading Order for Onboarding

### Framework Understanding
1. CLAUDE.md (routing)
2. README.md (overview)
3. current-focus.md (tasks)
4. broad-focus.md (vision)
5. changelog.md (history)
6. AIPM.md with sequential thinking (deep dive)

### Product Understanding
1. Navigate to Product/
2. Product/CLAUDE.md (instructions)
3. Product/README.md (overview)
4. Product/current-focus.md (tasks)
5. Product/broad-focus.md (vision)
6. Product/changelog.md (history)

## Common Pitfalls to Avoid

1. **Mixed Updates**: Updating both framework and product docs in one session
2. **Wrong Directory**: Making changes from the wrong location
3. **Prefix Confusion**: Using wrong memory prefixes
4. **Context Switching**: Not clearly transitioning between contexts
5. **Documentation Drift**: Not keeping parallel docs in sync

## Best Practices

1. **One Context Per Session**: Focus on either framework OR product
2. **Clear Commits**: Specify whether changes are framework or product
3. **Consistent Headers**: All docs have context headers
4. **Cross-References**: Point to parallel documentation when relevant
5. **Regular Sync**: Keep documentation structure consistent

## Quick Decision Tree

```
Start Here
    ↓
Am I improving AIPM itself?
    YES → Stay in AIPM root → Update framework docs
    NO ↓
Am I managing a project?
    YES → cd Product/ → Update product docs
    NO ↓
Read CLAUDE.md for clarity
```

## Summary

The AIPM repository is a dual-purpose system:
- **AIPM root**: Framework development
- **Product/**: Project management using AIPM

Always maintain clear boundaries between these contexts to ensure clean, understandable documentation.