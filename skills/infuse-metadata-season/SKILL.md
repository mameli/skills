---
name: infuse-metadata-season
description: "Rename TV/anime seasons and episodes for Infuse matching."
---

# Infuse season naming

Inspect the supplied folder directly. Establish the series, season and episode mapping from the request and filenames; ask only for missing information that affects identification. Do not infer ambiguous episode order from directory listing order.

Use the user's naming convention, or default to `Show Name/Season 02/Show Name - S02E01.ext`. Include the year for requested disambiguation and episode titles only when requested.

Build a before/after mapping and check for collisions. When the user has authorized renaming and the mapping is unambiguous, apply safe renames without another confirmation. Obtain clarification before acting on ambiguous episode assignments or overwriting files. Preserve extensions and associated subtitle mappings.

Verify the final names and file count, and retain the mapping so the operation can be reversed.
