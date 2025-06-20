# AIPM - AI Project Manager Framework

A protocol-driven framework for AI-assisted project management using Claude Code.

> **Note**: This README describes the AIPM framework itself. For product-specific documentation, see `./Product/README.md`

## Overview

AIPM (AI Project Manager) is a reusable framework that enables structured, repeatable, and scalable project execution with Claude Code. It provides a protocol-driven development methodology, memory management system, and clean separation between framework code and project data.

## Credits

- **Created by**: Harsh Joshi ([getharsh.in](https://getharsh.in))
- **Copyright Owner**: AION ([AION.xyz](https://AION.xyz))
- **License**: Apache License 2.0

This is an open-source framework created by Harsh Joshi and owned by AION.

## License Scope

This repository is licensed under the Apache License 2.0. This license applies to:
- The AIPM framework code and architecture
- All documentation in this repository
- Session management scripts and utilities
- Memory management solutions

This license does NOT apply to:
- Any content in the `Product/` directory (excluded via .gitignore)
- Project-specific data stored via symlinks
- Third-party MCP server implementations

## Key Features

### Protocol-Driven Development
- Mandatory protocol system for all AI interactions
- Memory-based protocol storage and evolution
- Guardrail enforcement for protocol compliance

### Memory Management
- Backup-restore memory isolation system
- Complete separation between framework and project memories
- Git-versioned local memory files
- Team collaboration through memory sharing

### Multi-Project Support
- Standardized project structure for all projects
- Each project maintains its own `.memory/` directory
- Centralized script management from AIPM root
- Scales to unlimited projects with identical architecture

## Working with AIPM

### First Time Setup
1. **Read CLAUDE.md** - Understand the two-track structure
2. **Choose your track**:
   - Framework development → Stay in AIPM root
   - Product management → Navigate to `./Product/`
3. **Follow track-specific onboarding** in CLAUDE.md

### Documentation Coordination
This repository uses decentralized documentation with clear boundaries:

| Document | Framework Version | Product Version | Purpose |
|----------|------------------|-----------------|---------|
| CLAUDE.md | AIPM root | Product/ | Entry point & routing |
| README.md | AIPM root | Product/ | Overview & quick start |
| current-focus.md | AIPM root | Product/ | Active tasks |
| broad-focus.md | AIPM root | Product/ | Vision & strategy |
| changelog.md | AIPM root | Product/ | Change history |

**Critical**: ALWAYS update documentation in the correct location based on your current work context.

## Getting Started

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd AIPM
   ```

2. **Configure MCP servers**
   ```bash
   # Required servers
   claude mcp add sequential-thinking npx -- -y @modelcontextprotocol/server-sequential-thinking
   claude mcp add memory npx -- -y @modelcontextprotocol/server-memory
   
   # Optional: Add project-specific servers
   claude mcp add linear npx mcp-remote https://mcp.linear.app/sse
   ```

3. **Start a session**
   ```bash
   # For framework development
   ./scripts/start.sh --framework
   
   # For project work
   ./scripts/start.sh --project Product
   ```

4. **Work with Claude Code**
   - Follow protocols in CLAUDE.md
   - Use sequential thinking for all tasks
   - Store new patterns in memory

5. **End session and save**
   ```bash
   # Must match start.sh context
   ./scripts/stop.sh --framework
   # or
   ./scripts/stop.sh --project Product
   
   # Commit changes
   ./scripts/save.sh --framework "Updated framework docs"
   # or
   ./scripts/save.sh --project Product "Fixed deployment"
   ```

## Documentation

- **CLAUDE.md**: Entry point with two-track routing (framework vs project)
- **AIPM.md**: Comprehensive framework architecture and design
- **AIPM_Design_Docs/memory-management.md**: Backup-restore memory isolation
- **AIPM_Design_Docs/documentation-structure.md**: Documentation guidelines
- **current-focus.md**: Active framework development tasks
- **broad-focus.md**: Framework vision and objectives

**Note**: Each project has its own parallel documentation structure

## Project Structure

```
AIPM/                          # Framework root
├── .memory/                   # Framework memory
│   ├── local_memory.json     # Persistent framework memory
│   └── backup.json          # Temporary backup (gitignored)
├── .claude/                   # Claude Code configuration
│   ├── settings.local.json   # MCP server configuration
│   └── memory.json          # Symlink to global (DO NOT COMMIT)
├── AIPM_Design_Docs/         # Framework design documentation
├── scripts/                  # Session management (run from root)
│   ├── start.sh             # ./scripts/start.sh --framework|--project NAME
│   ├── stop.sh              # ./scripts/stop.sh --framework|--project NAME
│   ├── save.sh              # ./scripts/save.sh --framework|--project NAME
│   └── revert.sh            # ./scripts/revert.sh --framework|--project NAME
├── Product/                  # Project 1 (symlinked git repo)
│   ├── .memory/             # Project's AI memory
│   │   └── local_memory.json
│   ├── data/                # Actual project data
│   ├── CLAUDE.md            # Project-specific instructions
│   ├── README.md            # Project documentation
│   ├── current-focus.md     # Active tasks
│   └── broad-focus.md       # Project vision
└── [ProjectName]/           # Future projects (same structure)
```

## Contributing

Contributions to the AIPM framework are welcome! Please ensure:
1. Follow the protocol-driven development methodology
2. Update relevant documentation
3. Test memory isolation features
4. Submit changes via pull request

## Known Issues & Solutions

- **Issue**: Memory server ignores MEMORY_FILE_PATH environment variable
- **Solution**: Backup-restore mechanism provides complete isolation
- **Result**: Each project maintains completely separate AI memory
- **Benefit**: Team collaboration enabled through git-based memory sharing

See `AIPM_Design_Docs/memory-management.md` for details.

## Support

For questions or issues:
- Review documentation in this repository
- Check the design docs in AIPM_Design_Docs/
- Visit: [getharsh.in](https://getharsh.in)

---

Copyright 2025 AION ([AION.xyz](https://AION.xyz))

Created by Harsh Joshi ([getharsh.in](https://getharsh.in))

Licensed under the Apache License, Version 2.0