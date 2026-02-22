# Views

@Metadata {
    @PageColor(blue)
}

The SwiftUI views that compose Thinger's notch interface — from the root container
to individual item cards.

## Overview

All views live in the `Views/` directory and follow a strict hierarchy:

```
NotchView                         ← root view in NSPanel
├── expandedContent
│   ├── toolbar HStack            ← "hello" label + gear icon
│   └── WidgetShelf               ← horizontal widget container
│       ├── AirDropWidgetView     ← always-present AirDrop target
│       ├── DropZoneView × N      ← one per BatchViewModel
│       │   └── ItemCard × M      ← one per ShelfItem
│       └── PlaceholderDropZone   ← ghost "+" (visible during drags)
└── NotchShape                    ← custom clip mask with animatable corners
```

Every widget wraps its content in a ``WidgetTrayView``, which provides:
- A dashed-border visual container
- An `.onDrop` modifier with synchronous targeting feedback
- Foreground color changes when a drag hovers over the tray

### Data Flow

Views are driven by two `ObservableObject` view models:

| View Model | Scope | Key Published Properties |
|------------|-------|--------------------------|
| ``NotchViewModel`` | Global (one per app) | `notchState`, `batches`, `globalDragTargeting`, `desiredOpenWidth` |
| ``BatchViewModel`` | Per-widget | `batch.items`, `isTargeted` |

`NotchViewModel` is injected via `@EnvironmentObject`. `BatchViewModel` is passed
directly as an `@ObservedObject` parameter to ``DropZoneView``.

## Topics

### Root Container
- ``NotchView``
- ``NotchShape``

### Widget Shelf
- ``WidgetShelf``
- ``PlaceholderDropZone``
- ``ShelfWidthPreferenceKey``

### File Drop Zone
- ``DropZoneView``
- ``ItemCard``
- ``FileURLTransferable``

### AirDrop
- ``AirDropWidgetView``

### Shared Chrome
- ``WidgetTrayView``
