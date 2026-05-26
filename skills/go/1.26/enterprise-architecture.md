# Enterprise Architecture

*Production-ready Go 1.26.x application architecture patterns for enterprise deployment*

## Project Layout

### Standard Project Structure
Follow golang-standards/project-layout for consistency:

```
/cmd
  /myapp
    main.go              # Application entrypoint
/internal               # Private application code
  /app                  # Application layer
  /pkg                  # Internal shared libraries
/pkg                    # Public library code
  /api                  # API definitions (protobuf, OpenAPI)
  /client               # Client SDKs
/api                    # API schema files
/web                    # Web application assets
/configs                # Configuration file templates
/deployments            # System and container orchestration configs
/scripts                # Build, install, analysis scripts
/docs                   # Design and user documentation
/examples               # Examples for library usage
/test                   # Additional external test data
```

### Application Layer Organization
Structure internal packages for maintainability:

```go
// internal/app/app.go
package app

import (
    "context"
    "log/slog"
    "net/http"
    
    "myapp/internal/config"
    "myapp/internal/handler"
    "myapp/internal/service"
    "myapp/internal/repository"
)

// App represents the main application structure containing all dependencies.
// Provides centralized management of services, configuration, and lifecycle.
type App struct {
    // Config holds application configuration loaded from environment
    Config *config.Config
    
    // Logger is the structured logger for application-wide logging
    Logger *slog.Logger
    
    // Server is the HTTP server instance handling incoming requests
    Server *http.Server
    
    // UserSvc provides user-related business operations
    UserSvc service.UserService
    
    // Repository provides data persistence operations
    Repository repository.Repository
}

// New creates a new App instance with all dependencies initialized.
// Performs dependency injection and validates configuration.
// Returns error if any critical dependency fails to initialize.
func New(cfg *config.Config) (*App, error) {
    // Initialize structured logger with JSON format for production
    logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
        Level: slog.LevelInfo,
    }))
    
    // Initialize database repository with connection pooling
    repo, err := repository.New(cfg.DatabaseURL)
    if err != nil {
        return nil, fmt.Errorf("init repository: %w", err)
    }
    
    // Initialize user service with dependencies
    userSvc := service.NewUserService(repo, logger)
    
    // Setup HTTP multiplexer and register all routes
    mux := http.NewServeMux()
    handler.RegisterRoutes(mux, userSvc, logger)
    
    // Configure HTTP server with security timeouts
    server := &http.Server{
        Addr:         cfg.ServerAddr,
        Handler:      mux,
        ReadTimeout:  cfg.ReadTimeout,
        WriteTimeout: cfg.WriteTimeout,
    }
    
    return &App{
        Config:     cfg,
        Logger:     logger,
        Server:     server,
        UserSvc:    userSvc,
        Repository: repo,
    }, nil
}

func (a *App) Start(ctx context.Context) error {
    a.Logger.Info("starting application", "addr", a.Server.Addr)
    
    if err := a.Server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
        return fmt.Errorf("server failed: %w", err)
    }
    
    return nil
}
```

## Logging Patterns

### Structured Logging with Context
Use structured logging for observability:

```go
import (
    "context"
    "log/slog"
    "net/http"
)

type LoggerKey struct{}

// Context-aware logging
func WithLogger(ctx context.Context, logger *slog.Logger) context.Context {
    return context.WithValue(ctx, LoggerKey{}, logger)
}

func LoggerFromContext(ctx context.Context) *slog.Logger {
    if logger, ok := ctx.Value(LoggerKey{}).(*slog.Logger); ok {
        return logger
    }
    return slog.Default()
}

// Request correlation ID middleware
func CorrelationMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        correlationID := r.Header.Get("X-Correlation-ID")
        if correlationID == "" {
            correlationID = generateCorrelationID()
        }
        
        logger := slog.With(
            "correlation_id", correlationID,
            "method", r.Method,
            "path", r.URL.Path,
            "remote_addr", r.RemoteAddr,
        )
        
        ctx := WithLogger(r.Context(), logger)
        r = r.WithContext(ctx)
        
        w.Header().Set("X-Correlation-ID", correlationID)
        
        logger.Info("request started")
        next.ServeHTTP(w, r)
        logger.Info("request completed")
    })
}

// Service-level logging
type UserService struct {
    repository UserRepository
    logger     *slog.Logger
}

func (s *UserService) CreateUser(ctx context.Context, user *User) error {
    logger := LoggerFromContext(ctx).With(
        "operation", "create_user",
        "user_id", user.ID,
    )
    
    logger.Info("creating user", "email", user.Email)
    
    if err := s.repository.Save(ctx, user); err != nil {
        logger.Error("failed to save user", "error", err)
        return fmt.Errorf("save user: %w", err)
    }
    
    logger.Info("user created successfully")
    return nil
}
```

### Log Level Management
Configure appropriate log levels for different environments:

```go
func setupLogger(env string) *slog.Logger {
    var level slog.Level
    var handler slog.Handler
    
    switch env {
    case "production":
        level = slog.LevelInfo
        handler = slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
            Level: level,
            ReplaceAttr: func(groups []string, a slog.Attr) slog.Attr {
                // Remove sensitive fields in production
                if a.Key == "password" || a.Key == "token" {
                    return slog.Attr{}
                }
                return a
            },
        })
    case "development":
        level = slog.LevelDebug
        handler = slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{
            Level: level,
        })
    default:
        level = slog.LevelInfo
        handler = slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
            Level: level,
        })
    }
    
    return slog.New(handler)
}
```

## Monitoring and Observability

### Health Check Patterns
Implement comprehensive health checks:

```go
import (
    "context"
    "database/sql"
    "encoding/json"
    "net/http"
    "time"
)

type HealthStatus string

const (
    HealthStatusUp   HealthStatus = "UP"
    HealthStatusDown HealthStatus = "DOWN"
)

type HealthCheck struct {
    Status    HealthStatus           `json:"status"`
    Timestamp time.Time              `json:"timestamp"`
    Services  map[string]ServiceHealth `json:"services"`
}

type ServiceHealth struct {
    Status  HealthStatus `json:"status"`
    Message string       `json:"message,omitempty"`
    Latency string       `json:"latency,omitempty"`
}

type HealthChecker struct {
    db     *sql.DB
    cache  CacheClient
    logger *slog.Logger
}

func (hc *HealthChecker) Check(ctx context.Context) HealthCheck {
    health := HealthCheck{
        Status:    HealthStatusUp,
        Timestamp: time.Now(),
        Services:  make(map[string]ServiceHealth),
    }
    
    // Check database
    dbHealth := hc.checkDatabase(ctx)
    health.Services["database"] = dbHealth
    if dbHealth.Status == HealthStatusDown {
        health.Status = HealthStatusDown
    }
    
    // Check cache
    cacheHealth := hc.checkCache(ctx)
    health.Services["cache"] = cacheHealth
    if cacheHealth.Status == HealthStatusDown {
        health.Status = HealthStatusDown
    }
    
    return health
}

func (hc *HealthChecker) checkDatabase(ctx context.Context) ServiceHealth {
    start := time.Now()
    
    ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel()
    
    err := hc.db.PingContext(ctx)
    latency := time.Since(start)
    
    if err != nil {
        return ServiceHealth{
            Status:  HealthStatusDown,
            Message: err.Error(),
            Latency: latency.String(),
        }
    }
    
    return ServiceHealth{
        Status:  HealthStatusUp,
        Latency: latency.String(),
    }
}

func (hc *HealthChecker) HTTPHandler() http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        ctx := r.Context()
        health := hc.Check(ctx)
        
        w.Header().Set("Content-Type", "application/json")
        
        if health.Status == HealthStatusDown {
            w.WriteHeader(http.StatusServiceUnavailable)
        }
        
        json.NewEncoder(w).Encode(health)
    }
}
```

### Metrics Collection
Integrate with Prometheus for metrics:

```go
import (
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
    httpRequestsTotal = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Name: "http_requests_total",
            Help: "Total number of HTTP requests",
        },
        []string{"method", "endpoint", "status"},
    )
    
    httpRequestDuration = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "http_request_duration_seconds",
            Help:    "HTTP request duration in seconds",
            Buckets: prometheus.DefBuckets,
        },
        []string{"method", "endpoint"},
    )
    
    activeConnections = promauto.NewGauge(
        prometheus.GaugeOpts{
            Name: "active_connections",
            Help: "Number of active connections",
        },
    )
)

func MetricsMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        
        // Wrap response writer to capture status code
        wrappedWriter := &statusCapturingWriter{ResponseWriter: w, statusCode: 200}
        
        next.ServeHTTP(wrappedWriter, r)
        
        duration := time.Since(start)
        
        httpRequestsTotal.WithLabelValues(
            r.Method,
            r.URL.Path,
            fmt.Sprintf("%d", wrappedWriter.statusCode),
        ).Inc()
        
        httpRequestDuration.WithLabelValues(
            r.Method,
            r.URL.Path,
        ).Observe(duration.Seconds())
    })
}

type statusCapturingWriter struct {
    http.ResponseWriter
    statusCode int
}

func (w *statusCapturingWriter) WriteHeader(code int) {
    w.statusCode = code
    w.ResponseWriter.WriteHeader(code)
}
```

## Configuration Management

### Environment-Based Configuration
Manage configuration across environments:

```go
import (
    "os"
    "strconv"
    "time"
)

type Config struct {
    // Server configuration
    ServerAddr   string
    ReadTimeout  time.Duration
    WriteTimeout time.Duration
    
    // Database configuration
    DatabaseURL      string
    MaxOpenConns     int
    MaxIdleConns     int
    ConnMaxLifetime  time.Duration
    
    // Cache configuration
    CacheURL        string
    CacheExpiration time.Duration
    
    // Security configuration
    JWTSecret       string
    EncryptionKey   []byte
    
    // Feature flags
    FeatureFlags map[string]bool
    
    // External services
    EmailServiceURL string
    APIKey         string
}

func LoadConfig() (*Config, error) {
    config := &Config{
        // Defaults
        ServerAddr:      ":8080",
        ReadTimeout:     30 * time.Second,
        WriteTimeout:    30 * time.Second,
        MaxOpenConns:    25,
        MaxIdleConns:    10,
        ConnMaxLifetime: 5 * time.Minute,
        CacheExpiration: 1 * time.Hour,
        FeatureFlags:    make(map[string]bool),
    }
    
    // Load from environment
    if addr := os.Getenv("SERVER_ADDR"); addr != "" {
        config.ServerAddr = addr
    }
    
    if dbURL := os.Getenv("DATABASE_URL"); dbURL != "" {
        config.DatabaseURL = dbURL
    } else {
        return nil, errors.New("DATABASE_URL is required")
    }
    
    if secret := os.Getenv("JWT_SECRET"); secret != "" {
        config.JWTSecret = secret
    } else {
        return nil, errors.New("JWT_SECRET is required")
    }
    
    // Load numeric values
    if maxConns := os.Getenv("DB_MAX_OPEN_CONNS"); maxConns != "" {
        if val, err := strconv.Atoi(maxConns); err == nil {
            config.MaxOpenConns = val
        }
    }
    
    // Load feature flags
    config.FeatureFlags["new_user_flow"] = getBoolEnv("FEATURE_NEW_USER_FLOW", false)
    config.FeatureFlags["enhanced_logging"] = getBoolEnv("FEATURE_ENHANCED_LOGGING", true)
    
    return config, nil
}

func getBoolEnv(key string, defaultVal bool) bool {
    val := os.Getenv(key)
    if val == "" {
        return defaultVal
    }
    parsed, err := strconv.ParseBool(val)
    if err != nil {
        return defaultVal
    }
    return parsed
}
```

### Secrets Management
Handle sensitive configuration securely:

```go
import (
    "context"
    "encoding/base64"
    "os"
)

type SecretsManager interface {
    GetSecret(ctx context.Context, key string) (string, error)
}

type EnvSecretsManager struct{}

func (e *EnvSecretsManager) GetSecret(ctx context.Context, key string) (string, error) {
    value := os.Getenv(key)
    if value == "" {
        return "", fmt.Errorf("secret %s not found", key)
    }
    return value, nil
}

// For production, use cloud-specific secret managers
type AWSSecretsManager struct {
    // AWS SDK client
}

func (a *AWSSecretsManager) GetSecret(ctx context.Context, key string) (string, error) {
    // Implement AWS Secrets Manager integration
    return "", nil
}

func LoadSecrets(ctx context.Context, sm SecretsManager) (*SecureConfig, error) {
    jwtSecret, err := sm.GetSecret(ctx, "JWT_SECRET")
    if err != nil {
        return nil, fmt.Errorf("load JWT secret: %w", err)
    }
    
    encKeyB64, err := sm.GetSecret(ctx, "ENCRYPTION_KEY")
    if err != nil {
        return nil, fmt.Errorf("load encryption key: %w", err)
    }
    
    encKey, err := base64.StdEncoding.DecodeString(encKeyB64)
    if err != nil {
        return nil, fmt.Errorf("decode encryption key: %w", err)
    }
    
    return &SecureConfig{
        JWTSecret:     jwtSecret,
        EncryptionKey: encKey,
    }, nil
}
```

## Graceful Shutdown

### Signal Handling and Cleanup
Implement graceful shutdown for production reliability:

```go
import (
    "context"
    "os"
    "os/signal"
    "syscall"
    "time"
)

func (a *App) Run(ctx context.Context) error {
    // Create context for graceful shutdown
    ctx, cancel := context.WithCancel(ctx)
    defer cancel()
    
    // Setup signal handling
    sigChan := make(chan os.Signal, 1)
    signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
    
    // Start server in goroutine
    serverErr := make(chan error, 1)
    go func() {
        a.Logger.Info("starting server", "addr", a.Server.Addr)
        serverErr <- a.Server.ListenAndServe()
    }()
    
    // Wait for shutdown signal or server error
    select {
    case sig := <-sigChan:
        a.Logger.Info("received shutdown signal", "signal", sig.String())
        cancel()
    case err := <-serverErr:
        if err != nil && err != http.ErrServerClosed {
            a.Logger.Error("server error", "error", err)
            return err
        }
    }
    
    return a.Shutdown(ctx)
}

func (a *App) Shutdown(ctx context.Context) error {
    a.Logger.Info("shutting down application")
    
    // Create shutdown context with timeout
    shutdownCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
    defer cancel()
    
    // Shutdown HTTP server
    if err := a.Server.Shutdown(shutdownCtx); err != nil {
        a.Logger.Error("server shutdown error", "error", err)
        return err
    }
    
    // Close database connections
    if err := a.Repository.Close(); err != nil {
        a.Logger.Error("database close error", "error", err)
        return err
    }
    
    // Close other resources (cache, message queues, etc.)
    if closer, ok := a.UserSvc.(interface{ Close() error }); ok {
        if err := closer.Close(); err != nil {
            a.Logger.Error("service close error", "error", err)
        }
    }
    
    a.Logger.Info("application shutdown complete")
    return nil
}
```

## Database Patterns

### Connection Pool Management
Configure database connections for production:

```go
import (
    "database/sql"
    "time"
    
    _ "github.com/lib/pq"
)

func NewDatabase(cfg *Config) (*sql.DB, error) {
    db, err := sql.Open("postgres", cfg.DatabaseURL)
    if err != nil {
        return nil, fmt.Errorf("open database: %w", err)
    }
    
    // Configure connection pool
    db.SetMaxOpenConns(cfg.MaxOpenConns)
    db.SetMaxIdleConns(cfg.MaxIdleConns)
    db.SetConnMaxLifetime(cfg.ConnMaxLifetime)
    
    // Verify connection
    ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
    defer cancel()
    
    if err := db.PingContext(ctx); err != nil {
        db.Close()
        return nil, fmt.Errorf("ping database: %w", err)
    }
    
    return db, nil
}

// Transaction wrapper with retry logic
func WithTransaction(db *sql.DB, fn func(*sql.Tx) error) error {
    const maxRetries = 3
    
    for attempt := 0; attempt < maxRetries; attempt++ {
        tx, err := db.Begin()
        if err != nil {
            return fmt.Errorf("begin transaction: %w", err)
        }
        
        err = fn(tx)
        if err != nil {
            if rbErr := tx.Rollback(); rbErr != nil {
                return fmt.Errorf("rollback failed: %v, original error: %w", rbErr, err)
            }
            
            // Check if error is retryable
            if isRetryableError(err) && attempt < maxRetries-1 {
                time.Sleep(time.Duration(attempt+1) * 100 * time.Millisecond)
                continue
            }
            
            return err
        }
        
        if err := tx.Commit(); err != nil {
            return fmt.Errorf("commit transaction: %w", err)
        }
        
        return nil
    }
    
    return errors.New("max retries exceeded")
}

func isRetryableError(err error) bool {
    // Check for specific database errors that are retryable
    return false // Implement based on your database driver
}
```

## Container Deployment

### Dockerfile Best Practices
Create optimized Docker images:

```dockerfile
# Multi-stage build for smaller images
FROM golang:1.26-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates

# Set working directory
WORKDIR /app

# Copy go mod files first (better caching)
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build binary with optimizations
RUN CGO_ENABLED=0 GOOS=linux go build \
    -a -installsuffix cgo \
    -ldflags="-w -s" \
    -o myapp \
    ./cmd/myapp

# Final stage with minimal base image
FROM alpine:latest

# Add security updates and certificates
RUN apk --no-cache add ca-certificates tzdata

# Create non-root user
RUN adduser -D -s /bin/sh appuser

# Copy binary from builder stage
COPY --from=builder /app/myapp /usr/local/bin/myapp

# Use non-root user
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Expose port
EXPOSE 8080

# Run application
CMD ["myapp"]
```

For security configurations in enterprise deployment, see [Security Crypto](security-crypto.md) and [Security Input](security-input.md). For performance optimization in production, see [Performance Optimization](performance-optimization.md). For testing enterprise applications, see [Testing Strategies](testing-strategies.md).