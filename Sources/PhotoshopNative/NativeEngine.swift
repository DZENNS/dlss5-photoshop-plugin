import Foundation
import CoreVideo
import DLSSCore
import DLSSMLX
import DLSSMedia
import ScreenCore

// In-process ABI. Input is copied before returning; result/error pointers are
// valid only during completion. The addon must copy them before scheduling JS.
public typealias DLSSCompletion = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<UInt8>?, Int, UnsafePointer<CChar>?) -> Void
private let processor = PhotoProcessor()

@_cdecl("dlss5_process")
public func dlss5Process(_ bytes: UnsafePointer<UInt8>?, _ length: Int,
                        _ width: Int32, _ height: Int32, _ components: Int32,
                        _ json: UnsafePointer<CChar>?, _ resources: UnsafePointer<CChar>?,
                        _ context: UnsafeMutableRawPointer?, _ completion: DLSSCompletion) {
    guard let bytes, let json, let resources, width > 0, height > 0,
          width <= 16384, height <= 16384, [3,4].contains(components),
          Int(width) * Int(height) <= 24_000_000,
          length == Int(width) * Int(height) * Int(components) else {
        "Invalid RGB image dimensions or pixel buffer".withCString { completion(context, nil, 0, $0) }; return
    }
    let source = Data(bytes: bytes, count: length)
    let settingsData = Data(String(cString: json).utf8)
    let directory = URL(fileURLWithPath: String(cString: resources), isDirectory: true)
    Task {
        do {
            let settings = try JSONDecoder().decode(RenderSettings.self, from: settingsData)
            let output = try await processor.process(source, width: Int(width), height: Int(height), components: Int(components), settings: settings, resources: directory)
            output.withUnsafeBytes { completion(context, $0.bindMemory(to: UInt8.self).baseAddress, output.count, nil) }
        } catch { error.localizedDescription.withCString { completion(context, nil, 0, $0) } }
    }
}

private actor PhotoProcessor {
    private var active = false
    private var renderer: MLXNeuralRenderingDeviceTemporalBackend?
    private var surfaces: MetalFrames?
    private var resourceDirectory: URL?
    private var sequence: UInt64 = 0

    func process(_ source: Data, width: Int, height: Int, components: Int,
                 settings: RenderSettings, resources: URL) async throws -> Data {
        guard !active else { throw PortError.message("Another photo is still processing") }
        active = true
        defer { active = false }
        var settings = settings; settings.sanitize()
        if resourceDirectory != resources || surfaces == nil {
            surfaces = try MetalFrames(shaderURL: resources.appendingPathComponent("Shaders.metal"))
            renderer = nil; resourceDirectory = resources
        }
        guard let surfaces else { throw PortError.message("Metal initialization failed") }
        let input = try surfaces.allocate(FrameSize(width, height))
        CVPixelBufferLockBaseAddress(input, [])
        let base = CVPixelBufferGetBaseAddress(input)!.assumingMemoryBound(to: UInt8.self)
        let stride = CVPixelBufferGetBytesPerRow(input)
        source.withUnsafeBytes { raw in
            let s = raw.bindMemory(to: UInt8.self)
            for y in 0..<height { for x in 0..<width {
                let a = (y * width + x) * components, b = y * stride + x * 4
                base[b] = s[a+2]; base[b+1] = s[a+1]; base[b+2] = s[a]; base[b+3] = 255
            } }
        }
        CVPixelBufferUnlockBaseAddress(input, [])
        var output = input
        if settings.neuralEnabled && settings.intensity > 0 {
            if renderer == nil {
                renderer = try MLXNeuralRenderingDeviceTemporalBackend(packageURL: resources.appendingPathComponent("NR.dlss"), executionMode: .metalFused, computePrecision: .float16)
            }
            let work = FrameSize(width,height).processing(longEdge: settings.processingLongEdge)
            let small = try await surfaces.resize(input, to: work)
            let rgb = try MLXVideoFrame(pixelBuffer: small)
            let profile = NeuralRenderingControlProfile(rawValue: settings.profile) ?? .natural
            let controls = NeuralRenderingFeatureControls(normalizedStyle: Float(profile.styleIndex) / 128,
                localToneStrength: settings.tone, localStructureStrength: settings.structure,
                automaticMask: settings.advanced.skinEnabled ? NeuralRenderingAutomaticMaskConfiguration(skinStructureStrength: settings.advanced.skin, automaticMaskStructureStrength: settings.advanced.automaticStructure) : nil)
            sequence &+= 1
            let result = try await renderer!.renderVideoFrame(rgb, motion: nil,
                context: NeuralRenderFrameContext(streamID: sequence, frameIndex: 0), processingScale: 1, temporal: false,
                outputOptions: MLXVideoOutputOptions(width: work.width, height: work.height, detailStrength: settings.advanced.detail, colourStrength: settings.advanced.colour, radius: settings.advanced.radius), featureControls: controls, intensity: settings.intensity)
            let writer = try MLXPixelBufferWriter(width: work.width,height: work.height,halfOutput: true)
            let processed = try await writer.write(result)
            output = try await surfaces.composite(original: input,input: small.buffer,processed: processed.buffer,split: 0).buffer
        }
        var rgba = Data(count: width * height * 4)
        CVPixelBufferLockBaseAddress(output, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(output, .readOnly) }
        let pixels = CVPixelBufferGetBaseAddress(output)!.assumingMemoryBound(to: UInt8.self)
        let row = CVPixelBufferGetBytesPerRow(output)
        rgba.withUnsafeMutableBytes { raw in
            let d = raw.bindMemory(to: UInt8.self)
            source.withUnsafeBytes { original in
                let s = original.bindMemory(to: UInt8.self)
                for y in 0..<height { for x in 0..<width {
                    let a = y * row + x * 4, b = (y * width + x) * 4
                    d[b] = pixels[a+2]; d[b+1] = pixels[a+1]; d[b+2] = pixels[a]
                    d[b+3] = components == 4 ? s[b+3] : 255
                } }
            }
        }
        return rgba
    }
}
