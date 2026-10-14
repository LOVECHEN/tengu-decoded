# Analysed Versions

| Version | Build Date | Platform | Analyst | Analysis Date |
|---------|-----------|----------|---------|---------------|
| [2.1.300](2.1.300/) | 2026-10-14 | Linux x86-64 | whs | 2026-10-15 |
| [2.1.197](2.1.197/) | 2026-06-29 | Linux x86-64 | whs | 2026-06-30 |
| [2.1.169](2.1.169/) | 2026-06-08 | Linux x86-64 | whs | 2026-06-09 |
| [2.1.32](2.1.32/) | 2026-02-05 | Linux x86-64 | whs | 2026-02-06 |

## Directory Structure

Each version directory contains:

- `metadata.yaml` — Version metadata
- `*.md` — Human-readable analysis reports per topic
- `data/*.yaml` — Structured machine-readable data
- `data/raw/` — Raw extraction output (provenance)
- `bundle/` — (Bun builds) the extracted JavaScript and the script that extracted it; from 2.1.300 the
  beautified `cli.beauty.js` is regenerated locally rather than committed (see that version's `bundle/README.md`)

## Cross-version comparisons

- [2.1.197 → 2.1.300](../comparisons/2.1.197-to-2.1.300.md)
- [2.1.169 → 2.1.197](../comparisons/2.1.169-to-2.1.197.md)
- [2.1.32 → 2.1.169](../comparisons/2.1.32-to-2.1.169.md)

## Note on methodology depth

The 2.1.169 analysis goes **beyond `strings`**: the binary is a Bun-compiled standalone
executable, so the full plaintext JS bundle was carved out and beautified, and findings are
grounded in real function bodies. It also adds a new
[device-fingerprinting](2.1.169/device-fingerprinting.md) deep-dive not present in the 2.1.32 analysis.

From **2.1.300** the application is code-split ESM: 2,651 files embedded in the binary's `.bun` ELF
section instead of one CommonJS bundle. The JavaScript is extracted by parsing Bun's module table
([`2.1.300/bundle/extract.py`](2.1.300/bundle/extract.py)), and the non-JS assets get their own
[embedded-assets](2.1.300/embedded-assets.md) report.
