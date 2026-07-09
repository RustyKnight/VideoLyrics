# VideoLyrics

A macOS command-line tool that generates a **transparent lyrics overlay video** (`.mov`) from an MP3 audio file and an LRCX lyrics file. The output is designed to be composited over a background in a video editor such as Final Cut Pro or DaVinci Resolve.

## AI

<img src=".assets/github-copilot-icon.svg" alt="GitHub Copilot" width="128" height="128">

This project is AI implementation of a pre-existing project intended to help improve one some of core features I felt were missing from the original.

It "mostly" works, but it's not perfect.

## Features

- Renders lyrics as white text with a black stroke outline for legibility over any background
- Karaoke-style character highlighting in translucent red, driven by `[tt]` character-timing data in LRCX files, with word-level fallback
- Transparent background (HEVC with alpha channel) — drop it directly onto a timeline
- Video duration matches the MP3 exactly
- Silent periods, instrumental breaks, and empty lines render as fully transparent frames
- Text is bottom-aligned, centre-aligned horizontally, with word-wrapping and safe-area insets
- Font: **Arial Rounded MT Bold** at 48 pt (scaled proportionally to resolution)

## Requirements

- macOS 13 or later
- Swift 6.3+

## Building

```bash
swift build -c release
```

The compiled binary is placed at `.build/release/VideoLyrics`.

## Usage

```bash
VideoLyrics --music <path/to/song.mp3> --lyrics <path/to/song.lrcx>
```

Both flags are required. The output `.mov` is written to the same directory as the MP3, named `<song>-lyrics.mov`.

### Example

```bash
VideoLyrics --music "Adele - Skyfall.mp3" --lyrics "Adele - Skyfall.lrcx"
# Writes: Adele - Skyfall-lyrics.mov
```

## Output Format

| Property   | Value                        |
|------------|------------------------------|
| Container  | QuickTime Movie (`.mov`)     |
| Video codec | HEVC with Alpha             |
| Default resolution | 1920 × 1080 (1080p)  |
| Default frame rate | 24 fps               |
| Alpha      | Premultiplied, fully transparent background |

## Supported Resolutions

Defined by the `VideoResolution` enum:

| Case | Dimensions |
|------|-----------|
| `.p720`  | 1280 × 720  |
| `.p1080` | 1920 × 1080 (default) |
| `.p1440` | 2560 × 1440 |
| `.p4K`   | 3840 × 2160 |
| `.custom(width:height:)` | Explicit dimensions |
| `.customWidth(_:aspectRatio:)` | Height derived from width ÷ ratio |
| `.customHeight(_:aspectRatio:)` | Width derived from height × ratio |

## Supported Frame Rates

Defined by the `FPS` enum: `fps23_976`, `fps24` (default), `fps25`, `fps29_97`, `fps30`, `fps48`, `fps50`, `fps59_94`, `fps60`, `fps120`, and `.custom(Double)`.

## LRCX Support

VideoLyrics reads standard [LRCX](https://github.com/nicholasvadasz/lrcx) files including:

- Line-level timestamps (`[mm:ss.xx]`)
- Word-level karaoke timestamps (`[mm:ss.xx]word`)
- Character-timing highlight sequences (`[tt]<offset,count>…`)
- Metadata tags: `[ti:]`, `[ar:]`, `[al:]`, `[length:]`, `[offset:]`, etc.
- Instrumental break lines (rendered as silence)

The `[length:]` tag is validated against the MP3 duration (within a 1-second tolerance) before rendering begins.

## Dependencies

- [LyrixLib](https://github.com/RustyKnight/LyrixLib) — Swift package for LRC/LRCX parsing
