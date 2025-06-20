# CLAUDE.md - AIPM Framework Entry Point

## 🚦 START HERE: Two Distinct Tracks

You are working with **AIPM (AI Project Manager)**, a protocol-driven framework for AI-assisted project management. There are TWO separate contexts to understand:

### ⚠️ CRITICAL IMPLEMENTATION DIRECTIVES

#### When implementing wrapper scripts (start.sh, stop.sh, save.sh, revert.sh):
**MANDATORY**: Read `scripts/test/workflow.md` FIRST - it is the single source of truth
- **NO DIRECT OUTPUT**: Never use echo/printf - ONLY shell-formatting.sh functions
- **NO DIRECT GIT**: Never use git commands - ONLY version-control.sh functions
- **FOLLOW GUARDRAILS**: Workflow.md has exact line references and patterns
- **TEST INCREMENTALLY**: Implement section by section, test before proceeding

#### When working on version-control.sh or shell-formatting.sh:
- These are CORE FOUNDATIONS that CANNOT fail
- version-control.sh: ALL git operations go through these functions
- shell-formatting.sh: ALL output goes through these functions
- Modularity is MANDATORY - each function must be independently testable
- 100% test coverage achieved on version-control.sh - maintain this standard

### Track 1: AIPM Framework Development
**Purpose**: Understanding and developing the AIPM framework itself  
**Location**: Current directory (AIPM root)

### Track 2: Product Management
**Purpose**: Using AIPM to manage a specific product/project  
**Location**: Work from AIPM root, target `Product/` via scripts

---

## 📍 CRITICAL: Determine Your Context First

Before proceeding, you MUST determine which track you're working on:

1. **Framework Work**: Improving AIPM itself
2. **Product Work**: Managing a project using AIPM

**NEVER mix these contexts. Always update ONLY the relevant documentation.**

---

## 🚀 Track 1: AIPM Framework Onboarding

### Initial Understanding (Read in Order)
1. **README.md** - Framework overview and quick start
2. **current-focus.md** - Active framework development tasks
3. **broad-focus.md** - Framework vision and objectives
4. **changelog.md** - Recent framework changes

### Deep Understanding
```
Use mcp__sequential-thinking__sequentialthinking to analyze AIPM.md
This will give you complete framework architecture understanding
```

### Framework Documentation Structure
```
AIPM/
├── CLAUDE.md          # This file - entry point
├── README.md          # Framework overview
├── AIPM.md           # Detailed framework documentation
├── current-focus.md   # Active framework tasks
├── broad-focus.md     # Framework vision
├── changelog.md       # Framework history
├── AIPM_Design_Docs/  # Technical design documents
│   └── memory-management.md
└── scripts/           # Session management tools
```

---

## 🎯 Track 2: Product Management Onboarding

### ⚠️ Key Difference from Framework Work
- **Stay in AIPM root directory**
- **Use `--project Product` flag with all scripts**
- **Project files are in `Product/` but you work from root**

### Important: All Operations from AIPM Root
```bash
# DO NOT cd into Product/
# Use: ./scripts/start.sh --project Product
```

### Initial Understanding (Read in Order)
1. **Product/README.md** - Product overview
2. **Product/current-focus.md** - Active product tasks
3. **Product/broad-focus.md** - Product vision
4. **Product/changelog.md** - Recent product changes

### Product-Specific Instructions
```
Read Product/CLAUDE.md for product-specific protocols
```

### Standardized Project Structure
```
Product/                 # Or any project name (symlinked git repo)
├── .memory/            # AI memory for this project
│   └── local_memory.json  # Git-tracked AI knowledge
├── data/               # ACTUAL PROJECT DATA GOES HERE
│   ├── [databases]
│   ├── [exports]
│   └── [any project files]
├── CLAUDE.md           # Project-specific AI instructions
├── README.md           # Project documentation
├── current-focus.md    # Active tasks
├── broad-focus.md      # Project vision
└── changelog.md        # Project history
```

**CRITICAL**: This structure is mandatory for ALL projects

---

## ⚠️ CRITICAL RULES

### 1. Context Isolation
- **NEVER** update framework docs when doing product work
- **NEVER** update product docs when doing framework work
- **ALWAYS** verify your current directory before making changes

### 2. Memory Management
- Framework memories use prefix: `AIPM_`
- Product memories use project name prefix (e.g., `PRODUCT_`)
- ALWAYS run scripts from AIPM root directory
- Use explicit context: `./scripts/start.sh --framework` or `./scripts/start.sh --project Product`
- End with matching context: `./scripts/stop.sh --framework` or `./scripts/stop.sh --project Product`

### 3. Documentation Updates
- Framework improvements → Update AIPM framework docs only
- Product work → Update Product/ docs only
- Each domain maintains its own:
  - current-focus.md
  - broad-focus.md
  - changelog.md

---

## 🔄 Session Workflow

### For ANY Work Session
```bash
# 1. Start session (ALWAYS from AIPM root)
./scripts/start.sh --framework  # For framework work
# OR
./scripts/start.sh --project Product  # For project work

# 2. Stay in AIPM root directory
#    NO NEED to cd into Product/

# 3. Read relevant current-focus.md

# 4. Do your work

# 5. Update relevant documentation

# 6. End session (from AIPM root, match start context)
./scripts/stop.sh --framework  # If started with --framework
# OR
./scripts/stop.sh --project Product  # If started with --project

# 7. Save changes
./scripts/save.sh --framework "Description"  # For framework
# OR
./scripts/save.sh --project Product "Description"  # For project
```

---

## 📚 Key Framework Concepts

For detailed understanding, see:
- **Protocol System**: AIPM.md → Protocol-Driven Development
- **Memory Management**: AIPM_Design_Docs/memory-management.md
- **Session Scripts**: AIPM.md → Session Management Scripts
- **Documentation Structure**: AIPM_Design_Docs/documentation-structure.md

---

## 🎭 Role Clarity

When working in this repository, you are either:
1. **Framework Developer**: Improving AIPM's capabilities
2. **Product Manager**: Using AIPM to manage a specific project

**Always be clear about which role you're in.**

---

## 🆘 Quick Reference

| Question | Answer |
|----------|--------|
| What is AIPM? | Read README.md |
| What needs doing? | Read current-focus.md (framework or product) |
| What's the vision? | Read broad-focus.md (framework or product) |
| What changed recently? | Read changelog.md (framework or product) |
| How does it work? | Use sequential thinking on AIPM.md |

---

## 📈 Multi-Project Scaling

When you have multiple projects:

```bash
AIPM/
├── Product/           # Current project
├── ClientWebsite/     # Another project (same structure)
├── MobileApp/         # Another project (same structure)
└── DataPipeline/      # Another project (same structure)
```

**Usage:**
```bash
./scripts/start.sh --project ClientWebsite
./scripts/stop.sh --project ClientWebsite
```

Each project:
- Is a separate git repository
- Maintains its own `.memory/local_memory.json`
- Follows identical structure
- Has complete isolation from other projects

---

*Remember: This is a multi-project framework. Always maintain clear separation between framework development and project management.*