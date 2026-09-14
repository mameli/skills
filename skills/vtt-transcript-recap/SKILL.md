---
name: vtt-transcript-recap
description: "Complete workflow for local WebVTT transcripts: clean and validate the VTT, review likely ASR errors, and produce a structured meeting recap or study document. Use only for local .vtt input."
argument-hint: "<transcript.vtt>"
---

# VTT Transcript Reader

Process one local `.vtt` transcript from start to finish. This skill accepts **only `.vtt` files**; do not add `.docx` or other input formats.

## Workflow

### 1. Validate and parse

1. Require an existing absolute local path whose extension is `.vtt`.
2. Run the bundled parser from this skill directory:

```bash
python3 <skill-dir>/scripts/parse_vtt.py "/absolute/path/to/file.vtt" --stats-only
python3 <skill-dir>/scripts/parse_vtt.py "/absolute/path/to/file.vtt" --format text
python3 <skill-dir>/scripts/parse_vtt.py "/absolute/path/to/file.vtt" --format json
```

3. Check that `cue_count == consumed_count`. If they differ, report the loss and stop before generating documentation.
4. Never modify the original VTT. Preserve the source path for the final report.

The parser removes timestamps, HTML tags, cue formatting and empty cues. Use its cleaned text as the working transcript. Do not invent speaker names when the VTT does not contain them.

### 2. Review transcription quality

Read the complete cleaned transcript. Identify likely ASR errors, technical terms, proper nouns, strange repetitions and truncated phrases. Do not silently change text.

For every proposed correction:

- show the original word or phrase and a short surrounding excerpt;
- explain why it is suspicious;
- suggest one or more replacements;
- ask the user to approve, reject or provide another correction.

Group repeated occurrences of the same term into one question. Keep normal filler words and unfamiliar but plausible words unchanged. Apply only approved corrections. If the user does not want an interactive correction pass, leave the transcript unchanged and say so.

Write an intermediate corrected transcript only when the user requests file output or when it is needed for the generated document. Never overwrite the source VTT.

### 3. Optional context

If the user provides local context files or folders, list what will be read and ask for confirmation before reading them. Never modify, move or delete context files. Use confirmed context to resolve terminology and identify project-specific people, tools and acronyms.

### 4. Generate the document

Infer the most useful structure from the transcript. Use full prose for explanations and lists or tables for parallel operational information. Include only sections supported by the source; mark missing facts as `Not specified in source material` rather than inventing them.

For a meeting or work discussion, extract:

- Title, date and attendees when available
- Executive summary
- Decisions
- Action items, with owner and status when stated
- Open questions and risks
- Relevant tools, systems and terminology
- Action backlog for distinct bugs, features or work items
- Acceptance criteria in Given/When/Then form only when the source supports them

For an educational or explanatory transcript, extract:

- Overview
- Key concepts
- Detailed exposition in article style
- Examples and procedures
- Architecture or Mermaid diagram when clearly described
- Questions and Answers when explicit questions are present
- Follow-ups or next steps

Do not include speaker labels, timestamps or raw cue blocks in the polished document. Avoid phrases such as “the discussion starts”, “during the meeting” or “the transcript says”. Preserve uncertainty and attribution.

### 5. Output

By default, return the polished document in the response. If the user asks to save it, write Markdown next to the source in:

```text
meeting_recap_output/documents/YYYY-MM-DD/<basename>.md
```

Use the execution date for `YYYY-MM-DD` unless the user specifies another output location. Do not archive or delete the original VTT by default. If intermediate files are created, keep them unless the user explicitly asks for cleanup.

## Output rules

- Input is always a local `.vtt`; reject other formats clearly.
- Keep the language of the source unless the user requests another language.
- Preserve facts, uncertainty, names, technical terms and attribution.
- Do not fabricate decisions, owners, dates, attendees or action items.
- Do not output timestamps or raw transcript blocks in the final document.
- Use Markdown headings, tables, numbered steps and Mermaid only when they improve clarity.
- A Q&A section is conditional: include it only when explicit questions or answerable question-and-answer exchanges are present.
- If the transcript contains no actionable meeting content, produce a coherent article or study note instead of forcing a meeting recap.

## Command reference

```bash
python3 <skill-dir>/scripts/parse_vtt.py "/absolute/path/to/file.vtt" --stats-only
python3 <skill-dir>/scripts/parse_vtt.py "/absolute/path/to/file.vtt" --format text
python3 <skill-dir>/scripts/parse_vtt.py "/absolute/path/to/file.vtt" --format json
```
