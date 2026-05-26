# Concurrency Basics

*Essential goroutine and channel patterns for Go 1.26.x following the Go Memory Model*

## Goroutine Management

### Goroutine Lifecycle and Resource Management
Always manage goroutine lifecycle explicitly:

```go
import (
    "context"
    "sync"
)

// Context-aware goroutine management
func ManagedWorker(ctx context.Context, workCh <-chan Work, resultCh chan<- Result) {
    defer close(resultCh) // Always clean up
    
    for {
        select {
        case <-ctx.Done():
            return // Respect cancellation
        case work, ok := <-workCh:
            if !ok {
                return // Channel closed
            }
            
            result := processWork(work)
            
            select {
            case resultCh <- result:
                // Result sent successfully
            case <-ctx.Done():
                return // Context cancelled while sending
            }
        }
    }
}

// WaitGroup pattern for coordinating multiple goroutines
func ProcessConcurrently(items []Item) []Result {
    var wg sync.WaitGroup
    resultCh := make(chan Result, len(items))
    
    for _, item := range items {
        wg.Add(1)
        go func(item Item) {
            defer wg.Done()
            result := processItem(item)
            resultCh <- result
        }(item) // Capture loop variable
    }
    
    // Close channel when all workers complete
    go func() {
        wg.Wait()
        close(resultCh)
    }()
    
    // Collect results
    var results []Result
    for result := range resultCh {
        results = append(results, result)
    }
    
    return results
}
```

### Panic Recovery in Goroutines
Always handle panics in goroutines to prevent server crashes:

```go
import (
    "fmt"
    "runtime"
    "runtime/debug"
)

// Safe goroutine wrapper with panic recovery
func SafeGoroutine(name string, fn func() error, errorHandler func(error)) {
    go func() {
        defer func() {
            if r := recover(); r != nil {
                // Create error from panic
                err := fmt.Errorf("panic in goroutine %s: %v\nstack trace:\n%s", 
                    name, r, debug.Stack())
                
                // Log the panic with full context
                log.Printf("PANIC RECOVERED: %v", err)
                
                // Propagate to error handler if provided
                if errorHandler != nil {
                    errorHandler(err)
                }
                
                // DO NOT re-panic - this would crash the server
                // panic(r) // NEVER do this
            }
        }()
        
        // Execute the function and handle errors
        if err := fn(); err != nil {
            log.Printf("Error in goroutine %s: %v", name, err)
            if errorHandler != nil {
                errorHandler(err)
            }
        }
    }()
}

// Error aggregation for multiple goroutines
type ErrorCollector struct {
    errors []error
    mu     sync.Mutex
}

func (ec *ErrorCollector) Add(err error) {
    if err == nil {
        return
    }
    
    ec.mu.Lock()
    defer ec.mu.Unlock()
    ec.errors = append(ec.errors, err)
}

func (ec *ErrorCollector) Errors() []error {
    ec.mu.Lock()
    defer ec.mu.Unlock()
    
    if len(ec.errors) == 0 {
        return nil
    }
    
    // Return copy to avoid race conditions
    errors := make([]error, len(ec.errors))
    copy(errors, ec.errors)
    return errors
}

func (ec *ErrorCollector) HasErrors() bool {
    ec.mu.Lock()
    defer ec.mu.Unlock()
    return len(ec.errors) > 0
}

// Safe concurrent processing with error collection
func ProcessConcurrentlySafe(items []Item) ([]Result, []error) {
    var wg sync.WaitGroup
    resultCh := make(chan Result, len(items))
    errorCollector := &ErrorCollector{}
    
    for i, item := range items {
        wg.Add(1)
        
        // Use SafeGoroutine for each worker
        SafeGoroutine(
            fmt.Sprintf("processor-%d", i),
            func() error {
                defer wg.Done()
                
                result, err := processItemSafe(item)
                if err != nil {
                    return fmt.Errorf("process item %v: %w", item, err)
                }
                
                select {
                case resultCh <- result:
                    return nil
                default:
                    return errors.New("result channel full")
                }
            },
            errorCollector.Add,
        )
    }
    
    // Close channel when all workers complete
    go func() {
        wg.Wait()
        close(resultCh)
    }()
    
    // Collect results
    var results []Result
    for result := range resultCh {
        results = append(results, result)
    }
    
    return results, errorCollector.Errors()
}
```

### Goroutine Leak Prevention
Prevent common causes of goroutine leaks:

```go
// Always provide cancellation mechanism
func AvoidLeaks() {
    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel() // Always clean up
    
    // Use context in all blocking operations
    resultCh := make(chan Result, 1)
    
    go func() {
        select {
        case resultCh <- expensiveOperation():
            // Operation completed
        case <-ctx.Done():
            // Operation cancelled
        }
    }()
    
    select {
    case result := <-resultCh:
        processResult(result)
    case <-ctx.Done():
        log.Printf("Operation timed out: %v", ctx.Err())
    }
}

// Proper channel closure to prevent leaks
func ProducerConsumerPattern() {
    dataCh := make(chan Data, 100)
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()
    
    // Producer
    go func() {
        defer close(dataCh) // Producer closes channel
        
        for i := 0; i < 1000; i++ {
            data := generateData(i)
            
            select {
            case dataCh <- data:
                // Data sent
            case <-ctx.Done():
                return // Cancelled
            }
        }
    }()
    
    // Consumer
    for data := range dataCh { // Range automatically handles channel closure
        processData(data)
    }
}
```

## Channel Communication Patterns

### Basic Channel Patterns
Use channels for goroutine communication following Go's philosophy:

```go
// Pipeline pattern for data processing
func Pipeline(input <-chan Data) <-chan ProcessedData {
    output := make(chan ProcessedData)
    
    go func() {
        defer close(output)
        
        for data := range input {
            processed := processData(data)
            output <- processed
        }
    }()
    
    return output
}

// Fan-out pattern for parallel processing
func FanOut(input <-chan Work, workers int) []<-chan Result {
    outputs := make([]<-chan Result, workers)
    
    for i := 0; i < workers; i++ {
        output := make(chan Result)
        outputs[i] = output
        
        go func(out chan<- Result) {
            defer close(out)
            
            for work := range input {
                result := processWork(work)
                out <- result
            }
        }(output)
    }
    
    return outputs
}

// Fan-in pattern for collecting results
func FanIn(inputs ...<-chan Result) <-chan Result {
    output := make(chan Result)
    var wg sync.WaitGroup
    
    // Start goroutine for each input channel
    for _, input := range inputs {
        wg.Add(1)
        go func(ch <-chan Result) {
            defer wg.Done()
            for result := range ch {
                output <- result
            }
        }(input)
    }
    
    // Close output when all inputs are exhausted
    go func() {
        wg.Wait()
        close(output)
    }()
    
    return output
}

// Select pattern for non-blocking operations
func SelectPatterns() {
    ch1 := make(chan string)
    ch2 := make(chan string)
    timeout := time.After(5 * time.Second)
    
    for {
        select {
        case msg1 := <-ch1:
            log.Printf("Received from ch1: %s", msg1)
            
        case msg2 := <-ch2:
            log.Printf("Received from ch2: %s", msg2)
            
        case <-timeout:
            log.Println("Timeout reached")
            return
            
        default:
            // Non-blocking operation when no channels are ready
            time.Sleep(100 * time.Millisecond)
        }
    }
}
```

### Buffered Channels for Performance
Use buffered channels strategically for performance and decoupling:

```go
// Buffered channel sizing guidelines
func OptimalChannelSizing() {
    // For producer-consumer with known capacity
    batchSize := 100
    dataCh := make(chan Data, batchSize) // Match processing batch size
    
    // For fan-out to multiple workers
    workers := 10
    workCh := make(chan Work, workers*2) // 2x workers for smooth flow
    
    // For results collection
    resultCh := make(chan Result, workers) // Match number of producers
    
    // For synchronization signals
    doneCh := make(chan struct{}) // Unbuffered for synchronization
}

// Producer-consumer with optimal buffering
func BufferedProcessing(items []Item) []Result {
    const batchSize = 50
    itemCh := make(chan Item, batchSize)
    resultCh := make(chan Result, batchSize)
    
    // Producer
    go func() {
        defer close(itemCh)
        for _, item := range items {
            itemCh <- item
        }
    }()
    
    // Consumer
    go func() {
        defer close(resultCh)
        
        batch := make([]Item, 0, batchSize)
        
        for item := range itemCh {
            batch = append(batch, item)
            
            if len(batch) == batchSize {
                results := processBatch(batch)
                for _, result := range results {
                    resultCh <- result
                }
                batch = batch[:0] // Reset but keep capacity
            }
        }
        
        // Process remaining items
        if len(batch) > 0 {
            results := processBatch(batch)
            for _, result := range results {
                resultCh <- result
            }
        }
    }()
    
    // Collect results
    var results []Result
    for result := range resultCh {
        results = append(results, result)
    }
    
    return results
}
```

### Context Integration
Always integrate context for cancellation and timeouts:

```go
// Context-aware channel operations
func ContextAwareProcessing(ctx context.Context, data []Data) <-chan Result {
    resultCh := make(chan Result)
    
    go func() {
        defer close(resultCh)
        
        for _, item := range data {
            select {
            case <-ctx.Done():
                log.Printf("Processing cancelled: %v", ctx.Err())
                return
            default:
            }
            
            result := processDataItem(item)
            
            select {
            case resultCh <- result:
                // Result sent successfully
            case <-ctx.Done():
                log.Printf("Context cancelled while sending result: %v", ctx.Err())
                return
            }
        }
    }()
    
    return resultCh
}

// Timeout-based processing
func ProcessWithTimeout(items []Item, timeout time.Duration) ([]Result, error) {
    ctx, cancel := context.WithTimeout(context.Background(), timeout)
    defer cancel()
    
    resultCh := ContextAwareProcessing(ctx, items)
    
    var results []Result
    for {
        select {
        case result, ok := <-resultCh:
            if !ok {
                return results, nil // Channel closed normally
            }
            results = append(results, result)
            
        case <-ctx.Done():
            return results, fmt.Errorf("processing timeout: %w", ctx.Err())
        }
    }
}
```

For advanced synchronization patterns, see [Concurrency Sync](concurrency-sync.md). For complex worker pools and streaming patterns, see [Concurrency Advanced](concurrency-advanced.md). For performance optimization of concurrent code, see [Performance Optimization](performance-optimization.md).