import Foundation

/// `context.json` from the app, `staging/` while a share is open, and the
/// saved shares in `inbox/`.
enum ShareFolder {
    /// Also in AppDelegate.swift and both entitlements files.
    static let appGroup = "group.com.zhfahim.anchor"

    static var root: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("share", isDirectory: true)
    }

    static func readContext() -> ShareContext {
        guard let root,
              let data = try? Data(contentsOf: root.appendingPathComponent("context.json")),
              let context = try? JSONDecoder().decode(ShareContext.self, from: data)
        else { return ShareContext() }
        return context
    }

    static func newStaging(id: String) -> URL? {
        guard let root else { return nil }
        let folder = root.appendingPathComponent("staging/\(id)", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func save(_ entry: ShareEntry, staging: URL) throws {
        guard let root else { throw CocoaError(.fileNoSuchFile) }
        let encoder = JSONEncoder()
        try encoder.encode(entry).write(to: staging.appendingPathComponent("manifest.json"), options: .atomic)
        let inbox = root.appendingPathComponent("inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: staging, to: inbox.appendingPathComponent(entry.id, isDirectory: true))
    }

    static func dropOldStaging() {
        guard let root else { return }
        let staging = root.appendingPathComponent("staging", isDirectory: true)
        let cutoff = Date().addingTimeInterval(-60 * 60)
        let folders = (try? FileManager.default.contentsOfDirectory(
            at: staging, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        for folder in folders {
            let modified = (try? folder.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let modified, modified < cutoff { try? FileManager.default.removeItem(at: folder) }
        }
    }
}

/// What the app keeps in `context.json`; see share_context.dart.
struct ShareContext: Decodable {
    var userId: String?
    var theme = "system"
    var density = "standard"
    var tags: [ShareTag] = []

    var isCompact: Bool { density == "compact" }

    private enum CodingKeys: String, CodingKey { case userId, theme, density, tags }

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let userId = try? values.decodeIfPresent(String.self, forKey: .userId)
        self.userId = userId?.isEmpty == false ? userId : nil
        theme = (try? values.decodeIfPresent(String.self, forKey: .theme)) ?? "system"
        density = (try? values.decodeIfPresent(String.self, forKey: .density)) ?? "standard"
        tags = (try? values.decodeIfPresent([ShareTag].self, forKey: .tags)) ?? []
    }
}

struct ShareTag: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let color: String?
}

/// A saved share, as `manifest.json`; see share_entry.dart.
struct ShareEntry: Encodable {
    let version = 1
    let id: String
    let userId: String
    let savedAt: String
    let title: String
    let text: String
    let link: String?
    let tagIds: [String]
    let files: [ShareEntryFile]
}

struct ShareEntryFile: Encodable {
    let file: String
    let name: String
    let mime: String
}
