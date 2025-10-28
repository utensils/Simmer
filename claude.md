# Claude Code Instructions for Simmer

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

**Build**: Cmd+B
**Run**: Cmd+R
**Test**: Cmd+U
**Lint**: SwiftLint from terminal

**Key files**:
- `SimmerApp.swift`: App entry point
- `MenuBarController.swift`: Status item management
- `LogMonitor.swift`: File watching coordinator
- `PatternMatcher.swift`: Regex matching engine
