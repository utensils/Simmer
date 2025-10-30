# Simmer Coding Standards

## Development Environment

- Xcode 15.0+
- macOS 14.0+ (Sonoma)
- Swift 5.9+
- SwiftLint for code quality

## Code Formatting

**Swift**: Follow Swift API Design Guidelines
- 2-space indentation
- 100 character line limit
- Trailing commas in multi-line arrays/dictionaries
- One blank line between methods
- SwiftFormat configuration in `.swiftformat`

## Linting

**SwiftLint** configuration enforces:
- No force unwrapping in production code
- No force casts
- Explicit `self` only when required
- Warnings as errors in CI
- Disabled rules: `line_length` in comments
- Type bodies should stay under 200 lines (lint warns at 200 and errors at 300)
- Function bodies should target 50 lines or fewer (lint warns at 50 and errors at 80)
- Type bodies should stay under 200 lines (lint warns at 200 and errors at 300)
- Function bodies should target 50 lines or fewer (lint warns at 50 and errors at 80)
- Trailing commas are required in multiline collection literals
- Explicit access control is required on all top-level declarations
- Vertical whitespace is enforced between switch cases

**ShellCheck** for all shell scripts:
- All `.sh` files must pass `shellcheck` with zero warnings
- Use `#!/usr/bin/env bash` shebang
- Quote all variable expansions
- Handle errors with `set -euo pipefail`
- Run via CI for scripts in `.specify/scripts/` and `.github/workflows/`

## Type Safety

- Avoid optionals where possible, use sensible defaults
- Use Result types for operations that can fail
- Protocol-oriented design for testability
- Value types (struct) preferred over reference types (class)
- Explicit error types conforming to Error protocol

## Testing Requirements

- Unit test coverage: 70% minimum (currently 64%)
- Critical paths: >80% coverage (PatternMatcher 84%, FileWatcher 89%, MatchEventHandler 94%)
- XCTest framework with protocol-based mocking
- Mock file system operations via FileSystemProtocol
- Manual UI testing for menu bar interactions

## Git Workflow

**Branch Naming**:
- `feature/description`
- `fix/description`
- `refactor/description`

**Commit Format**: Conventional Commits
```
type: brief description

Optional body
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`

## Code Structure

```
Simmer/
├── App/                   # App lifecycle
├── Features/
│   ├── MenuBar/           # Menu bar icon and menu
│   ├── Monitoring/        # Log file watching
│   ├── Patterns/          # Pattern matching engine
│   └── Settings/          # Configuration UI
├── Models/                # Data models
├── Services/              # File I/O, persistence
└── Utilities/             # Extensions, helpers
```

## Naming Conventions

- Types: `PascalCase`
- Functions/variables: `camelCase`
- Constants: `camelCase` with `let`
- Enums: `PascalCase` with lowercase cases
- Booleans: `is`, `has`, `should` prefix

## Documentation

- Public APIs: Swift DocC format
- Include usage examples for complex functions
- Header comments for each file with purpose

## Performance Guidelines

- File monitoring on background queues
- Main thread only for UI updates
- Batch pattern matching operations
- Lazy loading for settings UI
- Memory mapped file reading for large logs

## Security

- Validate all file paths before access
- No hardcoded paths
- User-selected files via open panel or direct path entry

## Accessibility

- VoiceOver labels for menu items
- Keyboard shortcuts documented
- High contrast icon variants

## Code Review Checklist

- [ ] SwiftLint passes
- [ ] ShellCheck passes (for shell scripts)
- [ ] Tests pass and coverage maintained
- [ ] No force unwraps or force casts
- [ ] Documentation updated
- [ ] Performance impact considered
- [ ] Error handling implemented

## Resources

- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [SwiftLint Rules](https://realm.github.io/SwiftLint/rule-directory.html)
- [Swift DocC](https://www.swift.org/documentation/docc/)
