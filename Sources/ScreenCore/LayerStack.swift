import Foundation

extension ProcessingGraph {
    public static func layerStarter(video: Bool) -> Self {
        let source = ProcessingNode(.source)
        return Self(nodes: [source, ProcessingNode(.output, input: source.id)], video: video)
    }

    /// Image chain in processing order. Depth maps remain internal dependencies.
    public var imageLayers: [ProcessingNode] {
        var result: [ProcessingNode] = [], seen = Set<UUID>()
        var cursor = output?.input
        while let id = cursor, seen.insert(id).inserted, let node = nodes.first(where: { $0.id == id }) {
            result.append(node); cursor = node.input
        }
        return result.reversed()
    }
    public var detachedLayers: [ProcessingNode] {
        let active = Set(imageLayers.map(\.id))
        return nodes.filter { !active.contains($0.id) && $0.kind != .output && $0.kind != .depthAnalysis && $0.kind != .source }
    }
    /// Only connected image layers may be reordered; map branches and detached nodes are preserved.
    public mutating func reorderLayers(_ ids: [UUID]) throws {
        let layers = imageLayers.filter { $0.kind != .source }
        guard ids.count == layers.count, Set(ids) == Set(layers.map(\.id)), let source = source else {
            throw GraphError("Layer order must include each adjustment exactly once.")
        }
        var next = self, previous = source.id
        for id in ids {
            guard let i = next.nodes.firstIndex(where: { $0.id == id }) else { continue }
            next.nodes[i].input = previous; previous = id
        }
        if let i = next.nodes.firstIndex(where: { $0.kind == .output }) { next.nodes[i].input = previous }
        next.previewTarget = nil
        _ = try next.plan(); self = next
    }
    public mutating func duplicateLayer(_ id: UUID) -> UUID? {
        guard let original = nodes.first(where: { $0.id == id }), original.kind != .source,
              original.kind != .output, original.kind != .depthAnalysis, nodes.count < 32,
              original.kind != .dlss || nodes.filter({ $0.kind == .dlss }).count < 4 else { return nil }
        var copy = original; copy.id = UUID(); copy.input = original.id
        copy.customName = (original.customName ?? original.kind.title) + " copy"
        for i in nodes.indices where nodes[i].input == id && nodes[i].kind != .depthAnalysis { nodes[i].input = copy.id }
        nodes.append(copy); previewTarget = nil; return copy.id
    }
}
