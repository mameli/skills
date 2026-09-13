---
name: youtube-to-obsidian-raw
description: Capture a YouTube video as a structured source note in an Obsidian vault’s `_Wiki/raw` folder.
---

# YouTube source note

Run `bash scripts/youtube_to_obsidian_bundle.sh "youtube-url" "temp-dir"` from this skill directory, using a temporary directory. The helper requires `yt-dlp`. Read its `manifest.json` and `transcript.txt` to build the note.

Locate the requested vault and follow its source-note conventions. Default to `_Wiki/raw`; write into `_Wiki/wiki` only when the user requests promotion. Ask for the vault only if the destination is ambiguous.

Preserve the source URL, channel, publication date and the video's substance in a structured note. A summary, source details, main ideas, takeaways and useful concepts are a possible structure; include limitations when material. Include the description when useful.

Prefer manual captions over automatic captions, and Italian, then English, then other available languages. If captions are unavailable, use metadata and description and label the note's limited basis; do not imply that the video's full content was reviewed.

Keep intermediate transcripts outside the vault. Embed or archive them only when requested; `scripts/youtube_to_obsidian_raw.sh` supports explicit raw archival requests. Verify the saved note and return its link.
