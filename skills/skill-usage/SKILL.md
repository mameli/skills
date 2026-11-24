---
name: skill-usage
description: Report how often each installed agent skill is used, from local Claude Code and Codex transcripts, and suggest which skills to remove. Use when the user asks which skills they use most, wants usage stats, or wants to clean up installed skills.
---

# Skill Usage

Run from this skill directory:

```bash
python3 -I scripts/skill_usage.py [--days N] [--installed]
```

- `--days N`: count only the last N days.
- `--installed`: list only installed skills (hide built-in and plugin skills that appear in transcripts).

Columns: `sess` is the number of sessions that used the skill, `Skill` counts
Skill tool calls, `/cmd` counts slash commands the user typed, `read` counts
tool calls that opened the skill's `SKILL.md`. `source` and `installed` come
from `~/.agents/.skill-lock.json`.

When you suggest a cleanup:

- Read the coverage line first. Codex keeps few local sessions, so a skill used
  mostly from Codex can show zero.
- Compare the use count with the install date. A skill installed in the last
  week or two has had no time to be used.
- Group the suggestions by source, and point out skills that overlap with
  skills the user does use.
- Do not remove anything without confirmation. Remove with
  `npx skills@latest remove --global <name> -y`, **one skill per call**: with
  several names, the CLI can silently remove only some of them.
