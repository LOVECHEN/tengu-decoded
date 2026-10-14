---
title: "Embedded Assets"
version: "2.1.300"
baseline: "2.1.197"
build_time: "2026-10-14T12:54:55Z"
git_sha: "c6733ae1276880507ca0c5b053ae18fb0df090d6"
runtime: "Bun v1.4.3"
packaging: "ESM, code-split (2,651 embedded files)"
source: "bundle/cli.beauty.js (1,857,789 lines), bundle/manifest.tsv, bundle/modules/"
---

# Embedded Assets

> [Back to version index](../README.md)
>
> **Version**: 2.1.300 | **Build**: `2026-10-14T12:54:55Z` | **GIT_SHA**: `c6733ae1276880507ca0c5b053ae18fb0df090d6` | **Platform**: Linux x86-64 | **Runtime**: Bun **v1.4.3** (standalone compiled binary, **code-split ESM**)

This document has no 2.1.197 counterpart. 2.1.197 shipped one CommonJS bundle, and its source references
exactly **two** embedded paths: `require("/$bunfs/root/image-processor.node")` and
`require("/$bunfs/root/audio-capture.node")` (2.1.197 `cli.beauty.js:91`, `:94`). Everything else (skill docs,
prompt templates) was inlined as JS string literals. 2.1.300 ships **2,651 files** in the Bun module table. This
document catalogues all of them by what they are, which code loads them, and who ends up receiving the bytes:
the **model** (prompt text), the **user** (terminal or local pages), a **browser** (Artifact or preview HTML),
a **subprocess** (`node`/`python3` scripts, an MCP server), or an in-process **worker / VM realm**.

Packaging mechanics (chunk loading, the fast-path entry table, facade chunks) are in
[architecture.md §1](architecture.md). The hooks worker and the mod API are in architecture.md §2–§3, and native
addons in §4. This page cross-references those sections rather than repeating them, and it adds the full
non-JS inventory.

Every number below comes from `bundle/manifest.tsv` or from a scratch script over `cli.beauty.js` /
`cli.min.js`. Line numbers are `cli.beauty.js:LINE`.

## The 30-second view

| # | Group | Files | Stored bytes | Loaded by | Delivered to | vs 2.1.197 |
|---|---|---:|---:|---|---|---|
| 1 | Code-split chunks `chunk-<hash>.js` | 2,395 | 46,009,001 | static `import`, `import()`, `import.meta.require` | the Bun runtime | **CHANGED** (was one CJS IIFE) |
| 2 | Entry loader `cli` | 1 | 24,477 | Bun entry point (module 6) | runtime | **CHANGED** |
| 3 | Worker / addon-wrapper entry modules | 3 | 13,701 | `new Worker(HOOKS_WORKER_URL)` `:484538`; wrappers unreferenced | worker thread | **NEW** |
| 4 | Native `.node` addons | 2 | 1,565,232 | `Ne()` in modules 8 / 10 | in-process (N-API) | **CHANGED** (clipboard NEW, image-processor REMOVED) |
| 5 | Vendored browser libs (mermaid, Chart.js, highlight.js) | 3 | 1,020,600 (zstd) | `uct()` async reader | browser (Artifact / preview HTML) | **NEW** |
| 6 | Fonts (Anthropic Sans/Serif 400) | 2 | 25,736 | `Nyo()` → base64 `@font-face` | browser (localhost sign-in pages) | **NEW** |
| 7 | Plugin SDK + mod templates (`claude-code.d.ts`, state library, `band.tsx`, `pane.tsx`, `tool-call.ts`, plugin-test kit) | 10 | 194,349 | `Ne()` / `tt()` | disk (plugin folder), plugin VM realm, model | **NEW** |
| 8 | Claude Test plugin toolkit (`ct*.mjs`, `playwright-mcp.mjs`, `fence-proxy.mjs`, `guard.mjs` …) | 30 | 289,480 | `Ne()` / `tt()` in module 2267 | disk → `node` subprocesses; SKILL text → model | **NEW** |
| 9 | `claude-api` skill corpus | 103 | 795,267 | `Ne()` / `tt()` in module 1841 | model (prompt + extracted files); 2 `.mjs` + 2 `.py` → subprocess | **CHANGED** (was inlined; much larger) |
| 10 | `claude-code-docs` skill corpus | 6 | 69,513 | modules 2304, 392 | model | **CHANGED** (was inlined) |
| 11 | Artifact / design / slides skills and HTML templates | 37 | 529,473 | 13 host modules | model; HTML/CSS/JS → browser; SDK → `node -e` | mostly **NEW** |
| 12 | `dataviz` skill | 10 | 87,964 | modules 1830, 2299, 2300 | model; validators → subprocess | **NEW** |
| 13 | `design-sync` converter toolkit | 26 | 229,517 | module 1820 + 17 one-asset modules | model; `.mjs` → `node` subprocess | **CHANGED** (was inlined) |
| 14 | `cowork-plugin` skill | 5 | 25,347 | module 1829 | model | **CHANGED** (was inlined) |
| 15 | `run` / `run-skill-generator` / `verify` skills | 12 | 42,975 | modules 2301, 2302, 1826 | model | **CHANGED** (was inlined) |
| 16 | Prompt-text assets (ultraplan, loop preambles, auto-mode rules) | 6 | 48,436 | modules 424, 1734, 1252 | model | **CHANGED** (was inlined) |
| — | **Total** | **2,651** | **50,971,068** | | | |

Rows 4–16 hold **252 non-JS records, 4,923,889 stored bytes**. A scratch script that maps every
`/$bunfs/root/<name>` literal in `cli.beauty.js` back to the manifest found that **every one of the 252 is
referenced exactly once**, by exactly one module. No asset is orphaned and none is shared between two loader
modules. (The sharing happens one level up: `gLn`, the plugin-eval quick reference, is exported once and
used in two places.)

---

## 1. Module-table anatomy

### 1.1 What the manifest flags mean

`manifest.tsv`'s `flags` column is the raw last 4 bytes of each 52-byte module record (`bundle/extract.py`
line 77; the extractor does not interpret them). Over the 2,651 rows they take five values:

| flags | rows | Which files |
|---|---:|---|
| `01010100` | 2,399 | every application JS module (ids 0–2398) |
| `00050001` | 144 | 139 `.zst` + 3 vendored libs + 2 fonts |
| `010d0001` | 90 | plain `.md` / `.txt` / `.mjs` text |
| `020d0001` | 16 | text stored as **UTF-16LE** (see below) |
| `000a0001` | 2 | `.node` addons |

**Byte 2 is the Bun loader**, which the extractor does not decode. This reading fits every row: `0x01` js,
`0x05` file, `0x0a` napi, `0x0d` text. Those values also fit Bun's `Loader` enum order as I remember it, but I
did **not** check that against Bun's source, so the field names are an **inference**. **Byte 1 is the stored
encoding.** All 16 `020d0001` files are 2 bytes per char with a NUL high byte (e.g. `design-6m4nsdef.md` starts
`5b00 4800 6f00…` = `[Ho…`, `SKILL-0vb5xk0r.md` starts `2300 2000 4300…` = `# C…`); all 16 decode cleanly as UTF-16LE. The 88 `010d0001` files present in `modules/` contain no NUL byte (the other 2 are the `.mjs` files that are not extracted there, §1.1 note). The split is exact: all 16 UTF-16 files contain at least one
non-ASCII character (e.g. `—`), and all 88 single-byte files are pure ASCII (checked byte by byte). So Bun
evidently stores any non-ASCII text asset as UTF-16 (**inference** about Bun's rule; the observation is verified).

> **Extraction gotcha.** The 16 UTF-16LE files in `bundle/modules/` (`SKILL-0vb5xk0r.md`, `SKILL-8zd8x5rj.md`,
> `recent-changes-*.md`, `design-*.md`, `slides-*.md`, the five dataviz references, `spec-format-*.md`,
> `check.mjs-*.txt`, `skeleton.html-*.txt`, `theme-script.html-*.txt`, `tool-use-ja69jv1h.md`,
> `designHowTo-*.md`) read as spaced-out garbage with `cat`/`grep`. Use `iconv -f UTF-16LE -t UTF-8`.
> `extract.py` writes them as they are stored.

> **Count note (verified).** Module ids 0–2398 are the 2,399 JS modules. They are 2,395 chunks plus `cli`,
> `audio-capture.js`, `clipboard-napi.js` and `hooks-worker.js`. Of these, 2,397 carry bytecode; the two
> 685-byte wrappers do not. The "2,401 application JS modules" in `cli.min.js` (`_facts.md`) are those 2,399
> **plus two `.mjs` files** (ids 2567, 2568: `runner-scaffold-*.mjs`, `build-report-lite-*.mjs`). Those two
> have loader `0x0d` (**text**) and no bytecode. They are claude-api skill **assets** that the code never runs
> (it reads them with `Ne()` at `:1545745–1545746`), but `extract.py` concatenated them because of their
> suffix. So they appear in `cli.beauty.js` (`:1856378`, `:1857149`, with the beautifier mangling the shebang
> into `#!/usr/bin / env node`) and **not** in `bundle/modules/`. `modules/` holds 389 files: 250 stored
> records (the 252 non-JS records minus those two .mjs; 139 of the 250 are `.zst`) plus 139 decompressed siblings.

### 1.2 The asset readers (every non-JS file goes through one of four)

| Reader | Defined at | What it does | Used for (sites) |
|---|---|---|---|
| `Ne(path)` | module 7 `chunk-jqp212qa.js`, `Ne = import.meta.require` `:1408` | Bun's synchronous require. With the `text` loader it returns the file's string; with `napi` it loads the addon | **108**: 106 text files (79 `.md`, 25 `.txt`, 2 `.mjs`) + 2 `.node` |
| `tt(path, dirname)` | module 391 `chunk-130x6yb8.js` `:372893` | `Nyo()` then `.toString("utf8")` | **139**: every `.zst`, read at module evaluation (`var X = tt("/$bunfs/root/…zst", import.meta.dirname)`) |
| `Nyo(path, dirname)` | same, `:372897` | `readFileSync`; if the first 4 bytes are the zstd magic `[40,181,47,253]` (`:372879`) it runs `Bun.zstdDecompressSync`, otherwise returns the raw buffer. On failure it throws `"embedded asset is missing or corrupt"` (`:372903`) | **2** direct (the fonts, kept as a Buffer for base64) |
| `uct(path, dirname)` | same, `:372888` | async `readFile` + `Bun.zstdDecompress` when magic matches | **3**: the vendored libs |

139 + 108 + 3 + 2 = **252**. The reader sniffs magic bytes and ignores file names. That matters because the
three vendored libraries are stored **zstd-compressed under plain `.js` names**: `mermaid.min.js`,
`chart.umd.min.js` and `hljsBundle.generated.min.js` all begin `28 b5 2f fd`. The `.zst` suffix is a naming
convention, not the trigger.

Compression: the 139 `.zst` files are 1,814,579 bytes stored and 5,986,213 bytes decompressed. The 3 vendored
libs are 1,020,600 bytes stored and 4,381,053 decompressed.

### 1.3 Bundled-skill plumbing (shared by groups 8–15)

Most assets are bundled-skill content. Each skill module exports some of `SKILL_MD`, `SKILL_FILES`,
`SKILL_PROMPT`, `SKILL_MODEL_VARS` and `RUN_EXAMPLE_FILES`. A registration call
`Zs({name, description, isEnabled, files, getPromptForCommand})` uses them. `Zs` = `registerBundledSkill`
(module 363 `chunk-snd38m61.js`, `:365324`; readable alias at `:880844`). Most registrations sit in
`:785200–790600`.

- **To the model:** `getPromptForCommand()` dynamically imports the skill's asset module, strips YAML front
  matter (`li(...).content`), appends `## User Request`, and returns it as a text block. This is the route by
  which a skill's **main** SKILL text reaches the model. Secondary `SKILL.md` files that ship inside `SKILL_FILES`
  (e.g. design-sync `storybook/SKILL.md`, Claude Test `templates/sign-in/SKILL.md`) go to disk and reach the model
  only if it `Read`s them, and `plugin-eval-quickref` is also appended to another prompt by `nlr()` (§7.2).
- **To disk (then to the model or a subprocess):** `files: () => import(...).then(m => m.SKILL_FILES)` hands a
  `{relativePath: content}` map to the extractor. `d3e(name)` (`:365394`) puts it at
  `bundledSkillFilesElsewhere.root/<name>` or `uHt()/<name>`. `uHt()` (`:228718`, module 256) is
  `<claudeTempDir>/bundled-skills/2.1.300/<32 random hex chars>`; `qf()` is `claudeTempDir`, module 243
  `:205392`. The write is `S(n, files, "verify-content")`; on success `g("skill_bundled_extract")` fires telemetry
  `tengu_feature_ok {feature_name:"skill_bundled_extract"}` (`g` is module 74 `chunk-6w4kc9tx.js`, `:47892`), on failure
  `m(…, "skill_bundled_extract_write_failed")` (`tengu_feature_bad`). The model then
  `Read`s references or runs scripts there through `${CLAUDE_SKILL_DIR}`.
- **Lazy by construction.** No asset module is imported until its skill is invoked or its `files` are
  requested. Because each asset module calls `tt()` at top level, the decompression cost is paid on that first import.

---

## 2. Code: chunks, entry loader, workers

### 2.1 `chunk-<hash>.js` (2,395 files) — CHANGED

- **What:** the application, split by Bun's bundler. Size spread: min 615 B, median 4,882 B, p90 28,622 B (nearest-rank),
  max 4,934,447 B. 348 are under 1 KB, 1,288 are 1–10 KB, 704 are 10–100 KB, 52 are 100 KB–1 MB and 3 are 1 MB or
  more. The three largest are module 424 `chunk-538n62w8.js` (4,934,447 B), module 1619 `chunk-rrqrxzer.js`
  (1,736,875) and module 1481 `chunk-ds2x9wed.js` (1,546,086). Every chunk opens with `// @bun @bytecode` and
  the same Anthropic legal banner (e.g. `:1–9`).
- **Linking** (counted over `cli.min.js`): **22,847** `import{…}from"/$bunfs/root/chunk-…"` bindings, **174,565**
  bare side-effect `import"/$bunfs/root/chunk-…"` statements, **1,398** `import("/$bunfs/root/…")` and **493**
  `import.meta.require("/$bunfs/root/…")`. The last two match architecture.md §1.4.
- **Delivered to:** the runtime only. No chunk is ever written to disk or sent anywhere.

### 2.2 `cli` entry loader (module 6, 24,477 B) — CHANGED

`Ge()` at `:528`, invoked at `:1327`. It statically imports six tiny chunks (`:438–459`), sets
`NoDefaultCurrentDirectoryInExePath=1` and `COREPACK_ENABLE_AUTO_PIN=0` (`:471–472`), then runs a chain of argv
fast paths (`--gh-standin` `:535`/`:578`, `plugin test` `:594`, `--eval-mock-server` `:623`,
`--claude-in-chrome-mcp` `:635`, `--chrome-native-host` `:642`, `--daemon-worker` `:650`, `--bg-pty-host`
`:672`, `--bg-spare` `:688`, `--preload` `:699`, `remote-control|rc|remote|sync|bridge` `:710`,
`self-hosted-runner` `:1196`). Anything else falls through to `import("/$bunfs/root/chunk-eprgt5fw.js").main`
(`:1323–1325`). Unless argv[0] is `--preload` or `--bg-spare` (`H`, `:572`), it schedules an unref'd 10 s timer (`:574–577`) that
calls `setJitPolicyAfterStartup()` from `chunk-pk18tpkz.js` when `CLAUDE_CODE_JIT_POLICY_AFTER_STARTUP` is set, and
otherwise `Bun.unsafe.setJITPolicy?.(1)`. The full table
is in architecture.md §1.3. The asset relevance is one path: `plugin test` loads module 874, which carries the
`kit-modules.js` asset (§5.4).

### 2.3 Worker and wrapper entry modules — NEW

| File | Id / size | What | Loaded by | Runs in |
|---|---|---|---|---|
| `src/plugins/functionHooks/hooks-worker/hooks-worker.js` | 161 / 12,331 B (bytecode 30,736) | Hosts every plugin's TypeScript **hooks module** (mods). It reads `workerData` (`:157193`), proxies `op` / `next` / `next_pull` messages over ports, and turns `unhandledRejection` into `{type:"unhandled"}` posts | `rJo()` `:484533` → `new Worker(e, jnn(s, n, r))` `:484538` | a Bun **worker thread** named `hooks-<uuid8>` (`znn()` `:484455`), with two `SharedArrayBuffer` stamp/mark arrays. A Linux CPU watchdog reads `/proc/self/task/*/stat` for that thread (`Z7()`/`c3e()`/`Znn()` `:484488–484531`) |
| `audio-capture.js` | 9 / 685 B, no bytecode | `export default nAo()`, re-exporting module 8's addon cell | **nothing references it by path** (0 hits) | — |
| `clipboard-napi.js` | 11 / 685 B, no bytecode | `export default rAo()` from module 10 | **nothing references it by path** | — |

The worker URL is baked into the build-info object (`HOOKS_WORKER_URL`, e.g. `:295`; 295 lines of `cli.beauty.js` carry the path). `Knn()`
(`:484469–484479`) uses it when set. Otherwise it falls back to
`new URL("../../../hooks-worker/hooks-worker.ts", import.meta.url)`, a dev/source-tree path. `Gnn()` (`:484448`)
leaves `B:/~BUN/root/` paths alone on Windows and wraps the rest as `file://` URLs. Both wrapper files are
**tentatively** bundler entry points kept for the addons. The live code imports the cells from modules 8 / 10
directly. 0 occurrences of `functionHooks` / `hooks-worker` in 2.1.197.

Other `new Worker(...)` sites (`:237203`, `:240669`) are inside the 990,546-byte module 270
`chunk-g8fq9q25.js`. They are worker pools of a vendored library whose identity I did **not** establish. They
load no embedded file.

---

## 3. Native addons (2 files) — CHANGED

Behaviour is decoded in architecture.md §4. The asset-side facts:

| Addon | Bytes | Wrapper | Resolver | Library evidence (`strings`) | Delivered to |
|---|---:|---|---|---|---|
| `clipboard-napi.node` (**NEW**) | 1,072,864 | module 10 `rAo` `:1474` | `x()` `:343490` (module 313): try the embedded addon, then `./vendor/clipboard-napi/x64-linux{,-musl}/…` and `../clipboard-napi/…` | Rust N-API; `x11rb-0.13.2`, `wayland-client-0.31.14`, `wl-clipboard-rs-0.9.3`; exports `setLinuxClipboardText` / `getLinuxClipboardText` | in-process. Used only when `probe()` (`class N` `:343561`) finds no `wl-copy`, `xclip` or `xsel`, and `k()` (`:343650`) sees a local `DISPLAY` (`/^(unix)?:/`) or, with no `DISPLAY`, any `WAYLAND_DISPLAY`. Precisely: `wl-copy` is only tried when Wayland is set, `xclip`/`xsel` only when `DISPLAY` is set; the addon branch is `:343586` |
| `audio-capture.node` (**CARRIED**, loader changed) | 492,368 | module 8 `nAo` `:1436` | `r()` in module 2306 (`:1822427`); fallback list now includes `x64-linux-musl` (`:1822436`). 2.1.197's list was `x64-linux` only (2.1.197 `:571723`) | Rust N-API on `cpal-0.15.3` + `alsa-0.9.1`; registers `start_recording`, `stop_recording`, `start_playback`, `stop_playback`, `write_playback_data`, `is_playing`, `is_recording`, `microphone_authorization_status` | in-process, voice mode. Lazy `import("/$bunfs/root/chunk-qs5f2z3g.js")`, which logs `[voice] audio-capture-napi loaded in …ms` (`:1559218–1559220`) |
| `image-processor.node` (**REMOVED**) | — | — | — | — | 0 occurrences in 2.1.300; the replacement (`Bun.Image`) is in architecture.md §4 |

Both files are stripped x86-64 ELF shared objects (`file`).

---

## 4. Browser-side assets

### 4.1 Vendored libraries (3 files, stored zstd) — NEW

| File | Stored → decompressed | Version (from the file / loader) | Loader module | Consumer | Delivered to |
|---|---|---|---|---|---|
| `mermaid.min.js` | 785,819 → 3,566,058 | **mermaid v11.16.1**. The loader prepends `/*! mermaid v11.16.1 \| MIT … */` (`:1770870`) | module 2194 `loadMermaidBundleJs` `:1770869–1770876` | `Bb()` `:1408800` (module 1689): local preview HTTP server. It serves the bundle at `_Dt = "/_runtime/mermaid-11.16.1.min.js"` (`:201379`) when any preview page's HTML contains that path string (`:1408807–1408814`), with `cache-control: no-store`, `referrer-policy: no-referrer`, `x-content-type-options: nosniff`, and CSP `sandbox; default-src 'none'` (`Zf`, `:1408797–1408799`) on non-HTML responses and 404s | **browser** (local Artifact preview) |
| `chart.umd.min.js` | 64,021 → 208,522 | **Chart.js v4.5.1** (header) | module 1663 `loadChartBundleJs` `:1388700` | `Un()` `:688762` (module 569): inlines `<script>{bundle}</script><script>{init}</script>` into Artifact HTML on publish. It first runs the safety checks `fa()`/`$ut()`/`ei()`, and failures report `artifact_publish` / `chart_bundle_unsafe` etc. | **browser** (published Artifact) |
| `hljsBundle.generated.min.js` | 170,760 → 606,473 | **highlight.js 11.11.1, 186 grammars** (header: *"Generated by scripts/generate-hljs-browser-bundle.ts"*) | module 1664 `loadHljsBundleJs` `:1388723` | `Vn()` `:688859`: same inline-on-publish path. The init script `va()` (`:688836`) highlights `pre>code.language-*` with a per-block cap of 50,000 chars and a page budget of 250,000, and marks blocks `data-claude-hljs-claimed` | **browser** (published Artifact) |

The runtime blocks are fenced with HTML-comment sentinels (`<!--claude-mermaid-runtime-begin:` /
`…-end-->`, `:201373–201374`; an hljs equivalent at `:201386`). That lets a republish strip and re-inject
them. `On()` (`:691713`, cached as `workshopBlessedHashes`) collects the **inline-script hashes** of the
workshop templates and of the blocks built by `Un()` (chart), `kxn()` (mermaid, `:689077`) and `Vn()` (hljs)
into an allow-list (`:691721`). Note that `kxn()` does **not** inline mermaid: it emits
`<script src="/_runtime/mermaid-11.16.1.min.js">` (`dxs`, `:201380`) plus an inline init script, and it is also
called on the publish path (`:691328`, `:1421092`). **Tentative:** this feeds a CSP or
integrity check on the published page; I did not trace the consumer of the hash set. Δ vs 2.1.197 (`cli.min.js` counts, 2.1.197 → 2.1.300): `_runtime/mermaid` 0 → 2, `claude-hljs` 0 → 4,
`chart.umd`/`Chart.js` 0 in 2.1.197. **Caveat:** highlight.js itself is **not** new. 2.1.197 already bundled the
highlight.js core in JS (`hljs` ×4, `registerLanguage` ×2, used by the terminal `color-diff` path). What is NEW is the
standalone **browser** bundle asset (11.11.1, 186 grammars) for Artifact pages. Mermaid in 2.1.197 appears only as
the text `mermaid.ink` in a safety prompt.

### 4.2 Fonts (2 files) — NEW

`anthropicSans400.woff2.asset` (10,980 B) and `anthropicSerif400.woff2.asset` (14,756 B) are raw WOFF2
(`774f4632` = `wOF2`). Module 1480 `chunk-t3vts5m9.js` declares the paths at `:1129853–1129854` and reads them with `Nyo()` inside `x()`. `x()`
turns each into a base64 `@font-face{font-family:"anthropic-sans"|"anthropic-serif"; …}`, and `b()` memoises
the pair. `yYr()` (`:1129994`) wraps them into a self-contained `<!DOCTYPE html>…<title>Claude Code</title>`
page with pixel-art animations (`BrokenLink`, `Checkmark`) and an optional 1.5 s `window.close()`. `i0()` is
the success/failure wrapper.

**Delivered to:** the user's **browser**, served from localhost OAuth/IdP callback listeners. Example: the
XAA IdP `/callback` handler answers `i0({ok:!1, heading:"Sign-in failed", …})` or
`i0({ok:!0, heading:"Sign-in complete", …})` (`:1582165–1582210`, module 1922). Importers include modules
1481, 1922, 1934 and 1939. "Sign-in complete" existed in 2.1.197, but the embedded fonts and the `pixelgram`
page did not (0 occurrences).

---

## 5. Plugin SDK and mod templates (10 files) — NEW

| File | Bytes | Loader | What it is | Delivered to |
|---|---:|---|---|---|
| `claude-code.d.ts-7e7b76be.txt.zst` | 145,380 → 650,675 | `tt()`, module 1120 `chunk-aqhmnebz.js` `:974446` → `PLUGIN_DECLARATIONS_TEXT` | The plugin API's TypeScript declarations. Its header says it is *"Written by the engine each time it loads a mod from a folder the person owns, beside that mod as `.claude-plugin/types/claude-code/index.d.ts`"*; it marks the surface *"EARLY ACCESS"* and requires *"TypeScript 5.4 or newer"*. `pluginDeclarationsOf(version, toolSchemas)` prefixes `// Written by Claude Code 2.1.300.` and appends built-in tool schemas (`Omo(P)`) | disk (plugin folder) → the user's editor and the model |
| `state-library.js-wy8y4843.txt` | 4,060 | `Ne()` `:72506` (module 104) → `cPr` | Source of the ESM module that hooks modules import as `'claude-code'` (`yft = "claude-code"` `:70746`): `atom`, `derive`, `memberOf`, `read`, `update`, branded by `Symbol.for('claude-code.state.atom')` | plugin **VM realm**. `DAo()` (`:155209`; the call is at `:155219`, module 157) instantiates it as `new vm.SourceTextModule(cPr, {identifier: "claude-code", …})` (`Js` is the chunk-local `vm` import here, `:155177`, **not** the telemetry `Js`). Module 311's `Qv()` (`:341858–341876`) also registers it as a virtual module. **Tentative:** that path serves the `claude plugin validate` analysis |
| `band.tsx-1v7nt0yx.txt`, `band-state.d.ts-jt01vrsc.txt` | 1,447 / 176 | `Ne()` module 2268 `:1819726–1819728` | Example mod: a band above the prompt showing the last turn's seconds and tool count (`atom({plugin:'turn-band',…})`, `on('prompt.submit')`, `on('tool.call')`), plus its `PluginState` augmentation | disk, then the model |
| `pane.tsx-9v31e0jz.txt`, `pane-state.d.ts-0gphkymd.txt` | 1,588 / 173 | `Ne()` `:1819730–1819732` | Example mod: registers a `tool-calls` command and opens a pane (`$.command.register`, `$.ui.open`) | disk, then the model |
| `tool-call.ts-tv29hdsd.txt` | 701 | `Ne()` `:1819734` | Example guard: denies `Edit` on `.env*` paths and trims `Bash` commands, with `.catch` fail-closed (`{ deny: … its guard failed }`) | disk, then the model |
| `reference-6bf44c8c.md.zst` | 23,281 | `tt()` `:1819736` | `reference.md` of the plugin-authoring skill | disk, then the model |
| `SKILL-346aaa9b.md.zst` | 3,616 | `tt()` `:1819739` | `plugin-authoring` SKILL.md (*"Make a mod: a change to Claude's own interface or behaviour…"*) | **model** |
| `kit-modules.js-c792dea0.txt.zst` | 13,927 | `tt()` module 874 `:865398` | A `//// <path>`-delimited bundle of the plugin-test testing kit (`collector/…`, `@/src/plugins/functionHooks/plugin-test/testing/…`). `It()` splits it into a `Map` (`:865402`), and `bt()` refuses imports that leave the kit (`:865413`) | in-process test harness for `claude plugin test` (entry fast path `:594`) |

**Skill registration.** `plugin-authoring` is not a top-level `Zs()` call. It is the skill
`xe = Object.freeze({name: J /* "plugin-authoring" */, …})` (`:1536654`) inside the built-in plugin
`cc-plugin-plugin-authoring` (`:1536673`). Its `files` resolver `Ne(e)` (`:1536618`) writes
`types/claude-code.d.ts`, `examples/{pane,pane-state.d,band,band-state.d}.ts(x)`, `examples/tool-call.ts` and
`reference.md`. `getPromptForCommand` substitutes `${CLAUDE_SKILL_DIR}` with the extract dir from
`getBundledSkillExtractDir` (`:1536663`). Behaviour of the mod runtime itself is in architecture.md §2–§3.

---

## 6. Claude Test plugin toolkit (30 files, module 2267) — NEW

Module 2267 `chunk-amdd9rxj.js` exports `INSTALLED_FILES` (`:1819652–1819680`, 27 paths) and
`SKILL_MD = {run, execute, draft}` (`:1819681–1819691`). Module 1801 `chunk-64xd7ej5.js` installs and drives it:

- Plugin id `claude-test@builtin`, version `0.4.28` (`:1533374–1533375`). Install folder `_()` =
  `gh("claude-test@builtin")/0.4.28`. The installer `Ne` (`:1533545`) refuses symlinked folders and files
  that differ from the shipped bytes (`claude_test_helper_files` = `linked` / `differs`). Skill references
  `claude-test:(run|execute|draft)` are rewritten to `claude-test`, `claude-test-execute` and
  `claude-test-draft` (`X()` `:1533387`).
- **MCP server (subprocess):** `Se()` (`:1533397–1533406`) declares
  `{command: "node", args: ["<folder>/skills/run/scripts/playwright-mcp.mjs"], env: {CLAUDE_TEST_PROJECT_DIR: "${CLAUDE_PROJECT_DIR}"}}`.
  The shipped `plugin.json` (`plugin.json-bf5v5g6j.txt`) declares the same `"browser"` server.
- Built-in plugin name `cc-plugin-claude-test` (`:1533685`). It needs an interactive terminal session (message `D`, `:1533686`).

| Installed path | Embedded file | Bytes (stored) | Role (from the file's own header/exports) |
|---|---|---:|---|
| `.claude-plugin/plugin.json` | `plugin.json-bf5v5g6j.txt` | 762 | `"name":"claude-test"`, `"version":"0.4.28"`, MCP `browser` server |
| `skills/run/onboarding.md` | `onboarding-0bd7ab6c.md.zst` | 11,841 | *"Onboarding — the machine first, then the starter suite, with the person"* |
| `skills/run/spec-format.md` | `spec-format-s2ka4mwv.md` (UTF-16) | 10,240 | spec file format |
| `skills/run/scripts/ct.mjs` | `ct.mjs-1415bbd2.txt.zst` | 28,223 | main CLI (`node ${CLAUDE_SKILL_DIR}/scripts/ct.mjs status\|new-run\|changes…`) |
| `skills/run/scripts/ct-auth.mjs` | `ct-auth.mjs-3994515c.txt.zst` | 6,323 | saved-session / sign-in runner |
| `skills/run/scripts/ctbrowser.mjs` | `ctbrowser.mjs-ec939aea.txt.zst` | 4,765 | browser launcher |
| `skills/run/scripts/playwright-mcp.mjs` | `playwright-mcp.mjs-8ae8cb57.txt.zst` | 22,879 | MCP launcher for the pinned `@playwright/mcp` |
| `skills/run/scripts/tools-snapshot.json` | `tools-snapshot.json-517c5f68.txt.zst` | 3,337 | *"client-visible tool list of the pinned @playwright/mcp … served by the lazy start-up before the real server exists"* (`server.version` `1.62.1`) |
| `skills/run/scripts/lib/tools-lock.json` | `tools-lock.json-2wbc4a0f.txt` | 1,917 | npm lockfile `claude-test-tools`: `@playwright/mcp` **0.0.79** with `overrides` `playwright`/`playwright-core` **1.62.1** (the package itself declares `1.63.0-alpha-2026-08-05`) |
| `skills/run/scripts/lib/tools.mjs` | `tools.mjs-d77a42b3.txt.zst` | 12,149 | installs/locates tooling; imports `PLAYWRIGHT_MCP_VERSION`, `PLAYWRIGHT_PIN` from `config.mjs` |
| `skills/run/scripts/lib/config.mjs` | `config.mjs-a7bf665e.txt.zst` | 16,179 | `PLAYWRIGHT_MCP_VERSION = '0.0.79'`, `PLAYWRIGHT_PIN = '1.62.1'`, run-dir/consent config |
| `skills/run/scripts/lib/fence-proxy.mjs` | `fence-proxy.mjs-e706eaf6.txt.zst` | 3,973 | `startFenceProxy({allow, onRefused, …})`, `isNonPublicAddress`, `noProxyMatcher`: a local proxy that **fences the test browser** to allowed hosts |
| `skills/run/scripts/lib/hosts.mjs` | `hosts.mjs-724sr8hv.txt` | 6,777 | `publicSuffix`, `registrableDomain`, `makeReachableMatcher`, `isBrowserServiceHost` |
| `skills/run/scripts/lib/psl-data.json` | `psl-data.json-ffeefa5c.txt.zst` | 41,172 | Public Suffix List, `"version":"2026-09-08_12-18-37_UTC"`, MPL-2.0 |
| `skills/run/scripts/lib/NOTICE` | `NOTICE-chm3rwx9.txt` | 335 | MPL-2.0 notice for `psl-data.json` |
| `skills/run/scripts/lib/guard.mjs` | `guard.mjs-cf2a91d4.txt.zst` | 4,703 | YAML/snapshot-line parsing guards (`yamlScalar`, `parseSnapLine`) |
| `skills/run/scripts/lib/allow-tool.mjs` | `allow-tool.mjs-41471569.txt.zst` | 7,529 | consent tools `claude_test_allow` / `claude_test_app_up` |
| `skills/run/scripts/lib/discover.mjs` | `discover.mjs-86dbed6d.txt.zst` | 4,211 | dev-server discovery (`COMMON_PORTS = [3000, 5173, 8080, 8000, 4200, 4321, 5000, 3001]`) |
| `skills/run/scripts/lib/envreport.mjs` | `envreport.mjs-2a6a40b0.txt.zst` | 9,443 | project environment report (skips `node_modules`, `.git`, `.next`, …) |
| `skills/run/scripts/lib/live-page.mjs` | `live-page.mjs-cf057e0f.txt.zst` | 9,261 | `renderLivePage`/`writeLivePage`/`keepLivePage` (a 2 s refresh `live.html` progress page) |
| `skills/run/scripts/lib/open-page.mjs` | `open-page.mjs-v558kpk1.txt` | 8,039 | `openerCommand`/`runOpener`: opens `live.html` in the user's browser |
| `skills/run/scripts/lib/runs.mjs` | `runs.mjs-bffmr2qc.txt` | 7,150 | run bookkeeping (`RUN_ID`, `execFileSync` git) |
| `skills/run/scripts/lib/signin.mjs` | `signin.mjs-e32ba544.txt.zst` | 9,774 | session save/restore (`spawn`) |
| `skills/run/scripts/lib/vet.mjs` | `vet.mjs-8072bf8f.txt.zst` | 4,921 | path and origin vetting (`assertRunsDirInsideProject`, `originAllowed`) |
| `skills/run/templates/sign-in/SKILL.md` | `SKILL-ecyx4ya1.md` | 1,060 | template `sign-in` skill: *"Signs the site's dedicated test member in…"* |
| `skills/run/templates/sign-in/scripts/sign-in.mjs` | `sign-in.mjs-e560d968.txt.zst` | 4,600 | template script. Contract: reads `CLAUDE_TEST_TARGET_ORIGIN`, `CLAUDE_TEST_OUTPUT`, `CT_TEST_MEMBER_EMAIL`/`_PASSWORD`, writes `storageState.json` |
| `skills/run/templates/sign-in/scripts/check.mjs` | `check.mjs-9esx2ea6.txt` (UTF-16) | 4,538 | sign-in check |
| (prompt) `run` | `SKILL-9eb4e8d2.md.zst` | 21,516 | *"Claude Test — the conversation side"* (64,641 B decompressed) |
| (prompt) `execute` | `SKILL-38905837.md.zst` | 16,109 | *"Claude Test runner — drive the app in a browser, judge each spec"*. Runs in the background, fenced (*"the plugin's own headless Playwright, fenced to the …"*) |
| (prompt) `draft` | `SKILL-2427898d.md.zst` | 5,754 | *"Claude Test — the spec author (background; nobody is watching you)"* |

**Delivered to:** 27 files go to **disk** and are run as **`node` subprocesses**: one MCP server, the rest
via Bash from the skill text. The 3 SKILL prompts go to the **model**. `live.html` is opened in the
**user's browser**. 0 occurrences of `claude-test` in 2.1.197.

---

## 7. Skill corpora (groups 9, 10, 12–15)

### 7.1 `claude-api` (103 files, module 1841 `chunk-xsp6hf1x.js`) — CHANGED

Registration `A8s()` `:785474` → `Zs({name:"claude-api", allowedTools:["WebFetch(domain:platform.claude.com)"], disableBridgeInvocation:!0, …})`
(`:785477–785486`). `files: () => k().then(A)` (`k()` `:785269`, `files` `:785485`). `A()` (`:785273–785276`) runs every
`.md` through `p(text, SKILL_MODEL_VARS)` before extraction, filling `{{OPUS_ID}}`, `{{FABLE_NAME}}`, etc. from
`gp` (`:1545846–1545864`). Those placeholders (`{{KEY}}` for the 18 `gp` keys) appear in **77** of the `SKILL_FILES` `.md` assets (78 counting the
`SKILL_PROMPT`, which `A()` does not run through `p()`; scratch count over `bundle/modules/`). `gp` maps, among others,
`OPUS_ID: "claude-opus-5-5"`, `SONNET_ID: "claude-sonnet-5-5"`, `HAIKU_ID: "claude-haiku-5-5"`,
`FABLE_ID: "claude-fable-5-1"`, `MYTHOS_ID: "claude-mythos-5-1"`. Each load fires
`tengu_claude_api_skill_loaded {detected_lang, subcommand, has_args, onboard_source, quickstart}` (`:785488`).

`SKILL_FILES` (`wp`, `:1545867–1545958`) layout:

- `{csharp,go,java,php,python,ruby,typescript}/claude-api/{README,batches,files-api,opentelemetry,streaming,tool-use}.md`
  (subset per language), `python/claude-api/sdk-upgrade.md`, `{go,java,php,python,ruby,typescript}/managed-agents/README.md`,
  `curl/{examples,managed-agents}.md`.
- `shared/`: `admin-api`, `agent-design`, `anthropic-cli`, `claude-platform-on-aws`, `cost-optimization`,
  `error-codes`, `live-sources`, `managed-agents-*` (17 topic docs + 13 `managed-agents-quickstarts/*.md`
  agent recipes such as `bug-hunter`, `incident-commander`, `watchlist-scanner`), `model-migration`
  (largest: 89,537 B stored), `models`, `opentelemetry`, `platform-availability`, `preserved-thinking-migration`
  (+ `causes.md`), `prompt-audit`, `prompt-caching`, `token-counting`, `tool-use-concepts`.
- `shared/evals/`: `build-eval`, `eval-audit`, `cost-hillclimb`, `eval-hillclimb`, `report/SCHEMA.md`.
- **Executable helpers (subprocess when the model runs them):** `shared/evals/report/runner-scaffold.mjs`
  (*"Runner scaffold for the build-eval / hillclimb loop. Copy this into the user's repo…"*),
  `shared/evals/report/build-report-lite.mjs` (*"Lite report builder… a single static report.html"*),
  `shared/preserved-thinking-migration/prefix_diff.py` (*"find what changed between two consecutive Messages
  API requests…"*) and `drop_block_probe.py` (*"replay a captured conversation against the Messages API with
  the preserved thinking controls turned on… Credentials come from the environment"*).
- `SKILL_PROMPT` = `SKILL-1bee3906.md.zst` (*"Building LLM-Powered Applications with Claude"*, 33,384 B stored).

**Δ vs 2.1.197:** `Building LLM-Powered Applications` occurred once in 2.1.197 `cli.min.js` and occurs 0 times
in 2.1.300's. The skill moved out of JS (**MOVED**). `hillclimb`, `preserved-thinking-migration` and
`managed-agents-quickstarts` occur 0 times in 2.1.197. Those parts are **NEW**.

### 7.2 `claude-code-docs` (6 files) — CHANGED

Module 1839 (`A = "claude-code-docs"` `:1545474`; `Zs` at `:1545573`) loads module 2304 `chunk-kqsnmm7x.js`:
`SKILL_PROMPT` = `SKILL-0vb5xk0r.md` (UTF-16, *"Claude Code Configuration Guide … Your knowledge of Claude Code is
stale by default"*). `SKILL_FILES` holds `references/{claude-tag, live-sources, plugin-eval, plugin-eval-quickref,
recent-changes}.md` (`E`, `:1822367–1822372`). The prompt builder `D()` adds the live command list
(*"Available commands (N in this build)"*) and the `claude plugin` subcommands.

`plugin-eval-quickref-e95bcd1b.md.zst` lives in its own module 392 (`gLn`, `:372931`). It is shared: it is
the `references/plugin-eval-quickref.md` file **and** it is appended to another prompt by `nlr()` (`:493318`,
*"# Plugin eval and /skill-doctor (embedded offline reference)"*). **Model-bound.** `Claude Code Configuration
Guide` and `Recently changed surfaces` were each inlined once in 2.1.197 (**MOVED**). `Claude Tag` and
`skill-doctor` occur 0 times there (**NEW**).

### 7.3 `dataviz` (10 files) — NEW

Module 1830 `chunk-1kwsvhhf.js`, registered by `Ro()` (`Zs` `:788694`, `name: Czn` = `"dataviz"` `:310237`).
`SKILL_MD` = `SKILL-8zd8x5rj.md` (UTF-16, front matter `name: Data Visualization`, *"BRAND-NEUTRAL"*).
`SKILL_FILES`: `references/{anti-patterns, choosing-a-form, color-formula, components, interaction,
marks-and-anatomy, palette}.md` plus `scripts/validate_palette.js` and `.py`. The scripts come from modules 2299
and 2300 via `import.meta.require` (`:1542865–1542866`); the skill tells the model to run
`node scripts/validate_palette.js "<hex,…>" --mode light` (**subprocess**). Separately, the `artifact-design`
prompt gains a dataviz callout only when `k("tengu_cobalt_plinth_dataviz", !1)` is true and `dataviz` is a
registered skill (`:786722`).

### 7.4 `design-sync` (26 files) — CHANGED

`Go()` registers `name: "design-sync"` (`:789031`, gate `WF`, `policyGate: L$e`, `disableModelInvocation: !0`).
Module 1820 `chunk-8yp1vh98.js` builds `SKILL_FILES` (`ye`, `:1542314–1542343`). Its sources are 9 assets
loaded directly (`SKILL-b6859017.md` base skill = `SKILL_MD`, `storybook/SKILL.md` ← `SKILL-76b8b2a9`,
`non-storybook/SKILL.md` ← `SKILL-a98d25a2`, and 6 `Ne()`-loaded `.mjs` (stored as `*.mjs-<hash>.txt`): `lib/detect`, `lib/source-kit`,
`lib/css-fallback`, `lib/preview-gen-storybook`, `storybook/http-serve`, `storybook/probe`) plus 17 one-asset
modules 2282–2298, each pulled in with `import.meta.require` (`:1542290–1542312`): `package-build`,
`package-validate`, `package-capture`, `resync`, `lib/{common,bundle,dts,css,source-storybook,story-imports,
emit,previews,docs,preview-rebuild,sync-hashes,remote-diff}`, `storybook/compare`. The skill text runs them as
`node .ds-sync/package-build.mjs --config .design-sync/config.json …` (**subprocess**). They bundle a React
design system and upload it to claude.ai/design. `design-sync` occurred 132 times in 2.1.197 and
`Storybook source shape` was inlined there (**MOVED** to assets).

### 7.5 `cowork-plugin` (5 files) — CHANGED

`Io()` → `Zs({name: Rzn /* "cowork-plugin" */, userInvocable: !1, isEnabled: () => I_() || cW()})` (`:788665`).
Module 1829: `SKILL_MD` = `SKILL-0e9ec89e.md.zst` (*"# Cowork Plugin Authoring"*). Files are
`references/{component-schemas, example-plugins, mcp-servers, search-strategies}.md`. **Model-bound.**
Inlined in 2.1.197 (**MOVED**).

### 7.6 `run`, `run-skill-generator`, `verify` (12 files) — CHANGED

| Skill | Registration | Asset module | Files |
|---|---|---|---|
| `run` | module 1833, `name: "run"` `:1543286` | 2301 `chunk-z7gggtph.js` | `SKILL_MD` = `SKILL-9ddmsnpa.md`; `RUN_EXAMPLE_FILES` = `examples/{cli, electron, library, playwright, server, tui}.md` |
| `run-skill-generator` | module 1834, `:1543490` (`disableModelInvocation: !0`) | 2302 `chunk-tdmgvye3.js` + 2301 | `SKILL_MD` = `SKILL-e3d212e9.md.zst`, `template.md` = `template-eg8004mh.md`, plus the run examples |
| `verify` | `En()` `:790520` (`disableModelInvocation: () => !oOr()`) | 1826 `chunk-ezhpamkz.js` | `SKILL_MD` = `SKILL-cf37e4b8.md.zst`; `examples/{cli, server}.md` |

All three carry a second `files` source, `uo(mwn)`, whose content is not embedded. Their descriptions
occurred twice each in 2.1.197 (**MOVED** to assets).

---

## 8. Artifact, design and slides assets (37 files) — mostly NEW

All are bundled-skill content or publish-path templates for claude.ai Artifacts. Skill names come from the
constant block `:310231–310246` (`M6="artifact-design"`, `npt="artifact-diagramming"`,
`mS="artifact-capabilities"`, `cfe="workshop"`, `_Ps="whiteboard"`, `Azn="prototype"`, `Czn="dataviz"`,
`rpt="design"`, `bPs="artifact-pr-review"`, `Rzn="cowork-plugin"`).

| Skill / consumer | Host module | Embedded files | Delivered to | vs 2.1.197 |
|---|---|---|---|---|
| `artifact-design` (`Ge()`, `Zs` `:786727`, `userInvocable: !1`) | 1842 `chunk-48rdarmk.js` | `SKILL-159ef46e.md.zst`, loaded by `M2t()` `:785551` | model | description inlined in 2.1.197 → **MOVED** |
| `artifact-diagramming` (`We()`, `:786744`) | 1827 `chunk-8fzwkd75.js` | `SKILL-kyber1ah.md` | model | **NEW** |
| `artifact-report`, `artifact-data-table`, `artifact-explainer` (`xt()` loops over `Jn`, `name: \`artifact-${e}\`` `:786790`) | 1828 `chunk-zf5ffzvk.js` | `SKILL-z3x847gz.md` + `template.html-268183fd` (report); `SKILL-5vqnvygj.md` + `template.html-cad26093` (data-table); `SKILL-sq87gt02.md` + `template.html-j5g90adz` (explainer) | SKILL → model; `template.html` → disk → model fills it → **browser** (published Artifact) | **NEW** |
| `doc` (`tn()` loops over `zs`, `:789543`) | 1822 `chunk-0ngfk9wb.js` | `SKILL-h8rn0xak.md`, `template.html-101715f9` | same | **NEW** |
| `whiteboard` (`sn()`, `:789590`; variant `dt() === "live"` picks the files) | 1823 `chunk-63vspk0f.js` (shared) / 1824 `chunk-3tsxnrt9.js` (live) | shared: `SKILL-7f2555bf`, `template.html-af756034`, `board.mjs`; live: `SKILL-8e6c8b5d`, `template.html-38b74715` (89,802 B stored, the largest template), `merge-state.mjs` | SKILL → model; `board.mjs` / `merge-state.mjs` → **`node` subprocess** (*"Whiteboard helper. Reads the published board… writes the republishable page"*); template → browser | **NEW** |
| `prototype` (`rn()`, `:789625`) | 1825 `chunk-2js44j5x.js` | `SKILL-b0897508.md.zst` | model | **NEW** |
| `artifact-components` (`Tt()`, `:786695`) | 1831 `chunk-ypyaac01.js` | `SKILL-fjp06kkf.md`; `decision/{skeleton.html, theme-script.html, decisions-script.html, component.css, tokens.css}` | model; HTML/CSS/JS → browser. `DECISION_DECISIONS_SCRIPT` / `DECISION_THEME_SCRIPT` are also exported for code use | **NEW** |
| `workshop` (`_t()`, `:786664`) | 1662 `chunk-57sywrng.js` | `SKILL-e92179a2.md.zst`, `artifact-workshop.html` (`WORKSHOP_TEMPLATE`), `workshop-page.html` (`WORKSHOP_PAGE_TEMPLATE`) | model; templates → browser. The publish path uses `WORKSHOP_TEMPLATE` (`:1403077`, feature `"workshop"`); the script-hash allow-list reads both (`:691718`) | **NEW** |
| `artifact-pr-review` (`mn()`, `:789760`) | 1658 `chunk-8a269dm1.js` | `SKILL-d7191b6b.md.zst` (legacy lane), `SKILL_COMPOSED-a8900b24.md.zst` (composed lane when `_Be()`, `:789776–789780`), `template.html-f851b5da` | model; the template is also parsed by code for pinned markup (`$Tt()` `:689421`, `Tk()` `:1413254`) → browser | **NEW** |
| Plan artifacts (no skill) | 2195 `chunk-3h1abadt.js` | `artifact-plan.html-80a36a32.txt.zst` → `PLAN_TEMPLATE`. Its header comment reads *"fill contract: the automatic publish path (src/frame/planArtifactHtml.ts) fills this mechanically — {{TITLE}}, …"* | browser. Default template of `Vc()` publish (`:1403111`); on load failure it falls back to a markdown stylesheet and logs `${feature}_template_load_failed` | **NEW** |
| `AppifactRepl` tool | 1692 `chunk-x161r071.js` | `appifact_sdk.js-852e8bcb.txt.zst` (`:1426133`) → `source` | **subprocess**. `Mn()` (`:1426190`) spawns `node -e <sdk> -- --repl -`, or `[binShell, "-c", wrapped]` when sandboxed (`:1425956`). The SDK talks back over the descriptor named by `CLAUDE_CODE_ARTIFACT_FD` (`:1425675`); its header: *"claude.use("db"), claude.use("files") and claude.use("assets") calls … go to the tool over the descriptor"*. Refused for remote callers | **NEW** |
| Design / Slides Artifact-type "REPL route" text | 1840 `chunk-xn1qetnk.js` | `design-6m4nsdef.md`, `designHowTo-p8zjfw0e.md`, `designTwoSteps-g0bev2xr.md`, `slides-zdpeg77q.md`, `slidesHowTo-09m4dbj2.md`, `slidesTwoSteps-1shjmnfb.md` (3 of 6 stored UTF-16: `design`, `designHowTo`, `slides`) | model. Appended only when `artifactReplToolPresent()`: `rlr()` / `SQr()` key on the skill's front-matter `name:` (`:779062–779090`, module 713); `V8o()` fills tokens.json paths and URLs into the how-to (`:929696+`, module 1001) | **NEW** |

`artifact-capabilities` (`Zs` `:786563`) and the `design` command (`lt()`, `:789004`) have **no** embedded
asset. Their content is fetched at runtime (`files: async (l) => { … Mn({credentials, storageV5}) … }`).

---

## 9. Prompt-text assets outside skills (6 files) — CHANGED

| Asset(s) | Loader | Consumer | Delivered to | vs 2.1.197 |
|---|---|---|---|---|
| `simple_plan-s5yyk7xh.txt`, `visual_plan-9bza2qe2.txt`, `three_subagents_with_critique-bd1egk7q.txt` | `Ne()` CJS cells `h7t`/`y7t`/`_7t` `:385495–385502` (module 424) | Ultraplan prompt table `T7t` (`:475103–475107`). `uVe()` (`:475114`) picks `k("tengu_ultraplan_prompt_identifier", "simple_plan")` and falls back to `simple_plan` for unknown ids. The texts start `<system-reminder>\nYou're running in a remote planning session…` | **model** (the remote cloud planning session) | ids existed in 2.1.197 (`QKl = "simple_plan"` 2.1.197 `:536281`), text inlined there (*"Run a lightweight planning process"* ×2) → **MOVED** |
| `loopAutonomousPreamble-07qcyhv4.md`, `loopAutonomousPreamblePersistent-3zqtkrvg.md` | `Ne()` `:1454104–1454105` (module 1734) | `L()` `:1454112` picks the persistent variant when `c()` (`:1454107`) is true: `CLAUDE_CODE_LOOP_PERSISTENT` set, or `k("tengu_kairos_loop_persistent", !1)`. It appends the text returned by `Utt({forCloudSession: Boolean(CLAUDE_CODE_REMOTE)})` when that is non-empty | **model** (`/loop` timer turns; `# Autonomous loop check`) | inlined in 2.1.197 (×2) → **MOVED**; see architecture.md §8 |
| `permissions_external-df98b90a.txt.zst` | `tt()` module 1252 `:1031394` | `pqe` (`:455108`) → auto-mode classifier template, substituted into `<permissions_template>` (`:455356`); also scanned by `CEo()` (`:431556`) for `- <rule name>:` lines | **model** (permission classifier) | template text was inlined in 2.1.197: `Trust slots` 1 → 0 and `None configured` 5 → 0 in `cli.min.js`, both present in the asset → **MOVED**. The content also **CHANGED** (`Context slots` is in the asset, 0 in 2.1.197). The `user_*_rules_to_replace` marker names stay in code as substitution keys (2 lines in 2.1.300) |

---

## 10. What's new / changed vs 2.1.197 — at a glance

- **Packaging (CHANGED):** 2 embedded non-JS files in 2.1.197 → **252** in 2.1.300, plus 2,399 JS modules
  instead of one bundle. `Bun.embeddedFiles` was probed in 2.1.197 (`:40785`) and is not referenced in 2.1.300.
- **MOVED out of JS into assets:** skill corpora for `claude-api`, `claude-code-docs`, `cowork-plugin`,
  `design-sync`, `run`, `run-skill-generator`, `verify`, `artifact-design`; the ultraplan templates; the loop
  preambles; the auto-mode permissions template. The consequence for analysis: `cli.min.js` alone no longer
  contains them, which is why `_facts.md` §1 counts env/API/model ids over JS + the 243 decompressed text assets.
- **NEW asset families:** hooks worker + plugin SDK (`claude-code.d.ts`, state library, mod templates,
  plugin-test kit); Claude Test (30 files, `@playwright/mcp` 0.0.79 / Playwright 1.62.1); Artifact templates
  (doc, report, data-table, explainer, whiteboard ×2, workshop, pr-review, plan, components); AppifactRepl SDK;
  dataviz; vendored mermaid 11.16.1 / Chart.js 4.5.1 / highlight.js 11.11.1 browser bundle (the highlight.js core was already
  in 2.1.197's JS); Anthropic Sans/Serif fonts.
- **Native:** `clipboard-napi.node` NEW, `image-processor.node` REMOVED, `audio-capture.node` CARRIED with a
  musl fallback added.
- **Compression:** 142 of 252 non-JS records are zstd blobs (139 `.zst` + 3 vendored libs), read through one
  magic-sniffing reader (`Nyo`/`uct`).

## Uncertainties / tentative inferences

- **Manifest flag fields.** "byte 1 = encoding, byte 2 = loader" fits all 2,651 rows and the UTF-16 check. The
  Bun field names and enum values were **not** checked against Bun's source.
- **Wrapper modules 9/11** (`audio-capture.js`, `clipboard-napi.js`) are unreferenced by path. Calling them
  bundler entry points is an inference.
- **Script-hash allow-list consumer** (`workshopBlessedHashes`, `:691713`): I traced what goes in, not where
  the set is enforced.
- **Mermaid on published Artifacts.** The local preview server serves `/_runtime/mermaid-11.16.1.min.js`
  (`:1408807–1408815`). The publish path's `kxn()` (`:689077`) emits a root-relative `<script src="/_runtime/mermaid-11.16.1.min.js">`
  into the page (verified), so a published page would request that path from whatever origin serves it. Whether
  claude.ai serves it is not established from this binary.
- **Gate bodies not decoded here:** `Wn`, `_e`, `eI`, `Yvo`, `Vs`, `Xs`, `gCr`, `hCr`, `WF`, `I_`, `cW`,
  `oOr`, `_Be`, `dt`. They are named so each registration can be found, but what they test is not documented here.
- **`module 270` worker pools** (`:237203`, `:240669`) belong to a vendored library I did not identify.
- **Executable assets run only if the model chooses to run them** (via Bash, following SKILL text). The only
  embedded scripts the code itself spawns are `playwright-mcp.mjs` (MCP config `:1533401`) and the AppifactRepl
  SDK (`:1425956`). Basis: the other script names (`board.mjs`, `merge-state.mjs`, `validate_palette`, `ct.mjs`,
  `package-build.mjs`, `prefix_diff.py`, …) occur in code only as asset paths and `SKILL_FILES` keys. `kit-modules.js`
  is evaluated in-process (`claude plugin test`), not spawned. The hooks worker is a thread, not a process.
