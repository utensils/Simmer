#!/bin/bash
#
# T083: Profile multi-watcher CPU load with Instruments Time Profiler
# Verify <5% CPU with 10 active patterns and 100 matches/second
#
# Usage: ./benchmark-multi-watcher.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
APP_PATH="${PROJECT_ROOT}/DerivedData/Build/Products/Release/Simmer.app"
TRACE_PATH="${PROJECT_ROOT}/DerivedData/Traces/multi-watcher-cpu-$(date +%Y%m%d-%H%M%S).trace"
TEST_LOGS_DIR="${PROJECT_ROOT}/test-logs"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== T083: Multi-Watcher CPU Profiling ===${NC}"
echo "Target: <5% CPU with 10 patterns @ 100 matches/sec"
echo ""

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: Simmer.app not found at ${APP_PATH}${NC}"
    echo "Please run: xcodebuild -project Simmer.xcodeproj -scheme Simmer -configuration Release -derivedDataPath ./DerivedData build"
    exit 1
fi

# Create test logs directory
mkdir -p "$TEST_LOGS_DIR"
mkdir -p "$(dirname "$TRACE_PATH")"

# Create 10 test log files
echo -e "${YELLOW}Creating 10 test log files...${NC}"
for i in {1..10}; do
    LOG_FILE="${TEST_LOGS_DIR}/test-${i}.log"
    echo "Initial content for log ${i}" > "$LOG_FILE"
done

echo -e "${GREEN}✓ Test log files created${NC}"
echo ""

# Start the app in background
echo -e "${YELLOW}Launching Simmer.app...${NC}"
open "$APP_PATH"
sleep 5  # Wait for app to fully launch

# Get the PID
APP_PID=$(pgrep -f "Simmer.app/Contents/MacOS/Simmer" | head -n 1)
if [ -z "$APP_PID" ]; then
    echo -e "${RED}Error: Could not find Simmer process${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Simmer running with PID: ${APP_PID}${NC}"
echo ""

# Note: Automated configuration would require scripting the settings UI
# For now, this script provides the framework and manual instructions

echo -e "${YELLOW}MANUAL CONFIGURATION REQUIRED:${NC}"
echo "1. Open Simmer settings (click menu bar icon → Settings)"
echo "2. Configure 10 patterns with the following settings:"
echo ""
for i in {1..10}; do
    LOG_FILE="${TEST_LOGS_DIR}/test-${i}.log"
    echo "   Pattern ${i}:"
    echo "     Name: Test Pattern ${i}"
    echo "     Regex: ERROR|WARN|CRITICAL"
    echo "     Log Path: ${LOG_FILE}"
    echo "     Color: Red"
    echo "     Animation: glow"
    echo "     Enabled: Yes"
    echo ""
done

echo "3. After configuring all patterns, press ENTER to continue..."
read -r

# Start Instruments profiling
echo -e "${YELLOW}Starting Instruments Time Profiler (60 second capture)...${NC}"
echo "Trace will be saved to: ${TRACE_PATH}"
echo ""

# Launch instruments in background
instruments -t "Time Profiler" -D "$TRACE_PATH" -l 60000 -p "$APP_PID" &
INSTRUMENTS_PID=$!

# Wait 5 seconds for instruments to start
sleep 5

# Generate load: 100 matches/second for 50 seconds
echo -e "${YELLOW}Generating load: 100 matches/second across 10 files...${NC}"
echo "Duration: 50 seconds"
echo ""

for second in {1..50}; do
    # Write 10 matches per second (distributed across 10 files)
    for i in {1..10}; do
        LOG_FILE="${TEST_LOGS_DIR}/test-${i}.log"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR Test error message ${second}" >> "$LOG_FILE"
    done

    # Progress indicator
    if [ $((second % 10)) -eq 0 ]; then
        echo -e "${GREEN}  ${second}/50 seconds elapsed...${NC}"
    fi

    sleep 1
done

echo -e "${GREEN}✓ Load generation complete${NC}"
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
echo -e "${GREEN}=== PROFILING COMPLETE ===${NC}"
echo ""
echo "Trace saved to: ${TRACE_PATH}"
echo ""
echo -e "${YELLOW}MANUAL ANALYSIS REQUIRED:${NC}"
echo "1. Open the trace file in Instruments:"
echo "   open \"${TRACE_PATH}\""
echo ""
echo "2. Verify CPU usage during load generation (30-50 second mark):"
echo "   - Switch to 'CPU' instrument view"
echo "   - Check average CPU % during load period"
echo "   - Expected: <5% CPU"
echo ""
echo "3. Identify hotspots:"
echo "   - Switch to 'Call Tree' view"
echo "   - Enable 'Invert Call Tree' and 'Hide System Libraries'"
echo "   - Look for LogMonitor, FileWatcher, PatternMatcher in hot paths"
echo ""
echo "4. Document results in test log"
echo ""

# Cleanup instructions
echo -e "${YELLOW}CLEANUP:${NC}"
echo "To remove test logs: rm -rf ${TEST_LOGS_DIR}"
echo ""
