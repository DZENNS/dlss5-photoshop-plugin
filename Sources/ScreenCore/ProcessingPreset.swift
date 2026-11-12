import Foundation

public struct ProcessingPreset: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var settings: RenderSettings
    public var automaticImages: Bool
    public var keepAudio: Bool
    public init(name: String, settings: RenderSettings, automaticImages: Bool, keepAudio: Bool) {
        id = UUID(); self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.settings = settings; self.settings.sanitize()
        self.settings.split = 0
        self.automaticImages = automaticImages; self.keepAudio = keepAudio
    }
}

/// Atomic, versioned storage. Failed writes leave the previous presets intact.
public struct PresetFile {
    public let url: URL
    public init(url: URL) { self.url = url }
    private struct Document: Codable {
        var version = 1
        var presets: [ProcessingPreset]
    }
    public func load() throws -> [ProcessingPreset] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let document = try JSONDecoder().decode(Document.self, from: Data(contentsOf: url))
        guard document.version == 1 else {
            throw NSError(domain: "Presets", code: 1, userInfo: [NSLocalizedDescriptionKey: "This preset file needs a newer version of the app."])
        }
        return document.presets
    }
    public func save(_ presets: [ProcessingPreset]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(Document(presets: presets)).write(to: url, options: .atomic)
    }
}
