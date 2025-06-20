# Changelog - AIPM Framework

> **Context**: This tracks AIPM framework changes only. For product-specific changes, see `./Product/changelog.md`

## [Unreleased]

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