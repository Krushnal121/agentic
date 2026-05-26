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

When this skill is invoked:

1. **Scan for installed skills:**
   ```
   - Check which skills/ directories exist (any type: go, python, react, auth, docker, etc.)
   - Verify each has a valid SKILL.md file
   - Build list of available skills for template rendering
   - Support any skill type: languages, frameworks, auth, infrastructure, databases
   ```

2. **Check project root for IDE indicators:**
   ```
   - Look for .claude/ directory or CLAUDE.md file
   - Look for .cursor/ directory
   - Look for .windsurf/ directory  
   - Look for .github/ directory
   - Look for existing AGENTS.md file
   ```

3. **For each detected IDE:**
   - Copy the base template from `skills/project-rules/templates/`
   - Replace {SKILL_LIST} placeholder with detected skills
   - Write base configuration to target location
   - For Cursor: Create individual .mdc files for each detected skill
   - For Claude Code: Create individual .claude/rules/agentic-<skill>.md files
   - If files exist, append/merge rather than overwrite

4. **Target file paths:**
   - Claude Code: `CLAUDE.md` (project root) + `.claude/rules/agentic-<skill>.md` per skill
   - Cursor: `.cursor/rules/agentic-universal.mdc` + `.cursor/rules/agentic-<skill>.mdc` per skill
   - Windsurf: `.windsurf/rules/skills.md` (single file with all rules)
   - GitHub Copilot: `.github/copilot-instructions.md` (single file with all rules)
   - Codex: `AGENTS.md` (project root, append)

5. **Create missing directories** if needed (e.g., `.cursor/rules/`, `.claude/rules/`)

6. **Print summary** of actions taken:
   ```
   ✓ Detected skills: go (1.23.x), react (18.2), auth (saml), docker (24)
   ✓ Detected Claude Code (.claude/ directory)
   ✓ Generated CLAUDE.md with skill routing rules
   ✓ Created .claude/rules/agentic-go.md, agentic-react.md, agentic-auth.md, agentic-docker.md
   ✓ Detected Cursor (.cursor/ directory)
   ✓ Created .cursor/rules/agentic-universal.mdc
   ✓ Created .cursor/rules/agentic-go.mdc, agentic-react.mdc, agentic-auth.mdc, agentic-docker.mdc
   
   Next steps:
   - Commit the generated files to version control
   - Any skill type can be installed from versioned branches
   - Re-run setup after installing new skills to update configuration
   - Mix and match skills from any branches - they all integrate seamlessly
   ```

### Template Rendering

Templates in `skills/project-rules/templates/` contain the IDE-specific syntax for:
- Conditional loading based on file patterns
- Skill references pointing to correct SKILL.md files
- IDE-specific configuration (globs, alwaysApply, etc.)

The setup skill copies these templates exactly - no variable substitution is needed as templates contain the final rule syntax.

## Constraints

- Never overwrite existing IDE rule files completely - always append
- Only generate rules for IDEs that are actually detected in the project
- Always create necessary directories before writing files
- Print clear summary of actions taken
- If no IDEs are detected, inform the user and suggest manual setup options
- Never modify the skill files themselves, only generate IDE rule files
- Ensure generated rules use conditional loading (not always-on) for language skills