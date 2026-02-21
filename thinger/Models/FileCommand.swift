//
//  FileCommand.swift
//  thinger
//
//  Simple command objects that run shell commands on dropped files.
//  Each command has a template string where {input} and {output} get replaced
//  with actual file paths, then executed via Process + zsh -c.
//

import Foundation

// MARK: - FileCommand

/// A shell command that operates on files.
/// `template` uses `{input}` for the source file path and `{output}` for the destination.
/// Output files are placed next to the input with a new extension.
struct FileCommand: Identifiable, Hashable {
    let id: String           // unique key
    let name: String         // display name (e.g. "PDF → PowerPoint")
    let icon: String         // SF Symbol
    let template: String     // shell command with {input} and {output} placeholders
    let outputExtension: String  // e.g. "pptx", "png"
    let acceptedExtensions: Set<String> // file extensions this command works on (empty = any)
}

// MARK: - Built-in Commands

extension FileCommand {
    static let allCommands: [FileCommand] = [
        .pdfToPowerpoint,
        .pdfToImages,
        .imageToJpeg,
        .imageToPng,
        .markdownToHtml,
        .compressZip,
    ]

    static let pdfToPowerpoint = FileCommand(
        id: "pdf-to-pptx",
        name: "PDF → PowerPoint",
        icon: "doc.richtext",
        template: "soffice --headless --convert-to pptx --outdir \"{outdir}\" \"{input}\"",
        outputExtension: "pptx",
        acceptedExtensions: ["pdf"]
    )

    static let pdfToImages = FileCommand(
        id: "pdf-to-png",
        name: "PDF → PNG Images",
        icon: "photo.on.rectangle",
        template: "sips -s format png \"{input}\" --out \"{output}\"",
        outputExtension: "png",
        acceptedExtensions: ["pdf"]
    )

    static let imageToJpeg = FileCommand(
        id: "img-to-jpeg",
        name: "Convert to JPEG",
        icon: "photo",
        template: "sips -s format jpeg \"{input}\" --out \"{output}\"",
        outputExtension: "jpg",
        acceptedExtensions: ["png", "tiff", "bmp", "gif", "heic", "webp"]
    )

    static let imageToPng = FileCommand(
        id: "img-to-png",
        name: "Convert to PNG",
        icon: "photo",
        template: "sips -s format png \"{input}\" --out \"{output}\"",
        outputExtension: "png",
        acceptedExtensions: ["jpg", "jpeg", "tiff", "bmp", "gif", "heic", "webp"]
    )

    static let markdownToHtml = FileCommand(
        id: "md-to-html",
        name: "Markdown → HTML",
        icon: "doc.text",
        template: """
        cat \"{input}\" | python3 -c "import sys,html; \
        lines=sys.stdin.read(); \
        print('<html><body>'+lines+'</body></html>')" > \"{output}\"
        """,
        outputExtension: "html",
        acceptedExtensions: ["md", "markdown"]
    )

    static let compressZip = FileCommand(
        id: "compress-zip",
        name: "Compress to ZIP",
        icon: "doc.zipper",
        template: "zip -j \"{output}\" \"{input}\"",
        outputExtension: "zip",
        acceptedExtensions: []  // any file
    )

    /// Returns commands that can operate on the given file extension.
    static func commands(for fileExtension: String) -> [FileCommand] {
        let ext = fileExtension.lowercased()
        return allCommands.filter { cmd in
            cmd.acceptedExtensions.isEmpty || cmd.acceptedExtensions.contains(ext)
        }
    }
}

// MARK: - Command Runner

extension FileCommand {

    /// Builds the final shell string by substituting placeholders.
    /// Output files go to a temp directory so the original location isn't polluted.
    func buildCommand(inputPath: String) -> (command: String, outputPath: String) {
        let inputURL = URL(fileURLWithPath: inputPath)
        let baseName = inputURL.deletingPathExtension().lastPathComponent

        // Create a dedicated temp directory for outputs
        let outDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("thinger-output", isDirectory: true)
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        let outputPath = outDir.appendingPathComponent("\(baseName).\(outputExtension)").path

        let cmd = template
            .replacingOccurrences(of: "{input}", with: inputPath)
            .replacingOccurrences(of: "{output}", with: outputPath)
            .replacingOccurrences(of: "{outdir}", with: outDir.path)

        return (cmd, outputPath)
    }

    /// Runs the command on a single file URL. Returns the output file URL on success.
    @discardableResult
    func process(fileURL: URL) async throws -> URL {
        let inputPath = fileURL.path
        let (command, outputPath) = buildCommand(inputPath: inputPath)

        print("FileCommand: running [\(name)] → \(command)")

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-c", command]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""

                    if process.terminationStatus == 0 {
                        print("FileCommand: ✅ done → \(outputPath)")
                        continuation.resume(returning: URL(fileURLWithPath: outputPath))
                    } else {
                        print("FileCommand: ❌ exit \(process.terminationStatus) → \(output)")
                        continuation.resume(throwing: CommandError.failed(
                            command: name,
                            exitCode: process.terminationStatus,
                            output: output
                        ))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Runs the command on multiple file URLs. Returns results for each.
    func processAll(fileURLs: [URL]) async -> [(url: URL, result: Result<URL, Error>)] {
        var results: [(url: URL, result: Result<URL, Error>)] = []
        for url in fileURLs {
            do {
                let output = try await process(fileURL: url)
                results.append((url, .success(output)))
            } catch {
                results.append((url, .failure(error)))
            }
        }
        return results
    }
}

// MARK: - Error

enum CommandError: LocalizedError {
    case failed(command: String, exitCode: Int32, output: String)

    var errorDescription: String? {
        switch self {
        case .failed(let cmd, let code, let output):
            return "\(cmd) failed (exit \(code)): \(output)"
        }
    }
}
