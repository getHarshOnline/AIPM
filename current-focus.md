# Current Focus - AIPM Framework

> **Context**: This document tracks AIPM framework development only. For product-specific tasks, see `./Product/current-focus.md`

## AIPM Framework Development

### Recently Completed (2025-06-20)
- [x] Cleaned framework documentation to remove project-specific content
- [x] Renamed AI-PROJECT-MANAGER.md to AIPM.md
- [x] Created comprehensive memory-management.md in AIPM_Design_Docs/
- [x] Added Apache License 2.0 with proper attribution
- [x] Created README.md with framework overview
- [x] Updated all documentation references for consistency
- [x] Established clear framework/project separation
- [x] Created boilerplate session management scripts (start.sh, stop.sh, save.sh, revert.sh)
- [x] Created utility scripts (cleanup-global.sh, migrate-memories.sh)
- [x] Reorganized all .sh scripts into scripts/ directory
- [x] Updated all shebangs to use /opt/homebrew/bin/bash
- [x] Restructured documentation for clear framework/product separation
- [x] Simplified CLAUDE.md as entry point with two-track onboarding
- [x] Added context headers to all documentation files

### Core Framework Features (In Progress)
- [x] Complete protocol-driven development system
- [x] Document memory management with branch-based isolation design
- [ ] Implement session management scripts (start.sh, stop.sh, save.sh, revert.sh)
- [x] Document framework architecture and best practices

### Memory Management Solution
- [ ] Implement session-based memory management
- [ ] Use git branch-based memory isolation
- [ ] Fix global memory pollution issue documented in AIPM_Design_Docs/memory-management.md
- [ ] Create memory backup and restore mechanisms

### Framework Infrastructure
- [x] Initialize git repository with clean structure
- [x] Create core documentation (CLAUDE.md, AIPM.md)
- [x] Configure MCP servers (Sequential Thinking, Memory)
- [x] Establish protocol entities in memory system
- [x] Create feedback loop between memory and documentation
- [x] Implement guardrail protocols for enforcement

## Immediate Priorities

### Phase 1: Framework Core
- [x] Set up base MCP configuration structure
- [x] Create protocol-driven development workflow
- [x] Establish memory system for protocol storage
- [ ] Build session management scripts
- [ ] Create framework template structure

### Phase 2: Project Integration System
- [x] Design symlink-based project data separation (Product/ symlink implemented)
- [ ] Create project onboarding workflow
- [x] Build project-specific MCP configuration system (Linear example in place)
- [x] Document project integration patterns (in AIPM.md)

### Phase 3: Framework Tools
- [ ] Develop protocol validation tools
- [ ] Create memory visualization utilities
- [ ] Build project scaffolding templates
- [ ] Implement framework testing suite

## Current Goals
- Build a reusable AI project management framework
- Enable protocol-driven development for any project type
- Create clean separation between framework and project data
- Solve memory isolation challenges for multi-project use

## Next Steps
1. Complete session management scripts
2. Document framework architecture thoroughly
3. Create project integration templates
4. Build example project implementations