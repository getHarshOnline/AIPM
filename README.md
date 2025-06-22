# AIPM - AI Project Manager Framework

**Bringing git-powered decision tracking to every team, not just developers**

## The Problem: Organizational Amnesia

Every organization suffers from the same disease:
- **"Why did we decide this?"** - Hours lost searching through old emails and Slack
- **"What was the context?"** - Critical decisions made without documentation
- **"Who changed what?"** - No audit trail for evolving strategies
- **"Which version is final?"** - Design_v3_final_FINAL_revised.pdf chaos
- **"What did the AI suggest?"** - AI recommendations lost after the chat ends

Whether you're developing software, planning marketing campaigns, designing products, or managing operations - teams waste countless hours reconstructing past decisions and context.

## The Solution: Git for Everything

### The Magic Formula
**Git + AI Memory + Smart Guardrails = Project-wide undo/merge for everyone**

Just like developers can revert code changes, now every team can:
- Revert to last week's marketing strategy
- Merge different design explorations
- Track why decisions changed over time
- Maintain parallel experiments safely

AIPM applies software engineering's most powerful tool - git version control - to ALL types of work:

- **Marketing**: Track campaign evolution, A/B test decisions, brand guideline changes
- **Product Design**: Version control for design decisions, user research insights, feature prioritization
- **Strategy**: Document pivot decisions, market analysis evolution, competitive responses
- **Operations**: Process changes, policy updates, compliance decisions
- **Cross-functional**: Maintain context across teams with isolated workspaces

## How It Works

AIPM creates **isolated workspaces** where:
1. Every decision is tracked in git branches
2. AI assistants maintain persistent memory per workspace
3. Teams can work in parallel without conflicts
4. Context travels with the work, not in someone's head

```bash
# Start working on marketing campaign
./start.sh
> Select workspace: MARKETING_Q1_CAMPAIGN

# AI assistant now has full context of this campaign
# Work naturally - everything is tracked

# Save your progress with context
./save.sh "Finalized influencer strategy based on meeting notes"

# Need to check why we chose Instagram over TikTok?
./revert.sh  # Browse complete decision history
```

## Real-World Use Cases

### Marketing Team
```yaml
workspace: MARKETING_CAMPAIGN_2025
branches:
  - MARKETING_feature/influencer-strategy
  - MARKETING_test/ab-email-subject
  - MARKETING_fix/brand-guidelines
memory: Campaign goals, target demographics, past learnings
```

### Product Design
```yaml
workspace: MOBILE_APP_REDESIGN
branches:
  - DESIGN_feature/onboarding-flow
  - DESIGN_research/user-interviews
  - DESIGN_spike/competitor-analysis
memory: Design principles, user personas, technical constraints
```

### Operations
```yaml
workspace: COMPLIANCE_SOC2
branches:
  - OPS_policy/data-retention
  - OPS_process/incident-response
  - OPS_audit/q4-findings
memory: Compliance requirements, audit history, remediation plans
```

## Key Innovation: Opinion-Driven Workspaces

Each team/project has its own `.aipm/opinions.yaml` that defines:
- **Naming conventions**: How branches are named for that domain
- **Lifecycle rules**: When to archive old decisions
- **Memory categories**: What types of knowledge to track
- **Team workflows**: Review requirements, approval processes

This means marketing can work their way, engineering theirs, and operations differently - all with the same framework.

## Core Benefits

### 🧠 Institutional Memory
- Decisions are preserved with full context
- AI assistants remember project history
- Knowledge transfers seamlessly between team members

### 📝 Decision Auditability
- Every change has a who, what, when, and **why**
- Browse decision history like a time machine
- Compliance-ready audit trails

### 👥 Parallel Collaboration
- Multiple team members work without conflicts
- Merge different perspectives systematically
- No more "who has the latest version?"

### 🔄 Living Documentation
- Documentation evolves with decisions
- Context travels with the work
- No separate "documentation sprint" needed

## Quick Start

### Prerequisites
- Git installed
- Claude Desktop with MCP server support
- MCP servers installed: memory-server, sequential-thinking, Linear (optional)

```bash
# 1. Clone AIPM
git clone https://github.com/getHarshOnline/aipm
cd AIPM

# 2. Initialize AIPM framework
./scripts/init.sh  # Creates directories, state system, and memory symlink

# 3. Start a session (interactive)
./scripts/start.sh

# 4. Work naturally with your AI assistant
# Everything is tracked automatically

# 5. Save progress with context
./save.sh "Description of what was decided/changed"
```

## Who Should Use AIPM?

- **Product Managers**: Track feature decisions and user feedback
- **Marketing Teams**: Version control campaigns and brand evolution
- **Design Teams**: Document design system changes and rationale
- **Operations**: Maintain process documentation and compliance
- **Leadership**: Track strategic decisions and pivots
- **Any Cross-functional Team**: Keep everyone aligned with shared context

## Documentation

- **[AIPM.md](./AIPM.md)** - Detailed framework architecture
- **[.agentrules](./.agentrules)** - How AI assistants should behave
- **[current-focus.md](./current-focus.md)** - Active development priorities
- **[broad-focus.md](./broad-focus.md)** - Long-term vision and strategic objectives
- **[.aipm/docs/](./.aipm/docs/)** - Technical design and architecture documentation

## The AIPM Philosophy

1. **Decisions are assets**: Every decision should be versioned and searchable
2. **Context is king**: The "why" matters more than the "what"
3. **Memory persists**: Organizational knowledge shouldn't die with employee turnover
4. **Tools shape culture**: Give teams git, and they'll think in versions
5. **AI amplifies**: With memory and context, AI becomes a true team member

## License & Ownership

**Maintained by**: [RawThoughts Enterprises Private Limited (RTEPL)](https://rawthoughts.in)
**Project Website**: [https://rawthoughts.in/aipm](https://rawthoughts.in/aipm)
**GitHub Repository**: [getHarshOnline/aipm](https://github.com/getHarshOnline/aipm)

**Ownership**: This project is owned by its contributors as documented in the git contribution history of this repository. RawThoughts Enterprises Private Limited (RTEPL) maintains the project but does not claim ownership.
**Created by**: [Harsh Joshi](https://getharsh.in)

**Sponsored by [AION](https://aion.xyz)** through:
- Providing work flexibility and development time
- Funding Claude AI credits for development and testing
- Internal dogfooding across all departments
- Proving that non-developers can use git workflows

Licensed under Apache License 2.0 - see [LICENSE](./LICENSE)

---

*AIPM: Because every team deserves git's superpowers, not just developers*