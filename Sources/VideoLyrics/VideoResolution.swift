import CoreGraphics

/// Common video resolutions for lyrics video export.
enum VideoResolution {
    /// 1280 × 720 (HD)
    case p720
    /// 1920 × 1080 (Full HD) — default
    case p1080
    /// 2560 × 1440 (Quad HD)
    case p1440
    /// 3840 × 2160 (4K UHD)
    case p4K

    /// Explicit pixel dimensions.
    case custom(width: Int, height: Int)
    /// Width is fixed; height is derived from `width / aspectRatio` (aspect ratio = width ÷ height).
    case customWidth(_ width: Int, aspectRatio: Double)
    /// Height is fixed; width is derived from `height * aspectRatio` (aspect ratio = width ÷ height).
    case customHeight(_ height: Int, aspectRatio: Double)

    /// Pixel dimensions of this resolution.
    var size: CGSize {
        switch self {
        case .p720:  return CGSize(width: 1280, height: 720)
        case .p1080: return CGSize(width: 1920, height: 1080)
        case .p1440: return CGSize(width: 2560, height: 1440)
        case .p4K:   return CGSize(width: 3840, height: 2160)
        case .custom(let w, let h):
            return CGSize(width: w, height: h)
        case .customWidth(let w, let ratio):
            return CGSize(width: CGFloat(w), height: (CGFloat(w) / CGFloat(ratio)).rounded())
        case .customHeight(let h, let ratio):
            return CGSize(width: (CGFloat(h) * CGFloat(ratio)).rounded(), height: CGFloat(h))
        }
    }
}
