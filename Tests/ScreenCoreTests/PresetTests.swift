import XCTest
@testable import ScreenCore

final class PresetTests: XCTestCase {
    func testPresetsPersistAllControlsAndDelete() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = PresetFile(url: directory.appendingPathComponent("presets.json"))
        XCTAssertEqual(try file.load(), [])
        var settings = RenderSettings()
        settings.profile = "cinematic"; settings.tone = 0.32
        settings.secondProfile = "natural"; settings.secondTone = 0.7
        settings.advanced.skinEnabled = true; settings.advanced.skin = 0.4
        settings.secondAdvanced.colour = 0.2; settings.secondAdvanced.radius = 7
        settings.depth.enabled = true; settings.depth.focus = 0.34; settings.depth.blur = 11
        settings.effects.grain = 0.03; settings.effects.saturation = 0.8
        let first = ProcessingPreset(name: " Portrait ", settings: settings, automaticImages: false, keepAudio: false)
        let second = ProcessingPreset(name: "Other", settings: RenderSettings(), automaticImages: true, keepAudio: true)
        try file.save([first, second])
        let restored = try file.load()
        XCTAssertEqual(restored, [first, second])
        XCTAssertEqual(restored[0].name, "Portrait")
        XCTAssertEqual(restored[0].settings, settings)
        try file.save(restored.filter { $0.id != first.id })
        XCTAssertEqual(try file.load(), [second])
    }
    func testMissingNewControlsUseDefaultsAndInvalidNumbersAreClamped() throws {
        let settings = try JSONDecoder().decode(RenderSettings.self, from: Data("{\"tone\":0.4,\"secondProfile\":\"cinematic\"}".utf8))
        XCTAssertEqual(settings.tone, 0.4)
        XCTAssertEqual(settings.advanced, NeuralDetailSettings())
        XCTAssertEqual(settings.depth, DepthSettings())
        var invalid = settings
        invalid.advanced.radius = .infinity; invalid.secondAdvanced.skin = -9
        invalid.sanitize()
        XCTAssertEqual(invalid.advanced.radius, 4); XCTAssertEqual(invalid.secondAdvanced.skin, 0)
    }
    func testAdvancedControlsInvalidateHistoryAndCachedOutput() {
        let settings = RenderSettings()
        let old = HistoryBoundary(size: FrameSize(320, 180), settings: settings)
        var next = settings; next.advanced.colour = 0.4
        XCTAssertNotEqual(old, HistoryBoundary(size: FrameSize(320, 180), settings: next))
        next = settings; next.advanced.skinEnabled = true
        XCTAssertNotEqual(old, HistoryBoundary(size: FrameSize(320, 180), settings: next))
    }
    func testCorruptFileIsNotSilentlyOverwrittenOnRead() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let original = Data("not json".utf8); try original.write(to: url)
        XCTAssertThrowsError(try PresetFile(url: url).load())
        XCTAssertEqual(try Data(contentsOf: url), original)
    }
}
