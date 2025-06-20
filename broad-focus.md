# Broad Focus - AIPM Framework

> **Context**: This document defines the AIPM framework vision only. For product-specific vision, see `./Product/broad-focus.md`

## Vision
Create a protocol-driven AI Project Management framework that enables structured, repeatable, and scalable project execution with Claude Code.

## Core Objectives

### 0. ⚠️ CRITICAL FOUNDATION - version-control.sh
- **version-control.sh is THE CORE FOUNDATION** - without it, nothing works
- Must provide bulletproof git operations for the entire framework
- shell-formatting.sh provides single source of truth for ALL output
- Modularity and maintainability are NON-NEGOTIABLE
- start/stop/save/revert are thin orchestration wrappers ONLY
- This component CANNOT fail - it must be perfect

### 1. Protocol-Driven Development
- Establish mandatory protocol system for all AI interactions
- Create memory-based protocol storage and evolution
- Enforce protocol compliance through guardrails

### 2. Framework Architecture
- Build reusable components for any project type
- Enable clean separation of framework and project data
- Support multiple concurrent projects via isolation

### 3. Memory Management System
- Implement branch-based memory isolation
- Create session management for memory persistence
- Solve global memory pollution challenges

### 4. Developer Experience
- Provide clear onboarding and integration patterns
- Create comprehensive documentation and examples
- Build tools for protocol validation and debugging

## Success Metrics
- Framework can support any project type without modification
- Memory isolation prevents cross-project contamination
- Protocol system ensures consistent AI behavior
- Clean architecture enables easy maintenance and updates

## Constraints
- Must work within Claude Code's MCP limitations
- Memory system must handle npm package constraints
- Framework should require minimal setup for new projects
- All protocols must be version-controlled and auditable