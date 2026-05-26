# Concurrency Synchronization

*Synchronization primitives and patterns for Go 1.26.x - mutexes, atomics, and condition variables*

## Mutex Patterns

### Read-Write Mutex for Read-Heavy Workloads
Use `sync.RWMutex` when reads significantly outnumber writes:

```go
import (
    "hash/fnv"
    "sync"
)

// Basic read-write mutex cache
type CacheService struct {
    data map[string]any
    mu   sync.RWMutex
}

func NewCacheService() *CacheService {
    return &CacheService{
        data: make(map[string]any),
    }
}

func (cs *CacheService) Get(key string) (any, bool) {
    cs.mu.RLock()
    defer cs.mu.RUnlock()
    
    value, exists := cs.data[key]
    return value, exists
}

func (cs *CacheService) Set(key string, value any) {
    cs.mu.Lock()
    defer cs.mu.Unlock()
    
    cs.data[key] = value
}

func (cs *CacheService) Delete(key string) {
    cs.mu.Lock()
    defer cs.mu.Unlock()
    
    delete(cs.data, key)
}

// Optimize lock contention with local copies
func (cs *CacheService) GetMultiple(keys []string) map[string]any {
    cs.mu.RLock()
    
    // Create local copy to minimize lock time
    result := make(map[string]any, len(keys))
    for _, key := range keys {
        if value, exists := cs.data[key]; exists {
            result[key] = value
        }
    }
    
    cs.mu.RUnlock()
    return result
}

// Bulk operations to reduce lock overhead
func (cs *CacheService) SetMultiple(items map[string]any) {
    cs.mu.Lock()
    defer cs.mu.Unlock()
    
    for key, value := range items {
        cs.data[key] = value
    }
}
```

### Fine-Grained Locking with Sharding
Reduce contention by sharding data across multiple mutexes:

```go
// Sharded cache for high-concurrency scenarios
type ShardedCache struct {
    shards   []*shard
    shardNum uint64
}

type shard struct {
    data map[string]any
    mu   sync.RWMutex
}

func NewShardedCache(shardCount int) *ShardedCache {
    shards := make([]*shard, shardCount)
    for i := 0; i < shardCount; i++ {
        shards[i] = &shard{
            data: make(map[string]any),
        }
    }
    
    return &ShardedCache{
        shards:   shards,
        shardNum: uint64(shardCount),
    }
}

func (sc *ShardedCache) getShard(key string) *shard {
    hash := fnv.New64a()
    hash.Write([]byte(key))
    return sc.shards[hash.Sum64()%sc.shardNum]
}

func (sc *ShardedCache) Get(key string) (any, bool) {
    shard := sc.getShard(key)
    shard.mu.RLock()
    defer shard.mu.RUnlock()
    
    value, exists := shard.data[key]
    return value, exists
}

func (sc *ShardedCache) Set(key string, value any) {
    shard := sc.getShard(key)
    shard.mu.Lock()
    defer shard.mu.Unlock()
    
    shard.data[key] = value
}

func (sc *ShardedCache) Delete(key string) {
    shard := sc.getShard(key)
    shard.mu.Lock()
    defer shard.mu.Unlock()
    
    delete(shard.data, key)
}

// Cross-shard operations (use with caution)
func (sc *ShardedCache) Size() int {
    total := 0
    
    // Lock all shards in order to prevent deadlock
    for i := range sc.shards {
        sc.shards[i].mu.RLock()
    }
    defer func() {
        for i := range sc.shards {
            sc.shards[i].mu.RUnlock()
        }
    }()
    
    for _, shard := range sc.shards {
        total += len(shard.data)
    }
    
    return total
}
```

### Mutex Best Practices
Avoid common mutex pitfalls:

```go
// Good: minimize critical section
func (cs *CacheService) ProcessAndCache(key string, processor func(any) any) {
    // First, check if processing is needed (read lock)
    cs.mu.RLock()
    existing, exists := cs.data[key]
    cs.mu.RUnlock()
    
    if exists {
        return // No processing needed
    }
    
    // Do expensive work outside the lock
    processed := processor(nil)
    
    // Then write (write lock)
    cs.mu.Lock()
    // Double-check after acquiring write lock
    if _, exists := cs.data[key]; !exists {
        cs.data[key] = processed
    }
    cs.mu.Unlock()
}

// Bad: holding lock during expensive operation
func (cs *CacheService) ProcessAndCacheBad(key string, processor func(any) any) {
    cs.mu.Lock()
    defer cs.mu.Unlock() // Lock held for entire duration
    
    if existing, exists := cs.data[key]; exists {
        return
    }
    
    // Expensive work while holding lock - BAD!
    processed := processor(nil)
    cs.data[key] = processed
}

// Deadlock prevention: consistent lock ordering
type MultiCache struct {
    cache1 *CacheService
    cache2 *CacheService
}

func (mc *MultiCache) Transfer(key string) {
    // Always acquire locks in consistent order
    // Use memory address to determine order
    first, second := mc.cache1, mc.cache2
    if uintptr(unsafe.Pointer(first)) > uintptr(unsafe.Pointer(second)) {
        first, second = second, first
    }
    
    first.mu.Lock()
    defer first.mu.Unlock()
    
    second.mu.Lock()
    defer second.mu.Unlock()
    
    // Perform transfer
    if value, exists := mc.cache1.data[key]; exists {
        mc.cache2.data[key] = value
        delete(mc.cache1.data, key)
    }
}
```

## Atomic Operations

### Atomic Counters for Metrics
Use atomic operations for simple shared state without mutex overhead:

```go
import "sync/atomic"

// Metrics with atomic operations
type Metrics struct {
    requests    int64
    errors      int64
    totalTime   int64
    activeUsers int64
}

func (m *Metrics) IncrementRequests() {
    atomic.AddInt64(&m.requests, 1)
}

func (m *Metrics) IncrementErrors() {
    atomic.AddInt64(&m.errors, 1)
}

func (m *Metrics) AddProcessingTime(duration time.Duration) {
    atomic.AddInt64(&m.totalTime, int64(duration))
}

func (m *Metrics) AddActiveUser() {
    atomic.AddInt64(&m.activeUsers, 1)
}

func (m *Metrics) RemoveActiveUser() {
    atomic.AddInt64(&m.activeUsers, -1)
}

func (m *Metrics) GetSnapshot() (int64, int64, time.Duration, int64) {
    requests := atomic.LoadInt64(&m.requests)
    errors := atomic.LoadInt64(&m.errors)
    totalTime := time.Duration(atomic.LoadInt64(&m.totalTime))
    activeUsers := atomic.LoadInt64(&m.activeUsers)
    
    return requests, errors, totalTime, activeUsers
}

func (m *Metrics) Reset() {
    atomic.StoreInt64(&m.requests, 0)
    atomic.StoreInt64(&m.errors, 0)
    atomic.StoreInt64(&m.totalTime, 0)
    // Note: activeUsers typically not reset
}
```

### Atomic Flags and State Management
Use atomic operations for flags and simple state:

```go
// Atomic flag for graceful shutdown
type Server struct {
    shutdownFlag int64
    startedFlag  int64
    // other fields
}

func (s *Server) Start() bool {
    if !atomic.CompareAndSwapInt64(&s.startedFlag, 0, 1) {
        return false // Already started
    }
    
    // Start server logic
    go s.run()
    return true
}

func (s *Server) Shutdown() {
    atomic.StoreInt64(&s.shutdownFlag, 1)
}

func (s *Server) IsShutdown() bool {
    return atomic.LoadInt64(&s.shutdownFlag) != 0
}

func (s *Server) IsStarted() bool {
    return atomic.LoadInt64(&s.startedFlag) != 0
}

func (s *Server) run() {
    for !s.IsShutdown() {
        request := s.getNextRequest()
        if request != nil {
            s.processRequest(request)
        }
        
        time.Sleep(10 * time.Millisecond)
    }
}
```

### Lock-Free Data Structures
Use compare-and-swap for lock-free operations:

```go
// Lock-free counter
type LockFreeCounter struct {
    value int64
}

func (lfc *LockFreeCounter) Increment() int64 {
    for {
        old := atomic.LoadInt64(&lfc.value)
        new := old + 1
        if atomic.CompareAndSwapInt64(&lfc.value, old, new) {
            return new
        }
        // CAS failed, retry
    }
}

func (lfc *LockFreeCounter) Add(delta int64) int64 {
    for {
        old := atomic.LoadInt64(&lfc.value)
        new := old + delta
        if atomic.CompareAndSwapInt64(&lfc.value, old, new) {
            return new
        }
    }
}

func (lfc *LockFreeCounter) Get() int64 {
    return atomic.LoadInt64(&lfc.value)
}

// Lock-free stack (simple version)
type LockFreeStack struct {
    head unsafe.Pointer
}

type stackNode struct {
    value any
    next  unsafe.Pointer
}

func (s *LockFreeStack) Push(value any) {
    node := &stackNode{value: value}
    
    for {
        head := atomic.LoadPointer(&s.head)
        node.next = head
        
        if atomic.CompareAndSwapPointer(&s.head, head, unsafe.Pointer(node)) {
            break
        }
    }
}

func (s *LockFreeStack) Pop() (any, bool) {
    for {
        head := atomic.LoadPointer(&s.head)
        if head == nil {
            return nil, false
        }
        
        node := (*stackNode)(head)
        next := atomic.LoadPointer(&node.next)
        
        if atomic.CompareAndSwapPointer(&s.head, head, next) {
            return node.value, true
        }
    }
}
```

## Condition Variables

### Producer-Consumer with Condition Variables
Use `sync.Cond` for complex coordination scenarios:

```go
// Bounded queue with condition variables
type BoundedQueue struct {
    items    []any
    capacity int
    mutex    sync.Mutex
    notFull  *sync.Cond
    notEmpty *sync.Cond
}

func NewBoundedQueue(capacity int) *BoundedQueue {
    bq := &BoundedQueue{
        items:    make([]any, 0, capacity),
        capacity: capacity,
    }
    
    bq.notFull = sync.NewCond(&bq.mutex)
    bq.notEmpty = sync.NewCond(&bq.mutex)
    
    return bq
}

func (bq *BoundedQueue) Put(item any) {
    bq.mutex.Lock()
    defer bq.mutex.Unlock()
    
    // Wait for space
    for len(bq.items) == bq.capacity {
        bq.notFull.Wait()
    }
    
    bq.items = append(bq.items, item)
    bq.notEmpty.Broadcast() // Wake up consumers
}

func (bq *BoundedQueue) Take() any {
    bq.mutex.Lock()
    defer bq.mutex.Unlock()
    
    // Wait for item
    for len(bq.items) == 0 {
        bq.notEmpty.Wait()
    }
    
    item := bq.items[0]
    bq.items = bq.items[1:]
    bq.notFull.Broadcast() // Wake up producers
    
    return item
}

func (bq *BoundedQueue) TryPut(item any) bool {
    bq.mutex.Lock()
    defer bq.mutex.Unlock()
    
    if len(bq.items) == bq.capacity {
        return false
    }
    
    bq.items = append(bq.items, item)
    bq.notEmpty.Broadcast()
    return true
}

func (bq *BoundedQueue) TryTake() (any, bool) {
    bq.mutex.Lock()
    defer bq.mutex.Unlock()
    
    if len(bq.items) == 0 {
        return nil, false
    }
    
    item := bq.items[0]
    bq.items = bq.items[1:]
    bq.notFull.Broadcast()
    return item, true
}

func (bq *BoundedQueue) Size() int {
    bq.mutex.Lock()
    defer bq.mutex.Unlock()
    
    return len(bq.items)
}
```

### Barrier Synchronization
Coordinate multiple goroutines to reach synchronization points:

```go
// Barrier for synchronizing multiple goroutines
type Barrier struct {
    required int
    current  int
    mutex    sync.Mutex
    cond     *sync.Cond
    generation int
}

func NewBarrier(required int) *Barrier {
    b := &Barrier{
        required: required,
    }
    b.cond = sync.NewCond(&b.mutex)
    return b
}

func (b *Barrier) Wait() {
    b.mutex.Lock()
    defer b.mutex.Unlock()
    
    generation := b.generation
    b.current++
    
    if b.current == b.required {
        // Last goroutine arrived, wake up all others
        b.current = 0
        b.generation++
        b.cond.Broadcast()
    } else {
        // Wait for other goroutines
        for generation == b.generation {
            b.cond.Wait()
        }
    }
}

// Usage example
func ParallelPhases(workers int, phases []func(int)) {
    barrier := NewBarrier(workers)
    var wg sync.WaitGroup
    
    for i := 0; i < workers; i++ {
        wg.Add(1)
        go func(workerID int) {
            defer wg.Done()
            
            for phaseNum, phase := range phases {
                // Execute phase
                phase(workerID)
                
                // Wait for all workers to complete this phase
                log.Printf("Worker %d completed phase %d", workerID, phaseNum)
                barrier.Wait()
                log.Printf("Worker %d proceeding to next phase", workerID)
            }
        }(i)
    }
    
    wg.Wait()
}
```

## Advanced Synchronization Patterns

### Read-Write Lock with Upgrade
Implement upgradeable read locks for complex scenarios:

```go
type UpgradeableRWMutex struct {
    mu       sync.RWMutex
    upgrades map[int64]bool
    upgradeID int64
    upgradeMu sync.Mutex
}

func NewUpgradeableRWMutex() *UpgradeableRWMutex {
    return &UpgradeableRWMutex{
        upgrades: make(map[int64]bool),
    }
}

func (u *UpgradeableRWMutex) RLock() int64 {
    u.mu.RLock()
    
    u.upgradeMu.Lock()
    id := u.upgradeID
    u.upgradeID++
    u.upgrades[id] = true
    u.upgradeMu.Unlock()
    
    return id
}

func (u *UpgradeableRWMutex) RUnlock(id int64) {
    u.upgradeMu.Lock()
    delete(u.upgrades, id)
    u.upgradeMu.Unlock()
    
    u.mu.RUnlock()
}

func (u *UpgradeableRWMutex) Upgrade(id int64) bool {
    u.upgradeMu.Lock()
    if !u.upgrades[id] {
        u.upgradeMu.Unlock()
        return false // Invalid ID or already upgraded
    }
    delete(u.upgrades, id)
    u.upgradeMu.Unlock()
    
    u.mu.RUnlock() // Release read lock
    u.mu.Lock()    // Acquire write lock
    return true
}

func (u *UpgradeableRWMutex) Unlock() {
    u.mu.Unlock()
}
```

For basic goroutine and channel patterns, see [Concurrency Basics](concurrency-basics.md). For complex worker pools and streaming, see [Concurrency Advanced](concurrency-advanced.md). For performance implications of synchronization, see [Performance Optimization](performance-optimization.md).