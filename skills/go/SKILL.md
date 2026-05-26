---
name: go
description: >
  Use when writing, debugging, or refactoring Go (.go) files, or when working with
  go.mod, go.sum, running go test/build/vet/golangci-lint, or diagnosing Go compiler errors.
  Targets Go 1.26.x with modern idioms, security practices, and performance patterns.
  Also use when reviewing Go code, setting up Go projects, or optimizing Go applications.
  Do NOT use for Go template files (.tmpl) unrelated to Go source code, or when Go 
  is only incidentally mentioned in a non-Go task.
---

# Go 1.26 Development

## When to Invoke
- Writing, reading, or editing any .go file
- Working with go.mod, go.sum, or Go modules
- Running go build, go test, go vet, or golangci-lint
- Diagnosing Go compiler, runtime, or performance issues
- Code reviews of Go projects
- Setting up Go project structure and toolchain
- Optimizing Go applications for production
- Implementing concurrent Go programs
- Securing Go applications for enterprise deployment
- NOT: .tmpl files used for HTML templating only
- NOT: tasks where Go is mentioned but not the primary language

## Prerequisites
- Advanced understanding of Go language fundamentals
- Experience with production Go applications
- Familiarity with enterprise software development practices
- Knowledge of software security principles
- Understanding of performance optimization concepts

## Go 1.26 Feature Highlights

### Language Enhancements
Go 1.26 builds on the solid foundation established in previous versions with focus on:
- **Performance**: Improved garbage collector and runtime optimizations
- **Security**: Enhanced cryptographic libraries and secure defaults
- **Toolchain**: Better build caching and module resolution
- **Standard Library**: Refined APIs and new utility packages

### Compatibility Promise
All patterns and practices in this skill maintain backward compatibility with Go 1.21+ while leveraging 1.26-specific improvements where beneficial.

## Quick Reference Index

### Core Development
- **[Code Style & Formatting](style-guide.md)** - Uber Go Guide implementation for teams
- **[Idiomatic Basics](idiomatic-basics.md)** - Error handling, interfaces, control flow
- **[Idiomatic Advanced](idiomatic-advanced.md)** - API design, resource management, enterprise patterns
- **[Testing Strategies](testing-strategies.md)** - Senior-level testing patterns

### Performance & Optimization
- **[Performance Profiling](performance-profiling.md)** - CPU/memory profiling, benchmarking strategies
- **[Performance Optimization](performance-optimization.md)** - Memory management, algorithms, I/O optimization

### Concurrency
- **[Concurrency Basics](concurrency-basics.md)** - Goroutines, channels, panic recovery
- **[Concurrency Sync](concurrency-sync.md)** - Mutexes, atomics, synchronization primitives
- **[Concurrency Advanced](concurrency-advanced.md)** - Worker pools, circuit breakers, streaming

### Security
- **[Security Input](security-input.md)** - Input validation, injection prevention
- **[Security Crypto](security-crypto.md)** - Authentication, cryptography, HTTP security

### Enterprise Operations
- **[Enterprise Architecture](enterprise-architecture.md)** - Logging, monitoring, deployment
- **[Toolchain Configuration](toolchain-configuration.md)** - golangci-lint, automation
- **[Anti-patterns](anti-patterns.md)** - Constraints and common pitfalls

## Essential Patterns Quick Reference

### Error Handling (1.26)
```go
// Wrap errors with context
if err != nil {
    return fmt.Errorf("process user %q: %w", userID, err)
}

// Type-based error handling
var netErr *net.OpError
if errors.As(err, &netErr) {
    // Handle network errors specifically
}
```

### Context Usage
```go
// ProcessData processes the given data bytes with context cancellation support.
// Returns error if context is cancelled or processing fails.
func ProcessData(ctx context.Context, data []byte) error {
    select {
    case <-ctx.Done():
        return ctx.Err()
    default:
        // Process data
    }
}
```

### Documentation Standards
```go
// User represents a system user with authentication and profile information.
// All exported fields are validated during creation and updates.
type User struct {
    // ID is the unique identifier for the user
    ID string `json:"id" db:"id"`
    
    // Name is the user's display name (required, max 100 characters)
    Name string `json:"name" db:"name"`
    
    // Email is the user's email address used for authentication
    Email string `json:"email" db:"email"`
}

// Validate performs schema validation for User and returns error if validation fails.
// Checks required fields, format constraints, and business rules.
func (u *User) Validate() error {
    if u.Name == "" {
        return errors.New("name is required")
    }
    
    // Validate email format
    if !isValidEmail(u.Email) {
        return errors.New("invalid email format")
    }
    
    return nil
}
```

### Resource Management
```go
// ProcessFile processes a file and ensures proper resource cleanup.
// Returns error if file cannot be opened or processing fails.
func ProcessFile(filename string) error {
    // Open file for reading
    f, err := os.Open(filename)
    if err != nil {
        return fmt.Errorf("failed to open file %s: %w", filename, err)
    }
    defer f.Close() // Always cleanup resources
    
    // Process file contents
    return processFileContents(f)
}
```

### Documentation Standards (Linter-Compliant)
```go
// ServiceConfig holds configuration for service initialization.
// All fields are validated during service startup.
type ServiceConfig struct {
    // Port is the TCP port for the service to listen on
    Port int `json:"port"`
    
    // Timeout is the request timeout duration
    Timeout time.Duration `json:"timeout"`
}

// NewService creates a new service instance with the provided configuration.
// Returns error if configuration validation fails or initialization errors occur.
func NewService(config *ServiceConfig) (*Service, error) {
    // Validate configuration parameters
    if config.Port <= 0 {
        return nil, errors.New("port must be positive")
    }
    
    // Initialize service with validated config
    service := &Service{
        port:    config.Port,
        timeout: config.Timeout,
    }
    
    return service, nil
}
```

## Navigation Guide

### By Development Phase

**Planning & Setup**:
1. [Project Structure](enterprise-architecture.md#project-layout) - Standard Go project organization
2. [Toolchain Setup](toolchain-configuration.md) - Essential development tools
3. [Security Baseline](security-input.md) - Input validation and injection prevention

**Development**:
1. [Style Guide](style-guide.md) - Consistent code formatting, naming, and documentation standards
2. [Idiomatic Basics](idiomatic-basics.md) - Core Go programming patterns with proper documentation
3. [Testing](testing-strategies.md) - Test-driven development practices

**Optimization**:
1. [Performance Profiling](performance-profiling.md) - Measurement and benchmarking
2. [Concurrency Basics](concurrency-basics.md) - Safe concurrent programming foundations
3. [Anti-patterns](anti-patterns.md) - Common mistakes to avoid

**Production**:
1. [Security Crypto](security-crypto.md) - Authentication and cryptographic security
2. [Concurrency Advanced](concurrency-advanced.md) - Enterprise concurrency patterns
3. [Enterprise Architecture](enterprise-architecture.md) - Production deployment patterns

### By Problem Domain

**API Development**: [Idiomatic Advanced](idiomatic-advanced.md#api-design) → [Security Crypto](security-crypto.md#authentication) → [Testing](testing-strategies.md#api-testing)

**Data Processing**: [Performance Optimization](performance-optimization.md#memory-optimization) → [Concurrency Advanced](concurrency-advanced.md#worker-pools) → [Performance Profiling](performance-profiling.md#benchmarking)

**Microservices**: [Enterprise Architecture](enterprise-architecture.md) → [Security Input](security-input.md) + [Security Crypto](security-crypto.md) → [Observability](enterprise-architecture.md#monitoring)

## Integration with Other Skills

This Go skill works in conjunction with:
- **Docker**: Container patterns in [Enterprise Architecture](enterprise-architecture.md#containerization)
- **Kubernetes**: Deployment patterns in [Enterprise Architecture](enterprise-architecture.md#deployment)
- **Security**: Input validation in [Security Input](security-input.md), cryptography in [Security Crypto](security-crypto.md)
- **Testing**: Advanced testing beyond [Testing Strategies](testing-strategies.md)

## Keeping Practices Current

### Staying Updated
- **Go Blog**: Follow https://blog.golang.org for language updates
- **Release Notes**: Review https://go.dev/doc/devel/release for version changes  
- **Proposals**: Monitor https://github.com/golang/proposal for upcoming features
- **Security**: Subscribe to https://groups.google.com/g/golang-announce for security updates

### Adopting New Features
1. **Evaluate Stability**: Wait for at least one minor release before adopting new features
2. **Team Consensus**: Discuss adoption strategy with team before updating patterns
3. **Incremental Updates**: Introduce new patterns gradually in non-critical paths
4. **Testing**: Thoroughly test new patterns before production deployment

### Continuous Improvement
- **Code Reviews**: Use this skill as a reference during code reviews
- **Team Training**: Regular team sessions on pattern updates and best practices
- **Tooling**: Keep toolchain configurations updated with latest rule sets
- **Feedback Loop**: Collect team feedback on pattern effectiveness and update accordingly

## Quick Decision Trees

### Error Handling Choice
```
Need to add context? → Use fmt.Errorf with %w
Need type checking? → Create custom error type
Simple failure? → Return errors.New()
```

### Interface Design Choice
```
Single method? → Use -er suffix (Reader, Writer)
Multiple related methods? → Use noun (User, Config)  
Testing abstraction? → Keep interface minimal
```

### Testing Strategy Choice
```
Unit test? → Table-driven tests
Integration? → Use testcontainers
Performance? → Benchmark tests with -benchmem
```

This skill provides enterprise-grade Go development practices for senior developers building production systems. Each focused section contains detailed guidance, examples, and actionable patterns specific to Go 1.26.x.

## Getting Started Recommendations

**New to Team/Project**: [Style Guide](style-guide.md) → [Idiomatic Basics](idiomatic-basics.md) → [Testing Strategies](testing-strategies.md)

**Performance Issues**: [Performance Profiling](performance-profiling.md) → [Performance Optimization](performance-optimization.md) → [Concurrency Advanced](concurrency-advanced.md)

**Security Requirements**: [Security Input](security-input.md) → [Security Crypto](security-crypto.md) → [Enterprise Architecture](enterprise-architecture.md)

**Production Deployment**: [Idiomatic Advanced](idiomatic-advanced.md) → [Concurrency Advanced](concurrency-advanced.md) → [Enterprise Architecture](enterprise-architecture.md)