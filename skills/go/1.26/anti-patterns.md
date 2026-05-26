# Anti-patterns

*Common pitfalls and constraints for Go 1.26.x enterprise development*

## Goroutine Anti-patterns

### Goroutine Leaks
Avoid creating goroutines that never terminate:

```go
// ❌ Bad: Goroutine leak - channel never closed, no documentation
func processEvents() {
    events := make(chan Event)
    
    // This goroutine will run forever
    go func() {
        for event := range events {
            handleEvent(event)
        }
    }()
    
    // events channel is never closed
}

// processEvents processes events from a source with proper lifecycle management.
// Uses context for cancellation and ensures all goroutines are cleaned up.
// ✅ Good: Proper goroutine lifecycle management with documentation
func processEvents(ctx context.Context) {
    // Buffered channel prevents blocking on event production
    events := make(chan Event, 100)
    
    // Producer goroutine - fetches events and sends to channel
    go func() {
        defer close(events) // Ensure channel is closed when done
        for {
            select {
            case <-ctx.Done():
                return // Exit on context cancellation
            case event := <-getEvent():
                events <- event // Send event to processing channel
            }
        }
    }()
    
    // Consumer goroutine - processes events from channel
    go func() {
        for {
            select {
            case <-ctx.Done():
                return // Exit on context cancellation
            case event, ok := <-events:
                if !ok {
                    return // Channel closed, exit gracefully
                }
                handleEvent(event) // Process the event
            }
        }
    }()
}
```

### Unbounded Goroutine Creation
Prevent resource exhaustion from too many goroutines:

```go
// ❌ Bad: Unbounded goroutine creation
func processItems(items []Item) {
    for _, item := range items {
        go processItem(item) // Could create millions of goroutines
    }
}

// ✅ Good: Worker pool pattern
func processItems(items []Item, numWorkers int) {
    itemChan := make(chan Item, len(items))
    
    // Start fixed number of workers
    var wg sync.WaitGroup
    for i := 0; i < numWorkers; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            for item := range itemChan {
                processItem(item)
            }
        }()
    }
    
    // Send items to workers
    for _, item := range items {
        itemChan <- item
    }
    close(itemChan)
    
    wg.Wait()
}

// ✅ Better: Semaphore pattern for dynamic workloads
type Semaphore chan struct{}

func NewSemaphore(n int) Semaphore {
    return make(Semaphore, n)
}

func (s Semaphore) Acquire() { s <- struct{}{} }
func (s Semaphore) Release() { <-s }

func processItemsWithSemaphore(items []Item, maxConcurrency int) {
    sem := NewSemaphore(maxConcurrency)
    var wg sync.WaitGroup
    
    for _, item := range items {
        wg.Add(1)
        go func(item Item) {
            defer wg.Done()
            sem.Acquire()
            defer sem.Release()
            
            processItem(item)
        }(item)
    }
    
    wg.Wait()
}
```

### Ignoring Context Cancellation
Always respect context cancellation in long-running operations:

```go
// ❌ Bad: Ignoring context cancellation
func longRunningOperation(ctx context.Context, data []Item) error {
    for _, item := range data {
        // This could run for hours, ignoring cancellation
        processItem(item)
    }
    return nil
}

// ✅ Good: Checking context regularly
func longRunningOperation(ctx context.Context, data []Item) error {
    for i, item := range data {
        select {
        case <-ctx.Done():
            return ctx.Err()
        default:
        }
        
        if err := processItem(item); err != nil {
            return err
        }
        
        // Check context every 100 items for efficiency
        if i%100 == 0 {
            if ctx.Err() != nil {
                return ctx.Err()
            }
        }
    }
    return nil
}
```

## Interface Anti-patterns

### Over-abstraction
Avoid unnecessary interfaces that add complexity without benefit:

```go
// ❌ Bad: Over-abstracted interface for simple operations
type StringProcessor interface {
    ProcessString(s string) string
    ValidateString(s string) bool
    TransformString(s string) string
    FormatString(s string) string
}

type EmailStringProcessor struct{}

func (e EmailStringProcessor) ProcessString(s string) string {
    return strings.ToLower(s)
}

func (e EmailStringProcessor) ValidateString(s string) bool {
    return strings.Contains(s, "@")
}

func (e EmailStringProcessor) TransformString(s string) string {
    return strings.TrimSpace(s)
}

func (e EmailStringProcessor) FormatString(s string) string {
    return strings.ToLower(strings.TrimSpace(s))
}

// ✅ Good: Simple, focused functions
func normalizeEmail(email string) string {
    return strings.ToLower(strings.TrimSpace(email))
}

func isValidEmail(email string) bool {
    return strings.Contains(email, "@") // Simplified for example
}
```

### Fat Interfaces
Keep interfaces small and focused:

```go
// ❌ Bad: Fat interface violating Interface Segregation Principle
type UserService interface {
    CreateUser(user *User) error
    UpdateUser(user *User) error
    DeleteUser(id string) error
    GetUser(id string) (*User, error)
    ListUsers() ([]*User, error)
    SendEmail(userID string, message string) error
    LogActivity(userID string, activity string) error
    ValidatePermissions(userID string, resource string) bool
    GenerateReport(userID string) (*Report, error)
    ExportData(userID string) ([]byte, error)
}

// ✅ Good: Segregated interfaces
type UserRepository interface {
    Create(user *User) error
    Update(user *User) error
    Delete(id string) error
    GetByID(id string) (*User, error)
    List() ([]*User, error)
}

type EmailService interface {
    SendEmail(userID string, message string) error
}

type AuditService interface {
    LogActivity(userID string, activity string) error
}

type PermissionService interface {
    ValidatePermissions(userID string, resource string) bool
}
```

### Interface Pollution
Don't create interfaces just because you can:

```go
// ❌ Bad: Unnecessary interface for concrete type
type DatabaseConfig interface {
    GetHost() string
    GetPort() int
    GetDatabase() string
    GetUser() string
    GetPassword() string
}

type Config struct {
    host     string
    port     int
    database string
    user     string
    password string
}

// ✅ Good: Use struct directly when no abstraction is needed
type DatabaseConfig struct {
    Host     string
    Port     int
    Database string
    User     string
    Password string
}

// Interface only when you have multiple implementations
type ConnectionProvider interface {
    GetConnection() (*sql.DB, error)
}
```

## Error Handling Anti-patterns

### Ignoring Errors
Never ignore errors without explicit justification:

```go
// ❌ Bad: Ignoring errors
func processFile(filename string) {
    data, _ := os.ReadFile(filename)
    json.Unmarshal(data, &result)
    writeResult(result)
}

// ✅ Good: Proper error handling
func processFile(filename string) error {
    data, err := os.ReadFile(filename)
    if err != nil {
        return fmt.Errorf("read file %s: %w", filename, err)
    }
    
    var result Result
    if err := json.Unmarshal(data, &result); err != nil {
        return fmt.Errorf("unmarshal data from %s: %w", filename, err)
    }
    
    if err := writeResult(result); err != nil {
        return fmt.Errorf("write result: %w", err)
    }
    
    return nil
}
```

### Poor Error Wrapping
Provide context without losing original error information:

```go
// ❌ Bad: Losing original error context
func processUser(userID string) error {
    user, err := getUser(userID)
    if err != nil {
        return errors.New("failed to process user")
    }
    
    if err := updateUser(user); err != nil {
        return errors.New("user processing failed")
    }
    
    return nil
}

// ✅ Good: Preserving error context with wrapping
func processUser(userID string) error {
    user, err := getUser(userID)
    if err != nil {
        return fmt.Errorf("get user %s: %w", userID, err)
    }
    
    if err := updateUser(user); err != nil {
        return fmt.Errorf("update user %s: %w", userID, err)
    }
    
    return nil
}
```

### Panic Misuse
Use panic only for truly unrecoverable situations:

```go
// ❌ Bad: Using panic for expected errors
func divideNumbers(a, b float64) float64 {
    if b == 0 {
        panic("division by zero") // This is an expected error condition
    }
    return a / b
}

// ✅ Good: Return errors for expected failure conditions
func divideNumbers(a, b float64) (float64, error) {
    if b == 0 {
        return 0, errors.New("division by zero")
    }
    return a / b, nil
}

// ✅ Acceptable: Panic for programming errors during initialization
func init() {
    config, err := loadConfig()
    if err != nil {
        panic(fmt.Sprintf("failed to load config: %v", err))
    }
    globalConfig = config
}
```

## Performance Anti-patterns

### Premature Optimization
Focus on correctness first, then optimize based on measurements:

```go
// ❌ Bad: Complex optimization without measurement
func findUserOptimized(users []User, id string) *User {
    // Complex hash-based lookup assuming it's faster
    lookup := make(map[string]*User, len(users))
    for i := range users {
        lookup[users[i].ID] = &users[i]
    }
    return lookup[id]
}

// ✅ Good: Simple, correct implementation first
func findUser(users []User, id string) *User {
    for i := range users {
        if users[i].ID == id {
            return &users[i]
        }
    }
    return nil
}

// ✅ Optimize only after profiling shows it's a bottleneck
func findUserOptimized(users []User, id string) *User {
    // Only optimize if profiling shows this is a hot path
    // and the slice is consistently large
    if len(users) > 1000 {
        return findUserWithMap(users, id)
    }
    return findUser(users, id)
}
```

### Unnecessary Allocations
Avoid allocations in hot paths:

```go
// ❌ Bad: Unnecessary string concatenation in loop
func buildMessage(items []string) string {
    message := ""
    for _, item := range items {
        message += item + ", " // Creates new string each iteration
    }
    return message
}

// ✅ Good: Use strings.Builder for efficient concatenation
func buildMessage(items []string) string {
    var builder strings.Builder
    builder.Grow(len(items) * 10) // Pre-allocate estimated capacity
    
    for i, item := range items {
        if i > 0 {
            builder.WriteString(", ")
        }
        builder.WriteString(item)
    }
    return builder.String()
}

// ❌ Bad: Converting between []byte and string repeatedly
func processData(data []byte) string {
    s := string(data) // Allocation
    s = strings.ToUpper(s)
    s = strings.TrimSpace(s)
    return s
}

// ✅ Good: Work with bytes when possible
func processData(data []byte) []byte {
    result := make([]byte, 0, len(data))
    
    // Skip leading whitespace
    start := 0
    for start < len(data) && isWhitespace(data[start]) {
        start++
    }
    
    // Skip trailing whitespace
    end := len(data)
    for end > start && isWhitespace(data[end-1]) {
        end--
    }
    
    // Convert to uppercase
    for i := start; i < end; i++ {
        result = append(result, toUpper(data[i]))
    }
    
    return result
}
```

## Security Anti-patterns

### Hardcoded Secrets
Never embed secrets in source code:

```go
// ❌ Bad: Hardcoded secrets
const (
    APIKey    = "sk-1234567890abcdef"
    DBPassword = "super_secret_password"
)

func connectToDatabase() *sql.DB {
    dsn := fmt.Sprintf("user=admin password=%s host=localhost dbname=myapp", DBPassword)
    db, _ := sql.Open("postgres", dsn)
    return db
}

// ✅ Good: Load secrets from environment or secret manager
type Config struct {
    APIKey     string
    DBPassword string
}

func loadConfig() (*Config, error) {
    config := &Config{}
    
    config.APIKey = os.Getenv("API_KEY")
    if config.APIKey == "" {
        return nil, errors.New("API_KEY environment variable required")
    }
    
    config.DBPassword = os.Getenv("DB_PASSWORD")
    if config.DBPassword == "" {
        return nil, errors.New("DB_PASSWORD environment variable required")
    }
    
    return config, nil
}
```

### SQL Injection Vulnerabilities
Always use parameterized queries:

```go
// ❌ Bad: SQL injection vulnerability
func getUserByName(db *sql.DB, name string) (*User, error) {
    query := fmt.Sprintf("SELECT id, name, email FROM users WHERE name = '%s'", name)
    row := db.QueryRow(query)
    
    var user User
    err := row.Scan(&user.ID, &user.Name, &user.Email)
    return &user, err
}

// ✅ Good: Parameterized queries
func getUserByName(db *sql.DB, name string) (*User, error) {
    query := "SELECT id, name, email FROM users WHERE name = $1"
    row := db.QueryRow(query, name)
    
    var user User
    err := row.Scan(&user.ID, &user.Name, &user.Email)
    return &user, err
}
```

### Inadequate Input Validation
Validate all external input:

```go
// ❌ Bad: No input validation
func createUser(w http.ResponseWriter, r *http.Request) {
    var user User
    json.NewDecoder(r.Body).Decode(&user)
    
    // Direct use without validation
    saveUser(&user)
    
    w.WriteHeader(http.StatusCreated)
    json.NewEncoder(w).Encode(user)
}

// ✅ Good: Comprehensive input validation
func createUser(w http.ResponseWriter, r *http.Request) {
    var user User
    if err := json.NewDecoder(r.Body).Decode(&user); err != nil {
        http.Error(w, "Invalid JSON", http.StatusBadRequest)
        return
    }
    
    if err := validateUser(&user); err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }
    
    // Sanitize input
    user.Name = sanitizeString(user.Name)
    user.Email = sanitizeEmail(user.Email)
    
    if err := saveUser(&user); err != nil {
        http.Error(w, "Internal server error", http.StatusInternalServerError)
        return
    }
    
    w.WriteHeader(http.StatusCreated)
    json.NewEncoder(w).Encode(user)
}

func validateUser(user *User) error {
    if user.Name == "" {
        return errors.New("name is required")
    }
    
    if len(user.Name) > 100 {
        return errors.New("name too long")
    }
    
    if !isValidEmail(user.Email) {
        return errors.New("invalid email format")
    }
    
    return nil
}
```

## Testing Anti-patterns

### Brittle Tests
Write maintainable tests that don't break on minor changes:

```go
// ❌ Bad: Brittle test that checks exact string matches
func TestUserString(t *testing.T) {
    user := User{ID: "123", Name: "John Doe", Email: "john@example.com"}
    expected := "User{ID: 123, Name: John Doe, Email: john@example.com, CreatedAt: 2023-01-01T00:00:00Z}"
    
    if user.String() != expected {
        t.Errorf("Expected %s, got %s", expected, user.String())
    }
}

// ✅ Good: Test behavior, not exact output format
func TestUserString(t *testing.T) {
    user := User{ID: "123", Name: "John Doe", Email: "john@example.com"}
    result := user.String()
    
    assert.Contains(t, result, "123")
    assert.Contains(t, result, "John Doe")
    assert.Contains(t, result, "john@example.com")
    assert.NotEmpty(t, result)
}
```

### Testing Implementation Instead of Behavior
Focus on what the code does, not how it does it:

```go
// ❌ Bad: Testing internal implementation details
func TestUserService_CreateUser(t *testing.T) {
    mockRepo := &MockRepository{}
    mockEmail := &MockEmailService{}
    service := NewUserService(mockRepo, mockEmail)
    
    user := &User{Name: "Alice", Email: "alice@example.com"}
    
    // Testing exact method call order and parameters
    mockRepo.On("Save", mock.MatchedBy(func(u *User) bool {
        return u.ID != "" && u.CreatedAt.After(time.Now().Add(-time.Second))
    })).Return(nil).Once()
    
    mockEmail.On("SendWelcomeEmail", "alice@example.com").Return(nil).Once()
    
    result, err := service.CreateUser(user)
    
    assert.NoError(t, err)
    assert.NotNil(t, result)
    mockRepo.AssertExpectations(t)
    mockEmail.AssertExpectations(t)
}

// ✅ Good: Testing behavior and outcomes
func TestUserService_CreateUser(t *testing.T) {
    mockRepo := &MockRepository{}
    mockEmail := &MockEmailService{}
    service := NewUserService(mockRepo, mockEmail)
    
    user := &User{Name: "Alice", Email: "alice@example.com"}
    
    // Focus on behavior: user gets saved, email gets sent
    mockRepo.On("Save", mock.AnythingOfType("*User")).Return(nil)
    mockEmail.On("SendWelcomeEmail", user.Email).Return(nil)
    
    result, err := service.CreateUser(user)
    
    // Test the observable outcomes
    assert.NoError(t, err)
    assert.NotEmpty(t, result.ID)
    assert.Equal(t, "Alice", result.Name)
    assert.Equal(t, "alice@example.com", result.Email)
    assert.False(t, result.CreatedAt.IsZero())
    
    mockRepo.AssertCalled(t, "Save", mock.AnythingOfType("*User"))
    mockEmail.AssertCalled(t, "SendWelcomeEmail", user.Email)
}
```

## Documentation Anti-patterns

### Missing or Poor Documentation
Always document exported types and functions properly:

```go
// ❌ Bad: No documentation
func ProcessUser(id string) error {
    return nil
}

type User struct {
    ID   string
    Name string
}

var ErrNotFound = errors.New("not found")

// ❌ Bad: Poor documentation that doesn't follow conventions
// this function does user processing
func ProcessUserData(id string) error {
    return nil
}

// ❌ Bad: Documentation doesn't start with function name
// Does user validation and returns true if valid
func ValidateUser(user *User) bool {
    return user.Name != ""
}

// ✅ Good: Proper documentation following linter conventions
// ProcessUser processes a user by their unique identifier.
// Returns error if user is not found or processing fails.
func ProcessUser(id string) error {
    // Validate input parameter
    if id == "" {
        return errors.New("user ID is required")
    }
    
    // Fetch user from repository
    user, err := getUserByID(id)
    if err != nil {
        return fmt.Errorf("failed to get user %s: %w", id, err)
    }
    
    // Process user data
    return processUserData(user)
}

// User represents a system user with authentication information.
// All fields are validated during creation and updates.
type User struct {
    // ID is the unique identifier for the user
    ID string `json:"id"`
    
    // Name is the user's display name (required)
    Name string `json:"name"`
}

// ErrUserNotFound is returned when a user lookup operation fails to find the requested user.
var ErrUserNotFound = errors.New("user not found")

// ValidateUser performs validation on a User instance.
// Returns true if all required fields are present and valid.
func ValidateUser(user *User) bool {
    // Check required fields
    if user.Name == "" {
        return false
    }
    
    if user.ID == "" {
        return false
    }
    
    return true
}
```

### Inconsistent Comment Styles
Maintain consistent documentation throughout codebase:

```go
// ❌ Bad: Inconsistent comment styles
/* ProcessOrder handles order processing */
func ProcessOrder(order *Order) error { return nil }

// processes payment
func ProcessPayment(payment *Payment) error { return nil }

// Validates the user input
func ValidateInput(input string) bool { return true }

// ✅ Good: Consistent documentation style
// ProcessOrder processes an order through the fulfillment pipeline.
// Returns error if validation fails or processing encounters issues.
func ProcessOrder(order *Order) error {
    // Validate order structure
    if err := order.Validate(); err != nil {
        return fmt.Errorf("invalid order: %w", err)
    }
    
    return nil
}

// ProcessPayment handles payment processing for the given payment request.
// Returns error if payment fails or validation errors occur.
func ProcessPayment(payment *Payment) error {
    // Validate payment details
    if payment.Amount <= 0 {
        return errors.New("payment amount must be positive")
    }
    
    return nil
}

// ValidateInput checks if the provided input meets validation criteria.
// Returns true if input is valid according to business rules.
func ValidateInput(input string) bool {
    // Check for empty input
    if strings.TrimSpace(input) == "" {
        return false
    }
    
    return true
}
```

## Package Design Anti-patterns

### Circular Dependencies
Avoid circular imports by proper dependency management:

```go
// ❌ Bad: Circular dependency
// package user
import "myapp/notification"

type User struct {
    ID   string
    Name string
}

func (u *User) SendNotification(msg string) error {
    return notification.Send(u.ID, msg)
}

// package notification  
import "myapp/user" // Circular import!

func Send(userID string, message string) error {
    user := user.GetByID(userID) // This creates circular dependency
    return sendEmail(user.Email, message)
}

// ✅ Good: Break circular dependency with interfaces or shared types
// package types
type User struct {
    ID    string
    Name  string
    Email string
}

// package user
import (
    "myapp/types"
    "myapp/notification"
)

func GetByID(id string) (*types.User, error) {
    // Implementation
}

func (u *User) SendNotification(msg string) error {
    return notification.Send(u.ID, u.Email, msg)
}

// package notification
import "myapp/types"

func Send(userID, email, message string) error {
    return sendEmail(email, message)
}
```

### God Packages
Keep packages focused and cohesive:

```go
// ❌ Bad: God package with too many responsibilities
// package utils
func ValidateEmail(email string) bool { /* ... */ }
func HashPassword(password string) string { /* ... */ }
func ConnectDatabase() *sql.DB { /* ... */ }
func SendEmail(to, subject, body string) error { /* ... */ }
func GenerateReport() *Report { /* ... */ }
func ProcessPayment(amount float64) error { /* ... */ }
func LogMessage(level, message string) { /* ... */ }

// ✅ Good: Focused packages with clear responsibilities
// package validation
func Email(email string) bool { /* ... */ }
func Password(password string) error { /* ... */ }

// package crypto
func HashPassword(password string) string { /* ... */ }
func GenerateToken() string { /* ... */ }

// package database
func Connect(dsn string) (*sql.DB, error) { /* ... */ }

// package email
func Send(to, subject, body string) error { /* ... */ }

// package reports
func Generate(userID string) (*Report, error) { /* ... */ }
```

For proper error handling patterns, see [Idiomatic Basics](idiomatic-basics.md). For security best practices, see [Security Input](security-input.md) and [Security Crypto](security-crypto.md). For performance optimization guidelines, see [Performance Optimization](performance-optimization.md). For proper testing patterns, see [Testing Strategies](testing-strategies.md).