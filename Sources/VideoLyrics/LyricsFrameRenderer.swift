import CoreGraphics
import CoreText
import Foundation
import LyrixLib

/// Renders a single lyrics frame onto a CGContext backed by a pixel buffer.
///
/// All dimensional constants are specified at a 1080p baseline and scaled
/// proportionally to the actual canvas height.
struct LyricsFrameRenderer {

    // MARK: - Constants (1080p baseline)

    /// Font point size at 1080p.
    private static let baseFontSize: CGFloat = 48
    /// Reference height for all scale calculations.
    private static let baseHeight: CGFloat = 1080
    /// Horizontal safe inset from each edge at 1080p.
    private static let baseSafeH: CGFloat = 60
    /// Bottom safe inset at 1080p.
    private static let baseSafeB: CGFloat = 80
    /// Stroke pass line-width at 1080p. The fill pass then covers the inner half,
    /// leaving an effective outline of ~half this value.
    private static let baseStroke: CGFloat = 6
    /// Padding around the text block inside the progress fill capsule at 1080p.
    private static let baseBarPad: CGFloat = 14

    private static let fontName = "Arial Rounded MT Bold"

    // MARK: - Public API

    /// Renders `line` at the given `milliseconds` into `context`.
    ///
    /// Always starts with a fully transparent clear. Draws nothing for `nil` lines,
    /// instrumental breaks, or empty text.
    func render(line: LyrixLine?, at milliseconds: Int, into context: CGContext, size: CGSize) {
        context.clear(CGRect(origin: .zero, size: size))

        guard let line, !line.isInstrumentalBreak else { return }
        let text = line.displayText
        guard !text.isEmpty else { return }

        if let progress = resolveProgress(line: line, at: milliseconds) {
            let highlightCount = resolveHighlightCount(line: line, at: milliseconds)
            drawLyricWithProgressFill(text: text, progress: progress, highlightCount: highlightCount, into: context, size: size)
        } else {
            let highlightCount = resolveHighlightCount(line: line, at: milliseconds)
            drawLyric(text: text, highlightCount: highlightCount, into: context, size: size)
        }
    }

    // MARK: - Progress resolution

    /// Returns a 0–1 progress value when the line carries an explicit duration,
    /// or `nil` when progress-fill is not supported (falls back to character/word highlight).
    private func resolveProgress(line: LyrixLine, at milliseconds: Int) -> Double? {
        guard let duration = line.lineDurationMilliseconds, duration > 0 else { return nil }
        let elapsed = milliseconds - line.timestamp
        return min(max(Double(elapsed) / Double(duration), 0.0), 1.0)
    }

    // MARK: - Highlight resolution

    private func resolveHighlightCount(line: LyrixLine, at milliseconds: Int) -> Int {
        let wordCount = highlightedWordCount(line: line, at: milliseconds)
        guard !line.characterTiming.isEmpty else { return wordCount }

        let charCount = line.highlightedCharacterCount(atOffset: milliseconds - line.timestamp)

        // Only blend with word-level timing when words carry independent per-word timestamps.
        // Files that batch all words at line.timestamp rely solely on [tt] for progression;
        // taking max() there would immediately highlight the whole line on the first frame.
        let contentWords = line.words.filter { !$0.displayText.isEmpty }
        let hasIndependentWordTiming = contentWords.dropFirst().contains { $0.timestamp > line.timestamp }

        return hasIndependentWordTiming ? max(charCount, wordCount) : charCount
    }

    private func highlightedWordCount(line: LyrixLine, at milliseconds: Int) -> Int {
        guard !line.words.isEmpty else { return 0 }
        var total = 0
        for word in line.words where word.timestamp <= milliseconds {
            let count = word.displayText.count
            total += word.isUnfill ? -count : count
        }
        return max(total, 0)
    }

    // MARK: - Per-frame drawing

    private func drawLyric(text: String, highlightCount: Int, into context: CGContext, size: CGSize) {
        let scale       = size.height / Self.baseHeight
        let fontSize    = Self.baseFontSize * scale
        let safeH       = Self.baseSafeH    * scale
        let safeB       = Self.baseSafeB    * scale
        let strokeWidth = Self.baseStroke   * scale
        let textWidth   = size.width - safeH * 2

        let font           = CTFontCreateWithName(Self.fontName as CFString, fontSize, nil)
        let paragraphStyle = makeParagraphStyle()
        let attrString     = makeAttributedString(
            text:           text,
            highlightCount: highlightCount,
            font:           font,
            paragraphStyle: paragraphStyle
        )

        let framesetter = CTFramesetterCreateWithAttributedString(attrString as CFAttributedString)
        let textSize = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRangeMake(0, 0),
            nil,
            CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            nil
        )

        // Pixel-buffer backed CGBitmap contexts are already in bottom-left
        // coordinate space for Core Text. Keep identity transforms to avoid
        // mirrored / upside-down glyph output.
        context.saveGState()
        context.textMatrix = .identity

        // Place text so its bottom edge sits safeB pixels above the frame bottom.
        let frameRect = CGRect(
            x:      safeH,
            y:      safeB,
            width:  textWidth,
            height: textSize.height + fontSize * 0.25  // padding for descenders
        )
        let framePath = CGPath(rect: frameRect, transform: nil)

        // — Pass 1: black stroke outline —
        // Drawing in stroke mode with a wide line produces an outline.
        // The fill pass on top covers the interior, so only the outer edge is visible.
        context.saveGState()
        context.setTextDrawingMode(.stroke)
        context.setStrokeColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
        context.setLineWidth(strokeWidth)
        context.setLineJoin(.round)
        let strokeFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), framePath, nil)
        CTFrameDraw(strokeFrame, context)
        context.restoreGState()

        // — Pass 2: colored fill (white / translucent red) —
        context.saveGState()
        context.setTextDrawingMode(.fill)
        let fillFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), framePath, nil)
        CTFrameDraw(fillFrame, context)
        context.restoreGState()

        context.restoreGState()
    }

    private func drawLyricWithProgressFill(text: String, progress: Double, highlightCount: Int, into context: CGContext, size: CGSize) {
        let scale       = size.height / Self.baseHeight
        let fontSize    = Self.baseFontSize * scale
        let safeH       = Self.baseSafeH    * scale
        let safeB       = Self.baseSafeB    * scale
        let strokeWidth = Self.baseStroke   * scale
        let pad         = Self.baseBarPad   * scale
        let textWidth   = size.width - safeH * 2

        let font           = CTFontCreateWithName(Self.fontName as CFString, fontSize, nil)
        let paragraphStyle = makeParagraphStyle()
        let attrString     = makeAttributedString(
            text:           text,
            highlightCount: highlightCount,
            font:           font,
            paragraphStyle: paragraphStyle
        )

        let framesetter = CTFramesetterCreateWithAttributedString(attrString as CFAttributedString)
        let textSize = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRangeMake(0, 0),
            nil,
            CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            nil
        )

        context.saveGState()
        context.textMatrix = .identity

        let frameRect = CGRect(
            x:      safeH,
            y:      safeB,
            width:  textWidth,
            height: textSize.height + fontSize * 0.25
        )
        let framePath = CGPath(rect: frameRect, transform: nil)

        // — Pass 1: progress fill capsule (behind text) —
        // Sized to the actual rendered text width (centred in the safe area) + padding on all sides,
        // growing left→right with progress.
        let capsuleFullWidth = textSize.width + pad * 2
        let capsuleHeight    = frameRect.height + pad * 2
        let capsuleX         = safeH + (textWidth - textSize.width) / 2 - pad
        let capsuleY         = safeB - pad
        let fillWidth        = capsuleFullWidth * CGFloat(progress)
        if fillWidth > 0 {
            let cornerR = capsuleHeight / 4
            // Clip to the growing fill region so corners are correct at any progress.
            context.saveGState()
            context.clip(to: CGRect(x: capsuleX, y: capsuleY, width: fillWidth, height: capsuleHeight))
            let capsuleRect = CGRect(x: capsuleX, y: capsuleY, width: capsuleFullWidth, height: capsuleHeight)
            context.setFillColor(CGColor(srgbRed: 0.9, green: 0.1, blue: 0.1, alpha: 0.8))
            context.addPath(CGPath(roundedRect: capsuleRect, cornerWidth: cornerR, cornerHeight: cornerR, transform: nil))
            context.fillPath()
            context.restoreGState()
        }

        // — Pass 2: black stroke outline —
        context.saveGState()
        context.setTextDrawingMode(.stroke)
        context.setStrokeColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
        context.setLineWidth(strokeWidth)
        context.setLineJoin(.round)
        let strokeFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), framePath, nil)
        CTFrameDraw(strokeFrame, context)
        context.restoreGState()

        // — Pass 3: white text fill —
        context.saveGState()
        context.setTextDrawingMode(.fill)
        let fillFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), framePath, nil)
        CTFrameDraw(fillFrame, context)
        context.restoreGState()

        context.restoreGState()
    }

    // MARK: - Paragraph style

    private func makeParagraphStyle() -> CTParagraphStyle {
        var alignment = CTTextAlignment.center
        var lineBreak = CTLineBreakMode.byWordWrapping
        return withUnsafeBytes(of: &alignment) { alignPtr in
            withUnsafeBytes(of: &lineBreak) { breakPtr in
                let settings: [CTParagraphStyleSetting] = [
                    CTParagraphStyleSetting(
                        spec:      .alignment,
                        valueSize: MemoryLayout<CTTextAlignment>.size,
                        value:     alignPtr.baseAddress!
                    ),
                    CTParagraphStyleSetting(
                        spec:      .lineBreakMode,
                        valueSize: MemoryLayout<CTLineBreakMode>.size,
                        value:     breakPtr.baseAddress!
                    ),
                ]
                return CTParagraphStyleCreate(settings, settings.count)
            }
        }
    }

    // MARK: - Attributed string

    private func makeAttributedString(
        text:           String,
        highlightCount: Int,
        font:           CTFont,
        paragraphStyle: CTParagraphStyle
    ) -> NSAttributedString {
        let white = CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        let red   = CGColor(srgbRed: 0.9, green: 0.1, blue: 0.1, alpha: 0.8)

        func attrs(_ color: CGColor) -> [NSAttributedString.Key: Any] {
            [
                kCTFontAttributeName            as NSAttributedString.Key: font,
                kCTForegroundColorAttributeName as NSAttributedString.Key: color,
                kCTParagraphStyleAttributeName  as NSAttributedString.Key: paragraphStyle,
            ]
        }

        let result = NSMutableAttributedString()
        let clamp  = min(max(highlightCount, 0), text.count)

        if clamp > 0 {
            let end = text.index(text.startIndex, offsetBy: clamp)
            result.append(NSAttributedString(string: String(text[..<end]), attributes: attrs(red)))
        }
        if clamp < text.count {
            let start = text.index(text.startIndex, offsetBy: clamp)
            result.append(NSAttributedString(string: String(text[start...]), attributes: attrs(white)))
        }

        return result
    }
}
