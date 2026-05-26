# Existing AGENTS

# --- Added by agentic setup ---


# Agentic Skills Auto-Loading

This section configures automatic skill loading for enhanced development capabilities.

## Universal Agent Rules

**Core Principle**: Always consult the relevant `skills/<skill-name>/SKILL.md` before writing code or creating files.

**Mandatory Behavior**:
- Never skip skill loading, even for simple tasks within a skill's domain
- Skills contain critical patterns, constraints, and best practices
- Load file-reading skill first when working with uploaded files not yet in context

**File Type Triggers**:
- **Documents**: `.docx`, `.pdf`, `.pptx`, `.xlsx` → Load corresponding document processing skills
- **Code**: Language-specific triggers activate relevant development skills

## Language-Specific Development Agents
#### Go Development Agent (Version 1.26)

**Activation**: When working with `.go`, `go.mod`, or `go.sum` files
**Skill Source**: `skills/go/1.26/SKILL.md`

**Capabilities**:
- Enterprise Go 1.26 development patterns and idioms
- Modern tooling integration: mockery, testcontainers, golangci-lint
- Security practices: input validation, cryptography, authentication
- Performance optimization: profiling, memory management, concurrency
- Production deployment: architecture, monitoring, containerization

**Usage**: Automatically loads when Go is the primary language focus. Provides comprehensive guidance for enterprise-grade Go development.

## Agent Configuration Notes

### Conditional Activation
- Language agents only activate when that language is the primary focus
- File type agents load based on specific file extensions
- Multiple agents can collaborate when working across languages/technologies

### Context Optimization
- Only relevant agents load to maintain focused assistance
- Agent knowledge is sourced from versioned skill files
- No manual agent invocation required - activation is automatic

### Version Management
- Multiple skill versions can coexist without conflicts
- Agents use specific version knowledge (e.g., Go 1.26 vs Go 1.25)
- Re-run setup after installing new skills to update agent configurations

### Troubleshooting
1. Verify skill files exist at `skills/<skill-name>/<version>/SKILL.md`
2. Check file extensions match agent trigger patterns
3. Ensure target language/technology is the primary task focus
4. Confirm AGENTS.md is being read by your development environment
