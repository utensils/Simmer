# Simmer Vision & Scope

## Core Product Definition

Simmer is a macOS menu bar application that provides passive, non-intrusive visual feedback for log monitoring. It watches multiple log files for user-configured patterns and signals matches through subtle menu bar icon animations (glowing, pulsing). Designed for developers working with verbose worker queues who need ambient awareness without terminal overload.

## Essential Features (MVP)

**Pattern Configuration**: Users define regex patterns mapped to log file paths. Each pattern can specify color and animation style (glow, pulse, blink).

**Log Monitoring**: Background file watchers tail configured logs with minimal system impact. Pattern matching runs asynchronously without blocking the UI.

**Visual Feedback**: Menu bar icon transforms based on active matches. Multiple simultaneous matches blend or prioritize by severity. Animations are subtle enough for peripheral vision.

**Status Interface**: Click menu bar icon to see recent matches with timestamps, file sources, and matched content excerpts. Clear all notifications with one action.

**Configuration UI**: Simple settings window for adding/editing patterns, selecting log files, and configuring animation preferences.

## Technology Approach

Native macOS app built with Swift 5.9+, SwiftUI (settings), and AppKit (menu bar). File monitoring via DispatchSource. Pattern matching with NSRegularExpression. Zero dependencies beyond system frameworks. Launch at login via SMAppService.

## Strategic Priorities

**Minimal & Fast**: App should consume negligible CPU and memory. Icon animations must be smooth (60fps). Pattern matching should not lag log generation.

**Vibe Monitoring**: Feedback is ambient and peripheral. Users should feel the system's pulse without active monitoring. No intrusive notifications or sounds unless explicitly configured.

**Developer-First**: Configuration uses familiar regex syntax. Log paths support wildcards and environment variables. Export/import configs as JSON for sharing.

## Future Roadmap

Post-launch enhancements include remote log monitoring (SSH tailing), webhook triggers, custom icon sets, and integration with notification center for high-priority patterns.
