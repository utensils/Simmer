# Internal Protocols: Simmer MVP Core

**Feature**: 001-mvp-core | **Date**: 2025-10-28

## Overview

Simmer is a single-process macOS application with no network APIs or external services. This document defines internal Swift protocols that establish contracts between subsystems for dependency injection and testability.

---

## FileSystemProtocol

**Purpose**: Abstraction over POSIX file I/O for mocking in FileWatcher tests.

**Conforming Types**:
- `RealFileSystem` (production)
- `MockFileSystem` (tests)

```swift
protocol FileSystemProtocol {
    /// Open file at path with flags, returns file descriptor or -1 on error
    func open(_ path: String, _ oflag: Int32) -> Int32

    /// Read bytes from file descriptor into buffer
    func read(_ fd: Int32, _ buffer: UnsafeMutableRawPointer, _ count: Int) -> Int

    /// Close file descriptor
    func close(_ fd: Int32) -> Int32

    /// Get current file offset
    func lseek(_ fd: Int32, _ offset: off_t, _ whence: Int32) -> off_t
}
```

**Usage**:
```swift
// FileWatcher accepts protocol for testability
class FileWatcher {
    private let fileSystem: FileSystemProtocol
    init(path: String, fileSystem: FileSystemProtocol = RealFileSystem()) { ... }
}

// Tests inject mock
func testFileAppend() {
    let mock = MockFileSystem()
    mock.simulateAppend(to: "/tmp/test.log", content: "ERROR: test")
    let watcher = FileWatcher(path: "/tmp/test.log", fileSystem: mock)
    // ... assertions
}
```

---

## PatternMatcherProtocol

**Purpose**: Contract for regex pattern matching, enables testing MatchEventHandler without real NSRegularExpression.

**Conforming Types**:
- `RegexPatternMatcher` (production, wraps NSRegularExpression)
- `MockPatternMatcher` (tests, returns pre-configured matches)

```swift
protocol PatternMatcherProtocol {
    /// Evaluate line against pattern, returns MatchResult with range and captures
    func match(line: String, pattern: LogPattern) -> MatchResult?
}

struct MatchResult {
    let range: NSRange
    let captureGroups: [String]  // For future named capture support
}
```

**Usage**:
```swift
// MatchEventHandler depends on protocol
class MatchEventHandler {
    private let matcher: PatternMatcherProtocol
    init(matcher: PatternMatcherProtocol = RegexPatternMatcher()) { ... }
}

// Tests inject predictable matcher
func testMultipleMatches() {
    let mock = MockPatternMatcher()
    mock.addMatch(for: "pattern1", line: "ERROR")
    let handler = MatchEventHandler(matcher: mock)
    // ... assertions
}
```

---

## ConfigurationStoreProtocol

**Purpose**: Abstract persistence layer for pattern configurations.

**Conforming Types**:
- `UserDefaultsStore` (production)
- `InMemoryStore` (tests, ephemeral storage)

```swift
protocol ConfigurationStoreProtocol {
    /// Load all patterns from storage
    func loadPatterns() -> [LogPattern]

    /// Save patterns to storage, throws on encoding/write errors
    func savePatterns(_ patterns: [LogPattern]) throws

    /// Delete specific pattern by ID
    func deletePattern(id: UUID) throws

    /// Update existing pattern
    func updatePattern(_ pattern: LogPattern) throws
}
```

**Usage**:
```swift
// LogMonitor depends on store protocol
class LogMonitor {
    private let store: ConfigurationStoreProtocol
    init(store: ConfigurationStoreProtocol = UserDefaultsStore()) { ... }
}

// Tests use in-memory store, no UserDefaults pollution
func testPatternPersistence() {
    let store = InMemoryStore()
    let monitor = LogMonitor(store: store)
    // ... assertions without UserDefaults side effects
}
```

---

## IconAnimatorDelegate

**Purpose**: Callback protocol for IconAnimator to notify MenuBarController of animation state changes.

**Conforming Types**:
- `MenuBarController` (production)
- `MockAnimatorDelegate` (tests)

```swift
protocol IconAnimatorDelegate: AnyObject {
    /// Called when animation starts
    func animationDidStart(style: AnimationStyle, color: CodableColor)

    /// Called when animation completes and icon returns to idle
    func animationDidEnd()

    /// Called on each frame update with current NSImage
    func updateIcon(_ image: NSImage)
}
```

**Usage**:
```swift
// IconAnimator notifies delegate on frame updates
class IconAnimator {
    weak var delegate: IconAnimatorDelegate?

    func startAnimation(style: AnimationStyle, color: CodableColor) {
        delegate?.animationDidStart(style: style, color: color)
        // ... generate frames and call updateIcon(_:) at 60fps
    }
}

// MenuBarController implements delegate to update NSStatusItem
extension MenuBarController: IconAnimatorDelegate {
    func updateIcon(_ image: NSImage) {
        statusItem.button?.image = image
    }
}
```

---

## FileWatcherDelegate

**Purpose**: Callback protocol for FileWatcher to notify LogMonitor of file events.

**Conforming Types**:
- `LogMonitor` (production)
- `MockWatcherDelegate` (tests)

```swift
protocol FileWatching: AnyObject {
    var path: String { get }
    var delegate: FileWatcherDelegate? { get set }
    func start() throws
    func stop()
}

protocol FileWatcherDelegate: AnyObject {
    /// Called when new content appended to watched file
    func fileWatcher(_ watcher: FileWatching, didReadLines lines: [String])

    /// Called when file becomes inaccessible (deleted, permissions changed)
    func fileWatcher(_ watcher: FileWatching, didEncounterError error: FileWatcherError)
}

enum FileWatcherError: Error {
    case fileDeleted(path: String)
    case permissionDenied(path: String)
    case fileDescriptorInvalid
}
```

**Usage**:
```swift
// FileWatcher notifies delegate of new lines
class FileWatcher {
    weak var delegate: FileWatcherDelegate?

    private func handleFileEvent() {
        let newLines = readNewContent()
        delegate?.fileWatcher(self, didReadLines: newLines)
    }
}

// LogMonitor coordinates pattern matching on new lines
extension LogMonitor: FileWatcherDelegate {
    func fileWatcher(_ watcher: FileWatching, didReadLines lines: [String]) {
        for line in lines {
            evaluateAllPatterns(line: line, filePath: watcher.path)
        }
    }
}
```

---

## MatchEventHandlerDelegate

**Purpose**: Callback protocol for MatchEventHandler to notify consumers of new matches.

**Conforming Types**:
- `LogMonitor` (production, orchestrates animation and menu updates)
- `MockMatchHandler` (tests)

```swift
protocol MatchEventHandlerDelegate: AnyObject {
    /// Called when pattern match detected with priority-selected event
    func matchEventHandler(_ handler: MatchEventHandler, didDetectMatch event: MatchEvent)

    /// Called when match history updated (for menu refresh)
    func matchEventHandler(_ handler: MatchEventHandler, historyDidUpdate: [MatchEvent])
}
```

**Usage**:
```swift
// MatchEventHandler processes matches and notifies delegate
class MatchEventHandler {
    weak var delegate: MatchEventHandlerDelegate?

    func handleMatch(pattern: LogPattern, line: String, lineNumber: Int) {
        let event = MatchEvent(pattern: pattern, line: line, lineNumber: lineNumber)
        addToHistory(event)
        delegate?.matchEventHandler(self, didDetectMatch: event)
    }
}

// LogMonitor triggers icon animation on match
extension LogMonitor: MatchEventHandlerDelegate {
    func matchEventHandler(_ handler: MatchEventHandler, didDetectMatch event: MatchEvent) {
        iconAnimator.startAnimation(
            style: event.pattern.animationStyle,
            color: event.pattern.color
        )
    }
}
```

---

## Protocol Dependency Graph

```
MenuBarController (UI)
    ↓ owns
IconAnimator
    ↓ delegate
MenuBarController (IconAnimatorDelegate)

LogMonitor (Coordinator)
    ↓ owns multiple
FileWatcher(s)
    ↓ delegate
LogMonitor (FileWatcherDelegate)
    ↓ owns
MatchEventHandler
    ↓ uses
PatternMatcherProtocol (RegexPatternMatcher)
    ↓ delegate
LogMonitor (MatchEventHandlerDelegate)
    ↓ triggers
IconAnimator.startAnimation()

ConfigurationStore (Persistence)
    ↓ implements
ConfigurationStoreProtocol
    ↓ used by
LogMonitor (loads patterns on launch)
```

---

## Testing Strategy

Each protocol enables isolated unit testing:

**FileWatcher tests**: Mock FileSystemProtocol to simulate file events without disk I/O
**LogMonitor tests**: Mock FileWatcherDelegate and ConfigurationStoreProtocol
**MatchEventHandler tests**: Mock PatternMatcherProtocol with pre-defined match results
**IconAnimator tests**: Mock IconAnimatorDelegate to verify frame updates without NSStatusItem

**Integration tests**: Use real protocol implementations, mock only external dependencies (file system)
