# Feature Specification: Simmer MVP Core

**Feature Branch**: `001-mvp-core`
**Created**: 2025-10-28
**Status**: Draft
**Input**: User description: "initial MVP"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Monitor Single Log with Visual Feedback (Priority: P1)

Developer monitors a worker queue log file and receives passive visual feedback when error patterns appear.

**Why this priority**: Core value proposition - passive monitoring with visual feedback is the fundamental feature that differentiates Simmer.

**Independent Test**: Start app, configure one pattern for one log file, trigger a matching log entry, observe menu bar icon animation. Delivers immediate value for single-log monitoring use case.

**Acceptance Scenarios**:

1. **Given** app is running with a configured pattern, **When** a matching line is appended to the monitored log, **Then** the menu bar icon animates (glows/pulses/blinks) with the configured color
2. **Given** app is running and monitoring a log, **When** no matches occur for 5 minutes, **Then** the icon remains in idle state with minimal resource usage
3. **Given** multiple matches occur rapidly, **When** the icon is already animating, **Then** the animation continues smoothly without stuttering or dropping frames

---

### User Story 2 - Review Recent Matches (Priority: P2)

Developer clicks menu bar icon to view recent pattern matches with context for troubleshooting.

**Why this priority**: Essential for understanding what triggered alerts without switching to terminal.

**Independent Test**: Configure pattern, trigger matches, click icon to see match history. Works independently to provide match context and history browsing.

**Acceptance Scenarios**:

1. **Given** 3 pattern matches have occurred, **When** user clicks the menu bar icon, **Then** menu displays the 3 most recent matches with pattern name, timestamp, and matched line excerpt
2. **Given** match history exists, **When** user selects "Clear All" from menu, **Then** all match history is cleared and menu shows empty state
3. **Given** 15 matches have occurred, **When** user opens the menu, **Then** only the 10 most recent matches are displayed

---

### User Story 3 - Configure Patterns and Files (Priority: P3)

Developer opens settings to add, edit, and remove log patterns with associated files and visual preferences.

**Why this priority**: Required for customization but users could theoretically work with pre-configured patterns initially.

**Independent Test**: Open settings window, add a new pattern with regex/file path/color/animation, save and verify pattern is monitored. Provides full configuration capability.

**Acceptance Scenarios**:

1. **Given** settings window is open, **When** user adds a pattern with name, regex, log file path, color, and animation style, **Then** the pattern is saved and begins monitoring immediately
2. **Given** a pattern has invalid regex syntax, **When** user attempts to save, **Then** an inline error message appears explaining the regex syntax error
3. **Given** multiple patterns exist, **When** user disables a pattern, **Then** monitoring stops for that pattern but continues for others
4. **Given** user selects log file via file picker, **When** file requires permissions, **Then** system permission dialog appears and access is granted

---

### User Story 4 - Monitor Multiple Logs Simultaneously (Priority: P4)

Developer monitors multiple log files with different patterns and receives appropriate visual feedback for each.

**Why this priority**: Powerful but builds on P1-P3 foundations.

**Independent Test**: Configure 3 patterns for 3 different log files, trigger matches in different files, verify correct animations and match attribution.

**Acceptance Scenarios**:

1. **Given** 3 patterns are configured for different log files, **When** matches occur in different files simultaneously, **Then** icon animation reflects the highest-priority match color
2. **Given** patterns have different animation styles, **When** matches overlap, **Then** the animation style of the highest-priority pattern is used

---

### Edge Case Requirements

- **EC-001**: When monitored log file is deleted, system MUST detect deletion via DispatchSource .delete event (typically <100ms), stop the watcher, display notification to user, and mark pattern as inactive
- **EC-002**: When log output exceeds 1000 lines/second, system MUST implement debouncing (100ms window) and maintain <10% CPU usage; if CPU exceeds 10% despite debouncing, system MUST escalate to throttling (process matches every 500ms, ignoring intermediate lines)
- **EC-003**: When user configures more than 20 patterns, system MUST enforce FR-020 limit and display error message: "Maximum 20 patterns supported"
- **EC-004**: When log file exceeds 10GB, system MUST only read newly appended content (FR-023) without loading entire file into memory; file size MUST NOT impact memory usage (FR-018 still applies)
- **EC-005**: When regex pattern matches every line in verbose log (>100 consecutive matches), system MUST limit match history storage to 100 items (FIFO) and display warning after 50 consecutive matches: "Pattern '[name]' matching frequently - consider refining regex"

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: App MUST display as menu bar-only application (no dock icon) with status item icon
- **FR-002**: System MUST monitor configured log files for new appended content in real-time
- **FR-003**: System MUST evaluate each new log line against all enabled regex patterns
- **FR-004**: Menu bar icon MUST animate with configured style (glow, pulse, or blink) when pattern matches
- **FR-005**: System MUST generate icon animations programmatically using configured RGB colors
- **FR-006**: Menu bar icon MUST maintain smooth 60fps animation without degrading system performance; if 60fps cannot be sustained due to system load, animation MUST gracefully degrade to 30fps or pause until resources available
- **FR-007**: Menu bar menu MUST display up to 10 most recent matches with pattern name, relative timestamp, and line excerpt
- **FR-008**: Menu MUST provide "Clear All" action to remove all match history
- **FR-009**: Menu MUST provide "Settings" action to open configuration window
- **FR-010**: Settings window MUST allow adding patterns with: name, regex, log file path, color (RGB), animation style, enabled state
- **FR-011**: Settings window MUST validate regex syntax before saving and display inline errors for invalid patterns
- **FR-012**: Settings window MUST provide file picker for selecting log files
- **FR-013**: System MUST request and store file access permissions for selected log files using security-scoped bookmarks
- **FR-014**: System MUST persist pattern configurations across app restarts
- **FR-015**: System MUST support editing and deleting existing patterns
- **FR-016**: System MUST support disabling patterns without deleting them
- **FR-017**: App MUST consume less than 1% CPU when idle and less than 5% CPU during active monitoring
- **FR-018**: App MUST consume less than 50MB of sustained memory usage under typical load; transient spikes up to 75MB during bulk match processing (>50 matches/second) are acceptable if memory returns to baseline within 10 seconds
- **FR-019**: System MUST process pattern matching in less than 10ms per log line
- **FR-020**: System MUST limit simultaneous file watchers to 20 files maximum
- **FR-021**: System MUST handle file permission errors gracefully by displaying alerts and disabling affected patterns
- **FR-022**: System MUST handle log file deletion by stopping the watcher and marking pattern as inactive
- **FR-023**: System MUST read only newly appended content, not re-processing entire log files
- **FR-024**: System MUST support tilde (~) expansion and environment variables in log file paths
- **FR-025**: When multiple patterns match simultaneously, system MUST prioritize animation by pattern configuration order (first enabled pattern in list = highest priority)

### Key Entities

- **LogPattern**: Represents a monitoring configuration with name, regex pattern, target log file path, visual appearance (color, animation style), and enabled state
- **MatchEvent**: Represents a detected pattern match with reference to source pattern, timestamp, matched line content, and line number
- **IconAnimationState**: Represents current menu bar icon visual state (idle or animating with specific style and color)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developers can configure a complete monitoring pattern (regex, file, appearance) in under 60 seconds
- **SC-002**: Pattern matches appear as visual feedback within 500ms of log line being written
- **SC-003**: App maintains smooth icon animations at 60fps with CPU usage below 5% during active monitoring
- **SC-004**: Developers can monitor up to 10 log files simultaneously without performance degradation
- **SC-005**: 95% of developers successfully configure their first pattern without consulting documentation
- **SC-006**: App launches and becomes ready for monitoring in under 2 seconds
- **SC-007**: Pattern matching completes within 10ms per log line for patterns with up to 20 regex rules
- **SC-008**: Match history provides sufficient context (pattern name, timestamp, excerpt) for developers to identify issues without opening logs 80% of the time
