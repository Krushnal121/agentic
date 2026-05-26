# Contributing to Agentic Skills

Help us build the most comprehensive collection of AI agent skills! This guide shows you how to contribute new skills, improve existing ones, and add support for new tech stacks.

## 🚀 Quick Start for Contributors

```bash
# Fork the repository
git clone https://github.com/YOUR_USERNAME/agentic.git
cd agentic

# Create a new skill branch
git checkout -b <skill-type>/<version>

# Example: React 18.2 skill
git checkout -b react/18.2
```

## 📋 Skill Creation Guide

### 1. Choose Your Skill

Pick a technology you're expert in. Examples:
- `react/18.2` - React 18.2 with hooks, suspense, concurrent features
- `auth/oauth2` - OAuth2 implementation patterns and security
- `docker/24` - Docker 24.x best practices and patterns
- `postgres/15` - PostgreSQL 15 features, performance, patterns

### 2. Create the Branch Structure

```bash
# Language skills (version-specific)
git checkout -b go/1.24
git checkout -b python/3.12
git checkout -b typescript/5.2

# Framework skills (version-specific)
git checkout -b react/18.2
git checkout -b vue/3.4
git checkout -b angular/17

# Domain skills (implementation-specific)  
git checkout -b auth/oauth2
git checkout -b auth/saml
git checkout -b auth/jwt

# Infrastructure skills (tool-specific)
git checkout -b docker/24
git checkout -b k8s/1.28
git checkout -b terraform/1.5
```

### 3. Create the Skill Directory

```bash
mkdir -p skills/<skill-name>
```

Examples:
- `skills/react/` for React framework
- `skills/auth/` for authentication patterns
- `skills/docker/` for containerization

### 4. Write the SKILL.md

Create `skills/<skill-name>/SKILL.md` with this structure:

```markdown
---
name: <skill-name>
description: >
  Use when [specific trigger conditions]. Also use when [additional conditions].
  Targets [version/implementation]. Do NOT use for [exclusions].
---

# <Skill Name>

## When to Invoke
- [Specific trigger condition 1]
- [Specific trigger condition 2]
- [Specific trigger condition 3]
- NOT: [Exclusion condition 1]
- NOT: [Exclusion condition 2]

## Prerequisites
[Any required skills or context]

## [Skill-Specific Sections]
[Add sections relevant to your technology]

## Constraints
[Hard rules and limitations]
```

## 📝 SKILL.md Examples

### Framework Example: React 18.2

```markdown
---
name: react
description: >
  Use when working with React (.jsx, .tsx) components, hooks, or React-specific patterns.
  Targets React 18.2+ with concurrent features, Suspense, and modern hooks. Also use
  when working with Next.js, component libraries, or React testing. Do NOT use for
  plain JavaScript React concepts or when React is only mentioned in passing.
---

# React 18.2

## When to Invoke
- Writing or editing .jsx or .tsx files
- Working with React components, hooks, or context
- Implementing React 18 concurrent features (Suspense, useTransition)
- Building with Next.js, Remix, or other React frameworks
- Testing React components with Testing Library
- NOT: Plain JavaScript/TypeScript files that happen to mention React
- NOT: Non-React frontend frameworks (Vue, Angular, Svelte)

## Prerequisites
Understanding of JavaScript/TypeScript fundamentals.

## Component Patterns
[React-specific patterns, hooks usage, etc.]

## Performance Optimization
[React 18 performance features]

## Testing Strategies  
[React Testing Library best practices]

## Common Pitfalls
[React-specific gotchas and anti-patterns]

## Constraints
- Always use function components over class components
- Prefer hooks over higher-order components
- Follow React 18 concurrent patterns
```

### Auth Example: OAuth2

```markdown
---
name: auth
description: >
  Use when implementing OAuth2 authentication flows, JWT tokens, or authorization
  patterns. Also use when working with auth providers (Auth0, Firebase Auth), 
  login/logout flows, or API security. Do NOT use for basic user management
  unrelated to authentication protocols.
---

# OAuth2 Authentication

## When to Invoke
- Implementing OAuth2 authorization code flow
- Working with JWT tokens, refresh tokens, access tokens
- Integrating with auth providers (Google, GitHub, Auth0)
- Building login/logout functionality
- Securing APIs with bearer tokens
- NOT: Basic user CRUD operations without auth protocols
- NOT: Simple session-based authentication

## Prerequisites
Understanding of HTTP, tokens, and web security basics.

## OAuth2 Flows
[Authorization code, implicit, client credentials flows]

## Token Management
[JWT handling, refresh strategies, security]

## Security Best Practices
[PKCE, state parameters, token storage]

## Common Vulnerabilities
[OAuth2 security pitfalls to avoid]

## Constraints
- Always use HTTPS for token exchange
- Implement PKCE for public clients
- Never store tokens in localStorage for sensitive apps
```

## 🔧 Skill Description Best Practices

The `description` field is **critical** - it's what makes skills auto-load. Follow these rules:

### ✅ Good Descriptions

```yaml
# Specific triggers AND exclusions
description: >
  Use when writing, debugging, or refactoring Go (.go) files, or when working with
  go.mod, go.sum, running go test/build/vet, or diagnosing Go compiler errors.
  Targets Go 1.24.x. Do NOT use for Go template files (.tmpl) unrelated to Go
  source code, or when Go is only incidentally mentioned in a non-Go task.

# Clear technology scope
description: >
  Use when implementing React components (.jsx, .tsx), hooks, or React 18+ patterns.
  Also use for Next.js, component testing, or React performance optimization.
  Do NOT use for plain JavaScript or other frontend frameworks.
```

### ❌ Bad Descriptions  

```yaml
# Too vague - will trigger incorrectly
description: "Helps with React development"

# Missing exclusions - will load when irrelevant  
description: "Use when working with authentication"

# No version specificity
description: "Use for Go programming"
```

### 🎯 Description Template

```yaml
description: >
  Use when [primary trigger conditions]. Also use when [secondary conditions].
  Targets [specific version/implementation]. Do NOT use for [exclusion 1], 
  or when [exclusion 2].
```

## 🌿 Branch Naming Convention

Use this pattern: `<category>/<version-or-type>`

### Language Skills (Version-Based)
```
go/1.22, go/1.23, go/1.24
python/3.10, python/3.11, python/3.12  
typescript/4.9, typescript/5.0, typescript/5.2
rust/1.70, rust/1.75
```

### Framework Skills (Version-Based)
```
react/17, react/18.0, react/18.2
vue/2.7, vue/3.3, vue/3.4
angular/15, angular/16, angular/17
next/13, next/14
```

### Domain Skills (Implementation-Based)
```
auth/oauth2, auth/saml, auth/jwt, auth/firebase
database/postgres, database/mongodb, database/redis
docker/compose, docker/swarm, docker/24
k8s/1.27, k8s/1.28, k8s/1.29
```

## 🧪 Testing Your Skill

### 1. Validate SKILL.md Format
```bash
# Check YAML frontmatter is valid
python3 -c "
import yaml
with open('skills/<skill-name>/SKILL.md') as f:
    content = f.read()
    frontmatter = content.split('---')[1]
    metadata = yaml.safe_load(frontmatter)
    print(f'✓ Valid frontmatter: {metadata[\"name\"]}')
"
```

### 2. Test Skill Integration
```bash
# Install your skill branch locally
npx skills add . --branch <your-branch>

# Test auto-loading by creating relevant files
touch example.jsx  # Should trigger React skill
touch login.py     # Should trigger Python + Auth skills
```

### 3. Verify IDE Integration  
```bash
# Run setup skill to generate IDE configs
"Run the setup skill"

# Check that your skill gets detected and configured
ls .cursor/rules/agentic-<your-skill>.mdc
ls .claude/rules/agentic-<your-skill>.md
```

## 📋 Pull Request Checklist

Before submitting, ensure:

- [ ] **Branch name** follows convention: `<category>/<version>`
- [ ] **SKILL.md exists** at `skills/<skill-name>/SKILL.md`
- [ ] **Valid YAML frontmatter** with `name` and `description`
- [ ] **Precise description** with triggers AND exclusions
- [ ] **Complete sections** (When to Invoke, Prerequisites, Constraints, etc.)
- [ ] **Real-world content** (not just TODO placeholders)
- [ ] **Version specificity** (React 18.2, not just "React")
- [ ] **Tested locally** with skill installation and IDE setup

## 🚀 Submission Process

### 1. Create Your Skill

```bash
# Create branch for your skill
git checkout -b react/18.2

# Write the skill content
# ... create skills/react/SKILL.md ...

# Commit your skill
git add skills/react/SKILL.md
git commit -m "Add React 18.2 skill with hooks, Suspense, and concurrent features

- Covers React 18.2+ modern patterns and features
- Includes component patterns, hooks best practices
- Performance optimization with concurrent features
- Testing strategies with React Testing Library  
- Clear triggers for .jsx/.tsx files and React-specific work
- Excludes plain JS/TS files that mention React incidentally"

# Push to your fork
git push origin react/18.2
```

### 2. Open Pull Request

Create a PR with this template:

```markdown
## Skill Addition: <Skill Name> <Version>

**Skill Type**: [Language/Framework/Auth/Infrastructure/Database]
**Branch**: `<category>/<version>`
**Targets**: [Specific version or implementation]

### Description
Brief description of what this skill covers and when it should be used.

### Triggers
- File patterns that activate this skill
- Specific scenarios when it should load

### Exclusions  
- When this skill should NOT be used
- Common false positive scenarios

### Testing Done
- [ ] Tested skill installation locally
- [ ] Verified IDE integration (Cursor/Claude Code)
- [ ] Confirmed auto-loading works correctly
- [ ] No conflicts with existing skills

### Additional Notes
Any special considerations or dependencies.
```

## 🎯 Skill Quality Guidelines

### Content Standards

- **Expert-level**: Skills should contain deep, actionable knowledge
- **Version-specific**: Target specific versions with their unique features
- **Pattern-focused**: Emphasize idiomatic patterns and best practices
- **Constraint-aware**: Include common pitfalls and anti-patterns
- **Testing-included**: Cover testing strategies where applicable

### Trigger Accuracy

- **Precise conditions**: Skills should only load when truly relevant
- **Clear exclusions**: Explicitly state when NOT to use the skill
- **File pattern matching**: Use specific file extensions and patterns
- **Context awareness**: Consider when the technology is primary vs incidental

---

**Let's build the future of AI agent expertise together!** 🚀

Every skill you add helps thousands of developers work more effectively with their AI assistants.