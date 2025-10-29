# Simmer Performance Benchmark Suite

Comprehensive performance testing for tasks T083, T084, T085, T098, T099, T100, T105, and T132.

## Overview

This suite validates the performance requirements from the MVP specification:

- **FR-019**: <10ms pattern matching latency per log line
- **SC-002**: <500ms visual feedback after match detection
- **SC-003**: <1% idle CPU with 10 patterns
- **SC-004**: <5% active CPU with 100 matches/second
- **SC-006**: <2 second app launch time
- **SC-007**: <10ms per-match processing with 20 patterns

## Quick Start

### Run All Benchmarks

```bash
# Full suite (requires manual configuration)
./run-all-benchmarks.sh

# Quick mode (automated tests only, skips manual tests)
./run-all-benchmarks.sh --quick
```

### Run Individual Tests

```bash
# Baseline performance
./benchmark-baseline-idle.sh       # T098: 5 minute idle CPU test
./benchmark-baseline-active.sh     # T099: 1 minute active CPU test
./benchmark-baseline-memory.sh     # T100: Memory with 1000 matches

# Multi-watcher stress tests
./benchmark-multi-watcher.sh       # T083: CPU with 10 patterns
./benchmark-memory.sh              # T084: Memory with 20 patterns + 10k history

# Specific benchmarks
./benchmark-launch-time.sh         # T105: App launch timing
./benchmark-pattern-matching.sh    # T132: Regex performance
```

## Test Descriptions

### T098: Baseline Idle CPU

**Duration**: 5 minutes
**Target**: <1% CPU
**Configuration**: 10 patterns monitoring static log files

Validates that the app has minimal overhead when idle. Samples CPU every 5 seconds and calculates average.

**Pass Criteria**: Average CPU < 1.0%

---

### T099: Baseline Active CPU

**Duration**: 60 seconds
**Target**: <5% CPU
**Configuration**: 10 patterns, 100 matches/second

Generates sustained load with matches distributed across all patterns. Validates efficient pattern matching and animation handling under normal load.

**Pass Criteria**: Average CPU < 5.0%

---

### T100: Baseline Memory

**Target**: <50MB
**Configuration**: 20 patterns, 1000 match events

Tests memory usage with maximum pattern count and significant match history. Verifies MatchEventHandler pruning is working correctly.

**Pass Criteria**: Final memory < 50MB

---

### T083: Multi-Watcher CPU Profiling

**Duration**: 60 seconds
**Target**: <5% CPU
**Configuration**: 10 patterns, 100 matches/second distributed

Uses Instruments Time Profiler to identify CPU hotspots during multi-file monitoring. Generates detailed trace for analysis.

**Deliverable**: Instruments trace showing CPU usage breakdown

**Analysis**:
- Check LogMonitor, FileWatcher, PatternMatcher hot paths
- Verify background queue usage
- Identify optimization opportunities

---

### T084: Multi-Watcher Memory Profiling

**Target**: <50MB
**Configuration**: 20 patterns, 10,000 match events

Uses Instruments Allocations to track memory usage at scale. Verifies no memory leaks and proper history pruning.

**Deliverable**: Instruments trace showing allocations

**Analysis**:
- Check for memory leaks
- Verify MatchEvent pruning (should cap at 100 items)
- Identify allocation hotspots

---

### T105: Launch Time Measurement

**Target**: <2 seconds
**Method**: Automated timing (10 iterations)

Measures time from app launch to process ready. Provides average across multiple cold starts.

**Pass Criteria**: Average launch time < 2.0s

**Optional Detailed Analysis**:
Use Instruments System Trace to break down launch phases:
- Dyld loading
- Static initializers
- App initialization
- First UI draw

---

### T132: Pattern Matching Latency

**Target**: <10ms per line
**Configuration**: 20 patterns with varied complexity

Generates 5,000 log lines with patterns ranging from simple to very complex. Uses Instruments Time Profiler to measure regex performance.

**Pattern Complexity Levels**:
- Simple: `ERROR|WARN` (expected <0.1ms)
- Medium: `\[ERROR\].*failed.*\d+` (expected <0.5ms)
- Complex: `(critical|fatal|error)\s+in\s+(\w+):\s*(.+)` (expected <2ms)
- Very Complex: `(?:exception|error|fail).*?(?:in|at)\s+([\w\.]+)\((.*?)\)` (expected <5ms)

**Deliverable**: Instruments trace showing per-pattern timing

---

### T085: Multi-Pattern Priority (Manual Test)

**Target**: Verify animation prioritization
**Configuration**: 5 patterns with different priorities

This test is NOT automated. Requires manual verification:

1. Configure 5 patterns with different colors:
   - Pattern 1: ERROR → Red (highest priority)
   - Pattern 2: WARN → Yellow
   - Pattern 3: INFO → Blue
   - Pattern 4: DEBUG → Green
   - Pattern 5: TRACE → Gray (lowest priority)

2. Create 5 log files, one per pattern

3. Test scenarios:
   - Trigger Pattern 1 (ERROR) → Verify red animation
   - While animating red, trigger Pattern 5 (TRACE) → Verify animation stays red
   - Wait for animation to stop
   - Trigger Pattern 5 (TRACE) → Verify gray animation
   - While animating gray, trigger Pattern 1 (ERROR) → Verify switches to red

**Pass Criteria**: Higher-priority patterns always override lower-priority animations

---

## Prerequisites

1. **Build Release Configuration**:
   ```bash
   xcodebuild -project Simmer.xcodeproj -scheme Simmer \
              -configuration Release -derivedDataPath ./DerivedData build
   ```

2. **Install Xcode Command Line Tools**:
   ```bash
   xcode-select --install
   ```

3. **Instruments Access**: Ensure Xcode Instruments is installed

## Output

### Automated Results

- CPU samples: `DerivedData/Traces/*-cpu-samples.txt`
- Launch results: `DerivedData/Traces/launch-time-results.txt`
- Benchmark summary: `DerivedData/BenchmarkResults/benchmark-summary-*.md`

### Instruments Traces

All `.trace` files saved to `DerivedData/Traces/`:

- `multi-watcher-cpu-*.trace` (T083)
- `memory-footprint-*.trace` (T084)
- `pattern-matching-*.trace` (T132)

Open in Instruments:
```bash
open DerivedData/Traces/*.trace
```

### Test Logs

Test log files created in `test-logs/` directory. Clean up after testing:

```bash
rm -rf test-logs/
```

## Interpreting Results

### CPU Usage

- **<1%**: Excellent idle performance
- **1-5%**: Acceptable under load
- **>5%**: Investigate bottlenecks (check Instruments traces)

### Memory Usage

- **<20MB**: Excellent (minimal overhead)
- **20-50MB**: Acceptable (within target)
- **>50MB**: Investigate memory leaks or excessive history retention

### Launch Time

- **<1s**: Excellent
- **1-2s**: Acceptable (within target)
- **>2s**: Investigate slow initializers or blocking I/O

### Pattern Matching Latency

- **<5ms**: Excellent
- **5-10ms**: Acceptable (within target)
- **>10ms**: Optimize regex patterns or add short-circuit logic

## Troubleshooting

### "Simmer.app not found"

Build the app first:
```bash
xcodebuild -project Simmer.xcodeproj -scheme Simmer \
           -configuration Release -derivedDataPath ./DerivedData build
```

### "Could not find Simmer process"

The app failed to launch or crashed. Check:
1. App builds successfully
2. No conflicting instances running: `pkill -9 Simmer`
3. Console.app for crash logs

### Instruments fails to attach

1. Grant Instruments permissions in System Settings → Privacy & Security → Developer Tools
2. Ensure Xcode is trusted: `sudo DevToolsSecurity -enable`

### Tests fail with permission errors

The app may not have disk access. For non-sandboxed testing:
1. System Settings → Privacy & Security → Full Disk Access
2. Add Simmer.app

## Continuous Integration

These tests can be integrated into CI with:

```yaml
- name: Performance Tests
  run: |
    xcodebuild -project Simmer.xcodeproj -scheme Simmer \
               -configuration Release build
    ./scripts/performance/run-all-benchmarks.sh --quick
```

Note: Instruments requires macOS runner and may have variable results in CI. Consider gating on automated CPU/memory tests only.

## Maintenance

Update benchmarks when:
- Performance requirements change in spec.md
- New performance-critical features added
- Optimization work requires validation

Document results in:
- `specs/001-mvp-core/research.md` - Performance findings
- `DerivedData/BenchmarkResults/` - Historical benchmark data

## References

- **Tasks**: See `specs/001-mvp-core/tasks.md` for task definitions
- **Requirements**: See `specs/001-mvp-core/spec.md` for performance criteria
- **Architecture**: See `TECH_DESIGN.md` for implementation details
