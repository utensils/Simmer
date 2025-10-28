# Repository Guidelines

## Project Structure & Module Organization
Simmer is a macOS SwiftUI app. Core source lives in `Simmer/`, where `SimmerApp.swift` boots the scene and `ContentView.swift` hosts top-level UI, with shared assets in `Assets.xcassets`. Tests mirror the app layout: `SimmerTests/` for unit coverage and `SimmerUITests/` for UI flows. Planning artifacts live under `specs/001-mvp-core/`, while `VISION.md`, `TECH_DESIGN.md`, and `STANDARDS.md` provide scope, architecture, and style guidance. When adding features, follow the planned module map in `STANDARDS.md` (e.g., `Features/MenuBar`, `Services/`) so future growth stays modular.

## Build, Test, and Development Commands
- `open Simmer.xcodeproj` — launch the project in Xcode for interactive development.
- `xcodebuild -scheme Simmer -destination 'platform=macOS' build` — headless build for CI or pre-PR validation.
 - `xcodebuild -scheme Simmer -destination 'platform=macOS' test` — run XCTest and UI tests.
- `swiftformat .` — format Swift sources using the repository’s `.swiftformat` rules.
- `swiftlint` — lint Swift code and fail fast on style or safety violations.

## Coding Style & Naming Conventions
Adhere to `STANDARDS.md` and Swift API Design Guidelines: 2-space indentation, 100-character lines, trailing commas on multiline literals, and one blank line between methods. `SwiftFormat` handles layout; do not hand-tune around its output. `SwiftLint` forbids force unwraps/casts and treats warnings as errors in CI. Use `PascalCase` for types, `camelCase` for members, and prefix Booleans with `is`, `has`, or `should`. Document public-facing APIs with DocC comments and include a concise file header stating the purpose.

## Testing Guidelines
All tests use XCTest. Co-locate unit tests with their target module names (e.g., `SimmerTests/Monitoring/PatternMatcherTests.swift`) and name methods `test_<behavior>_when_<condition>`. Maintain ≥70% overall coverage and 100% on critical monitoring paths, using mocks for file system interactions. Before pushing, run `xcodebuild -scheme Simmer -destination 'platform=macOS' test`; UI smoke tests in `SimmerUITests/` should cover menu bar affordances and launch stability.

## Commit & Pull Request Guidelines
Create branches using `feature/*`, `fix/*`, or `refactor/*`. Commits follow Conventional Commit syntax (`type: summary`) with optional scoped bodies for context. Each pull request should describe the behavior change, link related spec tasks, and attach screenshots or GIFs when UI is affected. Verify `swiftlint` and the full test suite pass, confirm documentation updates in `TECH_DESIGN.md` or `specs/`, and request review once all acceptance criteria are satisfied.

## Documentation & Planning
Align roadmap changes with `VISION.md`, and reflect implementation decisions in `TECH_DESIGN.md` or new design notes. Update the task lists in `specs/001-mvp-core/` as milestones progress so agents share a common backlog state.
