# Changelog

All notable changes to Simmer will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-10-30

**Early Development Build** - Initial release with core functionality. Universal binary supports both Intel and Apple Silicon Macs.

### Implemented
- Menu bar application with icon animations (glow, pulse, blink)
- Log file monitoring with background file watchers
- Regex pattern matching with NSRegularExpression
- Pattern configuration UI with color picker and animation selection
- Recent matches menu (10 most recent with timestamps)
- Export/import pattern configurations as JSON
- Launch at login support via SMAppService
- File permission and deletion error handling
- High-frequency match warnings

### Known Limitations
- Test coverage at ~64% (target: 70%)
- No signing/notarization configured yet (app won't run on unmodified systems)
- Limited to local file monitoring (no remote logs)
- No custom icon sets
- No notification center integration

### Technical Details
- macOS 14.0+ (Sonoma) required
- Swift 5.9+ with strict concurrency
- Protocol-based architecture for testability
- Background DispatchQueue for file I/O
- 60fps icon animations with graceful degradation

### Performance Targets
- <1% CPU when idle
- <5% CPU during active monitoring
- <50MB memory footprint
- <10ms pattern matching per line

---

## Release Notes

This is an early development build to establish CI/CD infrastructure and validate core functionality. Not recommended for production use until signing, notarization, and full test coverage are complete.
