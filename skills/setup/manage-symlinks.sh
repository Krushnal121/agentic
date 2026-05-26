#!/bin/bash

# Safe Symlink Management for Agentic Skills Setup
# Handles symlink creation with safety checks and idempotent behavior

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if a symlink is safe to create or update
check_symlink_safety() {
    local link_path="$1"
    local target_path="$2"
    
    # If link doesn't exist, it's safe to create
    if [[ ! -e "$link_path" && ! -L "$link_path" ]]; then
        return 0
    fi
    
    # If it exists and is a symlink
    if [[ -L "$link_path" ]]; then
        current_target=$(readlink "$link_path")
        
        # If pointing to the same target, no action needed
        if [[ "$current_target" == "$target_path" ]]; then
            log_info "Symlink $link_path already points to $target_path"
            return 1  # No action needed
        fi
        
        # If pointing to different target, check if we should update
        log_warn "Symlink $link_path currently points to: $current_target"
        log_warn "Setup wants to point it to: $target_path"
        return 2  # Needs update
    fi
    
    # If it exists but is not a symlink
    if [[ -e "$link_path" ]]; then
        if [[ -d "$link_path" ]]; then
            log_error "Cannot create symlink: $link_path exists as a directory"
        else
            log_error "Cannot create symlink: $link_path exists as a regular file"
        fi
        return 3  # Cannot create
    fi
    
    return 0  # Safe to create
}

# Create or update symlink safely
create_safe_symlink() {
    local link_path="$1"
    local target_path="$2"
    local force="${3:-false}"
    
    # Check safety
    check_symlink_safety "$link_path" "$target_path"
    local safety_result=$?
    
    case $safety_result in
        0)
            # Safe to create
            ln -sf "$target_path" "$link_path"
            log_info "Created symlink: $link_path -> $target_path"
            return 0
            ;;
        1)
            # No action needed
            return 0
            ;;
        2)
            # Needs update
            if [[ "$force" == "true" ]]; then
                ln -sf "$target_path" "$link_path"
                log_info "Updated symlink: $link_path -> $target_path"
                return 0
            else
                log_warn "Use --force to update existing symlink"
                return 1
            fi
            ;;
        3)
            # Cannot create
            log_error "Cannot create symlink at $link_path"
            return 1
            ;;
    esac
}

# Setup skills symlink with safety checks
setup_skills_symlink() {
    local target_skills_dir="$1"
    local force="${2:-false}"
    
    # Default target is .agents/skills if not specified
    if [[ -z "$target_skills_dir" ]]; then
        target_skills_dir=".agents/skills"
    fi
    
    # Check if target directory exists
    if [[ ! -d "$target_skills_dir" ]]; then
        log_error "Target skills directory '$target_skills_dir' does not exist"
        log_error "Cannot create symlink to non-existent directory"
        return 1
    fi
    
    # Check if skills directory already exists
    if [[ -L "skills" ]]; then
        current_target=$(readlink "skills")
        
        # If already pointing to the right place
        if [[ "$current_target" == "$target_skills_dir" ]]; then
            log_info "Skills symlink already correctly configured"
            return 0
        fi
        
        # If pointing somewhere else
        log_warn "Skills symlink currently points to: $current_target"
        log_warn "Setup wants to point it to: $target_skills_dir"
        
        if [[ "$force" == "true" ]]; then
            ln -sf "$target_skills_dir" "skills"
            log_info "Updated skills symlink to point to $target_skills_dir"
            return 0
        else
            log_warn "Use --force to update existing skills symlink"
            return 1
        fi
        
    elif [[ -d "skills" ]] && [[ ! -L "skills" ]]; then
        # skills exists as a regular directory
        log_error "Cannot create symlink: 'skills' exists as a directory"
        log_error "You may need to:"
        log_error "  1. Backup existing skills/ directory"
        log_error "  2. Remove or rename it"
        log_error "  3. Re-run setup to create the symlink"
        return 1
        
    elif [[ -f "skills" ]]; then
        # skills exists as a file
        log_error "Cannot create symlink: 'skills' exists as a file"
        return 1
        
    else
        # Safe to create new symlink
        ln -sf "$target_skills_dir" "skills"
        log_info "Created skills symlink: skills -> $target_skills_dir"
        return 0
    fi
}

# Validate symlink integrity
validate_skills_symlink() {
    if [[ ! -L "skills" ]]; then
        log_error "Skills symlink does not exist"
        return 1
    fi
    
    local target=$(readlink "skills")
    
    if [[ ! -d "$target" ]]; then
        log_error "Skills symlink points to non-existent directory: $target"
        return 1
    fi
    
    # Check if we can read from the target
    if [[ ! -r "$target" ]]; then
        log_error "Cannot read from skills target directory: $target"
        return 1
    fi
    
    log_info "Skills symlink is valid and points to: $target"
    return 0
}

# Main function for command line usage
main() {
    case "$1" in
        "setup")
            setup_skills_symlink "$2" "$3"
            ;;
        "validate")
            validate_skills_symlink
            ;;
        "create")
            if [[ $# -lt 3 ]]; then
                echo "Usage: $0 create <link_path> <target_path> [force]"
                exit 1
            fi
            create_safe_symlink "$2" "$3" "$4"
            ;;
        *)
            echo "Usage: $0 {setup|validate|create} [options]"
            echo ""
            echo "Commands:"
            echo "  setup [target_dir] [force]    Setup skills symlink"
            echo "  validate                      Validate existing symlink"
            echo "  create <link> <target> [force] Create/update symlink"
            echo ""
            echo "Options:"
            echo "  force                         Update existing symlinks"
            exit 1
            ;;
    esac
}

# Run main if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi