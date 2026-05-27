#!/bin/bash

# Enhanced GitHub Copilot Setup Functions
# Handles safe creation of .github/copilot-instructions.md with all skills and versions

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

# Generate skill-specific rule content for GitHub Copilot
generate_copilot_skill_rules() {
    local skill_name="$1"
    local skill_version="$2"
    local skills_path="$3"
    
    case "$skill_name" in
        "go")
            echo "
#### Go Development (Version $skill_version)

**Trigger files**: \`.go\`, \`go.mod\`, \`go.sum\`

**Instruction**: When working primarily with Go files, load and follow \`$skills_path/go/$skill_version/SKILL.md\`

**Reference format**: \"Following $skills_path/go/$skill_version/SKILL.md guidelines for Go development...\"

**Capabilities**:
- Enterprise Go $skill_version development patterns
- Modern tooling integration (mockery, testcontainers, golangci-lint)
- Security practices and performance optimization
- Production-ready patterns for senior developers"
            ;;
        "python")
            echo "
#### Python Development (Version $skill_version)

**Trigger files**: \`.py\`

**Instruction**: When working primarily with Python files, load and follow \`$skills_path/python/$skill_version/SKILL.md\`

**Reference format**: \"Following $skills_path/python/$skill_version/SKILL.md guidelines for Python development...\"

**Capabilities**:
- Python $skill_version best practices and patterns
- Framework-specific guidance (Django, FastAPI, Flask)
- Testing strategies and performance optimization
- Modern Python tooling and deployment practices"
            ;;
        "typescript")
            echo "
#### TypeScript Development (Version $skill_version)

**Trigger files**: \`.ts\`, \`.tsx\`

**Instruction**: When working primarily with TypeScript files, load and follow \`$skills_path/typescript/$skill_version/SKILL.md\`

**Reference format**: \"Following $skills_path/typescript/$skill_version/SKILL.md guidelines for TypeScript development...\"

**Capabilities**:
- TypeScript $skill_version patterns and best practices
- React and Node.js integration guidance
- Type safety and modern JavaScript features
- Build tooling and deployment strategies"
            ;;
        "rust")
            echo "
#### Rust Development (Version $skill_version)

**Trigger files**: \`.rs\`

**Instruction**: When working primarily with Rust files, load and follow \`$skills_path/rust/$skill_version/SKILL.md\`

**Reference format**: \"Following $skills_path/rust/$skill_version/SKILL.md guidelines for Rust development...\"

**Capabilities**:
- Rust $skill_version systems programming patterns
- Memory safety and performance optimization
- Cargo ecosystem and crate development
- Async programming and error handling"
            ;;
        *)
            echo "
#### ${skill_name} (Version $skill_version)

**Instruction**: When working with ${skill_name}, load and follow \`$skills_path/$skill_name/$skill_version/SKILL.md\`

**Reference format**: \"Following $skills_path/$skill_name/$skill_version/SKILL.md guidelines for ${skill_name}...\"

**Capabilities**: ${skill_name} version $skill_version expertise and patterns"
            ;;
    esac
}

# Create complete GitHub Copilot instructions file
create_copilot_instructions() {
    local detected_skills_output="$1"
    local skills_path="${2:-skills}"
    local backup="${3:-true}"
    
    local copilot_content="# GitHub Copilot - Agentic Skills Integration

Auto-loading skill configuration for GitHub Copilot.

## Core Instruction

**Before writing any code or creating any file, consult the relevant skill documentation from the \`$skills_path/\` directory.**

## Skill Loading Rules

### Universal Requirements

- Always read the appropriate \`$skills_path/<skill-name>/SKILL.md\` before coding
- Never skip skill loading, even for simple tasks within a skill's domain
- Skills contain critical patterns, constraints, and best practices

### File Type Triggers

Load these skills automatically based on file context (only if installed):

- **Word Documents (\`.docx\`)**: Load and follow \`$skills_path/docx/SKILL.md\` (if exists)
- **PDF Files (\`.pdf\`)**: Load and follow \`$skills_path/pdf/SKILL.md\` (if exists)
- **Presentations (\`.pptx\`)**: Load and follow \`$skills_path/pptx/SKILL.md\` (if exists)
- **Spreadsheets (\`.xlsx\`)**: Load and follow \`$skills_path/xlsx/SKILL.md\` (if exists)
- **Uploaded Files**: If files are uploaded but not in context, load \`$skills_path/file-reading/SKILL.md\` (if exists)

### Language-Specific Skills

Load these skills when the specified language is the primary focus (only if installed):"
    
    # Process detected skills and add their rules (VERSION dirs and ALIAS symlinks)
    local skills_processed=0

    _copilot_append_skill_rule() {
        local skill="$1"
        local version="$2"
        local path="$3"
        copilot_content+="$(generate_copilot_skill_rules "$skill" "$version" "$path")"
    }

    process_detected_skill_versions "$detected_skills_output" "$skills_path" _copilot_append_skill_rule skills_processed
    
    # Add implementation guidelines
    copilot_content+="

## Implementation Guidelines

### Conditional Loading
- Language skills only activate when that language is the primary task focus
- Don't load multiple language skills simultaneously unless truly needed
- File type skills load whenever those file formats are involved

### Context Optimization  
- Only load relevant skills to keep suggestions focused and efficient
- Skills are loaded automatically based on project context
- No manual skill invocation should be required

### Skill Reference Format
When a skill is loaded, reference it in responses like:
\`\`\`
Following $skills_path/go/SKILL.md guidelines for Go development...
\`\`\`

## Usage Notes

- Skills are located in the \`$skills_path/\` directory relative to project root
- Each skill has comprehensive documentation in its \`SKILL.md\` file
- Skills may have prerequisites or dependencies listed in their documentation
- Multiple skill versions can coexist without conflicts

## Troubleshooting

If skills aren't being applied correctly:

1. Verify the skill file exists at \`$skills_path/<skill-name>/SKILL.md\`
2. Check that file extensions match the trigger patterns
3. Ensure the language/file type is the primary focus of the current task
4. Confirm GitHub Copilot is reading instructions from \`.github/copilot-instructions.md\`

## Customization

To modify skill loading:
1. Edit the template at \`$skills_path/project-rules/templates/copilot.md\`
2. Re-run the setup skill to update \`.github/copilot-instructions.md\`
3. Changes will apply to all team members using GitHub Copilot"

    # Ensure directory exists
    mkdir -p ".github"
    
    # Write the complete content
    safe_append_to_file ".github/copilot-instructions.md" "$copilot_content" "md" "$backup"
    
    return $skills_processed
}

# Main GitHub Copilot setup function
setup_copilot_instructions() {
    local detected_skills_output="$1"
    local skills_path="${2:-skills}"
    local backup="${3:-true}"
    
    log_info "Setting up GitHub Copilot instructions"
    
    # Create the complete instructions file
    create_copilot_instructions "$detected_skills_output" "$skills_path" "$backup"
    local skills_processed=$?
    
    if [[ $skills_processed -eq 0 ]]; then
        log_warn "No GitHub Copilot skill-specific rules created"
    else
        log_info "Created GitHub Copilot instructions with $skills_processed skills"
    fi
}

# Functions are available when script is sourced