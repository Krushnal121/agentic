#!/bin/bash

# Enhanced Windsurf Setup Functions
# Handles safe creation of .windsurf/rules/skills.md with all skills and versions

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

# Generate skill-specific rule content for Windsurf
generate_windsurf_skill_rules() {
    local skill_name="$1"
    local skill_version="$2"
    local skills_path="$3"
    
    case "$skill_name" in
        "go")
            echo "
### Go Development (Version $skill_version)

**Triggers on**: \`*.go\`, \`go.mod\`, \`go.sum\`
```
When editing Go files → load $skills_path/go/$skill_version/SKILL.md
```

- Enterprise Go $skill_version development patterns
- Modern tooling integration (mockery, testcontainers, golangci-lint)
- Security practices and performance optimization
- Production-ready patterns for senior developers"
            ;;
        "python")
            echo "
### Python Development (Version $skill_version)

**Triggers on**: \`*.py\`
```
When editing Python files → load $skills_path/python/$skill_version/SKILL.md
```

- Python $skill_version best practices and patterns
- Framework-specific guidance (Django, FastAPI, Flask)
- Testing strategies and performance optimization
- Modern Python tooling and deployment practices"
            ;;
        "typescript")
            echo "
### TypeScript Development (Version $skill_version)

**Triggers on**: \`*.ts\`, \`*.tsx\`
```
When editing TypeScript files → load $skills_path/typescript/$skill_version/SKILL.md
```

- TypeScript $skill_version patterns and best practices
- React and Node.js integration guidance
- Type safety and modern JavaScript features
- Build tooling and deployment strategies"
            ;;
        "rust")
            echo "
### Rust Development (Version $skill_version)

**Triggers on**: \`*.rs\`
```
When editing Rust files → load $skills_path/rust/$skill_version/SKILL.md
```

- Rust $skill_version systems programming patterns
- Memory safety and performance optimization
- Cargo ecosystem and crate development
- Async programming and error handling"
            ;;
        *)
            echo "
### ${skill_name} (Version $skill_version)

**Triggers on**: Files related to ${skill_name}
```
When working with ${skill_name} → load $skills_path/$skill_name/$skill_version/SKILL.md
```

- ${skill_name} version $skill_version expertise and patterns"
            ;;
    esac
}

# Create complete Windsurf rules file
create_windsurf_rules() {
    local detected_skills_output="$1"
    local skills_path="${2:-skills}"
    local backup="${3:-true}"
    
    local windsurf_content="# Agentic Skills - Windsurf Rules

Auto-loading skill configuration for Windsurf IDE.

## Universal Rules

**Always apply these rules:**

- Read the relevant \`$skills_path/<skill-name>/SKILL.md\` BEFORE writing any code or creating any file
- Never skip skill loading even for \"simple\" versions of covered tasks
- When files are uploaded but not yet in context → load \`$skills_path/file-reading/SKILL.md\` FIRST

## Conditional Skill Loading

### Language Skills (Load only when working primarily with these file types)"
    
    # Process detected skills and add their rules (VERSION dirs and ALIAS symlinks)
    local skills_processed=0

    _windsurf_append_skill_rule() {
        local skill="$1"
        local version="$2"
        local path="$3"
        windsurf_content+="$(generate_windsurf_skill_rules "$skill" "$version" "$path")"
    }

    process_detected_skill_versions "$detected_skills_output" "$skills_path" _windsurf_append_skill_rule skills_processed
    
    # Add document processing section
    windsurf_content+="

### Document Processing Skills (Load when working with these file types)

**Microsoft Word** - If \`$skills_path/docx/SKILL.md\` exists, triggers on: \`*.docx\`
\`\`\`
When working with Word documents → load $skills_path/docx/SKILL.md
\`\`\`

**PDF Documents** - If \`$skills_path/pdf/SKILL.md\` exists, triggers on: \`*.pdf\`
\`\`\`
When working with PDF files → load $skills_path/pdf/SKILL.md
\`\`\`

**PowerPoint Presentations** - If \`$skills_path/pptx/SKILL.md\` exists, triggers on: \`*.pptx\`
\`\`\`
When working with presentations → load $skills_path/pptx/SKILL.md
\`\`\`

**Excel Spreadsheets** - If \`$skills_path/xlsx/SKILL.md\` exists, triggers on: \`*.xlsx\`
\`\`\`
When working with spreadsheets → load $skills_path/xlsx/SKILL.md
\`\`\`

## Configuration Notes

- **Conditional Loading**: Language skills only activate when those file types are the primary focus
- **Context Optimization**: Only installed skills load to keep context lean
- **Zero Manual Invocation**: Skills auto-load based on project context
- **Single Source of Truth**: Skill content lives in \`$skills_path/\` directory, not in these rules
- **Version Support**: Supports multiple skill versions without conflicts
- **Additive Installation**: New skills integrate without affecting existing ones

## Troubleshooting

If skills aren't loading as expected:

1. Verify you're working with files matching the trigger patterns
2. Check that skill files exist at \`$skills_path/<skill-name>/SKILL.md\`  
3. Ensure the language is the primary focus of your current task
4. Confirm Windsurf is reading from \`.windsurf/rules/skills.md\`

## Customization

To modify loading behavior:
1. Edit \`$skills_path/project-rules/templates/windsurf.md\`
2. Re-run the setup skill to regenerate \`.windsurf/rules/skills.md\`
3. Commit changes to share with your team"

    # Ensure directory exists
    mkdir -p ".windsurf/rules"
    
    # Write the complete content
    safe_append_to_file ".windsurf/rules/skills.md" "$windsurf_content" "md" "$backup"
    
    return $skills_processed
}

# Main Windsurf setup function
setup_windsurf_rules() {
    local detected_skills_output="$1"
    local skills_path="${2:-skills}"
    local backup="${3:-true}"
    
    log_info "Setting up Windsurf rules"
    
    # Create the complete rules file
    create_windsurf_rules "$detected_skills_output" "$skills_path" "$backup"
    local skills_processed=$?
    
    if [[ $skills_processed -eq 0 ]]; then
        log_warn "No Windsurf skill-specific rules created"
    else
        log_info "Created Windsurf rules file with $skills_processed skills"
    fi
}

# Functions are available when script is sourced