#!/usr/bin/env python3
"""Turn a YouTube video into a single Markdown file.

Usage:
    youtube_to_markdown.py <youtube-url> [output-dir-or-file] [--langs it,en] [--no-transcript]

Requirements: python3 and yt-dlp on PATH.
Works on macOS, Linux and Windows (any Python 3.8+).
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path

DEFAULT_LANGS = ["it", "en"]


def die(message: str) -> "None":
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def run_json(url: str) -> dict:
    proc = subprocess.run(
        ["yt-dlp", "--dump-single-json", "--no-warnings", "--skip-download", url],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        die(f"yt-dlp failed:\n{proc.stderr.strip()}")
    return json.loads(proc.stdout)


def caption_candidates(data: dict, langs: list) -> list:
    manual = data.get("subtitles") or {}
    auto = data.get("automatic_captions") or {}
    out = []

    def add(kind: str, lang: str) -> None:
        if (kind, lang) not in out:
            out.append((kind, lang))

    for wanted in langs:
        for kind, table in (("manual", manual), ("auto", auto)):
            for lang in table:
                if lang == wanted or lang.startswith(wanted + "-"):
                    add(kind, lang)
    for lang in sorted(manual):
        add("manual", lang)
    for lang in sorted(auto):
        add("auto", lang)
    return out


def fetch_subtitle(url: str, video_id: str, kind: str, lang: str, work: Path):
    flag = "--write-subs" if kind == "manual" else "--write-auto-subs"
    proc = subprocess.run(
        [
            "yt-dlp", "--skip-download", "--no-warnings", flag,
            "--sub-langs", lang, "--sub-format", "srt/vtt/best",
            "--convert-subs", "srt",
            "-o", "%(id)s.%(ext)s", url,
        ],
        cwd=str(work),
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        return None
    hits = sorted(work.glob(f"{video_id}*.srt"))
    return hits[0] if hits else None


TIMECODE = re.compile(r"^\d{2}:\d{2}:\d{2}[.,]\d{3} -->")


def srt_to_text(path: Path) -> str:
    lines = []
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if not line or line.isdigit() or TIMECODE.match(line):
            continue
        line = re.sub(r"<[^>]+>", "", line)
        if lines and lines[-1] == line:  # auto-captions repeat rolling lines
            continue
        lines.append(line)
    text = " ".join(lines)
    text = re.sub(r"\s+([,.;:?!])", r"\1", text)
    text = re.sub(r"\s+", " ", text).strip()
    return re.sub(r"([.!?])\s+", "\\1\n\n", text)


def slugify(title: str) -> str:
    safe = re.sub(r'[\\/:*?"<>|]+', "-", title).strip().strip(".")
    safe = re.sub(r"\s+", " ", safe)
    return safe[:120] or "video"


def yaml_str(value) -> str:
    return json.dumps(str(value), ensure_ascii=False)


def hms(seconds) -> str:
    try:
        total = int(float(seconds))
    except (TypeError, ValueError):
        return ""
    if total <= 0:
        return ""
    hours, rest = divmod(total, 3600)
    minutes, secs = divmod(rest, 60)
    if hours:
        return f"{hours}:{minutes:02d}:{secs:02d}"
    return f"{minutes}:{secs:02d}"


def build_markdown(data: dict, transcript: str, lang: str, kind: str) -> str:
    title = data.get("title") or "Untitled"
    channel = data.get("channel") or data.get("uploader") or ""
    channel_url = data.get("channel_url") or data.get("uploader_url") or ""
    url = data.get("webpage_url") or ""
    date = data.get("upload_date") or ""
    if re.fullmatch(r"\d{8}", date):
        date = f"{date[:4]}-{date[4:6]}-{date[6:]}"
    description = (data.get("description") or "").strip()
    duration = hms(data.get("duration")) or (data.get("duration_string") or "")
    chapters = data.get("chapters") or []
    yt_tags = [t for t in (data.get("tags") or []) if t]

    out = ["---", f"title: {yaml_str(title)}"]
    if data.get("id"):
        out.append(f"id: {data['id']}")
    out.append(f"source: {yaml_str(url)}")
    if channel:
        out.append(f"channel: {yaml_str(channel)}")
    if channel_url:
        out.append(f"channel_url: {yaml_str(channel_url)}")
    if date:
        out.append(f"published: {date}")
    out.append(f"created: {datetime.now().strftime('%Y-%m-%d')}")
    if duration:
        out.append(f"duration: {yaml_str(duration)}")
    if transcript:
        out.append(f"transcript: {yaml_str(f'{lang} ({kind})')}")
    else:
        out.append("transcript: none")
    if data.get("thumbnail"):
        out.append(f"thumbnail: {yaml_str(data['thumbnail'])}")
    out += ["tags:", "  - youtube", "  - video"]
    if yt_tags:
        out.append("youtube_tags:")
        out += [f"  - {yaml_str(t)}" for t in yt_tags[:15]]
    out += ["---", "", f"# {title}", ""]

    if transcript:
        label = "manual subtitles" if kind == "manual" else "auto-generated subtitles"
        out.append(f"> Transcript: `{lang}` ({label}).")
    else:
        out.append("> No transcript available; metadata and description only.")
    out.append("")

    if description:
        out += ["## Description", "", description, ""]
    if chapters:
        out += ["## Chapters", ""]
        for chapter in chapters:
            stamp = hms(chapter.get("start_time")) or "0:00"
            out.append(f"- `{stamp}` {chapter.get('title', '').strip()}")
        out.append("")
    if transcript:
        out += ["## Transcript", "", transcript, ""]
    return "\n".join(out)


def main() -> int:
    parser = argparse.ArgumentParser(description="YouTube video -> Markdown file")
    parser.add_argument("url")
    parser.add_argument("output", nargs="?", default=".",
                        help="output directory or .md file path (default: current dir)")
    parser.add_argument("--langs", default=",".join(DEFAULT_LANGS),
                        help="preferred caption languages, comma separated")
    parser.add_argument("--no-transcript", action="store_true",
                        help="skip captions, metadata only")
    args = parser.parse_args()

    if shutil.which("yt-dlp") is None:
        die("yt-dlp is required (pip install yt-dlp / brew install yt-dlp)")

    data = run_json(args.url)
    video_id = data.get("id") or "video"

    transcript, used_lang, used_kind = "", "", ""
    if not args.no_transcript:
        langs = [x.strip() for x in args.langs.split(",") if x.strip()]
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            for kind, lang in caption_candidates(data, langs):
                for stale in work.glob("*.srt"):
                    stale.unlink()
                found = fetch_subtitle(args.url, video_id, kind, lang, work)
                if found:
                    text = srt_to_text(found)
                    if text:
                        transcript, used_lang, used_kind = text, lang, kind
                        break

    out_arg = Path(os.path.expanduser(args.output))
    if out_arg.suffix.lower() == ".md":
        target = out_arg
    else:
        target = out_arg / f"{slugify(data.get('title') or video_id)} [{video_id}].md"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(build_markdown(data, transcript, used_lang, used_kind), encoding="utf-8")
    print(target)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
