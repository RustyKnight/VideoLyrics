// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import LyrixLib

@main
struct VideoLyrics {
    static func main() async throws {
        var mp3Path: String?
        var lrcxPath: String?
        var iter = CommandLine.arguments.dropFirst().makeIterator()
        while let arg = iter.next() {
            switch arg {
            case "--music":  mp3Path  = iter.next()
            case "--lyrics": lrcxPath = iter.next()
            default: break
            }
        }

        let exe = URL(fileURLWithPath: CommandLine.arguments[0]).lastPathComponent
        guard let mp3Path, let lrcxPath else {
            fputs("Usage: \(exe) --music <music.mp3> --lyrics <lyrics.lrcx>\n", stderr)
            exit(1)
        }

        let mp3    = URL(fileURLWithPath: mp3Path)
        let lyrixs = URL(fileURLWithPath: lrcxPath)

        let name  = mp3.deletingPathExtension().lastPathComponent
        let movie = mp3
            .deletingLastPathComponent()
            .appendingPathComponent("\(name)-lyrics")
            .appendingPathExtension("mov")

        let renderer = LyricsVideoRenderer()
        try await renderer.render(lrcx: lyrixs, mp3: mp3, to: movie)
    }
}

