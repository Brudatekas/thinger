//
//  DropZoneView.swift
//  thinger
//
//  A single universal drop zone that accepts any file type, URL, or text.
//  Shows items as thumbnail cards. Supports collapsed (stacked ZStack) and
//  expanded (side-by-side HStack) modes with matchedGeometryEffect transitions.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - DropZoneView

struct DropZoneView: View {
    @EnvironmentObject var vm: NotchViewModel
    @ObservedObject var batch: BatchViewModel
    @State private var isExpanded = false
    @State private var isRunningCommand = false
    @Namespace private var cardNamespace

    init(batch: BatchViewModel) {
        self.batch = batch
    }

    /// Commands available for the current set of files
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
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
            }
        }
    }



    // MARK: - Collapsed (ZStack — overlapping cards)

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
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isExpanded = true
            }
        }
    }

    // MARK: - Expanded (HStack — side by side)

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
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
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
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isExpanded = false
                    }
                } label: {
                    Image(systemName: "arrow.right.and.line.vertical.and.arrow.left")
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isExpanded = true
                    }
                } label: {
                    Image(systemName: "arrow.left.and.line.vertical.and.arrow.right")
                }
                .buttonStyle(.plain)
            }

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
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

    private func transferable(for items: [ShelfItem]) -> FileURLTransferable {
        FileURLTransferable(urls: items.compactMap { $0.itemURL })
    }

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

    private func dragPreview(for items: [ShelfItem]) -> some View {
        HStack(spacing: -10) {
            ForEach(items.prefix(3)) { item in
                singleDragPreview(for: item)
            }
        }
    }

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

struct FileURLTransferable: Transferable {
    let urls: [URL]
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation { $0.urls.first ?? URL(fileURLWithPath: "/") }
    }
}

// MARK: - ItemCard

struct ItemCard: View {
    let item: ShelfItem
    let compact: Bool

    private var cardWidth: CGFloat { compact ? 55 : 65 }
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
