# Versioned Skills Architecture

This repository uses a **versioned skills architecture** where each skill can have multiple versions in separate folders, allowing users to choose exactly the version they need.

## 📁 Structure

```
skills/
├── go/
│   ├── 1.26/SKILL.md          # Comprehensive Go 1.26 enterprise skill
│   ├── latest -> 1.26         # Symlink to latest version
├── python/                    # Future: Python versions
│   ├── 3.12/SKILL.md
│   ├── latest -> 3.12
├── setup/SKILL.md            # Infrastructure - no versions needed
└── project-rules/SKILL.md    # Infrastructure - no versions needed
```

## 🚀 Installation

### Current CLI (Works Now)
```bash
npx skills add Krushnal121/agentic
```

**Shows skill picker:**
```
◆  Select skills to install:
│  ◻ go (Enterprise Go 1.26.x patterns - 10,738+ lines)
│  ◻ project-rules (Infrastructure)  
│  ◻ setup (Infrastructure)
```

### Future Enhanced CLI (Planned)
```bash
npx skills add Krushnal121/agentic
```

**Enhanced picker with versions:**
```
◆  Select skills to install:
│  ◻ go
│     › 1.26 (Latest - Enterprise patterns, recommended)
│     › 1.25 (Stable production version)
│  ◻ python  
│     › 3.12 (Latest)
│     › 3.11 (Stable)
```

## 🎯 Benefits

1. **Version Choice**: Select exact versions needed for your project
2. **No Conflicts**: Multiple versions can coexist in same repository  
3. **Clear Defaults**: `latest` symlink points to recommended version
4. **Rich Metadata**: Each version includes features, compatibility, stability info
5. **IDE Integration**: Version-specific rule files (e.g., `agentic-go-1.26.mdc`)

## 🔧 How It Works

### Skill Detection
The setup skill scans for:
- **Versioned skills**: `skills/<name>/<version>/SKILL.md`
- **Direct skills**: `skills/<name>/SKILL.md` (infrastructure)
- **Latest symlinks**: `skills/<name>/latest -> <version>/`

### IDE Rule Generation
Each skill version gets its own rule files:
- **Cursor**: `.cursor/rules/agentic-go-1.26.mdc`
- **Claude Code**: `.claude/rules/agentic-go-1.26.md`
- **Version info included**: Rules point to specific version paths

### Version Metadata
Each skill includes rich metadata:

```yaml
---
name: go
version: 1.26
description: Enterprise Go 1.26.x development patterns...
stability: latest
recommended: true
features:
  - "Modern tooling integration (mockery, testcontainers)"
  - "15 comprehensive modules (10,738+ lines total)"
target_audience: "Senior developers building production applications"
compatibility: "Go 1.21+ with 1.26-specific optimizations"
---
```

## 📊 Current Skills

### Go 1.26 (Latest)
- **Content**: 15 comprehensive modules, 10,738+ lines
- **Features**: Enterprise patterns, modern tooling, security practices
- **Audience**: Senior developers building production Go applications  
- **Includes**: Testing with mockery, performance optimization, security

### Infrastructure Skills
- **setup**: Auto-generates IDE rule files for installed skills
- **project-rules**: Templates and routing logic for skill loading

## 🔄 Migration Path

This architecture is backwards compatible:
1. **Current**: Works with existing `npx skills add` command
2. **Enhanced**: Future versions will support version selection UI  
3. **Direct**: Can still install specific versions via URL paths

## 🎯 Adding New Skills

To add a new skill version:

1. **Create version directory**: `skills/<name>/<version>/`
2. **Add SKILL.md**: Include version metadata in frontmatter  
3. **Update latest symlink**: Point to recommended version
4. **Test**: Verify setup skill detects the new version

Example:
```bash
mkdir -p skills/python/3.12
# Add comprehensive Python 3.12 skill content
ln -sf 3.12 skills/python/latest
```

The setup skill will automatically detect and configure the new versioned skill for all supported IDEs.