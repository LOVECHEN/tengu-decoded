# Version Comparisons

This directory contains changelogs documenting differences between Claude Code versions.

## Available Comparisons

- [2.1.197 → 2.1.300](2.1.197-to-2.1.300.md) — ESM code-split re-platform, hooks worker + mods, Claude 5.5 / Opus-by-default, device keys + self-hosted runners, LLM bash classifier removed; Bun 1.4.3. (~15 weeks, 103 patches)
- [2.1.169 → 2.1.197](2.1.169-to-2.1.197.md) — Fable 5 / Mythos 5 / Sonnet 5, credits & Frame artifacts, vaults + memory stores; Bun 1.4.0. (~3 weeks, 28 patches)
- [2.1.32 → 2.1.169](2.1.32-to-2.1.169.md) — cloud backend, background daemon, agent teams, kairos loops; Node SEA → Bun. (~4 months, 137 patches)

## How Comparisons Work

When a new version is analysed, its structured YAML data is compared against the previous version to identify:

- **Added** flags, events, endpoints, or variables
- **Removed** items no longer present in the binary
- **Changed** items with different defaults, categories, or behaviour

Each comparison file follows the naming convention: `<old-version>-vs-<new-version>.md`
