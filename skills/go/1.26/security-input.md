# Security - Input Validation

*Input validation and injection prevention for Go 1.26.x based on [OWASP Go Secure Coding Practices](https://owasp.org/www-project-go-secure-coding-practices-guide/)*

## Input Validation and Sanitization

### String Validation
Validate and sanitize all input data:

```go
import (
    "errors"
    "regexp"
    "strings"
    "unicode"
    "unicode/utf8"
)

var (
    emailRegex   = regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)
    alphaNumeric = regexp.MustCompile(`^[a-zA-Z0-9]+$`)
    phoneRegex   = regexp.MustCompile(`^\+?[1-9]\d{1,14}$`) // E.164 format
    uuidRegex    = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)
)

func ValidateEmail(email string) error {
    if len(email) > 320 { // RFC 5321 limit
        return errors.New("email too long")
    }
    
    if !utf8.ValidString(email) {
        return errors.New("invalid UTF-8 in email")
    }
    
    if !emailRegex.MatchString(email) {
        return errors.New("invalid email format")
    }
    
    return nil
}

func ValidateUsername(username string) error {
    if len(username) < 3 || len(username) > 32 {
        return errors.New("username must be 3-32 characters")
    }
    
    if !alphaNumeric.MatchString(username) {
        return errors.New("username can only contain letters and numbers")
    }
    
    return nil
}

func ValidatePhoneNumber(phone string) error {
    if len(phone) > 16 {
        return errors.New("phone number too long")
    }
    
    if !phoneRegex.MatchString(phone) {
        return errors.New("invalid phone number format")
    }
    
    return nil
}

func ValidateUUID(uuid string) error {
    if !uuidRegex.MatchString(uuid) {
        return errors.New("invalid UUID format")
    }
    
    return nil
}

func SanitizeUserInput(input string) string {
    if !utf8.ValidString(input) {
        return ""
    }
    
    // Remove control characters
    var cleaned strings.Builder
    for _, r := range input {
        if !unicode.IsControl(r) {
            cleaned.WriteRune(r)
        }
    }
    
    return strings.TrimSpace(cleaned.String())
}

// Whitelist approach for allowed characters
func SanitizeAlphaNumeric(input string) string {
    var cleaned strings.Builder
    for _, r := range input {
        if unicode.IsLetter(r) || unicode.IsDigit(r) {
            cleaned.WriteRune(r)
        }
    }
    return cleaned.String()
}

// HTML sanitization (basic)
func SanitizeHTML(input string) string {
    // Replace dangerous HTML characters
    replacements := map[string]string{
        "<":  "&lt;",
        ">":  "&gt;",
        "\"": "&quot;",
        "'":  "&#x27;",
        "&":  "&amp;",
    }
    
    result := input
    for old, new := range replacements {
        result = strings.ReplaceAll(result, old, new)
    }
    
    return result
}
```

### Request Validation
Comprehensive request validation patterns:

```go
import (
    "fmt"
    "net/url"
    "strconv"
)

type ValidationError struct {
    Field   string
    Value   any
    Message string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation failed for field %q: %s", e.Field, e.Message)
}

type Validator struct {
    errors []ValidationError
}

func NewValidator() *Validator {
    return &Validator{
        errors: make([]ValidationError, 0),
    }
}

func (v *Validator) ValidateRequired(field string, value any) *Validator {
    if value == nil {
        v.errors = append(v.errors, ValidationError{
            Field:   field,
            Value:   value,
            Message: "is required",
        })
        return v
    }
    
    // Check for empty strings
    if str, ok := value.(string); ok && strings.TrimSpace(str) == "" {
        v.errors = append(v.errors, ValidationError{
            Field:   field,
            Value:   value,
            Message: "cannot be empty",
        })
    }
    
    return v
}

func (v *Validator) ValidateLength(field string, value string, min, max int) *Validator {
    length := len(value)
    if length < min {
        v.errors = append(v.errors, ValidationError{
            Field:   field,
            Value:   value,
            Message: fmt.Sprintf("must be at least %d characters", min),
        })
    }
    
    if max > 0 && length > max {
        v.errors = append(v.errors, ValidationError{
            Field:   field,
            Value:   value,
            Message: fmt.Sprintf("cannot exceed %d characters", max),
        })
    }
    
    return v
}

func (v *Validator) ValidateRange(field string, value, min, max int) *Validator {
    if value < min {
        v.errors = append(v.errors, ValidationError{
            Field:   field,
            Value:   value,
            Message: fmt.Sprintf("must be at least %d", min),
        })
    }
    
    if value > max {
        v.errors = append(v.errors, ValidationError{
            Field:   field,
            Value:   value,
            Message: fmt.Sprintf("cannot exceed %d", max),
        })
    }
    
    return v
}

func (v *Validator) ValidateEmail(field string, email string) *Validator {
    if err := ValidateEmail(email); err != nil {
        v.errors = append(v.errors, ValidationError{
            Field:   field,
            Value:   email,
            Message: err.Error(),
        })
    }
    
    return v
}

func (v *Validator) ValidateURL(field string, urlStr string) *Validator {
    if _, err := url.ParseRequestURI(urlStr); err != nil {
        v.errors = append(v.errors, ValidationError{
            Field:   field,
            Value:   urlStr,
            Message: "invalid URL format",
        })
    }
    
    return v
}

func (v *Validator) ValidateInSlice(field string, value string, allowed []string) *Validator {
    for _, item := range allowed {
        if value == item {
            return v
        }
    }
    
    v.errors = append(v.errors, ValidationError{
        Field:   field,
        Value:   value,
        Message: fmt.Sprintf("must be one of: %v", allowed),
    })
    
    return v
}

func (v *Validator) IsValid() bool {
    return len(v.errors) == 0
}

func (v *Validator) Errors() []ValidationError {
    return v.errors
}

// Usage example
type CreateUserRequest struct {
    Name     string `json:"name"`
    Email    string `json:"email"`
    Age      int    `json:"age"`
    Role     string `json:"role"`
    Website  string `json:"website,omitempty"`
}

func (r *CreateUserRequest) Validate() error {
    validator := NewValidator()
    
    validator.ValidateRequired("name", r.Name).
        ValidateLength("name", r.Name, 2, 100)
    
    validator.ValidateRequired("email", r.Email).
        ValidateEmail("email", r.Email)
    
    validator.ValidateRange("age", r.Age, 13, 120)
    
    allowedRoles := []string{"user", "admin", "moderator"}
    validator.ValidateInSlice("role", r.Role, allowedRoles)
    
    if r.Website != "" {
        validator.ValidateURL("website", r.Website)
    }
    
    if !validator.IsValid() {
        return fmt.Errorf("validation failed: %v", validator.Errors())
    }
    
    return nil
}
```

## SQL Injection Prevention

### Parameterized Queries
Always use parameterized queries to prevent SQL injection:

```go
import (
    "database/sql"
    "fmt"
)

// Good - parameterized query
func GetUserByID(db *sql.DB, userID int64) (*User, error) {
    query := "SELECT id, name, email, created_at FROM users WHERE id = $1"
    
    var user User
    err := db.QueryRow(query, userID).Scan(&user.ID, &user.Name, &user.Email, &user.CreatedAt)
    if err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return nil, ErrUserNotFound
        }
        return nil, fmt.Errorf("query user: %w", err)
    }
    
    return &user, nil
}

// Good - parameterized query with IN clause
func GetUsersByIDs(db *sql.DB, userIDs []int64) ([]*User, error) {
    if len(userIDs) == 0 {
        return []*User{}, nil
    }
    
    // Create placeholder string: $1,$2,$3...
    placeholders := make([]string, len(userIDs))
    args := make([]any, len(userIDs))
    
    for i, id := range userIDs {
        placeholders[i] = fmt.Sprintf("$%d", i+1)
        args[i] = id
    }
    
    query := fmt.Sprintf("SELECT id, name, email FROM users WHERE id IN (%s)", 
        strings.Join(placeholders, ","))
    
    rows, err := db.Query(query, args...)
    if err != nil {
        return nil, fmt.Errorf("query users: %w", err)
    }
    defer rows.Close()
    
    var users []*User
    for rows.Next() {
        var user User
        if err := rows.Scan(&user.ID, &user.Name, &user.Email); err != nil {
            return nil, fmt.Errorf("scan user: %w", err)
        }
        users = append(users, &user)
    }
    
    return users, rows.Err()
}

// Good - using prepared statements for repeated queries
type UserQueries struct {
    getUser    *sql.Stmt
    updateUser *sql.Stmt
    deleteUser *sql.Stmt
}

func PrepareUserQueries(db *sql.DB) (*UserQueries, error) {
    getUserStmt, err := db.Prepare("SELECT id, name, email FROM users WHERE id = $1")
    if err != nil {
        return nil, fmt.Errorf("prepare get user stmt: %w", err)
    }
    
    updateUserStmt, err := db.Prepare("UPDATE users SET name = $1, email = $2, updated_at = NOW() WHERE id = $3")
    if err != nil {
        getUserStmt.Close()
        return nil, fmt.Errorf("prepare update user stmt: %w", err)
    }
    
    deleteUserStmt, err := db.Prepare("DELETE FROM users WHERE id = $1")
    if err != nil {
        getUserStmt.Close()
        updateUserStmt.Close()
        return nil, fmt.Errorf("prepare delete user stmt: %w", err)
    }
    
    return &UserQueries{
        getUser:    getUserStmt,
        updateUser: updateUserStmt,
        deleteUser: deleteUserStmt,
    }, nil
}

func (uq *UserQueries) Close() error {
    var errs []error
    
    if err := uq.getUser.Close(); err != nil {
        errs = append(errs, err)
    }
    if err := uq.updateUser.Close(); err != nil {
        errs = append(errs, err)
    }
    if err := uq.deleteUser.Close(); err != nil {
        errs = append(errs, err)
    }
    
    if len(errs) > 0 {
        return fmt.Errorf("close statements: %v", errs)
    }
    
    return nil
}

// Query builder with proper parameterization
type QueryBuilder struct {
    table      string
    columns    []string
    where      []string
    args       []any
    argCounter int
}

func NewQueryBuilder(table string) *QueryBuilder {
    return &QueryBuilder{
        table:   table,
        columns: make([]string, 0),
        where:   make([]string, 0),
        args:    make([]any, 0),
    }
}

func (qb *QueryBuilder) Select(columns ...string) *QueryBuilder {
    qb.columns = append(qb.columns, columns...)
    return qb
}

func (qb *QueryBuilder) Where(condition string, value any) *QueryBuilder {
    qb.argCounter++
    placeholder := fmt.Sprintf("$%d", qb.argCounter)
    
    // Replace ? with proper PostgreSQL placeholder
    condition = strings.ReplaceAll(condition, "?", placeholder)
    
    qb.where = append(qb.where, condition)
    qb.args = append(qb.args, value)
    return qb
}

func (qb *QueryBuilder) Build() (string, []any) {
    var query strings.Builder
    
    query.WriteString("SELECT ")
    if len(qb.columns) == 0 {
        query.WriteString("*")
    } else {
        query.WriteString(strings.Join(qb.columns, ", "))
    }
    
    query.WriteString(" FROM ")
    query.WriteString(qb.table)
    
    if len(qb.where) > 0 {
        query.WriteString(" WHERE ")
        query.WriteString(strings.Join(qb.where, " AND "))
    }
    
    return query.String(), qb.args
}

// NEVER do this - vulnerable to SQL injection
func BadGetUserByName(db *sql.DB, name string) (*User, error) {
    // DON'T DO THIS - SQL injection vulnerability
    // query := "SELECT id, name, email FROM users WHERE name = '" + name + "'"
    
    // Use parameterized queries instead
    query := "SELECT id, name, email FROM users WHERE name = $1"
    return queryUser(db, query, name)
}
```

## NoSQL Injection Prevention

### MongoDB Query Validation
Validate inputs for NoSQL databases to prevent injection:

```go
import (
    "go.mongodb.org/mongo-driver/bson"
    "go.mongodb.org/mongo-driver/bson/primitive"
    "go.mongodb.org/mongo-driver/mongo"
)

// Validate MongoDB queries to prevent injection
func ValidateMongoQuery(filter bson.M) error {
    return validateBSONDocument(filter)
}

func validateBSONDocument(doc bson.M) error {
    for key, value := range doc {
        // Prevent MongoDB injection operators in user input
        if strings.HasPrefix(key, "$") {
            return fmt.Errorf("operator %q not allowed in user input", key)
        }
        
        // Recursively validate nested documents
        if nested, ok := value.(bson.M); ok {
            if err := validateBSONDocument(nested); err != nil {
                return err
            }
        }
        
        // Validate arrays
        if array, ok := value.(bson.A); ok {
            if err := validateBSONArray(array); err != nil {
                return err
            }
        }
    }
    return nil
}

func validateBSONArray(array bson.A) error {
    for _, item := range array {
        if doc, ok := item.(bson.M); ok {
            if err := validateBSONDocument(doc); err != nil {
                return err
            }
        }
        
        if subArray, ok := item.(bson.A); ok {
            if err := validateBSONArray(subArray); err != nil {
                return err
            }
        }
    }
    return nil
}

// Safe MongoDB operations
func SafeFindUser(collection *mongo.Collection, userID string) (*User, error) {
    // Validate ObjectID format
    objID, err := primitive.ObjectIDFromHex(userID)
    if err != nil {
        return nil, fmt.Errorf("invalid user ID format: %w", err)
    }
    
    filter := bson.M{"_id": objID}
    
    var user User
    err = collection.FindOne(context.Background(), filter).Decode(&user)
    if err != nil {
        if errors.Is(err, mongo.ErrNoDocuments) {
            return nil, ErrUserNotFound
        }
        return nil, fmt.Errorf("find user: %w", err)
    }
    
    return &user, nil
}

func SafeFindUsersByStatus(collection *mongo.Collection, status string) ([]*User, error) {
    // Validate status value (whitelist approach)
    allowedStatuses := []string{"active", "inactive", "pending", "suspended"}
    if !contains(allowedStatuses, status) {
        return nil, fmt.Errorf("invalid status: %s", status)
    }
    
    filter := bson.M{"status": status}
    
    cursor, err := collection.Find(context.Background(), filter)
    if err != nil {
        return nil, fmt.Errorf("find users: %w", err)
    }
    defer cursor.Close(context.Background())
    
    var users []*User
    for cursor.Next(context.Background()) {
        var user User
        if err := cursor.Decode(&user); err != nil {
            return nil, fmt.Errorf("decode user: %w", err)
        }
        users = append(users, &user)
    }
    
    return users, cursor.Err()
}

// Safe dynamic query building
func SafeBuildMongoQuery(userFilters map[string]any) (bson.M, error) {
    // Whitelist allowed filter fields
    allowedFields := map[string]bool{
        "name":   true,
        "email":  true,
        "status": true,
        "age":    true,
    }
    
    filter := bson.M{}
    
    for field, value := range userFilters {
        if !allowedFields[field] {
            return nil, fmt.Errorf("field %q not allowed in filters", field)
        }
        
        // Additional validation based on field type
        switch field {
        case "name", "email":
            if str, ok := value.(string); ok && str != "" {
                // Use regex for partial matching (be careful with user input)
                filter[field] = primitive.Regex{Pattern: regexp.QuoteMeta(str), Options: "i"}
            }
        case "status":
            if str, ok := value.(string); ok {
                allowedStatuses := []string{"active", "inactive", "pending"}
                if contains(allowedStatuses, str) {
                    filter[field] = str
                }
            }
        case "age":
            if age, ok := value.(float64); ok && age > 0 && age < 150 {
                filter[field] = bson.M{"$gte": age}
            }
        }
    }
    
    return filter, nil
}

func contains(slice []string, item string) bool {
    for _, s := range slice {
        if s == item {
            return true
        }
    }
    return false
}
```

## Path Traversal Prevention

### File Path Validation
Prevent directory traversal attacks:

```go
import (
    "path/filepath"
    "os"
)

// Safe file operations
func SafeReadFile(basePath, userPath string) ([]byte, error) {
    // Clean and validate the path
    cleanPath := filepath.Clean(userPath)
    
    // Check for directory traversal attempts
    if strings.Contains(cleanPath, "..") {
        return nil, errors.New("invalid file path: directory traversal detected")
    }
    
    // Ensure path is relative
    if filepath.IsAbs(cleanPath) {
        return nil, errors.New("absolute paths not allowed")
    }
    
    // Join with base path
    fullPath := filepath.Join(basePath, cleanPath)
    
    // Double-check the resolved path is within base directory
    absBasePath, err := filepath.Abs(basePath)
    if err != nil {
        return nil, fmt.Errorf("resolve base path: %w", err)
    }
    
    absFullPath, err := filepath.Abs(fullPath)
    if err != nil {
        return nil, fmt.Errorf("resolve full path: %w", err)
    }
    
    if !strings.HasPrefix(absFullPath, absBasePath+string(filepath.Separator)) {
        return nil, errors.New("path outside allowed directory")
    }
    
    // Check if file exists and is not a directory
    info, err := os.Stat(fullPath)
    if err != nil {
        return nil, fmt.Errorf("stat file: %w", err)
    }
    
    if info.IsDir() {
        return nil, errors.New("path is a directory")
    }
    
    return os.ReadFile(fullPath)
}

// Whitelist approach for allowed file extensions
func ValidateFileExtension(filename string) error {
    allowedExtensions := map[string]bool{
        ".txt":  true,
        ".json": true,
        ".csv":  true,
        ".xml":  true,
        ".yml":  true,
        ".yaml": true,
    }
    
    ext := strings.ToLower(filepath.Ext(filename))
    if !allowedExtensions[ext] {
        return fmt.Errorf("file extension %q not allowed", ext)
    }
    
    return nil
}

// Safe file upload handling
func HandleFileUpload(filename string, maxSize int64, allowedTypes map[string]bool) error {
    // Validate filename
    if filename == "" {
        return errors.New("filename cannot be empty")
    }
    
    // Check for null bytes
    if strings.Contains(filename, "\x00") {
        return errors.New("filename contains null bytes")
    }
    
    // Validate extension
    ext := strings.ToLower(filepath.Ext(filename))
    if !allowedTypes[ext] {
        return fmt.Errorf("file type %q not allowed", ext)
    }
    
    // Additional filename sanitization
    sanitized := filepath.Base(filename)
    if sanitized != filename {
        return errors.New("invalid filename")
    }
    
    return nil
}
```

For cryptographic security and authentication patterns, see [Security Crypto](security-crypto.md). For secure coding in concurrent applications, see [Concurrency Basics](concurrency-basics.md). For security testing strategies, see [Testing Strategies](testing-strategies.md).