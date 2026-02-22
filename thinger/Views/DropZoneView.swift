//
//  DropZoneView.swift
//  thinger
//
//  A single universal drop zone that accepts any file type, URL, or text.
//  Shows items as thumbnail cards. Supports collapsed (stacked ZStack) and
//  expanded (side-by-side HStack) modes
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - DropZoneView

/// A universal drag-and-drop widget that displays a batch of shelf items as visual cards.
///
/// ## Overview
///
/// `DropZoneView` is the primary widget rendered inside ``WidgetShelf``. Each instance
/// manages one ``BatchViewModel`` and transitions between two visual modes:
///
/// | Mode | Trigger | Layout |
/// |------|---------|--------|
/// | **Collapsed** | Default, or tap "minimize" | `ZStack` of ≤ 3 cards with random rotation/offset |
/// | **Expanded** | Tap the collapsed stack | Horizontal `ScrollView` with individually draggable cards |
///
/// ### Drop Acceptance
///
/// The entire view is wrapped in a ``WidgetTrayView`` that accepts `.fileURL`, `.url`,
/// `.utf8PlainText`, `.plainText`, and `.data` UTTypes. Dropped providers are forwarded
/// to ``BatchViewModel/handleDrop(providers:)`` for async extraction.
///
/// ### File Commands
///
/// When the batch contains files, a gear menu (⚙) appears in the controls row listing
/// ``FileCommand`` instances that match the current file extensions. Running a command:
/// 1. Extracts all file URLs from the batch.
/// 2. Calls ``FileCommand/processAll(fileURLs:)`` asynchronously.
/// 3. Creates a **new** "Output" batch (via ``NotchViewModel/addBatch()``) with the results.
///
/// ### Drag Out
///
/// - **Collapsed**: Dragging the stacked preview produces a ``FileURLTransferable`` containing
///   **all** item URLs, letting the user drag the entire batch into Finder or another app.
/// - **Expanded**: Each card is individually draggable. Text items are written to temporary
///   `.txt` files so they can be dragged as file URLs.
///
/// ### Matched Geometry
///
/// A `@Namespace` (`cardNamespace`) is shared between collapsed and expanded layouts.
/// Each ``ItemCard`` is tagged with `.matchedGeometryEffect(id: item.id, in: cardNamespace)`
/// so SwiftUI animates cards from their stacked position to side-by-side and back.
///
/// ## Topics
///
/// ### Visual Modes
/// - ``collapsedStack``
/// - ``expandedRow``
///
/// ### Commands
/// - ``availableCommands``
/// - ``runCommand(_:)``
///
/// ### Drag Support
/// - ``FileURLTransferable``
/// - ``ItemCard``
struct DropZoneView: View {

    /// The notch view model, used to create new output batches and remove this widget.
    @EnvironmentObject var vm: NotchViewModel

    /// The batch view model that owns the items displayed in this drop zone.
    @ObservedObject var batch: BatchViewModel

    /// Whether the cards are shown side-by-side (`true`) or stacked (`false`).
    @State private var isExpanded = false

    /// Guards the command menu while a ``FileCommand`` is executing.
    @State private var isRunningCommand = false

    /// Namespace for `matchedGeometryEffect` card transitions between collapsed and expanded layouts.
    @Namespace private var cardNamespace

    /// Creates a drop zone for the given batch.
    ///
    /// - Parameter batch: The ``BatchViewModel`` whose items this view will display.
    init(batch: BatchViewModel) {
        self.batch = batch
    }

    /// Returns the subset of ``FileCommand/allCommands`` that are applicable to the current batch.
    ///
    /// Applicability is determined by comparing each command's `acceptedExtensions` against the
    /// set of lowercased file extensions present in the batch. Commands with an empty
    /// `acceptedExtensions` set match any file.
    ///
    /// - Returns: An empty array if the batch contains no file items.
    private var availableCommands: [FileCommand] {
        let extensions = Set(batch.items.compactMap { $0.fileURL?.pathExtension.lowercased() })
        if extensions.isEmpty { return [] }
        // Return commands that match any of the file extensions present
        return FileCommand.allCommands.filter { cmd in
            cmd.acceptedExtensions.isEmpty || !cmd.acceptedExtensions.isDisjoint(with: extensions)
        }
    }

    var body: some View {
        WidgetTrayView(padding: 5, onDropHandler: { providers in
            batch.handleDrop(providers: providers)
            return true
        }) { isTargeted in
            VStack(spacing: 6) {
                // Controls row
                controls
                // Cards area — transitions between ZStack and HStack
                Group {
                    if isExpanded {
                        expandedRow
                    } else {
                        collapsedStack
                    }
                }
                .animation(.spring(response: NotchConfiguration.shared.widgetSpringResponse, dampingFraction: NotchConfiguration.shared.widgetSpringDamping), value: isExpanded)
            }
        }
    }



    // MARK: - Collapsed (ZStack — overlapping cards)

    /// A fan-style preview of up to three ``ItemCard`` instances stacked with slight rotation and offset.
    ///
    /// Tapping the stack sets `isExpanded = true`, transitioning to ``expandedRow`` via
    /// matched geometry. Dragging the stack produces a ``FileURLTransferable`` containing
    /// all batch item URLs.
    private var collapsedStack: some View {
        ZStack {
            ForEach(Array(batch.items.prefix(3).enumerated()), id: \.element.id) { index, item in
                ItemCard(item: item, compact: true)
                    .matchedGeometryEffect(id: item.id, in: cardNamespace)
                    .rotationEffect(.degrees(Double(index - 1) * 5))
                    .offset(x: CGFloat(index - 1) * 4, y: CGFloat(index - 1) * -2)
                    .zIndex(Double(index))
            }
        }
        .draggable(transferable(for: batch.items)) {
            dragPreview(for: batch.items)
        }
        .onTapGesture {
            withAnimation(.spring(response: NotchConfiguration.shared.widgetSpringResponse, dampingFraction: NotchConfiguration.shared.widgetSpringDamping)) {
                isExpanded = true
            }
        }
    }

    // MARK: - Expanded (HStack — side by side)

    /// A horizontal scroll of all batch items, each rendered as an individually draggable ``ItemCard``.
    ///
    /// Right-clicking a card reveals a context menu with "Remove Item" and "Minimize Batch".
    /// The scroll is capped at 200 pt width to keep the widget compact within the shelf.
    private var expandedRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(batch.items) { item in
                    ItemCard(item: item, compact: false)
                        .matchedGeometryEffect(id: item.id, in: cardNamespace)
                        .draggable(singleTransferable(for: item)) {
                            singleDragPreview(for: item)
                        }
                        .contextMenu {
                            Button("Remove Item") { batch.remove(item) }
                            Button("Minimize Batch") {
                                withAnimation(.spring(response: NotchConfiguration.shared.widgetSpringResponse, dampingFraction: NotchConfiguration.shared.widgetSpringDamping)) {
                                    isExpanded = false
                                }
                            }
                        }
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: 200)
    }

    // MARK: - Controls

    /// The toolbar row above the cards showing item count, command menu, expand/collapse toggle,
    /// and a clear button.
    ///
    /// - Output widgets (whose titles begin with "Output") display a prominent uppercase label.
    /// - The command menu only appears when ``availableCommands`` is non-empty.
    /// - The clear button removes all items and destroys the widget via ``NotchViewModel/removeBatch(_:)``.
    private var controls: some View {
        HStack(spacing: 8) {
            // Title — prominent for output widgets
            if batch.title.hasPrefix("Output") {
                Text(batch.title.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(0.5)
            }

            Text("\(batch.items.count)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))

//            Spacer()

            // Commands menu
            if !availableCommands.isEmpty {
                Menu {
                    ForEach(availableCommands) { cmd in
                        Button {
                            runCommand(cmd)
                        } label: {
                            Label(cmd.name, systemImage: cmd.icon)
                        }
                    }
                } label: {
                    if isRunningCommand {
                        ProgressView()
                            .controlSize(.mini)
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "gearshape")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .menuStyle(.borderlessButton)
                .frame(width: 16, height: 16)
                .disabled(isRunningCommand)
            }

            if (isExpanded == true){
                Button {
                    withAnimation(.spring(response: NotchConfiguration.shared.widgetSpringResponse, dampingFraction: NotchConfiguration.shared.widgetSpringDamping)) {
                        isExpanded = false
                    }
                } label: {
                    Image(systemName: "arrow.right.and.line.vertical.and.arrow.left")
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    withAnimation(.spring(response: NotchConfiguration.shared.widgetSpringResponse, dampingFraction: NotchConfiguration.shared.widgetSpringDamping)) {
                        isExpanded = true
                    }
                } label: {
                    Image(systemName: "arrow.left.and.line.vertical.and.arrow.right")
                }
                .buttonStyle(.plain)
            }

            Button {
                withAnimation(.spring(response: NotchConfiguration.shared.widgetSpringResponse, dampingFraction: NotchConfiguration.shared.widgetSpringDamping)) {
                    batch.clear()
                    vm.removeBatch(batch)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Run Command

    /// Executes a ``FileCommand`` against all file items in the batch.
    ///
    /// The method:
    /// 1. Extracts file URLs from the batch (skipping text/link items).
    /// 2. Sets ``isRunningCommand`` to show a progress spinner in the controls.
    /// 3. Calls ``FileCommand/processAll(fileURLs:)`` on a background task.
    /// 4. Collects successful output URLs and creates a new "Output" batch widget.
    ///
    /// - Parameter command: The ``FileCommand`` to run (e.g., PDF → PowerPoint).
    private func runCommand(_ command: FileCommand) {
        let fileURLs = batch.items.compactMap { $0.fileURL }
        guard !fileURLs.isEmpty else { return }

        isRunningCommand = true
        Task {
            let results = await command.processAll(fileURLs: fileURLs)
            await MainActor.run {
                isRunningCommand = false
                let outputItems = results.compactMap { (_, result) -> ShelfItem? in
                    if case .success(let url) = result {
                        return ShelfItem(kind: .link(url: url))
                    }
                    return nil
                }
                if !outputItems.isEmpty {
                    // Create a new "Output" widget for the results
                    let outputBatch = vm.addBatch()
                    outputBatch.batch.title = "Output: \(command.name)"
                    outputBatch.add(items: outputItems)
                }
            }
        }
    }

    // MARK: - Transferable Helpers

    /// Wraps all item URLs from the batch into a single ``FileURLTransferable``.
    ///
    /// Items without a URL (e.g., plain text) are skipped.
    private func transferable(for items: [ShelfItem]) -> FileURLTransferable {
        FileURLTransferable(urls: items.compactMap { $0.itemURL })
    }

    /// Wraps a single item's URL into a ``FileURLTransferable``.
    ///
    /// For text items, a temporary `.txt` file is written to `$TMPDIR` so they can
    /// participate in file-based drag-and-drop.
    ///
    /// - Parameter item: The ``ShelfItem`` to convert.
    /// - Returns: A transferable containing exactly one URL (or an empty array as fallback).
    private func singleTransferable(for item: ShelfItem) -> FileURLTransferable {
        if let url = item.itemURL {
            return FileURLTransferable(urls: [url])
        }
        if case .text(let str) = item.kind {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("thinger-text-\(item.id.uuidString.prefix(8)).txt")
            try? str.write(to: tempURL, atomically: true, encoding: .utf8)
            return FileURLTransferable(urls: [tempURL])
        }
        return FileURLTransferable(urls: [])
    }

    // MARK: - Drag Previews

    /// A composite drag preview showing up to three overlapping item previews.
    ///
    /// Used when dragging the entire collapsed batch out of the notch.
    private func dragPreview(for items: [ShelfItem]) -> some View {
        HStack(spacing: -10) {
            ForEach(items.prefix(3)) { item in
                singleDragPreview(for: item)
            }
        }
    }

    /// A drag preview for a single item — icon + filename on a blurred material card.
    private func singleDragPreview(for item: ShelfItem) -> some View {
        VStack(spacing: 2) {
            Image(nsImage: item.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
            Text(item.displayName)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 50)
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 8).fill(.ultraThinMaterial))
    }
}

// MARK: - FileURLTransferable

/// A `Transferable` wrapper that vends an array of file URLs for drag-and-drop operations.
///
/// ## Overview
///
/// `FileURLTransferable` bridges Thinger's internal ``ShelfItem`` URLs to SwiftUI's
/// `Transferable` protocol, enabling items to be dragged *out* of the notch into
/// Finder, Mail, or any other drop target that accepts file URLs.
///
/// The `ProxyRepresentation` exposes the **first** URL. While this means only one URL
/// is advertised to the system's drag pasteboard, it is sufficient for single-item drags.
/// For multi-item drags, the collapsed ``DropZoneView`` batches all URLs into one
/// transferable and relies on the proxy for the primary item.
///
/// - Note: If `urls` is empty, the representation falls back to the root filesystem URL
///   (`/`), which acts as a harmless no-op.
struct FileURLTransferable: Transferable {
    /// The file URLs to expose via drag-and-drop.
    let urls: [URL]

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation { $0.urls.first ?? URL(fileURLWithPath: "/") }
    }
}

// MARK: - ItemCard

/// A rounded card view that displays an item's system icon and filename.
///
/// ## Overview
///
/// `ItemCard` renders a single ``ShelfItem`` as a small tile suitable for both
/// the collapsed stack and the expanded scroll view inside ``DropZoneView``.
///
/// ### Compact vs Full Size
///
/// | Property | Compact (`true`) | Full (`false`) |
/// |----------|-----------------|----------------|
/// | Card width | 55 pt | 65 pt |
/// | Icon size | 32 pt | 40 pt |
/// | Corner radius | 8 pt | 10 pt |
/// | Name lines | 1 | 2 |
/// | Font size | 8 pt | 9 pt |
///
/// ### Visual Treatment
///
/// The icon sits inside a rounded rectangle with a subtle top-leading → bottom-trailing
/// `LinearGradient` (white at 12% → 6% opacity) and a thin white stroke (10% opacity).
/// A drop shadow adds depth against the dark notch background.
///
/// - Parameters:
///   - item: The ``ShelfItem`` to display.
///   - compact: `true` for the collapsed stack (smaller cards), `false` for the expanded row.
struct ItemCard: View {

    /// The shelf item to render.
    let item: ShelfItem

    /// Whether to use the smaller compact layout for the collapsed stack.
    let compact: Bool

    /// The overall card width — varies with ``compact``.
    private var cardWidth: CGFloat { compact ? 55 : 65 }

    /// The system icon size — varies with ``compact``.
    private var iconSize: CGFloat { compact ? 32 : 40 }

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                RoundedRectangle(cornerRadius: compact ? 8 : 10)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.12), Color.white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: compact ? 8 : 10)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )

                Image(nsImage: item.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)
            }
            .frame(width: cardWidth, height: cardWidth)
            .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)

            Text(item.displayName)
                .font(.system(size: compact ? 8 : 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(compact ? 1 : 2)
                .multilineTextAlignment(.center)
                .frame(width: cardWidth)
        }
    }
}

// MARK: - Preview
#Preview {
    DropZoneView(batch: BatchViewModel(batch: FileBatch(title: "Preview", items: [], isPersisted: false)))
        .padding()
        .background(Color.black)
        .environmentObject(NotchViewModel())
}
