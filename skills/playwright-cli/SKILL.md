---
name: playwright-cli
description: "Use when explicitly asked to automate via Playwright CLI."
version: 1.1.0
---

# Playwright CLI

Use the installed `playwright-cli`; if unavailable, the package is `@playwright/cli` (`npx @playwright/cli`). Consult `playwright-cli --help <command>` for supported options rather than assuming Playwright library syntax.

List existing sessions and choose a unique task-owned name. Use it throughout; obtain current element references with `snapshot` after navigation or page changes. For example, after choosing an unused session name:

```bash
playwright-cli -s=task-name open https://example.com
playwright-cli -s=task-name snapshot
# Substitute the actual element reference from that snapshot:
playwright-cli -s=task-name click e3
playwright-cli -s=task-name screenshot --filename=page.png
playwright-cli -s=task-name close
```

Close only sessions created for the task. An existing CDP-attached browser is not task-owned: preserve it, its cookies, persistent profiles and unrelated tabs. Do not use global cleanup or delete profiles as routine recovery. Maoty uses its own direct-CDP helper, not this CLI.

Load the relevant reference:

- [Session ownership and persistence](references/session-management.md)
- [Storage state and cookies](references/storage-state.md)
- [Request mocking](references/request-mocking.md)
- [Custom Playwright code](references/running-code.md)
- [Test generation](references/test-generation.md)
- [Tracing](references/tracing.md)
- [Video recording](references/video-recording.md)
