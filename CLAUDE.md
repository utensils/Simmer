# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Rule #1: Concise Documentation

Keep all project docs clean, concise, and to the point. Do not overwhelm with walls of text.

## Project Overview

Simmer is a minimal macOS menu bar app for passive log monitoring with visual feedback. Read VISION.md, TECH_DESIGN.md, and STANDARDS.md before starting work.

## Key Principles

1. **Keep it simple**: No over-engineering. Single responsibility per component.
2. **Native first**: Use system frameworks. No unnecessary dependencies.
3. **Performance matters**: Background threads for I/O, main thread only for UI updates.
4. **Developer UX**: Assume users are comfortable with regex and file paths.

## Development Workflow

**Before coding**:
- Read relevant documentation files
- Check TECH_DESIGN.md for architecture decisions
- Verify approach aligns with STANDARDS.md

**During coding**:
- Follow Swift API Design Guidelines
- Run SwiftLint before committing
- Add tests for new business logic
- Document public APIs

**After coding**:
- Test with real log files
- Verify performance (Activity Monitor)
- Update documentation if architecture changes

## Common Tasks

### Adding a new feature
1. Check if it aligns with VISION.md MVP scope
2. Design component following existing architecture
3. Implement with tests
4. Update TECH_DESIGN.md if significant

### Fixing bugs
1. Add test that reproduces bug
2. Fix issue
3. Verify test passes
4. Check for similar issues elsewhere

### Refactoring
1. Ensure tests exist and pass
2. Make changes incrementally
3. Verify tests still pass
4. Update documentation

## Code Organization

Place code in appropriate feature directories:
- Menu bar logic → `Features/MenuBar/`
- File monitoring → `Features/Monitoring/`
- Pattern matching → `Features/Patterns/`
- Settings UI → `Features/Settings/`
- Shared models → `Models/`
- Services → `Services/`

## Testing Strategy

- Unit test pattern matching thoroughly
- Mock file system for watcher tests
- Manual testing for menu bar UI
- Performance testing with large log files

## What to avoid

- External dependencies unless absolutely necessary
- Complex inheritance hierarchies
- Force unwrapping in production code
- Long functions (>50 lines)
- Global mutable state
- Premature optimization

## When stuck

1. Check TECH_DESIGN.md for architectural guidance
2. Review similar patterns in existing code
3. Consult Apple documentation
4. Ask for clarification on approach

## Quick Reference

```bash
# Build and test
xcodebuild -project Simmer.xcodeproj -scheme Simmer -configuration Debug build
xcodebuild test -project Simmer.xcodeproj -scheme Simmer -destination 'platform=macOS'
xcodebuild test -project Simmer.xcodeproj -scheme Simmer -only-testing:SimmerTests/PatternMatcherTests

# Lint and format
swiftlint
swiftlint --fix
swiftformat .
```

**Key files**:
- `SimmerApp.swift`: App entry point
- `MenuBarController.swift`: Status item management
- `LogMonitor.swift`: File watching coordinator
- `PatternMatcher.swift`: Regex matching engine

## Architecture Overview

**Concurrency Model**:
- LogMonitor and FileWatcher use background DispatchQueues for file I/O
- Pattern matching happens off main thread
- UI updates (MenuBarController, icon animations) must be on main thread
- Use `@MainActor` or `DispatchQueue.main.async` for UI updates

**Protocol-Based Design**:
- `FileSystemProtocol`: Abstracts file system for testability (RealFileSystem vs MockFileSystem)
- `PatternMatcherProtocol`: Allows mock pattern matching in tests
- `ConfigurationStoreProtocol`: Enables in-memory stores for tests

**Data Flow**:
```
LogMonitor → FileWatcher → New lines detected
          ↓
PatternMatcher → Match found
          ↓
MatchEventHandler → IconAnimator → MenuBarController (UI update on main thread)
```

## Active Technologies
- Swift 5.9+ with strict concurrency checking
- Foundation, AppKit (menu bar), SwiftUI (settings), Core Graphics (icon rendering)
- DispatchSource for file monitoring
- UserDefaults for pattern configurations with JSON encoding
- XCTest with protocol-based mocking
