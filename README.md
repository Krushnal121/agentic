# agentic

**Stop re-explaining your stack. Skill up your agent.**

Transform any coding AI into a domain expert that automatically loads the right knowledge at the right time. No more "use the Python skill" or re-explaining your architecture — your agent just *knows*.

[![skills.sh](https://skills.sh/b/Krushnal121/agentic)](https://skills.sh/Krushnal121/agentic)

## The Problem

Every conversation with your coding AI starts the same way:

- "I'm working on a Go microservice using Chi and PostgreSQL..."
- "Remember to follow our team's naming conventions..."
- "Use our testing patterns from the last project..."
- "Don't forget the error handling we discussed..."

**Your agent has amnesia. Every. Single. Time.**

## The Solution

**Zero-friction skill loading** that makes your agent context-aware:

```bash
# One command, infinite intelligence
npx skills add Krushnal121/agentic
```

Your agent instantly gains:
- **Language expertise** — Go patterns, Python best practices, TypeScript types
- **Architecture knowledge** — Your project structure, naming conventions, patterns
- **Smart loading** — Only relevant skills activate, keeping context lean
- **Team consistency** — Everyone gets the same expert guidance

## How It Works

### Auto-Detection Magic
```bash
# Your agent sees: main.go
# Instantly loads: Go 1.24 best practices, testing patterns, build tools
```

### IDE-Native Integration
Works with your existing workflow:
- **Cursor** → `.cursor/rules/*.mdc` 
- **Claude Code** → `CLAUDE.md` + `.claude/rules/`
- **Windsurf** → `.windsurf/rules/skills.md`
- **GitHub Copilot** → `.github/copilot-instructions.md`

### Zero Manual Invocation
```diff
- "Use the Python skill to help me debug this FastAPI endpoint"
+ *Automatically detects .py file and loads Python expertise*
```

## Quick Start

### 1. Install Skills
```bash
# Install all skills
npx skills add Krushnal121/agentic

# Or install globally with IDE adapter
npx skills add Krushnal121/agentic -g -a claude-code
```

### 2. Setup IDE Integration
```bash
# In your project, tell your agent:
"Run the setup skill"
```

This auto-detects your IDE and generates the right config files:
- Cursor → `.cursor/rules/` with conditional loading
- Claude Code → `CLAUDE.md` with smart routing  
- Windsurf → `.windsurf/rules/skills.md`
- GitHub Copilot → `.github/copilot-instructions.md`

### 3. Code Like Magic
```bash
# Open any .go file
# Agent automatically knows Go best practices

# Switch to .py file  
# Agent instantly becomes Python expert

# Edit .ts file
# TypeScript mastery activated
```

### 4. Share with Your Team
```bash
# Commit the generated IDE configuration files
# Team members automatically get the same intelligent behavior
```

## Advanced Features

### Versioned & Specialized Skills
Pin to specific versions or install specialized skills:
```bash
# Language versions
npx skills add https://github.com/Krushnal121/agentic/tree/go/1.23/skills/go
npx skills add https://github.com/Krushnal121/agentic/tree/python/3.12/skills/python

# Framework versions  
npx skills add https://github.com/Krushnal121/agentic/tree/react/18.2/skills/react
npx skills add https://github.com/Krushnal121/agentic/tree/vue/3.4/skills/vue

# Specialized auth skills
npx skills add https://github.com/Krushnal121/agentic/tree/auth/saml/skills/auth
npx skills add https://github.com/Krushnal121/agentic/tree/auth/oauth2/skills/auth

# Infrastructure tools
npx skills add https://github.com/Krushnal121/agentic/tree/docker/24/skills/docker
npx skills add https://github.com/Krushnal121/agentic/tree/k8s/1.28/skills/kubernetes
```

### Project Context 
Add a `CONTEXT.md` to your project root:
```markdown
# My Awesome API
- **Stack**: Go 1.24, Chi router, PostgreSQL, Docker
- **Patterns**: Hexagonal architecture, CQRS
- **Testing**: Testify + test containers
```

Your agent combines general language skills with your specific context.

### Conditional Loading
Skills load intelligently:
- **Language skills** → Only when that's the primary language
- **File type skills** → When working with specific formats (.pdf, .docx)
- **Universal rules** → Always apply but stay minimal (< 10 lines)

## Architecture

```
agentic/
├── skills/                    # The core intelligence
│   ├── setup/                 # One-time IDE configuration  
│   ├── project-rules/         # Smart routing logic
│   ├── go/                    # Go expertise (versioned)
│   ├── python/                # Python mastery
│   ├── typescript/            # TypeScript + React
│   └── rust/                  # Rust systems programming
├── contexts/                  # Project templates
│   └── go-service.md          # Go microservice starter
└── README.md                  # This guide
```

**Design Principles:**
- **Auto-invoke, never manual** — Precise trigger conditions
- **Scoped loading** — Conditional rules, minimal context overhead  
- **Single source of truth** — Skills live in SKILL.md, not duplicated
- **Composable** — Mix and match skills per project needs
- **IDE-agnostic** — Same content, IDE-specific delivery

## Contributing

Help us build the most comprehensive AI skill collection! 

### 🚀 Add New Skills
We need skills for every technology:
- **Frameworks**: React, Vue, Angular, Next.js, Django, FastAPI
- **Authentication**: OAuth2, SAML, JWT, Auth0, Firebase Auth  
- **Infrastructure**: Docker, Kubernetes, Terraform, AWS CDK
- **Databases**: PostgreSQL, MongoDB, Redis, Supabase
- **And much more!**

### 📝 Quick Start
```bash
# Create a versioned skill branch
git checkout -b react/18.2
git checkout -b auth/oauth2  
git checkout -b docker/24

# Follow our skill template
# See CONTRIBUTING.md for detailed guide
```

### 🎯 What Makes a Great Skill
- **Precise auto-triggering** based on file patterns
- **Version-specific expertise** (React 18.2, not just "React")
- **Clear exclusions** (when NOT to use)
- **Real-world patterns** and best practices

**👉 See [CONTRIBUTING.md](CONTRIBUTING.md) for the complete guide!**

## License

MIT — Build something amazing! 

---

<div align="center">
<strong>Stop explaining. Start building.</strong><br>
<em>Your agent is about to get a lot smarter.</em>
</div>