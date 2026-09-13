# skills

Reusable agent skills for Codex and other Agent Skills-compatible tools.

[![skills.sh](https://skills.sh/b/mameli/skills)](https://skills.sh/mameli/skills)

## Install

List the available skills:

```sh
npx skills@latest add mameli/skills --list
```

Install every skill globally for Codex:

```sh
npx skills@latest add mameli/skills --skill '*' --global --agent codex --yes
```

Add another explicit `--agent` option when a device should share the same
skills with another compatible agent. Avoid `--all`: agent selection is a
per-device decision.

Update installed global skills:

```sh
npx skills@latest update --global
```

Installed copies are downstream artifacts. Make changes in this repository,
commit and push them, then run the update command on each device.

## Included skills

- `editor`: Proofread or simplify prose and technical Markdown.
- `file-to-markdown`: Convert local PDF and Office files to Markdown.
- `infuse-metadata-season`: Rename TV and anime files for Infuse matching.
- `italian-english-translator`: Translate between Italian and English.
- `markdown-to-pdf-export`: Export Markdown with a compact Pandoc/XeLaTeX profile.
- `playwright-cli`: Automate a browser when Playwright CLI is explicitly requested.
- `whisper-audio-transcriber`: Transcribe local audio with whisper.cpp.
- `yagni`: Apply explicit YAGNI-focused simplification to software work.
- `youtube-to-obsidian-raw`: Capture a YouTube video as an Obsidian source note.

## Layout

Each skill lives in `skills/<name>/` and contains a required `SKILL.md` plus
optional scripts, references, assets, and OpenAI metadata.

## Requirements

Individual skills document their own optional command-line dependencies. Review
skill instructions and bundled scripts before use.

## License

MIT
