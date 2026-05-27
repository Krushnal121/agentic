#!/bin/bash

# Enhanced Agentic Skills Setup
# Addresses all the gaps identified in the original workflow:
# - Creates missing .cursor/rules/skills.mdc index file
# - Improved version detection for latest vs versioned skills  
# - Safer symlink creation with idempotent behavior
# - Merge/append behavior for existing rule files
# - Comprehensive error handling and validation

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source helper scripts
source "$SCRIPT_DIR/detect-versions.sh" 2>/dev/null || echo "Warning: detect-versions.sh not found"
source "$SCRIPT_DIR/manage-symlinks.sh" 2>/dev/null || echo "Warning: manage-symlinks.sh not found"  
source "$SCRIPT_DIR/merge-rules.sh" 2>/dev/null || echo "Warning: merge-rules.sh not found"
source "$SCRIPT_DIR/claude-setup.sh" 2>/dev/null || echo "Warning: claude-setup.sh not found"
source "$SCRIPT_DIR/windsurf-setup.sh" 2>/dev/null || echo "Warning: windsurf-setup.sh not found"
source "$SCRIPT_DIR/copilot-setup.sh" 2>/dev/null || echo "Warning: copilot-setup.sh not found"
source "$SCRIPT_DIR/codex-setup.sh" 2>/dev/null || echo "Warning: codex-setup.sh not found"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log_header() {
    echo -e "\n${BOLD}${BLUE}$1${NC}"
}

log_info() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_debug() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Configuration
SKILLS_SOURCE_DIR="${SKILLS_SOURCE_DIR:-.agents/skills}"
SKILLS_LINK_DIR="${SKILLS_LINK_DIR:-skills}"
FORCE_UPDATE="${FORCE_UPDATE:-false}"
BACKUP_EXISTING="${BACKUP_EXISTING:-true}"

# Step 1: Validate environment and setup skills directory access
setup_skills_access() {
    log_header "Setting up skills directory access"
    
    # Check if skills source directory exists
    if [[ ! -d "$SKILLS_SOURCE_DIR" ]]; then
        log_warn "Skills source directory '$SKILLS_SOURCE_DIR' not found"
        log_warn "Falling back to local skills directory"
        SKILLS_SOURCE_DIR="skills"
        
        if [[ ! -d "$SKILLS_SOURCE_DIR" ]]; then
            log_error "No skills directory found. Please install skills first."
            exit 1
        fi
    fi
    
    # Setup symlink if needed (only if skills source is not the current skills dir)
    if [[ "$SKILLS_SOURCE_DIR" != "skills" ]]; then
        setup_skills_symlink "$SKILLS_SOURCE_DIR" "$FORCE_UPDATE"
        if [[ $? -ne 0 ]]; then
            log_error "Failed to setup skills symlink"
            exit 1
        fi
        
        # Validate symlink
        validate_skills_symlink
        if [[ $? -ne 0 ]]; then
            log_error "Skills symlink validation failed"
            exit 1
        fi
    fi
    
    log_info "Skills directory access configured"
}

# Step 2: Detect installed skills and versions
detect_skills_and_versions() {
    log_header "Detecting installed skills and versions"
    
    # Use the enhanced detection script
    local detection_output=$(detect_all_skills "$SKILLS_LINK_DIR")
    
    if [[ -z "$detection_output" ]]; then
        log_warn "No skills detected"
        return 1
    fi
    
    # Parse detection output
    declare -A skills=()
    declare -A versions=()
    declare -A aliases=()
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^SKILL, ]]; then
            skill_name=$(echo "$line" | cut -d',' -f2)
            skills["$skill_name"]=1
            log_debug "Found skill: $skill_name"
            
        elif [[ "$line" =~ ^VERSION, ]]; then
            skill_version=$(echo "$line" | cut -d',' -f2)
            # Assuming current skill context
            versions["$current_skill"]+="$skill_version "
            log_debug "Found version: $skill_version"
            
        elif [[ "$line" =~ ^ALIAS, ]]; then
            alias_name=$(echo "$line" | cut -d',' -f2)
            target_version=$(echo "$line" | cut -d',' -f3)
            aliases["$current_skill,$alias_name"]="$target_version"
            log_debug "Found alias: $alias_name -> $target_version"
        fi
        
        # Track current skill for version/alias context
        if [[ "$line" =~ ^SKILL, ]]; then
            current_skill=$(echo "$line" | cut -d',' -f2)
        fi
    done <<< "$detection_output"
    
    # Export for use in other functions
    export DETECTED_SKILLS_OUTPUT="$detection_output"
    
    log_info "Skill detection completed"
}

# Step 3: Detect IDE configurations
detect_ide_configurations() {
    log_header "Detecting IDE configurations"
    
    declare -a detected_ides=()
    
    # Check for Cursor (.cursor/ directory or Cursor runtime environment)
    if [[ -d ".cursor" ]]; then
        detected_ides+=("cursor")
        log_info "Detected Cursor IDE (.cursor/ directory)"
    elif [[ "${SETUP_CURSOR:-}" == "true" ]] \
        || [[ -n "${CURSOR_TRACE_ID:-}" ]] \
        || [[ -n "${CURSOR_AGENT:-}" ]] \
        || [[ "${TERM_PROGRAM:-}" == "cursor" ]]; then
        mkdir -p ".cursor/rules"
        detected_ides+=("cursor")
        log_info "Detected Cursor IDE (runtime) — created .cursor/rules/"
    fi
    
    # Check for Claude Code
    if [[ -d ".claude" ]] || [[ -f "CLAUDE.md" ]]; then
        detected_ides+=("claude")
        log_info "Detected Claude Code (.claude/ directory or CLAUDE.md)"
    fi
    
    # Check for Windsurf
    if [[ -d ".windsurf" ]]; then
        detected_ides+=("windsurf") 
        log_info "Detected Windsurf IDE (.windsurf/ directory)"
    fi
    
    # Check for GitHub Copilot
    if [[ -d ".github" ]]; then
        detected_ides+=("github")
        log_info "Detected GitHub presence (.github/ directory)"
    fi
    
    # Check for Codex
    if [[ -f "AGENTS.md" ]]; then
        detected_ides+=("codex")
        log_info "Detected Codex (AGENTS.md file)"
    fi
    
    if [[ ${#detected_ides[@]} -eq 0 ]]; then
        log_warn "No IDE configurations detected"
        log_warn "You may need to manually configure your IDE"
        return 1
    fi
    
    export DETECTED_IDES=("${detected_ides[@]}")
    log_info "IDE detection completed: ${detected_ides[*]}"
}

# Step 4: Create IDE-specific rules

# Create Claude Code rules
create_claude_rules() {
    log_header "Creating Claude Code rules"
    
    # Source the function and call it
    source "$SCRIPT_DIR/claude-setup.sh"
    setup_claude_rules "$DETECTED_SKILLS_OUTPUT" "$SKILLS_LINK_DIR" "$BACKUP_EXISTING"
}

# Create Windsurf rules  
create_windsurf_rules() {
    log_header "Creating Windsurf rules"
    
    # Source the function and call it
    source "$SCRIPT_DIR/windsurf-setup.sh"
    setup_windsurf_rules "$DETECTED_SKILLS_OUTPUT" "$SKILLS_LINK_DIR" "$BACKUP_EXISTING"
}

# Create GitHub Copilot rules
create_github_rules() {
    log_header "Creating GitHub Copilot instructions"
    
    # Source the function and call it
    source "$SCRIPT_DIR/copilot-setup.sh"
    setup_copilot_instructions "$DETECTED_SKILLS_OUTPUT" "$SKILLS_LINK_DIR" "$BACKUP_EXISTING"
}

# Create Codex/AGENTS.md configuration
create_codex_rules() {
    log_header "Creating Codex/AGENTS.md configuration"
    
    # Source the function and call it
    source "$SCRIPT_DIR/codex-setup.sh"
    setup_codex_configuration "$DETECTED_SKILLS_OUTPUT" "$SKILLS_LINK_DIR" "$BACKUP_EXISTING"
}

# Create Cursor rules
create_cursor_rules() {
    log_header "Creating Cursor rules"
    
    # Ensure .cursor/rules directory exists
    mkdir -p ".cursor/rules"
    
    # Create or update skills.mdc index file (with merge safety)
    local skills_index_content="---
description: Agentic Skills Index — Master routing file for all skills
alwaysApply: true
---

# Agentic Skills Routing Index

This file serves as the master index for all agentic skills. It references all generated skill-specific rule files in this directory.

## Universal Rules (Always Active)

Load file reading skill for uploads not in context:
- File uploads not yet in context → load skills/file-reading/SKILL.md if available

## Core Principle

**Always read the relevant SKILL.md before writing any code.** Never skip skill loading even for simple tasks.

## Auto-Generated Files

This index references the following auto-generated rule files:
- \`agentic-universal.mdc\` - Base universal rules (always active)
- \`agentic-{skill}-{version}.mdc\` - Individual skill routing rules

Re-run the setup skill after installing new skills to update this configuration."

    safe_append_to_file ".cursor/rules/skills.mdc" "$skills_index_content" "mdc" "$BACKUP_EXISTING"
    
    # Create universal rules
    local universal_content="---
description: Universal agentic skill routing — always active
alwaysApply: true
---

# Universal Agentic Skills Rules

Before writing any code or creating any file, read the SKILL.md for the relevant skill if available.

Never skip skill loading even for simple tasks.

File uploads not yet in context → load skills/file-reading/SKILL.md if available."

    safe_append_to_file ".cursor/rules/agentic-universal.mdc" "$universal_content" "mdc" "$BACKUP_EXISTING"
    
    # Process detected skills and create individual rules (VERSION dirs and ALIAS symlinks)
    local skills_processed=0

    _cursor_create_skill_rule() {
        local skill="$1"
        local version="$2"
        local skills_path="$3"
        if update_cursor_rule "$skill" "$version" "$skills_path"; then
            log_info "Created Cursor rule for $skill $version"
        fi
    }

    process_detected_skill_versions "$DETECTED_SKILLS_OUTPUT" "$SKILLS_LINK_DIR" _cursor_create_skill_rule skills_processed
    
    if [[ $skills_processed -eq 0 ]]; then
        log_warn "No skill-specific rules created"
    else
        log_info "Created $skills_processed Cursor skill rules"
    fi
}

# Step 5: Validation and summary
validate_setup() {
    log_header "Validating setup"
    
    local validation_passed=true
    
    # Check skills directory
    if [[ -L "$SKILLS_LINK_DIR" ]]; then
        validate_skills_symlink
        if [[ $? -ne 0 ]]; then
            validation_passed=false
        fi
    elif [[ -d "$SKILLS_LINK_DIR" ]]; then
        log_info "Skills directory exists as regular directory"
    else
        log_error "Skills directory not accessible"
        validation_passed=false
    fi
    
    # Check IDE configurations if detected
    if [[ " ${DETECTED_IDES[*]} " =~ " cursor " ]]; then
        local cursor_files_count=$(find ".cursor/rules" -name "agentic-*.mdc" 2>/dev/null | wc -l)
        if [[ $cursor_files_count -gt 0 ]]; then
            log_info "Created $cursor_files_count Cursor rule files"
        else
            log_warn "No Cursor rule files found"
            validation_passed=false
        fi
    fi
    
    if [[ " ${DETECTED_IDES[*]} " =~ " claude " ]]; then
        if [[ -f "CLAUDE.md" ]] && [[ -d ".claude/rules" ]]; then
            local claude_files_count=$(find ".claude/rules" -name "agentic-*.md" 2>/dev/null | wc -l)
            log_info "Created Claude Code configuration with $claude_files_count skill rules"
        else
            log_warn "Claude Code configuration incomplete"
            validation_passed=false
        fi
    fi
    
    if [[ " ${DETECTED_IDES[*]} " =~ " windsurf " ]]; then
        if [[ -f ".windsurf/rules/skills.md" ]]; then
            log_info "Created Windsurf skills configuration"
        else
            log_warn "Windsurf configuration missing"
            validation_passed=false
        fi
    fi
    
    if [[ " ${DETECTED_IDES[*]} " =~ " github " ]]; then
        if [[ -f ".github/copilot-instructions.md" ]]; then
            log_info "Created GitHub Copilot instructions"
        else
            log_warn "GitHub Copilot configuration missing"
            validation_passed=false
        fi
    fi
    
    if [[ " ${DETECTED_IDES[*]} " =~ " codex " ]]; then
        if [[ -f "AGENTS.md" ]] && grep -q "Agentic Skills Auto-Loading" "AGENTS.md" 2>/dev/null; then
            log_info "Updated AGENTS.md with agentic skills configuration"
        else
            log_warn "Codex/AGENTS.md configuration incomplete"
            validation_passed=false
        fi
    fi
    
    if [[ "$validation_passed" == "true" ]]; then
        log_info "Setup validation passed"
        return 0
    else
        log_error "Setup validation failed"
        return 1
    fi
}

# Print setup summary
print_summary() {
    log_header "Setup Summary"
    
    echo -e "\n${BOLD}Skills Configuration:${NC}"
    if [[ -L "$SKILLS_LINK_DIR" ]]; then
        local target=$(readlink "$SKILLS_LINK_DIR")
        echo "  Skills directory: $SKILLS_LINK_DIR -> $target"
    else
        echo "  Skills directory: $SKILLS_LINK_DIR (direct)"
    fi
    
    echo -e "\n${BOLD}Detected Skills:${NC}"
    while IFS= read -r line; do
        if [[ "$line" =~ ^SKILL, ]]; then
            current_skill=$(echo "$line" | cut -d',' -f2)
            echo "  - $current_skill"
            
        elif [[ "$line" =~ ^VERSION, ]]; then
            version=$(echo "$line" | cut -d',' -f2)
            echo "    version $version"
        elif [[ "$line" =~ ^ALIAS, ]]; then
            alias_name=$(echo "$line" | cut -d',' -f2)
            target_version=$(echo "$line" | cut -d',' -f3)
            echo "    $alias_name -> $target_version"
        fi
    done <<< "$DETECTED_SKILLS_OUTPUT"
    
    echo -e "\n${BOLD}IDE Configurations:${NC}"
    for ide in "${DETECTED_IDES[@]}"; do
        case "$ide" in
            "cursor")
                local rule_count=$(find ".cursor/rules" -name "agentic-*.mdc" 2>/dev/null | wc -l)
                echo "  - Cursor: $rule_count rule files created in .cursor/rules/"
                ;;
            "claude")
                local claude_rule_count=$(find ".claude/rules" -name "agentic-*.md" 2>/dev/null | wc -l)
                echo "  - Claude Code: CLAUDE.md + $claude_rule_count skill rules in .claude/rules/"
                ;;
            "windsurf")
                if [[ -f ".windsurf/rules/skills.md" ]]; then
                    echo "  - Windsurf: .windsurf/rules/skills.md created"
                else
                    echo "  - Windsurf: configuration failed"
                fi
                ;;
            "github")
                if [[ -f ".github/copilot-instructions.md" ]]; then
                    echo "  - GitHub Copilot: .github/copilot-instructions.md created"
                else
                    echo "  - GitHub Copilot: configuration failed"
                fi
                ;;
            "codex")
                if grep -q "Agentic Skills Auto-Loading" "AGENTS.md" 2>/dev/null; then
                    echo "  - Codex: AGENTS.md updated with skill configuration"
                else
                    echo "  - Codex: AGENTS.md configuration failed"
                fi
                ;;
            *)
                echo "  - $ide: detected but not configured yet"
                ;;
        esac
    done
    
    echo -e "\n${BOLD}Next Steps:${NC}"
    echo "  1. Commit the generated files to version control"
    echo "  2. Skills will auto-load based on file patterns and versions"  
    echo "  3. Re-run setup after installing new skills"
    echo "  4. Multiple skill versions can coexist without conflicts"
}

# Main execution
main() {
    echo -e "${BOLD}${GREEN}Enhanced Agentic Skills Setup${NC}"
    echo "Addressing workflow gaps with improved robustness..."
    
    # Parse command line options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE_UPDATE="true"
                shift
                ;;
            --no-backup)
                BACKUP_EXISTING="false"
                shift
                ;;
            --skills-dir)
                SKILLS_SOURCE_DIR="$2"
                shift 2
                ;;
            --cursor)
                SETUP_CURSOR="true"
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --force           Force update existing symlinks and rules"
                echo "  --no-backup       Don't create backup files"
                echo "  --skills-dir DIR  Specify skills source directory"
                echo "  --cursor          Configure Cursor even without .cursor/ directory"
                echo "  --help            Show this help"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Execute setup steps
    setup_skills_access
    detect_skills_and_versions
    detect_ide_configurations
    
    # Create IDE-specific rules (don't exit on errors)
    for ide in "${DETECTED_IDES[@]}"; do
        case "$ide" in
            "cursor")
                create_cursor_rules || log_warn "Cursor rules creation had issues"
                ;;
            "claude")
                create_claude_rules || log_warn "Claude rules creation had issues"
                ;;
            "windsurf")
                create_windsurf_rules || log_warn "Windsurf rules creation had issues"
                ;;
            "github")
                create_github_rules || log_warn "GitHub rules creation had issues"
                ;;
            "codex")
                create_codex_rules || log_warn "Codex rules creation had issues"
                ;;
            *)
                log_warn "IDE $ide detected but configuration not implemented yet"
                ;;
        esac
    done
    
    validate_setup
    if [[ $? -eq 0 ]]; then
        print_summary
        log_info "Enhanced setup completed successfully!"
    else
        log_error "Setup completed with validation errors"
        exit 1
    fi
}

# Run main if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi