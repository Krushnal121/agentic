# Performance Optimization

*Memory management, algorithms, and I/O optimization for Go 1.26.x*

## Memory Optimization

### Pool Pattern for Object Reuse
Use sync.Pool for expensive object allocation:

```go
import (
    "sync"
    "net"
    "time"
)

type BufferPool struct {
    pool sync.Pool
}

func NewBufferPool() *BufferPool {
    return &BufferPool{
        pool: sync.Pool{
            New: func() any {
                return make([]byte, 0, 1024) // Initial capacity
            },
        },
    }
}

func (bp *BufferPool) Get() []byte {
    return bp.pool.Get().([]byte)
}

func (bp *BufferPool) Put(buf []byte) {
    if cap(buf) > 16*1024 { // Don't pool very large buffers
        return
    }
    
    buf = buf[:0] // Reset length but keep capacity
    bp.pool.Put(buf)
}

// Usage example
var bufferPool = NewBufferPool()

func ProcessRequest(data []byte) ([]byte, error) {
    buf := bufferPool.Get()
    defer bufferPool.Put(buf)
    
    // Use buffer for processing
    buf = append(buf, processData(data)...)
    
    // Return copy since buffer will be returned to pool
    result := make([]byte, len(buf))
    copy(result, buf)
    return result, nil
}

// Connection pool for expensive resources
type ConnectionPool struct {
    pool    sync.Pool
    factory func() (net.Conn, error)
    timeout time.Duration
}

func NewConnectionPool(factory func() (net.Conn, error), timeout time.Duration) *ConnectionPool {
    return &ConnectionPool{
        factory: factory,
        timeout: timeout,
        pool: sync.Pool{
            New: func() any {
                conn, err := factory()
                if err != nil {
                    return nil
                }
                return conn
            },
        },
    }
}

func (cp *ConnectionPool) GetConnection() (net.Conn, error) {
    if conn := cp.pool.Get(); conn != nil {
        if netConn := conn.(net.Conn); netConn != nil {
            // Check if connection is still valid
            netConn.SetDeadline(time.Now().Add(cp.timeout))
            return netConn, nil
        }
    }
    
    return cp.factory()
}

func (cp *ConnectionPool) PutConnection(conn net.Conn) {
    if conn != nil {
        cp.pool.Put(conn)
    }
}
```

### Memory-Efficient Data Structures
Choose appropriate data structures for memory efficiency:

```go
// Use slices efficiently
func OptimizedSliceOperations() {
    // Pre-allocate when size is known
    items := make([]Item, 0, 1000) // length 0, capacity 1000
    
    // Append efficiently
    for i := 0; i < 1000; i++ {
        items = append(items, Item{ID: i})
    }
    
    // When filtering, reuse slice to avoid allocation
    filtered := items[:0] // Reuse underlying array
    for _, item := range items {
        if item.IsValid() {
            filtered = append(filtered, item)
        }
    }
    items = filtered
}

// Struct field ordering for memory efficiency
type EfficientStruct struct {
    // Order fields by size to minimize padding
    id       int64   // 8 bytes
    score    float64 // 8 bytes
    name     string  // 16 bytes (on 64-bit)
    active   bool    // 1 byte
    category uint8   // 1 byte
    // Total: 34 bytes + minimal padding
}

type InefficientStruct struct {
    // Poor field ordering causes padding
    active   bool    // 1 byte + 7 bytes padding
    id       int64   // 8 bytes
    category uint8   // 1 byte + 7 bytes padding
    score    float64 // 8 bytes
    name     string  // 16 bytes
    // Total: 42 bytes (more memory due to padding)
}

// Use string interning for repeated strings
type StringInterner struct {
    strings map[string]string
    mu      sync.RWMutex
}

func NewStringInterner() *StringInterner {
    return &StringInterner{
        strings: make(map[string]string),
    }
}

func (si *StringInterner) Intern(s string) string {
    si.mu.RLock()
    if interned, exists := si.strings[s]; exists {
        si.mu.RUnlock()
        return interned
    }
    si.mu.RUnlock()
    
    si.mu.Lock()
    defer si.mu.Unlock()
    
    // Double-check after acquiring write lock
    if interned, exists := si.strings[s]; exists {
        return interned
    }
    
    // Create interned copy
    interned := string([]byte(s))
    si.strings[s] = interned
    return interned
}

// Bit manipulation for compact storage
type BitSet struct {
    bits []uint64
    size int
}

func NewBitSet(size int) *BitSet {
    return &BitSet{
        bits: make([]uint64, (size+63)/64),
        size: size,
    }
}

func (bs *BitSet) Set(index int) {
    if index >= 0 && index < bs.size {
        bs.bits[index/64] |= 1 << (index % 64)
    }
}

func (bs *BitSet) Clear(index int) {
    if index >= 0 && index < bs.size {
        bs.bits[index/64] &^= 1 << (index % 64)
    }
}

func (bs *BitSet) Test(index int) bool {
    if index >= 0 && index < bs.size {
        return bs.bits[index/64]&(1<<(index%64)) != 0
    }
    return false
}

func (bs *BitSet) Count() int {
    count := 0
    for _, word := range bs.bits {
        count += popcount(word)
    }
    return count
}

func popcount(x uint64) int {
    // Brian Kernighan's algorithm
    count := 0
    for x != 0 {
        x &= x - 1
        count++
    }
    return count
}
```

### Garbage Collection Optimization
Optimize for garbage collection performance:

```go
import (
    "runtime"
    "runtime/debug"
)

// Configure GC for your workload
func OptimizeGC() {
    // Set GC target percentage (default 100)
    debug.SetGCPercent(50) // More frequent GC, lower memory usage
    
    // For batch processing, you might want less frequent GC
    // debug.SetGCPercent(200) // Less frequent GC, higher memory usage
    
    // Set memory limit (Go 1.19+)
    debug.SetMemoryLimit(1024 * 1024 * 1024) // 1GB limit
}

// Monitor GC performance
func MonitorGC() {
    var lastGC uint32
    
    ticker := time.NewTicker(10 * time.Second)
    defer ticker.Stop()
    
    for range ticker.C {
        var m runtime.MemStats
        runtime.ReadMemStats(&m)
        
        if m.NumGC > lastGC {
            gcCount := m.NumGC - lastGC
            lastGC = m.NumGC
            
            // Calculate recent pause times
            var totalPause time.Duration
            for i := uint32(0); i < gcCount && i < 256; i++ {
                pause := time.Duration(m.PauseNs[(m.NumGC-1-i)%256])
                totalPause += pause
            }
            
            avgPause := totalPause / time.Duration(gcCount)
            
            log.Printf("GC: %d cycles, avg pause: %v, heap: %d MB", 
                gcCount, avgPause, m.HeapAlloc/1024/1024)
        }
    }
}

// Minimize allocations in hot paths
func ProcessHotPath(data []byte) []byte {
    // Pre-allocate result buffer
    result := make([]byte, 0, len(data))
    
    // Process data without additional allocations
    for _, b := range data {
        if b > 127 {
            result = append(result, b-128)
        } else {
            result = append(result, b)
        }
    }
    
    return result
}

// Reduce any allocations
func ProcessTypedData(items []any) {
    // Better: separate by type beforehand to avoid repeated type assertions
    var strings []string
    var ints []int
    
    for _, item := range items {
        switch v := item.(type) {
        case string:
            strings = append(strings, v)
        case int:
            ints = append(ints, v)
        }
    }
    
    // Process homogeneous slices for better performance
    for _, s := range strings {
        processString(s)
    }
    for _, i := range ints {
        processInt(i)
    }
}
```

## Algorithmic Optimization

### Efficient String Operations
Optimize string processing for performance:

```go
import (
    "strings"
    "unsafe"
)

// Use strings.Builder for concatenation
func BuildLargeString(parts []string) string {
    var builder strings.Builder
    
    // Calculate total size and grow buffer
    totalSize := 0
    for _, part := range parts {
        totalSize += len(part)
    }
    builder.Grow(totalSize)
    
    for _, part := range parts {
        builder.WriteString(part)
    }
    
    return builder.String()
}

// Efficient string searching
func FindMultipleSubstrings(text string, patterns []string) map[string][]int {
    results := make(map[string][]int)
    
    // For multiple patterns, consider using a trie or Aho-Corasick
    // For simple cases, use strings.Index with optimization
    for _, pattern := range patterns {
        var positions []int
        start := 0
        
        for {
            pos := strings.Index(text[start:], pattern)
            if pos == -1 {
                break
            }
            
            actualPos := start + pos
            positions = append(positions, actualPos)
            start = actualPos + 1
        }
        
        if len(positions) > 0 {
            results[pattern] = positions
        }
    }
    
    return results
}

// Byte-level string operations for performance
func ProcessStringBytes(s string) string {
    // Convert to bytes for manipulation
    data := []byte(s)
    
    // Process in place when possible
    for i, b := range data {
        if b >= 'a' && b <= 'z' {
            data[i] = b - 32 // Convert to uppercase
        }
    }
    
    return string(data)
}

// Zero-copy string to byte conversion (use with caution)
func StringToBytes(s string) []byte {
    return *(*[]byte)(unsafe.Pointer(&struct {
        string
        Cap int
    }{s, len(s)}))
}

func BytesToString(b []byte) string {
    return *(*string)(unsafe.Pointer(&b))
}
```

### Data Processing Optimization
Optimize data processing pipelines:

```go
// Batch processing for efficiency
type BatchProcessor[T any] struct {
    batchSize   int
    maxWait     time.Duration
    processor   func([]T) error
    buffer      []T
    timer       *time.Timer
    mu          sync.Mutex
    wg          sync.WaitGroup
}

func NewBatchProcessor[T any](batchSize int, maxWait time.Duration, processor func([]T) error) *BatchProcessor[T] {
    bp := &BatchProcessor[T]{
        batchSize: batchSize,
        maxWait:   maxWait,
        processor: processor,
        buffer:    make([]T, 0, batchSize),
    }
    
    bp.timer = time.NewTimer(maxWait)
    bp.timer.Stop()
    
    go bp.timerWorker()
    return bp
}

func (bp *BatchProcessor[T]) Add(item T) error {
    bp.mu.Lock()
    defer bp.mu.Unlock()
    
    bp.buffer = append(bp.buffer, item)
    
    if len(bp.buffer) == 1 {
        bp.timer.Reset(bp.maxWait)
    }
    
    if len(bp.buffer) >= bp.batchSize {
        return bp.flush()
    }
    
    return nil
}

func (bp *BatchProcessor[T]) flush() error {
    if len(bp.buffer) == 0 {
        return nil
    }
    
    batch := make([]T, len(bp.buffer))
    copy(batch, bp.buffer)
    bp.buffer = bp.buffer[:0]
    
    bp.timer.Stop()
    
    bp.wg.Add(1)
    go func() {
        defer bp.wg.Done()
        bp.processor(batch)
    }()
    
    return nil
}

func (bp *BatchProcessor[T]) timerWorker() {
    for range bp.timer.C {
        bp.mu.Lock()
        bp.flush()
        bp.mu.Unlock()
    }
}

// Parallel processing with worker pools
type WorkerPool[T, R any] struct {
    workers    int
    jobs       chan T
    results    chan R
    processor  func(T) R
    wg         sync.WaitGroup
}

func NewWorkerPool[T, R any](workers int, processor func(T) R) *WorkerPool[T, R] {
    wp := &WorkerPool[T, R]{
        workers:   workers,
        jobs:      make(chan T, workers*2), // Buffer for jobs
        results:   make(chan R, workers*2), // Buffer for results
        processor: processor,
    }
    
    // Start workers
    for i := 0; i < workers; i++ {
        go wp.worker()
    }
    
    return wp
}

func (wp *WorkerPool[T, R]) worker() {
    for job := range wp.jobs {
        result := wp.processor(job)
        wp.results <- result
        wp.wg.Done()
    }
}

func (wp *WorkerPool[T, R]) Submit(job T) {
    wp.wg.Add(1)
    wp.jobs <- job
}

func (wp *WorkerPool[T, R]) Results() <-chan R {
    return wp.results
}

func (wp *WorkerPool[T, R]) Wait() {
    wp.wg.Wait()
}

func (wp *WorkerPool[T, R]) Close() {
    close(wp.jobs)
    close(wp.results)
}
```

## I/O Optimization

### Buffered I/O Patterns
Optimize file and network I/O:

```go
import (
    "bufio"
    "os"
    "io"
    "net/http"
)

// Efficient file reading with custom buffer size
func ReadLargeFile(filename string) ([]byte, error) {
    file, err := os.Open(filename)
    if err != nil {
        return nil, err
    }
    defer file.Close()
    
    // Get file size for pre-allocation
    stat, err := file.Stat()
    if err != nil {
        return nil, err
    }
    
    // Pre-allocate buffer
    data := make([]byte, 0, stat.Size())
    
    // Use buffered reader with optimal buffer size
    reader := bufio.NewReaderSize(file, 64*1024) // 64KB buffer
    
    for {
        chunk := make([]byte, 32*1024) // 32KB chunks
        n, err := reader.Read(chunk)
        if n > 0 {
            data = append(data, chunk[:n]...)
        }
        if err == io.EOF {
            break
        }
        if err != nil {
            return nil, err
        }
    }
    
    return data, nil
}

// Streaming file processing for memory efficiency
func ProcessLargeFileStream(filename string, processor func([]byte) error) error {
    file, err := os.Open(filename)
    if err != nil {
        return err
    }
    defer file.Close()
    
    scanner := bufio.NewScanner(file)
    
    // Increase buffer size for large lines
    const maxCapacity = 1024 * 1024 // 1MB
    buf := make([]byte, 0, 64*1024)  // 64KB initial
    scanner.Buffer(buf, maxCapacity)
    
    for scanner.Scan() {
        if err := processor(scanner.Bytes()); err != nil {
            return err
        }
    }
    
    return scanner.Err()
}

// Optimized network I/O
type OptimizedHTTPClient struct {
    client *http.Client
    pool   *sync.Pool
}

func NewOptimizedHTTPClient() *OptimizedHTTPClient {
    transport := &http.Transport{
        MaxIdleConns:        100,
        MaxIdleConnsPerHost: 20,
        IdleConnTimeout:     90 * time.Second,
        DisableCompression:  false, // Enable compression
        ForceAttemptHTTP2:   true,
    }
    
    client := &http.Client{
        Transport: transport,
        Timeout:   30 * time.Second,
    }
    
    // Pool for reusing byte buffers
    pool := &sync.Pool{
        New: func() any {
            return make([]byte, 0, 32*1024)
        },
    }
    
    return &OptimizedHTTPClient{
        client: client,
        pool:   pool,
    }
}

func (c *OptimizedHTTPClient) Get(url string) ([]byte, error) {
    resp, err := c.client.Get(url)
    if err != nil {
        return nil, err
    }
    defer resp.Body.Close()
    
    // Get buffer from pool
    buf := c.pool.Get().([]byte)
    defer c.pool.Put(buf[:0])
    
    // Read response with pre-allocated buffer
    for {
        chunk := make([]byte, 8192)
        n, err := resp.Body.Read(chunk)
        if n > 0 {
            buf = append(buf, chunk[:n]...)
        }
        if err == io.EOF {
            break
        }
        if err != nil {
            return nil, err
        }
    }
    
    // Return copy since buffer goes back to pool
    result := make([]byte, len(buf))
    copy(result, buf)
    return result, nil
}
```

## Database Optimization

### Connection Pooling and Statement Caching
Optimize database performance:

```go
import "database/sql"

func OptimizeDatabase(db *sql.DB) {
    // Configure connection pool
    db.SetMaxOpenConns(25)                 // Maximum open connections
    db.SetMaxIdleConns(10)                 // Maximum idle connections
    db.SetConnMaxLifetime(5 * time.Minute) // Connection lifetime
    db.SetConnMaxIdleTime(2 * time.Minute) // Idle connection timeout
}

// Prepared statement caching
type StatementCache struct {
    db    *sql.DB
    cache map[string]*sql.Stmt
    mu    sync.RWMutex
}

func NewStatementCache(db *sql.DB) *StatementCache {
    return &StatementCache{
        db:    db,
        cache: make(map[string]*sql.Stmt),
    }
}

func (sc *StatementCache) GetStatement(query string) (*sql.Stmt, error) {
    sc.mu.RLock()
    if stmt, exists := sc.cache[query]; exists {
        sc.mu.RUnlock()
        return stmt, nil
    }
    sc.mu.RUnlock()
    
    sc.mu.Lock()
    defer sc.mu.Unlock()
    
    // Double-check after acquiring write lock
    if stmt, exists := sc.cache[query]; exists {
        return stmt, nil
    }
    
    stmt, err := sc.db.Prepare(query)
    if err != nil {
        return nil, err
    }
    
    sc.cache[query] = stmt
    return stmt, nil
}

// Batch operations for database efficiency
func BatchInsert(db *sql.DB, users []User) error {
    tx, err := db.Begin()
    if err != nil {
        return err
    }
    defer tx.Rollback()
    
    stmt, err := tx.Prepare("INSERT INTO users (name, email) VALUES ($1, $2)")
    if err != nil {
        return err
    }
    defer stmt.Close()
    
    for _, user := range users {
        if _, err := stmt.Exec(user.Name, user.Email); err != nil {
            return err
        }
    }
    
    return tx.Commit()
}

// Query result caching
type QueryCache struct {
    cache    map[string]CacheEntry
    maxSize  int
    maxAge   time.Duration
    mu       sync.RWMutex
}

type CacheEntry struct {
    Data      any
    Timestamp time.Time
}

func NewQueryCache(maxSize int, maxAge time.Duration) *QueryCache {
    qc := &QueryCache{
        cache:   make(map[string]CacheEntry),
        maxSize: maxSize,
        maxAge:  maxAge,
    }
    
    // Cleanup expired entries periodically
    go qc.cleanup()
    
    return qc
}

func (qc *QueryCache) Get(key string) (any, bool) {
    qc.mu.RLock()
    defer qc.mu.RUnlock()
    
    entry, exists := qc.cache[key]
    if !exists {
        return nil, false
    }
    
    if time.Since(entry.Timestamp) > qc.maxAge {
        return nil, false
    }
    
    return entry.Data, true
}

func (qc *QueryCache) Set(key string, data any) {
    qc.mu.Lock()
    defer qc.mu.Unlock()
    
    // Evict oldest entries if cache is full
    if len(qc.cache) >= qc.maxSize {
        qc.evictOldest()
    }
    
    qc.cache[key] = CacheEntry{
        Data:      data,
        Timestamp: time.Now(),
    }
}

func (qc *QueryCache) evictOldest() {
    var oldestKey string
    var oldestTime time.Time
    
    for key, entry := range qc.cache {
        if oldestKey == "" || entry.Timestamp.Before(oldestTime) {
            oldestKey = key
            oldestTime = entry.Timestamp
        }
    }
    
    if oldestKey != "" {
        delete(qc.cache, oldestKey)
    }
}

func (qc *QueryCache) cleanup() {
    ticker := time.NewTicker(time.Minute)
    defer ticker.Stop()
    
    for range ticker.C {
        qc.mu.Lock()
        
        now := time.Now()
        for key, entry := range qc.cache {
            if now.Sub(entry.Timestamp) > qc.maxAge {
                delete(qc.cache, key)
            }
        }
        
        qc.mu.Unlock()
    }
}
```

For profiling and measurement techniques, see [Performance Profiling](performance-profiling.md). For concurrent performance patterns, see [Concurrency Advanced](concurrency-advanced.md). For security considerations in optimized code, see [Security Practices](security-practices.md).