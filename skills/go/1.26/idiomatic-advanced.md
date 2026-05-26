# Idiomatic Go Advanced

*Advanced Go patterns for API design, resource management, and enterprise development on Go 1.26.x*

## Data Structure Patterns

### Slice Operations
Handle slices safely and efficiently:

```go
import (
    "sync"
)

// Safe slice operations
func RemoveItem(slice []string, index int) []string {
    if index < 0 || index >= len(slice) {
        return slice
    }
    
    // Remove by preserving order
    return append(slice[:index], slice[index+1:]...)
}

// Remove without preserving order (more efficient)
func RemoveItemFast(slice []string, index int) []string {
    if index < 0 || index >= len(slice) {
        return slice
    }
    
    // Swap with last element and truncate
    slice[index] = slice[len(slice)-1]
    return slice[:len(slice)-1]
}

// Filter slice with pre-allocated capacity
func FilterUsers(users []User, predicate func(User) bool) []User {
    result := make([]User, 0, len(users)) // Pre-allocate capacity
    
    for _, user := range users {
        if predicate(user) {
            result = append(result, user)
        }
    }
    
    return result
}

// Slice patterns for different scenarios
func SlicePatterns() {
    // nil slice vs empty slice
    var nilSlice []string        // nil slice - preferred for empty
    emptySlice := []string{}     // non-nil empty slice
    emptySlice2 := make([]string, 0) // non-nil empty slice
    
    // Pre-allocation for known capacity
    items := make([]Item, 0, 1000) // length 0, capacity 1000
    
    // Reuse slice to avoid allocation
    filtered := items[:0] // Reuse underlying array
    for _, item := range items {
        if item.IsValid() {
            filtered = append(filtered, item)
        }
    }
}
```

### Map Operations
Use maps effectively and safely:

```go
// Thread-safe map operations
type SafeMap struct {
    data map[string]any
    mu   sync.RWMutex
}

func NewSafeMap() *SafeMap {
    return &SafeMap{
        data: make(map[string]any),
    }
}

func (sm *SafeMap) Get(key string) (any, bool) {
    sm.mu.RLock()
    defer sm.mu.RUnlock()
    
    value, exists := sm.data[key]
    return value, exists
}

func (sm *SafeMap) Set(key string, value any) {
    sm.mu.Lock()
    defer sm.mu.Unlock()
    
    sm.data[key] = value
}

func (sm *SafeMap) Delete(key string) {
    sm.mu.Lock()
    defer sm.mu.Unlock()
    
    delete(sm.data, key) // Safe even if key doesn't exist
}

func (sm *SafeMap) Keys() []string {
    sm.mu.RLock()
    defer sm.mu.RUnlock()
    
    keys := make([]string, 0, len(sm.data))
    for key := range sm.data {
        keys = append(keys, key)
    }
    return keys
}

// Map initialization patterns
func MapPatterns() {
    // Literal initialization
    users := map[string]*User{
        "user1": {ID: 1, Name: "Alice"},
        "user2": {ID: 2, Name: "Bob"},
    }
    
    // Pre-allocated map
    cache := make(map[string]any, 100)
    
    // Check for key existence
    if user, exists := users["user1"]; exists {
        processUser(user)
    }
    
    // Safe deletion
    delete(users, "user1") // No-op if key doesn't exist
}
```

### Channel Patterns
Use channels for communication and synchronization:

```go
// Producer-consumer pattern
func ProcessItems(items []Item) <-chan Result {
    results := make(chan Result, len(items))
    
    go func() {
        defer close(results) // Always close channels
        
        for _, item := range items {
            result := processItem(item)
            results <- result
        }
    }()
    
    return results
}

// Fan-out pattern
func DistributeWork(work []Task, numWorkers int) <-chan Result {
    tasks := make(chan Task, len(work))
    results := make(chan Result, len(work))
    
    // Send tasks
    go func() {
        defer close(tasks)
        for _, task := range work {
            tasks <- task
        }
    }()
    
    // Start workers
    for i := 0; i < numWorkers; i++ {
        go func() {
            for task := range tasks {
                results <- processTask(task)
            }
        }()
    }
    
    return results
}

// Timeout pattern
func ProcessWithTimeout(data []Item, timeout time.Duration) error {
    done := make(chan error, 1)
    
    go func() {
        done <- processData(data)
    }()
    
    select {
    case err := <-done:
        return err
    case <-time.After(timeout):
        return errors.New("processing timeout")
    }
}
```

## Resource Management

### Defer Patterns
Use defer for cleanup and resource management:

```go
import (
    "os"
    "database/sql"
)

// File processing with proper cleanup
func ProcessFile(filename string) error {
    file, err := os.Open(filename)
    if err != nil {
        return fmt.Errorf("open file: %w", err)
    }
    defer file.Close() // Always cleanup
    
    // Multiple defers execute in LIFO order
    defer func() {
        if r := recover(); r != nil {
            log.Printf("Recovered from panic: %v", r)
        }
    }()
    
    return processFileContent(file)
}

// Database transaction with rollback
func UpdateDatabase(tx *sql.Tx) (err error) {
    defer func() {
        if err != nil {
            if rbErr := tx.Rollback(); rbErr != nil {
                log.Printf("Rollback failed: %v", rbErr)
            }
        } else {
            err = tx.Commit()
        }
    }()
    
    // Database operations
    if err := insertUser(tx); err != nil {
        return fmt.Errorf("insert user: %w", err)
    }
    
    if err := updateMetrics(tx); err != nil {
        return fmt.Errorf("update metrics: %w", err)
    }
    
    return nil
}

// Resource cleanup with multiple resources
func ProcessMultipleResources() error {
    file1, err := os.Open("file1.txt")
    if err != nil {
        return err
    }
    defer file1.Close()
    
    file2, err := os.Open("file2.txt")
    if err != nil {
        return err
    }
    defer file2.Close()
    
    db, err := sql.Open("postgres", "connection-string")
    if err != nil {
        return err
    }
    defer db.Close()
    
    // Process all resources
    return processAllResources(file1, file2, db)
}
```

### Resource Pooling
Implement resource pools for expensive resources:

```go
import (
    "net"
    "context"
    "time"
)

type ConnectionPool struct {
    connections chan net.Conn
    factory     func() (net.Conn, error)
    maxSize     int
    timeout     time.Duration
}

func NewConnectionPool(size int, factory func() (net.Conn, error), timeout time.Duration) *ConnectionPool {
    return &ConnectionPool{
        connections: make(chan net.Conn, size),
        factory:     factory,
        maxSize:     size,
        timeout:     timeout,
    }
}

func (p *ConnectionPool) Get(ctx context.Context) (net.Conn, error) {
    select {
    case conn := <-p.connections:
        // Test connection is still valid
        conn.SetDeadline(time.Now().Add(time.Second))
        return conn, nil
    case <-ctx.Done():
        return nil, ctx.Err()
    default:
        // Pool empty, create new connection
        return p.factory()
    }
}

func (p *ConnectionPool) Put(conn net.Conn) {
    if conn == nil {
        return
    }
    
    select {
    case p.connections <- conn:
        // Connection returned to pool
    default:
        // Pool full, close connection
        conn.Close()
    }
}

func (p *ConnectionPool) Close() {
    close(p.connections)
    
    // Close all connections in pool
    for conn := range p.connections {
        conn.Close()
    }
}
```

## API Design Patterns

### Function Options Pattern
Use functional options for configurable APIs:

```go
import (
    "log"
    "time"
)

// ServerConfig holds configuration parameters for HTTP server initialization.
// Use functional options pattern for flexible configuration.
type ServerConfig struct {
    // Port is the TCP port number for the server to listen on (default: 8080)
    Port int
    
    // ReadTimeout is the maximum duration for reading the entire request including body
    ReadTimeout time.Duration
    
    // WriteTimeout is the maximum duration before timing out writes of the response
    WriteTimeout time.Duration
    
    // Logger is the structured logger instance for server operations
    Logger *log.Logger
    
    // TLSCert is the path to the TLS certificate file (optional)
    TLSCert string
    
    // TLSKey is the path to the TLS private key file (optional)
    TLSKey string
    
    // MaxConns is the maximum number of concurrent connections (default: 1000)
    MaxConns int
}

// ServerOption defines a function type for configuring ServerConfig.
// Used with functional options pattern for flexible server configuration.
type ServerOption func(*ServerConfig)

// WithPort returns a ServerOption that sets the server port.
// Port must be between 1 and 65535. Use 0 for automatic port selection.
func WithPort(port int) ServerOption {
    return func(c *ServerConfig) {
        c.Port = port
    }
}

// WithTimeout returns a ServerOption that sets read and write timeouts.
// Both timeouts should be positive durations to prevent hanging connections.
func WithTimeout(read, write time.Duration) ServerOption {
    return func(c *ServerConfig) {
        c.ReadTimeout = read
        c.WriteTimeout = write
    }
}

func WithTLS(certFile, keyFile string) ServerOption {
    return func(c *ServerConfig) {
        c.TLSCert = certFile
        c.TLSKey = keyFile
    }
}

func WithMaxConnections(max int) ServerOption {
    return func(c *ServerConfig) {
        c.MaxConns = max
    }
}

func WithLogger(logger *log.Logger) ServerOption {
    return func(c *ServerConfig) {
        c.Logger = logger
    }
}

func NewServer(addr string, options ...ServerOption) *Server {
    config := &ServerConfig{
        Port:         8080,
        ReadTimeout:  30 * time.Second,
        WriteTimeout: 30 * time.Second,
        Logger:       log.Default(),
        MaxConns:     1000,
    }
    
    for _, option := range options {
        option(config)
    }
    
    return &Server{
        Addr:   fmt.Sprintf("%s:%d", addr, config.Port),
        Config: config,
    }
}

// Usage examples
func ExampleServerOptions() {
    // Basic server
    server1 := NewServer("localhost")
    
    // Server with custom port
    server2 := NewServer("localhost", WithPort(9000))
    
    // Server with multiple options
    server3 := NewServer("localhost",
        WithPort(443),
        WithTLS("/path/to/cert.pem", "/path/to/key.pem"),
        WithTimeout(60*time.Second, 60*time.Second),
        WithMaxConnections(5000),
    )
}
```

### Builder Pattern
Use builders for complex object construction:

```go
import "strings"

type QueryBuilder struct {
    table     string
    columns   []string
    where     []string
    joins     []string
    orderBy   []string
    groupBy   []string
    having    []string
    limit     *int
    offset    *int
    args      []any
}

func NewQuery(table string) *QueryBuilder {
    return &QueryBuilder{
        table:   table,
        columns: make([]string, 0),
        where:   make([]string, 0),
        joins:   make([]string, 0),
        orderBy: make([]string, 0),
        groupBy: make([]string, 0),
        having:  make([]string, 0),
        args:    make([]any, 0),
    }
}

func (qb *QueryBuilder) Select(columns ...string) *QueryBuilder {
    qb.columns = append(qb.columns, columns...)
    return qb
}

func (qb *QueryBuilder) Where(condition string, args ...any) *QueryBuilder {
    qb.where = append(qb.where, condition)
    qb.args = append(qb.args, args...)
    return qb
}

func (qb *QueryBuilder) Join(table, condition string) *QueryBuilder {
    qb.joins = append(qb.joins, fmt.Sprintf("JOIN %s ON %s", table, condition))
    return qb
}

func (qb *QueryBuilder) LeftJoin(table, condition string) *QueryBuilder {
    qb.joins = append(qb.joins, fmt.Sprintf("LEFT JOIN %s ON %s", table, condition))
    return qb
}

func (qb *QueryBuilder) OrderBy(column string) *QueryBuilder {
    qb.orderBy = append(qb.orderBy, column)
    return qb
}

func (qb *QueryBuilder) GroupBy(columns ...string) *QueryBuilder {
    qb.groupBy = append(qb.groupBy, columns...)
    return qb
}

func (qb *QueryBuilder) Having(condition string, args ...any) *QueryBuilder {
    qb.having = append(qb.having, condition)
    qb.args = append(qb.args, args...)
    return qb
}

func (qb *QueryBuilder) Limit(n int) *QueryBuilder {
    qb.limit = &n
    return qb
}

func (qb *QueryBuilder) Offset(n int) *QueryBuilder {
    qb.offset = &n
    return qb
}

func (qb *QueryBuilder) Build() (string, []any) {
    var query strings.Builder
    
    // SELECT clause
    query.WriteString("SELECT ")
    if len(qb.columns) == 0 {
        query.WriteString("*")
    } else {
        query.WriteString(strings.Join(qb.columns, ", "))
    }
    
    // FROM clause
    query.WriteString(" FROM ")
    query.WriteString(qb.table)
    
    // JOIN clauses
    if len(qb.joins) > 0 {
        query.WriteString(" ")
        query.WriteString(strings.Join(qb.joins, " "))
    }
    
    // WHERE clause
    if len(qb.where) > 0 {
        query.WriteString(" WHERE ")
        query.WriteString(strings.Join(qb.where, " AND "))
    }
    
    // GROUP BY clause
    if len(qb.groupBy) > 0 {
        query.WriteString(" GROUP BY ")
        query.WriteString(strings.Join(qb.groupBy, ", "))
    }
    
    // HAVING clause
    if len(qb.having) > 0 {
        query.WriteString(" HAVING ")
        query.WriteString(strings.Join(qb.having, " AND "))
    }
    
    // ORDER BY clause
    if len(qb.orderBy) > 0 {
        query.WriteString(" ORDER BY ")
        query.WriteString(strings.Join(qb.orderBy, ", "))
    }
    
    // LIMIT clause
    if qb.limit != nil {
        query.WriteString(fmt.Sprintf(" LIMIT %d", *qb.limit))
    }
    
    // OFFSET clause
    if qb.offset != nil {
        query.WriteString(fmt.Sprintf(" OFFSET %d", *qb.offset))
    }
    
    return query.String(), qb.args
}

// Usage example
func ExampleQueryBuilder() {
    query, args := NewQuery("users").
        Select("id", "name", "email", "created_at").
        LeftJoin("profiles", "users.id = profiles.user_id").
        Where("users.age > ?", 18).
        Where("users.active = ?", true).
        GroupBy("users.id").
        Having("COUNT(profiles.id) > ?", 0).
        OrderBy("users.created_at DESC").
        Limit(10).
        Offset(20).
        Build()
    
    fmt.Println(query)
    fmt.Println(args)
}
```

## Naming Patterns

### Function Naming Conventions
Use clear, descriptive function names that indicate purpose:

```go
// Good - clear action verbs
func ValidateUser(user *User) error { /* ... */ }
func TransformData(input []byte) ([]byte, error) { /* ... */ }
func ParseConfig(filename string) (*Config, error) { /* ... */ }

// Constructor patterns
func NewUserService(db Database) *UserService { /* ... */ }
func NewHTTPClient(timeout time.Duration) *HTTPClient { /* ... */ }

// Boolean functions with clear questions
func IsValidEmail(email string) bool { /* ... */ }
func HasPermission(user *User, resource string) bool { /* ... */ }
func CanProcess(item *Item) bool { /* ... */ }

// Event handler patterns
func HandleUserCreated(event UserCreatedEvent) error { /* ... */ }
func OnConnectionEstablished(conn net.Conn) { /* ... */ }

// Getter/Setter patterns (use sparingly)
func (u *User) GetName() string { return u.name }
func (u *User) SetName(name string) { u.name = name }

// Preferred: direct field access or methods with business logic
func (u *User) Name() string { return u.name }
func (u *User) UpdateName(name string) error {
    if name == "" {
        return errors.New("name cannot be empty")
    }
    u.name = name
    return nil
}
```

### Variable Naming
Use contextually appropriate variable names:

```go
// Good - clear in context
func ProcessUsers(users []*User) {
    for i, user := range users {
        if user.Active {
            log.Printf("Processing user %d: %s", i, user.Name)
            processUser(user)
        }
    }
}

// Good - descriptive for wider scope
func ProcessPayment(amount decimal.Decimal) error {
    paymentProcessor := NewPaymentProcessor()
    transactionID := generateTransactionID()
    
    processingContext := &PaymentContext{
        TransactionID: transactionID,
        Amount:        amount,
        Timestamp:     time.Now(),
    }
    
    if err := paymentProcessor.Process(processingContext); err != nil {
        return fmt.Errorf("process payment %s: %w", transactionID, err)
    }
    
    return nil
}

// Package-level variables
var (
    ErrInvalidInput = errors.New("invalid input")
    DefaultTimeout  = 30 * time.Second
)

// Constants
const (
    MaxRetryAttempts = 3
    DefaultBufferSize = 4096
    APIVersion       = "v1.2.3"
)
```

### Package and Type Naming
Follow Go conventions for package and type names:

```go
// Package names: short, lowercase, no underscores
package userservice
package httputil
package stringhelper

// Type names: PascalCase, descriptive
type UserRepository any
type HTTPClient struct{}
type DatabaseConnection struct{}

// Avoid stuttering
// Good
type User struct {
    ID   string
    Name string
}

func (u User) String() string { return u.Name }

// Bad - stuttering
type UserStruct struct {
    UserID   string
    UserName string
}

func (u UserStruct) UserString() string { return u.UserName }
```

## Enterprise Integration Patterns

### Service Interfaces
Design clean interfaces for service boundaries:

```go
// Domain service interface
type UserService interface {
    CreateUser(ctx context.Context, req CreateUserRequest) (*User, error)
    GetUser(ctx context.Context, userID string) (*User, error)
    UpdateUser(ctx context.Context, userID string, req UpdateUserRequest) (*User, error)
    DeleteUser(ctx context.Context, userID string) error
    ListUsers(ctx context.Context, filters UserFilters) ([]*User, error)
}

// Repository interface (data layer)
type UserRepository interface {
    Save(ctx context.Context, user *User) error
    FindByID(ctx context.Context, id string) (*User, error)
    FindByEmail(ctx context.Context, email string) (*User, error)
    Delete(ctx context.Context, id string) error
    List(ctx context.Context, limit, offset int) ([]*User, error)
}

// External service interface
type NotificationService interface {
    SendEmail(ctx context.Context, req EmailRequest) error
    SendSMS(ctx context.Context, req SMSRequest) error
}

// Implementation with dependency injection
type userService struct {
    userRepo     UserRepository
    notification NotificationService
    logger       Logger
}

func NewUserService(repo UserRepository, notification NotificationService, logger Logger) UserService {
    return &userService{
        userRepo:     repo,
        notification: notification,
        logger:       logger,
    }
}

func (s *userService) CreateUser(ctx context.Context, req CreateUserRequest) (*User, error) {
    // Validation
    if err := req.Validate(); err != nil {
        return nil, fmt.Errorf("invalid request: %w", err)
    }
    
    // Business logic
    user := &User{
        ID:    generateUserID(),
        Name:  req.Name,
        Email: req.Email,
    }
    
    // Persist
    if err := s.userRepo.Save(ctx, user); err != nil {
        return nil, fmt.Errorf("save user: %w", err)
    }
    
    // Side effects
    if err := s.notification.SendEmail(ctx, WelcomeEmail(user)); err != nil {
        s.logger.Log("warn", "failed to send welcome email", map[string]any{
            "user_id": user.ID,
            "error":   err.Error(),
        })
    }
    
    return user, nil
}
```

For basic error handling and interface patterns, see [Idiomatic Basics](idiomatic-basics.md). For performance optimization of data structures, see [Performance Optimization](performance-optimization.md). For security considerations in API design, see [Security Practices](security-practices.md).