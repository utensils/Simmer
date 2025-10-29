# Repository Guidelines

## Project Structure & Module Organization
Simmer is a macOS SwiftUI app. Core app source lives in `Simmer/`, where `SimmerApp.swift` configures the scene and `ContentView.swift` hosts top-level UI. Shared assets reside in `Simmer/Assets.xcassets`. Unit tests mirror the app layout under `SimmerTests/`, and UI flows live in `SimmerUITests/`. Planning docs, including feature breakdowns, sit in `specs/001-mvp-core/`, while `VISION.md`, `TECH_DESIGN.md`, and `STANDARDS.md` capture roadmap, architecture, and coding expectations. Follow the module map in `STANDARDS.md` (e.g., `Features/MenuBar`, `Services/`) when adding features so code stays modular.

## Build, Test, and Development Commands
Run `open Simmer.xcodeproj` for interactive Xcode work. Use `xcodebuild -scheme Simmer -destination 'platform=macOS' build` for CI-style builds, and `xcodebuild -scheme Simmer -destination 'platform=macOS' test` to execute the XCTest and UI suites. Apply formatting with `swiftformat .` and lint with `swiftlint`; both tools gate CI, so keep them clean before committing.

## Coding Style & Naming Conventions
Adhere to Swift API Design Guidelines and `STANDARDS.md`: 2-space indentation, 100-character lines, trailing commas in multiline literals, and a blank line between methods. Avoid force unwraps and casts—`swiftlint` treats them as errors. Use `PascalCase` for types, `camelCase` for members, and prefix Booleans with `is`, `has`, or `should`. Document public APIs with DocC comments and add concise file headers describing intent.

## Testing Guidelines
All tests use XCTest. Co-locate new specs with their module in `SimmerTests/` or `SimmerUITests/`, and name methods `test_<behavior>_when_<condition>`. Maintain at least 70% overall coverage and 100% on monitoring-critical paths, mocking file system access where applicable. Validate changes with `xcodebuild -scheme Simmer -destination 'platform=macOS' test` before pushing.

## Commit & Pull Request Guidelines
Create branches under `feature/*`, `fix/*`, or `refactor/*`. Commits follow Conventional Commit syntax, e.g., `feat: add menu bar timer`. Pull requests must describe behavior changes, link relevant spec tasks, and include screenshots or GIFs when UI is affected. Confirm `swiftlint` and the full test suite pass, update `TECH_DESIGN.md` or `specs/001-mvp-core/` with new decisions, and request review once acceptance criteria are satisfied.
