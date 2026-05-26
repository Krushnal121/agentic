# GitHub Copilot - Agentic Skills Integration

Auto-loading skill configuration for GitHub Copilot.

## Core Instruction

**Before writing any code or creating any file, consult the relevant skill documentation from the `skills/` directory.**

## Skill Loading Rules

### Universal Requirements

- Always read the appropriate `skills/<skill-name>/SKILL.md` before coding
- Never skip skill loading, even for simple tasks within a skill's domain
- Skills contain critical patterns, constraints, and best practices

### File Type Triggers

Load these skills automatically based on file context (only if installed):

- **Word Documents (`.docx`)**: Load and follow `skills/docx/SKILL.md` (if exists)
- **PDF Files (`.pdf`)**: Load and follow `skills/pdf/SKILL.md` (if exists)
- **Presentations (`.pptx`)**: Load and follow `skills/pptx/SKILL.md` (if exists)
- **Spreadsheets (`.xlsx`)**: Load and follow `skills/xlsx/SKILL.md` (if exists)
- **Uploaded Files**: If files are uploaded but not in context, load `skills/file-reading/SKILL.md` (if exists)

### Language-Specific Skills

Load these skills when the specified language is the primary focus (only if installed):

**Installed Skills**: {SKILL_LIST}

Example triggers (only active for installed skills):
- **Go (`.go`, `go.mod`, `go.sum`)**: Load and follow `skills/go/SKILL.md`
- **Python (`.py`)**: Load and follow `skills/python/SKILL.md`
- **TypeScript (`.ts`, `.tsx`)**: Load and follow `skills/typescript/SKILL.md`
- **Rust (`.rs`)**: Load and follow `skills/rust/SKILL.md`

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
```
Following skills/go/SKILL.md guidelines for Go development...
```

## Usage Notes

- Skills are located in the `skills/` directory relative to project root
- Each skill has comprehensive documentation in its `SKILL.md` file
- Skills may have prerequisites or dependencies listed in their documentation
- Some skills are versioned (like Go) - check branches for specific versions

## Troubleshooting

If skills aren't being applied correctly:

1. Verify the skill file exists at `skills/<skill-name>/SKILL.md`
2. Check that file extensions match the trigger patterns
3. Ensure the language/file type is the primary focus of the current task
4. Confirm GitHub Copilot is reading instructions from `.github/copilot-instructions.md`

## Customization

To modify skill loading:
1. Edit the template at `skills/project-rules/templates/copilot.md`
2. Re-run the setup skill to update `.github/copilot-instructions.md`
3. Changes will apply to all team members using GitHub Copilot