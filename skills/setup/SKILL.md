---
name: setup
description: >
  Use when the user wants to configure agentic skills for their IDE, setup skill routing,
  generate IDE rule files, or configure project-specific skill automation. Also use when
  setting up a new project to work with agentic skills. Do NOT use for general project
  setup unrelated to skill routing or IDE configuration.
---

# Setup

## When to Invoke
- User asks to setup agentic skills for their project
- User wants to configure skill routing for their IDE
- User mentions generating IDE rule files
- User asks how to configure their IDE to work with skills
- User wants to enable automatic skill loading
- NOT: General project initialization unrelated to skills
- NOT: Installing skills (use npx skills add instead)

## Prerequisites
None. This is typically the first skill to run in a new project.

## Reference

This skill sets up automatic skill routing for your IDE by detecting which IDEs are configured in your project and generating the appropriate rule files.

### Supported IDEs

The skill detects and configures these IDEs:

| IDE | Detection | Generated File |
|---|---|---|
| Claude Code | `.claude/` directory or existing `CLAUDE.md` | `CLAUDE.md` at project root |
| Cursor | `.cursor/` directory | `.cursor/rules/skills.mdc` |
| Windsurf | `.windsurf/` directory | `.windsurf/rules/skills.md` |
| GitHub Copilot | `.github/` directory | `.github/copilot-instructions.md` |
| Codex | `AGENTS.md` exists | `AGENTS.md` (append to existing) |

### Setup Process

1. **Scan for IDE indicators**: Check project root for IDE-specific directories and files
2. **Copy templates**: For each detected IDE, copy the appropriate template from `skills/project-rules/templates/`
3. **Render rules**: Generate IDE-specific rule files with proper skill routing logic
4. **Handle existing files**: If target files exist, append skill routing blocks rather than overwrite
5. **Report results**: Print summary of what was created or updated

### Routing Logic Generated

The setup creates rules that automatically load the right skills based on context:

**File Type Triggers:**
- `.docx` files → load `skills/docx/SKILL.md`
- `.pdf` files → load `skills/pdf/SKILL.md`
- `.pptx` files → load `skills/pptx/SKILL.md`
- `.xlsx` files → load `skills/xlsx/SKILL.md`
- Uploaded files not in context → load `skills/file-reading/SKILL.md` first

**Language Triggers (only when primary language):**
- `.go`, `go.mod`, `go.sum` → load `skills/go/SKILL.md`
- `.py` files → load `skills/python/SKILL.md`
- `.ts`, `.tsx` files → load `skills/typescript/SKILL.md`
- `.rs` files → load `skills/rust/SKILL.md`

**Universal Rules:**
- Always read the relevant `SKILL.md` BEFORE writing any code
- Never skip skill loading even for "simple" tasks

### Implementation Steps

When this skill is invoked, it follows an enhanced workflow that addresses robustness and safety:

1. **Setup skills directory access (Enhanced):**
   ```
   - Detect skills source directory (.agents/skills, skills/, or custom path)
   - Create safe symlink if needed (with conflict detection and validation)
   - Verify symlink integrity and permissions
   - Support idempotent reruns without breaking existing setups
   ```

2. **Scan for installed skills with improved version detection:**
   ```
   - Check for versioned skills: skills/<name>/<version>/SKILL.md (e.g., skills/go/1.26/SKILL.md)
   - Check for direct skills: skills/<name>/SKILL.md (e.g., skills/setup/SKILL.md)
   - Follow symlinks intelligently: skills/<name>/latest -> <version>/
   - Detect whether "latest" is alias or separate version
   - Extract version metadata from SKILL.md frontmatter (version, stability, features)
   - Generate rules only for actual versions, not aliases
   - Support any skill type: languages, frameworks, auth, infrastructure, databases
   ```

3. **Check project root for IDE indicators:**
   ```
   - Look for .claude/ directory or CLAUDE.md file
   - Look for .cursor/ directory
   - Look for .windsurf/ directory  
   - Look for .github/ directory
   - Look for existing AGENTS.md file
   ```

4. **For each detected IDE (with merge safety):**
   - Copy the base template from `skills/project-rules/templates/`
   - Create skills index file (e.g., `.cursor/rules/skills.mdc`)
   - Generate universal rules file
   - Create individual skill rule files with version
   - **Enhanced safety:** Check for existing content before writing
   - **Enhanced safety:** Append/merge rather than overwrite existing files
   - **Enhanced safety:** Create backup files before modifications
   - **Enhanced safety:** Validate rule uniqueness to prevent duplicates

5. **Target file paths with index files:**
   - Cursor: 
     - `.cursor/rules/skills.mdc` (master index - NEW)
     - `.cursor/rules/agentic-universal.mdc` (always active rules)
     - `.cursor/rules/agentic-<skill>-<version>.mdc` per versioned skill
   - Claude Code: `CLAUDE.md` (project root) + `.claude/rules/agentic-<skill>-<version>.md` per versioned skill
   - Windsurf: `.windsurf/rules/skills.md` (single file with all rules and versions)
   - GitHub Copilot: `.github/copilot-instructions.md` (single file with all rules and versions)
   - Codex: `AGENTS.md` (project root, append with version info)

6. **Enhanced validation and safety:**
   ```
   - Validate symlink integrity
   - Check file permissions and accessibility
   - Verify rule file syntax
   - Test for duplicate content
   - Validate skill file existence
   - Create backups before modifications
   ```

7. **Print comprehensive summary:**
   ```
   ✓ Skills directory access configured: skills -> .agents/skills
   ✓ Detected skills: go (latest -> 1.26), python (3.12), react (18.2)
   ✓ Version resolution: latest alias resolved to actual versions
   ✓ Detected Cursor (.cursor/ directory)
   ✓ Created .cursor/rules/skills.mdc (master index)
   ✓ Created .cursor/rules/agentic-universal.mdc (universal rules)
   ✓ Created .cursor/rules/agentic-go-1.26.mdc (version-specific rules)
   ✓ Validation: All symlinks and rule files verified
   
   Next steps:
   - Commit the generated files to version control  
   - Skills auto-load based on file patterns and versions
   - Multiple skill versions can coexist without conflicts
   - Re-run setup safely after installing new skills
   - Enhanced merge behavior prevents duplicate rules
   ```

### Template Rendering

Templates in `skills/project-rules/templates/` contain the IDE-specific syntax for:
- Conditional loading based on file patterns
- Skill references pointing to correct SKILL.md files
- IDE-specific configuration (globs, alwaysApply, etc.)

The setup skill copies these templates exactly - no variable substitution is needed as templates contain the final rule syntax.

## Enhanced Tools and Scripts

The setup skill includes several utility scripts for improved robustness:

### Version Detection (`detect-versions.sh`)
- Intelligently detects installed skills and their versions
- Properly handles symlinks and aliases (e.g., `latest -> 1.26`)
- Differentiates between real versions and aliases
- Prevents duplicate rule generation for aliased versions
- Outputs structured data for processing

### Symlink Management (`manage-symlinks.sh`) 
- Safe symlink creation with conflict detection
- Idempotent behavior - safe to run multiple times
- Validates existing symlinks and their targets
- Provides clear warnings for manual intervention needed
- Supports force updates when needed

### Rule Merging (`merge-rules.sh`)
- Safe append/merge behavior for existing files
- Duplicate detection prevents rule conflicts  
- Creates backup files before modifications
- Supports multiple IDE rule formats
- Maintains rule integrity across reruns

### Enhanced Setup (`enhanced-setup.sh`)
- Main orchestration script incorporating all improvements
- Comprehensive validation and error handling
- Clear progress reporting and summary
- Command-line options for customization
- Addresses all identified workflow gaps

## Constraints

- Never overwrite existing IDE rule files completely - always append/merge
- Only generate rules for IDEs that are actually detected in the project
- Always create necessary directories before writing files
- Create backup files before modifying existing configurations
- Print clear summary of actions taken with validation results
- If no IDEs are detected, inform the user and suggest manual setup options
- Never modify the skill files themselves, only generate IDE rule files
- Ensure generated rules use conditional loading (not always-on) for language skills
- Validate symlink integrity and provide clear error messages for conflicts
- Support safe reruns without breaking existing configurations