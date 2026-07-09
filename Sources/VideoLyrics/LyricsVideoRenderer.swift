import AVFoundation
import CoreGraphics
import Foundation
import LyrixLib

/// Renders a transparent lyrics overlay video to a `.mov` file (HEVC with alpha).
///
/// ```swift
/// let renderer = LyricsVideoRenderer()          // 1080p @ 24 fps
/// try await renderer.render(lrcx: lrcxURL, mp3: mp3URL, to: outputURL)
/// ```
struct LyricsVideoRenderer {

    let resolution: VideoResolution
    let fps: FPS

    init(resolution: VideoResolution = .p1080, fps: FPS = .fps24) {
        self.resolution = resolution
        self.fps = fps
    }

    // MARK: - Public API

    /// Renders a transparent lyrics overlay video to `outputURL`.
    ///
    /// - Parameters:
    ///   - lrcxURL:   URL of the LRCX lyrics file (local or remote).
    ///   - mp3URL:    URL of the MP3 audio file; determines video duration.
    ///   - outputURL: Destination `.mov` file path (overwritten if it exists).
    func render(lrcx lrcxURL: URL, mp3 mp3URL: URL, to outputURL: URL) async throws {
        let size       = resolution.size
        let doc        = try LyrixParser().parse(contentsOf: lrcxURL)
        let duration   = try await audioDuration(of: mp3URL)
        let totalFrames = fps.totalFrames(for: duration)

        print("Rendering \(totalFrames) frames at \(Int(size.width))×\(Int(size.height)) \(fps.value) fps…")

        let writer           = try makeWriter(outputURL: outputURL, size: size)
        let (input, adaptor) = makeInputAndAdaptor(size: size, writer: writer)

        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let pool           = try makePixelBufferPool(size: size)
        let frameRenderer  = LyricsFrameRenderer()
        let progressStep   = max(totalFrames / 20, 1)  // log every ~5%
        let sampleLeadMs   = Int((500.0 / fps.value).rounded()) // half-frame lead for tighter sync

        for frame in 0..<totalFrames {
            while !input.isReadyForMoreMediaData { await Task.yield() }

            let ms        = fps.milliseconds(for: frame)
            let sampleMs  = ms + sampleLeadMs
            let line      = doc.isLyricsSilent(at: sampleMs) ? nil : doc.activeLine(at: sampleMs)
            let buffer = try makePixelBuffer(from: pool)

            renderFrame(frameRenderer: frameRenderer, line: line, at: sampleMs, into: buffer, size: size)

            let presentationTime = CMTime(value: CMTimeValue(ms), timescale: 1000)
            adaptor.append(buffer, withPresentationTime: presentationTime)

            if frame % progressStep == 0 {
                let pct = Int(Double(frame) / Double(totalFrames) * 100)
                print("  \(pct)% (\(frame)/\(totalFrames))")
            }
        }

        input.markAsFinished()
        await writer.finishWriting()

        guard writer.status == .completed else {
            throw writer.error ?? CocoaError(.fileWriteUnknown)
        }

        print("✅ Video written to \(outputURL.path)")
    }

    // MARK: - AVFoundation setup

    private func makeWriter(outputURL: URL, size: CGSize) throws -> AVAssetWriter {
        try? FileManager.default.removeItem(at: outputURL)
        return try AVAssetWriter(outputURL: outputURL, fileType: .mov)
    }

    private func makeInputAndAdaptor(
        size: CGSize,
        writer: AVAssetWriter
    ) -> (AVAssetWriterInput, AVAssetWriterInputPixelBufferAdaptor) {
        let videoSettings: [String: Any] = [
            AVVideoCodecKey:  AVVideoCodecType.hevcWithAlpha,
            AVVideoWidthKey:  Int(size.width),
            AVVideoHeightKey: Int(size.height),
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey  as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height),
            ]
        )
        writer.add(input)
        return (input, adaptor)
    }

    // MARK: - Pixel buffer helpers

    private func makePixelBufferPool(size: CGSize) throws -> CVPixelBufferPool {
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey          as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey                    as String: Int(size.width),
            kCVPixelBufferHeightKey                   as String: Int(size.height),
            kCVPixelBufferCGImageCompatibilityKey     as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]
        var pool: CVPixelBufferPool?
        let status = CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attrs as CFDictionary, &pool)
        guard status == kCVReturnSuccess, let pool else {
            throw CocoaError(.fileWriteUnknown)
        }
        return pool
    }

    private func makePixelBuffer(from pool: CVPixelBufferPool) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer)
        guard status == kCVReturnSuccess, let buffer else {
            throw CocoaError(.fileWriteUnknown)
        }
        return buffer
    }

    // MARK: - Frame rendering

    private func renderFrame(
        frameRenderer: LyricsFrameRenderer,
        line:          LyrixLine?,
        at milliseconds: Int,
        into buffer:   CVPixelBuffer,
        size:          CGSize
    ) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else { return }

        guard let context = CGContext(
            data:           baseAddress,
            width:          Int(size.width),
            height:         Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow:    CVPixelBufferGetBytesPerRow(buffer),
            space:          CGColorSpaceCreateDeviceRGB(),
            bitmapInfo:     CGImageAlphaInfo.premultipliedFirst.rawValue
                            | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return }

        frameRenderer.render(line: line, at: milliseconds, into: context, size: size)
    }
}
