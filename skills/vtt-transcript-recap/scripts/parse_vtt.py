#!/usr/bin/env python3
"""Parse a local WebVTT file and emit cleaned cue text or structured data."""

from __future__ import annotations

import argparse
import html
import json
import re
import sys
from pathlib import Path

TIMING_RE = re.compile(
    r"^\s*(?P<start>\d{2}:\d{2}:\d{2}\.\d{3})\s+-->\s+"
    r"(?P<end>\d{2}:\d{2}:\d{2}\.\d{3})(?:\s+.*)?\s*$"
)
TAG_RE = re.compile(r"<[^>]+>")


def clean_text(lines: list[str]) -> str:
    raw = " ".join(line.strip() for line in lines if line.strip())
    raw = TAG_RE.sub("", raw)
    raw = html.unescape(raw)
    raw = re.sub(r"\s+", " ", raw).strip()
    return raw


def parse_vtt(path: Path) -> dict:
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()

    first_non_empty = next((ln.strip() for ln in lines if ln.strip()), "")
    if not first_non_empty.startswith("WEBVTT"):
        raise ValueError("Invalid WebVTT header: expected WEBVTT")

    entries = []
    idx = 0
    n = len(lines)

    while idx < n:
        line = lines[idx].strip()

        if not line:
            idx += 1
            continue

        if line.startswith("WEBVTT"):
            idx += 1
            continue

        if line.startswith("NOTE") or line.startswith("STYLE") or line.startswith("REGION"):
            idx += 1
            while idx < n and lines[idx].strip():
                idx += 1
            continue

        cue_id = ""
        timing_line = lines[idx].strip()
        timing_match = TIMING_RE.match(timing_line)

        if not timing_match:
            cue_id = timing_line
            idx += 1
            if idx >= n:
                break
            timing_line = lines[idx].strip()
            timing_match = TIMING_RE.match(timing_line)
            if not timing_match:
                while idx < n and lines[idx].strip():
                    idx += 1
                continue

        start = timing_match.group("start")
        end = timing_match.group("end")
        timing_source_line = idx + 1

        idx += 1
        cue_lines = []
        while idx < n and lines[idx].strip():
            cue_lines.append(lines[idx])
            idx += 1

        text_clean = clean_text(cue_lines)
        entries.append(
            {
                "cue_id": cue_id,
                "start": start,
                "end": end,
                "source_line": timing_source_line,
                "text": text_clean,
            }
        )

    non_empty_entries = [entry for entry in entries if entry["text"]]
    clean_lines = [entry["text"] for entry in non_empty_entries]

    return {
        "path": str(path),
        "cue_count": len(entries),
        "consumed_count": len(entries),
        "non_empty_cues": len(non_empty_entries),
        "empty_cues": len(entries) - len(non_empty_entries),
        "entries": entries,
        "clean_text": "\n".join(clean_lines),
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Parse a local .vtt file and emit cleaned text or JSON."
    )
    parser.add_argument("input", help="Absolute path to local .vtt file")
    parser.add_argument(
        "--format",
        choices=["text", "json", "jsonl"],
        default="text",
        help="Output format (default: text)",
    )
    parser.add_argument(
        "--stats-only",
        action="store_true",
        help="Print only parsing stats as JSON",
    )
    args = parser.parse_args()

    path = Path(args.input).expanduser()
    if not path.is_absolute():
        print("Input path must be absolute.", file=sys.stderr)
        return 2
    if path.suffix.lower() != ".vtt":
        print("Input file must end with .vtt", file=sys.stderr)
        return 2
    if not path.exists() or not path.is_file():
        print(f"File not found: {path}", file=sys.stderr)
        return 2

    try:
        parsed = parse_vtt(path)
    except Exception as exc:
        print(f"Parse error: {exc}", file=sys.stderr)
        return 1

    if args.stats_only:
        stats = {
            "path": parsed["path"],
            "cue_count": parsed["cue_count"],
            "consumed_count": parsed["consumed_count"],
            "non_empty_cues": parsed["non_empty_cues"],
            "empty_cues": parsed["empty_cues"],
        }
        print(json.dumps(stats, ensure_ascii=False, indent=2))
        return 0

    if args.format == "text":
        print(parsed["clean_text"])
        return 0

    if args.format == "jsonl":
        for entry in parsed["entries"]:
            print(json.dumps(entry, ensure_ascii=False))
        return 0

    print(json.dumps(parsed, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
