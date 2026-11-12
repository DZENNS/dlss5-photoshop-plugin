import XCTest
@testable import ScreenCore

final class LayerTests: XCTestCase {
    func testLayerOrderChangesExecutionButPreservesDepthDependency() throws {
        var graph = ProcessingGraph.layerStarter(video: false)
        graph.add(.dlss); graph.add(.colour); graph.add(.depthAnalysis); graph.add(.depthEffects)
        let map = graph.nodes.first { $0.kind == .depthAnalysis }!
        let layers = graph.imageLayers.filter { $0.kind != .source }
        try graph.reorderLayers(layers.reversed().map(\.id))
        XCTAssertEqual(graph.imageLayers.filter { $0.kind != .source }.map(\.id), layers.reversed().map(\.id))
        XCTAssertEqual(graph.nodes.first { $0.kind == .depthEffects }?.depthInput, map.id)
        XCTAssertEqual(try graph.plan().first?.kind, .source)
        XCTAssertEqual(try graph.plan().last?.kind, .output)
        let snapshot = graph
        XCTAssertThrowsError(try graph.reorderLayers([layers[0].id, layers[0].id]))
        XCTAssertEqual(graph, snapshot)
    }
    func testDuplicatePreservesControlsAndReconnectsSuccessor() throws {
        var graph = ProcessingGraph.layerStarter(video: false)
        graph.add(.dlss)
        let id = graph.imageLayers.last!.id
        let i = graph.nodes.firstIndex { $0.id == id }!
        graph.nodes[i].neural.intensity = 0.42; graph.nodes[i].customName = "Skin"
        let copyID = try XCTUnwrap(graph.duplicateLayer(id))
        let copy = try XCTUnwrap(graph.nodes.first { $0.id == copyID })
        XCTAssertEqual(copy.input, id); XCTAssertEqual(copy.neural.intensity, 0.42)
        XCTAssertEqual(copy.customName, "Skin copy"); XCTAssertEqual(graph.output?.input, copyID)
        let data = try JSONEncoder().encode(graph)
        XCTAssertEqual(try JSONDecoder().decode(ProcessingGraph.self, from: data), graph)
        graph.remove(copyID)
        XCTAssertEqual(graph.output?.input, id)
    }
    func testDetachedPresetLayersAreNotSilentlyActivated() throws {
        var graph = ProcessingGraph.layerStarter(video: false)
        let unused = ProcessingNode(.colour, input: graph.source!.id)
        graph.nodes.append(unused)
        XCTAssertEqual(graph.imageLayers.map(\.kind), [.source])
        XCTAssertEqual(graph.detachedLayers.map(\.id), [unused.id])
        try graph.reorderLayers([])
        XCTAssertFalse(try graph.plan().contains { $0.id == unused.id })
    }
}
