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

- [ ] T022 [P] [US1] Create FileWatcherDelegate protocol in Simmer/Features/Monitoring/FileWatcherDelegate.swift per contracts/internal-protocols.md
- [ ] T023 [US1] Implement FileWatcher class in Simmer/Features/Monitoring/FileWatcher.swift using DispatchSource.makeFileSystemObjectSource with .write and .extend event masks
- [ ] T024 [US1] Write FileWatcher tests in SimmerTests/MonitoringTests/FileWatcherTests.swift (100% coverage: file appends, deletions, permission errors, rapid changes with MockFileSystem)
- [ ] T025 [P] [US1] Create IconAnimatorDelegate protocol in Simmer/Features/MenuBar/IconAnimatorDelegate.swift per contracts/internal-protocols.md

### Menu Bar Integration

- [ ] T026 [US1] Implement IconAnimator class in Simmer/Features/MenuBar/IconAnimator.swift with Core Graphics frame generation at 60fps
- [ ] T027 [US1] Implement glow animation style in IconAnimator (opacity interpolation 0.5→1.0→0.5, 2-second cycle)
- [ ] T028 [US1] Implement pulse animation style in IconAnimator (scale 1.0→1.15→1.0 with opacity, 1.5-second cycle)
- [ ] T029 [US1] Implement blink animation style in IconAnimator (hard on/off, 0.5-second intervals)
- [ ] T030 [US1] Write IconAnimator tests in SimmerTests/MenuBarTests/IconAnimatorTests.swift (state machine transitions, frame generation timing)
- [ ] T031 [US1] Create MenuBarController class in Simmer/Features/MenuBar/MenuBarController.swift managing NSStatusItem
- [ ] T032 [US1] Implement IconAnimatorDelegate in MenuBarController to update NSStatusItem.button?.image on frame updates
- [ ] T033 [US1] Wire MenuBarController to IconAnimator in MenuBarController initializer

### App Lifecycle & Coordination

- [ ] T034 [US1] Create SimmerApp.swift in Simmer/App/SimmerApp.swift as @main entry point with LSUIElement configuration
- [ ] T035 [US1] Create AppDelegate.swift in Simmer/App/AppDelegate.swift for app lifecycle events
- [ ] T036 [US1] Create MatchEventHandlerDelegate protocol in Simmer/Features/Patterns/MatchEventHandlerDelegate.swift per contracts/internal-protocols.md
- [ ] T037 [US1] Implement MatchEventHandler class in Simmer/Features/Patterns/MatchEventHandler.swift with in-memory history array (max 100 items, FIFO pruning)
- [ ] T038 [US1] Write MatchEventHandler tests in SimmerTests/PatternsTests/MatchEventHandlerTests.swift (history pruning, prioritization, FIFO behavior)
- [ ] T039 [US1] Implement LogMonitor coordinator in Simmer/Features/Monitoring/LogMonitor.swift integrating FileWatcher, PatternMatcher, MatchEventHandler, and IconAnimator
- [ ] T040 [US1] Implement FileWatcherDelegate in LogMonitor to receive file change events and trigger pattern matching
- [ ] T041 [US1] Implement MatchEventHandlerDelegate in LogMonitor to receive match events and trigger icon animations
- [ ] T042 [US1] Write LogMonitor tests in SimmerTests/MonitoringTests/LogMonitorTests.swift (single watcher coordination, match event flow)
- [ ] T043 [US1] Wire SimmerApp to instantiate MenuBarController and LogMonitor on launch
- [ ] T044 [US1] Manual test: Create test log file, hardcode one pattern in LogMonitor init, run app, append matching line, verify icon animates

## Phase 4: User Story 2 - Review Recent Matches (P2)

**Goal**: Menu displays match history with timestamps and excerpts

**Independent Test**: Configure pattern, trigger 5 matches, click menu bar icon, verify 5 matches displayed with pattern names and relative timestamps

**Story Requirements**: FR-007, FR-008, FR-009 | **Success Criteria**: SC-008

**Dependencies**: Requires US1 complete (MatchEventHandler with history tracking already implemented)

### Utilities & Menu Construction

- [ ] T045 [P] [US2] Create RelativeTimeFormatter in Simmer/Utilities/RelativeTimeFormatter.swift to format timestamps as "2m ago", "1h ago"
- [ ] T046 [US2] Write RelativeTimeFormatter tests in SimmerTests/UtilitiesTests/RelativeTimeFormatterTests.swift (seconds, minutes, hours, days formatting)
- [ ] T047 [US2] Create MenuBuilder class in Simmer/Features/MenuBar/MenuBuilder.swift to construct NSMenu from MatchEvent array
- [ ] T048 [US2] Implement buildMatchHistoryMenu method in MenuBuilder querying MatchEventHandler for recent 10 matches
- [ ] T049 [US2] Implement Clear All menu action in MenuBuilder calling MatchEventHandler.clearHistory()
- [ ] T050 [US2] Implement Settings menu action in MenuBuilder (placeholder, opens alert for US3)
- [ ] T051 [US2] Implement Quit menu action in MenuBuilder calling NSApplication.shared.terminate()
- [ ] T052 [US2] Write MenuBuilder tests in SimmerTests/MenuBarTests/MenuBuilderTests.swift (menu structure, 10-item limit, empty state, Clear All action)
- [ ] T053 [US2] Integrate MenuBuilder with MenuBarController to build menu on statusItem click
- [ ] T054 [US2] Implement menu refresh on MatchEventHandlerDelegate.historyDidUpdate callback in MenuBarController
- [ ] T055 [US2] Manual test: Trigger multiple matches, click icon, verify menu shows recent 10 with timestamps, test Clear All

## Phase 5: User Story 3 - Configure Patterns and Files (P3)

**Goal**: Settings UI for pattern CRUD with file picker and regex validation

**Independent Test**: Open settings, add new pattern with regex/file/color/animation, save, verify pattern persisted and monitoring starts

**Story Requirements**: FR-010, FR-011, FR-012, FR-013, FR-014, FR-015, FR-016 | **Success Criteria**: SC-001, SC-005

**Dependencies**: Requires US1 complete (LogMonitor, ConfigurationStore)

### Validation & File Access

- [ ] T056 [P] [US3] Create PatternValidator in Simmer/Features/Patterns/PatternValidator.swift with validateRegex method using NSRegularExpression syntax checking
- [ ] T057 [US3] Write PatternValidator tests in SimmerTests/PatternsTests/PatternValidatorTests.swift (valid regex, invalid regex, empty patterns, special chars)
- [ ] T058 [P] [US3] Create PathExpander utility in Simmer/Services/PathExpander.swift for tilde (~) and environment variable expansion
- [ ] T059 [US3] Write PathExpander tests in SimmerTests/ServicesTests/PathExpanderTests.swift (tilde expansion ~/foo, env vars $HOME/$USER, invalid paths, nested expansion)
- [ ] T060 [P] [US3] Create FileAccessManager in Simmer/Features/Monitoring/FileAccessManager.swift for security-scoped bookmark creation/resolution
- [ ] T061 [US3] Implement requestAccess method in FileAccessManager using NSOpenPanel for file selection
- [ ] T062 [US3] Implement bookmarkData generation and storage in FileAccessManager (store in UserDefaults alongside pattern)
- [ ] T063 [US3] Implement bookmark resolution in FileAccessManager.resolveBookmark checking isStale flag

### Settings UI Components

- [ ] T064 [P] [US3] Create SettingsWindow.swift in Simmer/Features/Settings/SettingsWindow.swift as SwiftUI WindowGroup coordinator
- [ ] T065 [US3] Create PatternListView.swift in Simmer/Features/Settings/PatternListView.swift displaying patterns in SwiftUI List with add/edit/delete actions
- [ ] T066 [US3] Implement ObservableObject ViewModel for PatternListView wrapping ConfigurationStore
- [ ] T067 [US3] Create PatternEditorView.swift in Simmer/Features/Settings/PatternEditorView.swift as SwiftUI Form with fields for name, regex, logPath, color, animationStyle, enabled
- [ ] T068 [US3] Integrate PatternValidator in PatternEditorView.swift to show inline regex errors on blur/save
- [ ] T069 [US3] Create ColorPickerView.swift in Simmer/Features/Settings/ColorPickerView.swift wrapping ColorPicker with RGB sliders
- [ ] T070 [US3] Implement file picker button in PatternEditorView calling FileAccessManager.requestAccess
- [ ] T071 [US3] Implement save action in PatternEditorView calling ConfigurationStore.savePatterns and notifying LogMonitor
- [ ] T072 [US3] Implement delete action in PatternListView calling ConfigurationStore.deletePattern and stopping associated FileWatcher
- [ ] T073 [US3] Implement enable/disable toggle in PatternListView updating LogPattern.enabled and stopping/starting FileWatcher
- [ ] T074 [US3] Wire Settings menu action in MenuBuilder to open SettingsWindow
- [ ] T075 [US3] Implement LogMonitor.reloadPatterns method to sync with ConfigurationStore changes from settings UI
- [ ] T076 [US3] Manual test: Open settings, add pattern with invalid regex (verify error), add valid pattern, save, verify monitoring starts, edit pattern, delete pattern

## Phase 6: User Story 4 - Monitor Multiple Logs Simultaneously (P4)

**Goal**: Support 20 concurrent file watchers with animation prioritization

**Independent Test**: Configure 3 patterns for 3 different log files, trigger matches in different files, verify highest-priority animation displayed

**Story Requirements**: FR-020 | **Success Criteria**: SC-004, SC-007

**Dependencies**: Requires US1, US2, US3 complete (all components implemented, now scaling to multiple watchers)

### Multi-Watcher Coordination

- [ ] T077 [US4] Implement LogMonitor.watchers dictionary mapping pattern ID to FileWatcher instances
- [ ] T078 [US4] Implement LogMonitor.addWatcher method creating FileWatcher for new patterns, enforce 20-watcher limit (FR-020)
- [ ] T079 [US4] Implement LogMonitor.removeWatcher method cleaning up DispatchSource and file descriptor
- [ ] T080 [US4] Implement animation prioritization in LogMonitor based on pattern array order (first = highest priority)
- [ ] T081 [US4] Update MatchEventHandler to track pattern priority and only trigger animation for highest-priority active match
- [ ] T082 [US4] Implement debouncing in LogMonitor to coalesce rapid matches within 100ms window per EC-002; implement CPU monitoring to escalate to 500ms throttling if CPU exceeds 10%
- [ ] T083 [US4] Write multi-watcher tests in SimmerTests/MonitoringTests/LogMonitorTests.swift (20 concurrent watchers, prioritization, debouncing)
- [ ] T084 [US4] Profile with Instruments Time Profiler: verify <5% CPU with 10 active patterns and 100 matches/second
- [ ] T085 [US4] Profile with Instruments Allocations: verify <50MB memory with 20 patterns and 10k match history
- [ ] T086 [US4] Manual test: Configure 5 patterns for 5 different log files, trigger simultaneous matches, verify correct animation priority

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Error handling, edge cases, performance optimization, final integration

**Story Requirements**: FR-017, FR-018, FR-019, FR-021, FR-022, FR-023, FR-024

### Error Handling & Edge Cases

- [ ] T087 [P] Implement file deletion handling in FileWatcher: catch .delete DispatchSource event, notify delegate with FileWatcherError.fileDeleted
- [ ] T088 [P] Implement permission error handling in FileWatcher: catch open() errors, notify delegate with FileWatcherError.permissionDenied
- [ ] T089 Implement error UI alerts in LogMonitor for FileWatcherError cases: show NSAlert, disable affected pattern, update settings UI
- [ ] T090 [P] Implement path expansion in PathExpander: replace ~ with NSHomeDirectory(), expand environment variables via ProcessInfo
- [ ] T091 Integrate PathExpander in PatternEditorView to expand logPath before saving
- [ ] T092 Integrate PathExpander in FileWatcher to expand path before opening file descriptor
- [ ] T093 [P] Implement incremental line reading in FileWatcher: maintain file position with lseek, only read new content (FR-023)
- [ ] T094 [P] Implement match line truncation in MatchEvent init: limit matchedLine to 200 chars with "..." suffix per data-model.md

### Performance Optimization

- [ ] T095 Implement regex pre-compilation in LogPattern: compile NSRegularExpression once on init, cache in property
- [ ] T096 Implement batch pattern matching in LogMonitor: evaluate all enabled patterns per line in single background queue pass
- [ ] T097 Add background queue to LogMonitor for all file I/O and pattern matching (DispatchQueue with .userInitiated QoS)
- [ ] T098 Implement animation frame budget verification in IconAnimator: log warning if Core Graphics rendering exceeds 2ms
- [ ] T099 Profile idle CPU usage with Activity Monitor: verify <1% with 10 patterns, no matches for 5 minutes
- [ ] T100 Profile active CPU usage with Activity Monitor: verify <5% with 10 patterns, 100 matches/second
- [ ] T101 Verify 60fps icon animation with Instruments Time Profiler during active monitoring: confirm frame delivery at 16.67ms intervals, verify graceful degradation to 30fps if system load exceeds capacity per FR-006
- [ ] T102 Profile memory usage with Activity Monitor: verify <50MB with 20 patterns, 1000 match history

### Launch & Persistence

- [ ] T103 [P] Implement pattern loading in LogMonitor.init: call ConfigurationStore.loadPatterns, create FileWatcher for each enabled pattern
- [ ] T104 [P] Implement security-scoped bookmark resolution in LogMonitor.init: resolve bookmarks via FileAccessManager, prompt user if stale
- [ ] T105 [P] Add launch at login support in AppDelegate using SMAppService (macOS 13+) or LaunchServices
- [ ] T106 Implement app launch performance optimization: defer non-critical init until after window appears
- [ ] T107 Measure app launch time with Instruments: verify <2 seconds from click to ready (SC-006)

### Final Integration & Testing

- [ ] T108 Run SwiftLint across entire codebase: verify zero warnings
- [ ] T109 Run all unit tests with code coverage: verify 70% overall coverage
- [ ] T110 Verify 100% coverage for critical paths: PatternMatcher, FileWatcher, MatchEventHandler
- [ ] T111 Manual edge case testing per spec.md: log file deletion, 10GB log files, 50+ patterns, pattern matching every line, rapid log output (1000 lines/sec)
- [ ] T112 End-to-end test: Fresh install, configure 3 patterns, monitor logs for 1 hour, verify no crashes/leaks, verify animations smooth
- [ ] T113 Create .swiftformat config file per STANDARDS.md if not exists
- [ ] T114 Run swift-format across codebase for final formatting consistency
- [ ] T115 Update TECH_DESIGN.md with any architectural changes discovered during implementation
- [ ] T116 Document any open questions resolved during implementation in research.md

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
4. **T045-T055**: US2 menu history (depends on US1)
5. **T056-T075**: US3 settings UI (depends on US1)
6. **T076-T085**: US4 multi-watcher (depends on US1-US3)
7. **T086-T114**: Polish (depends on all stories)

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

**Phase 4 (US2)** (T045-T055):
- Parallel: T045 can start immediately after Phase 1
- Sequential: T046 (tests after formatter)
- Sequential: T047→T048→T049→T050→T051→T052 (MenuBuilder implementation + tests)
- Sequential: T053→T054→T055 (integration and manual test)

**Phase 5 (US3)** (T056-T075):
- Parallel: T056, T058, T059 after Phase 2 complete
- Sequential: T057 (validator tests)
- Sequential: T060→T061→T062 (FileAccessManager)
- Parallel: T063, T064 after T056 complete
- Sequential: T065→T066→T067→T068→T069→T070 (PatternEditorView flow)
- Sequential: T071→T072 (list actions)
- Sequential: T073→T074→T075 (integration and manual test)

**Phase 6 (US4)** (T076-T085):
- Sequential: T076→T077→T078→T079→T080→T081→T082 (multi-watcher logic)
- Parallel: T083, T084 (profiling)
- Sequential: T085 (manual test)

**Phase 7 (Polish)** (T086-T114):
- Parallel: T086, T087, T089, T092, T093 (independent error/edge case handlers)
- Sequential: T088 (error UI integration)
- Sequential: T090→T091 (path expansion integration)
- Sequential: T094→T095→T096 (performance optimizations)
- Sequential: T097 (frame budget verification)
- Parallel: T098, T099, T100 (profiling tasks)
- Parallel: T101, T102, T103 (launch tasks)
- Sequential: T104→T105 (launch perf)
- Sequential: T106→T107→T108→T109→T110 (final testing)
- Parallel: T111, T112 (formatting)
- Parallel: T113, T114 (documentation)

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
2. **Iteration 2**: US2 (T045-T055) - Match history
3. **Iteration 3**: US3 (T056-T075) - Settings UI
4. **Iteration 4**: US4 (T076-T085) - Multiple logs
5. **Final**: Polish (T086-T114) - Production ready

Each iteration delivers independently testable value per constitution.

---

## Task Summary

**Total Tasks**: 116
- **Phase 1** (Setup): 11 tasks
- **Phase 2** (Foundational): 10 tasks
- **Phase 3** (US1): 23 tasks
- **Phase 4** (US2): 11 tasks
- **Phase 5** (US3): 21 tasks
- **Phase 6** (US4): 10 tasks
- **Phase 7** (Polish): 30 tasks

**Parallelizable Tasks**: 32 tasks marked with [P]

**Test Tasks**: 17 test suites covering all critical paths

**User Story Distribution**:
- US1 (Monitor Single Log): 23 tasks
- US2 (Review Matches): 11 tasks
- US3 (Configure Patterns): 21 tasks
- US4 (Multiple Logs): 10 tasks
- Setup/Foundational/Polish: 51 tasks
