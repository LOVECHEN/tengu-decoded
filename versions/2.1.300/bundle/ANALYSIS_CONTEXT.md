# Shared Analysis Context — Claude Code (tengu) v2.1.300

You are one of several agents producing a deep reverse-engineering analysis of Claude Code v2.1.300
for the `tengu-decoded` repo. The analysis goes **beyond `strings`**: the full JavaScript source was
extracted from the Bun binary's embedded module graph and beautified. The previous deep analysis is
**v2.1.197**; that is the comparison baseline (103 patch versions earlier).

## Established ground truth (VERIFIED from the binary — do not contradict)

- **Version:** 2.1.300
- **BUILD_TIME:** 2026-10-14T12:54:55Z
- **GIT_SHA:** c6733ae1276880507ca0c5b053ae18fb0df090d6
- **Platform analyzed:** linux-x86_64, ELF 64-bit, 266,972,344 bytes (2.1.197: 245,517,112)
- **Runtime:** **Bun v1.4.3** (`bun_version:1.4.3`; 2.1.197 was Bun v1.4.0)

### Packaging changed: the app is now ESM and code-split

- 2.1.197 shipped one CommonJS bundle (`// @bun @bytecode @bun-cjs`, one 18 MB file).
- 2.1.300 ships **2,651 embedded files** in the ELF `.bun` section (file offset 0x5c93000, 169,843,365
  bytes, ending in the `---- Bun! ----` trailer). Header is now `// @bun @bytecode` (no `@bun-cjs`).
  - 2,401 `.js` (2,395 `chunk-<hash>.js` code-split chunks, the `cli` entry, workers and 3 vendored libraries), 2 `.mjs`, 139 `.zst`
    (zstd-compressed assets), 79 `.md`, 25 `.txt`, 2 native `.node` addons (`clipboard-napi.node`,
    `audio-capture.node`), 2 font assets (`anthropicSans400.woff2`, `anthropicSerif400.woff2`).
  - Entry point (module id 6) is `/$bunfs/root/cli`, a 24,477-byte loader; the code lives in the chunks.
  - Chunks import each other by absolute path, e.g. `import{oft,sft}from"/$bunfs/root/chunk-ppwns75t.js"`
    (~22,800 such imports). **Exported names are kept unchanged across chunks, so cross-chunk symbol names
    below are global.** Chunk-LOCAL helper names (e.g. `Tu`) are reused with different meanings in
    different chunks — always check which module you are in before trusting a short local name.
  - JSC bytecode is embedded for 2,397 modules; **no source maps** are embedded.
- Extraction is done by `bundle/extract.py` (parses Bun's module table: 2,651 records × 52 bytes).

### Files produced

- `bundle/cli.min.js` — all 2,401 application JS modules concatenated **in module-table order**, each
  preceded by a separator line `//// ===== MODULE <id> <name> (<bytes> bytes) =====`. 46,253,541 bytes.
  The three vendored standalone libraries (`mermaid.min.js`, `chart.umd.min.js`,
  `hljsBundle.generated.min.js`) are NOT in it; they are in `bundle/modules/`.
- `bundle/cli.beauty.js` — the beautified version: **1,857,789 lines, 58 MB** (2.1.197: 733,394 lines).
  All 2,401 separators survive (some indented). To find which module a line is in, search backwards for
  the nearest `//// ===== MODULE` line.
- `bundle/modules/` — every non-application file, by its embedded name; each `.zst` also has a
  decompressed sibling without the `.zst` suffix (bundled skills, artifact templates, `claude-code.d.ts`,
  a set of `.mjs` browser/automation scripts, mod templates `band.tsx`/`pane.tsx`, native addons, …).
- `bundle/manifest.tsv` — one row per embedded file: id, name, size, bytecode size, flags, sha256.
- Raw string extracts: `data/raw/` (`strings -n 6` of the whole binary; counts are inflated vs 2.1.197
  because there is ~2.6× more JS — do not cite raw counts as feature counts).

## Per-build symbol map (VERIFIED, global cross-chunk exports)

| Role | 2.1.197 | 2.1.300 | Defined in |
|---|---|---|---|
| Telemetry event fire (sync) | `q(name, payload)` | **`i(eventName, metadata)`** (~2,865 call sites) | module 73 `chunk-62mje8eg.js` |
| Telemetry event fire (async) | — | **`Js(eventName, metadata)`** | module 73 |
| Flag read with provenance | — | **`vn(name, default)` → `{value, source}`** | module 152 `chunk-7rwjz6p0.js` |
| Flag read (primary) | `it(name, default)` | **`k(name, default)` = `vn(...).value`** (~698 call sites) | module 152 |
| Flag read, pinned per session | — | **`vr(name, default)`** — first read cached in `pinnedFeatureValues` | module 152 |
| Flag read wrapper | `J7` | **`MG(name, default, _)`** → `k` | module 152 |
| Async gate checks | `QYr` / `$U` | **`rb(name)`** (`checkGateCachedOrBlocking`), **`V9e(name)`** | module 152 |
| userID (device id) | `vW()` | **`_M(e, seed)`** | module 152 |
| machineID | `z5t()` | **`Umt(e)`** | module 152 |
| summonSidKey | — | **`rPo(e)`** | module 152 |
| Provider plane selector | `yr()` ternary | ternary over a normalized env object `a` (`cli.beauty.js:21729`) | — |

Behaviour already verified (decode further, do not contradict):

- **Telemetry `i()`**: if no sink is attached yet, the event is queued (`{eventName, metadata, async}`)
  rather than dropped; otherwise `sink.logEvent(name, metadata)`. `Js()` is the async twin.
- **Flag reader is now a class.** Resolution (method body near `cli.beauty.js:134160`): environment
  overrides → config overrides (both `source:"override"`) → if disabled `source:"disabled"` → remote-eval
  payload `source:"payload"` → `source:"fallback"` if a payload exists or the name is in set `_r` →
  disk cache `cachedGrowthBookFeatures[name]` `source:"disk"` (records a deferred exposure) → fallback.
  `f5(source)` classifies sources (`payload`/`override`/`disabled` → true, `fallback` → `Wi()`,
  `disk` → false); `QOr`/`V9e` use it. GrowthBook is still the backend (`cachedGrowthBookFeatures`).
- **Persistent random identifiers** — `userID` (`_M`, was `vW`), `machineID` (`Umt`, was `z5t`; both existed
  in 2.1.197), NEW `summonSidKey` (`rPo`), and — found by the fingerprinting agent — NEW
  `remoteControlMachineId` (`f7s`, a randomUUID) plus a device keypair; see `_facts.md`. `userID`, `machineID` and `summonSidKey` are each `Tu(32).toString("hex")` where, in module 152,
  `import{randomBytes as Tu,randomUUID as tO}from"crypto"` — random 256-bit, not hardware derived —
  validated against `/^[0-9a-f]{64}$/` (new) and persisted via `Ce(...)`. `Uee()` initialises userID + machineID.
  *(Corrected after the workflow: this brief originally said 2.1.197 had only one identifier. Wrong — see
  `_facts.md` and `device-fingerprinting.md`.)*
- **New provider plane `anthropicGoogleCloud`** via `CLAUDE_CODE_USE_ANTHROPIC_GOOGLE_CLOUD`. Order (`Ie()`):
  gateway → bedrock → foundry → anthropicAws → anthropicGoogleCloud → mantle → vertex → firstParty.

## Preliminary headline counts (computed inline — the recon agent must confirm or correct)

> **Superseded.** These were the pre-workflow figures. The recon agent widened the accessor set and
> fixed the canonical numbers (704 flags, 1,944 events, 84 tools, 1,018 env vars, …) in
> [`_facts.md`](_facts.md). Cite `_facts.md`, not this table.

| Metric | 2.1.197 | 2.1.300 (preliminary) | Method |
|---|---|---|---|
| Feature flags | 243 | 692 | distinct `"tengu_*"` first arg to `k`/`vn`/`vr`/`MG`/`rb`/`V9e` |
| Telemetry events | 1,163 | 1,924 | distinct `"tengu_*"` first arg to `i`/`Js` |
| Flag/event name overlap | — | 6 | names appearing in both sets — explain them |
| `CLAUDE_*` env vars | 470 | 925 | distinct `\bCLAUDE_[A-Z0-9_]+` in `cli.min.js` |
| `ANTHROPIC_*` env vars | 56 | 69 | distinct `\bANTHROPIC_[A-Z0-9_]+` in `cli.min.js` |

## Tooling gotchas (important)

- In this shell `grep` is aliased to **ugrep**, which rejects wide context windows ("exceeds complexity
  limits"). Use **`command grep -n 'pattern' file`** (GNU grep) or Python. Prefer fixed strings / short
  patterns on the 58 MB file. Never `cat` the whole file; Read with offset/limit.
- Python on these files: run with `python3 -I` and keep scripts outside `bundle/`.

## Files and references (ABSOLUTE paths)

- Beautified source (PRIMARY): `~/dev/projects/tengu-decoded/versions/2.1.300/bundle/cli.beauty.js`
- Minified source: `~/dev/projects/tengu-decoded/versions/2.1.300/bundle/cli.min.js`
- Assets: `~/dev/projects/tengu-decoded/versions/2.1.300/bundle/modules/` + `manifest.tsv`
- Raw extracts: `~/dev/projects/tengu-decoded/versions/2.1.300/data/raw/`
- **Baseline (2.1.197 deep analysis):** `~/dev/projects/tengu-decoded/versions/2.1.197/` — MATCH its
  markdown style and YAML schema. Read the corresponding 2.1.197 file (and its YAML) before writing yours.
  Its beautified source is `~/dev/projects/tengu-decoded/versions/2.1.197/bundle/cli.beauty.js`
  if you need to confirm that something is genuinely new.

## Output location

Write into `~/dev/projects/tengu-decoded/versions/2.1.300/` (markdown at top level, YAML in `data/`).

## Quality bar

- Ground every claim in the source; cite function names and `cli.beauty.js:LINE` (and the module name
  when it matters). Read real function bodies.
- Decode behaviour: what the code DOES when a flag/env/setting is on vs off.
- Mark NEW / CHANGED / REMOVED vs **2.1.197** explicitly, and when you say something is new, check it is
  actually absent from the 2.1.197 source.
- Exact defaults (`!0`=true, `!1`=false, `null`, `{}`, `""`, numbers).
- Mark uncertainty explicitly. Never invent. Minified names are mangled — say when an inference is tentative.
