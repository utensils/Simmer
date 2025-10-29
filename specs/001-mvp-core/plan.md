# Implementation Plan: Simmer MVP Core

**Branch**: `001-mvp-core` | **Date**: 2025-10-28 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-mvp-core/spec.md`

## Summary

Build native macOS menu bar application for passive log monitoring with visual feedback. Core functionality includes real-time file monitoring using DispatchSource, regex pattern matching with NSRegularExpression, programmatic icon animations via Core Graphics, and SwiftUI-based configuration UI. App must maintain <1% CPU idle, <5% active, <50MB memory while monitoring up to 20 log files simultaneously with sub-500ms match feedback latency.

## Technical Context

**Language/Version**: Swift 5.9+
**Primary Dependencies**: Foundation, AppKit (menu bar), SwiftUI (settings), Core Graphics (icon rendering)
**Storage**: UserDefaults for pattern configurations with JSON encoding
**Testing**: XCTest framework with file system mocking for watcher tests
**Target Platform**: macOS 14.0+ (Sonoma)
**Project Type**: Single native macOS application
**Performance Goals**: 60fps icon animations, <10ms pattern matching per line, <500ms match detection latency
**Constraints**: <1% CPU idle, <5% CPU active, <50MB memory, menu bar-only (LSUIElement), sandboxed file access
**Scale/Scope**: Support 20 simultaneous file watchers, 10 recent matches in history, unlimited pattern configurations

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle I: Simplicity First ✅
- **Compliance**: MVP scope strictly limited to 4 user stories in VISION.md
- **Components**: Single responsibility - MenuBarController (UI), LogMonitor (coordination), FileWatcher (I/O), PatternMatcher (regex), ConfigurationStore (persistence)
- **No over-engineering**: Direct DispatchSource usage instead of reactive frameworks, value types over classes where possible

### Principle II: Native & Performant ✅
- **Zero external dependencies**: Uses only system frameworks (Foundation, AppKit, SwiftUI, Core Graphics)
- **Threading model**: File I/O on background queues via DispatchSource, UI updates on main thread
- **Performance targets**: <1% CPU idle, <5% active, <50MB memory explicitly defined in FR-017, FR-018

### Principle III: Developer-Centric UX ✅
- **Power-user features**: Raw regex syntax (FR-011), file path wildcards/env vars (FR-024), JSON export/import planned
- **No patronization**: Settings expose technical details (regex, file paths, RGB colors)
- **Technical audience**: Developers monitoring worker queues, comfortable with log file concepts

### Principle IV: Testing Discipline ✅
- **Coverage targets**: 70% overall minimum, 100% for critical paths (pattern matching, file monitoring)
- **Test-first approach**: Tests required before merging (constitution quality gates)
- **Mocking strategy**: File system operations mocked in tests (per STANDARDS.md)
- **SwiftLint**: Zero warnings enforcement via quality gates
- **CI/CD**: GitHub Actions workflows enforce automated testing, linting, and build verification on all PRs

### Principle V: Concise Documentation ✅
- **Separation of concerns**: VISION.md (what/why), TECH_DESIGN.md (architecture), STANDARDS.md (how), claude.md (AI guidance)
- **No redundancy**: Each doc serves distinct purpose, this plan references rather than duplicates
- **Brevity**: Implementation plan focuses on actionable technical decisions

**GATE RESULT**: ✅ PASS - All principles satisfied, no complexity violations to justify.

## Project Structure

### Documentation (this feature)

```text
specs/001-mvp-core/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
Simmer/
├── App/
│   ├── SimmerApp.swift           # App lifecycle, LSUIElement configuration
│   └── AppDelegate.swift         # Launch at login, app-level event handling
├── Features/
│   ├── MenuBar/
│   │   ├── MenuBarController.swift      # NSStatusItem management
│   │   ├── IconAnimator.swift           # Core Graphics animation engine
│   │   └── MenuBuilder.swift            # Recent matches menu construction
│   ├── Monitoring/
│   │   ├── LogMonitor.swift             # Coordinates multiple FileWatchers
│   │   ├── FileWatcher.swift            # DispatchSource wrapper for individual logs
│   │   └── FileAccessManager.swift      # Security-scoped URL bookmarks
│   ├── Patterns/
│   │   ├── PatternMatcher.swift         # NSRegularExpression evaluation
│   │   ├── PatternValidator.swift       # Regex syntax validation
│   │   └── MatchEventHandler.swift      # Match event aggregation/prioritization
│   └── Settings/
│       ├── SettingsWindow.swift         # SwiftUI settings coordinator
│       ├── PatternListView.swift        # Pattern CRUD UI
│       ├── PatternEditorView.swift      # Individual pattern form
│       └── ColorPickerView.swift        # RGB color selection
├── Models/
│   ├── LogPattern.swift           # Codable pattern configuration
│   ├── MatchEvent.swift           # Match metadata
│   ├── AnimationStyle.swift       # Enum: glow, pulse, blink
│   └── IconAnimationState.swift   # Current animation state
├── Services/
│   ├── ConfigurationStore.swift   # UserDefaults persistence
│   └── PathExpander.swift         # Tilde/env var expansion
└── Utilities/
    ├── CodableColor.swift         # RGB color encoding/decoding
    └── RelativeTimeFormatter.swift # "2m ago" timestamp formatting

SimmerTests/
├── MenuBarTests/
│   ├── IconAnimatorTests.swift    # Animation state machine tests
│   └── MenuBuilderTests.swift     # Menu structure tests
├── MonitoringTests/
│   ├── FileWatcherTests.swift     # Mocked file system tests
│   └── LogMonitorTests.swift      # Coordination tests
├── PatternsTests/
│   ├── PatternMatcherTests.swift  # Regex matching tests (100% coverage)
│   ├── PatternValidatorTests.swift # Syntax validation tests
│   └── MatchEventHandlerTests.swift # Prioritization tests
├── ServicesTests/
│   └── ConfigurationStoreTests.swift # Persistence tests
└── Mocks/
    ├── MockFileHandle.swift       # File I/O mocking
    └── MockDispatchSource.swift   # DispatchSource mocking
```

**Structure Decision**: Single macOS application structure following feature-based organization per STANDARDS.md and constitution. App/ for lifecycle, Features/ for domain logic, Models/ for shared data structures, Services/ for cross-cutting concerns, Utilities/ for helpers. Tests mirror source structure with dedicated Mocks/ directory for file system simulation.

## Complexity Tracking

No violations - constitution check passed without requiring complexity justifications.
