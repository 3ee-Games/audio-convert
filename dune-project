(lang dune 3.20)

(name audio_convert)

(generate_opam_files true)

(source
 (github 3ee-Games/audio-convert))

(authors "Ryan Sadwick <rsadwick@gmail.com>")

(maintainers "Ryan Sadwick <rsadwick@gmail.com>")

(license MIT)

(documentation https://github.com/3ee-Games/audio-convert/#readme)

(package
 (name audio_convert)
 (synopsis "A CLI tool to convert audio files to MP3 and OGG")
 (description
  "A OCaml command-line utility that converts common audio formats (WAV, AIFF, FLAC) to MP3 and OGG using system ffmpeg, with optional silence trimming. Dependency-light: only stdlib and unix.")
 (depends
  (ocaml (>= 5.0))
  (dune (>= 3.20))
  unix)
 (tags
  ("ocaml" "audio" "converter" "cli" "ffmpeg", "gamedev")))