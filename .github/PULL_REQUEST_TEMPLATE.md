## Skill Addition: [Skill Name] [Version]

**Skill Type**: [Language/Framework/Auth/Infrastructure/Database/Other]  
**Branch**: `[category]/[version]`  
**Targets**: [Specific version or implementation]

### 📋 Description
Brief description of what this skill covers and when it should be used.

### 🎯 Triggers
List the specific conditions that should activate this skill:
- [ ] File patterns (e.g., `*.jsx`, `*.py`, `Dockerfile`)
- [ ] Directory patterns (e.g., `components/`, `auth/`, `k8s/`)
- [ ] Specific scenarios when it should load

### ❌ Exclusions  
When this skill should NOT be used:
- [ ] Common false positive scenarios
- [ ] Related but different technologies
- [ ] When the tech is mentioned but not primary focus

### ✅ Testing Checklist
- [ ] Tested skill installation locally (`npx skills add . --branch <branch>`)
- [ ] Verified IDE integration (Cursor/Claude Code rules generated)
- [ ] Confirmed auto-loading works correctly
- [ ] No conflicts with existing skills
- [ ] YAML frontmatter validates correctly

### 📝 Content Quality
- [ ] Expert-level, actionable knowledge (not basic tutorials)
- [ ] Version-specific features and patterns
- [ ] Real-world best practices included
- [ ] Common pitfalls and constraints documented
- [ ] Clear, comprehensive section organization

### 🔧 Technical Details
**SKILL.md Location**: `skills/[skill-name]/SKILL.md`  
**Auto-trigger Pattern**: [Describe the file/context patterns]  
**Version Coverage**: [Specific versions this skill covers]

### 💡 Additional Notes
[Any special considerations, dependencies, or implementation details]

---

### 📚 For Reviewers

**Skill Quality Review**:
- [ ] Description is precise enough for auto-triggering
- [ ] Triggers are specific and well-defined
- [ ] Exclusions prevent false positives
- [ ] Content is expert-level and actionable
- [ ] Branch naming follows convention
- [ ] No conflicts with existing skills

**Integration Review**:
- [ ] SKILL.md format is correct
- [ ] YAML frontmatter is valid
- [ ] Skill integrates with setup/project-rules properly
- [ ] Documentation is clear and comprehensive

---

*See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.*