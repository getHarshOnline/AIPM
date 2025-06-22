# AIPM Project Templates

This directory contains templates for initializing new AIPM workspaces.

## Available Templates

### default.yaml (Coming Soon)
Standard project template with basic configuration.

### web-project.yaml (Coming Soon)
Template for web development projects with deployment branches.

### marketing.yaml (Coming Soon)
Template for marketing teams with campaign-focused branching.

### design.yaml (Coming Soon)
Template for design teams with iteration and review cycles.

## How Templates Work

When you run `./scripts/init.sh --project MyProject --template marketing`:

1. AIPM copies the template to `MyProject/.aipm/opinions.yaml`
2. Updates the workspace name and prefix
3. Initializes the workspace branches
4. Sets up the memory structure

## Creating Custom Templates

To create a template for your organization:

1. Copy `.aipm/opinions.yaml` as a starting point
2. Customize the settings for your workflow
3. Save as `.aipm/templates/your-org.yaml`
4. Teams can now use: `./scripts/init.sh --template your-org`

---

*Templates enable consistent workspace initialization across teams.*