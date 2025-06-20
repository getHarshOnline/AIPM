# Changelog - AIPM Framework

> **Context**: This tracks AIPM framework changes only. For product-specific changes, see `./Product/changelog.md`

## [Unreleased]

## 2025-06-20 - Critical Bug Discovery & save.sh Re-implementation

### Fixed
- **save.sh** - Re-implemented after discovering file reversion bug
  - Original implementation was lost due to Claude Code file reversion
  - Re-implemented with full shell-formatting.sh and version-control.sh integration
  - Now properly follows workflow.md patterns like other wrapper scripts

### Discovered
- **CRITICAL: Claude Code File Reversion Bug**
  - Files can spontaneously revert to previous states during a session
  - System reminders about "file modified by user or linter" indicate reversions
  - Can cause complete loss of implemented code
  - Added comprehensive guardrails to CLAUDE.md to prevent future incidents

## 2025-06-20 - AIPM Wrapper Scripts Implementation

### Added
- **start.sh** - Complete session initialization implementation
  - Memory symlink verification with sync-memory.sh integration
  - Interactive project selection using shell-formatting.sh menus
  - Git synchronization with version-control.sh functions
  - Memory backup/restore isolation pattern
  - Session metadata tracking
  - Claude Code launch with argument passthrough
  
- **stop.sh** - Complete session cleanup implementation
  - Active session detection and validation
  - Automatic save.sh integration
  - Memory restoration from backup
  - Session artifact archival
  - Duration calculation and statistics
  
- **save.sh** - Complete memory persistence implementation
  - Global to local memory transfer
  - Backup restoration after save
  - Git commit integration with commit_with_stats
  - Golden rule enforcement (stage_all_changes)
  - Context-aware path handling
  
- **revert.sh** - Complete memory version control implementation
  - Active session safety checks with save option
  - Interactive context and commit selection
  - Git history display with show_log
  - Preview changes before revert
  - Automatic backup before revert
  - Post-revert statistics and next steps

### Implementation Patterns
- All scripts follow workflow.md patterns strictly
- NO direct echo/printf - only shell-formatting.sh functions
- NO direct git commands - only version-control.sh functions
- Consistent error handling with die() for fatal errors
- Visual feedback with sections, steps, and status messages
- Interactive prompts using confirm() and format_prompt()

## 2025-06-20 - Version Control Hardening & Workflow Documentation

### Added
- **version-control.sh testing** - Achieved 100% test coverage
  - Fixed environment detection bug (removed forced AIPM_COLOR=true)
  - Added missing return statements in fetch_remote and pull_latest
  - Documented test status inline for all 41 functions
  - Created comprehensive test suite validating all functions
  
- **scripts/test/version-control.md** - Complete implementation documentation
  - 899 lines of exhaustive documentation
  - Function reference with exact line numbers
  - Integration patterns for all wrapper scripts
  - Test coverage summary and quality metrics
  
- **scripts/test/workflow.md** - Single source of truth for wrapper implementation
  - Exact file references and line numbers
  - Function mapping tables from shell-formatting.sh and version-control.sh
  - Implementation guardrails with ❌ WRONG and ✅ CORRECT examples
  - Script-by-script implementation guide
  - Testing workflow and branch structure
  - Quick reference card for essential functions

### Changed
- **CLAUDE.md** - Added critical implementation directives
  - Mandatory workflow.md reference for wrapper scripts
  - NO DIRECT OUTPUT rule (only shell-formatting.sh)
  - NO DIRECT GIT rule (only version-control.sh)
  - Test incrementally directive

- **current-focus.md** - Updated with implementation rules
  - Added wrapper script implementation guidelines
  - Referenced workflow.md as mandatory reading
  - Updated testing status for version-control.sh

### Fixed
- **version-control.sh** - Critical bug fixes
  - Environment detection now works correctly in all contexts
  - Functions return proper exit codes consistently
  - DID_STASH tracking works correctly across function calls

## 2025-06-20 - Base Helper Scripts Implementation

### Added
- **shell-formatting.sh** - Comprehensive formatting utilities
  - Color support with automatic detection and fallbacks
  - Unicode symbols with ASCII alternatives
  - Progress bars: simple and advanced with item lists
  - Message functions: error, warn, success, info, step, section
  - Error handling with traps and assertions
  - Visual elements: box drawing, separators
  - Input helpers: confirm, prompt_value
  - Utility functions: format_size, format_duration, center_text
  - Logging functions with structured output
  - **Hardened**: Socket/REPL compatibility, stderr suppression
  - **Optimized**: Cached platform detection, direct ANSI codes

- **version-control.sh** - Git wrapper utilities
  - Full integration with shell-formatting.sh (no echo statements!)
  - Repository and branch management functions
  - Enhanced status display with categorized output
  - Smart push/pull with auto-stash handling
  - Commit creation with statistics and formatting
  - Branch operations with safety checks
  - Merge and conflict resolution helpers
  - History and diff visualization
  - Tag management with semantic versioning
  - Advanced operations: undo_last_commit, create_backup_branch
  - Interactive conflict resolution
  - Cleanup utilities for merged branches

### Changed
- **sync-memory.sh** - Enhanced with visual feedback
  - Integrated shell-formatting.sh for consistent output
  - Added step-by-step progress indicators
  - Improved error messages and status display
  - File size formatting using format_size
  - Structured sections for better readability

### Implementation Details
- All scripts follow "no echo" principle - using printf throughout
- Consistent error handling with specific exit codes
- Progress indication for long-running operations
- REPL/socket environment compatibility
- Performance optimizations without losing functionality
- Comprehensive inline documentation and learning notes

## 2025-06-20 - Framework Prototype Complete

### 🎉 Milestone: Idea → Prototype | Done | Now let's build it for deployment

This marks the completion of the AIPM framework prototype phase. All core concepts have been designed, documented, and scaffolded. The framework is ready for implementation.

### Changed
- Restructured documentation for clear framework/product separation
- Simplified CLAUDE.md as routing document with two-track onboarding
- Added context headers to all framework documentation files
- Updated all docs to reference dual-track structure
- Redesigned memory management from session-based to backup-restore isolation
- Updated all scripts to use explicit --framework or --project flags
- Changed from branch-based to project-based memory isolation
- All operations now run from AIPM root directory
- Cleaned up memory MCP server configuration (removed unused MEMORY_FILE_PATH)

### Added
- AIPM_Design_Docs/documentation-structure.md - Guide for LLMs on dual-track structure
- Documentation coordination table in README.md
- Clear context headers in all documentation files
- Strict memory prefix separation rules
- Backup-restore memory isolation design in memory-management.md
- Team collaboration memory sharing workflow
- .memory/backup.json entries to .gitignore
- Multi-project support architecture
- Standardized project structure requirements
- Project-specific .memory/ directories
- Single backup location design (.memory/backup.json)
- Placeholder JSON files for memory structure verification
- Product/.gitignore for project-specific ignores

### Script Enrichment
- **start.sh**: Full implementation blueprint with 7 detailed tasks
- **stop.sh**: Session cleanup flow with save.sh integration
- **save.sh**: Core memory persistence logic documented
- **revert.sh**: Version control integration for memory time travel
- **shell-formatting.sh**: Common formatting utilities library
- **version-control.sh**: Git wrapper with opinionated workflow

### Framework Architecture Finalized
- Each project maintains its own git repository
- Projects own their `.memory/local_memory.json` files
- Complete isolation between framework and project memories
- Scripts support unlimited projects with --project NAME syntax
- All projects follow identical structure (data/, .memory/, docs)
- Backup-restore mechanism provides complete memory isolation
- Team collaboration enabled through git-based memory sharing

### Ready for Implementation
The framework prototype is complete with:
- ✅ Comprehensive documentation
- ✅ Memory isolation architecture
- ✅ Script blueprints with detailed TODOs
- ✅ Multi-project support design
- ✅ Team collaboration workflow
- ✅ Utility libraries scaffolded
- ✅ Git workflow defined

**Next Phase**: Implementation of session management scripts

## 2025-06-20 - Framework Documentation Cleanup

### Changed
- Renamed AI-PROJECT-MANAGER.md to AIPM.md for consistency
- Removed all project-specific content from framework documentation
- Updated all file references to use new AIPM.md filename
- Cleaned memory.json to remove Linear-specific entities

### Added  
- README.md with proper framework overview
- Apache License 2.0 with attribution to AION and creator credit to Harsh Joshi
- Moved and rewrote MEMORY-ISOLATION-ISSUE.md to AIPM_Design_Docs/memory-management.md
- Boilerplate session management scripts in scripts/ directory:
  - start.sh - Session initialization
  - stop.sh - Session cleanup
  - save.sh - Memory versioning
  - revert.sh - Memory rollback
  - cleanup-global.sh - Emergency cleanup
  - migrate-memories.sh - Migration tool
- All scripts use /opt/homebrew/bin/bash shebang

### Removed
- linear-workspace-data-summary.md (project-specific file)
- All Linear-specific content from documentation
- Old AI-PROJECT-MANAGER.md file

### Framework Status
- Protocol-driven development system: Complete
- Memory management design: Documented
- Session management scripts: Planned but not implemented
- Project integration patterns: Documented with Linear as example

### Added
- AIPM (AI Project Manager) framework initialization
- Protocol-driven development methodology
- Memory management system with entity/relation schema
- Session management architecture (start.sh, stop.sh, save.sh, revert.sh)
- MCP server integration patterns
- Project data separation via symlinks
- Comprehensive framework documentation

### Framework Components
- **CLAUDE.md**: Core framework documentation and usage guide
- **AIPM.md**: Executive and developer guide with architecture
- **AIPM_Design_Docs/memory-management.md**: Comprehensive memory system documentation
- **current-focus.md**: Framework development priorities
- **broad-focus.md**: Framework vision and objectives

### MCP Integration
- Sequential Thinking server for mandatory task breakdown
- Memory server for protocol and knowledge persistence
- Example: Linear MCP server integration pattern
- Configuration via `.claude/settings.local.json`

### Protocol System
- SESSION_PROTOCOL_INIT: Session initialization requirements
- SESSION_PROTOCOL_SEQUENTIAL: Sequential thinking usage
- SESSION_PROTOCOL_MEMORY: Memory storage patterns
- PROTOCOL_FEEDBACK_LOOP: Documentation-memory synchronization
- GUARDRAIL_PROTOCOL_COMPLIANCE: Protocol enforcement

### Memory Schema Documentation
- Newline-delimited JSON format specification
- Entity structure: type, name, entityType, observations
- Relation structure: type, from, to, relationType
- Schema constraints and validation rules

### Known Issues
- Memory server ignores MEMORY_FILE_PATH environment variable
- All projects share global memory storage
- Workaround: Symlink and session-based memory management

## Format
This changelog follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format.