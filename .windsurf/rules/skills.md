# Agentic Skills - Windsurf Rules

Auto-loading skill configuration for Windsurf IDE.

## Universal Rules

**Always apply these rules:**

- Read the relevant `skills/<skill-name>/SKILL.md` BEFORE writing any code or creating any file
- Never skip skill loading even for "simple" versions of covered tasks
- When files are uploaded but not yet in context → load `skills/file-reading/SKILL.md` FIRST

## Conditional Skill Loading

### Language Skills (Load only when working primarily with these file types)
### Go Development (Version 1.26)

**Triggers on**: `*.go`, `go.mod`, `go.sum`


- Enterprise Go 1.26 development patterns
- Modern tooling integration (mockery, testcontainers, golangci-lint)
- Security practices and performance optimization
- Production-ready patterns for senior developers

### Document Processing Skills (Load when working with these file types)

**Microsoft Word** - If `skills/docx/SKILL.md` exists, triggers on: `*.docx`
```
When working with Word documents → load skills/docx/SKILL.md
```

**PDF Documents** - If `skills/pdf/SKILL.md` exists, triggers on: `*.pdf`
```
When working with PDF files → load skills/pdf/SKILL.md
```

**PowerPoint Presentations** - If `skills/pptx/SKILL.md` exists, triggers on: `*.pptx`
```
When working with presentations → load skills/pptx/SKILL.md
```

**Excel Spreadsheets** - If `skills/xlsx/SKILL.md` exists, triggers on: `*.xlsx`
```
When working with spreadsheets → load skills/xlsx/SKILL.md
```

## Configuration Notes

- **Conditional Loading**: Language skills only activate when those file types are the primary focus
- **Context Optimization**: Only installed skills load to keep context lean
- **Zero Manual Invocation**: Skills auto-load based on project context
- **Single Source of Truth**: Skill content lives in `skills/` directory, not in these rules
- **Version Support**: Supports multiple skill versions without conflicts
- **Additive Installation**: New skills integrate without affecting existing ones

## Troubleshooting

If skills aren't loading as expected:

1. Verify you're working with files matching the trigger patterns
2. Check that skill files exist at `skills/<skill-name>/SKILL.md`  
3. Ensure the language is the primary focus of your current task
4. Confirm Windsurf is reading from `.windsurf/rules/skills.md`

## Customization

To modify loading behavior:
1. Edit `skills/project-rules/templates/windsurf.md`
2. Re-run the setup skill to regenerate `.windsurf/rules/skills.md`
3. Commit changes to share with your team
