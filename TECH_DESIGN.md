# Simmer Technical Design

## Architecture

Native macOS menu bar application (LSUIElement) using SwiftUI for settings interface and AppKit for menu bar integration.

### Core Components

**MenuBarController**: Manages NSStatusItem, handles icon animation states, responds to user clicks.

**LogMonitor**: Coordinates multiple FileWatcher instances, aggregates match events, triggers visual feedback.

**FileWatcher**: Wraps DispatchSource for individual log file monitoring, emits file change events.

**PatternMatcher**: Evaluates log lines against regex patterns, returns match metadata.

**ConfigurationStore**: Persists patterns and settings using UserDefaults or JSON file.

## Technology Stack

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI (settings), AppKit (menu bar)
- **File Monitoring**: DispatchSource.makeFileSystemObjectSource
- **Pattern Matching**: NSRegularExpression
- **Persistence**: UserDefaults with JSON encoding/decoding
- **Logging**: OSLog

## File Monitoring Strategy

### DispatchSource Implementation

```swift
func watchFile(at path: String) {
    let descriptor = open(path, O_EVTONLY)
    let source = DispatchSource.makeFileSystemObjectSource(
        fileDescriptor: descriptor,
        eventMask: [.write, .extend],
        queue: monitoringQueue
    )

    source.setEventHandler { [weak self] in
        self?.handleFileChange(path: path)
    }

    source.activate()
}
```

**Key Points**:
- `.extend` event for appended log lines
- Background queue for all file I/O
- Maintain file position pointer to read only new content
- Debounce rapid changes (100ms window)

## Animation System

### Icon State Machine

States: `idle`, `glowing(color)`, `pulsing(color)`, `blinking(color)`

Transitions triggered by match events. Multiple simultaneous matches prioritize by configured severity.

### Implementation

```swift
class IconAnimator {
    private var timer: Timer?
    private var frameIndex = 0
    private let frames: [NSImage]

    func startAnimation(style: AnimationStyle, color: NSColor) {
        // Generate icon frames with Core Graphics
        // Use NSTimer to cycle through frames at 60fps
    }
}
```

**Rendering**: Generate icon images programmatically using Core Graphics to allow dynamic colors.

## Data Model

### Pattern Configuration

```swift
struct LogPattern: Codable, Identifiable {
    let id: UUID
    var name: String
    var regex: String
    var logPath: String
    var color: CodableColor  // RGB values
    var animationStyle: AnimationStyle  // glow, pulse, blink
    var enabled: Bool
}

enum AnimationStyle: String, Codable {
    case glow, pulse, blink
}
```

### Match Event

```swift
struct MatchEvent {
    let pattern: LogPattern
    let timestamp: Date
    let matchedLine: String
    let lineNumber: Int
}
```

## Menu Bar Interface

**Status Item**: NSStatusItem with custom view for animations

**Menu Structure**:
```
[Icon]
├─ Recent Matches (last 10)
│  ├─ Pattern Name • 2m ago
│  └─ Matched excerpt...
├─ ─────────────────
├─ Clear All
├─ Settings...
├─ ─────────────────
└─ Quit
```

## Settings Interface

SwiftUI window with sections:
- **Patterns**: List with add/edit/delete
- **Appearance**: Animation preferences, icon size
- **General**: Launch at login, notification settings

## Performance Targets

- **CPU Usage**: <1% idle, <5% during active monitoring
- **Memory**: <50MB
- **Pattern Matching**: <10ms per line
- **Animation Frame Rate**: 60fps

## File Access Strategy

**Path Input**:
- Users enter file paths directly or via file picker (NSOpenPanel).
- Validate existence, non-directory, and read permission before saving.
- Support `~`, environment variables, and wildcards in paths.

**Permission Handling**:
- Treat `EPERM`/`EACCES` errors as permission failures.
- Disable the offending pattern and show actionable alerts.

**Launch at Login**:
- AppDelegate defers SMAppService registration until after initial launch.
- Launch-at-login is enabled only outside of test environments.
- Failures are logged via `OSLog`.

## Error Handling

- File permissions: Show alert, disable pattern
- Invalid regex: Validate on save, show inline error
- File deletion: Gracefully stop watcher, mark pattern inactive
- Resource limits: Cap active watchers at 20 simultaneous files

## Implementation Status

Core MVP features implemented:
- Menu bar-only app (LSUIElement)
- Real-time file monitoring with DispatchSource
- Regex pattern matching with NSRegularExpression
- Icon animations (glow, pulse, blink) at 60fps with graceful degradation
- Recent matches menu (10 items, FIFO)
- Settings UI with pattern CRUD, file picker, regex validation
- JSON import/export for pattern configurations
- Launch at login via SMAppService
- Performance: <1% CPU idle, <5% active, <50MB memory
- 20-pattern limit with UI warnings
- Frequent match warnings (EC-005)
- Error handling for permissions and file deletion

## Future Enhancements

- Match history persistence across restarts
- Custom icon sets
- Pattern templates library
- Match statistics and trends
- Remote log monitoring (SSH)
- Notification Center integration

## Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Log files too large | High CPU/memory | Read only new lines, limit buffer size |
| Too many patterns | Slow matching | Compile regex once, batch processing |
| File permissions | App fails silently | Explicit error UI, request access |
| Animation jank | Poor UX | Profile with Instruments, use CAAnimation |
