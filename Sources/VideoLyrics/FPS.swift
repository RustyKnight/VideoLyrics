import Foundation

/// Common frame rates used in TV and film production.
enum FPS {
    case fps23_976
    case fps24
    case fps25
    case fps29_97
    case fps30
    case fps48
    case fps50
    case fps59_94
    case fps60
    case fps120
    case custom(Double)

    /// The numeric frame rate value.
    var value: Double {
        switch self {
        case .fps23_976:      return 23.976
        case .fps24:          return 24.0
        case .fps25:          return 25.0
        case .fps29_97:       return 29.97
        case .fps30:          return 30.0
        case .fps48:          return 48.0
        case .fps50:          return 50.0
        case .fps59_94:       return 59.94
        case .fps60:          return 60.0
        case .fps120:         return 120.0
        case .custom(let v):  return v
        }
    }

    /// All named (non-custom) frame rates.
    static let allCommon: [FPS] = [
        .fps23_976, .fps24, .fps25, .fps29_97, .fps30,
        .fps48, .fps50, .fps59_94, .fps60, .fps120
    ]

    /// Total number of frames for a given duration.
    func totalFrames(for duration: Duration) -> Int {
        let seconds = Double(duration.components.seconds) +
                      Double(duration.components.attoseconds) * 1e-18
        return Int((seconds * value).rounded())
    }

    /// Time in milliseconds at the start of the given frame number (zero-based).
    func milliseconds(for frame: Int) -> Int {
        Int((Double(frame) / value * 1000.0).rounded())
    }
}
