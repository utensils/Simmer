#!/bin/bash
#
# T132: Benchmark pattern matching timing with Instruments Time Profiler
# Verify <10ms per log line processing with 20 active patterns
#
# Usage: ./benchmark-pattern-matching.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
APP_PATH="${PROJECT_ROOT}/DerivedData/Build/Products/Release/Simmer.app"
TRACE_PATH="${PROJECT_ROOT}/DerivedData/Traces/pattern-matching-$(date +%Y%m%d-%H%M%S).trace"
TEST_LOGS_DIR="${PROJECT_ROOT}/test-logs"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== T132: Pattern Matching Performance ===${NC}"
echo "Target: <10ms per log line with 20 active patterns"
echo ""

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: Simmer.app not found${NC}"
    exit 1
fi

# Create test logs directory
mkdir -p "$TEST_LOGS_DIR"
mkdir -p "$(dirname "$TRACE_PATH")"

# Create 20 test log files
echo -e "${YELLOW}Creating 20 test log files with varied patterns...${NC}"
for i in {1..20}; do
    LOG_FILE="${TEST_LOGS_DIR}/pattern-test-${i}.log"
    echo "Initial content for pattern matching test ${i}" > "$LOG_FILE"
done

echo -e "${GREEN}✓ Test log files created${NC}"
echo ""

# Start the app
echo -e "${YELLOW}Launching Simmer.app...${NC}"
open "$APP_PATH"
sleep 5

APP_PID=$(pgrep -f "Simmer.app/Contents/MacOS/Simmer" | head -n 1)
if [ -z "$APP_PID" ]; then
    echo -e "${RED}Error: Could not find Simmer process${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Simmer running with PID: ${APP_PID}${NC}"
echo ""

echo -e "${YELLOW}MANUAL CONFIGURATION REQUIRED:${NC}"
echo "Configure 20 patterns with VARIED complexity:"
echo ""
echo "   Pattern 1-5 (simple): ERROR|WARN"
echo "   Pattern 6-10 (medium): \\[ERROR\\].*failed.*\\d+"
echo "   Pattern 11-15 (complex): (critical|fatal|error)\\s+in\\s+(\\w+):\\s*(.+)"
echo "   Pattern 16-20 (very complex): (?:exception|error|fail).*?(?:in|at)\\s+([\\w\\.]+)\\((.*?)\\)"
echo ""
for i in {1..20}; do
    LOG_FILE="${TEST_LOGS_DIR}/pattern-test-${i}.log"
    echo "   Pattern ${i} → ${LOG_FILE}"
done
echo ""
echo "Press ENTER when configuration is complete..."
read -r

# Start Instruments profiling
echo -e "${YELLOW}Starting Instruments Time Profiler (60 second capture)...${NC}"
echo "Trace will be saved to: ${TRACE_PATH}"
echo ""

instruments -t "Time Profiler" -D "$TRACE_PATH" -l 60000 -p "$APP_PID" &
INSTRUMENTS_PID=$!

sleep 5

# Generate test load with timing
echo -e "${YELLOW}Generating test lines at controlled rate...${NC}"
echo "Pattern: 100 lines/second for 50 seconds = 5000 total lines"
echo ""

START_TIME=$(date +%s%3N)

for second in {1..50}; do
    # Write 100 lines this second (distributed across 20 files)
    for line in {1..100}; do
        file_idx=$(( (line % 20) + 1 ))
        LOG_FILE="${TEST_LOGS_DIR}/pattern-test-${file_idx}.log"

        # Vary line content to exercise different pattern complexities
        case $((line % 4)) in
            0)
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR Simple error message ${second}-${line}" >> "$LOG_FILE"
                ;;
            1)
                echo "[ERROR] Operation failed with code 500 at line ${line}" >> "$LOG_FILE"
                ;;
            2)
                echo "CRITICAL in module_name: Complex error occurred during processing ${second}" >> "$LOG_FILE"
                ;;
            3)
                echo "Exception occurred at com.example.Handler(process) line ${line}" >> "$LOG_FILE"
                ;;
        esac
    done

    # Progress indicator
    if [ $((second % 10)) -eq 0 ]; then
        lines_so_far=$((second * 100))
        echo -e "${GREEN}  ${lines_so_far}/5000 lines written (${second}s elapsed)${NC}"
    fi

    sleep 1
done

END_TIME=$(date +%s%3N)
TOTAL_TIME=$((END_TIME - START_TIME))
TOTAL_SEC=$(echo "scale=2; $TOTAL_TIME / 1000" | bc)

echo ""
echo -e "${GREEN}✓ Load generation complete${NC}"
echo "Total lines: 5000"
echo "Duration: ${TOTAL_SEC}s"
echo ""

# Wait for instruments to finish
echo -e "${YELLOW}Waiting for Instruments to complete capture...${NC}"
wait $INSTRUMENTS_PID

echo -e "${GREEN}✓ Profiling complete${NC}"
echo ""

# Quit the app
echo -e "${YELLOW}Stopping Simmer...${NC}"
osascript -e 'quit app "Simmer"' 2>/dev/null || kill "$APP_PID" 2>/dev/null || true
sleep 2

echo ""
echo -e "${GREEN}=== PATTERN MATCHING BENCHMARK COMPLETE ===${NC}"
echo ""
echo "Trace saved to: ${TRACE_PATH}"
echo ""
echo -e "${YELLOW}MANUAL ANALYSIS REQUIRED:${NC}"
echo "1. Open the trace file in Instruments:"
echo "   open \"${TRACE_PATH}\""
echo ""
echo "2. Focus on pattern matching hot paths:"
echo "   - Enable 'Call Tree' view"
echo "   - Check 'Invert Call Tree' and 'Hide System Libraries'"
echo "   - Look for time in:"
echo "     * PatternMatcher.match()"
echo "     * NSRegularExpression.matches()"
echo "     * LogMonitor file reading"
echo ""
echo "3. Calculate per-line latency:"
echo "   - Total time in pattern matching / 5000 lines"
echo "   - Should be <10ms per line with 20 patterns"
echo "   - With 20 patterns, budget is ~0.5ms per pattern per line"
echo ""
echo "4. Identify bottlenecks:"
echo "   - Check if regex compilation is happening repeatedly"
echo "   - Verify batch processing is working"
echo "   - Look for main thread blocking (should be on background queue)"
echo ""
echo "5. Performance optimization opportunities:"
echo "   - Pre-compiled regex caching"
echo "   - Short-circuit on first match"
echo "   - Batch line processing"
echo "   - Priority-based early termination"
echo ""

echo -e "${YELLOW}Expected results:${NC}"
echo "- Simple patterns (ERROR|WARN): <0.1ms"
echo "- Medium patterns: <0.5ms"
echo "- Complex patterns: <2ms"
echo "- Very complex patterns: <5ms"
echo "- Average across all: <2ms per line"
echo ""

echo -e "${YELLOW}CLEANUP:${NC}"
echo "To remove test logs: rm -rf ${TEST_LOGS_DIR}"
echo ""
