# Simmer

Passive log monitoring for macOS with subtle visual feedback.

![Simmer Screenshot](docs/images/screenshot.png)

## What is Simmer?

Simmer lives in your menu bar and watches log files for patterns you care about. When it finds a match, the icon subtly glows or pulses. No intrusive notifications, no terminal overload—just ambient awareness of your systems.

Perfect for monitoring verbose worker queues, background jobs, or any logs that would otherwise flood your terminal during development.

## Status

Early development. Not yet functional.

## Features (Planned)

- Watch multiple log files simultaneously
- Configure regex patterns with custom colors and animations
- Menu bar icon animations: glow, pulse, blink
- Recent matches accessible from menu bar
- Export/import configurations
- Minimal resource usage

## Requirements

- macOS 14.0+ (Sonoma)
- Xcode 15.0+

## Building

```bash
git clone https://github.com/utensils/simmer.git
cd simmer
open Simmer.xcodeproj
# Build and run from Xcode (Cmd+R)
```

## Documentation

- [VISION.md](VISION.md) - Product vision and scope
- [TECH_DESIGN.md](TECH_DESIGN.md) - Technical architecture
- [STANDARDS.md](STANDARDS.md) - Coding standards
- [CLAUDE.md](CLAUDE.md) - AI assistant guidelines

## License

MIT License - see LICENSE file for details.

## Author

James Brink

## Contributing

This project is in early development. Issues and PRs welcome once initial implementation is complete.
