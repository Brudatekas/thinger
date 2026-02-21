# Debug Snapshot Skill

## Quick Reference
```bash
make debug-snapshot   # Export full app state
make peekaboo         # Screenshot only
make axe              # Accessibility hierarchy only
```

## Output Directory
All debug output goes to `debug-output/`:
- `screenshot.png` - Current app screen capture
- `hierarchy.json` - View hierarchy with frames and properties
- `metadata.json` - Device and app info

## When to Use Debug Snapshots
Use this when:
- UI looks wrong but code seems correct
- Need to verify element positions
- App state differs from expected
- Debugging layout issues

## Reading the Hierarchy JSON
```json
{
  "views": [
    {
      "type": "VStack",
      "frame": {"x": 0, "y": 0, "width": 375, "height": 812},
      "children": [...]
    }
  ]
}
```

## Reading Metadata JSON
```json
{
  "app": {
    "bundleId": "com.example.istantransit",
    "version": "1.0.0"
  },
  "device": {
    "name": "iPhone 15",
    "osVersion": "17.0"
  },
  "timestamp": "2024-01-26T10:30:00Z"
}
```

## Debugging Workflow
1. Run `make debug-snapshot`
2. Open `debug-output/screenshot.png` to see current state
3. Read `debug-output/hierarchy.json` to understand view structure
4. Compare expected vs actual positions
5. Fix layout code
6. Re-run and verify

## Common Findings
- View hidden behind another view (z-order issue)
- Incorrect frame/constraints
- View exists but offscreen
- Accessibility identifier missing
