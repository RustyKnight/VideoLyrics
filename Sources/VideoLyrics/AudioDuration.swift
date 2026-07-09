import AVFoundation

/// Returns the duration of an audio file at the given URL.
/// - Throws: If the asset cannot be loaded or duration is unavailable.
func audioDuration(of url: URL) async throws -> Duration {
    let asset = AVURLAsset(url: url)
    let cmDuration = try await asset.load(.duration)
    let seconds = CMTimeGetSeconds(cmDuration)
    guard seconds.isFinite else {
        throw CocoaError(.fileReadCorruptFile)
    }
    return .seconds(seconds)
}
