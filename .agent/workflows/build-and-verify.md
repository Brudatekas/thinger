---
description: Standard build, run, and verify workflow for macOS development
---

# Build and Verify Workflow

// turbo-all

## 1. Build the Application
```bash
make build
```
If build fails, xcbeautify will show the exact file and line. Fix the error and re-run.

## 2. Run the Application
```bash
make run
```

## 3. Capture Debug Snapshot (if UI issues)
```bash
make debug-snapshot
```
This exports screenshots, view hierarchy, and metadata to `debug-output/`.

## 4. Inspect Accessibility (if needed)
```bash
make axe
```
Check that all interactive elements have accessibility identifiers.

## When to Use This Workflow
- After making code changes
- When verifying a fix
- Before committing changes
