---
name: markdown-to-pdf-export
description: Export Markdown to a compact PDF using the bundled Pandoc and XeLaTeX profile.
---

# Markdown to PDF

Run `bash scripts/markdown_to_pdf.sh "input.md" "output.pdf"` from this skill directory. Without an output path, the helper writes beside the input with the same basename.

The default profile uses XeLaTeX, 1.2 cm margins, 10 pt text and 0.95 line spacing. Honor explicit formatting requests instead of treating these defaults as fixed requirements.

If conversion fails, diagnose the relevant Pandoc or XeLaTeX dependency or document error. Verify that the PDF exists and inspect its rendering for clipping or broken layout before returning a link.
