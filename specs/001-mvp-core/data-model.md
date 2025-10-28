# Data Model: Simmer MVP Core

**Feature**: 001-mvp-core | **Date**: 2025-10-28

## Core Entities

### LogPattern

**Purpose**: Represents a user-configured monitoring rule mapping regex pattern to log file with visual appearance settings.

**Fields**:
- `id: UUID` - Unique identifier for pattern, generated on creation
- `name: String` - User-provided label for pattern (e.g., "Error Detector", "Queue Failures")
- `regex: String` - Regular expression pattern to match against log lines
- `logPath: String` - Absolute file path to monitored log file (supports ~ and env vars)
- `color: CodableColor` - RGB color for icon animation when pattern matches
- `animationStyle: AnimationStyle` - Visual feedback style (glow, pulse, blink)
- `enabled: Bool` - Whether pattern is actively monitored (false = soft delete)

**Validation Rules** (from FR-011):
- `regex`: Must be valid NSRegularExpression syntax, validated by PatternValidator
- `logPath`: Must be non-empty, resolvable after path expansion
- `name`: Must be non-empty, max 50 characters
- `color`: RGB values must be 0-255 range

**Relationships**:
- One LogPattern → Many MatchEvents (one-to-many, not persisted)
- One LogPattern → One FileWatcher (runtime only, not persisted)

**State Transitions**:
```
Created (enabled=true) → Active Monitoring
Active Monitoring → Disabled (enabled=false) → Monitoring Stopped
Disabled → Active Monitoring (re-enabled)
Active Monitoring → Deleted (removed from ConfigurationStore)
```

**Persistence**: Encoded to JSON via Codable, stored in UserDefaults array under key "patterns"

---

### MatchEvent

**Purpose**: Represents a detected pattern match occurrence with metadata for display in menu bar history.

**Fields**:
- `id: UUID` - Unique identifier for this match occurrence
- `patternID: UUID` - Foreign key to LogPattern.id that triggered match
- `patternName: String` - Denormalized copy of pattern name for display (avoids lookup)
- `timestamp: Date` - When match was detected
- `matchedLine: String` - Full text of log line that matched (truncated to 200 chars for display)
- `lineNumber: Int` - Line number in log file where match occurred (for debugging)
- `filePath: String` - Denormalized log file path for context display

**Validation Rules**:
- `matchedLine`: Max 200 characters stored, truncated with "..." if longer
- `timestamp`: Must be recent (within app runtime, not persisted across restarts)

**Relationships**:
- Many MatchEvents → One LogPattern (many-to-one)
- MatchEvents stored in-memory only, not persisted

**Lifecycle**:
```
Pattern Match Detected → MatchEvent Created → Added to History Array
History Array > 100 items → Oldest Events Pruned (FIFO)
App Quit → All MatchEvents Discarded
```

**Display Format** (for menu):
```
[patternName] • [relative timestamp]
[first 60 chars of matchedLine]...
```

---

### AnimationStyle (Enum)

**Purpose**: Defines visual feedback styles for menu bar icon animations.

**Cases**:
- `glow` - Smooth opacity interpolation, 2-second cycle
- `pulse` - Scale + opacity animation, 1.5-second cycle
- `blink` - Hard on/off transitions, 0.5-second intervals

**Raw Value**: String (for Codable JSON encoding)

**Default**: `glow` (most subtle, aligns with "passive monitoring" vision)

---

### IconAnimationState (Enum)

**Purpose**: Represents current runtime state of menu bar icon animation system.

**Cases**:
- `idle` - No active matches, icon in default static state
- `animating(style: AnimationStyle, color: CodableColor)` - Active animation with associated style and color

**State Transitions**:
```
idle → animating (when first match occurs)
animating → animating (when new higher-priority match occurs, updates style/color)
animating → idle (when animation duration expires with no new matches, after 5-second cooldown)
```

**Prioritization Logic** (for simultaneous matches):
- Priority determined by pattern order in ConfigurationStore (first = highest)
- Later matches with lower priority do not interrupt current animation
- Higher priority matches immediately replace current animation

---

### CodableColor (Struct)

**Purpose**: Wrapper for NSColor/Color to enable Codable serialization of RGB values.

**Fields**:
- `red: Double` - Red component 0.0-1.0
- `green: Double` - Green component 0.0-1.0
- `blue: Double` - Blue component 0.0-1.0
- `alpha: Double` - Opacity 0.0-1.0 (always 1.0 for MVP)

**Conversion**:
```swift
init(nsColor: NSColor)
func toNSColor() -> NSColor
func toColor() -> Color  // For SwiftUI
```

**Validation**: RGB components clamped to 0.0-1.0 range on init

---

## Value Objects

### FileBookmark (Struct)

**Purpose**: Encapsulates security-scoped bookmark data for sandboxed file access.

**Fields**:
- `bookmarkData: Data` - Serialized security-scoped bookmark from URL.bookmarkData()
- `filePath: String` - Original file path for reference (may be stale if file moved)
- `isStale: Bool` - Indicates if bookmark needs re-resolution

**Lifecycle**:
```
User selects file via NSOpenPanel → URL.startAccessingSecurityScopedResource()
→ Generate bookmarkData → Store in UserDefaults
App launch → Resolve bookmark → If stale, prompt user to re-select file
```

---

## Data Flow

### Pattern Configuration Flow
```
User creates pattern in Settings → LogPattern created
→ ConfigurationStore.save() → UserDefaults persisted
→ LogMonitor notified → FileWatcher created → DispatchSource activated
```

### Match Detection Flow
```
Log file appended → DispatchSource event fires
→ FileWatcher reads new lines → PatternMatcher evaluates
→ Match found → MatchEvent created → MenuBuilder updates menu
→ IconAnimator state transitions → Animation started
```

### History Management Flow
```
MatchEvent created → Added to in-memory array
→ If count > 100 → Oldest 50 pruned (keep 50 most recent)
→ MenuBuilder queries recent 10 for menu display
→ User clicks "Clear All" → Array emptied
```

---

## Schema Evolution (Future Considerations)

Not implemented in MVP, documented for future reference:

**Pattern Priority Field**:
- Add `priority: Int` to LogPattern for explicit animation precedence
- Default all existing patterns to priority=0 on migration

**Match Persistence**:
- Add `matchHistory: [MatchEvent]` to UserDefaults
- Limit to 1000 most recent matches persisted
- Lazy load from disk on menu open

**Pattern Groups**:
- Add `groupID: UUID?` to LogPattern
- Allow visual grouping in settings UI
