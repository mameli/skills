---
name: whisper-audio-transcriber
description: Transcribe local audio to plain text with whisper-cpp; default language is Italian.
---

# Local audio transcription

Run `zsh scripts/transcribe_audio.sh "audio-path"` from this skill directory. Default to Italian; use `--language en` when the user specifies English. Respect another supported language when explicitly requested.

The helper requires `ffmpeg`, `whisper-cli` and a local GGML model. It uses `$WHISPER_MODEL_PATH` when present; `--model "model-path"` overrides it.

The helper creates `YYYY-MM-DD_HH-MM_file-name/` beside the source, containing a copy of the original, a mono 16 kHz PCM WAV and `*_transcript.txt`. Keep generated files there even for WAV input. Preserve the source.

Verify successful completion and a usable transcript, then return the transcript and output-folder links. Produce subtitles only when requested.

## Local configuration

Run the helper with `zsh` or directly via its shebang, not `bash`. Model precedence is `--model`, then `WHISPER_MODEL_PATH`, then a model in `WHISPER_MODEL_DIR` (default `$HOME/.local/share/whisper/models`). Prefer `ggml-medium.bin`, then an available `ggml-*.bin`. Do not assume a particular user home or model installation.
