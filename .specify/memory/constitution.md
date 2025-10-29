<!--
SYNC IMPACT REPORT
==================
Version Change: 1.0.0 → 1.1.0
Change Type: MINOR - Added CI/CD requirement to quality gates

Modified Sections:
- Quality Gates: Added gate #7 for CI/CD workflow enforcement

Modified Principles:
- None

Templates Requiring Updates:
✅ specs/001-mvp-core/plan.md (updated - Principle IV now references CI/CD)
✅ specs/001-mvp-core/tasks.md (updated - added T115-T117 for CI/CD workflows)
✅ .specify/templates/* (no changes required)

Follow-up TODOs:
- Implement T115: GitHub Actions workflow for automated testing
- Implement T116: GitHub Actions workflow for SwiftLint enforcement
- Implement T117: GitHub Actions workflow for build verification
-->

# Simmer Constitution

## Core Principles

### I. Simplicity First

Every feature MUST justify its existence against the MVP scope defined in VISION.md. No over-engineering. Components MUST have single responsibility. Complex inheritance hierarchies are prohibited. Start simple, apply YAGNI principles ruthlessly.

**Rationale**: Simmer is a minimal tool. Complexity is the enemy of maintainability and performance. Each unnecessary abstraction adds cognitive load and potential failure points.

### II. Native & Performant

System frameworks MUST be used exclusively. External dependencies are prohibited unless absolutely necessary and explicitly justified. File monitoring MUST run on background threads. UI updates MUST occur only on main thread. App MUST consume <1% CPU idle, <5% active, <50MB memory.

**Rationale**: Native macOS apps should leverage platform capabilities. Dependencies increase attack surface, maintenance burden, and binary size. Performance targets ensure passive monitoring remains truly passive.

### III. Developer-Centric UX

Users are developers comfortable with regex, file paths, and technical configuration. UI MUST NOT patronize or oversimplify. Regex syntax is expected. File paths support tilde expansion, environment variables, and wildcards. Configuration export/import uses JSON for programmability.

**Rationale**: The target audience expects power-user features. Hiding technical details would diminish utility and force workarounds.

### IV. Testing Discipline

Unit tests MUST cover 70% of codebase minimum. Critical paths (pattern matching, file monitoring) MUST have 100% coverage. Tests MUST exist before merging new business logic. File system operations MUST be mocked in tests. SwiftLint MUST pass without warnings.

**Rationale**: Menu bar apps run continuously in user environments. Bugs erode trust. Pattern matching and file watching are core value—they must be bulletproof.

### V. Concise Documentation

All project documentation MUST be clean, concise, and to the point. No walls of text. Every doc serves a specific purpose: VISION.md (what/why), TECH_DESIGN.md (architecture), STANDARDS.md (how to code), claude.md (AI guidance). Redundancy across docs is prohibited.

**Rationale**: Documentation becomes stale when verbose. Concise docs are maintained, read, and trusted. Developers hate fluff.

## Development Standards

All code MUST comply with STANDARDS.md:
- Swift 5.9+, SwiftUI + AppKit
- No force unwrapping or force casts in production
- Protocol-oriented design for testability
- Value types (struct) preferred over reference types (class)
- Conventional Commits for all commits
- SwiftLint configured and passing

Code structure MUST follow feature-based organization:
```
Features/MenuBar/    → Status item, menu, animations
Features/Monitoring/ → File watchers, log tailing
Features/Patterns/   → Regex matching engine
Features/Settings/   → Configuration UI
Models/              → Shared data models
Services/            → Persistence, file I/O
```

## Quality Gates

No PR may be merged without:
1. SwiftLint passing with zero warnings
2. All tests passing
3. Coverage requirements met (70% overall, 100% critical paths)
4. No force unwraps or force casts introduced
5. Public APIs documented with Swift DocC
6. Performance impact assessed (CPU/memory profiling for I/O changes)
7. CI/CD workflows passing (automated testing, linting, build verification)

Breaking changes to file monitoring, pattern matching, or configuration persistence MUST:
1. Document migration path in PR description
2. Provide backward compatibility or explicit version bump
3. Update TECH_DESIGN.md with architectural changes

## Governance

This constitution supersedes conflicting guidance in other docs. Amendments require:
1. Documented rationale for change
2. Impact assessment on existing features
3. Update to dependent templates and docs
4. Version bump following semantic versioning

Compliance verification:
- All PRs MUST reference constitution principles when making design decisions
- Code reviews MUST reject violations with specific principle citations
- Quarterly constitution review to prune obsolete rules or add emerging patterns

Runtime development guidance lives in claude.md and MUST align with this constitution. Any conflict defaults to constitution rules.

**Version**: 1.1.0 | **Ratified**: 2025-10-28 | **Last Amended**: 2025-10-28

**Amendments**:
- v1.1.0 (2025-10-28): Added CI/CD requirement to Quality Gates (gate #7)
