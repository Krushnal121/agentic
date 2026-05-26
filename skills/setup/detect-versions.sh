#!/bin/bash

# Version Detection Script for Agentic Skills Setup
# Detects installed skills and resolves version aliases properly

detect_skill_versions() {
    local skills_dir="$1"
    local skill_name="$2"
    local skill_path="$skills_dir/$skill_name"
    
    if [[ ! -d "$skill_path" ]]; then
        return 1
    fi
    
    # Array to store detected versions
    declare -a versions=()
    declare -a resolved_versions=()
    
    # Find all version directories (numeric versions only)
    for version_dir in "$skill_path"/*; do
        if [[ -d "$version_dir" ]]; then
            version=$(basename "$version_dir")
            
            # Skip symlinks for now, process them separately
            if [[ ! -L "$version_dir" ]] && [[ -f "$version_dir/SKILL.md" ]]; then
                versions+=("$version")
            fi
        fi
    done
    
    # Process symlinks (like 'latest')
    for link in "$skill_path"/*; do
        if [[ -L "$link" ]]; then
            link_name=$(basename "$link")
            target=$(readlink "$link")
            
            # Resolve target to absolute path if relative
            if [[ "$target" != /* ]]; then
                target="$skill_path/$target"
            fi
            
            target_version=$(basename "$target")
            
            # Check if target version exists and is valid
            if [[ " ${versions[*]} " =~ " ${target_version} " ]]; then
                echo "ALIAS,$link_name,$target_version"
                resolved_versions+=("$target_version")
            fi
        fi
    done
    
    # Output real versions (excluding those that are just aliases)
    for version in "${versions[@]}"; do
        if [[ ! " ${resolved_versions[*]} " =~ " ${version} " ]]; then
            echo "VERSION,$version,$version"
        fi
    done
}

# Detect all skills and their versions
detect_all_skills() {
    local skills_dir="${1:-skills}"
    
    if [[ ! -d "$skills_dir" ]]; then
        echo "ERROR: Skills directory '$skills_dir' not found"
        return 1
    fi
    
    for skill_dir in "$skills_dir"/*; do
        if [[ -d "$skill_dir" ]]; then
            skill_name=$(basename "$skill_dir")
            
            # Skip template directories and other non-skill directories
            if [[ "$skill_name" == "project-rules" ]]; then
                continue
            fi
            
            echo "SKILL,$skill_name"
            detect_skill_versions "$skills_dir" "$skill_name"
        fi
    done
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    detect_all_skills "$@"
fi