---
description: Profile the macOS app using xctrace to identify performance issues
---

# Profile App with xctrace

This workflow runs a Time Profiler trace on the app to identify sources of lag and performance issues.

## Prerequisites
- The app should be buildable
- The app should be running (for some profiling methods)

## Steps

// turbo-all

1. Build the app:
```bash
make build
```

2. Create a profiles directory if it doesn't exist:
```bash
mkdir -p profiles
```

3. Run xctrace with the Time Profiler template (30-second recording):
```bash
xcrun xctrace record --template "Time Profiler" --attach thinger --time-limit 30s --output profiles/time_profile_$(date +%Y%m%d_%H%M%S).trace
```

4. View the table of contents of the trace:
```bash
xcrun xctrace export --input profiles/<trace_file>.trace --toc
```

5. Export the time profile summary:
```bash
xcrun xctrace export --input profiles/<trace_file>.trace --xpath '/trace-toc/run/data/table[@schema="time-profile"]' --output profiles/time_profile_summary.xml
```

6. Analyze the hottest functions (most CPU time):
```bash
cat profiles/time_profile_summary.xml | grep -oE 'name="[^"]*"' | sort | uniq -c | sort -rn | head -50
```

7. Filter for app-specific functions:
```bash
cat profiles/time_profile_summary.xml | grep -oE 'name="[^"]*"' | grep -iE "(Thinger|Notch|Shelf|Share|Drag)" | sort | uniq -c | sort -rn | head -30
```

8. Open the trace in Instruments for detailed visual analysis:
```bash
open profiles/<trace_file>.trace
```

## Available Templates

You can use different templates for different types of analysis:
- **Time Profiler** - CPU usage and call stacks (best for lag)
- **Allocations** - Memory allocations
- **Leaks** - Memory leaks
- **SwiftUI** - SwiftUI-specific performance

To see all available templates:
```bash
xcrun xctrace list templates
```

## Quick Profiling Commands

### Sample a running process (quick):
```bash
sample thinger 5 -file output.txt
```

### Check for memory leaks:
```bash
leaks thinger
```

## Interpreting Results

- **Microhangs (250-500ms)**: Minor UI stutters
- **Hangs (>500ms)**: Noticeable freezes
- **Severe Hangs (>2000ms)**: Major freezes

Look for:
1. High sample counts in app functions
2. Main thread blocking operations
3. Excessive view updates/layouts
