# Quickstart: Simmer MVP Core Implementation

**Feature**: 001-mvp-core | **Date**: 2025-10-28

## Prerequisites

- Xcode 15.0+
- macOS 14.0+ (Sonoma) for development
- Read VISION.md, STANDARDS.md, and constitution.md
- Review plan.md, data-model.md, and contracts/internal-protocols.md

## Implementation Order

Follow prioritized user stories (P1→P4) for incremental delivery:

### Phase 1: P1 - Monitor Single Log with Visual Feedback

**Goal**: Basic log watching with static icon changes (no animations yet).

**Components**:
1. `Models/LogPattern.swift` - Data model with Codable
2. `Models/AnimationStyle.swift` - Enum (glow, pulse, blink)
3. `Services/ConfigurationStore.swift` - UserDefaults persistence
4. `Features/Monitoring/FileWatcher.swift` - DispatchSource wrapper
5. `Features/Patterns/PatternMatcher.swift` - NSRegularExpression wrapper
6. `Features/MenuBar/MenuBarController.swift` - NSStatusItem with static icon
7. `App/SimmerApp.swift` - LSUIElement=true, launch coordinator

**Testing**:
- `PatternsTests/PatternMatcherTests.swift` - 100% coverage target
- `MonitoringTests/FileWatcherTests.swift` - Mock FileSystemProtocol
- Create test log file, write pattern, verify icon changes

**Success Criteria**: FR-001 through FR-003, SC-002 (match detection <500ms)

---

### Phase 2: P2 - Review Recent Matches

**Goal**: Menu displays match history with timestamps.

**Components**:
1. `Models/MatchEvent.swift` - Match metadata model
2. `Features/Patterns/MatchEventHandler.swift` - History management
3. `Features/MenuBar/MenuBuilder.swift` - NSMenu construction
4. `Utilities/RelativeTimeFormatter.swift` - "2m ago" formatting

**Testing**:
- `PatternsTests/MatchEventHandlerTests.swift` - History pruning logic
- `MenuBarTests/MenuBuilderTests.swift` - Menu structure validation

**Success Criteria**: FR-007, FR-008, SC-008 (match context sufficient 80% of time)

---

### Phase 3: P3 - Configure Patterns and Files

**Goal**: Settings UI for CRUD operations on patterns.

**Components**:
1. `Features/Settings/SettingsWindow.swift` - SwiftUI window coordinator
2. `Features/Settings/PatternListView.swift` - List with add/edit/delete
3. `Features/Settings/PatternEditorView.swift` - Form with validation
4. `Features/Settings/ColorPickerView.swift` - RGB color selection
5. `Features/Patterns/PatternValidator.swift` - Regex syntax validation
6. `Utilities/CodableColor.swift` - NSColor wrapper for Codable
7. `Features/Monitoring/FileAccessManager.swift` - Security-scoped bookmarks

**Testing**:
- `PatternsTests/PatternValidatorTests.swift` - Invalid regex handling
- `ServicesTests/ConfigurationStoreTests.swift` - Persistence verification
- Manual testing for NSOpenPanel file selection

**Success Criteria**: FR-010 through FR-016, SC-001 (configure pattern <60s), SC-005 (95% success without docs)

---

### Phase 4: P1 Enhancement - Icon Animations

**Goal**: Replace static icon changes with smooth 60fps animations.

**Components**:
1. `Models/IconAnimationState.swift` - State machine enum
2. `Features/MenuBar/IconAnimator.swift` - Core Graphics frame generation
3. Update `MenuBarController` to use IconAnimator

**Testing**:
- `MenuBarTests/IconAnimatorTests.swift` - State transitions
- Manual testing with Activity Monitor for frame rate verification

**Success Criteria**: FR-004 through FR-006, SC-003 (60fps, <5% CPU)

---

### Phase 5: P4 - Monitor Multiple Logs Simultaneously

**Goal**: Handle 20 concurrent file watchers with prioritization.

**Components**:
1. `Features/Monitoring/LogMonitor.swift` - Coordinates multiple FileWatchers
2. Update MatchEventHandler for animation prioritization

**Testing**:
- `MonitoringTests/LogMonitorTests.swift` - Multi-watcher coordination
- Performance testing with 20 simultaneous log files

**Success Criteria**: FR-020, SC-004 (10 files without degradation)

---

### Phase 6: Polish & Performance

**Goal**: Error handling, path expansion, performance tuning.

**Components**:
1. `Services/PathExpander.swift` - Tilde and env var expansion
2. Error handling in FileWatcher (FR-021, FR-022)
3. Debouncing in LogMonitor (100ms window per TECH_DESIGN.md)
4. Launch at login support in AppDelegate

**Testing**:
- Edge case testing per spec.md edge cases section
- Instruments profiling for CPU/memory targets

**Success Criteria**: FR-017 through FR-024, SC-006 (launch <2s), SC-007 (match <10ms per line)

---

## Development Commands

```bash
# Open project
cd /Users/jamesbrink/Projects/utensils/Simmer
open Simmer.xcodeproj

# Build
xcodebuild -scheme Simmer -configuration Debug build

# Run tests
xcodebuild -scheme Simmer -configuration Debug test

# Run SwiftLint
swiftlint lint --strict

# Launch app in debug
xcodebuild -scheme Simmer -configuration Debug run

# Profile with Instruments
xcodebuild -scheme Simmer -configuration Release \
  -derivedDataPath build && \
  instruments -t "Time Profiler" \
  build/Build/Products/Release/Simmer.app
```

---

## Key Files Reference

### Entry Point
- `Simmer/App/SimmerApp.swift` - @main entry, LSUIElement configuration

### Core Coordinator
- `Simmer/Features/Monitoring/LogMonitor.swift` - Orchestrates watchers, matches, animations

### Critical Path (100% test coverage required)
- `Simmer/Features/Patterns/PatternMatcher.swift` - Regex evaluation
- `Simmer/Features/Monitoring/FileWatcher.swift` - DispatchSource I/O

### Configuration
- `Simmer/Services/ConfigurationStore.swift` - UserDefaults persistence
- `Simmer/Features/Monitoring/FileAccessManager.swift` - Security-scoped bookmarks

### UI
- `Simmer/Features/MenuBar/MenuBarController.swift` - NSStatusItem
- `Simmer/Features/Settings/SettingsWindow.swift` - SwiftUI settings root

---

## Common Pitfalls

**DispatchSource file descriptor leaks**: Always call `source.cancel()` and `close(fd)` on cleanup

**Main thread blocking**: Never read files or evaluate regex on main thread, use background queues

**Force unwrapping**: Prohibited in production code per STANDARDS.md, use guard/if let

**Animation jank**: Ensure Core Graphics rendering completes <2ms per frame, profile with Instruments

**Security-scoped bookmark staleness**: Always check `isStale` on bookmark resolution, prompt user to re-select file

**Pattern compilation cost**: Pre-compile NSRegularExpression when LogPattern created, reuse instance

---

## Constitution Compliance Checklist

Before committing each component:

- [ ] **Simplicity First**: Single responsibility, no over-engineering
- [ ] **Native & Performant**: Zero external dependencies, background threads for I/O
- [ ] **Developer-Centric UX**: Technical details exposed, no patronization
- [ ] **Testing Discipline**: Unit tests written, 70%+ coverage, critical paths 100%
- [ ] **Concise Documentation**: Swift DocC comments on public APIs
- [ ] **SwiftLint**: Zero warnings
- [ ] **Quality Gates**: All tests passing, no force unwraps/casts

---

## Next Steps

1. Review constitution.md and STANDARDS.md
2. Start with Phase 1 (P1) implementation
3. Run `/speckit.tasks` to generate detailed task breakdown
4. Commit frequently with conventional commit messages
5. Profile early and often with Instruments
