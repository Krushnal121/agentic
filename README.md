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
- **Language expertise** — Go 1.26 enterprise patterns, Python best practices, TypeScript types
- **Version control** — Choose exact skill versions for your project needs
- **Smart loading** — Only relevant skills activate, keeping context lean
- **Team consistency** — Everyone gets the same expert guidance

## How It Works

### Auto-Detection Magic
```bash
# Your agent sees: main.go
# Instantly loads: Go 1.26 enterprise patterns, testing strategies, security practices
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

## Getting Started

### Step 1: Install Skills
```bash
npx skills add Krushnal121/agentic
```

**Select all 3 skills when prompted:**
```
◆  Select skills to install (space to toggle)
│  ☑ go (Enterprise Go 1.26.x patterns - 10,738+ lines)
│  ☑ setup (IDE rule generation)  
│  ☑ project-rules (Infrastructure templates)
```

**Why all 3?**
- **go**: Your comprehensive enterprise Go skill (the actual valuable content)
- **setup**: Auto-generates IDE rules so skills load automatically
- **project-rules**: Infrastructure that setup needs for template processing

### Step 2: Configure Your Project
```bash
# Navigate to your Go project
cd /path/to/your/go-project

# Tell your AI assistant:
"Run the setup skill to configure IDE rules for the installed skills"
```

**What setup does automatically:**
1. **Detects your IDE** (.cursor/, .claude/, .github/ directories)
2. **Finds installed skills** (go 1.26, python, etc.)
3. **Generates IDE rules** (.cursor/rules/agentic-go-1.26.mdc, etc.)
4. **Configures auto-loading** (skills activate based on file types)

### Step 3: Code with Expert Guidance

**The magic happens automatically:**
```bash
# Open main.go → Go 1.26 enterprise patterns load instantly
# Work with testing → Mockery integration, t.Parallel() patterns  
# Handle errors → Proper wrapping, context, sentinel errors
# Write APIs → Function options, builder patterns, resource management
# Security concerns → Input validation, crypto best practices
```

**Available expertise:**
- **15 comprehensive modules** covering all Go aspects
- **10,738+ lines** of enterprise-focused guidance
- **Modern tooling** (mockery, testcontainers, golangci-lint)
- **Production patterns** for senior developers

### Step 4: Share with Your Team
```bash
# Commit the generated IDE files to version control
git add .cursor/rules/ .claude/rules/ CLAUDE.md
git commit -m "Add agentic skills configuration"

# Team members get the same intelligent AI behavior automatically
```

### 🔧 Troubleshooting

**Skills not loading?**
1. Verify setup ran successfully: check for `.cursor/rules/` or `.claude/rules/` files
2. Ensure you selected all 3 skills during installation (go, setup, project-rules)
3. Try running setup skill again if IDE rules are missing
4. Check that you're working with `.go` files (skills are file-type triggered)

## What You Get

### 🎯 **Go 1.26 Enterprise Skill**
- **15 Comprehensive Modules**: Testing, security, performance, concurrency, architecture
- **10,738+ Lines** of expert guidance written for senior developers
- **Modern Tooling**: Integration with mockery, testcontainers, golangci-lint
- **Production Ready**: Enterprise patterns, security practices, deployment strategies

### 📚 **Complete Coverage**
1. **Style Guide** - Uber Go Guide implementation + documentation standards
2. **Testing Strategies** - Mockery integration, parallel testing, benchmarking
3. **Security Practices** - Input validation, cryptography, authentication
4. **Performance** - Profiling, optimization, memory management
5. **Concurrency** - Goroutines, channels, worker pools, circuit breakers
6. **Enterprise Architecture** - Project layout, logging, monitoring, deployment
7. **Anti-patterns** - Common pitfalls and how to avoid them

### 🚀 **Zero-Friction Experience**
- **No manual invocation** - Skills activate automatically based on file context
- **Context-aware** - Only relevant skills load, keeping AI responses focused
- **Team consistency** - Everyone gets the same expert guidance
- **Version control** - Choose exact skill versions for your project needs

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
# Fork and create your skill
mkdir -p skills/python/3.12
mkdir -p skills/react/18
mkdir -p skills/docker/24

# Follow our versioned skill template
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