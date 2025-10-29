#!/bin/bash
#
# T084: Profile multi-watcher memory with Instruments Allocations
# Verify <50MB memory with 20 patterns and 10k match history
#
# Usage: ./benchmark-memory.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
APP_PATH="${PROJECT_ROOT}/DerivedData/Build/Products/Release/Simmer.app"
TRACE_PATH="${PROJECT_ROOT}/DerivedData/Traces/memory-footprint-$(date +%Y%m%d-%H%M%S).trace"
TEST_LOGS_DIR="${PROJECT_ROOT}/test-logs"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== T084: Memory Footprint Profiling ===${NC}"
echo "Target: <50MB with 20 patterns and 10k match history"
echo ""

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: Simmer.app not found at ${APP_PATH}${NC}"
    echo "Please build first: xcodebuild -project Simmer.xcodeproj -scheme Simmer -configuration Release build"
    exit 1
fi

# Create test logs directory
mkdir -p "$TEST_LOGS_DIR"
mkdir -p "$(dirname "$TRACE_PATH")"

# Create 20 test log files
echo -e "${YELLOW}Creating 20 test log files...${NC}"
for i in {1..20}; do
    LOG_FILE="${TEST_LOGS_DIR}/test-${i}.log"
    echo "Initial content for log ${i}" > "$LOG_FILE"
done

echo -e "${GREEN}✓ Test log files created${NC}"
echo ""

# Start the app
echo -e "${YELLOW}Launching Simmer.app...${NC}"
open "$APP_PATH"
sleep 5

# Get the PID
APP_PID=$(pgrep -f "Simmer.app/Contents/MacOS/Simmer" | head -n 1)
if [ -z "$APP_PID" ]; then
    echo -e "${RED}Error: Could not find Simmer process${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Simmer running with PID: ${APP_PID}${NC}"
echo ""

echo -e "${YELLOW}MANUAL CONFIGURATION REQUIRED:${NC}"
echo "1. Open Simmer settings"
echo "2. Configure 20 patterns (one for each test log file):"
echo ""
for i in {1..20}; do
    LOG_FILE="${TEST_LOGS_DIR}/test-${i}.log"
    echo "   Pattern ${i}: ERROR|WARN → ${LOG_FILE}"
done
echo ""
echo "3. After configuring all 20 patterns, press ENTER to continue..."
read -r

# Start Instruments profiling
echo -e "${YELLOW}Starting Instruments Allocations profiler (120 second capture)...${NC}"
echo "Trace will be saved to: ${TRACE_PATH}"
echo ""

instruments -t "Allocations" -D "$TRACE_PATH" -l 120000 -p "$APP_PID" &
INSTRUMENTS_PID=$!

sleep 5

# Generate 10k matches
echo -e "${YELLOW}Generating 10,000 match events...${NC}"
echo "This will create match history to test memory usage"
echo ""

TOTAL_MATCHES=10000
MATCHES_PER_BATCH=100
BATCHES=$((TOTAL_MATCHES / MATCHES_PER_BATCH))

for batch in $(seq 1 $BATCHES); do
    # Distribute matches across all 20 files
    for match in $(seq 1 $MATCHES_PER_BATCH); do
        file_idx=$(( (batch * match) % 20 + 1 ))
        LOG_FILE="${TEST_LOGS_DIR}/test-${file_idx}.log"
        echo "[$(date '+%Y-%m-%d %H:%M:%S.%3N')] ERROR Memory test match ${batch}-${match}" >> "$LOG_FILE"
    done

    # Progress indicator
    matches_so_far=$((batch * MATCHES_PER_BATCH))
    if [ $((batch % 10)) -eq 0 ]; then
        echo -e "${GREEN}  ${matches_so_far}/${TOTAL_MATCHES} matches generated...${NC}"
    fi

    # Brief pause to allow processing
    sleep 0.5
done

echo -e "${GREEN}✓ All 10,000 matches generated${NC}"
echo ""

# Let the system stabilize
echo -e "${YELLOW}Waiting 30 seconds for memory to stabilize...${NC}"
sleep 30

# Wait for instruments to finish
echo -e "${YELLOW}Waiting for Instruments to complete capture...${NC}"
wait $INSTRUMENTS_PID

echo -e "${GREEN}✓ Profiling complete${NC}"
echo ""

# Get current memory usage via Activity Monitor
echo -e "${YELLOW}Current memory usage:${NC}"
ps -p "$APP_PID" -o rss=,vsz= | awk '{printf "  RSS: %.2f MB\n  VSZ: %.2f MB\n", $1/1024, $2/1024}'
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
echo "2. Check 'All Heap & Anonymous VM' statistics:"
echo "   - Look at the final memory value (should be <50MB)"
echo "   - Check for memory leaks in the 'Leaks' section"
echo "   - Verify no persistent growth after stabilization"
echo ""
echo "3. Analyze allocation patterns:"
echo "   - Switch to 'Statistics' view"
echo "   - Sort by 'Persistent Bytes'"
echo "   - Look for MatchEvent, LogPattern, FileWatcher allocations"
echo "   - Verify MatchEventHandler pruning is working (should cap at 100 events)"
echo ""
echo "4. Document results"
echo ""

echo -e "${YELLOW}CLEANUP:${NC}"
echo "To remove test logs: rm -rf ${TEST_LOGS_DIR}"
echo ""
