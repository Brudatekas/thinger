//
//  TeleprompterView.swift
//  thinger
//
//  The teleprompter display shown inside the expanded notch when the
//  Teleprompter tab is active. Shows scrolling text with gradient masks,
//  playback controls, and an empty-state prompt.
//

import SwiftUI

// MARK: - TeleprompterView

/// A scrolling teleprompter display for the notch's expanded content area.
///
/// ## Overview
///
/// `TeleprompterView` renders the script text in a large, readable font and
/// scrolls it vertically using an animated offset. The view has three layers:
///
/// 1. **Text content** — positioned using `.offset(y:)` driven by
///    ``TeleprompterViewModel/scrollOffset``.
/// 2. **Gradient masks** — top and bottom edges fade to black for readability.
/// 3. **Bottom toolbar** — play/pause, speed indicator, and reset button.
///
/// When no script is loaded, an empty state with "Paste" and "Load File"
/// buttons is shown instead.
///
/// ## Topics
///
/// ### Related Types
/// - ``TeleprompterViewModel``
struct TeleprompterView: View {

    @EnvironmentObject var vm: NotchViewModel
    @ObservedObject private var config = NotchConfiguration.shared

    @EnvironmentObject var tvm: TeleprompterViewModel

    var body: some View {
        ZStack {
            if tvm.isEmpty {
                emptyState
            } else {
                teleprompterContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.justify.leading")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.white.opacity(0.4))

            Text("No Script Loaded")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))

            HStack(spacing: 10) {
                Button {
                    tvm.loadFromClipboard()
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .tint(.white.opacity(0.6))

                Button {
                    tvm.loadFromFile()
                } label: {
                    Label("Load File", systemImage: "folder")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .tint(.white.opacity(0.6))
            }
        }
    }

    // MARK: - Teleprompter Content

    private var teleprompterContent: some View {
        VStack(spacing: 0) {
            // Scrolling text area
            GeometryReader { geo in
                let viewHeight = geo.size.height

                ZStack(alignment: .top) {
                    Text(tvm.scriptText)
                        .font(.system(size: CGFloat(config.teleprompterFontSize), weight: .medium))
                        .foregroundStyle(.white)
                        .lineSpacing(CGFloat(config.teleprompterFontSize) * 0.4)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 8)
                        .padding(.top, viewHeight * 0.4) // Start text below center
                        .fixedSize(horizontal: false, vertical: true)
                        .background(
                            GeometryReader { textGeo in
                                Color.clear.preference(
                                    key: ContentHeightKey.self,
                                    value: textGeo.size.height
                                )
                            }
                        )
                        .offset(y: -tvm.scrollOffset)
                        .scaleEffect(x: config.teleprompterMirror ? -1 : 1, y: 1)
                }
                .frame(width: geo.size.width, height: viewHeight, alignment: .top)
                .clipped()
                .mask(
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [.clear, .white],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 20)

                        Color.white

                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 20)
                    }
                )
                .onAppear {
                    tvm.viewportHeight = viewHeight
                }
                .onChange(of: geo.size.height) { _, newHeight in
                    tvm.viewportHeight = newHeight
                }
                .onPreferenceChange(ContentHeightKey.self) { height in
                    tvm.contentHeight = height
                }
            }

            // Bottom toolbar
            bottomToolbar
        }
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 12) {
            // Play/Pause
            Button {
                tvm.togglePlayback()
            } label: {
                Image(systemName: tvm.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .buttonStyle(.plain)

            // Rewind
            Button {
                tvm.rewind()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)

            // Skip
            Button {
                tvm.skipForward()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)

            Spacer()

            // Speed indicator
            Text("\(Int(config.teleprompterSpeed)) px/s")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))

            // Progress
            Text("\(Int(tvm.progress * 100))%")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))

            Spacer()

            // Reset
            Button {
                tvm.reset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)

            // Clear script
            Button {
                tvm.clearScript()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

// MARK: - Content Height Preference Key

/// Preference key for measuring the rendered text content height.
private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
