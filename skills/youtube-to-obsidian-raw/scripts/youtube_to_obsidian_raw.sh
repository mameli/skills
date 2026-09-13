#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <youtube-url> [vault-root]" >&2
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
VAULT_ROOT="${2:-$PWD}"
RAW_DIR="${VAULT_ROOT}/_Wiki/raw"

if [[ ! -d "$RAW_DIR" ]]; then
  echo "Target folder not found: $RAW_DIR" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

INFO_JSON="$TMP_DIR/info.json"

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
' "$INFO_JSON" "$TMP_DIR"

VIDEO_ID="$(<"$TMP_DIR/id.txt")"
TITLE="$(<"$TMP_DIR/title.txt")"
CHANNEL="$(<"$TMP_DIR/channel.txt")"
UPLOAD_DATE_RAW="$(<"$TMP_DIR/upload_date.txt")"
DESCRIPTION="$(<"$TMP_DIR/description.txt")"
WEBPAGE_URL="$(<"$TMP_DIR/webpage_url.txt")"

SUB_LANG=""
SUB_SOURCE=""

if [[ -z "$WEBPAGE_URL" ]]; then
  WEBPAGE_URL="$URL"
fi

if [[ -s "$TMP_DIR/candidates.txt" ]]; then
  while IFS=$'\t' read -r candidate_source candidate_lang; do
    [[ -n "$candidate_source" && -n "$candidate_lang" ]] || continue
    rm -f "$TMP_DIR/${VIDEO_ID}."*.srt 2>/dev/null || true
    pushd "$TMP_DIR" >/dev/null
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
  done < "$TMP_DIR/candidates.txt"
fi

UPLOAD_DATE_FMT=""
if [[ -n "$UPLOAD_DATE_RAW" && "$UPLOAD_DATE_RAW" =~ ^[0-9]{8}$ ]]; then
  UPLOAD_DATE_FMT="${UPLOAD_DATE_RAW:0:4}-${UPLOAD_DATE_RAW:4:2}-${UPLOAD_DATE_RAW:6:2}"
fi

TODAY="$(date +%F)"
SAFE_TITLE="${TITLE//\//-}"
SAFE_TITLE="${SAFE_TITLE//:/ -}"
OUTPUT_FILE="${RAW_DIR}/${SAFE_TITLE} [${VIDEO_ID}].md"
SUBTITLE_FILE="$TMP_DIR/${VIDEO_ID}.${SUB_LANG}.srt"

ruby - "$OUTPUT_FILE" "$TITLE" "$WEBPAGE_URL" "$CHANNEL" "$UPLOAD_DATE_FMT" "$TODAY" "$DESCRIPTION" "$SUB_LANG" "$SUB_SOURCE" "$SUBTITLE_FILE" <<'RUBY'
require "cgi"

output_file, title, source_url, channel, published, created, description, sub_lang, sub_source, subtitle_file = ARGV

def yaml_string(value)
  value.to_s.inspect
end

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

body = []
body << "---"
body << "title: #{yaml_string(title)}"
body << "source: #{yaml_string(source_url)}"
body << "author:"
body << "  - #{yaml_string("[[#{channel}]]")}"
body << "published: #{published}" unless published.empty?
body << "created: #{created}"
body << "description: #{yaml_string("YouTube raw import generated with yt-dlp.")}"
body << "tags:"
body << "  - \"clippings\""
body << "  - \"youtube\""
body << "  - \"video\""
body << "  - \"transcript\""
body << "---"
body << ""
body << "> Imported with `yt-dlp` from YouTube."
if !sub_lang.empty?
  subtitle_label = sub_source == "manual" ? "manual subtitles" : "auto-generated subtitles"
  body << "> Transcript source: `#{sub_lang}` (#{subtitle_label})."
else
  body << "> No subtitles or transcript were available for this video."
end
body << ""

unless description.strip.empty?
  body << "## Description"
  body << ""
  body << description.rstrip
  body << ""
end

transcript = paragraphize_srt(subtitle_file)
if transcript && !transcript.empty?
  body << "## Transcript"
  body << ""
  body << transcript
  body << ""
end

File.write(output_file, body.join("\n"))
puts output_file
RUBY
