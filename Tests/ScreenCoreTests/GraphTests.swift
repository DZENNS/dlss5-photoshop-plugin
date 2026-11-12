import XCTest
@testable import ScreenCore

final class GraphTests: XCTestCase {
    func testStarterIsMinimalConnectedAndArranged() throws {
        let graph = ProcessingGraph.starter(video: false)
        let plan = try graph.plan()
        XCTAssertEqual(plan.map(\.kind), [.source, .dlss, .output])
        XCTAssertLessThan(plan[0].x, plan[1].x)
        XCTAssertLessThan(plan[1].x, plan[2].x)
    }
    func testArrangeKeepsDepthBranchSeparateWithoutChangingExecution() throws {
        var graph = ProcessingGraph.starter(video: false)
        graph.add(.depthAnalysis); graph.add(.depthEffects)
        let before = try graph.plan().map(\.id)
        graph.arrange()
        XCTAssertEqual(try graph.plan().map(\.id), before)
        let analyzer = graph.nodes.first { $0.kind == .depthAnalysis }!
        let enhance = graph.nodes.first { $0.kind == .dlss }!
        let effect = graph.nodes.first { $0.kind == .depthEffects }!
        XCTAssertNotEqual(analyzer.y, enhance.y)
        XCTAssertLessThan(analyzer.x, effect.x)
    }
    func testLegacyConversionPreservesBothPassesAndDepth() throws {
        var s = RenderSettings(); s.secondProfile = "cinematic"; s.secondAdvanced.skinEnabled = true
        s.secondIntensity = 0.65; s.effects.saturation = 0.8; s.effects.grain = 0.02; s.depth.enabled = true
        let graph = ProcessingGraph.legacy(s, video: false)
        let plan = try graph.plan()
        XCTAssertEqual(plan.last?.kind, .output)
        let layers = plan.filter { $0.kind == .dlss }
        XCTAssertEqual(layers.count, 2); XCTAssertEqual(layers[1].neural.profile, "cinematic")
        XCTAssertEqual(layers[1].neural.intensity, 0.65); XCTAssertTrue(layers[1].neural.advanced.skinEnabled)
        XCTAssertEqual(plan.first { $0.kind == .grade }?.effectSettings.saturation, 0.8)
        XCTAssertEqual(plan.first { $0.kind == .grade }?.effectSettings.grain, 0.02)
        XCTAssertEqual(plan.first { $0.kind == .depthAnalysis }?.input, graph.source?.id)
    }
    func testExecutionFollowsConnectionsNotStorageOrPositions() throws {
        var graph = ProcessingGraph.legacy(RenderSettings(), video: false)
        let before = try graph.plan().map(\.id)
        graph.nodes.reverse(); graph.nodes[0].x = 3000
        XCTAssertEqual(try graph.plan().map(\.id), before)
        let colour = graph.nodes.first { $0.kind == .colour }!.id
        let effects = graph.nodes.first { $0.kind == .effects }!.id
        let dlss = graph.nodes.first { $0.kind == .dlss }!.id
        graph.nodes[graph.nodes.firstIndex { $0.id == effects }!].input = dlss
        graph.nodes[graph.nodes.firstIndex { $0.id == colour }!].input = effects
        graph.nodes[graph.nodes.firstIndex { $0.kind == .output }!].input = colour
        XCTAssertEqual(try graph.plan().map(\.kind), [.source, .dlss, .effects, .colour, .output])
    }
    func testCyclesTypesAndDisconnectedTerminalsRejected() throws {
        var graph = ProcessingGraph.legacy(RenderSettings(), video: false)
        let dlss = graph.nodes.first { $0.kind == .dlss }!.id
        let colour = graph.nodes.first { $0.kind == .colour }!.id
        XCTAssertThrowsError(try graph.connect(colour, to: dlss))
        XCTAssertNoThrow(try graph.plan())
        graph.add(.depthAnalysis)
        let depth = graph.nodes.last!.id
        XCTAssertThrowsError(try graph.connect(depth, to: dlss))
        XCTAssertThrowsError(try graph.connect(dlss, to: colour, depth: true))
        graph.nodes[graph.nodes.firstIndex { $0.kind == .output }!].input = nil
        XCTAssertThrowsError(try graph.plan())
    }
    func testIntermediatePreviewAndBypassDepth() throws {
        var graph = ProcessingGraph.legacy(RenderSettings(), video: false)
        graph.add(.depthEffects)
        XCTAssertThrowsError(try graph.plan())
        graph.nodes[graph.nodes.count-1].enabled = false
        XCTAssertNoThrow(try graph.plan())
        graph.previewTarget = graph.source!.id
        XCTAssertEqual(try graph.plan().count, 1)
    }
    func testPresetRoundTripLayoutAndRenderInvalidation() throws {
        var s = RenderSettings(); s.graph = ProcessingGraph.legacy(s, video: false)
        let before = s
        s.graph!.nodes[0].x = 1234
        XCTAssertEqual(s, before, "Layout does not invalidate rendered output")
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(RenderSettings.self, from: data)
        XCTAssertEqual(decoded.graph!.nodes[0].x, 1234)
        s.graph!.nodes[1].neural.intensity = 0.3
        XCTAssertNotEqual(s, before)
        s = before; s.graph!.previewTarget = s.graph!.source!.id
        XCTAssertNotEqual(s, before, "Intermediate preview cannot authorize final export")
    }
    func testVideoRejectsPhotoOnlyDepthAndDeletionReconnectsChain() throws {
        var graph = ProcessingGraph.legacy(RenderSettings(), video: false)
        let dlss = graph.nodes.first { $0.kind == .dlss }!.id
        graph.remove(dlss)
        XCTAssertEqual(try graph.plan().map(\.kind), [.source, .colour, .effects, .output])
        graph.add(.depthAnalysis); graph.video = true
        XCTAssertThrowsError(try graph.plan())
    }
}
