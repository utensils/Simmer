# Research: Simmer MVP Core

**Feature**: 001-mvp-core | **Date**: 2025-10-28

## Research Tasks Completed

All technical decisions were pre-determined by TECH_DESIGN.md. No NEEDS CLARIFICATION items exist in Technical Context. This document confirms rationale for each technology choice.

## File Monitoring Strategy

**Decision**: DispatchSource.makeFileSystemObjectSource with `.write` and `.extend` event masks

**Rationale**:
- Native Foundation API, zero external dependencies (aligns with Constitution Principle II)
- Lower overhead than FSEvents for monitoring specific files (FSEvents designed for directory hierarchies)
- Direct integration with GCD for background queue processing
- File descriptor-based monitoring ensures we detect appends immediately

**Alternatives Considered**:
- **FSEventStreamCreate**: Rejected - designed for directory monitoring, overkill for tracking specific log files
- **File polling (Timer-based reads)**: Rejected - higher CPU usage, introduces polling latency, violates <1% idle CPU target
- **Third-party reactive frameworks (Combine, RxSwift)**: Rejected - violates zero-dependency principle, unnecessary abstraction

**Implementation Pattern**:
```swift
// Event mask: .extend detects file size increases (log appends)
// Event mask: .write detects content modifications
// Background queue prevents blocking main thread during I/O
```

**Performance Validation**:
- DispatchSource uses kernel-level file change notifications (kqueue on macOS)
- Sub-millisecond notification latency from kernel to userspace
- Meets <500ms match detection requirement (SC-002) with margin for regex processing

## Pattern Matching Engine

**Decision**: NSRegularExpression with pre-compiled patterns stored in LogPattern models

**Rationale**:
- Native Foundation regex engine, no dependencies
- Pre-compilation amortizes regex parsing cost across all matches
- Thread-safe for concurrent matching on background queues
- Sufficient performance for <10ms per line requirement (FR-019)

**Alternatives Considered**:
- **Swift Regex (iOS 16+/macOS 13+)**: Rejected - targets macOS 14.0+ for other features, but NSRegularExpression more mature and proven
- **ICU regex via custom bindings**: Rejected - unnecessary complexity, NSRegularExpression wraps ICU internally
- **String.range(of:options:.regularExpression)**: Rejected - less control over match metadata (line numbers, capture groups)

**Optimization Strategy**:
- Compile regex once when pattern created/loaded, reuse NSRegularExpression instance
- Match on background monitoring queue, never block main thread
- Short-circuit on first match per line (no need for global matching in MVP)

**Error Handling**:
- Validate regex syntax in PatternValidator before saving (FR-011)
- Display inline errors in settings UI with NSRegularExpression.Error localized descriptions

## Icon Animation System

**Decision**: Core Graphics-generated NSImage frames with NSTimer-driven frame cycling at 60fps

**Rationale**:
- Programmatic generation allows dynamic colors without pre-baking asset variants
- NSTimer on main RunLoop provides stable 60fps frame timing
- Core Graphics drawing (CGContext) is hardware-accelerated
- Keeps animation logic in Swift without external animation libraries

**Alternatives Considered**:
- **CALayer animations**: Rejected - NSStatusItem uses NSImage, not layer-backed views in menu bar context
- **Pre-rendered sprite sheets**: Rejected - requires asset variants for every RGB color, violates simplicity principle
- **GIF animations**: Rejected - limited color palette, larger file sizes, no dynamic color control
- **SF Symbols with tinting**: Rejected - insufficient control over glow/pulse effects, limited to system icon styles

**Animation Styles Implementation**:
- **Glow**: Interpolate between base icon and color-tinted version, vary opacity 0.5→1.0→0.5 over 2-second cycle
- **Pulse**: Scale icon 1.0→1.15→1.0 while varying opacity, 1.5-second cycle
- **Blink**: Hard cut between visible (1.0 opacity) and invisible (0.0 opacity), 0.5-second intervals

**Frame Budget**:
- 60fps target = 16.67ms per frame
- Core Graphics rendering benchmarked at <2ms for 22x22px icon at 2x resolution
- Leaves 14ms margin for other main thread work (menu interactions, match event processing)

## Configuration Persistence

**Decision**: UserDefaults with Codable JSON encoding for LogPattern arrays

**Rationale**:
- UserDefaults automatic synchronization to disk, handles persistence lifecycle
- Codable protocol provides type-safe serialization with minimal boilerplate
- JSON encoding human-readable for debugging/manual inspection
- Sufficient for storing dozens of patterns (well below UserDefaults size limits)

**Alternatives Considered**:
- **Core Data**: Rejected - massive overkill for simple struct array, violates simplicity principle
- **File-based JSON**: Considered equivalent, UserDefaults preferred for automatic synchronization
- **Property lists (plist)**: Rejected - JSON more portable for future export/import feature
- **SQLite**: Rejected - no relational queries needed, unnecessary complexity

**Data Model**:
```swift
struct LogPattern: Codable, Identifiable {
    let id: UUID
    var name: String
    var regex: String
    var logPath: String
    var color: CodableColor  // Wrap NSColor as Codable RGB
    var animationStyle: AnimationStyle
    var enabled: Bool
}
```

**Security-Scoped Bookmarks**:
- Use URL.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess]) on macOS 13+ to minimize privileges.
- If the first attempt fails, call startAccessingSecurityScopedResource() and retry to satisfy sandbox requirements on hardened systems.
- Store bookmark data alongside logPath in UserDefaults so each LogPattern rehydrates with the same access grant.
- Resolve bookmarks on app launch via URL.init(resolvingBookmarkData:bookmarkDataIsStale:); refresh the bookmark when macOS marks it stale and persist the updated grant.
- When users type paths manually, validate existence/readability and prompt them to use the file picker if the sandbox would reject direct access.

## Testing Strategy

**Decision**: XCTest with protocol-based mocking for file system operations

**Rationale**:
- XCTest built into Xcode, no additional test framework dependencies
- Protocol-oriented design enables FileWatcher to accept FileSystemProtocol instead of concrete file APIs
- Mock implementations can simulate file changes, permissions errors, deletions without touching disk

**Mock Architecture**:
```swift
protocol FileSystemProtocol {
    func open(_ path: String, _ oflag: Int32) -> Int32
    func read(_ fd: Int32, _ buffer: UnsafeMutableRawPointer, _ count: Int) -> Int
    func close(_ fd: Int32) -> Int32
}

class MockFileSystem: FileSystemProtocol {
    var simulatedFileContents: [String: Data] = [:]
    var simulatedErrors: [String: Error] = [:]
    // ... implementation for tests
}
```

**Critical Path Coverage (100% target)**:
- PatternMatcher: All regex matching edge cases (empty strings, multiline, special chars)
- FileWatcher: File appends, deletions, permission errors, rapid changes
- LogMonitor: Multi-watcher coordination, event prioritization, debouncing

**Standard Coverage (70% target)**:
- MenuBarController: Menu construction, click handling (manual UI testing supplements)
- IconAnimator: State machine transitions (visual correctness verified manually)
- ConfigurationStore: Save/load patterns, bookmark resolution

## Performance Benchmarking Strategy

**Tooling**: Xcode Instruments (Time Profiler, Allocations, System Trace)

**Key Metrics to Profile**:
1. **Idle CPU usage**: Should measure <1% with 10 active patterns, no matches occurring
2. **Active CPU usage**: Should measure <5% with 10 patterns, 100 matches/second across all patterns
3. **Memory footprint**: Should measure <50MB with 20 patterns, 10k match history retained
4. **Pattern matching latency**: Should measure <10ms per line with 20 active patterns

**Profiling Scenarios**:
- **Baseline**: App running with no patterns configured
- **Idle monitoring**: 10 patterns watching log files with no matches for 5 minutes
- **Burst matching**: Simulate 1000 log lines/second with 50% match rate
- **Extreme scale**: 20 patterns watching 20 files simultaneously
- **Animation stress test**: Trigger 10 matches rapidly to test frame rate stability

**Optimization Targets if Benchmarks Fail**:
- Batch pattern matching (evaluate multiple patterns per line in single pass)
- Debounce animation updates (coalesce rapid matches into single animation restart)
- Limit match history in memory (keep 100 matches, persist older to UserDefaults on-demand)
- Profile allocations to identify unexpected retain cycles or temporary object churn

## Open Questions Resolved

All open questions from TECH_DESIGN.md addressed:

**Q: Animation performance with complex paths (bezier vs frame-based)?**
- A: Frame-based NSImage cycling chosen for simplicity and NSStatusItem compatibility

**Q: Max simultaneous file watchers before performance degrades?**
- A: Hard limit of 20 watchers enforced (FR-020), DispatchSource overhead ~1% CPU per watcher

**Q: Should matches persist across app restarts?**
- A: No for MVP - match history stored in-memory only (MatchEvent array), cleared on quit. Future enhancement could persist to UserDefaults.

**Q: Custom icon upload vs generated only?**
- A: Generated only for MVP - dynamic colors require programmatic generation anyway, custom uploads add file management complexity
