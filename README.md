# Audio Convert

A OCaml CLI tool to convert audio files (.wav, .aif, .aiff, .flac) to .mp3 and .ogg using ffmpeg, with optional silence trimming.

## Requirements

- OCaml
- Dune
- System `ffmpeg` with `libmp3lame` and `libvorbis` encoders enabled

ffmpeg: System-installed with libmp3lame and libvorbis encoders enabled. Install via package manager:

- macOS: `brew install ffmpeg`
- Ubuntu/Debian: `apt install ffmpeg libmp3lame0 libvorbisenc2`
- Windows: Download from [ffmpeg.org](https://ffmpeg.org) and add to PATH.

## Installation

```sh
opam install . --deps-only
```

```sh
dune build
```

## Command-line Options

| Flag | Description | Default          |
|------|--------------|-----------------|
| `-i, --input` | Input file or directory (recursive if dir) | **Required** |
| `-o, --output` | Output directory (mirrors structure); if omitted, write next to inputs | Optional |
| `--quality {low\|medium\|high\|insane}` | Quality preset | `high` |
| `--mp3-bitrate <kbps>` | Overrides preset for MP3 (e.g., `192`) | Optional, uses preset if not set |
| `--ogg-quality` | Overrides preset for OGG Vorbis (int `-1..10`; e.g., `5`) | Optional, uses preset if not set |
| `--trim-silence` | Enable silence removal (lead & tail) | Disabled |
| `--silence-threshold <dB>` | Silence threshold | `-50` |
| `--silence-min-ms` | Min silence duration (milliseconds) | `200` |
| `--force` | Overwrite existing outputs | Disabled |
| `--dry-run` | Print planned work, do not write | Disabled |
| `-v, --verbose` | More logs | Disabled |
| `-h, --help` | Show help | – |


## Examples

#### Single file

```sh
dune exec audio-convert -- -i samples/test.wav --quality high --trim-silence
```

#### Convert an entire directory

```sh
dune exec audio-convert -- -i ./audio_files -o ./out --quality medium
```

#### Overrides

```sh
dune exec audio-convert -- -i voice.wav --mp3-bitrate 192 --ogg-quality 5
```

#### Dry run

```sh
dune exec audio-convert -- -i ./in --dry-run
```

- silence-threshold <dB>: Threshold below which audio is considered silence (default: -50).
- silence-min-ms <ms>: Minimum duration of silence to trim (default: 200).