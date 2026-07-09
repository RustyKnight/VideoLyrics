import CoreGraphics
import Foundation
import LyrixLib
import Testing
@testable import VideoLyrics

// MARK: - Helpers

private let testSize = CGSize(width: 4, height: 4)

/// Creates a small RGBA CGContext pre-filled with opaque white (0xFF bytes) and
/// passes it to `body` together with the raw backing buffer for inspection.
private func withTestContext(_ body: (CGContext, UnsafeMutableBufferPointer<UInt8>) -> Void) {
    let w = 4, h = 4, bytesPerRow = w * 4
    let count = bytesPerRow * h
    let raw = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
    defer { raw.deallocate() }
    raw.initialize(repeating: 0xFF, count: count)  // dirty sentinel: opaque white

    guard let ctx = CGContext(
        data:               raw,
        width:              w,
        height:             h,
        bitsPerComponent:   8,
        bytesPerRow:        bytesPerRow,
        space:              CGColorSpaceCreateDeviceRGB(),
        bitmapInfo:         CGBitmapInfo.byteOrder32Big.rawValue
                            | CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        Issue.record("Failed to create test CGContext")
        return
    }

    body(ctx, UnsafeMutableBufferPointer(start: raw, count: count))
}

/// Returns `true` when every byte in the buffer is 0 (fully transparent black — the
/// result of `CGContext.clear()`).
private func isBlankFrame(_ buf: UnsafeMutableBufferPointer<UInt8>) -> Bool {
    buf.allSatisfy { $0 == 0 }
}

// MARK: - Tests

@Suite("LyricsFrameRenderer blank-frame handling")
struct LyricsFrameRendererBlankFrameTests {

    let renderer = LyricsFrameRenderer()

    /// A `nil` line means no active lyric (pre-song, between lines, or after a silent
    /// period). The renderer must produce a fully transparent frame.
    @Test("nil line produces a fully transparent frame")
    func nilLineProducesBlankFrame() {
        withTestContext { ctx, buf in
            renderer.render(line: nil, at: 0, into: ctx, size: testSize)
            #expect(isBlankFrame(buf), "nil line should produce a fully transparent frame")
        }
    }

    /// An instrumental break is a `LyrixLine` with no ruby segments and no word
    /// segments (`isInstrumentalBreak == true`). The renderer must skip drawing and
    /// leave a fully transparent frame so the background video shows through.
    @Test("instrumental break (no words, no ruby) produces a fully transparent frame")
    func instrumentalBreakProducesBlankFrame() {
        let instrumental = LyrixLine(timestamp: 1000, rubySegments: [], words: [])
        #expect(instrumental.isInstrumentalBreak, "precondition: LyrixLine must be an instrumental break")

        withTestContext { ctx, buf in
            renderer.render(line: instrumental, at: 1000, into: ctx, size: testSize)
            #expect(isBlankFrame(buf), "instrumental break should produce a fully transparent frame")
        }
    }

    /// A line whose `displayText` resolves to an empty string (e.g. a word segment
    /// that carries no ruby base text) must also render as blank. This guards the
    /// third early-exit path in the renderer: `guard !text.isEmpty`.
    @Test("line with empty display text produces a fully transparent frame")
    func emptyDisplayTextProducesBlankFrame() {
        // A WordSegment with no RubySegments has displayText == "".
        // words is non-empty → isInstrumentalBreak is false, but displayText is still "".
        let emptyWord = WordSegment(timestamp: 0, rubySegments: [])
        let line = LyrixLine(timestamp: 0, rubySegments: [], words: [emptyWord])

        #expect(!line.isInstrumentalBreak, "precondition: words is non-empty so this is not an instrumental break")
        #expect(line.displayText.isEmpty, "precondition: all words have empty text so displayText must be empty")

        withTestContext { ctx, buf in
            renderer.render(line: line, at: 0, into: ctx, size: testSize)
            #expect(isBlankFrame(buf), "empty display text should produce a fully transparent frame")
        }
    }
}
