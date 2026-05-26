# Performance Profiling

*Profiling and benchmarking strategies for Go 1.26.x targeting high-throughput enterprise applications*

## CPU and Memory Profiling

### CPU Profiling with pprof
Use built-in profiling tools for performance analysis:

```go
import (
    _ "net/http/pprof" // Import for side effects
    "runtime/pprof"
    "os"
    "log"
    "net/http"
    "runtime"
)

// Enable profiling in your application
func main() {
    // Start CPU profiling
    if cpuProfile := os.Getenv("CPU_PROFILE"); cpuProfile != "" {
        f, err := os.Create(cpuProfile)
        if err != nil {
            log.Fatal(err)
        }
        defer f.Close()
        
        if err := pprof.StartCPUProfile(f); err != nil {
            log.Fatal(err)
        }
        defer pprof.StopCPUProfile()
    }
    
    // Your application code
    runApplication()
    
    // Write heap profile
    if memProfile := os.Getenv("MEM_PROFILE"); memProfile != "" {
        f, err := os.Create(memProfile)
        if err != nil {
            log.Fatal(err)
        }
        defer f.Close()
        
        runtime.GC() // Get up-to-date statistics
        if err := pprof.WriteHeapProfile(f); err != nil {
            log.Fatal(err)
        }
    }
}

// Add profiling endpoint to HTTP server
func setupProfiling() {
    go func() {
        log.Println("Starting profiling server on :6060")
        log.Println(http.ListenAndServe("localhost:6060", nil))
    }()
}

// Conditional profiling for production
func setupProductionProfiling() {
    if os.Getenv("ENABLE_PROFILING") == "true" {
        go func() {
            log.Println("Profiling enabled on :6060")
            log.Println(http.ListenAndServe("localhost:6060", nil))
        }()
    }
}
```

### Memory Profiling Techniques
Profile different types of memory usage:

```go
import (
    "runtime"
    "runtime/debug"
    "time"
)

// Memory profiling utility
type MemoryProfiler struct {
    interval time.Duration
    stop     chan bool
}

func NewMemoryProfiler(interval time.Duration) *MemoryProfiler {
    return &MemoryProfiler{
        interval: interval,
        stop:     make(chan bool),
    }
}

func (mp *MemoryProfiler) Start() {
    ticker := time.NewTicker(mp.interval)
    defer ticker.Stop()
    
    for {
        select {
        case <-ticker.C:
            mp.logMemoryStats()
        case <-mp.stop:
            return
        }
    }
}

func (mp *MemoryProfiler) Stop() {
    close(mp.stop)
}

func (mp *MemoryProfiler) logMemoryStats() {
    var m runtime.MemStats
    runtime.ReadMemStats(&m)
    
    log.Printf("Memory Stats:")
    log.Printf("  Alloc: %s", formatBytes(m.Alloc))
    log.Printf("  TotalAlloc: %s", formatBytes(m.TotalAlloc))
    log.Printf("  Sys: %s", formatBytes(m.Sys))
    log.Printf("  NumGC: %d", m.NumGC)
    log.Printf("  PauseTotalNs: %s", time.Duration(m.PauseTotalNs))
    
    if m.NumGC > 0 {
        recentPause := time.Duration(m.PauseNs[(m.NumGC+255)%256])
        log.Printf("  LastGC: %s ago, Pause: %s", 
            time.Since(time.Unix(0, int64(m.LastGC))), recentPause)
    }
}

func formatBytes(bytes uint64) string {
    const unit = 1024
    if bytes < unit {
        return fmt.Sprintf("%d B", bytes)
    }
    
    div, exp := uint64(unit), 0
    for n := bytes / unit; n >= unit; n /= unit {
        div *= unit
        exp++
    }
    
    return fmt.Sprintf("%.1f %cB", float64(bytes)/float64(div), "KMGTPE"[exp])
}

// Garbage collection profiling
func ProfileGC() {
    // Force GC and get stats before
    runtime.GC()
    var m1 runtime.MemStats
    runtime.ReadMemStats(&m1)
    
    start := time.Now()
    
    // Your code to profile
    performWorkload()
    
    // Force GC and get stats after
    runtime.GC()
    var m2 runtime.MemStats
    runtime.ReadMemStats(&m2)
    
    duration := time.Since(start)
    
    log.Printf("Workload completed in %v", duration)
    log.Printf("Memory allocated during workload: %s", 
        formatBytes(m2.TotalAlloc-m1.TotalAlloc))
    log.Printf("GC cycles during workload: %d", m2.NumGC-m1.NumGC)
}

// Allocation profiling
func ProfileAllocations(fn func()) (allocCount uint64, allocSize uint64) {
    var m1, m2 runtime.MemStats
    runtime.ReadMemStats(&m1)
    
    fn()
    
    runtime.ReadMemStats(&m2)
    
    return m2.Mallocs - m1.Mallocs, m2.TotalAlloc - m1.TotalAlloc
}
```

### Custom Profilers
Build domain-specific profilers for your application:

```go
// HTTP request profiler
type HTTPProfiler struct {
    requests     map[string]*RequestStats
    mu           sync.RWMutex
    sampleRate   float64
    maxSamples   int
}

type RequestStats struct {
    Path         string
    Method       string
    Count        int64
    TotalTime    time.Duration
    MinTime      time.Duration
    MaxTime      time.Duration
    Samples      []time.Duration
    LastAccessed time.Time
}

func NewHTTPProfiler(sampleRate float64, maxSamples int) *HTTPProfiler {
    return &HTTPProfiler{
        requests:   make(map[string]*RequestStats),
        sampleRate: sampleRate,
        maxSamples: maxSamples,
    }
}

func (hp *HTTPProfiler) Middleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        
        next.ServeHTTP(w, r)
        
        duration := time.Since(start)
        
        // Sample based on rate
        if rand.Float64() < hp.sampleRate {
            hp.recordRequest(r.Method, r.URL.Path, duration)
        }
    })
}

func (hp *HTTPProfiler) recordRequest(method, path string, duration time.Duration) {
    key := method + " " + path
    
    hp.mu.Lock()
    defer hp.mu.Unlock()
    
    stats, exists := hp.requests[key]
    if !exists {
        stats = &RequestStats{
            Path:    path,
            Method:  method,
            MinTime: duration,
            MaxTime: duration,
        }
        hp.requests[key] = stats
    }
    
    stats.Count++
    stats.TotalTime += duration
    stats.LastAccessed = time.Now()
    
    if duration < stats.MinTime {
        stats.MinTime = duration
    }
    if duration > stats.MaxTime {
        stats.MaxTime = duration
    }
    
    // Keep samples for percentile calculations
    if len(stats.Samples) < hp.maxSamples {
        stats.Samples = append(stats.Samples, duration)
    } else {
        // Replace random sample
        idx := rand.Intn(len(stats.Samples))
        stats.Samples[idx] = duration
    }
}

func (hp *HTTPProfiler) GetStats() map[string]*RequestStats {
    hp.mu.RLock()
    defer hp.mu.RUnlock()
    
    result := make(map[string]*RequestStats, len(hp.requests))
    for k, v := range hp.requests {
        // Deep copy
        statsCopy := *v
        statsCopy.Samples = make([]time.Duration, len(v.Samples))
        copy(statsCopy.Samples, v.Samples)
        result[k] = &statsCopy
    }
    
    return result
}

func (hp *HTTPProfiler) PrintSummary() {
    stats := hp.GetStats()
    
    log.Println("HTTP Request Profile Summary:")
    log.Println("==============================")
    
    for key, stat := range stats {
        avg := stat.TotalTime / time.Duration(stat.Count)
        
        log.Printf("%s:", key)
        log.Printf("  Count: %d", stat.Count)
        log.Printf("  Avg: %v", avg)
        log.Printf("  Min: %v", stat.MinTime)
        log.Printf("  Max: %v", stat.MaxTime)
        
        if len(stat.Samples) > 0 {
            p95 := hp.percentile(stat.Samples, 0.95)
            p99 := hp.percentile(stat.Samples, 0.99)
            log.Printf("  P95: %v", p95)
            log.Printf("  P99: %v", p99)
        }
        log.Println()
    }
}

func (hp *HTTPProfiler) percentile(samples []time.Duration, p float64) time.Duration {
    if len(samples) == 0 {
        return 0
    }
    
    sorted := make([]time.Duration, len(samples))
    copy(sorted, samples)
    sort.Slice(sorted, func(i, j int) bool {
        return sorted[i] < sorted[j]
    })
    
    index := int(float64(len(sorted)) * p)
    if index >= len(sorted) {
        index = len(sorted) - 1
    }
    
    return sorted[index]
}
```

## Benchmarking Best Practices

### Comprehensive Benchmarking
Write effective benchmarks for accurate performance measurement:

```go
import (
    "testing"
    "strings"
    "fmt"
)

// Multi-scenario benchmarking
func BenchmarkStringOperations(b *testing.B) {
    scenarios := []struct {
        name  string
        count int
    }{
        {"Small", 10},
        {"Medium", 100},
        {"Large", 1000},
        {"XLarge", 10000},
    }
    
    for _, scenario := range scenarios {
        b.Run(fmt.Sprintf("StringBuilder_%s", scenario.name), func(b *testing.B) {
            for i := 0; i < b.N; i++ {
                var sb strings.Builder
                sb.Grow(scenario.count * 10) // Pre-allocate capacity
                
                for j := 0; j < scenario.count; j++ {
                    sb.WriteString("test")
                }
                _ = sb.String()
            }
        })
        
        b.Run(fmt.Sprintf("StringConcat_%s", scenario.name), func(b *testing.B) {
            for i := 0; i < b.N; i++ {
                var result string
                for j := 0; j < scenario.count; j++ {
                    result += "test"
                }
                _ = result
            }
        })
        
        b.Run(fmt.Sprintf("ByteBuffer_%s", scenario.name), func(b *testing.B) {
            for i := 0; i < b.N; i++ {
                buf := make([]byte, 0, scenario.count*4)
                for j := 0; j < scenario.count; j++ {
                    buf = append(buf, "test"...)
                }
                _ = string(buf)
            }
        })
    }
}

// Benchmark with allocation reporting
func BenchmarkMapOperations(b *testing.B) {
    sizes := []int{10, 100, 1000, 10000}
    
    for _, size := range sizes {
        b.Run(fmt.Sprintf("PreallocatedMap_%d", size), func(b *testing.B) {
            b.ReportAllocs()
            for i := 0; i < b.N; i++ {
                m := make(map[string]int, size) // Pre-allocate
                for j := 0; j < size; j++ {
                    m[fmt.Sprintf("key%d", j)] = j
                }
            }
        })
        
        b.Run(fmt.Sprintf("GrowingMap_%d", size), func(b *testing.B) {
            b.ReportAllocs()
            for i := 0; i < b.N; i++ {
                m := make(map[string]int) // No pre-allocation
                for j := 0; j < size; j++ {
                    m[fmt.Sprintf("key%d", j)] = j
                }
            }
        })
    }
}

// Custom benchmarking with setup and teardown
func BenchmarkDatabaseOperations(b *testing.B) {
    // Setup - this time doesn't count
    db := setupTestDatabase()
    defer db.Close()
    
    testData := generateTestData(1000)
    
    b.ResetTimer() // Reset timer after setup
    b.ReportAllocs() // Report allocation statistics
    
    for i := 0; i < b.N; i++ {
        b.StopTimer() // Pause timer for per-iteration setup
        record := testData[i%len(testData)]
        b.StartTimer() // Resume timer
        
        err := db.Insert(record)
        if err != nil {
            b.Fatal(err)
        }
        
        b.StopTimer() // Pause for validation
        validateInsert(db, record) // Validation doesn't count toward benchmark
        b.StartTimer() // Resume timer
    }
}

// Parallel benchmarking
func BenchmarkConcurrentOperations(b *testing.B) {
    cache := NewThreadSafeCache()
    
    b.RunParallel(func(pb *testing.PB) {
        i := 0
        for pb.Next() {
            key := fmt.Sprintf("key%d", i%1000)
            value := fmt.Sprintf("value%d", i)
            
            // Mix of read and write operations
            if i%10 == 0 {
                cache.Set(key, value)
            } else {
                cache.Get(key)
            }
            i++
        }
    })
}
```

### Micro-benchmarking
Benchmark specific operations for optimization:

```go
// Benchmark different approaches to the same problem
func BenchmarkSliceCopy(b *testing.B) {
    data := make([]int, 10000)
    for i := range data {
        data[i] = i
    }
    
    b.Run("copy_builtin", func(b *testing.B) {
        for i := 0; i < b.N; i++ {
            dst := make([]int, len(data))
            copy(dst, data)
        }
    })
    
    b.Run("copy_loop", func(b *testing.B) {
        for i := 0; i < b.N; i++ {
            dst := make([]int, len(data))
            for j, v := range data {
                dst[j] = v
            }
        }
    })
    
    b.Run("copy_append", func(b *testing.B) {
        for i := 0; i < b.N; i++ {
            dst := make([]int, 0, len(data))
            dst = append(dst, data...)
        }
    })
}

// Benchmark with different input sizes
func BenchmarkSearch(b *testing.B) {
    sizes := []int{10, 100, 1000, 10000}
    
    for _, size := range sizes {
        data := generateSortedData(size)
        target := data[size/2] // Middle element
        
        b.Run(fmt.Sprintf("Linear_%d", size), func(b *testing.B) {
            for i := 0; i < b.N; i++ {
                linearSearch(data, target)
            }
        })
        
        b.Run(fmt.Sprintf("Binary_%d", size), func(b *testing.B) {
            for i := 0; i < b.N; i++ {
                binarySearch(data, target)
            }
        })
    }
}
```

## Performance Analysis Tools

### Custom Performance Counters
Build application-specific performance metrics:

```go
import (
    "sync/atomic"
    "time"
)

// Performance counter for tracking custom metrics
type PerformanceCounter struct {
    name       string
    count      int64
    totalTime  int64
    minTime    int64
    maxTime    int64
    startTimes map[int64]time.Time
    mu         sync.RWMutex
}

func NewPerformanceCounter(name string) *PerformanceCounter {
    return &PerformanceCounter{
        name:       name,
        minTime:    int64(time.Hour), // Initialize to high value
        startTimes: make(map[int64]time.Time),
    }
}

func (pc *PerformanceCounter) Start() int64 {
    id := time.Now().UnixNano()
    
    pc.mu.Lock()
    pc.startTimes[id] = time.Now()
    pc.mu.Unlock()
    
    return id
}

func (pc *PerformanceCounter) End(id int64) {
    pc.mu.Lock()
    start, exists := pc.startTimes[id]
    if !exists {
        pc.mu.Unlock()
        return
    }
    delete(pc.startTimes, id)
    pc.mu.Unlock()
    
    duration := time.Since(start)
    durationNs := int64(duration)
    
    atomic.AddInt64(&pc.count, 1)
    atomic.AddInt64(&pc.totalTime, durationNs)
    
    // Update min/max with atomic operations
    for {
        currentMin := atomic.LoadInt64(&pc.minTime)
        if durationNs >= currentMin {
            break
        }
        if atomic.CompareAndSwapInt64(&pc.minTime, currentMin, durationNs) {
            break
        }
    }
    
    for {
        currentMax := atomic.LoadInt64(&pc.maxTime)
        if durationNs <= currentMax {
            break
        }
        if atomic.CompareAndSwapInt64(&pc.maxTime, currentMax, durationNs) {
            break
        }
    }
}

func (pc *PerformanceCounter) Stats() (count int64, avg, min, max time.Duration) {
    count = atomic.LoadInt64(&pc.count)
    totalTime := atomic.LoadInt64(&pc.totalTime)
    minTime := atomic.LoadInt64(&pc.minTime)
    maxTime := atomic.LoadInt64(&pc.maxTime)
    
    if count > 0 {
        avg = time.Duration(totalTime / count)
    }
    
    min = time.Duration(minTime)
    max = time.Duration(maxTime)
    
    return
}

func (pc *PerformanceCounter) Reset() {
    atomic.StoreInt64(&pc.count, 0)
    atomic.StoreInt64(&pc.totalTime, 0)
    atomic.StoreInt64(&pc.minTime, int64(time.Hour))
    atomic.StoreInt64(&pc.maxTime, 0)
    
    pc.mu.Lock()
    pc.startTimes = make(map[int64]time.Time)
    pc.mu.Unlock()
}

// Usage example
func ExampleUsage() {
    counter := NewPerformanceCounter("database_query")
    
    id := counter.Start()
    performDatabaseQuery()
    counter.End(id)
    
    count, avg, min, max := counter.Stats()
    log.Printf("Query stats: count=%d, avg=%v, min=%v, max=%v", count, avg, min, max)
}
```

For memory and algorithm optimization techniques, see [Performance Optimization](performance-optimization.md). For concurrent performance patterns, see [Concurrency Advanced](concurrency-advanced.md).