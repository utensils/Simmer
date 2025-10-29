# Tasks: Simmer MVP Core

**Input**: Design documents from `/specs/001-mvp-core/`
**Prerequisites**: plan.md, spec.md, data-model.md, contracts/internal-protocols.md

**Tests**: Following constitution Principle IV (Testing Discipline), tests are required for 70% coverage overall with 100% coverage for critical paths (pattern matching, file monitoring).

**Organization**: Tasks grouped by user story (P1→P4) to enable independent implementation and testing per constitution.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Phase 1: Setup & Infrastructure

**Purpose**: Project initialization and shared components used across all user stories

- [X] T001 Create Xcode project with macOS target, set deployment target to macOS 14.0+
- [X] T002 Configure Info.plist with LSUIElement=true for menu bar-only app
- [X] T003 Create directory structure: Simmer/{App,Features/{MenuBar,Monitoring,Patterns,Settings},Models,Services,Utilities}
- [X] T004 Create test directory structure: SimmerTests/{MenuBarTests,MonitoringTests,PatternsTests,ServicesTests,Mocks}
- [X] T005 Configure SwiftLint with .swiftlint.yml per STANDARDS.md (no force unwrap, no force cast, warnings as errors)
- [X] T006 [P] Create AnimationStyle enum in Simmer/Models/AnimationStyle.swift (cases: glow, pulse, blink)
- [X] T007 [P] Create CodableColor struct in Simmer/Utilities/CodableColor.swift with NSColor conversion methods
- [X] T008 [P] Create IconAnimationState enum in Simmer/Models/IconAnimationState.swift (idle, animating)
- [X] T009 [P] Create FileSystemProtocol in Simmer/Features/Monitoring/FileSystemProtocol.swift per contracts/internal-protocols.md
- [X] T010 [P] Create RealFileSystem conforming to FileSystemProtocol in Simmer/Features/Monitoring/RealFileSystem.swift
- [X] T011 [P] Create MockFileSystem conforming to FileSystemProtocol in SimmerTests/Mocks/MockFileSystem.swift

## Phase 2: Foundational Components

**Purpose**: Core components required by multiple user stories, must complete before story implementation

- [X] T012 [P] Create LogPattern model in Simmer/Models/LogPattern.swift with Codable conformance per data-model.md
- [X] T013 [P] Create MatchEvent model in Simmer/Models/MatchEvent.swift per data-model.md
- [X] T014 [P] Create ConfigurationStoreProtocol in Simmer/Services/ConfigurationStoreProtocol.swift
- [X] T015 Implement UserDefaultsStore conforming to ConfigurationStoreProtocol in Simmer/Services/ConfigurationStore.swift (load/save/update/delete patterns)
- [X] T016 Write tests for ConfigurationStore in SimmerTests/ServicesTests/ConfigurationStoreTests.swift (save, load, update, delete, persistence)
- [X] T017 [P] Create InMemoryStore conforming to ConfigurationStoreProtocol in SimmerTests/Mocks/InMemoryStore.swift for testing
- [X] T018 [P] Create PatternMatcherProtocol in Simmer/Features/Patterns/PatternMatcherProtocol.swift per contracts/internal-protocols.md
- [X] T019 Implement RegexPatternMatcher conforming to PatternMatcherProtocol in Simmer/Features/Patterns/PatternMatcher.swift using NSRegularExpression
- [X] T020 Write comprehensive tests for PatternMatcher in SimmerTests/PatternsTests/PatternMatcherTests.swift (100% coverage: empty strings, special chars, multiline, invalid regex)
- [X] T021 [P] Create MockPatternMatcher conforming to PatternMatcherProtocol in SimmerTests/Mocks/MockPatternMatcher.swift

## Phase 3: User Story 1 - Monitor Single Log with Visual Feedback (P1)

**Goal**: Basic log watching with icon animation when pattern matches

**Independent Test**: Start app with one configured pattern, append matching line to log file, verify icon animates with configured color/style

**Story Requirements**: FR-001, FR-002, FR-003, FR-004, FR-005, FR-006 | **Success Criteria**: SC-002, SC-003, SC-006

### Models & Services

- [X] T022 [P] [US1] Create FileWatcherDelegate protocol in Simmer/Features/Monitoring/FileWatcherDelegate.swift per contracts/internal-protocols.md
- [X] T023 [US1] Implement FileWatcher class in Simmer/Features/Monitoring/FileWatcher.swift using DispatchSource.makeFileSystemObjectSource with .write and .extend event masks
- [X] T024 [US1] Write FileWatcher tests in SimmerTests/MonitoringTests/FileWatcherTests.swift (100% coverage: file appends, deletions, permission errors, rapid changes with MockFileSystem)
- [X] T025 [P] [US1] Create IconAnimatorDelegate protocol in Simmer/Features/MenuBar/IconAnimatorDelegate.swift per contracts/internal-protocols.md

### Menu Bar Integration

- [X] T026 [US1] Implement IconAnimator class in Simmer/Features/MenuBar/IconAnimator.swift with Core Graphics frame generation at 60fps
- [X] T027 [US1] Implement glow animation style in IconAnimator (opacity interpolation 0.5→1.0→0.5, 2-second cycle)
- [X] T028 [US1] Implement pulse animation style in IconAnimator (scale 1.0→1.15→1.0 with opacity, 1.5-second cycle)
- [X] T029 [US1] Implement blink animation style in IconAnimator (hard on/off, 0.5-second intervals)
- [X] T030 [US1] Write IconAnimator tests in SimmerTests/MenuBarTests/IconAnimatorTests.swift (state machine transitions, frame generation timing)
- [X] T031 [US1] Create MenuBarController class in Simmer/Features/MenuBar/MenuBarController.swift managing NSStatusItem
- [X] T032 [US1] Implement IconAnimatorDelegate in MenuBarController to update NSStatusItem.button?.image on frame updates
- [X] T033 [US1] Wire MenuBarController to IconAnimator in MenuBarController initializer

### App Lifecycle & Coordination

- [X] T034 [US1] Create SimmerApp.swift in Simmer/App/SimmerApp.swift as @main entry point with LSUIElement configuration
- [X] T035 [US1] Create AppDelegate.swift in Simmer/App/AppDelegate.swift for app lifecycle events
- [X] T036 [US1] Create MatchEventHandlerDelegate protocol in Simmer/Features/Patterns/MatchEventHandlerDelegate.swift per contracts/internal-protocols.md
- [X] T037 [US1] Implement MatchEventHandler class in Simmer/Features/Patterns/MatchEventHandler.swift with in-memory history array (max 100 items, FIFO pruning)
- [X] T038 [US1] Write MatchEventHandler tests in SimmerTests/PatternsTests/MatchEventHandlerTests.swift (history pruning, prioritization, FIFO behavior)
- [X] T039 [US1] Implement LogMonitor coordinator in Simmer/Features/Monitoring/LogMonitor.swift integrating FileWatcher, PatternMatcher, MatchEventHandler, and IconAnimator
- [X] T040 [US1] Implement FileWatcherDelegate in LogMonitor to receive file change events and trigger pattern matching
- [X] T041 [US1] Implement MatchEventHandlerDelegate in LogMonitor to receive match events and trigger icon animations
- [X] T042 [US1] Write LogMonitor tests in SimmerTests/MonitoringTests/LogMonitorTests.swift (single watcher coordination, match event flow)
- [X] T043 [US1] Wire SimmerApp to instantiate MenuBarController and LogMonitor on launch
- [X] T044 [US1] Manual test: Create test log file, hardcode one pattern in LogMonitor init, run app, append matching line, verify icon animates

## Phase 4: User Story 2 - Review Recent Matches (P2)

**Goal**: Menu displays match history with timestamps, excerpts, and high-frequency warnings

**Independent Test**: Configure pattern, trigger 5 matches, click menu bar icon, verify 5 matches displayed with pattern names and relative timestamps

**Story Requirements**: FR-007, FR-008, FR-009, EC-005 | **Success Criteria**: SC-008

**Dependencies**: Requires US1 complete (MatchEventHandler with history tracking already implemented)

### Utilities & Menu Construction

- [X] T045 [P] [US2] Create RelativeTimeFormatter in Simmer/Utilities/RelativeTimeFormatter.swift to format timestamps as "2m ago", "1h ago"
- [X] T046 [US2] Write RelativeTimeFormatter tests in SimmerTests/UtilitiesTests/RelativeTimeFormatterTests.swift (seconds, minutes, hours, days formatting)
- [X] T047 [US2] Create MenuBuilder class in Simmer/Features/MenuBar/MenuBuilder.swift to construct NSMenu from MatchEvent array
- [X] T048 [US2] Implement buildMatchHistoryMenu method in MenuBuilder querying MatchEventHandler for recent 10 matches
- [X] T049 [US2] Implement Clear All menu action in MenuBuilder calling MatchEventHandler.clearHistory()
- [X] T050 [US2] Implement Settings menu action in MenuBuilder (placeholder, opens alert for US3)
- [X] T051 [US2] Implement Quit menu action in MenuBuilder calling NSApplication.shared.terminate()
- [X] T052 [US2] Write MenuBuilder tests in SimmerTests/MenuBarTests/MenuBuilderTests.swift (menu structure, 10-item limit, empty state, Clear All action)
- [X] T053 [US2] Integrate MenuBuilder with MenuBarController to build menu on statusItem click
- [X] T054 [US2] Implement menu refresh on MatchEventHandlerDelegate.historyDidUpdate callback in MenuBarController
- [X] T055 [US2] Manual test: Trigger multiple matches, click icon, verify menu shows recent 10 with timestamps, test Clear All
- [ ] T121 [US2] Extend MatchEventHandler to track consecutive matches per pattern and emit warning events after 50 consecutive matches (EC-005)
- [ ] T122 [US2] Surface EC-005 warning in MenuBuilder/MenuBar UI (dedicated menu item + highlight) and clear warning after manual reset
- [ ] T123 [US2] Write tests for EC-005 warning flow covering threshold detection, reset, and UI rendering (MatchEventHandlerTests, MenuBuilderTests)

## Phase 5: User Story 3 - Configure Patterns and Files (P3)

**Goal**: Settings UI for pattern CRUD, file picker, regex validation, and JSON import/export

**Independent Test**: Open settings, add new pattern with regex/file/color/animation, save, verify pattern persisted and monitoring starts

**Story Requirements**: FR-010, FR-011, FR-012, FR-013, FR-014, FR-015, FR-016, FR-027 | **Success Criteria**: SC-001, SC-005

**Dependencies**: Requires US1 complete (LogMonitor, ConfigurationStore)

### Validation & File Access

- [X] T056 [P] [US3] Create PatternValidator in Simmer/Features/Patterns/PatternValidator.swift with validateRegex method using NSRegularExpression syntax checking
- [X] T057 [US3] Write PatternValidator tests in SimmerTests/PatternsTests/PatternValidatorTests.swift (valid regex, invalid regex, empty patterns, special chars)
- [X] T058 [P] [US3] Create PathExpander utility in Simmer/Services/PathExpander.swift for tilde (~) and environment variable expansion
- [X] T059 [P] [US3] Create FileAccessManager in Simmer/Features/Monitoring/FileAccessManager.swift for security-scoped bookmark creation/resolution
- [X] T060 [US3] Implement requestAccess method in FileAccessManager using NSOpenPanel for file selection
- [X] T061 [US3] Implement bookmarkData generation and storage in FileAccessManager (store in UserDefaults alongside pattern)
- [X] T062 [US3] Implement bookmark resolution in FileAccessManager.resolveBookmark checking isStale flag

### Settings UI Components

- [X] T063 [P] [US3] Create SettingsWindow.swift in Simmer/Features/Settings/SettingsWindow.swift as SwiftUI WindowGroup coordinator
- [X] T064 [US3] Create PatternListView.swift in Simmer/Features/Settings/PatternListView.swift displaying patterns in SwiftUI List with add/edit/delete actions
- [X] T065 [US3] Implement ObservableObject ViewModel for PatternListView wrapping ConfigurationStore
- [X] T066 [US3] Create PatternEditorView.swift in Simmer/Features/Settings/PatternEditorView.swift as SwiftUI Form with fields for name, regex, logPath, color, animationStyle, enabled
- [X] T067 [US3] Integrate PatternValidator in PatternEditorView.swift to show inline regex errors on blur/save
- [X] T068 [US3] Create ColorPickerView.swift in Simmer/Features/Settings/ColorPickerView.swift wrapping ColorPicker with RGB sliders
- [X] T069 [US3] Implement file picker button in PatternEditorView calling FileAccessManager.requestAccess
- [X] T070 [US3] Implement save action in PatternEditorView calling ConfigurationStore.savePatterns and notifying LogMonitor
- [X] T071 [US3] Implement delete action in PatternListView calling ConfigurationStore.deletePattern and stopping associated FileWatcher
- [X] T072 [US3] Implement enable/disable toggle in PatternListView updating LogPattern.enabled and stopping/starting FileWatcher
- [X] T073 [US3] Wire Settings menu action in MenuBuilder to open SettingsWindow
- [X] T074 [US3] Implement LogMonitor.reloadPatterns method to sync with ConfigurationStore changes from settings UI
- [ ] T124 [US3] Implement ConfigurationExporter in Simmer/Services/ConfigurationExporter.swift to serialize patterns (including bookmark data) to JSON files (FR-027)
- [ ] T125 [US3] Implement ConfigurationImporter in Simmer/Services/ConfigurationImporter.swift with schema validation, duplicate resolution, and bookmark restoration (FR-027)
- [ ] T126 [US3] Write ConfigurationExportImportTests in SimmerTests/ServicesTests/ConfigurationExportImportTests.swift covering round-trip, invalid JSON, missing bookmarks (FR-027)
- [ ] T127 [US3] Add export action in Settings UI (button/menu) invoking ConfigurationExporter with security-scoped save panel (FR-027)
- [ ] T128 [US3] Add import action in Settings UI invoking ConfigurationImporter, surfacing inline errors, and reloading LogMonitor (FR-027)
- [ ] T129 [US3] Manual test: Export patterns, clear local store, import JSON, verify patterns restored with bookmarks and monitoring resumes (FR-027)
- [X] T075 [US3] Manual test: Open settings, add pattern with invalid regex (verify error), add valid pattern, save, verify monitoring starts, edit pattern, delete pattern

## Phase 6: User Story 4 - Monitor Multiple Logs Simultaneously (P4)

**Goal**: Support 20 concurrent file watchers with animation prioritization

**Independent Test**: Configure 3 patterns for 3 different log files, trigger matches in different files, verify highest-priority animation displayed

**Story Requirements**: FR-020 | **Success Criteria**: SC-004, SC-007

**Dependencies**: Requires US1, US2, US3 complete (all components implemented, now scaling to multiple watchers)

### Multi-Watcher Coordination

- [X] T076 [US4] Implement LogMonitor.watchers dictionary mapping pattern ID to FileWatcher instances
- [X] T077 [US4] Implement LogMonitor.addWatcher method creating FileWatcher for new patterns, enforce 20-watcher limit (EC-003, FR-020)
- [X] T078 [US4] Implement LogMonitor.removeWatcher method cleaning up DispatchSource and file descriptor
- [X] T079 [US4] Implement animation prioritization in LogMonitor based on pattern array order (first = highest priority) (FR-025)
- [X] T080 [US4] Update MatchEventHandler to track pattern priority and only trigger animation for highest-priority active match
- [X] T081 [US4] Implement debouncing in LogMonitor to coalesce rapid matches within 100ms window per TECH_DESIGN.md
- [X] T082 [US4] Write multi-watcher tests in SimmerTests/MonitoringTests/LogMonitorTests.swift (20 concurrent watchers, prioritization, debouncing)
- [ ] T148 [US4] Display EC-003 warning alert with message "Maximum 20 patterns supported" when user attempts to add or enable a 21st pattern (FR-020, EC-003)
- [ ] T149 [US4] Extend LogMonitorTests or MenuBuilderTests to verify EC-003 warning presentation and dismissal when pattern count returns below the limit (FR-020, EC-003)
- [ ] T083 [US4] Profile with Instruments Time Profiler: verify <5% CPU with 10 active patterns and 100 matches/second
- [ ] T084 [US4] Profile with Instruments Allocations: verify <50MB memory with 20 patterns and 10k match history
- [ ] T085 [US4] Manual test: Configure 5 patterns for 5 different log files, trigger simultaneous matches, verify correct animation priority

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Error handling, edge cases, performance optimization, final integration

**Story Requirements**: FR-017, FR-018, FR-019, FR-021, FR-022, FR-023, FR-024 | **Success Criteria**: SC-002, SC-003, SC-004, SC-006, SC-007, SC-008

### Error Handling & Edge Cases

- [X] T086 [P] Implement file deletion handling in FileWatcher: catch .delete DispatchSource event, notify delegate with FileWatcherError.fileDeleted (EC-001, FR-022)
- [X] T087 [P] Implement permission error handling in FileWatcher: catch open() errors, notify delegate with FileWatcherError.permissionDenied
- [X] T088 Implement error UI alerts in LogMonitor for FileWatcherError cases: show NSAlert, disable affected pattern, update settings UI
- [X] T089 [P] Implement path expansion in PathExpander: replace ~ with NSHomeDirectory(), expand environment variables via ProcessInfo
- [X] T090 Integrate PathExpander in PatternEditorView to expand logPath before saving
- [X] T091 Integrate PathExpander in FileWatcher to expand path before opening file descriptor
- [X] T092 [P] Implement incremental line reading in FileWatcher: maintain file position with lseek, only read new content (EC-004, FR-023)
- [X] T093 [P] Implement match line truncation in MatchEvent init: limit matchedLine to 200 chars with "..." suffix per data-model.md
- [X] T118 [P] Harden FileWatcher teardown so disabling patterns does not emit false errors; add unit coverage in FileWatcherTests.swift
- [X] T119 Validate manually-entered log paths before enabling watchers; disable pattern with actionable alert when path is missing or unreadable

### Animation Resilience

- [ ] T145 Implement animation fallback in IconAnimator so 60fps rendering gracefully drops to 30fps or pauses when frame budgets are exceeded, and resumes full speed once resources recover (FR-006)
- [ ] T146 Write IconAnimator fallback tests in SimmerTests/MenuBarTests/IconAnimatorTests.swift covering degrade-to-30fps and resume-to-60fps scenarios (FR-006)

### Performance Optimization

- [X] T094 Implement regex pre-compilation in LogPattern: compile NSRegularExpression once on init, cache in property (EC-002)
- [X] T095 Implement batch pattern matching in LogMonitor: evaluate all enabled patterns per line in single background queue pass (EC-002)
- [X] T096 Add background queue to LogMonitor for all file I/O and pattern matching (DispatchQueue with .userInitiated QoS) (EC-002)
- [X] T097 Implement animation frame budget verification in IconAnimator: log warning if Core Graphics rendering exceeds 2ms
- [ ] T098 Profile idle CPU usage with Activity Monitor: verify <1% with 10 patterns, no matches for 5 minutes
- [ ] T099 Profile active CPU usage with Activity Monitor: verify <5% with 10 patterns, 100 matches/second
- [ ] T100 Profile memory usage with Activity Monitor: verify <50MB with 20 patterns, 1000 match history
- [X] T130 Instrument LogMonitor latency measurement and assert per-match timing <10ms in SimmerTests/MonitoringTests/LogMonitorTests.swift (FR-019, SC-007)
- [X] T131 Add LogMonitor latency test ensuring visual feedback occurs within 500ms (SC-002)
- [ ] T132 [P] Benchmark pattern matching timing with Instruments Time Profiler: verify <10ms per log line processing with 20 active patterns (FR-019, SC-007)

### Launch & Persistence

- [X] T101 [P] Implement pattern loading in LogMonitor.init: call ConfigurationStore.loadPatterns, create FileWatcher for each enabled pattern
- [X] T102 [P] Implement security-scoped bookmark resolution in LogMonitor.init: resolve bookmarks via FileAccessManager, prompt user if stale
- [X] T103 [P] Add launch at login infrastructure in AppDelegate using SMAppService (macOS 13+) - disabled by default
- [X] T104 Implement app launch performance optimization: defer non-critical init until after window appears
- [ ] T105 Measure app launch time with Instruments: verify <2 seconds from click to ready (SC-006)
- [X] T120 [P] Create LaunchAtLoginControlling protocol and LaunchAtLoginController implementation with SMAppService integration and UserDefaults persistence (FR-026 infrastructure)
- [ ] T141 [US3] Add "Launch at Login" toggle to Settings UI in PatternListView or dedicated preferences section (FR-026 UI)
- [ ] T142 [US3] Wire Settings toggle to LaunchAtLoginController.setEnabled() via SettingsCoordinator (FR-026 integration)
- [ ] T143 [P] Write LaunchAtLoginController tests: mock SMAppService, verify register/unregister, test preference persistence and resolvedPreference logic (FR-026)
- [ ] T144 [US3] Write Settings UI tests: verify toggle state reflects LaunchAtLoginController preference, test enable/disable actions (FR-026)

### Final Integration & Testing

- [ ] T106 Run SwiftLint across entire codebase: verify zero warnings
- [ ] T107 Run all unit tests with code coverage: verify 70% overall coverage
- [ ] T108 Verify 100% coverage for critical paths: PatternMatcher, FileWatcher, MatchEventHandler
- [ ] T109 Manual edge case testing per spec.md: log file deletion, 10GB log files, 50+ patterns, pattern matching every line, rapid log output (1000 lines/sec)
- [ ] T110 End-to-end test: Fresh install, configure 3 patterns, monitor logs for 1 hour, verify no crashes/leaks, verify animations smooth
- [ ] T111 Create .swiftformat config file per STANDARDS.md if not exists
- [ ] T112 Run swiftformat across codebase for final formatting consistency
- [X] T113 Update TECH_DESIGN.md with any architectural changes discovered during implementation
- [X] T114 Document any open questions resolved during implementation in research.md
- [ ] T133 Conduct usability study with 20 target developers to measure SC-001 and SC-008 outcomes; document success/failure rates
- [ ] T134 Summarize usability study findings and remediation follow-ups in research.md and quickstart.md where applicable

### CI/CD & Automation

- [X] T115 [P] Create GitHub Actions workflow for automated testing (.github/workflows/test.yml): run xcodebuild test on PR/push, upload coverage report, fail if coverage <70% or critical paths <100%
- [X] T116 [P] Create GitHub Actions workflow for SwiftLint enforcement (.github/workflows/lint.yml): run swiftlint lint on all PRs, fail if warnings exist per constitution quality gates
- [X] T117 [P] Create GitHub Actions workflow for build verification (.github/workflows/build.yml): verify xcodebuild succeeds on macOS 14.0+, archive .app bundle as artifact

### Release & Distribution

- [X] T135 [P] Create Simmer.entitlements file with hardened runtime entitlements (com.apple.security.app-sandbox, com.apple.security.files.user-selected.read-write) for notarization (FR-028)
- [X] T136 [P] Create release.yml workflow: trigger on v* tags, import signing certificate from GitHub Secrets (APPLE_CERTIFICATE_P12, APPLE_CERTIFICATE_PASSWORD) (FR-028, FR-030)
- [X] T137 Set up notarization in release.yml: submit .app to Apple using notarytool with App Store Connect API key (APPLE_API_KEY_ID, APPLE_API_ISSUER, APPLE_API_KEY_CONTENT), poll for completion (FR-028)
- [X] T138 Implement stapling in release.yml: run `xcrun stapler staple` after notarization completes to embed approval ticket in .app bundle for offline verification (FR-029)
- [X] T139 [P] Create .dmg installer in release.yml: use native hdiutil tooling to generate Simmer-{version}.dmg with /Applications symlink, custom background, and icon positioning (FR-030)
- [X] T140 Create GitHub Release in release.yml: use actions/create-release to publish release with changelog, upload Simmer-{version}.dmg as asset, mark as draft for manual review (FR-030)

---

## Dependencies & Execution Order

### User Story Completion Order

```
Phase 1 (Setup) → Phase 2 (Foundational)
    ↓
Phase 3 (US1: Monitor Single Log) → Phase 4 (US2: Review Matches)
    ↓                                       ↓
    └────────────→ Phase 5 (US3: Configure Patterns)
                          ↓
                  Phase 6 (US4: Multiple Logs)
                          ↓
                  Phase 7 (Polish)
```

### Critical Path

Must complete sequentially:
1. **T001-T011**: Setup infrastructure
2. **T012-T021**: Foundational models and protocols
3. **T022-T044**: US1 core monitoring (blocks all other stories)
4. **T045-T055, T121-T123**: US2 menu history + warning UX (depends on US1)
5. **T056-T075, T124-T129**: US3 settings UI + JSON import/export (depends on US1)
6. **T076-T085, T148-T149**: US4 multi-watcher (depends on US1-US3)
7. **T086-T117, T130-T146**: Polish, performance, and research (depends on all stories)

### Parallel Opportunities Per Phase

**Phase 1** (T001-T011): T006, T007, T008, T009, T010, T011 can run in parallel after T003 completes

**Phase 2** (T012-T021): T012, T013, T014, T018, T021 can run in parallel; T015-T016 sequential; T019-T020 sequential

**Phase 3 (US1)** (T022-T044):
- Parallel: T022, T025 after foundational complete
- Sequential: T023→T024 (FileWatcher + tests)
- Parallel: T026-T029 (animation styles) after T025
- Sequential: T030 (tests after animations)
- Sequential: T031→T032→T033 (MenuBarController integration)
- Sequential: T034→T035 (app lifecycle)
- Parallel: T036, T037 after T021 complete
- Sequential: T038 (tests after handler)
- Sequential: T039→T040→T041→T042 (LogMonitor coordination)
- Sequential: T043→T044 (final wiring and manual test)

**Phase 4 (US2)** (T045-T055, T121-T123):
- Parallel: T045 can start immediately after Phase 1
- Sequential: T046 (tests after formatter)
- Sequential: T047→T048→T049→T050→T051→T052 (MenuBuilder implementation + tests)
- Sequential: T053→T054→T055 (integration and manual test)
- Sequential: T121→T122→T123 (EC-005 warning detection, UI, and tests)

**Phase 5 (US3)** (T056-T075, T124-T129):
- Parallel: T056, T058, T059 after Phase 2 complete
- Sequential: T057 (validator tests)
- Sequential: T060→T061→T062 (FileAccessManager)
- Parallel: T063, T064 after T056 complete
- Sequential: T065→T066→T067→T068→T069→T070 (PatternEditorView flow)
- Sequential: T071→T072 (list actions)
- Sequential: T073→T074 (integration plumbing)
- Sequential: T124→T125→T126 (export/import services + tests)
- Sequential: T127→T128→T129 (UI actions + manual round-trip validation)

**Phase 6 (US4)** (T076-T085, T148-T149):
- Sequential: T076→T077→T078→T079→T080→T081→T082→T148→T149 (multi-watcher logic & limit messaging)
- Parallel: T083, T084 (profiling)
- Sequential: T085 (manual test)

**Phase 7 (Polish)** (T086-T117, T130-T146):
- Parallel: T086, T087, T089, T092, T093 (independent error/edge case handlers)
- Sequential: T088 (error UI integration)
- Sequential: T090→T091 (path expansion integration)
- Sequential: T094→T095→T096 (performance optimizations)
- Sequential: T097 (frame budget verification)
- Parallel: T098, T099, T100 (profiling tasks)
- Sequential: T130→T131 (performance instrumentation)
- Parallel: T132 (manual performance profiling)
- Sequential: T145→T146 (animation fallback implementation and tests)
- Parallel: T101, T102, T103 (launch tasks)
- Sequential: T104→T105 (launch perf)
- Sequential: T106→T107→T108→T109→T110 (final testing)
- Parallel: T111, T112 (formatting)
- Parallel: T113, T114 (documentation)
- Parallel: T115, T116, T117 (CI/CD workflows)
- Sequential: T120→T141→T142 (launch at login infrastructure + UI)
- Parallel: T143, T144 (launch at login tests)
- Parallel: T135, T136, T139 (release infrastructure)
- Sequential: T137→T138→T140 (notarization pipeline)
- Sequential: T133→T134 (usability study + reporting)

---

## Implementation Strategy

### Minimum Viable Product (MVP)

**Deliver US1 first** as standalone MVP:
- Tasks T001-T044 create fully functional single-log monitoring with animations
- Independent test: Configure one pattern, monitor one log, see visual feedback
- Demonstrates core value proposition
- Approximately 40% of total tasks

### Incremental Delivery

1. **MVP**: US1 (T001-T044) - Core monitoring
2. **Iteration 2**: US2 (T045-T055, T121-T123) - Match history + warnings
3. **Iteration 3**: US3 (T056-T075, T124-T129) - Settings UI + JSON import/export
4. **Iteration 4**: US4 (T076-T085, T148-T149) - Multiple logs
5. **Final**: Polish (T086-T117, T130-T146) - Production ready, performance, research, release automation

Each iteration delivers independently testable value per constitution.

---

## Task Summary

**Total Tasks**: 148
- **Phase 1** (Setup): 11 tasks
- **Phase 2** (Foundational): 10 tasks
- **Phase 3** (US1): 23 tasks
- **Phase 4** (US2): 14 tasks
- **Phase 5** (US3): 26 tasks
- **Phase 6** (US4): 12 tasks
- **Phase 7** (Polish): 52 tasks

**Parallelizable Tasks**: 40 tasks marked with [P]

**Test Tasks**: 21 test suites covering all critical paths

**CI/CD & Release Tasks**: 9 tasks (3 CI/CD workflows + 6 release automation tasks)

**User Story Distribution**:
- US1 (Monitor Single Log): 23 tasks
- US2 (Review Matches): 14 tasks
- US3 (Configure Patterns): 26 tasks
- US4 (Multiple Logs): 10 tasks
- Setup/Foundational/Polish: 72 tasks
