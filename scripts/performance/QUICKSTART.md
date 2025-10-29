# Performance Testing Quick Start

## Prerequisites

```bash
# Build Release configuration
xcodebuild -project Simmer.xcodeproj -scheme Simmer \
           -configuration Release -derivedDataPath ./DerivedData build
```

## Run All Tests

```bash
# Full suite (requires manual configuration)
./scripts/performance/run-all-benchmarks.sh

# Quick mode (automated only)
./scripts/performance/run-all-benchmarks.sh --quick
```

## Individual Tests

```bash
# Baseline performance
./scripts/performance/benchmark-baseline-idle.sh       # 5 min
./scripts/performance/benchmark-baseline-active.sh     # 1 min
./scripts/performance/benchmark-baseline-memory.sh     # 2 min

# Stress tests
./scripts/performance/benchmark-multi-watcher.sh       # 2 min + manual config
./scripts/performance/benchmark-memory.sh              # 3 min + manual config

# Specific benchmarks
./scripts/performance/benchmark-launch-time.sh         # 2 min (automated)
./scripts/performance/benchmark-pattern-matching.sh    # 2 min + manual config
```

## Performance Targets

| Metric | Target | Test |
|--------|--------|------|
| Launch time | <2s | T105 ✓ 1.120s |
| Idle CPU | <1% | T098 |
| Active CPU | <5% | T099, T083 |
| Memory | <50MB | T100, T084 |
| Pattern latency | <10ms/line | T132 |

## Results Location

```bash
# View traces
open DerivedData/Traces/*.trace

# View summaries
open DerivedData/BenchmarkResults/

# View samples
cat DerivedData/Traces/*-samples.txt
```

## Cleanup

```bash
# Remove test logs
rm -rf test-logs/

# Remove traces (optional)
rm -rf DerivedData/Traces/
```

## Quick Validation

```bash
# Just run launch time test (fastest, automated)
./scripts/performance/benchmark-launch-time.sh

# Expected: ~1.1s (target <2s) ✓
```

## Full Documentation

See `scripts/performance/README.md` for complete guide.
