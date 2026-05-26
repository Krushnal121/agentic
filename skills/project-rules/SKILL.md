---
name: project-rules
description: >
  Use when the user wants to understand or configure skill routing logic, create IDE-specific
  rule files, set up conditional skill loading, or customize how skills are automatically
  invoked. Also use when troubleshooting skill loading issues or when working with IDE
  rule templates. Do NOT use for general IDE configuration unrelated to skill routing.
---

# Project Rules

## When to Invoke
- User asks about skill routing logic or how skills are automatically loaded
- User wants to customize IDE rule generation
- User is troubleshooting skill loading issues
- User mentions conditional skill loading or file-based triggers
- User wants to understand the templates in project-rules/templates/
- User asks how to prevent skills from loading when not needed
- NOT: General IDE setup unrelated to skill routing
- NOT: Installing or managing skills themselves

## Prerequisites
This skill is typically invoked by the `setup` skill but can be used independently for customization.

## Reference

This skill contains the core routing logic and templates that enable automatic skill loading based on project context. The goal is **zero manual skill invocation** - skills should load automatically when relevant and stay out of the way when not needed.

### Core Routing Principles

1. **Conditional Loading**: Language skills only load when working with files of that language
2. **File Type Triggers**: Document skills load based on file extensions
3. **Universal Rules**: Some rules (like "read SKILL.md before coding") apply everywhere
4. **Single Source of Truth**: All logic is defined once in templates, then generated for each IDE
5. **Modular Installation**: Skills can be installed independently from different branches
6. **Additive Configuration**: New skills integrate without affecting existing ones
7. **Skill Detection**: Setup automatically scans for installed skills and configures accordingly

### Routing Logic

The templates implement this trigger hierarchy:

#### File Type Triggers (Always Apply)
```
.docx files → skills/docx/SKILL.md
.pdf files → skills/pdf/SKILL.md  
.pptx files → skills/pptx/SKILL.md
.xlsx files → skills/xlsx/SKILL.md
Uploaded files not in context → skills/file-reading/SKILL.md (load first)
```

#### Language Triggers (Conditional - Only When Primary Language)
```
.go, go.mod, go.sum → skills/go/SKILL.md
.py files → skills/python/SKILL.md
.ts, .tsx files → skills/typescript/SKILL.md
.rs files → skills/rust/SKILL.md
```

#### Framework & Technology Triggers (Conditional - When Working with Specific Tech)
```
React components, JSX → skills/react/SKILL.md
Auth directories, login flows → skills/auth/SKILL.md  
Dockerfile, docker-compose → skills/docker/SKILL.md
Kubernetes manifests → skills/kubernetes/SKILL.md
Terraform files → skills/terraform/SKILL.md
```

#### Universal Rules (Always Apply)
```
- Read relevant SKILL.md BEFORE writing any code or creating any file
- Never skip skill loading even for "simple" versions of covered tasks
```

### IDE-Specific Implementation

Each IDE has different syntax for conditional loading:

#### Cursor (.cursor/rules/*.mdc)
- **Split into multiple files**: One per trigger group
- **Use `globs` + `alwaysApply: false`** for language rules
- **Only universal rules use `alwaysApply: true`**
- **Keep universal rules under 10 lines**

Example structure:
```
.cursor/rules/
├── universal.mdc (alwaysApply: true, <10 lines)
├── go.mdc (globs: ["**/*.go"], alwaysApply: false)
├── python.mdc (globs: ["**/*.py"], alwaysApply: false)
└── typescript.mdc (globs: ["**/*.ts", "**/*.tsx"], alwaysApply: false)
```

#### Claude Code (CLAUDE.md)
- **Single file at root** with routing logic
- **Keep under 80 lines total**
- **Language rules go in separate `.claude/rules/<lang>.md` files**
- **Reference skills/ directory for SKILL.md files**

#### Windsurf (.windsurf/rules/skills.md)
- **Single markdown file** with conditional syntax
- **Use Windsurf-specific conditional formatting**

#### GitHub Copilot (.github/copilot-instructions.md)
- **Append to existing file** if present
- **Use GitHub Copilot instruction format**
- **Include file pattern matching**

### Template Structure

Each template in `templates/` contains:

1. **IDE-specific header/frontmatter** (if required)
2. **Universal rules** (always active)
3. **File type triggers** (document processing)
4. **Language triggers** (conditional on file patterns)
5. **Skill reference paths** pointing to skills/ directory

### Template Rendering Process

When `setup` skill runs:

1. **Scan installed skills**: Check which `skills/<name>/SKILL.md` files exist
2. **Detect IDE**: Check for IDE-specific directories/files
3. **Render base template**: Replace {SKILL_LIST} with detected skills
4. **Create modular files**: Generate separate config files per skill (for Cursor/Claude Code)
5. **Write to targets**: Place files in IDE-expected locations
6. **Create directories**: Make parent directories if needed
7. **Handle conflicts**: Merge with existing files rather than overwrite

### Versioned Skill Architecture

This design supports mixed skill installation with version selection:

```bash
# Primary installation with version picker
npx skills add Krushnal121/agentic
# Shows: ☑ go (1.26 - latest, enterprise patterns) ☑ python (3.12 - latest) etc.

# Direct version installation (for specific requirements)
npx skills add https://github.com/Krushnal121/agentic/skills/go/1.25

# Mix different versions as needed
# Install Go 1.26, Python 3.11, React 17 - all work together

# Re-run setup to detect new skills and versions
```

**Result**: All skills and versions work independently without conflicts:
- **Cursor gets**: `agentic-go-1.26.mdc`, `agentic-python-3.12.mdc`, `agentic-react-18.mdc`
- **Claude Code gets**: Individual `.claude/rules/agentic-{skill}-{version}.md` files for each
- **Universal rules**: Stay consistent across all skill types and versions
- **Trigger patterns**: Each skill version defines its own file patterns and trigger conditions

### Skill Type Examples

The system supports any skill type with appropriate trigger patterns:

| Skill Type | Version Example | Trigger Patterns | Use Case |
|------------|----------------|------------------|----------|
| **Language** | `go/1.26` | `*.go`, `go.mod`, `go.sum` | Version-specific language features |
| **Framework** | `react/18` | `*.jsx`, `*.tsx`, `components/**` | Framework-specific patterns |
| **Auth** | `auth/oauth2` | `**/auth/**`, `**/*oauth*`, login flows | Authentication implementation |
| **Infrastructure** | `docker/24` | `Dockerfile`, `docker-compose*` | Container orchestration |
| **Database** | `postgres/15` | `*.sql`, migrations, schema files | Database-specific patterns |

### Customization

To customize routing for your project:

1. **Modify templates**: Edit files in `skills/project-rules/templates/`
2. **Re-run setup**: Execute setup skill to regenerate IDE files
3. **Test loading**: Verify skills load only when expected

### Debugging Skill Loading

If skills aren't loading as expected:

1. **Check file patterns**: Ensure your files match the glob patterns
2. **Verify IDE rules**: Confirm the rule file exists in the right location
3. **Test conditions**: Check if the trigger conditions are met
4. **Review logs**: Look for IDE-specific skill loading messages

### Adding New IDEs

To support a new IDE:

1. **Create template**: Add new template in `templates/` directory
2. **Update setup skill**: Add IDE detection logic
3. **Define target path**: Specify where the IDE expects rule files
4. **Test integration**: Verify skill loading works with new IDE

## Constraints

- Templates must use conditional loading for language skills (not always-on)
- Universal rules should be minimal and under 10 lines where possible
- Never duplicate skill content between templates and SKILL.md files
- Templates reference skills/ directory, never embed skill content
- All templates must be IDE-agnostic content delivered through IDE-specific wrappers
- Language skills only load when that language is the primary focus of the task
- File type skills load whenever those file types are involved
- Keep template complexity minimal - prefer simple pattern matching over complex logic