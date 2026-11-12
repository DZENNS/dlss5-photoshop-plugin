import Foundation

public struct FrameSize: Equatable, Sendable, Codable {
    public var width: Int
    public var height: Int
    public init(_ width: Int, _ height: Int) { self.width = width; self.height = height }
    /// Keep the original aspect ratio, even dimensions and never supersample.
    public func processing(longEdge: Int) -> FrameSize {
        let factor = min(1, Double(max(64, longEdge)) / Double(max(1, max(width, height))))
        return FrameSize(max(2, Int(Double(width) * factor) / 2 * 2),
                         max(2, Int(Double(height) * factor) / 2 * 2))
    }
}

public struct RenderSettings: Codable, Equatable, Sendable {
    public var imageUpscaler = "off"
    public var graph: ProcessingGraph?
    public var neuralEnabled = true
    public var temporal = true
    public var processingLongEdge = 512
    public var captureFPS = 30
    public var intensity: Float = 1
    public var tone: Float = 1
    public var structure: Float = 1
    public var split: Float = 0
    public var profile = "natural"
    public var secondProfile = "off"
    public var secondProcessingLongEdge = 512
    public var secondIntensity: Float = 1
    public var secondTone: Float = 1
    public var secondStructure: Float = 1
    public var secondTemporal = true
    public var depth = DepthSettings()
    public var advanced = NeuralDetailSettings()
    public var secondAdvanced = NeuralDetailSettings()
    public var effects = EffectSettings()
    public init() {}
    private enum CodingKeys: String, CodingKey { case imageUpscaler, graph, depth, neuralEnabled, temporal, processingLongEdge, captureFPS, intensity, tone, structure, split, profile, secondProfile, secondProcessingLongEdge, secondIntensity, secondTone, secondStructure, secondTemporal, advanced, secondAdvanced, effects }
    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        imageUpscaler = try c.decodeIfPresent(String.self, forKey: .imageUpscaler) ?? "off"
        graph = try c.decodeIfPresent(ProcessingGraph.self, forKey: .graph)
        depth = try c.decodeIfPresent(DepthSettings.self, forKey: .depth) ?? DepthSettings()
        neuralEnabled = try c.decodeIfPresent(type(of: neuralEnabled), forKey: .neuralEnabled) ?? neuralEnabled
        temporal = try c.decodeIfPresent(type(of: temporal), forKey: .temporal) ?? temporal
        processingLongEdge = try c.decodeIfPresent(type(of: processingLongEdge), forKey: .processingLongEdge) ?? processingLongEdge
        captureFPS = try c.decodeIfPresent(type(of: captureFPS), forKey: .captureFPS) ?? captureFPS
        intensity = try c.decodeIfPresent(type(of: intensity), forKey: .intensity) ?? intensity
        tone = try c.decodeIfPresent(type(of: tone), forKey: .tone) ?? tone
        structure = try c.decodeIfPresent(type(of: structure), forKey: .structure) ?? structure
        split = try c.decodeIfPresent(type(of: split), forKey: .split) ?? split
        profile = try c.decodeIfPresent(type(of: profile), forKey: .profile) ?? profile
        secondProfile = try c.decodeIfPresent(type(of: secondProfile), forKey: .secondProfile) ?? secondProfile
        secondProcessingLongEdge = try c.decodeIfPresent(type(of: secondProcessingLongEdge), forKey: .secondProcessingLongEdge) ?? secondProcessingLongEdge
        secondIntensity = try c.decodeIfPresent(type(of: secondIntensity), forKey: .secondIntensity) ?? secondIntensity
        secondTone = try c.decodeIfPresent(type(of: secondTone), forKey: .secondTone) ?? secondTone
        secondStructure = try c.decodeIfPresent(type(of: secondStructure), forKey: .secondStructure) ?? secondStructure
        secondTemporal = try c.decodeIfPresent(type(of: secondTemporal), forKey: .secondTemporal) ?? secondTemporal
        advanced = try c.decodeIfPresent(type(of: advanced), forKey: .advanced) ?? advanced
        secondAdvanced = try c.decodeIfPresent(type(of: secondAdvanced), forKey: .secondAdvanced) ?? secondAdvanced
        effects = try c.decodeIfPresent(type(of: effects), forKey: .effects) ?? effects
        sanitize()
    }
    public var usesTemporal: Bool { graph?.needsTemporal ?? (temporal || (secondProfile != "off" && secondTemporal)) }
    public var needsModel: Bool { graph?.needsModel ?? (neuralEnabled || secondProfile != "off") }
    public mutating func sanitize() {
        graph?.sanitize()
        if !["off", "realesrgan2"].contains(imageUpscaler) { imageUpscaler = "off" }
        processingLongEdge = min(1920, max(320, processingLongEdge))
        secondProcessingLongEdge = min(1920, max(320, secondProcessingLongEdge))
        secondIntensity = secondIntensity.isFinite ? min(2, max(0, secondIntensity)) : 1
        secondTone = secondTone.isFinite ? min(2, max(0, secondTone)) : 1
        secondStructure = secondStructure.isFinite ? min(2, max(0, secondStructure)) : 1
        depth.sanitize()
        advanced.sanitize(); secondAdvanced.sanitize()
        effects.sanitize()
        captureFPS = min(60, max(5, captureFPS))
        intensity = intensity.isFinite ? min(2, max(0, intensity)) : 1
        tone = tone.isFinite ? min(2, max(0, tone)) : 1
        structure = structure.isFinite ? min(2, max(0, structure)) : 1
        split = split.isFinite ? min(1, max(0, split)) : 0
        if !["off", "natural", "standard", "cinematic", "neutral"].contains(secondProfile) { secondProfile = "off" }
        if !["natural", "standard", "cinematic", "neutral"].contains(profile) { profile = "natural" }
    }
}

/// A reset is needed after source switches, geometry changes, control changes,
/// bypass, or a long interruption. Dropped captures alone are fine: flow is
/// estimated between the two frames that actually reach the model.
public struct HistoryBoundary: Equatable, Sendable {
    public let size: FrameSize
    public let profile: String
    public let tone: Float
    public let structure: Float
    public let intensity: Float
    public let temporal: Bool
    public let advanced: NeuralDetailSettings
    public init(size: FrameSize, settings: RenderSettings) {
        self.size = size; profile = settings.profile; tone = settings.tone
        structure = settings.structure; intensity = settings.intensity; temporal = settings.temporal
        advanced = settings.advanced
    }
}

/// Thread-safe bounded handoff. A slow renderer retains only the latest pending
/// frame; it never builds seconds of desktop latency behind an unbounded queue.
public final class LatestFrames<Element: Sendable>: @unchecked Sendable {
    public let stream: AsyncStream<Element>
    private let continuation: AsyncStream<Element>.Continuation
    private let lock = NSLock()
    private var droppedCount = 0
    public init() {
        let pair = AsyncStream<Element>.makeStream(bufferingPolicy: .bufferingNewest(1))
        stream = pair.stream; continuation = pair.continuation
    }
    public var dropped: Int { lock.lock(); defer { lock.unlock() }; return droppedCount }
    public func yield(_ element: Element) {
        if case .dropped = continuation.yield(element) {
            lock.lock(); droppedCount += 1; lock.unlock()
        }
    }
    public func finish() { continuation.finish() }
}

/// Final image adjustments, applied once after all neural passes.
public struct EffectSettings: Codable, Equatable, Sendable {
    public var exposure: Float = 0
    public var contrast: Float = 1
    public var highlights: Float = 1
    public var shadows: Float = 0
    public var whites: Float = 0
    public var blacks: Float = 0
    public var saturation: Float = 1
    public var vibrance: Float = 0
    public var temperature: Float = 0
    public var tint: Float = 0
    public var sharpness: Float = 0
    public var clarity: Float = 0
    public var denoise: Float = 0
    public var bloom: Float = 0
    public var vignette: Float = 0
    public var grain: Float = 0
    public init() {}
    public var isIdentity: Bool { self == EffectSettings() }
    public mutating func sanitize() {
        func clamp(_ value: Float, _ lower: Float, _ upper: Float, _ fallback: Float = 0) -> Float {
            value.isFinite ? min(upper, max(lower, value)) : fallback
        }
        exposure = clamp(exposure, -3, 3); contrast = clamp(contrast, 0.5, 1.5, 1)
        highlights = clamp(highlights, 0, 2, 1); shadows = clamp(shadows, -1, 1)
        whites = clamp(whites, -1, 1); blacks = clamp(blacks, -1, 1)
        saturation = clamp(saturation, 0, 2, 1); vibrance = clamp(vibrance, -1, 1)
        temperature = clamp(temperature, -1, 1); tint = clamp(tint, -1, 1)
        sharpness = clamp(sharpness, 0, 1); clarity = clamp(clarity, 0, 1)
        denoise = clamp(denoise, 0, 1); bloom = clamp(bloom, 0, 1)
        vignette = clamp(vignette, 0, 2); grain = clamp(grain, 0, 0.1)
    }
}

/// Composition controls and the model's optional automatic structure conditioning.
public struct NeuralDetailSettings: Codable, Equatable, Sendable {
    public var detail: Float = 1
    public var colour: Float = 1
    public var radius: Float = 4
    public var skinEnabled = false
    public var skin: Float = 1
    public var automaticStructure: Float = 1
    public init() {}
    public mutating func sanitize() {
        func bounded(_ x: Float, _ range: ClosedRange<Float>, _ fallback: Float) -> Float {
            x.isFinite ? min(range.upperBound, max(range.lowerBound, x)) : fallback
        }
        detail = bounded(detail, 0...2, 1); colour = bounded(colour, 0...2, 1)
        radius = bounded(radius, 0.5...12, 4)
        skin = bounded(skin, 0...2, 1); automaticStructure = bounded(automaticStructure, 0...2, 1)
    }
}

public struct DepthSettings: Codable, Equatable, Sendable {
    public var enabled = false
    public var focus: Float = 0.75
    public var focusWidth: Float = 0.2
    public var blur: Float = 0
    public var backgroundExposure: Float = 0
    public init() {}
    public mutating func sanitize() {
        func clamp(_ x: Float, _ lo: Float, _ hi: Float, _ fallback: Float) -> Float {
            x.isFinite ? min(hi, max(lo, x)) : fallback
        }
        focus = clamp(focus, 0, 1, 0.75); focusWidth = clamp(focusWidth, 0.02, 0.8, 0.2)
        blur = clamp(blur, 0, 30, 0); backgroundExposure = clamp(backgroundExposure, -2, 2, 0)
    }
}
