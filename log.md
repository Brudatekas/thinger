## 2026-02-21: Centralize Notch Dimensions
- **Updated** `NotchDimensions.swift` — Added `hardwareTopCornerRadius` (6) and `hardwareBottomCornerRadius` (14) to centralize physical hardware specs. Added `usableNotchSize` to represent the central flat width of the notch (excluding its outward curves).
- **Updated** `NotchView.swift` — Replaced hardcoded default corner radii in the view and in `NotchShape` with centralized values from `NotchDimensions.shared`.
- **Updated** `DOCUMENTATION.md` — Documented the new pixel-perfect hardware constants and usable notch dimensions logic.

## 2026-02-21: Batch Expansion UX Rewrite
- **Updated** `DropZoneView.swift` — removed the manual expand/compress button from the controls.
- **Added** `.onTapGesture` to `collapsedStack` so that clicking the actual batch expands it visually.
- **Added** a "Minimize Batch" button to the `.contextMenu` of the expanded items and the row itself, making minimization a secondary action.

## 2026-02-21: Robust Drag Targeting and Hover
- **Moved** `isHovering`, `hoverTask`, and `handleHover()` from `NotchView` (local `@State`) to `NotchViewModel` (`@Published`). The VM now owns all hover logic: open on hover, delayed close on hover-off, lock check. Hover works over the entire expanded notch area.
- **Debounced Drag Targeting**: Added `updateGlobalDragTargeting(_:)` to `NotchViewModel` with a 50ms delayed close for `globalDragTargeting` to prevent UI flicker when dragging files from the outer notch background into inner widgets.
- **Synchronous Binding**: Replaced asynchronous `.onChange(of: isTargeted)` with synchronous `Binding` getters/setters in `DropZoneView` and `PlaceholderDropZone` so `activeTargetCount` updates instantly when the inner target captures the drop.
- **Updated** `FileCommand.buildCommand()` — output files now go to `$TMPDIR/thinger-output/` instead of next to the input file.
- **Updated** `DropZoneView.runCommand()` — command results spawn a new widget titled "Output: [command name]" instead of adding to the source batch.
- **Updated** `DropZoneView` controls — output widgets show a prominent title label (e.g., "OUTPUT: PDF → POWERPOINT").

## 2026-02-21: Extensive Test Suite
- **Expanded** `thingerTests.swift` from 10 to 42 tests across 5 suites:
  - **NotchViewModelTests** (14): state transitions, lock, targeting, multi-batch add/remove/prune/clear, hasNoFiles, close prunes, idempotency, toggle lock, target count floor.
  - **BatchViewModelTests** (7): item CRUD, dedup, clear, title, mutable title, multi-add, remove nonexistent, onItemsAdded callback.
  - **ShelfItemTests** (6): display name, identity key, icon, itemURL/fileURL distinction, unique ID.
  - **FileCommandTests** (12): temp dir output, extensions, filtering, case insensitive, unique IDs, metadata, placeholders, real sips PNG→JPEG, processAll, zip compression, nonexistent file.
  - **CommandErrorTests** (1): error description format.

## 2026-02-21: Dynamic Multi-Widget System
- **Updated** `NotchViewModel.swift` — replaced single `shelfBatch` with `@Published var batches: [BatchViewModel]`. Added `addBatch()`, `removeBatch()`, `pruneEmptyBatches()`, `clearAllBatches()`. Empty batches auto-prune on notch close.
- **Created** `WidgetShelf.swift` — container view showing widgets in an HStack. A `PlaceholderDropZone` (dashed "+" ghost) appears when dragging files and creates a new batch on drop.
- **Updated** `DropZoneView.swift` — removed empty state (empty widgets are pruned, not shown). Clear button now removes the widget entirely via `vm.removeBatch()`.
- **Updated** `thingerApp.swift` — menu item changed from "Clear Shelf" to "Clear All Widgets" calling `clearAllBatches()`.
- Build verified: **BUILD SUCCEEDED**. Tests verified: **10/10 PASSED**.

## 2026-02-21: File Command System
- **Created** `FileCommand.swift` — a model for shell commands that operate on dropped files. Each command has a `template` string with `{input}`, `{output}`, and `{outdir}` placeholders, an `outputExtension`, and a set of `acceptedExtensions` to filter which files it works on.
- **Built-in commands**: PDF→PowerPoint (via soffice), PDF→PNG, Image→JPEG, Image→PNG (via sips), Markdown→HTML, Compress to ZIP.
- **Runner**: `process(fileURL:)` and `processAll(fileURLs:)` execute via `Process()` + `/bin/zsh -c`. Async, returns output file URL on success.
- **Integrated** into `DropZoneView` — a gear (⚙) menu appears in the controls row when commands are available for the current files. Shows a spinner while running. Output files are added back to the batch.

## 2026-02-20: Widget Overhaul — Single Universal Drop Zone
- **Deleted** `ShelfStackView.swift`, `FileBatchWidget.swift`, `WidgetView.swift`, `ShelfView.swift` — removed the multi-widget system.
- **Created** `DropZoneView.swift` — a single universal drop zone that accepts any file type, URL, or text. Shows items as thumbnail cards with file icons and names. Supports collapsed (stacked preview, drag all) and expanded (side-by-side, drag individual) modes.
- **Simplified** `NotchViewModel.swift` — stripped all sharing/AirDrop code (QuickShareService, SharingLifecycleDelegate, share providers, session tracking). Kept: shelf batch, notch state, lock, targeting aggregation, `preventNotchClose` flag.
- **Updated** `NotchView.swift` — replaced `ShelfView()` → `DropZoneView()` in expanded content.
- **Updated** `thingerTests.swift` — replaced `testSharingSessionBlocksClose` with `testPreventNotchCloseBlocksClose` (direct flag test). Added `makeCleanVM()` helper to reset `@AppStorage("notchLocked")` between test runs, fixing test isolation.
- Build verified: **BUILD SUCCEEDED**. Tests verified: **10/10 PASSED**.

## 2026-02-20: Extensive Testing Suite
- Created a comprehensive test suite in `thingerTests.swift` targeting deep functionality out of UI.
- Integrated `Swift Testing` metrics for modern, async testing structure.
- **NotchViewModelTests**: Added tests for `open`/`close`/`toggle` transitions, `lockNotch` prevention state changes, Combine publisher dropping (`reportTargetingChange`), and `SharingStateManager` interaction session blocks.
- **BatchViewModelTests**: Added tests for `add`/`remove` item deduplication logic based on identity key matching.
- **ShelfItemTests**: Added comprehensive checks for resolving display names (truncating long strings), identity keys uniquely assigning identical URLs, and symbol names fetching.
- Resolves issue where `ShelfItem` initializer caused `async` context errors by refactoring tests outside macro arguments.
- Build and tests verified: **TESTS SUCCEEDED**.

## 2026-02-20: Architecture Merge
- Merged `ShelfDropService.swift` into `BatchViewModel` (in `FileBatch.swift`). Drop processing methods (`processProviders`, `processProvider`, `loadURLObject`, `loadItem`, `loadText`, `makeBookmark`) are now private methods on `BatchViewModel`.
- Merged `QuickShareService.swift` into `NotchViewModel.swift`. Share provider discovery, `shareItems()`, `shareDroppedFiles()`, `showFilePicker()`, and `QuickShareProvider` struct all live on `NotchViewModel` now.
- Merged `SharingStateManager.swift` into `NotchViewModel.swift`. Session counting (`activeSharingSessions`), `preventNotchClose`, `SharingLifecycleDelegate`, and the delegate factory (`makeSharingDelegate`) are now on `NotchViewModel`.
- Deleted `Services/ShelfDropService.swift`, `Services/QuickShareService.swift`, `Managers/SharingStateManager.swift`.
- Updated `NotchView.swift` — replaced `SharingStateManager.shared.preventNotchClose` → `vm.preventNotchClose`.
- Updated `FileBatchWidget.swift` — replaced `QuickShareService.shared.shareItems` → `vm.shareItems`, `QuickShareProvider.defaultProvider` → `vm.defaultShareProvider`.
- Updated `DOCUMENTATION.md` chapters 4.2, 5.3, and 6 to reflect merged architecture.
- Build verified: **BUILD SUCCEEDED**.

## 2026-02-20: Service Simplification
- Simplified `ShelfDropService.swift` from 430 → ~120 lines. Removed ASCII art UTI diagram and wall-of-text strategy comments. Merged 3 duplicate URL-loading helpers (`loadURL`, `loadURL(forType:)`, `extractFileURL`) into two simple helpers (`loadURLObject`, `loadItem`). All 4 fallback strategies still work.
- Simplified `QuickShareService.swift` from 243 → ~140 lines. Removed 3 duplicate `extractURL`/`extractFileURL`/`extractText` helpers — `shareDroppedFiles` now reuses `ShelfDropService.items(from:)` instead. Renamed `shareFilesOrText` → `shareItems`.
- Simplified `SharingStateManager.swift` from 181 → ~130 lines. Trimmed verbose MARK blocks and multi-line comments. All delegate logic unchanged.
- Simplified `ShelfItem.swift` from 185 → ~125 lines. Removed multi-line doc blocks, kept all Codable/Equatable/icon/displayName logic.
- Simplified `FileBatch.swift` from 157 → ~100 lines. Consolidated separate `saveToStorage()` calls into one `save()` method. Fixed typo "Unititled" → "Untitled".
- Updated `FileBatchWidget.swift` — renamed `shareFilesOrText` → `shareItems` (2 call sites).
- Updated `DOCUMENTATION.md` chapters 4.2 and 6.1 to match simplified code.
- Build verified: **BUILD SUCCEEDED**.

## 2026-02-15: NotchDimensions Singleton
- Created `NotchDimensions.swift` singleton to programmatically read notch dimensions from `NSScreen` APIs.
- Uses `auxiliaryTopLeftArea` / `auxiliaryTopRightArea` to derive notch width, and `safeAreaInsets.top` for height.
- `NotchView` now reads `closedWidth`/`closedHeight` from `NotchDimensions.shared` instead of hardcoded values.
- `AppDelegate.getClosedNotchSize` delegates to `NotchDimensions.shared.refresh(for:)` and `.closedSize`.
- Supports non-notch screens (falls back to menu bar height).
- Build verified: **BUILD SUCCEEDED**.

## 2026-02-15: Two-Phase Notch Hover Animation Overhaul
- **Major design overhaul** of the notch open/close animation.
- Uses `withAnimation(.interpolatingSpring)` + local `AnimPhase` state (closed/expanded/open) for a two-phase spring morph.
- Initially tried `KeyframeAnimator` but discovered it reverts to `initialValue` after animation completes, breaking the close animation.
- **Phase 1** (immediate): Width springs 200→350, height stays 32. Notch widens to pill shape.
- **Phase 2** (after 150ms): Width springs 350→500, height springs 32→180. Full notch with content.
- **Closing**: Single spring back to 200×32 from any state. `expandTask` cancelled if phase-2 is pending.
- **Top-edge locking**: `NSPanel` at fixed max-size frame (500×180). `ZStack(alignment: .top)` ensures growth downward only.
- Content fades in via conditional `if animPhase == .open` with `.transition(.opacity)`.
- `NotchViewModel` uses simple binary `closed/open` state; visual two-phase timing lives in `NotchView`.
- Build verified: **BUILD SUCCEEDED**.

## 2026-02-14: Interaction Model Documentation (Chapter 9)
- Added **Chapter 9: Interaction Model & Lifecycle** to `DOCUMENTATION.md`.
- Documents the five interaction signals that govern notch open/close: hover, global drag targeting, widget drop targeting, sharing session blocking, and lock.
- Explains the **300ms grace-period timer** in `NotchView.handleHover(_:)` — how it prevents premature close and is cancelled on re-entry.
- Details the **DragDetector**'s three global event monitors (`leftMouseDown`, `leftMouseDragged`, `leftMouseUp`) and how pasteboard change detection filters irrelevant drags.
- Covers **drop zone targeting aggregation** via Combine (`CombineLatest` → `anyDropZoneTargeting`) and the `activeTargetCount` counter.
- Explains **SharingStateManager** blocking close during AirDrop/share operations, including the 2-second timeout fallback.
- Documents **lock behavior** as the ultimate override on all open/close signals.
- Describes the **window resize animation** (0.25s ease-in-out via `NSAnimationContext`).
- Includes a **state machine diagram** and a **sequence diagram** (Mermaid) illustrating the full drag-to-share lifecycle.

## 2026-02-14: Notch Lock Feature
- Added `isLocked` property (persisted via `@AppStorage`) to `NotchViewModel`.
- When locked, `open()`, `close()`, and `toggle()` become no-ops — the notch stays in its current state.
- `NotchView.handleHover()` now skips all hover logic when locked, preventing accidental open/close.
- Added `lockNotch()`, `unlockNotch()`, and `toggleLock()` methods to `NotchViewModel`.
- Added a dynamic menu bar button in `thingerApp.swift` with ⌘L shortcut:
  - Shows **"Lock Open"** when the notch is open and unlocked.
  - Shows **"Lock Closed"** when the notch is closed and unlocked.
  - Shows **"Unlock Notch"** when the notch is currently locked.
- Updated `DOCUMENTATION.md` Chapter 2.1 and Chapter 3.2 to describe the lock feature.
- Build verified: **BUILD SUCCEEDED**.

## 2026-02-08: Shelf and Airdrop Implementation
- Implemented `WidgetView` as a reusable container for shelf and other future widgets.
- Implemented `ShelfStackView` to visualize files as a "stack of papers" with random rotation and offsets.
- Integrated `ShelfView` to use the new `WidgetView` and `ShelfStackView`.
- Added sharing functionality via a three-dot menu on the shelf widget.
- Verified drag and drop behavior and build success.
- Added "View Hierarchy Diagram" (Chapter 8) to `DOCUMENTATION.md` as requested.

## 2026-02-08: FileBatch Refactor
- Refactored application to use `FileBatch` and generic `BatchViewModel` for managing item collections.
- Created `FileBatchWidget.swift` as a reusable component for both Shelf and Share functionality.
- Removed legacy `ShelfStateViewModel` and `FileShareView`.
- Updated `NotchViewModel` to support generic widget targeting.
- **Fix:** Refactored `ShelfDropService` with robust multi-strategy extraction for file drops. Added comprehensive inline documentation explaining macOS UTI conformance, `NSItemProvider` handling, and security-scoped bookmarks.

## 2026-02-07: Comprehensive Documentation
- Completely rewrote `DOCUMENTATION.md` to provide a full, file-by-file breakdown of the system architecture.
- Included detailed flow descriptions for `App Entry`, `UI Core`, `Drag & Drop System`, `Data Models`, and `Sharing System`.
- Removed code snippets in favor of in-depth logical explanations as requested.

## 2026-02-07: Drag Detectors Separation
- Decoupled global notch expansion from widget-specific drop handling.
- `NotchView` no longer catches all drops; `ShelfView` and `FileShareView` manage their own.
- Updated `NotchViewModel` with `globalDragTargeting`, `shelfTargeting`, `fileShareTargeting` flags.

## 2026-02-07: Architecture Refactoring
- Moved menu bar from `NSStatusItem` to SwiftUI `MenuBarExtra` in App struct
- Fixed window configuration: style mask now includes `.utilityWindow`, `.hudWindow`
- Set window level to `.mainMenu + 3` (above menu bar, matching Boring Notch)
- Use `setFrameOrigin` for window positioning (like Boring Notch)
- Removed debug file-write code; simplified `AppDelegate`

## 2026-02-07: Boring Notch Source Analysis
- Explored `boringNotch/` source code added to project.
- Analyzed key components: `DragDetector`, `ShelfDropService`, `QuickShareService`, `SharingStateManager`.
- Updated `DOCUMENTATION.md` with architecture patterns for widget logic and drag-drop.
- Revised implementation plan to focus only on widget + AirDrop features (no music/calendar).

## 2026-02-07: Core Implementation Complete
- Created 11 Swift files: `thingerApp.swift`, `NotchView.swift`, `NotchViewModel.swift`, `DragDetector.swift`, `ShelfItem.swift`, `ShelfDropService.swift`, `ShelfStateViewModel.swift`, `QuickShareService.swift`, `SharingStateManager.swift`, `ShelfView.swift`, `ShelfItemView.swift`, `FileShareView.swift`
- Build succeeded with only deprecation warnings

## 2026-02-07: Menu Bar & Makefile Update
- Added status bar menu item with: Toggle Notch, Settings, Clear Shelf, Quit
- Updated Makefile for Thinger with xcbeautify, peekaboo, axe targets
- Updated workflows: `build-and-verify.md`, `profile-app.md` for macOS

## Initial Setup
- Created project structure documentation.
- Initialized log file.

