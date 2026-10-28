import AVFoundation
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

enum SharedFileKind { case picture, audio }

enum SkipReason: CaseIterable { case unsupported, tooBig, unreadable, overLimit }

struct SharedFile: Identifiable, Equatable {
    let id: String
    let kind: SharedFileKind
    var name: String
    /// The file's name in the staging folder, once copied.
    var file: String?
    var mime = ""
    var duration: TimeInterval?

    var isReady: Bool { file != nil }
}

/// Same rules as ShareIntake.kt on Android.
@MainActor
final class SharedIntake: ObservableObject {
    let id = UUID().uuidString.lowercased()
    let staging: URL?
    @Published private(set) var title = ""
    @Published private(set) var text = ""
    /// Set when what was shared is a single address.
    @Published private(set) var link: String?
    @Published private(set) var files: [SharedFile] = []
    @Published private(set) var skipped: [SkipReason: Int] = [:]
    @Published private(set) var isReading = true

    var isCopying: Bool { files.contains { !$0.isReady } }

    init() {
        staging = ShareFolder.newStaging(id: id)
    }

    func read(_ items: [NSExtensionItem]) async {
        var texts: [String] = []
        var urls: [String] = []
        var subject = ""
        var copies: [(SharedFile, NSItemProvider)] = []
        for item in items {
            if subject.isEmpty {
                subject = item.attributedTitle?.string ?? item.attributedContentText?.string ?? ""
            }
            for provider in item.attachments ?? [] {
                if let kind = kindOf(provider) {
                    guard copies.count < maxSharedFiles else {
                        skip(.overLimit)
                        continue
                    }
                    let file = SharedFile(id: "\(copies.count)", kind: kind, name: provider.suggestedName ?? "")
                    copies.append((file, provider))
                } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                          let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL,
                          !url.isFileURL {
                    urls.append(url.absoluteString)
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                          let string = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
                    texts.append(string)
                } else {
                    skip(.unsupported)
                }
            }
        }
        var body = texts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        for url in urls where !body.contains(url) {
            body = body.isEmpty ? url : "\(body)\n\(url)"
        }
        if isSingleAddress(body) {
            link = body
            body = ""
        }
        text = body
        let cleanSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        title = cleanSubject == link || cleanSubject == text ? "" : cleanSubject
        files = copies.map(\.0)
        isReading = false
        for (file, provider) in copies {
            Task { await copy(file, from: provider) }
        }
    }

    func discard() {
        if let staging { try? FileManager.default.removeItem(at: staging) }
    }

    private func skip(_ reason: SkipReason) {
        skipped[reason, default: 0] += 1
    }

    private func kindOf(_ provider: NSItemProvider) -> SharedFileKind? {
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) { return .picture }
        if provider.hasItemConformingToTypeIdentifier(UTType.audio.identifier) { return .audio }
        return nil
    }

    private func isSingleAddress(_ text: String) -> Bool {
        guard !text.isEmpty, text.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              let url = URL(string: text), let scheme = url.scheme?.lowercased()
        else { return false }
        return ["http", "https"].contains(scheme) && url.host != nil
    }

    private func copy(_ file: SharedFile, from provider: NSItemProvider) async {
        guard let staging else { return finish(file, skipping: .unreadable) }
        let type = file.kind == .picture ? UTType.image : UTType.audio
        do {
            let copied = try await copyRepresentation(of: provider, type: type, into: staging, id: file.id)
            let ready = try await Task.detached(priority: .userInitiated) {
                file.kind == .picture
                    ? try preparePicture(copied, id: file.id, name: file.name, in: staging)
                    : try prepareAudio(copied, id: file.id, name: file.name, in: staging)
            }.value
            finish(ready, skipping: nil)
        } catch CopyError.tooBig {
            finish(file, skipping: .tooBig)
        } catch CopyError.unsupported {
            finish(file, skipping: .unsupported)
        } catch {
            finish(file, skipping: .unreadable)
        }
    }

    private func finish(_ file: SharedFile, skipping reason: SkipReason?) {
        if let reason {
            files.removeAll { $0.id == file.id }
            skip(reason)
        } else if let index = files.firstIndex(where: { $0.id == file.id }) {
            files[index] = file
        }
    }
}

private let maxSharedFiles = 20

/// Must match the server's limit.
private let maxFileBytes = 50 * 1024 * 1024

private enum CopyError: Error { case tooBig, unsupported, unreadable }

/// The provider's URL only lasts for the callback.
private func copyRepresentation(
    of provider: NSItemProvider, type: UTType, into folder: URL, id: String
) async throws -> (url: URL, type: UTType?) {
    let identifier = provider.registeredTypeIdentifiers
        .first { UTType($0)?.conforms(to: type) == true } ?? type.identifier
    return try await withCheckedThrowingContinuation { continuation in
        provider.loadFileRepresentation(forTypeIdentifier: identifier) { url, error in
            guard let url else {
                continuation.resume(throwing: error ?? CopyError.unreadable)
                return
            }
            do {
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                if size > maxFileBytes { throw CopyError.tooBig }
                let target = folder.appendingPathComponent("\(id).part")
                try? FileManager.default.removeItem(at: target)
                try FileManager.default.copyItem(at: url, to: target)
                continuation.resume(returning: (target, UTType(identifier) ?? UTType(filenameExtension: url.pathExtension)))
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

private let pictureTypes: [(UTType, String, String)] = [
    (.jpeg, "image/jpeg", "jpg"), (.png, "image/png", "png"),
    (.gif, "image/gif", "gif"), (.webP, "image/webp", "webp"),
]

private func preparePicture(
    _ copied: (url: URL, type: UTType?), id: String, name: String, in folder: URL
) throws -> SharedFile {
    let base = name.isEmpty ? "Picture" : (name as NSString).deletingPathExtension
    if let source = CGImageSourceCreateWithURL(copied.url as CFURL, nil),
       let typeId = CGImageSourceGetType(source) as String?,
       let match = pictureTypes.first(where: { $0.0.identifier == typeId }) {
        let target = folder.appendingPathComponent("\(id).\(match.2)")
        try FileManager.default.moveItem(at: copied.url, to: target)
        return SharedFile(id: id, kind: .picture, name: "\(base).\(match.2)", file: target.lastPathComponent, mime: match.1)
    }
    // Any other picture, such as HEIC, becomes JPEG.
    defer { try? FileManager.default.removeItem(at: copied.url) }
    guard let source = CGImageSourceCreateWithURL(copied.url as CFURL, nil),
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
              kCGImageSourceCreateThumbnailFromImageAlways: true,
              kCGImageSourceCreateThumbnailWithTransform: true,
              kCGImageSourceThumbnailMaxPixelSize: 4096,
          ] as CFDictionary)
    else { throw CopyError.unreadable }
    let target = folder.appendingPathComponent("\(id).jpg")
    guard let destination = CGImageDestinationCreateWithURL(target as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
    else { throw CopyError.unreadable }
    CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { throw CopyError.unreadable }
    let size = (try? target.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    if size > maxFileBytes {
        try? FileManager.default.removeItem(at: target)
        throw CopyError.tooBig
    }
    return SharedFile(id: id, kind: .picture, name: "\(base).jpg", file: target.lastPathComponent, mime: "image/jpeg")
}

/// Audio types apps share, by the type the server takes.
private let audioTypes: [String: (mime: String, ext: String)] = [
    "audio/mpeg": ("audio/mpeg", "mp3"), "audio/mp3": ("audio/mpeg", "mp3"),
    "audio/wav": ("audio/wav", "wav"), "audio/x-wav": ("audio/wav", "wav"), "audio/wave": ("audio/wav", "wav"),
    "audio/mp4": ("audio/mp4", "m4a"), "audio/m4a": ("audio/mp4", "m4a"), "audio/x-m4a": ("audio/mp4", "m4a"),
    "audio/ogg": ("audio/ogg", "ogg"), "audio/opus": ("audio/ogg", "ogg"),
    "audio/aac": ("audio/aac", "aac"), "audio/webm": ("audio/webm", "webm"),
]

private func prepareAudio(
    _ copied: (url: URL, type: UTType?), id: String, name: String, in folder: URL
) throws -> SharedFile {
    guard let mime = copied.type?.preferredMIMEType?.lowercased(), let match = audioTypes[mime] else {
        try? FileManager.default.removeItem(at: copied.url)
        throw CopyError.unsupported
    }
    let target = folder.appendingPathComponent("\(id).\(match.ext)")
    try FileManager.default.moveItem(at: copied.url, to: target)
    let seconds = AVURLAsset(url: target).duration.seconds
    let base = name.isEmpty ? "Audio" : (name as NSString).deletingPathExtension
    return SharedFile(
        id: id, kind: .audio, name: "\(base).\(match.ext)", file: target.lastPathComponent,
        mime: match.mime, duration: seconds.isFinite && seconds > 0 ? seconds : nil)
}
