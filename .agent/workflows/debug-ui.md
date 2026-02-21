---
description: Visual debugging workflow using Peekaboo and Axe for UI inspection
---

# Debug UI Workflow

Use this workflow when the app builds and runs but UI elements are misaligned, missing, or behaving incorrectly.

// turbo-all

## 1. Capture Screenshot
```bash
make peekaboo
```
Screenshot saved to `debug-output/screenshot.png`.

## 2. Inspect View Hierarchy
```bash
make axe
```
Outputs the accessibility hierarchy showing all visible elements with their frames, labels, and identifiers.

## 3. Export Full Debug Snapshot
```bash
make debug-snapshot
```
Exports to `debug-output/`:
- `screenshot.png` - Current app state
- `hierarchy.json` - View hierarchy data
- `metadata.json` - App and device info

## 4. Analyze and Fix
Read the exported files in `debug-output/` to understand:
- Which views are visible and their positions
- Missing accessibility identifiers
- Layout constraint issues

## When to Use This Workflow
- UI element is in wrong position
- Button or view is not visible
- Layout looks different than expected
- Accessibility labels are missing
