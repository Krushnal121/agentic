# Contributing to Agentic Skills

Thank you for your interest in contributing to the agentic skills ecosystem! This guide explains how to contribute new skills, skill versions, improvements, and infrastructure enhancements.

## 🎯 Types of Contributions

### 1. **New Skill Versions** (Most Common)
Add new versions of existing skills (Go 1.27, Python 3.13, React 19, etc.)

### 2. **New Skill Types**
Add entirely new skills (Rust, Java, Kubernetes, Docker, etc.)

### 3. **Infrastructure Improvements**
Enhance setup mechanisms, templates, or skill detection

### 4. **Documentation & Examples**
Improve guides, add examples, fix typos

## 📁 Repository Structure

```
skills/
├── go/
│   ├── 1.26/               # Comprehensive Go 1.26 skill
│   │   ├── SKILL.md        # Main skill file with metadata
│   │   ├── *.md            # Supporting modules
│   │   └── ...
│   └── latest -> 1.26      # Symlink to recommended version
├── python/                 # Future: Python skills
├── setup/                  # Infrastructure: IDE rule generation
├── project-rules/          # Infrastructure: Templates & routing
└── README.md
```

## 🚀 Contributing a New Skill Version

### Step 1: Fork and Branch
```bash
git fork https://github.com/Krushnal121/agentic.git
git clone your-fork-url
cd agentic
git checkout -b add-go-1.27  # or python-3.13, etc.
```

### Step 2: Create Version Directory
```bash
mkdir -p skills/go/1.27
```

### Step 3: Create SKILL.md with Metadata
```yaml
---
name: go
version: 1.27
description: >
  Go 1.27.x development patterns with [key features/improvements].
  Targets [specific use case or improvements over previous versions].
stability: stable|latest|beta|experimental
recommended: true|false
features:
  - "Key feature 1"
  - "Key feature 2"
  - "Unique aspects of this version"
target_audience: "Who should use this version"
compatibility: "Go version compatibility info"
predecessor: 1.26  # Optional: previous version
---

# Go 1.27 Development

## When to Invoke
- [When this skill should be used]
- [File types and scenarios]

## Prerequisites
- [Required knowledge]
- [Tools/versions needed]

## [Your comprehensive content here]
```

### Step 4: Add Supporting Modules
Create supporting .md files as needed:
- `concurrency-patterns.md`
- `testing-strategies.md`  
- `performance-optimization.md`
- etc.

### Step 5: Update Latest Symlink (if appropriate)
```bash
# Only if this is the new recommended version
cd skills/go/
rm latest
ln -s 1.27 latest
```

### Step 6: Test with Setup
```bash
# Test that setup skill detects your new version
# This would be automated in CI, but you can verify locally
find skills/ -name "SKILL.md" | grep go
# Should show: skills/go/1.27/SKILL.md
```

## 🆕 Contributing a New Skill Type

### Step 1: Create Skill Structure
```bash
mkdir -p skills/python/3.12
```

### Step 2: Create Comprehensive SKILL.md
Follow the same metadata format but for your new skill type:

```yaml
---
name: python
version: 3.12
description: >
  Comprehensive Python 3.12 development patterns for enterprise applications.
stability: latest
recommended: true
features:
  - "Modern async patterns"
  - "Type hinting best practices"  
  - "Performance optimization"
target_audience: "Python developers building production applications"
compatibility: "Python 3.8+ with 3.12-specific features"
---

# Python 3.12 Development

## When to Invoke
- Writing, reading, or editing any .py file
- Working with requirements.txt, pyproject.toml, setup.py
- Python testing, debugging, or optimization
- NOT: Jupyter notebooks (separate skill)
- NOT: Data science workflows (separate skill)

## Prerequisites
- Advanced Python knowledge
- Understanding of modern Python tooling
- Production application development experience

## [Your comprehensive content]
```

### Step 3: Add to Templates (Optional)
If your skill needs special IDE integration, update templates:

```yaml
# skills/project-rules/templates/cursor.mdc
### If skills/python/*/SKILL.md exists → Create `.cursor/rules/agentic-python-<version>.mdc`:
```yaml
---
description: Python skill routing (version <version>)
globs: ["**/*.py", "**/requirements.txt", "**/pyproject.toml"]
alwaysApply: false
---
Read skills/python/<version>/SKILL.md before writing or editing Python code.
```
```

### Step 4: Create Latest Symlink
```bash
cd skills/python/
ln -s 3.12 latest
```

## 🔧 Infrastructure Contributions

### Setup Skill Improvements
The setup skill in `skills/setup/SKILL.md` handles:
- Skill detection (versioned and direct)
- IDE rule generation
- Template processing

Contributions needed:
- Better version detection algorithms
- New IDE support (VS Code, Vim, etc.)
- Improved error handling

### Template Enhancements
Templates in `skills/project-rules/templates/` need:
- New IDE support
- Better conditional logic
- Improved file pattern matching

### Project Rules Logic
The `skills/project-rules/SKILL.md` defines:
- Skill routing principles  
- Trigger patterns
- Architecture guidelines

## 📋 Contribution Standards

### Quality Requirements

1. **Comprehensive Content**:
   - Minimum 200 lines for basic skills
   - 500+ lines for comprehensive enterprise skills
   - Multiple supporting modules for complex skills

2. **Enterprise Focus**:
   - Target senior developers
   - Production-ready patterns
   - Security considerations
   - Performance optimization

3. **Version-Specific Value**:
   - Clear benefits over previous versions
   - Version-specific features and patterns
   - Compatibility information

4. **Documentation Standards**:
   - Linter-compliant code comments
   - Clear examples (5-15 lines each)
   - Cross-references to related skills
   - Actionable, copy-paste ready patterns

### Metadata Requirements

All skills must include:
```yaml
---
name: skillname        # Required: lowercase, no spaces
version: X.Y          # Required: semantic version
description: >        # Required: comprehensive description
  Clear description of what this skill provides...
stability: latest     # Required: latest|stable|beta|experimental  
recommended: boolean  # Required: should this be the default choice
features: []          # Required: list of key features
target_audience: ""   # Required: who should use this
compatibility: ""     # Required: version/tool compatibility info
predecessor: X.Y      # Optional: previous version this replaces
---
```

### File Organization

```
skills/<name>/<version>/
├── SKILL.md           # Required: main skill file
├── *.md              # Optional: supporting modules
└── examples/          # Optional: code examples (if needed)
```

## 🧪 Testing Your Contribution

### Local Testing
```bash
# 1. Verify skill detection
find skills/ -name "SKILL.md" | grep yourskill

# 2. Check metadata parsing
head -20 skills/yourskill/version/SKILL.md

# 3. Verify symlink
ls -la skills/yourskill/latest

# 4. Test with a sample project (manual)
# Create test project, run setup, verify IDE rules generated
```

### Automated Testing (CI)
Our CI will verify:
- ✅ All SKILL.md files have valid frontmatter  
- ✅ Required metadata fields present
- ✅ Symlinks point to existing versions
- ✅ File structure follows conventions
- ✅ No broken internal links
- ✅ Minimum content quality standards

## 📤 Submission Process

### 1. Create Pull Request
```bash
git add .
git commit -m "feat: add Go 1.27 skill with [key features]

- Comprehensive Go 1.27 patterns with [improvements]
- [X lines] of enterprise-focused content
- Includes [key modules]: testing, concurrency, performance
- Targets [specific audience/use case]
- Compatible with Go 1.21+ with 1.27-specific optimizations"

git push origin your-branch
# Create PR on GitHub
```

### 2. PR Requirements

**Title Format**: `feat: add <skill> <version> - <key benefit>`

**Description Must Include**:
- [ ] What skill/version you're adding
- [ ] Key improvements/features over previous versions
- [ ] Target audience and use cases
- [ ] Content summary (line count, modules included)  
- [ ] Testing performed

**PR Checklist**:
- [ ] Follows versioned skill structure (`skills/<name>/<version>/`)
- [ ] Includes comprehensive SKILL.md with proper metadata
- [ ] Updates/creates latest symlink if appropriate
- [ ] No placeholder or stub content
- [ ] Includes supporting modules for comprehensive skills
- [ ] Cross-references work correctly
- [ ] Tested locally with skill detection

### 3. Review Process

**Automated Checks**:
- Metadata validation
- File structure verification  
- Link checking
- Content quality metrics

**Human Review**:
- Content accuracy and completeness
- Enterprise focus and quality
- Version-specific value
- Integration with existing skills

## 💡 Contribution Ideas Needed

### High Priority
- **Python 3.12/3.13**: Comprehensive Python skills
- **TypeScript 5.x**: Modern TS patterns
- **React 18/19**: Component patterns, hooks, performance
- **Docker/Kubernetes**: Container orchestration
- **PostgreSQL/MySQL**: Database patterns

### Infrastructure  
- **VS Code integration**: Add template support
- **Enhanced version detection**: Better algorithms
- **Skill dependencies**: Skills that build on others
- **Cross-skill references**: Better linking system

### Documentation
- **Video guides**: How to contribute skills
- **Skill templates**: Starter templates for new skills
- **Best practices**: Examples of excellent skills
- **Migration guides**: Updating between skill versions

## 🤝 Community

### Getting Help
- **Issues**: Report bugs or request features
- **Discussions**: Ask questions about contributing
- **Discord/Slack**: Real-time community chat (if available)

### Recognition
Contributors get:
- Attribution in skill files
- Recognition in changelog
- Community contributor status
- Priority support for their contributions

## 📊 Success Metrics

We track:
- **Skill adoption**: Which skills are most installed
- **Version preferences**: Which versions users choose
- **Content quality**: User feedback and ratings  
- **Community growth**: Number of contributors

Your contributions directly impact thousands of developers using AI coding assistants!

---

**Ready to contribute?** Start with a skill version you're expert in, follow this guide, and help build the most comprehensive AI coding skill ecosystem! 🚀