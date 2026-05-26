# Go 1.26 Skill Rules

## Trigger Conditions

This rule activates when working primarily with Go files:
- `**/*.go` (Go source files)
- `**/go.mod` (Go module definition)
- `**/go.sum` (Go dependency checksums)

## Skill Loading

When these conditions are met:

**Read `skills/go/1.26/SKILL.md` before writing or editing Go code.**

This skill provides:
- Enterprise Go 1.26 development patterns
- Modern tooling integration (mockery, testcontainers, golangci-lint)
- Security practices and performance optimization
- Production-ready patterns for senior developers

## Context Notes

- Only loads when Go is the primary language focus
- Does not load for HTML templates (`.tmpl`) used only for templating
- Provides comprehensive guidance across all Go development phases
