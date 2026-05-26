# Testing Strategies

*Senior-level testing patterns for Go 1.26.x enterprise applications*

## Table-Driven Tests

### Comprehensive Test Tables
Structure complex test scenarios with clear organization:

```go
import (
    "testing"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestUserValidation(t *testing.T) {
    tests := []struct {
        name    string
        user    User
        wantErr bool
        errMsg  string
    }{
        {
            name: "valid user",
            user: User{
                ID:    "user123",
                Name:  "John Doe",
                Email: "john@example.com",
                Age:   25,
            },
            wantErr: false,
        },
        {
            name: "missing email",
            user: User{
                ID:   "user123",
                Name: "John Doe",
                Age:  25,
            },
            wantErr: true,
            errMsg:  "email is required",
        },
        {
            name: "invalid age",
            user: User{
                ID:    "user123",
                Name:  "John Doe",
                Email: "john@example.com",
                Age:   -1,
            },
            wantErr: true,
            errMsg:  "age must be positive",
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel() // Run subtests in parallel for faster execution
            
            err := ValidateUser(tt.user)
            
            if tt.wantErr {
                require.Error(t, err)
                assert.Contains(t, err.Error(), tt.errMsg)
            } else {
                assert.NoError(t, err)
            }
        })
    }
}
```

### Advanced Table Patterns
Handle complex scenarios with setup and cleanup:

```go
func TestDatabaseOperations(t *testing.T) {
    tests := []struct {
        name     string
        setup    func(db *sql.DB) error
        operation func(db *sql.DB) error
        validate func(t *testing.T, db *sql.DB)
        cleanup  func(db *sql.DB) error
        wantErr  bool
    }{
        {
            name: "create user successfully",
            setup: func(db *sql.DB) error {
                return createUsersTable(db)
            },
            operation: func(db *sql.DB) error {
                user := &User{ID: "1", Name: "Alice"}
                return CreateUser(db, user)
            },
            validate: func(t *testing.T, db *sql.DB) {
                var count int
                db.QueryRow("SELECT COUNT(*) FROM users").Scan(&count)
                assert.Equal(t, 1, count)
            },
            cleanup: func(db *sql.DB) error {
                _, err := db.Exec("DROP TABLE users")
                return err
            },
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Note: Don't use t.Parallel() here since database operations may conflict
            
            db := setupTestDB(t)
            defer db.Close()
            
            if tt.setup != nil {
                require.NoError(t, tt.setup(db))
            }
            
            defer func() {
                if tt.cleanup != nil {
                    tt.cleanup(db)
                }
            }()
            
            err := tt.operation(db)
            
            if tt.wantErr {
                assert.Error(t, err)
            } else {
                require.NoError(t, err)
                if tt.validate != nil {
                    tt.validate(t, db)
                }
            }
        })
    }
}
```

## Test Fixtures and Setup

### Test Suite Patterns
Organize related tests with shared setup:

```go
import (
    "testing"
    "github.com/stretchr/testify/suite"
)

type UserServiceSuite struct {
    suite.Suite
    service    *UserService
    repository *MockUserRepository
    notifier   *MockNotifier
}

func (suite *UserServiceSuite) SetupTest() {
    suite.repository = &MockUserRepository{}
    suite.notifier = &MockNotifier{}
    suite.service = NewUserService(suite.repository, suite.notifier)
}

func (suite *UserServiceSuite) TearDownTest() {
    // Cleanup after each test
    suite.repository.Reset()
    suite.notifier.Reset()
}

func (suite *UserServiceSuite) TestCreateUser() {
    user := &User{Name: "Alice", Email: "alice@example.com"}
    
    suite.repository.On("Save", mock.Anything).Return(nil)
    suite.notifier.On("SendWelcome", user.Email).Return(nil)
    
    result, err := suite.service.CreateUser(user)
    
    suite.NoError(err)
    suite.NotNil(result)
    suite.repository.AssertExpectations(suite.T())
    suite.notifier.AssertExpectations(suite.T())
}

func TestUserServiceSuite(t *testing.T) {
    suite.Run(t, new(UserServiceSuite))
}
```

### Fixture Management
Create reusable test data:

```go
// fixtures.go
package testdata

var (
    ValidUser = User{
        ID:    "user-123",
        Name:  "John Doe",
        Email: "john@example.com",
        Age:   30,
    }
    
    AdminUser = User{
        ID:    "admin-456",
        Name:  "Admin User",
        Email: "admin@example.com",
        Age:   35,
        Role:  "admin",
    }
    
    ExpiredToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
)

func CreateTestUsers(count int) []User {
    users := make([]User, count)
    for i := 0; i < count; i++ {
        users[i] = User{
            ID:    fmt.Sprintf("user-%d", i),
            Name:  fmt.Sprintf("User %d", i),
            Email: fmt.Sprintf("user%d@example.com", i),
            Age:   20 + i,
        }
    }
    return users
}
```

## Mock and Stub Strategies

### Mockery Integration
Use vektra/mockery to generate type-safe mocks automatically:

```bash
# Install mockery
go install github.com/vektra/mockery/v2@latest

# Generate mocks for interfaces
//go:generate mockery --name UserRepository --output mocks
```

```go
// UserRepository interface
type UserRepository interface {
    Save(user *User) error
    FindByID(id string) (*User, error)
    Delete(id string) error
}

// Generated mock (mocks/UserRepository.go) - created by mockery
// type MockUserRepository struct {
//     mock.Mock
// }
// ... (auto-generated methods)
```

```go
import (
    "testing"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/mock"
    "myapp/mocks"
)

func TestUserService_CreateUser(t *testing.T) {
    t.Parallel() // Safe to run in parallel since we use mocks
    
    repo := mocks.NewMockUserRepository(t)
    service := NewUserService(repo)
    
    user := &User{Name: "Alice"}
    
    // Setup expectations with type safety
    repo.EXPECT().Save(mock.MatchedBy(func(u *User) bool {
        return u.Name == "Alice" && u.ID != ""
    })).Return(nil).Once()
    
    result, err := service.CreateUser(user)
    
    assert.NoError(t, err)
    assert.NotEmpty(t, result.ID)
    // Mockery handles assertion automatically
}
```

### Mockery Configuration
Configure mockery with `.mockery.yaml`:

```yaml
# .mockery.yaml
with-expecter: true
output: "mocks"
outpkg: "mocks"
mockname: "Mock{{.InterfaceName}}"
filename: "{{.MockName}}.go"
inpackage: false
testonly: false
packages:
  github.com/mycompany/myapp/internal/domain:
    interfaces:
      UserRepository:
      EmailService:
      PaymentGateway:
```

### Interface-Based Testing with Mockery
Design testable interfaces and generate mocks:

```go
// Testable HTTP client interface
//go:generate mockery --name HTTPClient --output mocks
type HTTPClient interface {
    Do(req *http.Request) (*http.Response, error)
}

type APIClient struct {
    client  HTTPClient
    baseURL string
}

func NewAPIClient(client HTTPClient, baseURL string) *APIClient {
    return &APIClient{
        client:  client,
        baseURL: baseURL,
    }
}

func TestAPIClient_GetUser(t *testing.T) {
    t.Parallel() // Safe to run in parallel with mocks
    
    mockClient := mocks.NewMockHTTPClient(t)
    apiClient := NewAPIClient(mockClient, "https://api.example.com")
    
    response := &http.Response{
        StatusCode: 200,
        Body:       io.NopCloser(strings.NewReader(`{"id":"123","name":"Alice"}`)),
    }
    
    // Type-safe expectation with mockery
    mockClient.EXPECT().Do(mock.MatchedBy(func(req *http.Request) bool {
        return req.URL.Path == "/users/123"
    })).Return(response, nil).Once()
    
    user, err := apiClient.GetUser("123")
    
    assert.NoError(t, err)
    assert.Equal(t, "Alice", user.Name)
    // No need to manually assert expectations with mockery
}
```

### Advanced Mock Patterns
Use mockery features for complex scenarios:

```go
func TestUserService_Complex(t *testing.T) {
    t.Parallel()
    
    repo := mocks.NewMockUserRepository(t)
    emailService := mocks.NewMockEmailService(t)
    service := NewUserService(repo, emailService)
    
    user := &User{Name: "Alice", Email: "alice@example.com"}
    
    // Chain expectations
    repo.EXPECT().Save(mock.AnythingOfType("*User")).Return(nil).Once()
    
    // Conditional mock behavior
    emailService.EXPECT().SendWelcomeEmail(user.Email).Return(nil).Maybe()
    
    // Mock with callback
    repo.EXPECT().FindByEmail(user.Email).RunAndReturn(
        func(email string) (*User, error) {
            return &User{ID: "123", Email: email}, nil
        }).Once()
    
    result, err := service.CreateUser(user)
    
    assert.NoError(t, err)
    assert.NotNil(t, result)
}

## Integration Testing

### Testcontainers Integration
Test with real dependencies using containers:

```go
import (
    "context"
    "database/sql"
    "testing"
    
    "github.com/testcontainers/testcontainers-go"
    "github.com/testcontainers/testcontainers-go/wait"
    _ "github.com/lib/pq"
)

func setupPostgresContainer(t *testing.T) (string, func()) {
    ctx := context.Background()
    
    req := testcontainers.ContainerRequest{
        Image:        "postgres:15",
        ExposedPorts: []string{"5432/tcp"},
        Env: map[string]string{
            "POSTGRES_DB":       "testdb",
            "POSTGRES_USER":     "testuser",
            "POSTGRES_PASSWORD": "testpass",
        },
        WaitingFor: wait.ForLog("database system is ready to accept connections").
            WithOccurrence(2),
    }
    
    container, err := testcontainers.GenericContainer(ctx, testcontainers.GenericContainerRequest{
        ContainerRequest: req,
        Started:          true,
    })
    require.NoError(t, err)
    
    port, err := container.MappedPort(ctx, "5432")
    require.NoError(t, err)
    
    host, err := container.Host(ctx)
    require.NoError(t, err)
    
    dsn := fmt.Sprintf("postgres://testuser:testpass@%s:%s/testdb?sslmode=disable",
        host, port.Port())
    
    cleanup := func() {
        container.Terminate(ctx)
    }
    
    return dsn, cleanup
}

func TestUserRepository_Integration(t *testing.T) {
    // Integration tests should not use t.Parallel() at the top level
    // to avoid resource conflicts between containers
    
    dsn, cleanup := setupPostgresContainer(t)
    defer cleanup()
    
    db, err := sql.Open("postgres", dsn)
    require.NoError(t, err)
    defer db.Close()
    
    // Run migrations
    err = runMigrations(db)
    require.NoError(t, err)
    
    repo := NewUserRepository(db)
    
    t.Run("create and retrieve user", func(t *testing.T) {
        // Can use t.Parallel() here if each subtest uses isolated data
        t.Parallel()
        
        user := &User{
            Name:  "Alice",
            Email: "alice@example.com",
        }
        
        err := repo.Save(user)
        require.NoError(t, err)
        assert.NotEmpty(t, user.ID)
        
        retrieved, err := repo.FindByID(user.ID)
        require.NoError(t, err)
        assert.Equal(t, user.Name, retrieved.Name)
        assert.Equal(t, user.Email, retrieved.Email)
    })
    
    t.Run("update user", func(t *testing.T) {
        t.Parallel()
        
        user := &User{
            Name:  "Bob",
            Email: "bob@example.com",
        }
        
        err := repo.Save(user)
        require.NoError(t, err)
        
        user.Name = "Robert"
        err = repo.Update(user)
        require.NoError(t, err)
        
        updated, err := repo.FindByID(user.ID)
        require.NoError(t, err)
        assert.Equal(t, "Robert", updated.Name)
    })
}
```

## Benchmark Testing

### Performance Benchmarks with Memory Analysis
Measure both CPU and memory performance:

```go
func BenchmarkUserProcessing(b *testing.B) {
    users := createTestUsers(1000)
    
    b.ResetTimer()
    b.ReportAllocs()
    
    for i := 0; i < b.N; i++ {
        processUsers(users)
    }
}

func BenchmarkUserProcessingParallel(b *testing.B) {
    users := createTestUsers(1000)
    
    b.ResetTimer()
    b.ReportAllocs()
    
    b.RunParallel(func(pb *testing.PB) {
        for pb.Next() {
            processUsersParallel(users)
        }
    })
}

// Sub-benchmarks for different scenarios
func BenchmarkJSONProcessing(b *testing.B) {
    data := generateTestData(1000)
    
    benchmarks := []struct {
        name string
        fn   func([]byte) error
    }{
        {"stdlib", processWithStdlib},
        {"jsoniter", processWithJsoniter},
        {"sonic", processWithSonic},
    }
    
    for _, bm := range benchmarks {
        b.Run(bm.name, func(b *testing.B) {
            b.ReportAllocs()
            // Benchmarks can use RunParallel for CPU-bound operations
            b.RunParallel(func(pb *testing.PB) {
                for pb.Next() {
                    bm.fn(data)
                }
            })
        })
    }
}
```

## Testing Concurrent Code

### Goroutine Safety Testing
Test concurrent code with race detection:

```go
func TestConcurrentCache(t *testing.T) {
    cache := NewCache()
    const numGoroutines = 100
    const numOperations = 1000
    
    var wg sync.WaitGroup
    
    // Test concurrent writes
    for i := 0; i < numGoroutines; i++ {
        wg.Add(1)
        go func(id int) {
            defer wg.Done()
            for j := 0; j < numOperations; j++ {
                key := fmt.Sprintf("key-%d-%d", id, j)
                cache.Set(key, fmt.Sprintf("value-%d-%d", id, j))
            }
        }(i)
    }
    
    // Test concurrent reads
    for i := 0; i < numGoroutines; i++ {
        wg.Add(1)
        go func(id int) {
            defer wg.Done()
            for j := 0; j < numOperations; j++ {
                key := fmt.Sprintf("key-%d-%d", id, j)
                _, _ = cache.Get(key)
            }
        }(i)
    }
    
    wg.Wait()
    
    // Verify final state
    assert.Equal(t, numGoroutines*numOperations, cache.Size())
}

// Test with artificial delays to catch timing issues
func TestConcurrentWithDelay(t *testing.T) {
    service := NewUserService()
    
    var wg sync.WaitGroup
    results := make(chan error, 10)
    
    for i := 0; i < 10; i++ {
        wg.Add(1)
        go func(id int) {
            defer wg.Done()
            
            // Add artificial delay
            time.Sleep(time.Duration(rand.Intn(10)) * time.Millisecond)
            
            user := &User{
                ID:   fmt.Sprintf("user-%d", id),
                Name: fmt.Sprintf("User %d", id),
            }
            
            err := service.CreateUser(user)
            results <- err
        }(i)
    }
    
    wg.Wait()
    close(results)
    
    for err := range results {
        assert.NoError(t, err)
    }
}
```

## API Testing Patterns

### HTTP Service Testing
Test HTTP handlers and middleware:

```go
import (
    "net/http"
    "net/http/httptest"
    "strings"
)

func TestUserHandler(t *testing.T) {
    tests := []struct {
        name           string
        method         string
        path           string
        body           string
        setupMock      func(*MockUserService)
        expectedStatus int
        expectedBody   string
    }{
        {
            name:   "create user success",
            method: "POST",
            path:   "/users",
            body:   `{"name":"Alice","email":"alice@example.com"}`,
            setupMock: func(mock *MockUserService) {
                mock.On("CreateUser", mock.AnythingOfType("*User")).
                    Return(&User{ID: "123", Name: "Alice"}, nil)
            },
            expectedStatus: 201,
            expectedBody:   `{"id":"123","name":"Alice"}`,
        },
        {
            name:   "create user validation error",
            method: "POST",
            path:   "/users",
            body:   `{"name":"","email":"invalid"}`,
            setupMock: func(mock *MockUserService) {
                mock.On("CreateUser", mock.AnythingOfType("*User")).
                    Return(nil, errors.New("validation failed"))
            },
            expectedStatus: 400,
            expectedBody:   `{"error":"validation failed"}`,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel() // HTTP handler tests can run in parallel
            
            mockService := mocks.NewMockUserService(t)
            if tt.setupMock != nil {
                tt.setupMock(mockService)
            }
            
            handler := NewUserHandler(mockService)
            
            req := httptest.NewRequest(tt.method, tt.path, strings.NewReader(tt.body))
            req.Header.Set("Content-Type", "application/json")
            
            rr := httptest.NewRecorder()
            handler.ServeHTTP(rr, req)
            
            assert.Equal(t, tt.expectedStatus, rr.Code)
            
            if tt.expectedBody != "" {
                assert.JSONEq(t, tt.expectedBody, rr.Body.String())
            }
            
            // Mockery handles expectations automatically
        })
    }
}
```

## Security Testing Integration

### Input Validation Testing
Test security boundaries and edge cases:

```go
func TestInputValidation(t *testing.T) {
    securityTests := []struct {
        name    string
        input   string
        wantErr bool
        errType error
    }{
        {
            name:    "SQL injection attempt",
            input:   "'; DROP TABLE users; --",
            wantErr: true,
            errType: ErrMaliciousInput,
        },
        {
            name:    "XSS attempt",
            input:   "<script>alert('xss')</script>",
            wantErr: true,
            errType: ErrMaliciousInput,
        },
        {
            name:    "Command injection",
            input:   "test; rm -rf /",
            wantErr: true,
            errType: ErrMaliciousInput,
        },
        {
            name:    "Valid input",
            input:   "John Doe",
            wantErr: false,
        },
    }

    for _, tt := range securityTests {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel() // Security tests can run in parallel
            
            err := ValidateUserInput(tt.input)
            
            if tt.wantErr {
                assert.Error(t, err)
                if tt.errType != nil {
                    assert.ErrorIs(t, err, tt.errType)
                }
            } else {
                assert.NoError(t, err)
            }
        })
    }
}
```

## Test Parallelization Best Practices

### When to Use t.Parallel()
Maximize test performance with proper parallelization:

```go
func TestPureFunction(t *testing.T) {
    t.Parallel() // ✅ Always use for pure functions
    
    result := Calculate(10, 20)
    assert.Equal(t, 30, result)
}

func TestWithMocks(t *testing.T) {
    t.Parallel() // ✅ Safe with mockery-generated mocks
    
    mockRepo := mocks.NewMockUserRepository(t)
    mockRepo.EXPECT().Save(mock.Anything).Return(nil)
    // ... test code
}

func TestHTTPHandler(t *testing.T) {
    tests := []struct {
        name string
        // ... test cases
    }{
        // ... test data
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel() // ✅ HTTP handlers with mocks
            // ... test code
        })
    }
}

func TestDatabaseOperation(t *testing.T) {
    // ❌ Don't use t.Parallel() at top level for shared resources
    
    t.Run("isolated operation", func(t *testing.T) {
        t.Parallel() // ✅ OK if data is isolated per test
        // ... test with unique test data
    })
}

func TestFileSystem(t *testing.T) {
    // ❌ Don't parallelize if tests modify same files/directories
    
    tmpDir := t.TempDir() // Each test gets unique temp dir
    
    t.Run("create file", func(t *testing.T) {
        t.Parallel() // ✅ OK with unique temp directories
        // ... test code using tmpDir
    })
}
```

### Parallel Testing Guidelines
Follow these rules for safe parallelization:

```go
// ✅ Safe for parallelization:
// - Pure functions without side effects
// - Tests using mocks/stubs
// - Tests with isolated test data
// - HTTP handlers with mock dependencies

// ❌ Avoid parallelization for:
// - Shared database without isolation
// - File system operations on same paths
// - Environment variable modifications
// - Global state mutations
// - External service calls

func TestEnvironmentVariables(t *testing.T) {
    // ❌ Don't parallelize - modifies shared environment
    oldValue := os.Getenv("API_KEY")
    defer os.Setenv("API_KEY", oldValue)
    
    os.Setenv("API_KEY", "test-key")
    // ... test code
}

func TestWithIsolatedEnv(t *testing.T) {
    t.Parallel() // ✅ Use isolation helper
    
    testEnv := setupIsolatedEnvironment(t)
    testEnv.Set("API_KEY", "test-key")
    // ... test code with isolated environment
}
```

## Test Organization

### Large Codebase Testing Strategy
Organize tests for maintainability and speed:

```go
// tests/integration/user_test.go
package integration

func TestUserWorkflow(t *testing.T) {
    skipIntegration(t)
    // End-to-end user lifecycle tests
    // Don't use t.Parallel() for integration tests with shared resources
}

// tests/unit/user_service_test.go  
package unit

func TestUserService(t *testing.T) {
    t.Parallel() // ✅ Unit tests should use parallel execution
    
    tests := []struct {
        name string
        // ... test cases
    }{
        // ... test data
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel() // ✅ Parallel subtests for faster execution
            // ... isolated unit test code
        })
    }
}

// tests/performance/user_benchmark_test.go
package performance

func BenchmarkUserOperations(b *testing.B) {
    b.RunParallel(func(pb *testing.PB) {
        for pb.Next() {
            // ✅ Use RunParallel for CPU-bound benchmarks
            performOperation()
        }
    })
}

// Helper functions for test organization
func skipIntegration(t *testing.T) {
    if testing.Short() {
        t.Skip("Skipping integration test in short mode")
    }
}

func requireDatabase(t *testing.T) {
    if os.Getenv("DATABASE_URL") == "" {
        t.Skip("DATABASE_URL not set, skipping database test")
    }
}

// Test execution optimization
func TestMain(m *testing.M) {
    // Setup shared resources
    setupGlobalTestResources()
    
    // Run tests with parallel execution
    code := m.Run()
    
    // Cleanup
    cleanupGlobalTestResources()
    
    os.Exit(code)
}
```

### Mockery Integration in CI/CD
Automate mock generation in your build pipeline:

```bash
# Makefile
.PHONY: generate-mocks test

generate-mocks:
	@echo "Generating mocks..."
	mockery --config .mockery.yaml
	@echo "✅ Mocks generated successfully"

test: generate-mocks
	@echo "Running tests..."
	go test -race -coverprofile=coverage.out ./...
	@echo "✅ Tests completed"

test-parallel:
	@echo "Running tests with maximum parallelism..."
	go test -race -parallel=8 -coverprofile=coverage.out ./...
	@echo "✅ Parallel tests completed"
```

For concurrent testing patterns, see [Concurrency Basics](concurrency-basics.md). For performance testing strategies, see [Performance Profiling](performance-profiling.md). For security testing integration, see [Security Input](security-input.md) and [Security Crypto](security-crypto.md). For tool configuration including mockery setup, see [Toolchain Configuration](toolchain-configuration.md).