#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 2 ]]; then
  echo "Usage: $0 <youtube-url> <output-dir>" >&2
  exit 1
fi

if ! command -v yt-dlp >/dev/null 2>&1; then
  echo "yt-dlp is required but not installed or not on PATH." >&2
  exit 1
fi

if ! command -v ruby >/dev/null 2>&1; then
  echo "ruby is required but not installed or not on PATH." >&2
  exit 1
fi

URL="$1"
OUT_DIR="$2"

mkdir -p "$OUT_DIR"

WORK_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

INFO_JSON="$WORK_DIR/info.json"

yt-dlp --dump-single-json --no-warnings --skip-download "$URL" > "$INFO_JSON"

ruby -rjson -e '
  data = JSON.parse(File.read(ARGV[0]))
  out_dir = ARGV[1]

  def write_file(path, value)
    File.write(path, value.to_s.gsub("\r", ""))
  end

  def ordered_candidates(manual, auto)
    manual ||= {}
    auto ||= {}
    priority = ["it", "it-IT", "en", "en-US", "en-GB"]
    candidates = []

    priority.each do |lang|
      candidates << ["manual", lang] if manual.key?(lang)
    end
    priority.each do |lang|
      candidates << ["auto", lang] if auto.key?(lang)
    end

    manual.keys.sort.each do |lang|
      pair = ["manual", lang]
      candidates << pair unless candidates.include?(pair)
    end
    auto.keys.sort.each do |lang|
      pair = ["auto", lang]
      candidates << pair unless candidates.include?(pair)
    end

    candidates
  end

  write_file(File.join(out_dir, "id.txt"), data["id"])
  write_file(File.join(out_dir, "title.txt"), data["title"])
  write_file(File.join(out_dir, "channel.txt"), data["channel"] || data["uploader"] || "")
  write_file(File.join(out_dir, "upload_date.txt"), data["upload_date"] || "")
  write_file(File.join(out_dir, "description.txt"), data["description"] || "")
  write_file(File.join(out_dir, "webpage_url.txt"), data["webpage_url"] || "")

  candidates = ordered_candidates(data["subtitles"], data["automatic_captions"])
  File.write(
    File.join(out_dir, "candidates.txt"),
    candidates.map { |source, lang| "#{source}\t#{lang}" }.join("\n")
  )
' "$INFO_JSON" "$WORK_DIR"

VIDEO_ID="$(<"$WORK_DIR/id.txt")"
TITLE="$(<"$WORK_DIR/title.txt")"
CHANNEL="$(<"$WORK_DIR/channel.txt")"
UPLOAD_DATE_RAW="$(<"$WORK_DIR/upload_date.txt")"
DESCRIPTION="$(<"$WORK_DIR/description.txt")"
WEBPAGE_URL="$(<"$WORK_DIR/webpage_url.txt")"

SUB_LANG=""
SUB_SOURCE=""

if [[ -z "$WEBPAGE_URL" ]]; then
  WEBPAGE_URL="$URL"
fi

if [[ -s "$WORK_DIR/candidates.txt" ]]; then
  while IFS=$'\t' read -r candidate_source candidate_lang; do
    [[ -n "$candidate_source" && -n "$candidate_lang" ]] || continue
    rm -f "$WORK_DIR/${VIDEO_ID}."*.srt 2>/dev/null || true
    pushd "$WORK_DIR" >/dev/null
    if [[ "$candidate_source" == "manual" ]]; then
      if yt-dlp --skip-download --no-warnings --write-subs --sub-langs "$candidate_lang" --sub-format srt -o "%(id)s.%(ext)s" "$URL" >/dev/null 2>&1; then
        SUB_SOURCE="$candidate_source"
        SUB_LANG="$candidate_lang"
        popd >/dev/null
        break
      fi
    else
      if yt-dlp --skip-download --no-warnings --write-auto-subs --sub-langs "$candidate_lang" --sub-format srt -o "%(id)s.%(ext)s" "$URL" >/dev/null 2>&1; then
        SUB_SOURCE="$candidate_source"
        SUB_LANG="$candidate_lang"
        popd >/dev/null
        break
      fi
    fi
    popd >/dev/null
  done < "$WORK_DIR/candidates.txt"
fi

UPLOAD_DATE_FMT=""
if [[ -n "$UPLOAD_DATE_RAW" && "$UPLOAD_DATE_RAW" =~ ^[0-9]{8}$ ]]; then
  UPLOAD_DATE_FMT="${UPLOAD_DATE_RAW:0:4}-${UPLOAD_DATE_RAW:4:2}-${UPLOAD_DATE_RAW:6:2}"
fi

SUBTITLE_FILE="$WORK_DIR/${VIDEO_ID}.${SUB_LANG}.srt"
TRANSCRIPT_TXT="$OUT_DIR/transcript.txt"
MANIFEST_JSON="$OUT_DIR/manifest.json"

ruby - "$TRANSCRIPT_TXT" "$MANIFEST_JSON" "$VIDEO_ID" "$TITLE" "$WEBPAGE_URL" "$CHANNEL" "$UPLOAD_DATE_FMT" "$DESCRIPTION" "$SUB_LANG" "$SUB_SOURCE" "$SUBTITLE_FILE" <<'RUBY'
require "json"

transcript_txt, manifest_json, video_id, title, source_url, channel, published, description, sub_lang, sub_source, subtitle_file = ARGV

def paragraphize_srt(path)
  return nil unless File.exist?(path)

  lines = File.readlines(path, chomp: true)
  content = lines.reject do |line|
    line =~ /^\d+$/ || line =~ /^\d{2}:\d{2}:\d{2},\d{3} --> / || line.strip.empty?
  end

  text = content.join(" ")
  text.gsub!(/\s+([,.;:?!])/, '\1')
  text.gsub!(/\s+/, " ")
  text.strip!
  text.gsub!(/([.!?])\s+/, "\\1\n\n")
  text
end

transcript = paragraphize_srt(subtitle_file)
File.write(transcript_txt, transcript.to_s)

manifest = {
  id: video_id,
  title: title,
  source_url: source_url,
  channel: channel,
  published: published,
  description: description,
  transcript_language: sub_lang,
  transcript_source: sub_source,
  transcript_available: !transcript.to_s.empty?,
  transcript_path: transcript_txt
}

File.write(manifest_json, JSON.pretty_generate(manifest))
puts manifest_json
RUBY
