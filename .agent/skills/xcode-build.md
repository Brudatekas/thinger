# Xcode Build Skill

## Quick Reference
```bash
make build          # Debug build with xcbeautify
make build-release  # Release build
make clean          # Clean build artifacts
```

## Common Build Errors

### Missing Dependencies
**Error**: `No such module 'PackageName'`
**Fix**: Run `make build` which resolves packages first, or manually:
```bash
xcodebuild -resolvePackageDependencies -project istantransit.xcodeproj -scheme istantransit
```

### Simulator ID Errors
**Error**: `Unable to find a destination matching...`
**Fix**: Do NOT hardcode simulator IDs. Use `make simulator-list` to find valid destinations.

### Signing Errors
**Error**: `Signing requires a development team`
**Fix**: Open Xcode, select the project, and configure signing in the Signing & Capabilities tab.

### Swift Version Mismatch
**Error**: `Module compiled with Swift X.Y cannot be imported by Swift X.Z`
**Fix**: Clean and rebuild:
```bash
make clean && make build
```

## Build Output Location
- Debug builds: `build/Build/Products/Debug/istantransit.app`
- Release builds: `build/Build/Products/Release/istantransit.app`

## xcbeautify Output
Build output is piped through xcbeautify which:
- Filters verbose compiler noise
- Shows only errors and warnings clearly
- Highlights the exact file:line for failures

## When Build Succeeds But App Crashes
1. Check console logs: `make run` then observe Console.app
2. Look for `fatalError`, `preconditionFailure`, or force unwraps
3. Use `make debug-snapshot` after launch to capture state
