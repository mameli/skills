---
name: youtube-to-markdown
description: Convert a YouTube video into a Markdown file with metadata, description and transcript. Use for any "save/convert this YouTube video as markdown/notes" request.
---

# YouTube to Markdown

Run from this skill directory:

```bash
python3 scripts/youtube_to_markdown.py "<youtube-url>" [output-dir-or-file.md]
```

Requirements: `python3` and `yt-dlp` on PATH. Nothing else; no vault, no machine-specific paths.

Options:

- `[output-dir-or-file.md]` — directory (default: current directory) or explicit `.md` path.
- `--langs it,en` — preferred caption languages, in order.
- `--no-transcript` — metadata and description only.

The script prints the path of the file it wrote. It picks manual captions before
auto-generated ones, following the requested language order, and falls back to any
available language. Without captions it still writes the note and labels it as
metadata-only.

Behaviour notes:

- Ask for the output location only if the user's request is ambiguous; otherwise
  write into the current directory.
- Never claim the video content was reviewed when no transcript was captured.
- If the user wants a summary instead of the raw dump, read the generated file and
  rewrite it into the requested structure (summary, key ideas, takeaways), keeping
  the source URL, channel and publication date.
