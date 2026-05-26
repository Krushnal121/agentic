#!/bin/bash

# Enhanced Codex/AGENTS.md Setup Functions
# Handles safe appending to existing AGENTS.md with skill configuration

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

# Generate skill-specific rule content for Codex/AGENTS.md
generate_codex_skill_rules() {
    local skill_name="$1"
    local skill_version="$2"
    local skills_path="$3"
    
    case "$skill_name" in
        "go")
            echo "
#### Go Development Agent (Version $skill_version)

**Activation**: When working with \`.go\`, \`go.mod\`, or \`go.sum\` files
**Skill Source**: \`$skills_path/go/$skill_version/SKILL.md\`

**Capabilities**:
- Enterprise Go $skill_version development patterns and idioms
- Modern tooling integration: mockery, testcontainers, golangci-lint
- Security practices: input validation, cryptography, authentication
- Performance optimization: profiling, memory management, concurrency
- Production deployment: architecture, monitoring, containerization

**Usage**: Automatically loads when Go is the primary language focus. Provides comprehensive guidance for enterprise-grade Go development."
            ;;
        "python")
            echo "
#### Python Development Agent (Version $skill_version)

**Activation**: When working with \`.py\` files
**Skill Source**: \`$skills_path/python/$skill_version/SKILL.md\`

**Capabilities**:
- Python $skill_version best practices and design patterns
- Framework expertise: Django, FastAPI, Flask
- Testing strategies and performance optimization
- Modern tooling and deployment practices
- Package management and virtual environments

**Usage**: Automatically activates for Python-focused development tasks."
            ;;
        "typescript")
            echo "
#### TypeScript Development Agent (Version $skill_version)

**Activation**: When working with \`.ts\` or \`.tsx\` files
**Skill Source**: \`$skills_path/typescript/$skill_version/SKILL.md\`

**Capabilities**:
- TypeScript $skill_version patterns and advanced typing
- React and Node.js integration best practices
- Type safety and modern JavaScript features
- Build tooling: webpack, esbuild, vite
- Testing and deployment strategies

**Usage**: Loads automatically for TypeScript and React development."
            ;;
        "rust")
            echo "
#### Rust Development Agent (Version $skill_version)

**Activation**: When working with \`.rs\` files
**Skill Source**: \`$skills_path/rust/$skill_version/SKILL.md\`

**Capabilities**:
- Rust $skill_version systems programming patterns
- Memory safety and zero-cost abstractions
- Cargo ecosystem and crate development
- Async programming with tokio
- Performance optimization and error handling

**Usage**: Automatically engages for Rust systems programming tasks."
            ;;
        *)
            echo "
#### ${skill_name} Agent (Version $skill_version)

**Activation**: When working with ${skill_name}-related files
**Skill Source**: \`$skills_path/$skill_name/$skill_version/SKILL.md\`

**Capabilities**: ${skill_name} version $skill_version specialized expertise and patterns

**Usage**: Context-aware activation for ${skill_name} development tasks."
            ;;
    esac
}

# Create or append Codex/AGENTS.md configuration
setup_codex_agents() {
    local detected_skills_output="$1"
    local skills_path="${2:-skills}"
    local backup="${3:-true}"
    
    # Check if AGENTS.md already exists
    local agents_file_exists=false
    if [[ -f "AGENTS.md" ]]; then
        agents_file_exists=true
    fi
    
    # Build the agentic skills section
    local codex_content=""
    
    # Only add header if this is a new section
    if [[ "$agents_file_exists" == "true" ]]; then
        # Check if agentic skills section already exists
        if ! grep -q "# Agentic Skills Auto-Loading" "AGENTS.md" 2>/dev/null; then
            codex_content+="

# Agentic Skills Auto-Loading

This section configures automatic skill loading for enhanced development capabilities."
        fi
    else
        # New AGENTS.md file
        codex_content="# Development Agents Configuration

## Overview

This file configures intelligent development agents that automatically activate based on project context and file types.

# Agentic Skills Auto-Loading

This section configures automatic skill loading for enhanced development capabilities."
    fi
    
    # Add universal rules if not a duplicate
    if [[ "$agents_file_exists" == "false" ]] || ! grep -q "## Universal Agent Rules" "AGENTS.md" 2>/dev/null; then
        codex_content+="

## Universal Agent Rules

**Core Principle**: Always consult the relevant \`$skills_path/<skill-name>/SKILL.md\` before writing code or creating files.

**Mandatory Behavior**:
- Never skip skill loading, even for simple tasks within a skill's domain
- Skills contain critical patterns, constraints, and best practices
- Load file-reading skill first when working with uploaded files not yet in context

**File Type Triggers**:
- **Documents**: \`.docx\`, \`.pdf\`, \`.pptx\`, \`.xlsx\` → Load corresponding document processing skills
- **Code**: Language-specific triggers activate relevant development skills"
    fi
    
    # Add language-specific agents
    codex_content+="

## Language-Specific Development Agents"
    
    # Process detected skills and add their rules
    local current_skill=""
    local skills_processed=0
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^SKILL, ]]; then
            current_skill=$(echo "$line" | cut -d',' -f2)
            
        elif [[ "$line" =~ ^ALIAS, ]]; then
            local alias_name=$(echo "$line" | cut -d',' -f2)
            local target_version=$(echo "$line" | cut -d',' -f3)
            
            # Add rule for the actual version (not the alias)
            if [[ -f "$skills_path/$current_skill/$target_version/SKILL.md" ]]; then
                # Check if this specific skill version already exists
                if [[ "$agents_file_exists" == "false" ]] || ! grep -q "$current_skill Development Agent (Version $target_version)" "AGENTS.md" 2>/dev/null; then
                    local skill_rule=$(generate_codex_skill_rules "$current_skill" "$target_version" "$skills_path")
                    codex_content+="$skill_rule"
                    ((skills_processed++))
                fi
            fi
        fi
    done <<< "$detected_skills_output"
    
    # Add configuration notes
    if [[ "$agents_file_exists" == "false" ]] || ! grep -q "## Agent Configuration Notes" "AGENTS.md" 2>/dev/null; then
        codex_content+="

## Agent Configuration Notes

### Conditional Activation
- Language agents only activate when that language is the primary focus
- File type agents load based on specific file extensions
- Multiple agents can collaborate when working across languages/technologies

### Context Optimization
- Only relevant agents load to maintain focused assistance
- Agent knowledge is sourced from versioned skill files
- No manual agent invocation required - activation is automatic

### Version Management
- Multiple skill versions can coexist without conflicts
- Agents use specific version knowledge (e.g., Go 1.26 vs Go 1.25)
- Re-run setup after installing new skills to update agent configurations

### Troubleshooting
1. Verify skill files exist at \`$skills_path/<skill-name>/<version>/SKILL.md\`
2. Check file extensions match agent trigger patterns
3. Ensure target language/technology is the primary task focus
4. Confirm AGENTS.md is being read by your development environment"
    fi
    
    # Write the content (append to existing or create new)
    safe_append_to_file "AGENTS.md" "$codex_content" "md" "$backup"
    
    return $skills_processed
}

# Main Codex setup function
setup_codex_configuration() {
    local detected_skills_output="$1"
    local skills_path="${2:-skills}"
    local backup="${3:-true}"
    
    log_info "Setting up Codex/AGENTS.md configuration"
    
    # Setup the agents configuration
    setup_codex_agents "$detected_skills_output" "$skills_path" "$backup"
    local skills_processed=$?
    
    if [[ $skills_processed -eq 0 ]]; then
        log_warn "No new Codex agent configurations added"
    else
        log_info "Added/updated $skills_processed Codex agent configurations"
    fi
}

# Functions are available when script is sourced