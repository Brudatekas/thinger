# Accessibility Testing Skill

## Quick Reference
```bash
make axe            # Dump accessibility hierarchy
make a11y-audit     # Audit accessibility compliance
make a11y-report    # Generate accessibility report
```

## Accessibility Identifiers
Every interactive element MUST have an accessibility identifier for UI testing:

```swift
Button("Submit") {
    // action
}
.accessibilityIdentifier("submit_button")
```

## VoiceOver Labels
Add descriptive labels for VoiceOver users:

```swift
Image(systemName: "arrow.right")
    .accessibilityLabel("Next")
    .accessibilityHint("Go to the next screen")
```

## Dynamic Type Support
Use `@ScaledMetric` for dimensions that should scale:

```swift
@ScaledMetric var iconSize: CGFloat = 24
```

## Axe Output Format
The `make axe` command outputs hierarchy like:
```
Button "Submit" (submit_button)
  Frame: (16, 200, 343, 44)
  Traits: button
  Label: "Submit form"
```

## Common Issues

### Missing Accessibility Identifier
**Symptom**: Element not found in UI tests
**Fix**: Add `.accessibilityIdentifier("unique_id")`

### Generic Labels
**Symptom**: VoiceOver reads "button" instead of purpose
**Fix**: Add `.accessibilityLabel("descriptive text")`

### Non-Scaling UI
**Symptom**: Text truncates at larger type sizes
**Fix**: Use `@ScaledMetric` and flexible layouts

## Verification Steps
1. Run `make axe` to see current hierarchy
2. Verify all buttons have identifiers
3. Check that labels are descriptive
4. Test with larger text sizes in Settings > Accessibility
