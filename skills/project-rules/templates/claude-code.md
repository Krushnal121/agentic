# Agentic Skills - Auto-Loading Rules

This file enables automatic skill loading based on your project context. Skills are loaded conditionally to minimize context overhead while ensuring the right expertise is available when needed.

## Universal Rules (Always Active)

- **ALWAYS** read the relevant `skills/<skill-name>/SKILL.md` BEFORE writing any code or creating any file (if the skill exists)
- **NEVER** skip skill loading even for "simple" versions of covered tasks
- Skills contain critical patterns, constraints, and best practices for their domain

## File Type Triggers (When Skills Are Installed)

When working with these file types, the corresponding skill loads automatically if installed:

- **Word documents** (`.docx`) → Load `skills/docx/SKILL.md` (if exists)
- **PDF files** (`.pdf`) → Load `skills/pdf/SKILL.md` (if exists)
- **Presentations** (`.pptx`) → Load `skills/pptx/SKILL.md` (if exists)
- **Spreadsheets** (`.xlsx`) → Load `skills/xlsx/SKILL.md` (if exists)
- **Uploaded files** not yet in context → Load `skills/file-reading/SKILL.md` (if exists)

## Language-Specific Rules

Language skills are stored in separate `.claude/rules/agentic-<lang>-<version>.md` files to avoid bloating this root file. The setup skill creates these files only for installed skills with their specific versions.

**Installed Skills with Versions** (setup detects these automatically):
{SKILL_LIST}

## Versioned Skill Installation

This configuration supports mixed skill and version installation:
- Install Go 1.26: Gets `.claude/rules/agentic-go-1.26.md`
- Install Python 3.12: Gets `.claude/rules/agentic-python-3.12.md`
- All skills and versions work independently without conflicts

## How It Works

1. **Conditional Loading**: Language skills only activate when you're primarily working with that language
2. **Context Optimization**: Only installed skills load, keeping context lean and focused
3. **Expertise On-Demand**: The right domain knowledge appears exactly when needed
4. **Zero Manual Invocation**: You never need to say "use the go skill" - it just works
5. **Additive Installation**: New skills integrate seamlessly with existing ones

## Troubleshooting

If a skill isn't loading when expected:

1. Check that you're working with files of the expected type/extension
2. Ensure the skill file exists at `skills/<skill-name>/SKILL.md`
3. Verify the language is the primary focus of your current task
4. Check `.claude/rules/` for `agentic-<lang>.md` rule files
5. Re-run setup skill if you've installed new skills

## Customization

To modify skill loading behavior:
1. Edit the templates in `skills/project-rules/templates/`
2. Re-run the setup skill to regenerate this file
3. The setup skill will detect newly installed skills automatically