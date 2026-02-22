# ``thinger``

A macOS notch utility that transforms the MacBook's physical notch into a dynamic shelf and sharing hub.

@Metadata {
    @DisplayName("Thinger")
}

## Overview

Thinger is a macOS notch utility designed to act as a dynamic shelf and sharing hub. It resides in the physical notch area (or simulates one on notch-less screens) and expands when the user hovers over it or drags files toward it.

The app uses a hybrid SwiftUI/AppKit architecture: SwiftUI drives the UI, while an `NSPanel` configured as a floating, borderless HUD window ensures the notch sits above the menu bar and passes through clicks when collapsed.

### Architecture at a Glance

```
┌─ ThingerApp ──────────────────────────────────────────┐
│  SwiftUI App lifecycle + MenuBarExtra                  │
│  └─ AppDelegate (NSPanel management, DragDetector)     │
│      └─ NotchView (root SwiftUI view inside panel)     │
│          ├─ WidgetShelf (horizontal widget container)   │
│          │   ├─ AirDropWidgetView                      │
│          │   ├─ DropZoneView × N (one per batch)       │
│          │   └─ PlaceholderDropZone (ghost "+")         │
│          └─ All wrapped in WidgetTrayView trays        │
└────────────────────────────────────────────────────────┘
```

### Key Design Decisions

- **Single spring animation**: The notch uses one `.spring(response: 0.35)` animation for the open/close morph. All dimensions (width, height, corner radii) transition simultaneously.
- **Top-edge locking**: The `NSPanel` is positioned at a fixed max-size frame. SwiftUI grows the notch shape *downward* via `ZStack(alignment: .top)`.
- **Dynamic sizing**: `WidgetShelf` measures its intrinsic width via `GeometryReader` and pushes the needed size to `NotchViewModel.desiredOpenWidth`, so the notch auto-expands for more widgets.
- **Multi-batch system**: Each file drop creates a new `BatchViewModel`. Empty batches are pruned when the notch closes.

## Topics

### Views

- ``NotchView``
- ``NotchShape``
- ``WidgetShelf``
- ``PlaceholderDropZone``
- ``DropZoneView``
- ``ItemCard``
- ``FileURLTransferable``
- ``WidgetTrayView``
- ``AirDropWidgetView``
