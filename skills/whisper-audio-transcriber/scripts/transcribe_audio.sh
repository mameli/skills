#!/bin/zsh

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  transcribe_audio.sh [--language it|en] [--model /path/to/model.bin] /absolute/path/to/audio

Behavior:
  - creates a timestamped output folder next to the source audio
  - copies the original audio into that folder
  - converts the audio to a Whisper-friendly WAV
  - writes a plain-text transcript

Defaults:
  language: it
  model: --model, then WHISPER_MODEL_PATH, then ggml-medium.bin or another ggml-*.bin in WHISPER_MODEL_DIR
  model directory default: $HOME/.local/share/whisper/models
EOF
}

language="it"
model="${WHISPER_MODEL_PATH:-}"
model_dir="${WHISPER_MODEL_DIR:-$HOME/.local/share/whisper/models}"
audio=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --language|-l)
      [[ $# -ge 2 ]] || { echo "Missing value for $1" >&2; exit 1; }
      language="$2"
      shift 2
      ;;
    --model|-m)
      [[ $# -ge 2 ]] || { echo "Missing value for $1" >&2; exit 1; }
      [[ -n "$2" ]] || { echo "--model requires a nonempty file path" >&2; exit 1; }
      model="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ -n "$audio" ]]; then
        echo "Only one audio file is supported per run" >&2
        exit 1
      fi
      audio="$1"
      shift
      ;;
  esac
done

[[ -n "$audio" ]] || { usage >&2; exit 1; }
[[ -f "$audio" ]] || { echo "Audio file not found: $audio" >&2; exit 1; }

if [[ "$audio" != /* ]]; then
  audio="$(cd "$(dirname "$audio")" && pwd)/$(basename "$audio")"
fi

if [[ "$language" != "it" && "$language" != "en" ]]; then
  echo "Unsupported language: $language (use it or en)" >&2
  exit 1
fi

ffmpeg_bin="$(command -v ffmpeg || true)"
whisper_bin="$(command -v whisper-cli || true)"

[[ -n "$ffmpeg_bin" ]] || { echo "ffmpeg not found in PATH" >&2; exit 1; }
[[ -n "$whisper_bin" ]] || { echo "whisper-cli not found in PATH" >&2; exit 1; }

if [[ -z "$model" ]]; then
  if [[ -f "$model_dir/ggml-medium.bin" ]]; then
    model="$model_dir/ggml-medium.bin"
  else
    for candidate in "$model_dir"/ggml-*.bin(N); do
      if [[ -f "$candidate" ]]; then
        model="$candidate"
        break
      fi
    done
  fi
fi

[[ -n "$model" ]] || { echo "No GGML model found. Pass --model." >&2; exit 1; }
[[ -f "$model" ]] || { echo "Model file not found: $model" >&2; exit 1; }

src_dir="$(dirname "$audio")"
src_name="$(basename "$audio")"
base_name="${src_name%.*}"
ext="${src_name##*.}"
timestamp="$(date '+%Y-%m-%d_%H-%M')"
output_dir="${src_dir}/${timestamp}_${base_name}"

mkdir -p "$output_dir"

copied_audio="${output_dir}/${src_name}"
wav_file="${output_dir}/${base_name}_whisper.wav"
transcript_prefix="${output_dir}/${base_name}_transcript"
transcript_file="${transcript_prefix}.txt"

cp -f "$audio" "$copied_audio"

"$ffmpeg_bin" -y -i "$copied_audio" -ar 16000 -ac 1 -c:a pcm_s16le "$wav_file"
"$whisper_bin" -m "$model" -l "$language" -f "$wav_file" -otxt -of "$transcript_prefix"

cat <<EOF
output_dir=$output_dir
original_audio=$copied_audio
prepared_audio=$wav_file
transcript=$transcript_file
language=$language
model=$model
EOF
