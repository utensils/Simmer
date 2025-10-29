# Profiling Playbook: Simmer MVP Core

**Scope**: Tasks T083–T084 (Time Profiler & Allocations) and prerequisites for Activity Monitor sessions.

## Test Fixtures

Use the helper script below to seed 10 synthetic patterns and log files under `/tmp/simmer-profiling`.

```bash
mkdir -p /tmp/simmer-profiling
python3 - <<'PY'
import json, os, uuid

root = "/tmp/simmer-profiling"
os.makedirs(root, exist_ok=True)
patterns = []
for idx in range(10):
    path = os.path.join(root, f"pattern-{idx}.log")
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("")

    patterns.append({
        "id": str(uuid.uuid4()),
        "name": f"Profiling Pattern {idx}",
        "regex": "ERROR",
        "logPath": path,
        "color": {"red": 1.0, "green": 0.2, "blue": 0.2, "alpha": 1.0},
        "animationStyle": "glow",
        "enabled": True
    })

payload = json.dumps(patterns)
with open("/tmp/simmer-profiling/patterns.json", "w", encoding="utf-8") as handle:
    handle.write(payload)
PY

/usr/libexec/PlistBuddy -c "Delete :patterns" ~/Library/Preferences/io.utensils.Simmer.plist 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :patterns data" ~/Library/Preferences/io.utensils.Simmer.plist
/usr/libexec/PlistBuddy -c "Set :patterns `python3 - <<'PY'
import base64
with open('/tmp/simmer-profiling/patterns.json', 'rb') as handle:
    print(base64.b64encode(handle.read()).decode('ascii'))
PY
`" ~/Library/Preferences/io.utensils.Simmer.plist
```

Restart Simmer after seeding so `LogMonitor` loads the fixtures.

## Generate Log Traffic

While profiling, tail each file with simulated matches to hit the 100 matches/second target:

```bash
python3 - <<'PY'
import threading, time, os
root = "/tmp/simmer-profiling"
files = [os.path.join(root, name) for name in os.listdir(root) if name.endswith('.log')]

def spam(path):
    with open(path, 'a', encoding='utf-8') as handle:
        while True:
            handle.write("2025-10-28 12:00:00 ERROR simulated match\n")
            handle.flush()
            time.sleep(0.01)  # 100 lines/sec

threads = [threading.Thread(target=spam, args=(fp,), daemon=True) for fp in files]
for thread in threads:
    thread.start()

print(f"Streaming to {len(files)} log files. Ctrl+C to stop.")
while True:
    time.sleep(1)
PY
```

## Time Profiler (T083)

1. Build the app:
   ```bash
   xcodebuild -scheme Simmer -configuration Release build
   ```
2. Launch Instruments headless for 120 seconds while the traffic script is running:
   ```bash
   xcrun xctrace record \
     --template "Time Profiler" \
     --process Simmer \
     --launch /Users/jamesbrink/Library/Developer/Xcode/DerivedData/Simmer-*/Build/Products/Release/Simmer.app \
     --time-limit 120s \
     --output /tmp/simmer-profiling/time-profiler
   ```
3. Export a summary:
   ```bash
   xcrun xctrace export --input /tmp/simmer-profiling/time-profiler.trace --output /tmp/simmer-profiling/time-profiler.txt --type summary
   ```
4. Confirm CPU usage stays below 5% (`avg_cpu` column in the summary). Attach the text file to PR artifacts.

## Allocations (T084)

Repeat the steps with the "Allocations" template and inspect the exported summary for resident size (`max_rss < 50 MB`).

```bash
xcrun xctrace record \
  --template "Allocations" \
  --process Simmer \
  --launch /Users/jamesbrink/Library/Developer/Xcode/DerivedData/Simmer-*/Build/Products/Release/Simmer.app \
  --time-limit 120s \
  --output /tmp/simmer-profiling/allocations

xcrun xctrace export --input /tmp/simmer-profiling/allocations.trace --output /tmp/simmer-profiling/allocations.txt --type summary
```

## Clean Up

Stop the spam script (Ctrl+C) and delete `/tmp/simmer-profiling` once profiling is complete.

```bash
rm -rf /tmp/simmer-profiling
```

Document results (CPU%, memory) in the PR description when closing T083/T084.
