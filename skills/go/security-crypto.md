# Security - Cryptography & Authentication

*Authentication, cryptography, and HTTP security for Go 1.26.x based on [OWASP Go Secure Coding Practices](https://owasp.org/www-project-go-secure-coding-practices-guide/)*

## Authentication and Authorization

### Secure Password Handling
Use bcrypt for password hashing and proper handling:

```go
import (
    "errors"
    "golang.org/x/crypto/bcrypt"
    "crypto/subtle"
)

const (
    MinPasswordLength = 8
    MaxPasswordLength = 128
    BcryptCost       = 12 // Adjust based on security/performance needs
)

func HashPassword(password string) (string, error) {
    if len(password) < MinPasswordLength {
        return "", fmt.Errorf("password must be at least %d characters", MinPasswordLength)
    }
    
    if len(password) > MaxPasswordLength {
        return "", fmt.Errorf("password cannot exceed %d characters", MaxPasswordLength)
    }
    
    hash, err := bcrypt.GenerateFromPassword([]byte(password), BcryptCost)
    if err != nil {
        return "", fmt.Errorf("hash password: %w", err)
    }
    
    return string(hash), nil
}

func VerifyPassword(hashedPassword, password string) error {
    err := bcrypt.CompareHashAndPassword([]byte(hashedPassword), []byte(password))
    if err != nil {
        if errors.Is(err, bcrypt.ErrMismatchedHashAndPassword) {
            return ErrInvalidCredentials
        }
        return fmt.Errorf("verify password: %w", err)
    }
    
    return nil
}

// Clear sensitive data from memory
func ClearPassword(password []byte) {
    for i := range password {
        password[i] = 0
    }
}

// Timing-safe string comparison
func SecureCompare(a, b string) bool {
    return subtle.ConstantTimeCompare([]byte(a), []byte(b)) == 1
}

// Password strength validation
func ValidatePasswordStrength(password string) error {
    if len(password) < MinPasswordLength {
        return errors.New("password too short")
    }
    
    hasUpper := false
    hasLower := false
    hasDigit := false
    hasSpecial := false
    
    for _, char := range password {
        switch {
        case 'A' <= char && char <= 'Z':
            hasUpper = true
        case 'a' <= char && char <= 'z':
            hasLower = true
        case '0' <= char && char <= '9':
            hasDigit = true
        default:
            hasSpecial = true
        }
    }
    
    if !hasUpper {
        return errors.New("password must contain uppercase letter")
    }
    if !hasLower {
        return errors.New("password must contain lowercase letter")
    }
    if !hasDigit {
        return errors.New("password must contain digit")
    }
    if !hasSpecial {
        return errors.New("password must contain special character")
    }
    
    return nil
}
```

### JWT Token Security
Implement secure JWT handling:

```go
import (
    "time"
    "github.com/golang-jwt/jwt/v4"
)

type Claims struct {
    UserID   string   `json:"user_id"`
    Username string   `json:"username"`
    Role     string   `json:"role"`
    Scopes   []string `json:"scopes,omitempty"`
    jwt.RegisteredClaims
}

type TokenService struct {
    signingKey    []byte
    signingMethod jwt.SigningMethod
    issuer        string
    accessTTL     time.Duration
    refreshTTL    time.Duration
}

func NewTokenService(signingKey []byte, issuer string) *TokenService {
    return &TokenService{
        signingKey:    signingKey,
        signingMethod: jwt.SigningMethodHS256,
        issuer:        issuer,
        accessTTL:     15 * time.Minute,
        refreshTTL:    7 * 24 * time.Hour, // 7 days
    }
}

func (ts *TokenService) GenerateAccessToken(userID, username, role string, scopes []string) (string, error) {
    now := time.Now()
    claims := &Claims{
        UserID:   userID,
        Username: username,
        Role:     role,
        Scopes:   scopes,
        RegisteredClaims: jwt.RegisteredClaims{
            ExpiresAt: jwt.NewNumericDate(now.Add(ts.accessTTL)),
            IssuedAt:  jwt.NewNumericDate(now),
            NotBefore: jwt.NewNumericDate(now),
            Issuer:    ts.issuer,
            Subject:   userID,
            Audience:  jwt.ClaimStrings{"api"},
        },
    }
    
    token := jwt.NewWithClaims(ts.signingMethod, claims)
    return token.SignedString(ts.signingKey)
}

func (ts *TokenService) GenerateRefreshToken(userID string) (string, error) {
    now := time.Now()
    claims := &jwt.RegisteredClaims{
        ExpiresAt: jwt.NewNumericDate(now.Add(ts.refreshTTL)),
        IssuedAt:  jwt.NewNumericDate(now),
        NotBefore: jwt.NewNumericDate(now),
        Issuer:    ts.issuer,
        Subject:   userID,
        Audience:  jwt.ClaimStrings{"refresh"},
    }
    
    token := jwt.NewWithClaims(ts.signingMethod, claims)
    return token.SignedString(ts.signingKey)
}

func (ts *TokenService) ValidateToken(tokenString string, expectedAudience string) (*Claims, error) {
    token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (any, error) {
        // Verify signing method
        if token.Method != ts.signingMethod {
            return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
        }
        return ts.signingKey, nil
    })
    
    if err != nil {
        return nil, fmt.Errorf("parse token: %w", err)
    }
    
    claims, ok := token.Claims.(*Claims)
    if !ok || !token.Valid {
        return nil, errors.New("invalid token claims")
    }
    
    // Validate audience
    if !claims.VerifyAudience(expectedAudience, true) {
        return nil, errors.New("invalid token audience")
    }
    
    // Validate issuer
    if !claims.VerifyIssuer(ts.issuer, true) {
        return nil, errors.New("invalid token issuer")
    }
    
    return claims, nil
}

// Token blacklist for logout functionality
type TokenBlacklist struct {
    blacklist map[string]time.Time
    mu        sync.RWMutex
    cleanup   *time.Ticker
}

func NewTokenBlacklist() *TokenBlacklist {
    tb := &TokenBlacklist{
        blacklist: make(map[string]time.Time),
        cleanup:   time.NewTicker(1 * time.Hour),
    }
    
    go tb.cleanupExpired()
    return tb
}

func (tb *TokenBlacklist) BlacklistToken(tokenID string, expiry time.Time) {
    tb.mu.Lock()
    defer tb.mu.Unlock()
    tb.blacklist[tokenID] = expiry
}

func (tb *TokenBlacklist) IsBlacklisted(tokenID string) bool {
    tb.mu.RLock()
    defer tb.mu.RUnlock()
    
    expiry, exists := tb.blacklist[tokenID]
    return exists && time.Now().Before(expiry)
}

func (tb *TokenBlacklist) cleanupExpired() {
    for range tb.cleanup.C {
        tb.mu.Lock()
        now := time.Now()
        for tokenID, expiry := range tb.blacklist {
            if now.After(expiry) {
                delete(tb.blacklist, tokenID)
            }
        }
        tb.mu.Unlock()
    }
}
```

### Rate Limiting
Implement rate limiting for API endpoints:

```go
import (
    "golang.org/x/time/rate"
    "net"
    "net/http"
    "strings"
    "sync"
)

type RateLimiter struct {
    limiters map[string]*rate.Limiter
    mu       sync.RWMutex
    rate     rate.Limit
    burst    int
    cleanup  *time.Ticker
}

func NewRateLimiter(r rate.Limit, burst int) *RateLimiter {
    rl := &RateLimiter{
        limiters: make(map[string]*rate.Limiter),
        rate:     r,
        burst:    burst,
        cleanup:  time.NewTicker(time.Minute),
    }
    
    go rl.cleanupInactive()
    return rl
}

func (rl *RateLimiter) Allow(clientID string) bool {
    rl.mu.Lock()
    defer rl.mu.Unlock()
    
    limiter, exists := rl.limiters[clientID]
    if !exists {
        limiter = rate.NewLimiter(rl.rate, rl.burst)
        rl.limiters[clientID] = limiter
    }
    
    return limiter.Allow()
}

func (rl *RateLimiter) cleanupInactive() {
    for range rl.cleanup.C {
        rl.mu.Lock()
        
        // Remove limiters that haven't been used recently
        for id, limiter := range rl.limiters {
            if limiter.Allow() { // This resets the limiter if it's at capacity
                limiter.Allow() // Use up the token we just added
            } else {
                // If limiter is at capacity and hasn't recovered, it's inactive
                delete(rl.limiters, id)
            }
        }
        
        rl.mu.Unlock()
    }
}

func RateLimitMiddleware(rl *RateLimiter) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            clientIP := getClientIP(r)
            
            if !rl.Allow(clientIP) {
                w.Header().Set("X-RateLimit-Limit", fmt.Sprintf("%.0f", float64(rl.rate)))
                w.Header().Set("X-RateLimit-Remaining", "0")
                w.Header().Set("Retry-After", "60")
                http.Error(w, "Rate limit exceeded", http.StatusTooManyRequests)
                return
            }
            
            next.ServeHTTP(w, r)
        })
    }
}

func getClientIP(r *http.Request) string {
    // Check X-Forwarded-For header
    if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
        ips := strings.Split(xff, ",")
        return strings.TrimSpace(ips[0])
    }
    
    // Check X-Real-IP header
    if xri := r.Header.Get("X-Real-IP"); xri != "" {
        return strings.TrimSpace(xri)
    }
    
    // Fall back to remote address
    host, _, _ := net.SplitHostPort(r.RemoteAddr)
    return host
}

// Advanced rate limiting with different tiers
type TieredRateLimiter struct {
    tiers map[string]*RateLimiter
    mu    sync.RWMutex
}

func NewTieredRateLimiter() *TieredRateLimiter {
    return &TieredRateLimiter{
        tiers: map[string]*RateLimiter{
            "anonymous":   NewRateLimiter(rate.Limit(10), 20),   // 10 req/sec, burst 20
            "basic":       NewRateLimiter(rate.Limit(50), 100),  // 50 req/sec, burst 100
            "premium":     NewRateLimiter(rate.Limit(200), 400), // 200 req/sec, burst 400
            "enterprise":  NewRateLimiter(rate.Limit(1000), 2000), // 1000 req/sec, burst 2000
        },
    }
}

func (trl *TieredRateLimiter) Allow(clientID, tier string) bool {
    trl.mu.RLock()
    defer trl.mu.RUnlock()
    
    limiter, exists := trl.tiers[tier]
    if !exists {
        limiter = trl.tiers["anonymous"] // Default to most restrictive
    }
    
    return limiter.Allow(clientID)
}
```

## Cryptography

### Secure Random Number Generation
Use crypto/rand for cryptographic operations:

```go
import (
    "crypto/rand"
    "encoding/base64"
    "encoding/hex"
)

func GenerateSecureToken(length int) (string, error) {
    bytes := make([]byte, length)
    if _, err := rand.Read(bytes); err != nil {
        return "", fmt.Errorf("generate random bytes: %w", err)
    }
    
    return base64.URLEncoding.EncodeToString(bytes), nil
}

func GenerateHexToken(length int) (string, error) {
    bytes := make([]byte, length)
    if _, err := rand.Read(bytes); err != nil {
        return "", fmt.Errorf("generate random bytes: %w", err)
    }
    
    return hex.EncodeToString(bytes), nil
}

func GenerateAPIKey() (string, error) {
    return GenerateSecureToken(32) // 256 bits
}

func GenerateSessionID() (string, error) {
    return GenerateSecureToken(24) // 192 bits
}

func GenerateCSRFToken() (string, error) {
    return GenerateSecureToken(32) // 256 bits
}

// Generate cryptographically secure passwords
func GenerateSecurePassword(length int) (string, error) {
    if length < 8 {
        return "", errors.New("password length must be at least 8")
    }
    
    const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
    
    password := make([]byte, length)
    for i := range password {
        randomByte := make([]byte, 1)
        if _, err := rand.Read(randomByte); err != nil {
            return "", fmt.Errorf("generate random byte: %w", err)
        }
        password[i] = charset[randomByte[0]%byte(len(charset))]
    }
    
    return string(password), nil
}

// Never use math/rand for security-sensitive operations
func insecureRandom() string {
    // DON'T DO THIS for security purposes
    // return fmt.Sprintf("%d", rand.Int())
    
    // Use crypto/rand instead
    token, _ := GenerateSecureToken(16)
    return token
}
```

### Encryption and Decryption
Implement secure encryption using AES-GCM:

```go
import (
    "crypto/aes"
    "crypto/cipher"
    "crypto/rand"
    "crypto/sha256"
)

type Encryptor struct {
    gcm cipher.AEAD
}

func NewEncryptor(key []byte) (*Encryptor, error) {
    if len(key) != 32 { // AES-256
        return nil, errors.New("key must be 32 bytes for AES-256")
    }
    
    block, err := aes.NewCipher(key)
    if err != nil {
        return nil, fmt.Errorf("create cipher: %w", err)
    }
    
    gcm, err := cipher.NewGCM(block)
    if err != nil {
        return nil, fmt.Errorf("create GCM: %w", err)
    }
    
    return &Encryptor{gcm: gcm}, nil
}

func (e *Encryptor) Encrypt(plaintext []byte) ([]byte, error) {
    nonce := make([]byte, e.gcm.NonceSize())
    if _, err := rand.Read(nonce); err != nil {
        return nil, fmt.Errorf("generate nonce: %w", err)
    }
    
    ciphertext := e.gcm.Seal(nonce, nonce, plaintext, nil)
    return ciphertext, nil
}

func (e *Encryptor) Decrypt(ciphertext []byte) ([]byte, error) {
    nonceSize := e.gcm.NonceSize()
    if len(ciphertext) < nonceSize {
        return nil, errors.New("ciphertext too short")
    }
    
    nonce, ciphertext := ciphertext[:nonceSize], ciphertext[nonceSize:]
    plaintext, err := e.gcm.Open(nil, nonce, ciphertext, nil)
    if err != nil {
        return nil, fmt.Errorf("decrypt: %w", err)
    }
    
    return plaintext, nil
}

// Encrypt with additional authenticated data
func (e *Encryptor) EncryptWithAAD(plaintext, additionalData []byte) ([]byte, error) {
    nonce := make([]byte, e.gcm.NonceSize())
    if _, err := rand.Read(nonce); err != nil {
        return nil, fmt.Errorf("generate nonce: %w", err)
    }
    
    ciphertext := e.gcm.Seal(nonce, nonce, plaintext, additionalData)
    return ciphertext, nil
}

func (e *Encryptor) DecryptWithAAD(ciphertext, additionalData []byte) ([]byte, error) {
    nonceSize := e.gcm.NonceSize()
    if len(ciphertext) < nonceSize {
        return nil, errors.New("ciphertext too short")
    }
    
    nonce, ciphertext := ciphertext[:nonceSize], ciphertext[nonceSize:]
    plaintext, err := e.gcm.Open(nil, nonce, ciphertext, additionalData)
    if err != nil {
        return nil, fmt.Errorf("decrypt: %w", err)
    }
    
    return plaintext, nil
}
```

### Secure Key Derivation
Use PBKDF2 and other key derivation functions:

```go
import (
    "golang.org/x/crypto/pbkdf2"
    "golang.org/x/crypto/scrypt"
)

func DeriveKeyPBKDF2(password, salt []byte, iterations, keyLength int) []byte {
    return pbkdf2.Key(password, salt, iterations, keyLength, sha256.New)
}

func DeriveKeyScrypt(password, salt []byte, N, r, p, keyLength int) ([]byte, error) {
    return scrypt.Key(password, salt, N, r, p, keyLength)
}

func GenerateSalt() ([]byte, error) {
    salt := make([]byte, 32)
    if _, err := rand.Read(salt); err != nil {
        return nil, fmt.Errorf("generate salt: %w", err)
    }
    return salt, nil
}

// Example usage for encrypting user data
func EncryptUserData(password string, data []byte) (encrypted, salt []byte, err error) {
    salt, err = GenerateSalt()
    if err != nil {
        return nil, nil, err
    }
    
    key := DeriveKeyPBKDF2([]byte(password), salt, 100000, 32) // 100k iterations, 32-byte key
    
    encryptor, err := NewEncryptor(key)
    if err != nil {
        return nil, nil, err
    }
    
    encrypted, err = encryptor.Encrypt(data)
    if err != nil {
        return nil, nil, err
    }
    
    // Clear sensitive data
    for i := range key {
        key[i] = 0
    }
    
    return encrypted, salt, nil
}

func DecryptUserData(password string, encrypted, salt []byte) ([]byte, error) {
    key := DeriveKeyPBKDF2([]byte(password), salt, 100000, 32)
    
    encryptor, err := NewEncryptor(key)
    if err != nil {
        return nil, err
    }
    
    plaintext, err := encryptor.Decrypt(encrypted)
    
    // Clear sensitive data
    for i := range key {
        key[i] = 0
    }
    
    return plaintext, err
}
```

## HTTP Security

### Secure Headers
Implement comprehensive security headers:

```go
import "net/http"

func SecurityHeadersMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Prevent XSS attacks
        w.Header().Set("X-Content-Type-Options", "nosniff")
        w.Header().Set("X-Frame-Options", "DENY")
        w.Header().Set("X-XSS-Protection", "1; mode=block")
        
        // Enforce HTTPS
        w.Header().Set("Strict-Transport-Security", "max-age=63072000; includeSubDomains; preload")
        
        // Content Security Policy
        csp := "default-src 'self'; " +
            "script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; " +
            "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; " +
            "font-src 'self' https://fonts.gstatic.com; " +
            "img-src 'self' data: https:; " +
            "connect-src 'self'; " +
            "frame-ancestors 'none'"
        w.Header().Set("Content-Security-Policy", csp)
        
        // Referrer Policy
        w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")
        
        // Permissions Policy (formerly Feature-Policy)
        w.Header().Set("Permissions-Policy", "geolocation=(), microphone=(), camera=()")
        
        next.ServeHTTP(w, r)
    })
}

// Environment-specific security headers
func ProductionSecurityHeaders(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // More restrictive CSP for production
        csp := "default-src 'self'; " +
            "script-src 'self'; " +
            "style-src 'self'; " +
            "img-src 'self'; " +
            "connect-src 'self'; " +
            "frame-ancestors 'none'; " +
            "base-uri 'self'; " +
            "form-action 'self'"
        w.Header().Set("Content-Security-Policy", csp)
        
        // Additional security headers
        w.Header().Set("X-Permitted-Cross-Domain-Policies", "none")
        w.Header().Set("Cross-Origin-Embedder-Policy", "require-corp")
        w.Header().Set("Cross-Origin-Opener-Policy", "same-origin")
        w.Header().Set("Cross-Origin-Resource-Policy", "same-origin")
        
        next.ServeHTTP(w, r)
    })
}
```

### CSRF Protection
Implement CSRF token validation:

```go
type CSRFProtection struct {
    tokenGenerator func() (string, error)
    sessionStore   SessionStore
    cookieName     string
    headerName     string
    secure         bool
    sameSite       http.SameSite
}

type SessionStore interface {
    GetCSRFToken(sessionID string) (string, error)
    SetCSRFToken(sessionID, token string) error
    DeleteCSRFToken(sessionID string) error
}

func NewCSRFProtection(sessionStore SessionStore, secure bool) *CSRFProtection {
    return &CSRFProtection{
        tokenGenerator: func() (string, error) {
            return GenerateCSRFToken()
        },
        sessionStore: sessionStore,
        cookieName:   "csrf_token",
        headerName:   "X-CSRF-Token",
        secure:       secure,
        sameSite:     http.SameSiteStrictMode,
    }
}

func (csrf *CSRFProtection) GenerateToken(w http.ResponseWriter, sessionID string) (string, error) {
    token, err := csrf.tokenGenerator()
    if err != nil {
        return "", err
    }
    
    // Store token in session
    if err := csrf.sessionStore.SetCSRFToken(sessionID, token); err != nil {
        return "", err
    }
    
    // Set token in cookie for JavaScript access
    http.SetCookie(w, &http.Cookie{
        Name:     csrf.cookieName,
        Value:    token,
        Path:     "/",
        HttpOnly: false, // Allow JavaScript access
        Secure:   csrf.secure,
        SameSite: csrf.sameSite,
    })
    
    return token, nil
}

func (csrf *CSRFProtection) ValidateToken(sessionID, providedToken string) error {
    if providedToken == "" {
        return errors.New("CSRF token is required")
    }
    
    storedToken, err := csrf.sessionStore.GetCSRFToken(sessionID)
    if err != nil {
        return fmt.Errorf("get CSRF token: %w", err)
    }
    
    if storedToken == "" {
        return errors.New("no CSRF token found in session")
    }
    
    if !SecureCompare(storedToken, providedToken) {
        return errors.New("invalid CSRF token")
    }
    
    return nil
}

func (csrf *CSRFProtection) Middleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        sessionID := getSessionID(r)
        
        // Generate token for safe methods
        if r.Method == "GET" || r.Method == "HEAD" || r.Method == "OPTIONS" {
            if sessionID != "" {
                csrf.GenerateToken(w, sessionID)
            }
            next.ServeHTTP(w, r)
            return
        }
        
        // Validate token for unsafe methods
        if r.Method == "POST" || r.Method == "PUT" || r.Method == "DELETE" || r.Method == "PATCH" {
            if sessionID == "" {
                http.Error(w, "Session required", http.StatusForbidden)
                return
            }
            
            // Get token from header or form
            csrfToken := r.Header.Get(csrf.headerName)
            if csrfToken == "" {
                csrfToken = r.FormValue("csrf_token")
            }
            
            if err := csrf.ValidateToken(sessionID, csrfToken); err != nil {
                http.Error(w, "CSRF token validation failed", http.StatusForbidden)
                return
            }
        }
        
        next.ServeHTTP(w, r)
    })
}

func getSessionID(r *http.Request) string {
    cookie, err := r.Cookie("session_id")
    if err != nil {
        return ""
    }
    return cookie.Value
}
```

## Secure Configuration

### Environment-Based Configuration
Externalize sensitive configuration securely:

```go
import (
    "encoding/hex"
    "os"
    "strconv"
    "time"
)

type Config struct {
    DatabaseURL   string
    JWTSigningKey []byte
    EncryptionKey []byte
    RedisPassword string
    TLSCert       string
    TLSKey        string
    Port          int
    Debug         bool
}

func LoadConfig() (*Config, error) {
    config := &Config{}
    
    // Database configuration
    config.DatabaseURL = os.Getenv("DATABASE_URL")
    if config.DatabaseURL == "" {
        return nil, errors.New("DATABASE_URL is required")
    }
    
    // JWT signing key
    jwtKey := os.Getenv("JWT_SIGNING_KEY")
    if jwtKey == "" {
        return nil, errors.New("JWT_SIGNING_KEY is required")
    }
    config.JWTSigningKey = []byte(jwtKey)
    
    // Encryption key (hex-encoded)
    encKey := os.Getenv("ENCRYPTION_KEY")
    if len(encKey) != 64 { // 32 bytes hex-encoded
        return nil, errors.New("ENCRYPTION_KEY must be 32 bytes hex-encoded")
    }
    
    var err error
    config.EncryptionKey, err = hex.DecodeString(encKey)
    if err != nil {
        return nil, fmt.Errorf("decode encryption key: %w", err)
    }
    
    // Optional configurations with defaults
    config.RedisPassword = os.Getenv("REDIS_PASSWORD")
    config.TLSCert = os.Getenv("TLS_CERT_PATH")
    config.TLSKey = os.Getenv("TLS_KEY_PATH")
    
    // Port configuration
    portStr := os.Getenv("PORT")
    if portStr == "" {
        config.Port = 8080 // default
    } else {
        config.Port, err = strconv.Atoi(portStr)
        if err != nil {
            return nil, fmt.Errorf("invalid PORT: %w", err)
        }
    }
    
    // Debug mode
    config.Debug = os.Getenv("DEBUG") == "true"
    
    return config, nil
}

// Clear sensitive data from memory when done
func (c *Config) Clear() {
    for i := range c.JWTSigningKey {
        c.JWTSigningKey[i] = 0
    }
    for i := range c.EncryptionKey {
        c.EncryptionKey[i] = 0
    }
    c.DatabaseURL = ""
    c.RedisPassword = ""
}
```

For input validation and injection prevention, see [Security Input](security-input.md). For secure testing strategies, see [Testing Strategies](testing-strategies.md). For enterprise security deployment, see [Enterprise Architecture](enterprise-architecture.md).