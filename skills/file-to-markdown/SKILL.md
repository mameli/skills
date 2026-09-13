---
name: file-to-markdown
description: Convert local PDF, office, and other supported files into Markdown, including explicit MarkItDown requests.
---

# File to Markdown

Choose the converter from the requested engine and source type:

- Explicit Microsoft MarkItDown request, or a non-PDF document: `bash scripts/run_markitdown.sh "source-path"`.
- PDF without a specified engine: `bash scripts/run_pdf_to_markdown.sh "source.pdf"`. This uses OpenDataLoader PDF and requires Java on PATH.

Run commands from this skill directory. Both helpers bootstrap separate isolated runtimes and print Markdown to stdout. `--output "output.md"` writes the raw result to a file; check the destination before using it because it can replace an existing file.

Inspect extraction before delivering it. Diagnose recoverable failures and retry as appropriate; report empty, incomplete or unusable extraction clearly. Preserve wording, order, headings and lists with minimal cleanup; summarize or restructure only when requested. For office or explicit MarkItDown conversions, prepend available source metadata. Keep PDF extraction raw by default.

Use the requested destination, otherwise a sibling `.md` file. Unless replacement is authorized, preserve existing files by choosing `.converted.md`, then a numbered unused filename. Do not assume an Obsidian layout. Return the completed file link and material extraction limitations.
