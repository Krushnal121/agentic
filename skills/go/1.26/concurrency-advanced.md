# Advanced Concurrency Patterns

*Complex concurrency patterns for Go 1.26.x - worker pools, circuit breakers, streaming, and enterprise patterns*

## Worker Pool Patterns

### Basic Worker Pool
Implement controlled goroutine pools for resource management:

```go
import (
    "context"
    "sync"
)

// Basic worker pool implementation
type WorkerPool struct {
    workers   int
    workCh    chan func()
    ctx       context.Context
    cancel    context.CancelFunc
    wg        sync.WaitGroup
}

func NewWorkerPool(workers int) *WorkerPool {
    ctx, cancel := context.WithCancel(context.Background())
    
    wp := &WorkerPool{
        workers: workers,
        workCh:  make(chan func(), workers*2), // Buffer to prevent blocking
        ctx:     ctx,
        cancel:  cancel,
    }
    
    // Start worker goroutines
    for i := 0; i < workers; i++ {
        wp.wg.Add(1)
        go wp.worker()
    }
    
    return wp
}

func (wp *WorkerPool) worker() {
    defer wp.wg.Done()
    
    // Always recover from panics in worker goroutines
    defer func() {
        if r := recover(); r != nil {
            stack := debug.Stack()
            log.Printf("Worker panic recovered: %v\nStack trace:\n%s", r, stack)
            // DO NOT re-panic - this would bring down the entire pool
        }
    }()
    
    for {
        select {
        case <-wp.ctx.Done():
            return
        case work := <-wp.workCh:
            // Execute work with individual panic recovery
            func() {
                defer func() {
                    if r := recover(); r != nil {
                        log.Printf("Work function panic: %v\nStack: %s", r, debug.Stack())
                        // Continue processing other work items
                    }
                }()
                
                work()
            }()
        }
    }
}

func (wp *WorkerPool) Submit(work func()) bool {
    select {
    case wp.workCh <- work:
        return true
    case <-wp.ctx.Done():
        return false
    default:
        return false // Pool full
    }
}

func (wp *WorkerPool) Shutdown() {
    wp.cancel()
    wp.wg.Wait()
    close(wp.workCh)
}
```

### Buffered Processor with Worker Pool
Complex processing with buffering and dispatching:

```go
// Producer-consumer with buffered channels and workers
type BufferedProcessor struct {
    inputCh   chan Task
    outputCh  chan Result
    workerCh  chan Task
    workers   int
    ctx       context.Context
    cancel    context.CancelFunc
    wg        sync.WaitGroup
}

func NewBufferedProcessor(workers, bufferSize int) *BufferedProcessor {
    ctx, cancel := context.WithCancel(context.Background())
    
    bp := &BufferedProcessor{
        inputCh:  make(chan Task, bufferSize),
        outputCh: make(chan Result, bufferSize),
        workerCh: make(chan Task, bufferSize),
        workers:  workers,
        ctx:      ctx,
        cancel:   cancel,
    }
    
    // Start dispatcher
    bp.wg.Add(1)
    go bp.dispatcher()
    
    // Start workers
    for i := 0; i < workers; i++ {
        bp.wg.Add(1)
        go bp.worker()
    }
    
    return bp
}

func (bp *BufferedProcessor) dispatcher() {
    defer bp.wg.Done()
    defer close(bp.workerCh)
    
    for {
        select {
        case task := <-bp.inputCh:
            select {
            case bp.workerCh <- task:
                // Task dispatched
            case <-bp.ctx.Done():
                return
            }
        case <-bp.ctx.Done():
            return
        }
    }
}

func (bp *BufferedProcessor) worker() {
    defer bp.wg.Done()
    
    for {
        select {
        case task := <-bp.workerCh:
            result := processTask(task)
            
            select {
            case bp.outputCh <- result:
                // Result sent
            case <-bp.ctx.Done():
                return
            }
        case <-bp.ctx.Done():
            return
        }
    }
}

func (bp *BufferedProcessor) Submit(task Task) error {
    select {
    case bp.inputCh <- task:
        return nil
    case <-bp.ctx.Done():
        return bp.ctx.Err()
    }
}

func (bp *BufferedProcessor) Results() <-chan Result {
    return bp.outputCh
}

func (bp *BufferedProcessor) Shutdown() {
    bp.cancel()
    close(bp.inputCh)
    bp.wg.Wait()
    close(bp.outputCh)
}
```

## Circuit Breaker Pattern

### Circuit Breaker with Worker Pool Integration
Combine worker pools with circuit breaker for resilience:

```go
import (
    "errors"
    "time"
)

type CircuitState int

const (
    Closed CircuitState = iota
    Open
    HalfOpen
)

type CircuitBreaker struct {
    maxFailures  int
    resetTimeout time.Duration
    state        CircuitState
    failures     int
    lastFailTime time.Time
    mu           sync.RWMutex
}

func NewCircuitBreaker(maxFailures int, resetTimeout time.Duration) *CircuitBreaker {
    return &CircuitBreaker{
        maxFailures:  maxFailures,
        resetTimeout: resetTimeout,
        state:        Closed,
    }
}

func (cb *CircuitBreaker) Execute(operation func() error) error {
    if !cb.canExecute() {
        return errors.New("circuit breaker is open")
    }
    
    err := operation()
    cb.recordResult(err)
    return err
}

func (cb *CircuitBreaker) canExecute() bool {
    cb.mu.RLock()
    defer cb.mu.RUnlock()
    
    switch cb.state {
    case Closed:
        return true
    case Open:
        return time.Since(cb.lastFailTime) >= cb.resetTimeout
    case HalfOpen:
        return true
    default:
        return false
    }
}

func (cb *CircuitBreaker) recordResult(err error) {
    cb.mu.Lock()
    defer cb.mu.Unlock()
    
    if err != nil {
        cb.failures++
        cb.lastFailTime = time.Now()
        
        if cb.failures >= cb.maxFailures {
            cb.state = Open
        }
    } else {
        cb.failures = 0
        cb.state = Closed
    }
}

func (cb *CircuitBreaker) GetState() CircuitState {
    cb.mu.RLock()
    defer cb.mu.RUnlock()
    return cb.state
}

// Circuit breaker with panic recovery
func (cb *CircuitBreaker) ExecuteSafe(operation func() error) error {
    if !cb.canExecute() {
        return errors.New("circuit breaker is open")
    }
    
    var err error
    
    // Wrap operation with panic recovery
    func() {
        defer func() {
            if r := recover(); r != nil {
                stack := debug.Stack()
                err = fmt.Errorf("operation panicked: %v\nStack: %s", r, stack)
                log.Printf("Circuit breaker operation panic: %v", err)
            }
        }()
        
        err = operation()
    }()
    
    cb.recordResult(err)
    return err
}

// Worker pool with circuit breaker integration
type ResilientWorkerPool struct {
    workerPool     *WorkerPool
    circuitBreaker *CircuitBreaker
}

func NewResilientWorkerPool(workers int, maxFailures int, resetTimeout time.Duration) *ResilientWorkerPool {
    return &ResilientWorkerPool{
        workerPool:     NewWorkerPool(workers),
        circuitBreaker: NewCircuitBreaker(maxFailures, resetTimeout),
    }
}

func (rwp *ResilientWorkerPool) Execute(operation func() error) error {
    return rwp.circuitBreaker.ExecuteSafe(func() error {
        resultCh := make(chan error, 1)
        
        work := func() {
            resultCh <- operation()
        }
        
        if !rwp.workerPool.Submit(work) {
            return errors.New("worker pool full")
        }
        
        return <-resultCh
    })
}

func (rwp *ResilientWorkerPool) GetCircuitState() CircuitState {
    return rwp.circuitBreaker.GetState()
}

func (rwp *ResilientWorkerPool) Shutdown() {
    rwp.workerPool.Shutdown()
}
```

## Rate Limiting Patterns

### Rate-Limited Producer
Control production rate to prevent overwhelming downstream systems:

```go
import "golang.org/x/time/rate"

type RateLimitedProducer struct {
    limiter  *rate.Limiter
    outputCh chan<- Item
    ctx      context.Context
    cancel   context.CancelFunc
    wg       sync.WaitGroup
}

func NewRateLimitedProducer(rps int, burst int, outputCh chan<- Item) *RateLimitedProducer {
    ctx, cancel := context.WithCancel(context.Background())
    
    return &RateLimitedProducer{
        limiter:  rate.NewLimiter(rate.Limit(rps), burst),
        outputCh: outputCh,
        ctx:      ctx,
        cancel:   cancel,
    }
}

func (rlp *RateLimitedProducer) Start() {
    rlp.wg.Add(1)
    go rlp.produce()
}

func (rlp *RateLimitedProducer) produce() {
    defer rlp.wg.Done()
    
    ticker := time.NewTicker(100 * time.Millisecond)
    defer ticker.Stop()
    
    for {
        select {
        case <-rlp.ctx.Done():
            return
        case <-ticker.C:
            if rlp.limiter.Allow() {
                item := generateItem()
                
                select {
                case rlp.outputCh <- item:
                    // Item sent successfully
                case <-rlp.ctx.Done():
                    return
                }
            }
        }
    }
}

func (rlp *RateLimitedProducer) Stop() {
    rlp.cancel()
    rlp.wg.Wait()
}

// Adaptive rate limiting based on system load
type AdaptiveRateLimiter struct {
    baseLimiter    *rate.Limiter
    currentRate    rate.Limit
    targetLatency  time.Duration
    latencyTracker *LatencyTracker
    mu             sync.RWMutex
}

type LatencyTracker struct {
    samples    []time.Duration
    maxSamples int
    index      int
    mu         sync.Mutex
}

func NewAdaptiveRateLimiter(baseRate rate.Limit, burst int, targetLatency time.Duration) *AdaptiveRateLimiter {
    return &AdaptiveRateLimiter{
        baseLimiter:   rate.NewLimiter(baseRate, burst),
        currentRate:   baseRate,
        targetLatency: targetLatency,
        latencyTracker: &LatencyTracker{
            samples:    make([]time.Duration, 100),
            maxSamples: 100,
        },
    }
}

func (arl *AdaptiveRateLimiter) Allow() bool {
    arl.mu.RLock()
    defer arl.mu.RUnlock()
    return arl.baseLimiter.Allow()
}

func (arl *AdaptiveRateLimiter) RecordLatency(latency time.Duration) {
    arl.latencyTracker.Add(latency)
    avgLatency := arl.latencyTracker.Average()
    
    arl.mu.Lock()
    defer arl.mu.Unlock()
    
    if avgLatency > arl.targetLatency {
        // Reduce rate if latency is too high
        newRate := arl.currentRate * 0.9
        if newRate < rate.Limit(1) {
            newRate = rate.Limit(1)
        }
        arl.currentRate = newRate
        arl.baseLimiter.SetLimit(newRate)
    } else if avgLatency < arl.targetLatency/2 {
        // Increase rate if latency is low
        newRate := arl.currentRate * 1.1
        arl.currentRate = newRate
        arl.baseLimiter.SetLimit(newRate)
    }
}

func (lt *LatencyTracker) Add(latency time.Duration) {
    lt.mu.Lock()
    defer lt.mu.Unlock()
    
    lt.samples[lt.index] = latency
    lt.index = (lt.index + 1) % lt.maxSamples
}

func (lt *LatencyTracker) Average() time.Duration {
    lt.mu.Lock()
    defer lt.mu.Unlock()
    
    var total time.Duration
    count := 0
    
    for _, sample := range lt.samples {
        if sample > 0 {
            total += sample
            count++
        }
    }
    
    if count == 0 {
        return 0
    }
    
    return total / time.Duration(count)
}
```

## Streaming and Batch Processing

### Memory-Efficient Stream Processor
Process large datasets with bounded memory usage:

```go
type StreamProcessor struct {
    batchSize int
    processor func([]Item) error
    inputCh   <-chan Item
    outputCh  chan<- Result
    ctx       context.Context
    cancel    context.CancelFunc
    wg        sync.WaitGroup
}

func NewStreamProcessor(batchSize int, processor func([]Item) error, inputCh <-chan Item, outputCh chan<- Result) *StreamProcessor {
    ctx, cancel := context.WithCancel(context.Background())
    
    return &StreamProcessor{
        batchSize: batchSize,
        processor: processor,
        inputCh:   inputCh,
        outputCh:  outputCh,
        ctx:       ctx,
        cancel:    cancel,
    }
}

func (sp *StreamProcessor) Start() {
    sp.wg.Add(1)
    go sp.process()
}

func (sp *StreamProcessor) process() {
    defer sp.wg.Done()
    
    batch := make([]Item, 0, sp.batchSize)
    timer := time.NewTimer(time.Second) // Flush batch every second
    timer.Stop()
    
    defer func() {
        if len(batch) > 0 {
            sp.processBatch(batch)
        }
    }()
    
    for {
        select {
        case item, ok := <-sp.inputCh:
            if !ok {
                return // Input channel closed
            }
            
            batch = append(batch, item)
            
            if len(batch) == 1 {
                timer.Reset(time.Second)
            }
            
            if len(batch) >= sp.batchSize {
                sp.processBatch(batch)
                batch = batch[:0] // Reset slice but keep capacity
                timer.Stop()
            }
            
        case <-timer.C:
            if len(batch) > 0 {
                sp.processBatch(batch)
                batch = batch[:0]
            }
            
        case <-sp.ctx.Done():
            return
        }
    }
}

func (sp *StreamProcessor) processBatch(batch []Item) {
    if err := sp.processor(batch); err != nil {
        log.Printf("Batch processing error: %v", err)
        return
    }
    
    result := Result{ProcessedCount: len(batch)}
    
    select {
    case sp.outputCh <- result:
        // Result sent
    case <-sp.ctx.Done():
        // Context cancelled
    }
}

func (sp *StreamProcessor) Wait() {
    sp.wg.Wait()
}

func (sp *StreamProcessor) Stop() {
    sp.cancel()
    sp.wg.Wait()
}
```

### Parallel Stream Processing
Process multiple streams concurrently with coordination:

```go
// Multi-stream processor with coordination
type MultiStreamProcessor struct {
    processors []*StreamProcessor
    merger     *StreamMerger
    ctx        context.Context
    cancel     context.CancelFunc
    wg         sync.WaitGroup
}

type StreamMerger struct {
    inputs   []<-chan Result
    outputCh chan<- Result
    ctx      context.Context
    wg       sync.WaitGroup
}

func NewMultiStreamProcessor(streamCount int, batchSize int, processor func([]Item) error) *MultiStreamProcessor {
    ctx, cancel := context.WithCancel(context.Background())
    
    msp := &MultiStreamProcessor{
        processors: make([]*StreamProcessor, streamCount),
        ctx:        ctx,
        cancel:     cancel,
    }
    
    // Create result channels for each processor
    resultChannels := make([]<-chan Result, streamCount)
    for i := 0; i < streamCount; i++ {
        inputCh := make(chan Item, batchSize)
        outputCh := make(chan Result, batchSize)
        
        msp.processors[i] = NewStreamProcessor(batchSize, processor, inputCh, outputCh)
        resultChannels[i] = outputCh
    }
    
    // Create merger for combining results
    finalOutput := make(chan Result, batchSize)
    msp.merger = NewStreamMerger(resultChannels, finalOutput)
    
    return msp
}

func NewStreamMerger(inputs []<-chan Result, output chan<- Result) *StreamMerger {
    return &StreamMerger{
        inputs:   inputs,
        outputCh: output,
        ctx:      context.Background(),
    }
}

func (sm *StreamMerger) Start() {
    sm.wg.Add(1)
    go sm.merge()
}

func (sm *StreamMerger) merge() {
    defer sm.wg.Done()
    defer close(sm.outputCh)
    
    var wg sync.WaitGroup
    
    // Start goroutine for each input stream
    for _, input := range sm.inputs {
        wg.Add(1)
        go func(ch <-chan Result) {
            defer wg.Done()
            
            for result := range ch {
                select {
                case sm.outputCh <- result:
                    // Result forwarded
                case <-sm.ctx.Done():
                    return
                }
            }
        }(input)
    }
    
    wg.Wait()
}

func (msp *MultiStreamProcessor) Start() {
    // Start all stream processors
    for _, processor := range msp.processors {
        processor.Start()
    }
    
    // Start result merger
    msp.merger.Start()
}

func (msp *MultiStreamProcessor) Stop() {
    // Stop all processors
    for _, processor := range msp.processors {
        processor.Stop()
    }
    
    // Wait for merger
    msp.merger.wg.Wait()
    msp.cancel()
}

func (msp *MultiStreamProcessor) GetProcessor(index int) *StreamProcessor {
    if index >= 0 && index < len(msp.processors) {
        return msp.processors[index]
    }
    return nil
}
```

For basic goroutine and channel patterns, see [Concurrency Basics](concurrency-basics.md). For synchronization primitives, see [Concurrency Sync](concurrency-sync.md). For performance optimization of concurrent code, see [Performance Optimization](performance-optimization.md).