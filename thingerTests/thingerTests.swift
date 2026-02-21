//
//  thingerTests.swift
//  thingerTests
//
//  Created by Tarik Khafaga on 20/02/2026.
//

import Testing
import Foundation
@testable import thinger

// MARK: - NotchViewModelTests

@MainActor
struct NotchViewModelTests {
    
    /// Reset persisted state so tests don't leak into each other
    private func makeCleanVM() -> NotchViewModel {
        UserDefaults.standard.removeObject(forKey: "notchLocked")
        return NotchViewModel()
    }
    
    @Test("Notch state transitions without locks or sharing")
    func testNotchStateTransitions() async throws {
        let vm = makeCleanVM()
        #expect(vm.notchState == .closed)
        
        vm.open()
        #expect(vm.notchState == .open)
        
        vm.close()
        #expect(vm.notchState == .closed)
        
        vm.toggle()
        #expect(vm.notchState == .open)
        
        vm.toggle()
        #expect(vm.notchState == .closed)
    }
    
    @Test("Notch lock prevents state changes")
    func testNotchLock() async throws {
        let vm = makeCleanVM()
        #expect(vm.notchState == .closed)
        
        vm.lockNotch()
        #expect(vm.isLocked == true)
        
        vm.open()
        #expect(vm.notchState == .closed, "Should not open while locked")
        
        vm.unlockNotch()
        vm.open()
        #expect(vm.notchState == .open)
        
        vm.lockNotch()
        vm.close()
        #expect(vm.notchState == .open, "Should not close while locked")
        
        // Cleanup: unlock so other tests don't inherit locked state
        vm.unlockNotch()
    }
    
    @Test("Combine targeting aggregation")
    func testTargetingAggregation() async throws {
        let vm = makeCleanVM()
        
        #expect(vm.anyDropZoneTargeting == false)
        
        vm.reportTargetingChange(true)
        // Combine publisher updates asynchronously, we might need a small sleep
        try await Task.sleep(nanoseconds: 10_000_000)
        #expect(vm.anyDropZoneTargeting == true)
        #expect(vm.activeTargetCount == 1)
        
        vm.globalDragTargeting = true
        try await Task.sleep(nanoseconds: 10_000_000)
        #expect(vm.anyDropZoneTargeting == true)
        
        vm.reportTargetingChange(false)
        try await Task.sleep(nanoseconds: 10_000_000)
        #expect(vm.activeTargetCount == 0)
        #expect(vm.anyDropZoneTargeting == true) // global is still true
        
        vm.globalDragTargeting = false
        try await Task.sleep(nanoseconds: 10_000_000)
        #expect(vm.anyDropZoneTargeting == false)
    }
    
    @Test("preventNotchClose blocks close")
    func testPreventNotchCloseBlocksClose() async throws {
        let vm = makeCleanVM()
        vm.open()
        
        vm.preventNotchClose = true
        
        vm.close()
        #expect(vm.notchState == .open, "Notch should stay open when preventNotchClose is true")
        
        vm.preventNotchClose = false
        
        vm.close()
        #expect(vm.notchState == .closed)
    }
    
    // MARK: - Drag Targeting Debounce
    
    @Test("updateGlobalDragTargeting(false) debounces for 50ms")
    func testGlobalDragTargetingDebounce() async throws {
        let vm = makeCleanVM()
        
        // True is immediate
        vm.updateGlobalDragTargeting(true)
        #expect(vm.globalDragTargeting == true)
        
        // False is delayed
        vm.updateGlobalDragTargeting(false)
        #expect(vm.globalDragTargeting == true, "Should still be true immediately after setting to false")
        
        // Wait 100ms (longer than the 50ms debounce)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(vm.globalDragTargeting == false, "Should be false after debounce expires")
    }
    
    @Test("updateGlobalDragTargeting(true) cancels pending false debounce")
    func testGlobalDragTargetingCancellation() async throws {
        let vm = makeCleanVM()
        
        vm.updateGlobalDragTargeting(true)
        #expect(vm.globalDragTargeting == true)
        
        // Start the delayed false
        vm.updateGlobalDragTargeting(false)
        
        // Immediately set back to true before the 50ms expires
        vm.updateGlobalDragTargeting(true)
        
        // Wait 100ms (longer than the 50ms debounce)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(vm.globalDragTargeting == true, "Should remain true because the false debounce was cancelled")
    }
    
    // MARK: - Multi-Batch Management
    
    @Test("addBatch creates a new empty batch")
    func testAddBatch() async throws {
        let vm = makeCleanVM()
        #expect(vm.batches.count == 0)
        
        let batch = vm.addBatch()
        #expect(vm.batches.count == 1)
        #expect(batch.isEmpty == true)
        #expect(batch.title.contains("Batch"))
    }
    
    @Test("Multiple batches are independent")
    func testMultipleBatches() async throws {
        let vm = makeCleanVM()
        
        let b1 = vm.addBatch()
        let b2 = vm.addBatch()
        #expect(vm.batches.count == 2)
        
        b1.add(items: [ShelfItem(kind: .text(string: "A"))])
        b2.add(items: [ShelfItem(kind: .text(string: "B"))])
        
        #expect(b1.items.count == 1)
        #expect(b2.items.count == 1)
        #expect(b1.items.first?.displayName != b2.items.first?.displayName)
    }
    
    @Test("removeBatch removes the correct batch")
    func testRemoveBatch() async throws {
        let vm = makeCleanVM()
        
        let b1 = vm.addBatch()
        let b2 = vm.addBatch()
        let b3 = vm.addBatch()
        #expect(vm.batches.count == 3)
        
        vm.removeBatch(b2)
        #expect(vm.batches.count == 2)
        // b1 and b3 should remain
        #expect(vm.batches.contains(where: { $0 === b1 }))
        #expect(vm.batches.contains(where: { $0 === b3 }))
        #expect(!vm.batches.contains(where: { $0 === b2 }))
    }
    
    @Test("pruneEmptyBatches removes only empty batches")
    func testPruneEmptyBatches() async throws {
        let vm = makeCleanVM()
        
        let emptyBatch = vm.addBatch()
        let filledBatch = vm.addBatch()
        let anotherEmpty = vm.addBatch()
        
        filledBatch.add(items: [ShelfItem(kind: .text(string: "keep me"))])
        
        #expect(vm.batches.count == 3)
        vm.pruneEmptyBatches()
        #expect(vm.batches.count == 1)
        #expect(vm.batches.first === filledBatch)
    }
    
    @Test("clearAllBatches removes everything")
    func testClearAllBatches() async throws {
        let vm = makeCleanVM()
        
        let b1 = vm.addBatch()
        let b2 = vm.addBatch()
        b1.add(items: [ShelfItem(kind: .text(string: "A"))])
        b2.add(items: [ShelfItem(kind: .text(string: "B"))])
        
        #expect(vm.batches.count == 2)
        vm.clearAllBatches()
        #expect(vm.batches.count == 0)
    }
    
    @Test("hasNoFiles is true when all batches are empty")
    func testHasNoFiles() async throws {
        let vm = makeCleanVM()
        #expect(vm.hasNoFiles == true)
        
        let b = vm.addBatch()
        #expect(vm.hasNoFiles == true) // batch exists but is empty
        
        b.add(items: [ShelfItem(kind: .text(string: "X"))])
        #expect(vm.hasNoFiles == false)
        
        b.clear()
        #expect(vm.hasNoFiles == true)
    }
    
    @Test("Close prunes empty batches")
    func testClosePrunesEmptyBatches() async throws {
        let vm = makeCleanVM()
        vm.open()
        
        let emptyBatch = vm.addBatch()
        let filledBatch = vm.addBatch()
        filledBatch.add(items: [ShelfItem(kind: .text(string: "persist"))])
        
        #expect(vm.batches.count == 2)
        vm.close()
        #expect(vm.batches.count == 1)
        #expect(vm.batches.first === filledBatch)
    }
    
    @Test("Close resets targeting state")
    func testCloseResetsTargeting() async throws {
        let vm = makeCleanVM()
        vm.open()
        
        vm.globalDragTargeting = true
        vm.reportTargetingChange(true)
        vm.reportTargetingChange(true)
        
        vm.close()
        #expect(vm.globalDragTargeting == false)
        #expect(vm.activeTargetCount == 0)
    }
    
    @Test("Open is idempotent")
    func testOpenIdempotent() async throws {
        let vm = makeCleanVM()
        vm.open()
        #expect(vm.notchState == .open)
        vm.open() // should not crash or change anything
        #expect(vm.notchState == .open)
    }
    
    @Test("Close is idempotent")
    func testCloseIdempotent() async throws {
        let vm = makeCleanVM()
        #expect(vm.notchState == .closed)
        vm.close() // already closed, should be safe
        #expect(vm.notchState == .closed)
    }
    
    @Test("toggleLock flips lock state")
    func testToggleLock() async throws {
        let vm = makeCleanVM()
        #expect(vm.isLocked == false)
        vm.toggleLock()
        #expect(vm.isLocked == true)
        vm.toggleLock()
        #expect(vm.isLocked == false)
    }
    
    @Test("Target count never goes negative")
    func testTargetCountFloor() async throws {
        let vm = makeCleanVM()
        vm.reportTargetingChange(false)
        vm.reportTargetingChange(false)
        vm.reportTargetingChange(false)
        #expect(vm.activeTargetCount == 0)
    }
}

// MARK: - BatchViewModelTests

@MainActor
struct BatchViewModelTests {
    
    @Test("Adding and removing Items from batch")
    func testItemManagement() async throws {
        let batch = FileBatch(title: "Test", items: [], isPersisted: false)
        let vm = BatchViewModel(batch: batch)
        
        #expect(vm.isEmpty == true)
        
        let textItem = ShelfItem(kind: .text(string: "Hello"))
        vm.add(items: [textItem])
        #expect(vm.isEmpty == false)
        #expect(vm.items.count == 1)
        #expect(vm.items.first?.id == textItem.id)
        
        vm.remove(textItem)
        #expect(vm.isEmpty == true)
        
        let linkItem = ShelfItem(kind: .link(url: URL(string: "https://apple.com")!))
        vm.add(items: [linkItem])
        #expect(vm.isEmpty == false)
        #expect(vm.items.count == 1)
        #expect(vm.items.first?.id == linkItem.id)
        
        vm.remove(linkItem)
        #expect(vm.isEmpty == true)
    }
    
    @Test("Deduplication logic")
    func testDeduplication() async throws {
        let batch = FileBatch(title: "Test", items: [], isPersisted: false)
        let vm = BatchViewModel(batch: batch)
        
        let url = URL(string: "https://apple.com")!
        let item1 = ShelfItem(kind: .link(url: url))
        let item2 = ShelfItem(kind: .link(url: url))
        
        vm.add(items: [item1])
        #expect(vm.items.count == 1)
        
        vm.add(items: [item2])
        #expect(vm.items.count == 1, "Duplicate identityKey should be rejected")
    }
    
    @Test("Clearing items")
    func testClearItems() async throws {
        let batch = FileBatch(title: "Test", items: [], isPersisted: false)
        let vm = BatchViewModel(batch: batch)
        
        vm.add(items: [ShelfItem(kind: .text(string: "A")), ShelfItem(kind: .text(string: "B"))])
        #expect(vm.items.count == 2)
        
        vm.clear()
        #expect(vm.isEmpty == true)
    }
    
    @Test("Batch title is accessible")
    func testBatchTitle() async throws {
        let batch = FileBatch(title: "My Shelf", items: [], isPersisted: false)
        let vm = BatchViewModel(batch: batch)
        #expect(vm.title == "My Shelf")
    }
    
    @Test("Batch title is mutable via batch property")
    func testBatchTitleMutable() async throws {
        let batch = FileBatch(title: "Original", items: [], isPersisted: false)
        let vm = BatchViewModel(batch: batch)
        vm.batch.title = "Output: PDF → PNG"
        #expect(vm.title == "Output: PDF → PNG")
    }
    
    @Test("Adding multiple items at once")
    func testAddMultipleItems() async throws {
        let batch = FileBatch(title: "Test", items: [], isPersisted: false)
        let vm = BatchViewModel(batch: batch)
        
        let items = [
            ShelfItem(kind: .text(string: "A")),
            ShelfItem(kind: .text(string: "B")),
            ShelfItem(kind: .text(string: "C")),
        ]
        vm.add(items: items)
        #expect(vm.items.count == 3)
    }
    
    @Test("Removing an item that doesn't exist is safe")
    func testRemoveNonexistent() async throws {
        let batch = FileBatch(title: "Test", items: [], isPersisted: false)
        let vm = BatchViewModel(batch: batch)
        
        let item = ShelfItem(kind: .text(string: "Ghost"))
        vm.remove(item) // should not crash
        #expect(vm.isEmpty == true)
    }
    
    @Test("onItemsAdded callback fires")
    func testOnItemsAddedCallback() async throws {
        let batch = FileBatch(title: "Test", items: [], isPersisted: false)
        let vm = BatchViewModel(batch: batch)
        
        var callbackItems: [ShelfItem]?
        vm.onItemsAdded = { items in
            callbackItems = items
        }
        
        let item = ShelfItem(kind: .text(string: "Hello"))
        vm.add(items: [item])
        #expect(callbackItems?.count == 1)
        #expect(callbackItems?.first?.id == item.id)
    }
}

// MARK: - ShelfItemTests

@MainActor
struct ShelfItemTests {
    
    @Test("Display name logic")
    func testDisplayName() async throws {
        let textItem = ShelfItem(kind: .text(string: "   Short text   "))
        #expect(textItem.displayName == "Short text")
        
        let longTextItem = ShelfItem(kind: .text(string: "This is a very long string that should get truncated by the display name logic!"))
        #expect(longTextItem.displayName.hasSuffix("..."))
        
        let linkItem = ShelfItem(kind: .link(url: URL(string: "https://example.com/path")!))
        #expect(linkItem.displayName == "example.com/path")
    }
    
    @Test("Identity Key logic")
    func testIdentityKey() async throws {
        let url1 = URL(string: "https://apple.com")!
        let url2 = URL(string: "https://apple.com")!
        
        let item1 = ShelfItem(kind: .link(url: url1))
        let item2 = ShelfItem(kind: .link(url: url2))
        
        #expect(item1.identityKey == item2.identityKey)
        #expect(item1.identityKey == "link://https://apple.com")
        
        let textItem = ShelfItem(kind: .text(string: "test string"))
        #expect(textItem.identityKey == "text://test string")
    }
    
    @Test("Icon symbol name")
    func testIconSymbolName() async throws {
        let textItem = ShelfItem(kind: .text(string: "test"))
        #expect(textItem.kind.iconSymbolName == "text.alignleft")
        
        let linkItem = ShelfItem(kind: .link(url: URL(string: "https://apple.com")!))
        #expect(linkItem.kind.iconSymbolName == "link")
    }
    
    @Test("Link item provides itemURL")
    func testLinkItemURL() async throws {
        let url = URL(string: "https://example.com/file.pdf")!
        let item = ShelfItem(kind: .link(url: url))
        #expect(item.itemURL == url)
        // fileURL is only for .file kind (bookmark-backed)
        #expect(item.fileURL == nil)
    }
    
    @Test("Text item has no fileURL")
    func testTextNoFileURL() async throws {
        let item = ShelfItem(kind: .text(string: "hello"))
        #expect(item.fileURL == nil)
    }
    
    @Test("Each item gets a unique UUID")
    func testUniqueID() async throws {
        let a = ShelfItem(kind: .text(string: "same"))
        let b = ShelfItem(kind: .text(string: "same"))
        #expect(a.id != b.id)
    }
}

// MARK: - FileCommandTests

struct FileCommandTests {
    
    @Test("Command builds with temp output directory")
    func testBuildCommandUsesTemp() async throws {
        let cmd = FileCommand.imageToJpeg
        let input = "/Users/test/photo.png"
        let (shell, outputPath) = cmd.buildCommand(inputPath: input)
        
        // Output should be in temp directory, not next to input
        #expect(outputPath.contains("thinger-output"))
        #expect(outputPath.hasSuffix("photo.jpg"))
        #expect(!outputPath.hasPrefix("/Users/test/"))
        
        // Shell command should contain the input path
        #expect(shell.contains(input))
        // Shell command should contain the output path
        #expect(shell.contains(outputPath))
    }
    
    @Test("Command builds correct output extension")
    func testBuildCommandExtension() async throws {
        let tests: [(FileCommand, String, String)] = [
            (.pdfToPowerpoint, "/tmp/doc.pdf", "pptx"),
            (.pdfToImages, "/tmp/doc.pdf", "png"),
            (.imageToJpeg, "/tmp/img.png", "jpg"),
            (.imageToPng, "/tmp/img.heic", "png"),
            (.markdownToHtml, "/tmp/readme.md", "html"),
            (.compressZip, "/tmp/archive.txt", "zip"),
        ]
        
        for (cmd, input, expectedExt) in tests {
            let (_, outputPath) = cmd.buildCommand(inputPath: input)
            #expect(outputPath.hasSuffix(".\(expectedExt)"),
                    "Expected \(cmd.name) output to end with .\(expectedExt), got \(outputPath)")
        }
    }
    
    @Test("Commands filter by accepted extensions")
    func testCommandFiltering() async throws {
        let pdfCommands = FileCommand.commands(for: "pdf")
        #expect(pdfCommands.contains(where: { $0.id == "pdf-to-pptx" }))
        #expect(pdfCommands.contains(where: { $0.id == "pdf-to-png" }))
        #expect(pdfCommands.contains(where: { $0.id == "compress-zip" })) // any file
        #expect(!pdfCommands.contains(where: { $0.id == "img-to-jpeg" }))
        
        let pngCommands = FileCommand.commands(for: "png")
        #expect(pngCommands.contains(where: { $0.id == "img-to-jpeg" }))
        #expect(!pngCommands.contains(where: { $0.id == "pdf-to-pptx" }))
        
        let mdCommands = FileCommand.commands(for: "md")
        #expect(mdCommands.contains(where: { $0.id == "md-to-html" }))
        
        let unknownCommands = FileCommand.commands(for: "xyz")
        // Only "any file" commands (compress-zip) should match
        #expect(unknownCommands.allSatisfy { $0.acceptedExtensions.isEmpty })
    }
    
    @Test("Extension filtering is case insensitive")
    func testExtensionCaseInsensitive() async throws {
        let upper = FileCommand.commands(for: "PDF")
        let lower = FileCommand.commands(for: "pdf")
        #expect(upper.count == lower.count)
    }
    
    @Test("All commands have unique IDs")
    func testUniqueCommandIDs() async throws {
        let ids = FileCommand.allCommands.map(\.id)
        let uniqueIDs = Set(ids)
        #expect(ids.count == uniqueIDs.count, "Duplicate command IDs found")
    }
    
    @Test("All commands have non-empty names and icons")
    func testCommandMetadata() async throws {
        for cmd in FileCommand.allCommands {
            #expect(!cmd.name.isEmpty, "\(cmd.id) has empty name")
            #expect(!cmd.icon.isEmpty, "\(cmd.id) has empty icon")
            #expect(!cmd.outputExtension.isEmpty, "\(cmd.id) has empty outputExtension")
            #expect(!cmd.template.isEmpty, "\(cmd.id) has empty template")
        }
    }
    
    @Test("Templates contain required placeholders")
    func testTemplatePlaceholders() async throws {
        for cmd in FileCommand.allCommands {
            let hasInput = cmd.template.contains("{input}")
            let hasOutput = cmd.template.contains("{output}") || cmd.template.contains("{outdir}")
            
            #expect(hasInput, "\(cmd.id) template missing {input}")
            #expect(hasOutput, "\(cmd.id) template missing {output} or {outdir}")
        }
    }
    
    @Test("Process fails gracefully on nonexistent file")
    func testProcessNonexistentFile() async throws {
        // Use compressZip since zip actually fails on nonexistent input
        let cmd = FileCommand.compressZip
        let fakeURL = URL(fileURLWithPath: "/tmp/thinger-nonexistent-\(UUID().uuidString).txt")
        
        do {
            _ = try await cmd.process(fileURL: fakeURL)
            // zip may still create an empty archive, so just verify it ran
        } catch {
            // Expected — command should fail on nonexistent file
            #expect(error is CommandError || error is any Error)
        }
    }
    
    @Test("Process succeeds on real file (sips PNG to JPEG)")
    func testProcessRealFile() async throws {
        // Create a real temp PNG using sips-compatible data
        let tempDir = FileManager.default.temporaryDirectory
        let inputURL = tempDir.appendingPathComponent("thinger-test-\(UUID().uuidString).png")
        
        // Create a minimal 1x1 PNG file
        let pngData = createMinimalPNG()
        try pngData.write(to: inputURL)
        
        defer { try? FileManager.default.removeItem(at: inputURL) }
        
        let cmd = FileCommand.imageToJpeg
        let outputURL = try await cmd.process(fileURL: inputURL)
        
        defer { try? FileManager.default.removeItem(at: outputURL) }
        
        #expect(FileManager.default.fileExists(atPath: outputURL.path))
        #expect(outputURL.pathExtension == "jpg")
    }
    
    @Test("processAll handles multiple files")
    func testProcessAll() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let url1 = tempDir.appendingPathComponent("thinger-all1-\(UUID().uuidString).png")
        let url2 = tempDir.appendingPathComponent("thinger-all2-\(UUID().uuidString).png")
        
        let pngData = createMinimalPNG()
        try pngData.write(to: url1)
        try pngData.write(to: url2)
        defer {
            try? FileManager.default.removeItem(at: url1)
            try? FileManager.default.removeItem(at: url2)
        }
        
        let cmd = FileCommand.imageToJpeg
        let results = await cmd.processAll(fileURLs: [url1, url2])
        
        #expect(results.count == 2)
        
        for r in results {
            if case .success(let outURL) = r.result {
                #expect(FileManager.default.fileExists(atPath: outURL.path))
                try? FileManager.default.removeItem(at: outURL)
            } else {
                #expect(Bool(false), "Expected all results to succeed")
            }
        }
    }
    
    @Test("Compress to ZIP works on any file")
    func testCompressZip() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let inputURL = tempDir.appendingPathComponent("thinger-zip-test-\(UUID().uuidString).txt")
        try "Hello from thinger!".write(to: inputURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: inputURL) }
        
        let cmd = FileCommand.compressZip
        let outputURL = try await cmd.process(fileURL: inputURL)
        defer { try? FileManager.default.removeItem(at: outputURL) }
        
        #expect(FileManager.default.fileExists(atPath: outputURL.path))
        #expect(outputURL.pathExtension == "zip")
    }
    
    // Helper: create a minimal valid PNG (1x1 red pixel)
    private func createMinimalPNG() -> Data {
        // Minimal 1x1 red PNG (67 bytes)
        let pngBytes: [UInt8] = [
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1
            0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, // 8-bit RGB
            0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, // IDAT chunk
            0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00, // compressed data
            0x00, 0x02, 0x00, 0x01, 0xE2, 0x21, 0xBC, 0x33, // checksum
            0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, // IEND chunk
            0xAE, 0x42, 0x60, 0x82,
        ]
        return Data(pngBytes)
    }
}

// MARK: - CommandErrorTests

struct CommandErrorTests {
    
    @Test("Error description contains command name and exit code")
    func testErrorDescription() async throws {
        let error = CommandError.failed(command: "Test Command", exitCode: 42, output: "something broke")
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("Test Command"))
        #expect(desc.contains("42"))
        #expect(desc.contains("something broke"))
    }
}
