# Browser Session Management

Run multiple isolated browser sessions concurrently with state persistence.

## Named Browser Sessions

Use `-s` with a unique task-owned name to isolate browser contexts. Run `playwright-cli list` first; do not reuse an existing session unless the user requests it. Names below are examples, not ownership evidence:

```bash
# Browser 1: Authentication flow
playwright-cli -s=auth open https://app.example.com/login

# Browser 2: Public browsing (separate cookies, storage)
playwright-cli -s=public open https://example.com

# Commands are isolated by browser session
playwright-cli -s=auth fill e1 "user@example.com"
playwright-cli -s=public snapshot
```

## Browser Session Isolation Properties

Each browser session has independent:
- Cookies
- LocalStorage / SessionStorage
- IndexedDB
- Cache
- Browsing history
- Open tabs

## Browser Session Commands

```bash
# List all browser sessions
playwright-cli list

# Close only a session created for this task
playwright-cli -s=mysession close
```

## Environment Variable

Set a default browser session name via environment variable:

```bash
export PLAYWRIGHT_CLI_SESSION="mysession"
playwright-cli open example.com  # Uses "mysession" automatically
```

## Common Patterns

### Concurrent Scraping

```bash
#!/bin/bash
# Scrape multiple sites concurrently

# Start all browsers
playwright-cli -s=site1 open https://site1.com &
playwright-cli -s=site2 open https://site2.com &
playwright-cli -s=site3 open https://site3.com &
wait

# Take snapshots from each
playwright-cli -s=site1 snapshot
playwright-cli -s=site2 snapshot
playwright-cli -s=site3 snapshot

# Cleanup only these task-created sessions
playwright-cli -s=site1 close
playwright-cli -s=site2 close
playwright-cli -s=site3 close
```

### A/B Testing Sessions

```bash
# Test different user experiences
playwright-cli -s=variant-a open "https://app.com?variant=a"
playwright-cli -s=variant-b open "https://app.com?variant=b"

# Compare
playwright-cli -s=variant-a screenshot
playwright-cli -s=variant-b screenshot
```

### Persistent Profile

By default, browser profile is kept in memory only. Use `--persistent` flag on `open` to persist the browser profile to disk:

```bash
# Use persistent profile (auto-generated location)
playwright-cli open https://example.com --persistent

# Use persistent profile with custom directory
playwright-cli open https://example.com --profile=/path/to/profile
```

## Default Browser Session

When `-s` is omitted, commands use the default browser session:

```bash
# These use the same default browser session
playwright-cli open https://example.com
playwright-cli snapshot
playwright-cli close  # Only if this task created the default browser
```

## Browser Session Configuration

Configure a browser session with specific settings when opening:

```bash
# Open with config file
playwright-cli open https://example.com --config=.playwright/my-cli.json

# Open with specific browser
playwright-cli open https://example.com --browser=firefox

# Open in headed mode
playwright-cli open https://example.com --headed

# Open with persistent profile
playwright-cli open https://example.com --persistent
```

## Best Practices

### 1. Name Browser Sessions Semantically

```bash
# GOOD: Clear purpose
playwright-cli -s=github-auth open https://github.com
playwright-cli -s=docs-scrape open https://docs.example.com

# AVOID: Generic names
playwright-cli -s=s1 open https://github.com
```

### 2. Clean Up Only Task-Owned Sessions

```bash
# Only if this task created these sessions
playwright-cli -s=auth close
playwright-cli -s=scrape close
```

Do not use `close-all` or `kill-all` for routine cleanup or recovery. If a task-owned session is unresponsive, identify its exact process and ownership before targeted termination; otherwise ask the user.

### 3. Preserve Profiles and Attached Browsers

Never delete profiles merely because they appear stale. Preserve persistent profiles, cookies, and user data, including profiles used by CDP-attached browsers. Attaching to an existing browser does not make it task-owned: do not close or kill it. Remove only disposable task-created data whose deletion was authorized; ask before deleting any persistent profile.
