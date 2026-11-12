import Foundation

public enum NodeKind: String, Codable, CaseIterable, Sendable {
    case source, dlss, colour, effects, grade, depthAnalysis, depthEffects, output
    public var title: String {
        switch self {
        case .source: return "Source"
        case .dlss: return "DLSS5"
        case .colour: return "Colour"
        case .effects: return "Grain & Effects"
        case .grade: return "Colour & Effects"
        case .depthAnalysis: return "Analyze Depth"
        case .depthEffects: return "Depth Effects"
        case .output: return "Export"
        }
    }
}

public struct NeuralNodeSettings: Codable, Equatable, Sendable {
    public var profile = "natural"
    public var size = 512
    public var intensity: Float = 1
    public var tone: Float = 1
    public var structure: Float = 1
    public var temporal = true
    public var advanced = NeuralDetailSettings()
    public init() {}
    public var renderSettings: RenderSettings {
        var s = RenderSettings()
        s.profile = profile; s.processingLongEdge = size; s.intensity = intensity
        s.tone = tone; s.structure = structure; s.temporal = temporal; s.advanced = advanced
        return s
    }
    public init(_ settings: RenderSettings) {
        profile = settings.profile; size = settings.processingLongEdge; intensity = settings.intensity
        tone = settings.tone; structure = settings.structure; temporal = settings.temporal; advanced = settings.advanced
    }
}

public struct ProcessingNode: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var kind: NodeKind
    public var enabled = true
    public var customName: String?
    public var input: UUID?
    public var depthInput: UUID?
    public var x: Double = 40
    public var y: Double = 60
    public var neural = NeuralNodeSettings()
    public var effects = EffectSettings()
    public var depth = DepthSettings()
    public init(_ kind: NodeKind, input: UUID? = nil) { self.kind = kind; self.input = input }
    public var effectSettings: EffectSettings {
        var s = effects
        if kind == .colour {
            s.sharpness = 0; s.clarity = 0; s.denoise = 0; s.bloom = 0; s.vignette = 0; s.grain = 0
        } else if kind == .effects {
            s.exposure = 0; s.contrast = 1; s.highlights = 1; s.shadows = 0; s.whites = 0; s.blacks = 0
            s.saturation = 1; s.vibrance = 0; s.temperature = 0; s.tint = 0
        }
        s.sanitize(); return s
    }
}

public struct GraphError: LocalizedError {
    public let message: String
    public var errorDescription: String? { message }
    public init(_ message: String) { self.message = message }
}

public struct ProcessingGraph: Codable, Equatable, Sendable {
    public var nodes: [ProcessingNode]
    public var video: Bool
    /// nil means the mandatory export terminal. Previewing another node never authorizes export.
    public var previewTarget: UUID?
    public init(nodes: [ProcessingNode], video: Bool) { self.nodes = nodes; self.video = video }
    public static func == (lhs: Self, rhs: Self) -> Bool {
        // Moving a card changes the saved layout, not the rendered pixels.
        func semantic(_ nodes: [ProcessingNode]) -> [ProcessingNode] {
            nodes.map { var n = $0; n.x = 0; n.y = 0; return n }
        }
        return lhs.video == rhs.video && lhs.previewTarget == rhs.previewTarget && semantic(lhs.nodes) == semantic(rhs.nodes)
    }
    public var output: ProcessingNode? { nodes.first { $0.kind == .output } }
    public var source: ProcessingNode? { nodes.first { $0.kind == .source } }
    public var needsTemporal: Bool { video && nodes.contains { $0.kind == .dlss && $0.enabled && $0.neural.temporal } }
    public var needsModel: Bool { nodes.contains { $0.kind == .dlss && $0.enabled && $0.neural.intensity > 0 } }
    public mutating func sanitize() {
        for i in nodes.indices {
            var s = nodes[i].neural.renderSettings; s.sanitize()
            nodes[i].neural = NeuralNodeSettings(s)
            nodes[i].effects.sanitize(); nodes[i].depth.sanitize()
            nodes[i].x = nodes[i].x.isFinite ? min(8000, max(20, nodes[i].x)) : 40
            nodes[i].y = nodes[i].y.isFinite ? min(4000, max(20, nodes[i].y)) : 60
        }
    }
    /// Validate typed connections and return only the dependencies of the preview/output.
    public func plan() throws -> [ProcessingNode] {
        guard nodes.count <= 32, Set(nodes.map(\.id)).count == nodes.count,
              nodes.filter({ $0.kind == .source }).count == 1,
              nodes.filter({ $0.kind == .output }).count == 1 else {
            throw GraphError("A graph needs exactly one Source and one Export, unique node IDs and at most 32 nodes.")
        }
        guard nodes.filter({ $0.kind == .dlss }).count <= 4 else { throw GraphError("Use at most four DLSS5 nodes.") }
        if video && nodes.contains(where: { $0.kind == .depthAnalysis || $0.kind == .depthEffects }) {
            throw GraphError("Depth nodes are available for photos only. Remove them before using this preset for video.")
        }
        let lookup = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        for node in nodes {
            if node.kind == .source {
                guard node.input == nil, node.depthInput == nil else { throw GraphError("Source cannot have inputs.") }
            } else if let input = node.input {
                guard let parent = lookup[input], parent.kind != .depthAnalysis, parent.kind != .output else {
                    throw GraphError("Image inputs must connect to an image output.")
                }
                if node.kind == .depthAnalysis && parent.kind != .source { throw GraphError("Analyze Depth must connect to Source.") }
            }
            if let depth = node.depthInput {
                guard node.kind == .depthEffects, lookup[depth]?.kind == .depthAnalysis else { throw GraphError("Connect a depth output to the Depth Effects map input.") }
            }
        }
        var visiting = Set<UUID>(), visited = Set<UUID>()
        func checkCycle(_ id: UUID) throws {
            guard !visiting.contains(id) else { throw GraphError("Connections cannot form a cycle.") }
            if visited.contains(id) { return }
            visiting.insert(id)
            if let n = lookup[id] { for parent in [n.input, n.depthInput].compactMap({ $0 }) { try checkCycle(parent) } }
            visiting.remove(id); visited.insert(id)
        }
        for node in nodes { try checkCycle(node.id) }
        var ordered: [ProcessingNode] = []; visited.removeAll()
        func visit(_ id: UUID) throws {
            if visited.contains(id) { return }
            guard let n = lookup[id] else { throw GraphError("The preview node no longer exists.") }
            if n.kind != .source {
                guard let input = n.input else { throw GraphError("Connect the image input of \(n.kind.title).") }
                try visit(input)
                if n.kind == .depthEffects && n.enabled {
                    guard let depth = n.depthInput else { throw GraphError("Connect a depth map to Depth Effects.") }
                    try visit(depth)
                }
            }
            visited.insert(id); ordered.append(n)
        }
        guard let target = previewTarget ?? output?.id else { throw GraphError("Add an Export node.") }
        try visit(target)
        return ordered
    }
    public mutating func connect(_ from: UUID, to: UUID, depth: Bool = false) throws {
        guard let i = nodes.firstIndex(where: { $0.id == to }) else { throw GraphError("Missing input node.") }
        let old = self
        if depth { nodes[i].depthInput = from } else { nodes[i].input = from }
        // Missing connections are allowed while editing, but type and cycle checks must pass.
        do { _ = try plan() }
        catch let e as GraphError where e.message.hasPrefix("Connect the image input") || e.message == "Connect a depth map to Depth Effects." { return }
        catch { self = old; throw error }
    }
    public mutating func remove(_ id: UUID) {
        guard let n = nodes.first(where: { $0.id == id }), n.kind != .source, n.kind != .output else { return }
        nodes.removeAll { $0.id == id }
        for i in nodes.indices {
            if nodes[i].input == id { nodes[i].input = n.kind == .depthAnalysis ? nil : n.input }
            if nodes[i].depthInput == id { nodes[i].depthInput = nil }
        }
        if previewTarget == id { previewTarget = nil }
    }
    public mutating func add(_ kind: NodeKind, after selected: UUID? = nil) {
        guard kind != .source, kind != .output, nodes.count < 32,
              kind != .dlss || nodes.filter({ $0.kind == .dlss }).count < 4,
              !video || (kind != .depthEffects && kind != .depthAnalysis) else { return }
        let parent = nodes.first { $0.id == selected && $0.kind != .output && $0.kind != .depthAnalysis }?.id ?? output?.input ?? source?.id
        var n = ProcessingNode(kind, input: kind == .depthAnalysis ? source?.id : parent)
        if kind == .depthEffects { n.depthInput = nodes.first { $0.kind == .depthAnalysis }?.id }
        if kind != .depthAnalysis {
            for i in nodes.indices where nodes[i].input == parent && nodes[i].kind != .depthAnalysis { nodes[i].input = n.id }
        }
        n.x = 60 + Double(nodes.count % 4) * 250; n.y = 240 + Double(nodes.count / 4) * 190
        nodes.append(n)
    }
    public mutating func arrange() {
        var levels: [UUID: Int] = [:]
        // Relax only a bounded number of times, including during incomplete graph editing.
        for _ in 0..<nodes.count {
            for node in nodes {
                let dependencies = [node.input, node.depthInput].compactMap { $0 }
                if node.kind == .source { levels[node.id] = 0 }
                else if dependencies.allSatisfy({ levels[$0] != nil }) && !dependencies.isEmpty {
                    levels[node.id] = min(nodes.count, (dependencies.compactMap { levels[$0] }.max() ?? 0) + 1)
                }
            }
        }
        var rows: [Int: Int] = [:]
        for i in nodes.indices.sorted(by: { nodes[$0].kind != .depthAnalysis && nodes[$1].kind == .depthAnalysis }) {
            let level = levels[nodes[i].id] ?? 1
            let row = rows[level, default: 0]; rows[level] = row + 1
            nodes[i].x = 40 + Double(level) * 230
            nodes[i].y = 50 + Double(row) * 190
        }
    }
    public static func starter(video: Bool) -> Self {
        let source = ProcessingNode(.source)
        let enhance = ProcessingNode(.dlss, input: source.id)
        let output = ProcessingNode(.output, input: enhance.id)
        var graph = Self(nodes: [source, enhance, output], video: video)
        graph.arrange(); return graph
    }
    public static func legacy(_ settings: RenderSettings, video: Bool) -> Self {
        if var graph = settings.graph { graph.video = video; graph.previewTarget = nil; return graph }
        let source = ProcessingNode(.source)
        var nodes = [source]
        func append(_ node: ProcessingNode) { var n = node; n.input = nodes.last?.id; nodes.append(n) }
        var first = ProcessingNode(.dlss); first.enabled = settings.neuralEnabled; first.neural = NeuralNodeSettings(settings); append(first)
        if settings.secondProfile != "off" {
            var second = ProcessingNode(.dlss)
            second.neural.profile = settings.secondProfile; second.neural.size = settings.secondProcessingLongEdge
            second.neural.intensity = settings.secondIntensity; second.neural.tone = settings.secondTone
            second.neural.structure = settings.secondStructure; second.neural.temporal = settings.secondTemporal
            second.neural.advanced = settings.secondAdvanced; append(second)
        }
        if settings.effects.isIdentity {
            append(ProcessingNode(.colour)); append(ProcessingNode(.effects))
        } else {
            // Preserve the exact old filter ordering and its single render/quantization boundary.
            var grade = ProcessingNode(.grade); grade.effects = settings.effects; append(grade)
        }
        if settings.depth.enabled && !video {
            let analysis = ProcessingNode(.depthAnalysis, input: source.id)
            var effect = ProcessingNode(.depthEffects); effect.depth = settings.depth; effect.depthInput = analysis.id
            append(effect); let tail = nodes.last!.id; nodes.append(analysis)
            nodes.append(ProcessingNode(.output, input: tail))
        } else { append(ProcessingNode(.output)) }
        var graph = Self(nodes: nodes, video: video); graph.arrange(); return graph
    }
}
