# Toolchain Configuration

*Development tool configuration directives for Go 1.26.x enterprise projects*

## golangci-lint Configuration

### Essential Linter Rules
Configure comprehensive static analysis for enterprise code quality:

```yaml
# .golangci.yml
run:
  timeout: 5m
  go: "1.26"
  modules-download-mode: readonly

linters-settings:
  govet:
    enable-all: true
    disable:
      - fieldalignment  # Can be noisy for legacy code
  
  gocyclo:
    min-complexity: 15
  
  gocognit:
    min-complexity: 20
  
  goconst:
    min-len: 3
    min-occurrences: 3
  
  gomnd:
    ignored-functions:
      - os.Chmod
      - os.Mkdir
      - os.OpenFile
      - time.Sleep
    ignored-files:
      - ".*_test.go"
  
  gocritic:
    enabled-tags:
      - diagnostic
      - style
      - performance
      - opinionated
    disabled-checks:
      - unnamedResult  # Allow unnamed results in some cases
      - hugeParam     # May conflict with interface requirements
  
  revive:
    confidence: 0.8
    rules:
      - name: var-naming
        severity: warning
      - name: package-comments
        severity: error
      - name: exported
        severity: error
        arguments:
          - "checkPrivateReceivers"
          - "sayRepetitiveInsteadOfStutters"

linters:
  enable:
    # Core linters
    - errcheck        # Check error handling
    - gosimple        # Simplify code
    - govet           # Go vet analysis
    - ineffassign     # Detect ineffectual assignments
    - staticcheck     # Advanced static analysis
    - unused          # Find unused code
    
    # Security linters
    - gosec           # Security issues
    - bodyclose       # HTTP response body closing
    
    # Style linters
    - gofmt           # Code formatting
    - goimports       # Import formatting
    - goconst         # Repeated strings detection
    - gomnd           # Magic numbers detection
    - revive          # Comprehensive style checker
    
    # Performance linters
    - prealloc        # Slice preallocation
    - unconvert       # Unnecessary type conversions
    
    # Bug detection
    - gocritic        # Comprehensive bug and style checker
    - gocyclo         # Cyclomatic complexity
    - gocognit        # Cognitive complexity
    
    # Enterprise-specific
    - exhaustive      # Exhaustiveness checks for enums
    - nestif          # Nested if statements
    - whitespace      # Whitespace issues

  disable:
    - deadcode        # Deprecated, replaced by unused
    - structcheck     # Deprecated, replaced by unused
    - varcheck        # Deprecated, replaced by unused
    - maligned        # Performance impact minimal
    - lll             # Line length can be handled by formatter
    - funlen          # Function length less critical than complexity

issues:
  exclude-use-default: false
  max-issues-per-linter: 0
  max-same-issues: 0
  
  exclude-rules:
    # Exclude test files from some checks
    - path: "_test\\.go"
      linters:
        - gocyclo
        - gocognit
        - dupl
    
    # Exclude generated files
    - path: "\\.pb\\.go$"
      linters:
        - all
    
    # Allow underscore in test names
    - path: "_test\\.go"
      text: "should not use underscores"
      linters:
        - revive

output:
  format: colored-line-number
  print-issued-lines: true
  print-linter-name: true
```

### Pre-commit Integration
Integrate linting with git hooks:

```bash
#!/bin/sh
# .git/hooks/pre-commit

# Run golangci-lint on staged files
if command -v golangci-lint >/dev/null 2>&1; then
    echo "Running golangci-lint..."
    golangci-lint run --new-from-rev HEAD~1
    if [ $? -ne 0 ]; then
        echo "❌ golangci-lint failed"
        exit 1
    fi
    echo "✅ golangci-lint passed"
fi

# Run tests for changed packages
echo "Running tests for changed packages..."
CHANGED_PACKAGES=$(git diff --cached --name-only | grep '\.go$' | xargs -I {} dirname {} | sort -u | xargs -I {} go list ./{}... 2>/dev/null)

if [ -n "$CHANGED_PACKAGES" ]; then
    go test -short $CHANGED_PACKAGES
    if [ $? -ne 0 ]; then
        echo "❌ Tests failed"
        exit 1
    fi
    echo "✅ Tests passed"
fi

echo "✅ Pre-commit checks passed"
```

## Go Modules Best Practices

### Module Configuration
Optimize module management for enterprise development:

```go
// go.mod
module github.com/company/myapp

go 1.26

require (
    github.com/gin-gonic/gin v1.9.1
    github.com/lib/pq v1.10.9
    github.com/prometheus/client_golang v1.17.0
    github.com/stretchr/testify v1.8.4
    golang.org/x/crypto v0.14.0
)

require (
    // Indirect dependencies managed automatically
    github.com/bytedance/sonic v1.9.1 // indirect
    github.com/json-iterator/go v1.1.12 // indirect
)

// Replace directives for development
replace github.com/company/shared-lib => ../shared-lib

// Retract problematic versions
retract (
    v1.0.1 // Contains security vulnerability
    v1.0.2 // Breaking change in API
)
```

### Private Repository Configuration
Configure access to private modules:

```bash
# Configure Git for private repositories
git config --global url."git@github.com:company/".insteadOf "https://github.com/company/"

# Set GOPRIVATE environment variable
export GOPRIVATE=github.com/company/*,gitlab.company.com/*

# Configure .netrc for private repositories (if using HTTPS)
# ~/.netrc
machine github.com
login your-username
password your-token

machine gitlab.company.com
login your-username
password your-token
```

### Dependency Management
Implement secure dependency management:

```bash
#!/bin/bash
# scripts/update-deps.sh

# Update all dependencies
echo "Updating dependencies..."
go get -u ./...
go mod tidy

# Security scan
echo "Running security scan..."
if command -v govulncheck >/dev/null 2>&1; then
    govulncheck ./...
    if [ $? -ne 0 ]; then
        echo "❌ Vulnerability scan failed"
        exit 1
    fi
fi

# Verify dependencies
echo "Verifying dependencies..."
go mod verify
if [ $? -ne 0 ]; then
    echo "❌ Dependency verification failed"
    exit 1
fi

# Run tests to ensure compatibility
echo "Running tests..."
go test ./...
if [ $? -ne 0 ]; then
    echo "❌ Tests failed after dependency update"
    exit 1
fi

echo "✅ Dependencies updated successfully"
```

## Build Optimization

### Build Configuration
Optimize builds for different environments:

```makefile
# Makefile
.PHONY: build test clean lint security-scan

# Build variables
BINARY_NAME=myapp
VERSION?=dev
BUILD_TIME=$(shell date -u +%Y-%m-%dT%H:%M:%SZ)
GIT_COMMIT=$(shell git rev-parse --short HEAD)
LDFLAGS=-ldflags "-w -s -X main.version=${VERSION} -X main.buildTime=${BUILD_TIME} -X main.gitCommit=${GIT_COMMIT}"

# Build targets
build:
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build ${LDFLAGS} -o bin/${BINARY_NAME} ./cmd/${BINARY_NAME}

build-dev:
	go build -race ${LDFLAGS} -o bin/${BINARY_NAME} ./cmd/${BINARY_NAME}

# Cross-compilation targets
build-windows:
	CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build ${LDFLAGS} -o bin/${BINARY_NAME}.exe ./cmd/${BINARY_NAME}

build-darwin:
	CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build ${LDFLAGS} -o bin/${BINARY_NAME}-darwin ./cmd/${BINARY_NAME}

# Test targets
test:
	go test -v -race -coverprofile=coverage.out ./...

test-short:
	go test -short ./...

benchmark:
	go test -bench=. -benchmem ./...

# Quality checks
lint:
	golangci-lint run

security-scan:
	gosec ./...
	govulncheck ./...

# Clean
clean:
	rm -rf bin/
	rm -f coverage.out
	go clean -cache
	go clean -modcache
```

### Docker Build Optimization
Create efficient Docker builds with caching:

```dockerfile
# syntax=docker/dockerfile:1.4
FROM golang:1.26-alpine AS dependencies

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Copy go mod files for dependency caching
COPY go.mod go.sum ./

# Download dependencies with cache mount
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download && \
    go mod verify

FROM dependencies AS builder

# Copy source code
COPY . .

# Build with cache mount
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux go build \
    -a -installsuffix cgo \
    -ldflags="-w -s" \
    -o myapp \
    ./cmd/myapp

# Final stage
FROM scratch

# Copy certificates and timezone data
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Copy binary
COPY --from=builder /app/myapp /myapp

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["/myapp", "-health-check"]

USER 65534:65534
EXPOSE 8080

ENTRYPOINT ["/myapp"]
```

## CI/CD Pipeline Integration

### GitHub Actions Configuration
Automate testing, building, and deployment:

```yaml
# .github/workflows/ci.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  GO_VERSION: '1.26'
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: testdb
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

    steps:
    - uses: actions/checkout@v4

    - name: Set up Go
      uses: actions/setup-go@v4
      with:
        go-version: ${{ env.GO_VERSION }}

    - name: Cache Go modules
      uses: actions/cache@v3
      with:
        path: |
          ~/.cache/go-build
          ~/go/pkg/mod
        key: ${{ runner.os }}-go-${{ hashFiles('**/go.sum') }}
        restore-keys: |
          ${{ runner.os }}-go-

    - name: Download dependencies
      run: go mod download

    - name: Run linter
      uses: golangci/golangci-lint-action@v3
      with:
        version: latest
        args: --timeout=5m

    - name: Run security scan
      run: |
        go install golang.org/x/vuln/cmd/govulncheck@latest
        govulncheck ./...

    - name: Run tests
      env:
        DATABASE_URL: postgres://postgres:postgres@localhost:5432/testdb?sslmode=disable
      run: |
        go test -v -race -coverprofile=coverage.out ./...
        go tool cover -html=coverage.out -o coverage.html

    - name: Upload coverage reports
      uses: codecov/codecov-action@v3
      with:
        file: ./coverage.out

  build:
    needs: test
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v3

    - name: Log in to Container Registry
      uses: docker/login-action@v3
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v5
      with:
        images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
        tags: |
          type=ref,event=branch
          type=ref,event=pr
          type=sha,prefix={{branch}}-
          type=raw,value=latest,enable={{is_default_branch}}

    - name: Build and push Docker image
      uses: docker/build-push-action@v5
      with:
        context: .
        platforms: linux/amd64,linux/arm64
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=gha
        cache-to: type=gha,mode=max
```

## Code Generation Tools

### Protocol Buffers Integration
Configure protobuf code generation:

```bash
#!/bin/bash
# scripts/generate-protos.sh

# Install required tools
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

# Generate Go code from proto files
protoc --proto_path=api/proto \
       --go_out=pkg/api \
       --go_opt=paths=source_relative \
       --go-grpc_out=pkg/api \
       --go-grpc_opt=paths=source_relative \
       api/proto/*.proto

# Format generated code
gofmt -w pkg/api/

echo "✅ Protocol buffer code generated successfully"
```

### OpenAPI/Swagger Integration
Generate API documentation and clients:

```yaml
# api/openapi.yml
openapi: 3.0.3
info:
  title: MyApp API
  version: 1.0.0
  description: Enterprise API for MyApp

servers:
  - url: https://api.example.com/v1
    description: Production server
  - url: https://staging-api.example.com/v1
    description: Staging server

paths:
  /users:
    get:
      summary: List users
      parameters:
        - name: limit
          in: query
          schema:
            type: integer
            default: 10
            maximum: 100
      responses:
        '200':
          description: Successful response
          content:
            application/json:
              schema:
                type: object
                properties:
                  users:
                    type: array
                    items:
                      $ref: '#/components/schemas/User'

components:
  schemas:
    User:
      type: object
      required:
        - id
        - name
        - email
      properties:
        id:
          type: string
        name:
          type: string
        email:
          type: string
          format: email
```

```bash
# Generate server stubs and client code
go install github.com/deepmap/oapi-codegen/cmd/oapi-codegen@latest

# Generate server code
oapi-codegen -config server.cfg.yaml api/openapi.yml > internal/api/server.gen.go

# Generate client code  
oapi-codegen -config client.cfg.yaml api/openapi.yml > pkg/client/client.gen.go
```

## IDE Configuration

### VS Code Configuration
Optimize VS Code for Go development:

```json
// .vscode/settings.json
{
  "go.toolsManagement.autoUpdate": true,
  "go.useLanguageServer": true,
  "go.formatTool": "gofumpt",
  "go.lintTool": "golangci-lint",
  "go.lintFlags": ["--fast"],
  "go.buildTags": "integration",
  "go.testFlags": ["-v", "-race"],
  "go.testTimeout": "10m",
  "go.coverOnSave": true,
  "go.coverageDecorator": {
    "type": "gutter",
    "coveredHighlightColor": "rgba(64,128,128,0.5)",
    "uncoveredHighlightColor": "rgba(128,64,64,0.5)"
  },
  "gopls": {
    "analyses": {
      "unusedparams": true,
      "shadow": true,
      "fieldalignment": true
    },
    "staticcheck": true,
    "codelenses": {
      "gc_details": true,
      "generate": true,
      "test": true,
      "upgrade_dependency": true
    }
  },
  "files.eol": "\n",
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.organizeImports": true
  }
}

// .vscode/extensions.json
{
  "recommendations": [
    "golang.go",
    "ms-vscode.vscode-json",
    "ms-vscode-remote.remote-containers",
    "github.vscode-pull-request-github",
    "eamodio.gitlens"
  ]
}
```

### Debugging Configuration
Set up advanced debugging:

```json
// .vscode/launch.json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Launch Application",
      "type": "go",
      "request": "launch",
      "mode": "auto",
      "program": "${workspaceFolder}/cmd/myapp",
      "env": {
        "GO_ENV": "development",
        "DATABASE_URL": "postgres://localhost/myapp_dev?sslmode=disable"
      },
      "args": ["--debug"]
    },
    {
      "name": "Debug Test",
      "type": "go",
      "request": "launch",
      "mode": "test",
      "program": "${workspaceFolder}",
      "buildFlags": "-race",
      "args": ["-test.v", "-test.run", "TestFunctionName"]
    },
    {
      "name": "Attach to Process",
      "type": "go",
      "request": "attach",
      "mode": "local",
      "processId": 0
    }
  ]
}
```

## Release Automation

### Semantic Versioning with GoReleaser
Automate releases with proper versioning:

```yaml
# .goreleaser.yml
project_name: myapp

before:
  hooks:
    - go mod tidy
    - go generate ./...

builds:
  - env:
      - CGO_ENABLED=0
    goos:
      - linux
      - windows
      - darwin
    goarch:
      - amd64
      - arm64
    ldflags:
      - -s -w
      - -X main.version={{.Version}}
      - -X main.commit={{.Commit}}
      - -X main.date={{.Date}}
      - -X main.builtBy=goreleaser
    dir: cmd/myapp

archives:
  - format: tar.gz
    name_template: >-
      {{ .ProjectName }}_
      {{- title .Os }}_
      {{- if eq .Arch "amd64" }}x86_64
      {{- else if eq .Arch "386" }}i386
      {{- else }}{{ .Arch }}{{ end }}
    format_overrides:
      - goos: windows
        format: zip

checksum:
  name_template: 'checksums.txt'

snapshot:
  name_template: "{{ incpatch .Version }}-next"

changelog:
  sort: asc
  filters:
    exclude:
      - '^docs:'
      - '^test:'
```

For build optimization and performance considerations, see [Performance Optimization](performance-optimization.md). For security scanning and dependency management, see [Security Input](security-input.md). For testing tool configuration, see [Testing Strategies](testing-strategies.md).