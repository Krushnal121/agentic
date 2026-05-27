# Agentic: Intelligent AI Skill Management

**Stop re-explaining your stack. Skill up your agent.**

Transform any coding AI into a domain expert that automatically loads the right knowledge at the right time. No more "use the Python skill" or re-explaining your architecture — your agent just *knows*.

## What is Agentic?

Agentic is an **intelligent skill management system** that provides **zero-friction, context-aware skill loading** for coding AIs. It combines smart routing logic with conditional loading to ensure only relevant expertise activates when needed.

## Core Innovation: Smart Skill Routing

The system automatically detects file types, project context, and development patterns to load exactly the right skills:

- **File Detection**: `.py` files → Python expertise, `.rs` files → Rust patterns, etc.
- **Conditional Loading**: Only relevant skills activate, keeping AI responses focused
- **Version Awareness**: Pin to specific language/framework versions per project
- **Zero Manual Invocation**: No need to remember or request skill names

## Available Skills

### 🚀 Currently Available

#### Go Enterprise Development (v1.26)
- **Location**: `skills/go/1.26/SKILL.md`
- **Auto-triggers**: `.go`, `go.mod`, `go.sum` files
- **Coverage**: Enterprise patterns, testing, security, performance, concurrency
- **Status**: Production ready (10,738+ lines of guidance)

### 🛠️ Infrastructure Skills

#### Setup & Configuration
- **Location**: `skills/setup/SKILL.md`
- **Purpose**: Auto-generates IDE rules for installed skills
- **Supports**: Cursor, Claude Code, Windsurf, GitHub Copilot
- **Usage**: Enables automatic skill loading system

#### Smart Routing Logic
- **Location**: `skills/project-rules/SKILL.md`
- **Purpose**: Conditional activation rules and template processing
- **Function**: Determines which skills load based on context

### 🔮 Coming Soon

The system is designed for infinite expansion. Future skills will include:

#### Languages & Frameworks
- **Python** (Django, FastAPI, data science patterns)
- **TypeScript** (React, Vue, Node.js, serverless)
- **Rust** (systems programming, WebAssembly, async patterns)
- **Java** (Spring Boot, enterprise patterns, microservices)

#### Infrastructure & DevOps
- **Docker & Kubernetes** (containerization, orchestration)
- **Cloud Platforms** (AWS, GCP, Azure specific patterns)
- **Terraform & IaC** (infrastructure as code best practices)

#### Authentication & Security
- **OAuth2/SAML** (authentication implementation patterns)
- **Security Practices** (OWASP guidelines, secure coding)
- **Compliance** (SOC2, HIPAA, GDPR implementation guides)

## How the System Works

### Intelligent Activation
The system uses sophisticated rules to determine which skills to load:

```bash
# Your AI sees different files → Different expertise loads automatically
main.go          → Go enterprise patterns activate
app.py           → Python best practices (when available)  
package.json     → Node.js/TypeScript expertise (when available)
Dockerfile       → Container optimization skills (when available)
```

### Quick Start
```bash
# Install the skill management system
npx skills add Krushnal121/agentic

# Configure your project for automatic skill loading
# Tell your AI: "Run the setup skill to configure IDE rules for the installed skills"
```

### What Happens Automatically
1. **Context Detection**: AI analyzes your project structure and active files
2. **Smart Routing**: Only relevant skills activate based on conditional logic
3. **IDE Integration**: Works natively with your existing workflow
4. **Team Consistency**: Same expert guidance for everyone on your team

## System Architecture

```
agentic/
├── SKILL.md                   # Repository overview (this file)
├── skills/                    # Expandable skill collection
│   ├── go/1.26/SKILL.md      # Currently: Go expertise
│   ├── python/3.12/          # Future: Python mastery  
│   ├── typescript/5.0/       # Future: TypeScript + frameworks
│   ├── rust/latest/          # Future: Systems programming
│   ├── setup/SKILL.md        # Core: IDE configuration automation
│   └── project-rules/SKILL.md # Core: Smart routing logic
├── AGENTS.md                  # Conditional loading rules
└── README.md                  # Complete documentation & examples
```

## Key Features

- **Conditional Activation**: Skills load only when contextually relevant
- **Infinite Expandability**: Add any language, framework, or domain expertise
- **Versioned Skills**: Pin to specific versions per project needs
- **IDE-Agnostic**: Generates rules for any major IDE or AI assistant
- **Zero Manual Invocation**: Context drives activation, not commands
- **Smart Routing**: Advanced logic determines relevance and priority

## The Vision: Universal AI Expertise

Agentic aims to be the **universal skill library** for coding AIs. Every language, framework, and development pattern should have expert-level guidance that activates automatically when needed.

### Current State: Foundation + Go
- ✅ **Smart routing system** fully operational
- ✅ **IDE integration** across major platforms
- ✅ **Go 1.26** enterprise expertise (production ready)
- ✅ **Conditional loading** prevents context overflow

### Expansion Roadmap
- 🔄 **Python ecosystem** (Django, FastAPI, data science)
- 🔄 **JavaScript/TypeScript** (React, Vue, Node.js, serverless)
- 🔄 **Infrastructure** (Docker, Kubernetes, Terraform)
- 🔄 **Security & Auth** (OAuth2, SAML, compliance patterns)
- 🔄 **Database expertise** (PostgreSQL, MongoDB, optimization)

## Contributing: Build the Future

Help us create the most comprehensive AI skill ecosystem! 

### What We Need
- **Language Experts**: Python, TypeScript, Rust, Java expertise
- **Framework Specialists**: React, Vue, Django, Spring Boot patterns  
- **Infrastructure Gurus**: Docker, K8s, cloud platform best practices
- **Security Professionals**: Authentication, compliance, secure coding

### Quick Start Contributing
```bash
# Fork and create your expertise area
mkdir -p skills/python/3.12
mkdir -p skills/react/18.2  
mkdir -p skills/docker/24

# Follow our versioned skill template
# See CONTRIBUTING.md for detailed contribution guide
```

## Installation

```bash
# Add this skill management system to your AI
npx skills add Krushnal121/agentic

# Currently includes:
# ☑ go (Enterprise Go 1.26 patterns - ready for production)
# ☑ setup (IDE rule generation - required infrastructure)  
# ☑ project-rules (Smart routing logic - required infrastructure)
```

## License

MIT — Build something amazing!

---

**For complete documentation, examples, and troubleshooting**: See [README.md](README.md)

**Live Demo**: Try it on any supported project type — watch your AI automatically gain relevant expertise as you work.