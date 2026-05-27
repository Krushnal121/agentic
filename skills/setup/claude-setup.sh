#!/bin/bash

# Enhanced Claude Code Setup Functions
# Handles safe creation of CLAUDE.md and individual rule files

# Source the merge-rules script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/merge-rules.sh" 2>/dev/null || echo "Warning: merge-rules.sh not found"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Create or update main CLAUDE.md file
create_claude_main_file() {
    local skills_path="${1:-skills}"
    local backup="${2:-true}"
    
    local claude_content="# Agentic Skills - Auto-Loading Rules

This file enables automatic skill loading based on your project context. Skills are loaded conditionally to minimize context overhead while ensuring the right expertise is available when needed.

## Universal Rules (Always Active)

- **ALWAYS** read the relevant \`$skills_path/<skill-name>/SKILL.md\` BEFORE writing any code or creating any file (if the skill exists)
- **NEVER** skip skill loading even for \"simple\" versions of covered tasks
- Skills contain critical patterns, constraints, and best practices for their domain

## File Type Triggers (When Skills Are Installed)

When working with these file types, the corresponding skill loads automatically if installed:

- **Word documents** (\`.docx\`) → Load \`$skills_path/docx/SKILL.md\` (if exists)
- **PDF files** (\`.pdf\`) → Load \`$skills_path/pdf/SKILL.md\` (if exists)
- **Presentations** (\`.pptx\`) → Load \`$skills_path/pptx/SKILL.md\` (if exists)
- **Spreadsheets** (\`.xlsx\`) → Load \`$skills_path/xlsx/SKILL.md\` (if exists)
- **Uploaded files** not yet in context → Load \`$skills_path/file-reading/SKILL.md\` (if exists)

## Language-Specific Rules

Language skills are stored in separate \`.claude/rules/agentic-<lang>-<version>.md\` files to avoid bloating this root file. The setup skill creates these files only for installed skills with their specific versions.

## Versioned Skill Installation

This configuration supports mixed skill and version installation:
- Install Go 1.26: Gets \`.claude/rules/agentic-go-1.26.md\`
- Install Python 3.12: Gets \`.claude/rules/agentic-python-3.12.md\`
- All skills and versions work independently without conflicts

## How It Works

1. **Conditional Loading**: Language skills only activate when you're primarily working with that language
2. **Context Optimization**: Only installed skills load, keeping context lean and focused
3. **Expertise On-Demand**: The right domain knowledge appears exactly when needed
4. **Zero Manual Invocation**: You never need to say \"use the go skill\" - it just works
5. **Additive Installation**: New skills integrate seamlessly with existing ones

## Troubleshooting

If a skill isn't loading when expected:

1. Check that you're working with files of the expected type/extension
2. Ensure the skill file exists at \`$skills_path/<skill-name>/SKILL.md\`
3. Verify the language is the primary focus of your current task
4. Check \`.claude/rules/\` for \`agentic-<lang>.md\` rule files
5. Re-run setup skill if you've installed new skills

## Customization

To modify skill loading behavior:
1. Edit the templates in \`$skills_path/project-rules/templates/\`
2. Re-run the setup skill to regenerate this file
3. The setup skill will detect newly installed skills automatically"

    safe_append_to_file "CLAUDE.md" "$claude_content" "md" "$backup"
}

# Create individual Claude rule file for a skill
create_claude_skill_rule() {
    local skill_name="$1"
    local skill_version="$2"
    local skills_path="${3:-skills}"
    local backup="${4:-true}"
    
    local rule_file=".claude/rules/agentic-${skill_name}-${skill_version}.md"
    local skill_path="$skills_path/$skill_name/$skill_version/SKILL.md"
    
    # Check if skill exists
    if [[ ! -f "$skill_path" ]]; then
        log_error "Skill file not found: $skill_path"
        return 1
    fi
    
    # Create rule content based on skill type
    local rule_content=""
    case "$skill_name" in
        "go")
            rule_content="# Go ${skill_version} Skill Rules

## Trigger Conditions

This rule activates when working primarily with Go files:
- \`**/*.go\` (Go source files)
- \`**/go.mod\` (Go module definition)
- \`**/go.sum\` (Go dependency checksums)

## Skill Loading

When these conditions are met:

**Read \`$skills_path/$skill_name/$skill_version/SKILL.md\` before writing or editing Go code.**

This skill provides:
- Enterprise Go $skill_version development patterns
- Modern tooling integration (mockery, testcontainers, golangci-lint)
- Security practices and performance optimization
- Production-ready patterns for senior developers

## Context Notes

- Only loads when Go is the primary language focus
- Does not load for HTML templates (\`.tmpl\`) used only for templating
- Provides comprehensive guidance across all Go development phases"
            ;;
        "python")
            rule_content="# Python ${skill_version} Skill Rules

## Trigger Conditions

This rule activates when working primarily with Python files:
- \`**/*.py\` (Python source files)

## Skill Loading

When these conditions are met:

**Read \`$skills_path/$skill_name/$skill_version/SKILL.md\` before writing or editing Python code.**

This skill provides:
- Python $skill_version best practices and patterns
- Framework-specific guidance (Django, FastAPI, Flask)
- Testing strategies and performance optimization
- Modern Python tooling and deployment practices"
            ;;
        "typescript")
            rule_content="# TypeScript ${skill_version} Skill Rules

## Trigger Conditions

This rule activates when working primarily with TypeScript files:
- \`**/*.ts\` (TypeScript source files)
- \`**/*.tsx\` (TypeScript JSX files)

## Skill Loading

When these conditions are met:

**Read \`$skills_path/$skill_name/$skill_version/SKILL.md\` before writing or editing TypeScript code.**

This skill provides:
- TypeScript $skill_version patterns and best practices
- React and Node.js integration guidance
- Type safety and modern JavaScript features
- Build tooling and deployment strategies"
            ;;
        "rust")
            rule_content="# Rust ${skill_version} Skill Rules

## Trigger Conditions

This rule activates when working primarily with Rust files:
- \`**/*.rs\` (Rust source files)

## Skill Loading

When these conditions are met:

**Read \`$skills_path/$skill_name/$skill_version/SKILL.md\` before writing or editing Rust code.**

This skill provides:
- Rust $skill_version systems programming patterns
- Memory safety and performance optimization
- Cargo ecosystem and crate development
- Async programming and error handling"
            ;;
        *)
            rule_content="# ${skill_name} ${skill_version} Skill Rules

## Trigger Conditions

This rule activates when working with ${skill_name}-related files.

## Skill Loading

**Read \`$skills_path/$skill_name/$skill_version/SKILL.md\` when working with ${skill_name}.**

This skill provides expertise specific to ${skill_name} version ${skill_version}."
            ;;
    esac
    
    # Ensure directory exists
    mkdir -p ".claude/rules"
    
    safe_append_to_file "$rule_file" "$rule_content" "md" "$backup"
}

# Main Claude setup function
setup_claude_rules() {
    local detected_skills_output="$1"
    local skills_path="${2:-skills}"
    local backup="${3:-true}"
    
    log_info "Setting up Claude Code rules"
    
    # Ensure .claude/rules directory exists
    mkdir -p ".claude/rules"
    
    # Create or update main CLAUDE.md file
    create_claude_main_file "$skills_path" "$backup"
    
    # Process detected skills and create individual rules (VERSION dirs and ALIAS symlinks)
    local skills_processed=0

    _claude_create_skill_rule() {
        local skill="$1"
        local version="$2"
        local path="$3"
        if create_claude_skill_rule "$skill" "$version" "$path" "$backup"; then
            log_info "Created Claude rule for $skill $version"
        fi
    }

    process_detected_skill_versions "$detected_skills_output" "$skills_path" _claude_create_skill_rule skills_processed
    
    if [[ $skills_processed -eq 0 ]]; then
        log_warn "No Claude skill-specific rules created"
    else
        log_info "Created $skills_processed Claude skill rules"
    fi
}

# Functions are available when script is sourced