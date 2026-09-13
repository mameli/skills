---
name: handy-prompt-sync
description: Safely install or update the three Markdown prompts from a local handy-config repository in Handy's local settings on macOS. Use for syncing prompt.md, translate-to-english.md, and translate-to-x.md into Handy; do not use for changing providers, models, API keys, or unrelated Handy preferences.
---

# Handy prompt sync

Locate the user's `handy-config` repository and Handy settings file. The usual macOS settings path is `~/Library/Application Support/com.pais.handy/settings_store.json`.

Before changing anything:

- Confirm the source contains `prompt.md`, `translate-to-english.md`, and `translate-to-x.md`, each with exactly one literal `${output}` placeholder.
- Inspect only prompt-related settings. Never print or expose `post_process_api_keys` or unrelated settings.
- Check whether the `handy` process is running. Close it gracefully before syncing because Handy can overwrite an external settings edit from its in-memory state. Remember whether it was running so it can be reopened afterward.

Run the deterministic updater from this skill directory:

```bash
ruby scripts/sync_handy_prompts.rb \
  --repo /absolute/path/to/handy-config \
  --settings "/absolute/path/to/settings_store.json"
```

The script validates inputs, creates a timestamped backup beside the settings file, atomically updates only the managed prompt entries, preserves the built-in prompt and all other settings, and verifies the written contents. Its stable IDs are:

- `handy_config_cleanup`
- `handy_config_translate_to_english`
- `handy_config_translate_to_x`

It selects the cleanup prompt only when Handy has no selected prompt. Otherwise it preserves the user's selection.

After syncing, reopen Handy if it was previously running. Verify the Post Process prompt menu contains **Clean Up Transcription**, **Translate to English**, and **Translate to X**. Report the backup path and whether the previous selection was preserved. If Handy or the settings schema cannot be identified safely, stop without modifying the file and explain what is missing.
