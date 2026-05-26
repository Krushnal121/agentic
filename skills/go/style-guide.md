# Go Style Guide

*Enterprise-grade code style based on [Uber Go Style Guide](https://github.com/uber-go/guide/blob/master/style.md) for Go 1.26.x*

## Import Organization

### Import Grouping
Group imports in the following order with blank lines between groups:

```go
package main

import (
    // Standard library
    "context"
    "fmt"
    "net/http"
    
    // Third-party libraries  
    "github.com/gorilla/mux"
    "go.uber.org/zap"
    
    // Internal packages
    "github.com/yourorg/yourproject/internal/auth"
    "github.com/yourorg/yourproject/pkg/database"
)
```

### Import Aliasing
Avoid renaming imports except to resolve name collisions:

```go
// Good
import (
    "crypto/rand"
    "math/rand"  // Collision: rename the local one
)

// Better - explicit aliasing
import (
    "crypto/rand"
    mathrand "math/rand"
)
```

For more details on import management, see [Toolchain Configuration](toolchain-configuration.md#import-management).

## Naming Conventions

### Package Names
- Use lowercase, single-word names
- Avoid underscores or mixedCaps
- Make names short and concise

```go
// Good
package user
package httputil
package uuid

// Avoid
package userManagement
package user_management
package http_util
```

### Function and Variable Names
Use mixedCaps (camelCase for unexported, PascalCase for exported):

```go
// Good
func parseConfig() *Config { }
func NewUserService() *UserService { }
var maxRetries = 3
var DatabaseURL string

// Avoid
func parse_config() *Config { }  
func new_user_service() *UserService { }
var max_retries = 3
```

### Interface Names
Use `-er` suffix for single-method interfaces:

```go
type Reader interface {
    Read([]byte) (int, error)
}

type Closer interface {
    Close() error
}

// Multi-method interfaces use noun forms
type UserRepository interface {
    Create(User) error
    GetByID(int) (User, error)
    Update(User) error
}
```

### Initialisms and Acronyms
Keep consistent case for initialisms (URL, HTTP, ID, JSON):

```go
// Good
func ServeHTTP() { }
var userID int64
type APIKey string
var configURL string

// Avoid  
func ServeHttp() { }
var userId int64
type ApiKey string
var configUrl string
```

For comprehensive naming patterns, see [Idiomatic Patterns](idiomatic-patterns.md#naming-patterns).

## Struct Patterns

### Field Organization
Order struct fields logically, typically by importance or grouping:

```go
type User struct {
    // Identity fields first
    ID       int64     `json:"id" db:"id"`
    Email    string    `json:"email" db:"email"`
    Username string    `json:"username" db:"username"`
    
    // Metadata
    CreatedAt time.Time `json:"created_at" db:"created_at"`
    UpdatedAt time.Time `json:"updated_at" db:"updated_at"`
    
    // Optional/computed fields last
    FullName  string    `json:"full_name,omitempty"`
}
```

### Zero Value Usefulness
Design structs so their zero value is useful:

```go
// Good - zero value is immediately usable
type Buffer struct {
    data []byte
}

func (b *Buffer) Write(p []byte) (int, error) {
    b.data = append(b.data, p...)
    return len(p), nil
}

// Usage
var buf Buffer  // Zero value works immediately
buf.Write([]byte("hello"))
```

### Struct Initialization
Use field names in struct literals for clarity:

```go
// Good
user := User{
    ID:    123,
    Email: "user@example.com",
    CreatedAt: time.Now(),
}

// Avoid positional initialization
user := User{123, "user@example.com", time.Now()}
```

## Function Design

### Parameter Order
- Context first (if used)
- Required parameters  
- Optional parameters (or use functional options)

```go
// Good parameter ordering
func ProcessUser(ctx context.Context, userID int64, options *ProcessOptions) error

// Functional options for complex configuration
func NewServer(addr string, opts ...ServerOption) *Server
```

### Return Values
- Return concrete types, accept interfaces
- Use named returns for complex functions or documentation
- Error always last

```go
// Good - concrete return, interface parameter
func NewUserService(db UserRepository) *UserService

// Named returns for clarity
func ParseConfig(filename string) (config *Config, warnings []string, err error) {
    // Implementation
    return
}
```

### Receiver Types
Choose pointer vs value receivers consistently:

```go
type Counter struct {
    count int64
    mu    sync.Mutex
}

// Pointer receivers for mutation or large structs
func (c *Counter) Increment() {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.count++
}

// Value receivers for small, immutable types
type Point struct{ X, Y int }

func (p Point) String() string {
    return fmt.Sprintf("(%d, %d)", p.X, p.Y)
}
```

For advanced patterns, see [Concurrency Patterns](concurrency-patterns.md#safe-receivers).

## Error Handling Patterns

### Error Wrapping
Use `fmt.Errorf` with `%w` verb for context:

```go
func ProcessFile(filename string) error {
    f, err := os.Open(filename)
    if err != nil {
        return fmt.Errorf("open file %q: %w", filename, err)
    }
    defer f.Close()
    
    if err := process(f); err != nil {
        return fmt.Errorf("process file %q: %w", filename, err)
    }
    return nil
}
```

### Custom Error Types
For type-based error handling:

```go
type ValidationError struct {
    Field   string
    Message string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation failed for %s: %s", e.Field, e.Message)
}

// Usage with errors.As
var validationErr *ValidationError
if errors.As(err, &validationErr) {
    // Handle validation error specifically
}
```

For comprehensive error patterns, see [Idiomatic Patterns](idiomatic-patterns.md#error-handling).

## Code Organization

### File Structure
Organize code files logically within packages:

```
user/
├── user.go          // Core types and interfaces
├── service.go       // Business logic
├── repository.go    // Data access
├── handler.go       // HTTP handlers
└── user_test.go     // Tests
```

### Function Grouping
Group related functions together, constructor functions first:

```go
// Constructor first
func NewUserService(db Database) *UserService {
    return &UserService{db: db}
}

// Core methods
func (s *UserService) Create(user User) error { }
func (s *UserService) GetByID(id int64) (User, error) { }
func (s *UserService) Update(user User) error { }

// Utility methods last
func (s *UserService) validateUser(user User) error { }
```

## Documentation Standards

### Package Documentation
Every package should have a package comment:

```go
// Package user provides user management functionality including
// authentication, authorization, and user lifecycle management.
//
// The primary interface is UserService which coordinates between
// storage repositories and business logic.
package user
```

### Documentation Standards

#### Function Documentation
All exported functions must have comments following the linter-expected format:

```go
// ValidateEmail checks if the provided email address is valid according to RFC standards.
// Returns true if the email format is correct, false otherwise.
func ValidateEmail(email string) bool {
    // Check basic format requirements
    if !strings.Contains(email, "@") || len(email) < 3 {
        return false
    }
    
    // Validate email pattern with regex
    return emailRegex.MatchString(email)
}

// ProcessPayment handles payment processing for the given amount using the provided card token.
// Returns the transaction ID on success or an error if processing fails.
// Amount must be positive and card token must be valid.
func ProcessPayment(amount decimal.Decimal, cardToken string) (string, error) {
    // Validate input parameters
    if amount.LessThanOrEqual(decimal.Zero) {
        return "", errors.New("amount must be positive")
    }
    
    if cardToken == "" {
        return "", errors.New("card token is required")
    }
    
    // Initialize payment processor
    processor := NewPaymentProcessor()
    
    // Process payment with external service
    result, err := processor.Charge(amount, cardToken)
    if err != nil {
        return "", fmt.Errorf("payment processing failed: %w", err)
    }
    
    return result.TransactionID, nil
}
```

#### Struct and Interface Documentation
Document all exported types with purpose and usage:

```go
// User represents a system user with authentication and profile information.
// All exported fields are validated during creation and updates.
// Use NewUser() constructor for proper initialization.
type User struct {
    // ID is the unique identifier for the user (auto-generated)
    ID string `json:"id" db:"id"`
    
    // Name is the user's display name (required, max 100 characters)
    Name string `json:"name" db:"name" validate:"required,max=100"`
    
    // Email is the user's email address used for authentication (unique)
    Email string `json:"email" db:"email" validate:"required,email"`
    
    // CreatedAt tracks when the user account was created
    CreatedAt time.Time `json:"created_at" db:"created_at"`
    
    // isActive indicates if the user account is active (unexported)
    isActive bool
}

// UserRepository defines the interface for user data persistence operations.
// Implementations must handle concurrent access safely and provide transaction support.
type UserRepository interface {
    // Save persists a user to the data store, setting ID if new.
    // Returns error if validation fails or persistence operation fails.
    Save(ctx context.Context, user *User) error
    
    // FindByID retrieves a user by their unique identifier.
    // Returns ErrUserNotFound if user doesn't exist.
    FindByID(ctx context.Context, id string) (*User, error)
    
    // Delete removes a user from the data store.
    // Returns ErrUserNotFound if user doesn't exist.
    Delete(ctx context.Context, id string) error
}
```

#### Method Documentation
Document methods with receiver information:

```go
// Validate performs schema validation for User and returns error if validation fails.
// Checks required fields, format constraints, and business rules.
// Should be called before Save operations.
func (u *User) Validate() error {
    // Check required fields
    if u.Name == "" {
        return errors.New("name is required")
    }
    
    if u.Email == "" {
        return errors.New("email is required")
    }
    
    // Validate email format
    if !isValidEmail(u.Email) {
        return errors.New("invalid email format")
    }
    
    // Check name length constraints
    if len(u.Name) > 100 {
        return errors.New("name exceeds maximum length")
    }
    
    return nil
}

// IsActive returns true if the user account is currently active.
// Inactive users cannot authenticate or perform operations.
func (u *User) IsActive() bool {
    return u.isActive
}

// Activate sets the user account to active status.
// Only administrators should call this method.
func (u *User) Activate() {
    u.isActive = true
}
```

#### Variable and Constant Documentation
Document package-level declarations:

```go
// ErrUserNotFound is returned when a requested user doesn't exist in the data store.
var ErrUserNotFound = errors.New("user not found")

// ErrInvalidCredentials is returned when authentication fails due to invalid credentials.
var ErrInvalidCredentials = errors.New("invalid credentials")

// DefaultTimeout is the default timeout for user operations.
// Can be overridden in configuration for specific environments.
const DefaultTimeout = 30 * time.Second

// MaxUsersPerPage defines the maximum number of users returned in paginated responses.
// Prevents memory issues and improves response times.
const MaxUsersPerPage = 100
```

#### Logical Block Comments
Add comments after every major logical block:

```go
// CreateUser creates a new user account with the provided information.
// Validates input, checks for duplicates, and persists to data store.
// Returns the created user with generated ID or validation error.
func (s *UserService) CreateUser(ctx context.Context, req CreateUserRequest) (*User, error) {
    // Validate request parameters
    if err := req.Validate(); err != nil {
        return nil, fmt.Errorf("invalid request: %w", err)
    }
    
    // Check for existing user with same email
    existing, err := s.repository.FindByEmail(ctx, req.Email)
    if err != nil && !errors.Is(err, ErrUserNotFound) {
        return nil, fmt.Errorf("failed to check existing user: %w", err)
    }
    
    if existing != nil {
        return nil, ErrUserAlreadyExists
    }
    
    // Create new user instance
    user := &User{
        ID:        generateID(),
        Name:      req.Name,
        Email:     req.Email,
        CreatedAt: time.Now(),
        isActive:  true,
    }
    
    // Persist user to data store
    if err := s.repository.Save(ctx, user); err != nil {
        return nil, fmt.Errorf("failed to save user: %w", err)
    }
    
    // Send welcome notification (async)
    go func() {
        if err := s.emailService.SendWelcomeEmail(user.Email); err != nil {
            s.logger.Error("failed to send welcome email", "user_id", user.ID, "error", err)
        }
    }()
    
    return user, nil
}
```

### Example Documentation
Provide examples for complex functions:

```go
// ParseDuration parses a time duration string into a time.Duration.
//
// Supported units: "ms", "s", "m", "h", "d".
//
// Example:
//   dur, err := ParseDuration("1h30m")
//   if err != nil {
//       log.Fatal(err)
//   }
//   fmt.Println(dur) // Output: 1h30m0s
func ParseDuration(s string) (time.Duration, error) {
    // Implementation
}
```

## Formatting Automation

### gofmt Integration
Always use `gofmt` for code formatting. Configure your editor to run on save:

```bash
# Manual formatting
gofmt -w *.go

# With import organization
goimports -w *.go
```

### Editor Configuration
Recommended editor settings:
- Run `goimports` on save
- Show whitespace characters
- Tab width: 8 (Go standard)
- Use tabs for indentation

For editor setup details, see [Toolchain Configuration](toolchain-configuration.md#editor-setup).

## Variable Declarations

### Local Variables
Use short variable declarations when possible:

```go
// Good
user := getUser()
if user != nil {
    processUser(user)
}

// When type clarity needed
var user *User = getUser()
```

### Global Variables
Use explicit type declarations for package-level variables:

```go
var (
    ErrUserNotFound = errors.New("user not found")
    maxRetries      = 3
    defaultTimeout  = 30 * time.Second
)
```

### Zero Values
Leverage Go's zero values effectively:

```go
// Good - zero values are useful
var (
    buffer   strings.Builder  // Ready to use
    users    []User          // Ready to append
    cache    sync.Map        // Ready to store
)
```

## Channel and Concurrency Style

### Channel Declarations
Make channel direction and buffering explicit:

```go
// Clear channel intentions
func ProcessItems(items <-chan Item) <-chan Result {
    results := make(chan Result, 100) // Buffered for performance
    
    go func() {
        defer close(results)
        for item := range items {
            results <- process(item)
        }
    }()
    
    return results
}
```

### Mutex Embedding
Don't embed mutexes in exported structs:

```go
// Good
type UserCache struct {
    mu    sync.RWMutex
    users map[int64]*User
}

func (c *UserCache) Get(id int64) *User {
    c.mu.RLock()
    defer c.mu.RUnlock()
    return c.users[id]
}

// Avoid - exposes mutex methods
type UserCache struct {
    sync.RWMutex
    users map[int64]*User
}
```

For advanced concurrency patterns, see [Concurrency Patterns](concurrency-patterns.md).

## Performance Considerations

### String Building
Use `strings.Builder` for efficient string concatenation:

```go
// Good
var builder strings.Builder
for _, item := range items {
    builder.WriteString(item.String())
    builder.WriteString("\n")
}
result := builder.String()

// Avoid repeated concatenation
var result string
for _, item := range items {
    result += item.String() + "\n"  // Creates new string each time
}
```

### Slice Operations
Pre-allocate slices when size is known:

```go
// Good - pre-allocate with known capacity
users := make([]User, 0, len(userIDs))
for _, id := range userIDs {
    user, err := getUser(id)
    if err != nil {
        continue
    }
    users = append(users, user)
}

// Consider pre-allocation even when filtering
filtered := make([]Item, 0, len(items)/2) // Estimate capacity
```

For detailed optimization techniques, see [Performance Optimization](performance-optimization.md).

## Style Enforcement

### Team Standards
Establish team-wide style standards:

1. **Consistent Naming**: Agree on naming conventions for domain concepts
2. **Error Messages**: Use consistent error message formats
3. **Logging**: Standardize log levels and message formats
4. **Testing**: Consistent test naming and organization

### Code Review Checklist
During code reviews, verify:
- [ ] Consistent naming following Go conventions
- [ ] Proper error handling and wrapping
- [ ] Appropriate use of interfaces
- [ ] Clear function and variable names
- [ ] Proper documentation for exported items
- [ ] Consistent code organization

### Automation Tools
Use automated tools to enforce style:
- **gofmt/goimports**: Formatting and import organization
- **golangci-lint**: Comprehensive linting (see [Toolchain Configuration](toolchain-configuration.md))
- **revive**: Additional style checking
- **staticcheck**: Advanced static analysis

This style guide ensures consistent, readable, and maintainable Go code across enterprise development teams. The patterns here integrate with [Security Practices](security-practices.md) for secure coding and [Testing Strategies](testing-strategies.md) for maintainable tests.

Adherence to these style guidelines facilitates code reviews, reduces bugs, and improves team productivity. For questions about specific patterns or exceptions, consult [Anti-patterns](anti-patterns.md) for guidance on what to avoid.