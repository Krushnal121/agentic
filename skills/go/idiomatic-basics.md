# Idiomatic Go Basics

*Essential Go idioms based on [Effective Go](https://go.dev/doc/effective_go) and [Code Review Comments](https://go.dev/wiki/CodeReviewComments) for Go 1.26.x*

## Error Handling

### Error Wrapping and Context
Always provide context when wrapping errors:

```go
import (
    "errors"
    "fmt"
)

func ProcessOrder(orderID string) error {
    order, err := fetchOrder(orderID)
    if err != nil {
        return fmt.Errorf("fetch order %q: %w", orderID, err)
    }
    
    if err := validateOrder(order); err != nil {
        return fmt.Errorf("validate order %q: %w", orderID, err)
    }
    
    return nil
}

// ComplexOperation performs multi-step user permission validation.
// Returns error with context if any step fails, preserving error chain.
func ComplexOperation(userID string) error {
    // Retrieve user from data store
    user, err := getUser(userID)
    if err != nil {
        return fmt.Errorf("get user %s: %w", userID, err)
    }
    
    // Fetch user permissions from authorization service
    permissions, err := getUserPermissions(user.ID)
    if err != nil {
        return fmt.Errorf("get permissions for user %s: %w", userID, err)
    }
    
    // Validate permissions against business rules
    if err := validatePermissions(permissions); err != nil {
        return fmt.Errorf("validate permissions for user %s: %w", userID, err)
    }
    
    return nil
}
```

### Sentinel Errors
Use sentinel errors for expected error conditions:

```go
// ErrUserNotFound is returned when a user lookup fails to find the requested user.
var ErrUserNotFound = errors.New("user not found")

// ErrInsufficientFunds is returned when a transaction cannot be completed due to insufficient balance.
var ErrInsufficientFunds = errors.New("insufficient funds")

// ErrInvalidInput is returned when input validation fails.
var ErrInvalidInput = errors.New("invalid input")
```

### Documentation Standards for Error Handling
Document error conditions and return values:

```go
var (
    ErrUserNotFound     = errors.New("user not found")
    ErrInvalidInput     = errors.New("invalid input")
    ErrUnauthorized     = errors.New("unauthorized")
    ErrResourceExhausted = errors.New("resource exhausted")
)

func GetUser(id int64) (*User, error) {
    if id <= 0 {
        return nil, ErrInvalidInput
    }
    
    user := lookupUser(id)
    if user == nil {
        return nil, ErrUserNotFound
    }
    
    return user, nil
}

// Usage with errors.Is for robust error checking
func HandleUserOperation(userID int64) {
    user, err := GetUser(userID)
    if err != nil {
        switch {
        case errors.Is(err, ErrUserNotFound):
            log.Printf("User %d not found", userID)
            return
        case errors.Is(err, ErrInvalidInput):
            log.Printf("Invalid user ID: %d", userID)
            return
        default:
            log.Printf("Unexpected error: %v", err)
            return
        }
    }
    
    processUser(user)
}
```

### Custom Error Types
Create custom error types for structured error handling:

```go
// Validation error with detailed context
type ValidationError struct {
    Field   string
    Value   any
    Message string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation failed for field %q: %s", e.Field, e.Message)
}

// Network error with retry information
type NetworkError struct {
    Op       string
    Endpoint string
    Retry    bool
    Err      error
}

func (e *NetworkError) Error() string {
    return fmt.Sprintf("network %s to %s failed: %v", e.Op, e.Endpoint, e.Err)
}

func (e *NetworkError) Unwrap() error {
    return e.Err
}

// Usage with errors.As for type-specific handling
func HandleErrors(err error) {
    var validationErr *ValidationError
    if errors.As(err, &validationErr) {
        log.Printf("Field %s failed validation: %s", 
            validationErr.Field, validationErr.Message)
        return
    }
    
    var networkErr *NetworkError
    if errors.As(err, &networkErr) {
        if networkErr.Retry {
            log.Printf("Retryable network error: %v", networkErr)
            // Implement retry logic
        } else {
            log.Printf("Fatal network error: %v", networkErr)
        }
        return
    }
    
    log.Printf("Unknown error: %v", err)
}
```

### Error Handling Chains
Structure error handling for early returns:

```go
func ProcessRequest(req *Request) (*Response, error) {
    // Validate early
    if err := validateRequest(req); err != nil {
        return nil, fmt.Errorf("invalid request: %w", err)
    }
    
    // Fetch data
    data, err := fetchData(req.DataID)
    if err != nil {
        return nil, fmt.Errorf("fetch data %s: %w", req.DataID, err)
    }
    
    // Process data
    result, err := processData(data)
    if err != nil {
        return nil, fmt.Errorf("process data: %w", err)
    }
    
    // Transform result
    transformed, err := transformResult(result)
    if err != nil {
        return nil, fmt.Errorf("transform result: %w", err)
    }
    
    return &Response{Result: transformed}, nil
}

// Error aggregation for multiple operations
func ProcessMultipleItems(items []Item) error {
    var errors []error
    
    for i, item := range items {
        if err := processItem(item); err != nil {
            errors = append(errors, fmt.Errorf("item %d: %w", i, err))
        }
    }
    
    if len(errors) > 0 {
        return fmt.Errorf("processing failed: %v", errors)
    }
    
    return nil
}
```

## Interface Design

### Small, Focused Interfaces
Design minimal interfaces for specific behaviors:

```go
// Reader defines the interface for reading data from a source.
// Read reads up to len(p) bytes into p and returns the number of bytes read.
type Reader interface {
    // Read reads data into p and returns the number of bytes read (0 <= n <= len(p)) and any error.
    // Read should return (0, io.EOF) when no more data is available.
    Read(p []byte) (n int, err error)
}

// Writer defines the interface for writing data to a destination.
// Write must not modify the slice data, even temporarily.
type Writer interface {
    // Write writes len(p) bytes from p to the underlying data stream.
    // Returns the number of bytes written and any error that caused early termination.
    Write(p []byte) (n int, err error)
}

// Closer defines the interface for resources that can be closed.
// Close releases any resources associated with the object.
type Closer interface {
    // Close closes the resource and returns any error that occurred during closing.
    // Close should be safe to call multiple times.
    Close() error
}

// ReadWriter combines Reader and Writer interfaces for bidirectional data flow.
// Implementations must handle both read and write operations safely.
type ReadWriter interface {
    Reader
    Writer
}

// ReadWriteCloser combines Reader, Writer, and Closer for complete I/O resource management.
// Used for connections, files, and other resources that need explicit cleanup.
type ReadWriteCloser interface {
    Reader
    Writer
    Closer
}

// Domain-specific interfaces
type UserStore interface {
    GetUser(id string) (*User, error)
    SaveUser(user *User) error
}

type EmailSender interface {
    SendEmail(to, subject, body string) error
}

type Logger interface {
    Log(level string, message string, fields map[string]any)
}
```

### Interface Placement
Define interfaces in the consumer package, not the producer:

```go
// In consumer package (service layer)
type UserRepository interface {
    GetByID(int64) (*User, error)
    GetByEmail(string) (*User, error)
    Save(*User) error
    Delete(int64) error
}

type NotificationSender interface {
    SendNotification(userID string, message string) error
}

func NewUserService(repo UserRepository, notifier NotificationSender) *UserService {
    return &UserService{
        repo:     repo,
        notifier: notifier,
    }
}

// Producer packages provide concrete implementations
type PostgreSQLUserRepository struct {
    db *sql.DB
}

func (r *PostgreSQLUserRepository) GetByID(id int64) (*User, error) {
    // Implementation
}

func (r *PostgreSQLUserRepository) GetByEmail(email string) (*User, error) {
    // Implementation
}

func (r *PostgreSQLUserRepository) Save(user *User) error {
    // Implementation
}

func (r *PostgreSQLUserRepository) Delete(id int64) error {
    // Implementation
}
```

### Interface Compliance Verification
Verify interface compliance at compile time:

```go
import "net/http"

type Handler struct {
    userService *UserService
}

// Compile-time interface compliance checks
var _ http.Handler = (*Handler)(nil)
var _ http.HandlerFunc = Handler.ServeHTTP

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    // Implementation
}

// Multiple interface compliance
type MultiInterface struct{}

var _ Reader = (*MultiInterface)(nil)
var _ Writer = (*MultiInterface)(nil)
var _ Closer = (*MultiInterface)(nil)

func (m *MultiInterface) Read(p []byte) (int, error) { return 0, nil }
func (m *MultiInterface) Write(p []byte) (int, error) { return 0, nil }
func (m *MultiInterface) Close() error { return nil }
```

### Type Assertions and Type Switches
Handle interface types safely:

```go
// Type assertion with ok check
func ProcessValue(v any) error {
    s, ok := v.(string)
    if !ok {
        return fmt.Errorf("expected string, got %T", v)
    }
    
    // Process string safely
    return processString(s)
}

// Type switch for multiple types
func HandleValue(v any) {
    switch val := v.(type) {
    case string:
        handleString(val)
    case int:
        handleInt(val)
    case int64:
        handleInt64(val)
    case *User:
        handleUser(val)
    case []byte:
        handleBytes(val)
    case nil:
        handleNil()
    default:
        log.Printf("unexpected type: %T", val)
    }
}

// Interface type assertion
func ProcessReadCloser(rc any) error {
    // Check for specific interface
    if readCloser, ok := rc.(io.ReadCloser); ok {
        defer readCloser.Close()
        return processReader(readCloser)
    }
    
    // Fallback to basic reader
    if reader, ok := rc.(io.Reader); ok {
        return processReader(reader)
    }
    
    return fmt.Errorf("value does not implement Reader: %T", rc)
}
```

## Control Flow Patterns

### Guard Clauses and Early Returns
Use guard clauses to handle error conditions early:

```go
func ProcessUser(user *User) error {
    // Guard clauses first - handle invalid conditions
    if user == nil {
        return errors.New("user cannot be nil")
    }
    
    if user.ID <= 0 {
        return errors.New("user must have valid ID")
    }
    
    if user.Email == "" {
        return errors.New("user must have email")
    }
    
    if !isValidEmail(user.Email) {
        return fmt.Errorf("invalid email format: %s", user.Email)
    }
    
    // Main logic with reduced nesting
    if err := validateUser(user); err != nil {
        return fmt.Errorf("user validation: %w", err)
    }
    
    if err := enrichUser(user); err != nil {
        return fmt.Errorf("user enrichment: %w", err)
    }
    
    return updateUser(user)
}

// Complex validation with early returns
func ValidateOrder(order *Order) error {
    if order == nil {
        return errors.New("order cannot be nil")
    }
    
    if order.CustomerID == "" {
        return errors.New("customer ID is required")
    }
    
    if len(order.Items) == 0 {
        return errors.New("order must have at least one item")
    }
    
    if order.Total <= 0 {
        return errors.New("order total must be positive")
    }
    
    // Validate each item
    for i, item := range order.Items {
        if err := validateOrderItem(item); err != nil {
            return fmt.Errorf("item %d: %w", i, err)
        }
    }
    
    return nil
}
```

### Switch Statement Patterns
Prefer switch over long if-else chains:

```go
// Switch for multiple conditions
func GetStatusMessage(status int) string {
    switch status {
    case 200:
        return "OK"
    case 201:
        return "Created"
    case 400, 401, 403:
        return "Client Error"
    case 404:
        return "Not Found"
    case 500, 502, 503:
        return "Server Error"
    default:
        return "Unknown Status"
    }
}

// Switch without expression for complex conditions
func ProcessEvent(event *Event) {
    switch {
    case event.Type == "user" && event.Action == "create":
        handleUserCreate(event)
    case event.Type == "user" && event.Action == "update":
        handleUserUpdate(event)
    case event.Type == "user" && event.Action == "delete":
        handleUserDelete(event)
    case event.Priority > 8:
        handleCritical(event)
    case event.Priority > 5:
        handleHigh(event)
    case event.Priority > 2:
        handleMedium(event)
    default:
        handleLow(event)
    }
}

// Type switch pattern
func ProcessData(data any) string {
    switch v := data.(type) {
    case string:
        return fmt.Sprintf("String: %s", v)
    case int:
        return fmt.Sprintf("Int: %d", v)
    case bool:
        return fmt.Sprintf("Bool: %t", v)
    case []string:
        return fmt.Sprintf("String slice with %d items", len(v))
    case map[string]any:
        return fmt.Sprintf("Map with %d keys", len(v))
    default:
        return fmt.Sprintf("Unknown type: %T", v)
    }
}
```

### Range Loop Patterns
Use range loops idiomatically:

```go
// Slice iteration
func ProcessItems(items []Item) {
    // When you need both index and value
    for i, item := range items {
        fmt.Printf("Processing item %d: %v\n", i, item)
        processItem(i, item)
    }
    
    // When you only need the value
    for _, item := range items {
        processItem(item)
    }
    
    // When you only need the index
    for i := range items {
        fmt.Printf("Item %d exists\n", i)
    }
}

// Map iteration
func ProcessUserMap(users map[string]*User) {
    // Iterate over key-value pairs
    for userID, user := range users {
        fmt.Printf("User %s: %s\n", userID, user.Name)
    }
    
    // Check for key existence
    if user, exists := users[targetUserID]; exists {
        processUser(user)
    }
    
    // Safe map access
    user := users[userID] // Returns nil if key doesn't exist
    if user != nil {
        processUser(user)
    }
}

// Channel range (closes loop when channel closes)
func ProcessChannel(dataCh <-chan Data) {
    for data := range dataCh {
        processData(data)
    }
    // Loop ends when channel is closed
}

// String iteration (runes, not bytes)
func ProcessString(s string) {
    for i, r := range s {
        fmt.Printf("Rune at %d: %c\n", i, r)
    }
}
```

## Context Patterns

### Context Propagation
Always propagate context through call chains:

```go
import "context"

func HandleRequest(ctx context.Context, req *Request) (*Response, error) {
    // Validate with context
    if err := validateRequest(ctx, req); err != nil {
        return nil, err
    }
    
    // Call downstream services with context
    data, err := fetchUserData(ctx, req.UserID)
    if err != nil {
        return nil, fmt.Errorf("fetch user data: %w", err)
    }
    
    result, err := processData(ctx, data)
    if err != nil {
        return nil, fmt.Errorf("process data: %w", err)
    }
    
    return &Response{Data: result}, nil
}

// Database operations with context
func GetUser(ctx context.Context, db *sql.DB, userID int64) (*User, error) {
    query := "SELECT id, name, email FROM users WHERE id = $1"
    
    var user User
    err := db.QueryRowContext(ctx, query, userID).Scan(
        &user.ID, &user.Name, &user.Email)
    
    if err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return nil, ErrUserNotFound
        }
        return nil, fmt.Errorf("query user %d: %w", userID, err)
    }
    
    return &user, nil
}
```

### Context Values and Cancellation
Use context for cancellation and passing request-scoped values:

```go
type contextKey string

const (
    userIDKey    contextKey = "userID"
    requestIDKey contextKey = "requestID"
    traceIDKey   contextKey = "traceID"
)

func WithUserID(ctx context.Context, userID string) context.Context {
    return context.WithValue(ctx, userIDKey, userID)
}

func GetUserID(ctx context.Context) (string, bool) {
    userID, ok := ctx.Value(userIDKey).(string)
    return userID, ok
}

// Respect context cancellation
func LongRunningOperation(ctx context.Context, items []Item) error {
    for i, item := range items {
        // Check for cancellation periodically
        select {
        case <-ctx.Done():
            return fmt.Errorf("operation cancelled after processing %d items: %w", 
                i, ctx.Err())
        default:
        }
        
        if err := processItem(ctx, item); err != nil {
            return fmt.Errorf("process item %d: %w", i, err)
        }
    }
    
    return nil
}

// Context with timeout
func FetchDataWithTimeout(userID string, timeout time.Duration) (*Data, error) {
    ctx, cancel := context.WithTimeout(context.Background(), timeout)
    defer cancel()
    
    return fetchData(ctx, userID)
}
```

For advanced API design and resource management patterns, see [Idiomatic Advanced](idiomatic-advanced.md). For security considerations with error handling, see [Security Practices](security-practices.md).