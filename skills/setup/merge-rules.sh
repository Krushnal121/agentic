#!/bin/bash

# Safe Rule File Merging for Agentic Skills Setup
# Handles appending/merging rule content without duplicating blocks

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if a rule block already exists in a file
rule_block_exists() {
    local file_path="$1"
    local rule_identifier="$2"
    
    if [[ ! -f "$file_path" ]]; then
        return 1  # File doesn't exist, so rule doesn't exist
    fi
    
    # Look for the rule identifier in the file
    if grep -q "$rule_identifier" "$file_path"; then
        return 0  # Rule exists
    fi
    
    return 1  # Rule doesn't exist
}

# Extract rule identifier from content
extract_rule_identifier() {
    local content="$1"
    local file_type="$2"
    
    case "$file_type" in
        "mdc"|"md")
            # For markdown files, look for description in YAML frontmatter
            echo "$content" | grep -E "^description:" | head -1
            ;;
        "claude")
            # For Claude files, look for skill name/version patterns
            echo "$content" | grep -E "skills/[^/]+(/[^/]+)?/SKILL\.md" | head -1
            ;;
        *)
            # Generic approach: use first significant line
            echo "$content" | grep -v "^#" | grep -v "^$" | head -1
            ;;
    esac
}

# Safely append content to file
safe_append_to_file() {
    local file_path="$1"
    local new_content="$2"
    local file_type="$3"
    local backup="${4:-true}"
    
    # Create backup if requested
    if [[ "$backup" == "true" && -f "$file_path" ]]; then
        cp "$file_path" "${file_path}.backup.$(date +%s)"
        log_debug "Created backup: ${file_path}.backup.$(date +%s)"
    fi
    
    # Extract rule identifier to check for duplicates
    local rule_id=$(extract_rule_identifier "$new_content" "$file_type")
    
    if [[ -f "$file_path" ]] && [[ -n "$rule_id" ]]; then
        if rule_block_exists "$file_path" "$rule_id"; then
            log_warn "Rule already exists in $file_path, skipping"
            return 1
        fi
    fi
    
    # If file exists, append with separator
    if [[ -f "$file_path" ]]; then
        echo "" >> "$file_path"
        echo "# --- Added by agentic setup ---" >> "$file_path"
        echo "$new_content" >> "$file_path"
        log_info "Appended rule to existing file: $file_path"
    else
        # Create new file
        mkdir -p "$(dirname "$file_path")"
        echo "$new_content" > "$file_path"
        log_info "Created new rule file: $file_path"
    fi
    
    return 0
}

# Merge multiple rule files safely
merge_rule_files() {
    local target_file="$1"
    local file_type="$2"
    shift 2
    local source_files=("$@")
    
    local temp_file=$(mktemp)
    local any_changes=false
    
    # If target exists, start with its content
    if [[ -f "$target_file" ]]; then
        cp "$target_file" "$temp_file"
    fi
    
    # Process each source file
    for source_file in "${source_files[@]}"; do
        if [[ -f "$source_file" ]]; then
            local content=$(cat "$source_file")
            local rule_id=$(extract_rule_identifier "$content" "$file_type")
            
            # Check if this rule already exists
            if [[ -n "$rule_id" ]] && rule_block_exists "$temp_file" "$rule_id"; then
                log_warn "Skipping duplicate rule from $source_file"
                continue
            fi
            
            # Append with separator
            echo "" >> "$temp_file"
            echo "# --- Merged from $source_file ---" >> "$temp_file"
            cat "$source_file" >> "$temp_file"
            any_changes=true
            log_info "Merged content from: $source_file"
        fi
    done
    
    # Only update target if there were changes
    if [[ "$any_changes" == "true" ]]; then
        mkdir -p "$(dirname "$target_file")"
        cp "$temp_file" "$target_file"
        log_info "Updated merged file: $target_file"
    fi
    
    rm -f "$temp_file"
}

# Process VERSION and ALIAS lines from detect_all_skills output.
# Invokes callback(skill_name, version, skills_path) for each unique pair with SKILL.md present.
# Optional 4th arg: name of variable to receive invocation count.
process_detected_skill_versions() {
    local detection_output="$1"
    local skills_path="${2:-skills}"
    local callback="$3"
    local current_skill=""
    local count=0
    declare -A processed=()

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        if [[ "$line" =~ ^SKILL, ]]; then
            current_skill=$(echo "$line" | cut -d',' -f2)
            continue
        fi

        local version=""
        if [[ "$line" =~ ^VERSION, ]]; then
            version=$(echo "$line" | cut -d',' -f2)
        elif [[ "$line" =~ ^ALIAS, ]]; then
            version=$(echo "$line" | cut -d',' -f3)
        else
            continue
        fi

        [[ -z "$current_skill" || -z "$version" ]] && continue

        local key="${current_skill}::${version}"
        if [[ -n "${processed[$key]:-}" ]]; then
            continue
        fi

        if [[ ! -f "$skills_path/$current_skill/$version/SKILL.md" ]]; then
            continue
        fi

        processed[$key]=1
        "$callback" "$current_skill" "$version" "$skills_path"
        count=$((count + 1))
    done <<< "$detection_output"

    if [[ $# -ge 4 && -n "${4:-}" ]]; then
        printf -v "$4" '%s' "$count"
    fi

    return 0
}

# Create or update Cursor rule file
update_cursor_rule() {
    local skill_name="$1"
    local skill_version="$2"
    local skills_path="${3:-skills}"
    
    local rule_file=".cursor/rules/agentic-${skill_name}-${skill_version}.mdc"
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
            rule_content="---
description: Go skill routing (version $skill_version)
globs: [\"**/*.go\", \"**/go.mod\", \"**/go.sum\"]
alwaysApply: false
---

Read $skills_path/$skill_name/$skill_version/SKILL.md before writing or editing Go code."
            ;;
        "python")
            rule_content="---
description: Python skill routing (version $skill_version)
globs: [\"**/*.py\"]
alwaysApply: false
---

Read $skills_path/$skill_name/$skill_version/SKILL.md before writing or editing Python code."
            ;;
        "typescript")
            rule_content="---
description: TypeScript skill routing (version $skill_version)
globs: [\"**/*.ts\", \"**/*.tsx\"]
alwaysApply: false
---

Read $skills_path/$skill_name/$skill_version/SKILL.md before writing or editing TypeScript code."
            ;;
        "rust")
            rule_content="---
description: Rust skill routing (version $skill_version)
globs: [\"**/*.rs\"]
alwaysApply: false
---

Read $skills_path/$skill_name/$skill_version/SKILL.md before writing or editing Rust code."
            ;;
        *)
            rule_content="---
description: $skill_name skill routing (version $skill_version)
globs: [\"**/*\"]
alwaysApply: false
---

Read $skills_path/$skill_name/$skill_version/SKILL.md when working with $skill_name."
            ;;
    esac
    
    safe_append_to_file "$rule_file" "$rule_content" "mdc" true
}

# Main function for command line usage
main() {
    case "$1" in
        "append")
            if [[ $# -lt 4 ]]; then
                echo "Usage: $0 append <file_path> <content> <file_type> [backup]"
                exit 1
            fi
            safe_append_to_file "$2" "$3" "$4" "${5:-true}"
            ;;
        "merge")
            if [[ $# -lt 3 ]]; then
                echo "Usage: $0 merge <target_file> <file_type> <source_file1> [source_file2] ..."
                exit 1
            fi
            target="$2"
            file_type="$3"
            shift 3
            merge_rule_files "$target" "$file_type" "$@"
            ;;
        "cursor-rule")
            if [[ $# -lt 3 ]]; then
                echo "Usage: $0 cursor-rule <skill_name> <skill_version> [skills_path]"
                exit 1
            fi
            update_cursor_rule "$2" "$3" "$4"
            ;;
        "check")
            if [[ $# -lt 3 ]]; then
                echo "Usage: $0 check <file_path> <rule_identifier>"
                exit 1
            fi
            if rule_block_exists "$2" "$3"; then
                echo "Rule exists in file"
                exit 0
            else
                echo "Rule does not exist in file"
                exit 1
            fi
            ;;
        *)
            echo "Usage: $0 {append|merge|cursor-rule|check} [options]"
            echo ""
            echo "Commands:"
            echo "  append <file> <content> <type> [backup]    Safely append content to file"
            echo "  merge <target> <type> <source1> ...       Merge multiple files"
            echo "  cursor-rule <skill> <version> [path]      Create/update Cursor rule"
            echo "  check <file> <identifier>                 Check if rule exists"
            echo ""
            echo "File types: mdc, md, claude"
            exit 1
            ;;
    esac
}

# Run main if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi