# Claude Code v2.1.300 Overview

> [Back to version index](../README.md)
>
> **Version**: 2.1.300 | **Build**: `2026-10-14T12:54:55Z` | **Platform**: Linux x86-64 (ELF, 266,972,344 bytes)
> **GIT_SHA**: `c6733ae1276880507ca0c5b053ae18fb0df090d6` | **Runtime**: Bun **v1.4.3** (standalone compiled, **ESM, code-split**)
> **Baseline**: [2.1.197](../2.1.197/overview.md) | **Canonical numbers**: [`bundle/_facts.md`](bundle/_facts.md)

## Context

This analysis lands **107 days and 103 patch numbers** after [2.1.197](../2.1.197/overview.md) (build
2026-06-29 → 2026-10-14). How many of those 103 numbers were actually published as releases is not
verified here. 2.1.197 was a consolidation release: same runtime shape, same agent fabric, more managed
resources. **2.1.300 is the first build in this series whose packaging itself changed.** The single 18 MB
CommonJS bundle is gone. In its place are a 24,477-byte ESM entry loader, 2,395 code-split chunks, and 252
separately embedded non-JS assets (skill corpora, prompt text, browser libraries, fonts, native addons, a
plugin SDK).

The headline shifts:

- **Packaging: CJS IIFE → code-split ESM**, 2,651 embedded files, lazy chunk loading, zstd-compressed
  assets. Runtime bumped **Bun v1.4.0 → v1.4.3** (`bun_version: "1.4.3"`, `cli.beauty.js:350265`).
- **Scale roughly doubled on every axis.** Flags 251 → **704**, telemetry events 1,181 → **1,944**,
  built-in tools 49 → **84** sites, env vars 526 → **1,018**, API path templates 177 → **347** (all
  2.1.197 figures are same-method recounts; see the table below).
- **Flags became a provenance-aware class.** Every read can return `{value, source}`, a new
  session-pinned reader exists, and **232 of 704** flags default to `true` (2.1.197: 30 of 251).
- **A new provider plane, `anthropicGoogleCloud`**, and a bundled `@anthropic-ai/sdk` jump from
  **0.94.0 → 0.128.0**.
- **The Haiku-class LLM Bash prefix classifier is gone.** Bash safety is deterministic now. The
  model-based layer that remains is a rebuilt auto-mode classifier.
- **A Claude 5.5 generation is the compiled default** (`claude-opus-5-5` on firstParty), and a remote,
  signed model catalog can override the compiled defaults.
- **The identity surface grew.** It has four persisted random identifiers plus a per-account ECDSA P-256
  device key that survives logout. None of it is hardware-derived.

If 2.1.197 was "same fabric, more managed resources," 2.1.300 is "the same fabric, repackaged as a lazily
linked module graph, with a plugin worker, a mod UI API, self-hosted runners and a much larger
remotely tunable surface."

## The packaging change: code-split ESM, 2,651 embedded files (NEW)

Verified from the binary and `bundle/manifest.tsv`:

| Property | 2.1.197 | 2.1.300 |
|---|---|---|
| Bundle header | `// @bun @bytecode @bun-cjs` + CJS wrapper `(function(exports, require, module, __filename, __dirname) {…` | `// @bun @bytecode` (`@bun-cjs` occurs 0 times in `cli.min.js`) |
| Application JS | 1 file, 18,097,818 bytes | **2,401 modules**, 46,253,541 bytes concatenated in `cli.min.js` |
| Embedded files | the bundle + 2 `.node` addons referenced by path (`image-processor.node`, `audio-capture.node`) | **2,651** records in the Bun module table |
| `.bun` ELF section | — (carved by offset) | file offset `0x5c93000`, **169,843,365** bytes, trailer `---- Bun! ----` (`readelf -S`) |
| JSC bytecode | yes (one blob) | **2,397** modules carry bytecode (`bytecode_bytes > 0` in the manifest) |
| Source maps | none | none |
| Beautified lines | 733,394 | **1,857,789** |

How the 2,651 files break down (manifest, by `name` and `in_concat`):

- **2,401 application modules in `cli.min.js`**: 2,395 `chunk-<hash>.js` chunks, the entry loader `cli`
  (module 6, 24,477 bytes), 3 worker/wrapper entries (`src/plugins/functionHooks/hooks-worker/hooks-worker.js`
  module 161, `audio-capture.js` module 9, `clipboard-napi.js` module 11), and 2 `.mjs` modules
  (`runner-scaffold-*.mjs`, `build-report-lite-*.mjs`).
- **250 files outside `cli.min.js`** (all in `bundle/modules/`): 139 `.zst` (zstd-compressed), 79 `.md`,
  25 `.txt`, 2 native addons (`clipboard-napi.node`, `audio-capture.node`), 2 fonts
  (`anthropicSans400.woff2`, `anthropicSerif400.woff2`), and 3 vendored browser libraries
  (`mermaid.min.js`, `chart.umd.min.js`, `hljsBundle.generated.min.js`).
- [Embedded Assets](embedded-assets.md) counts the **non-JS** records as 252 (its groups 4–16). That
  figure includes the 2 `.mjs` text assets, which are also in the concatenated JS.

What the split means in practice (details in [Architecture §1](architecture.md)):

- **Chunks import each other by absolute path.** For example,
  `import{oft,sft}from"/$bunfs/root/chunk-ppwns75t.js"`. There are 22,847 `from"/$bunfs/root/chunk-`
  occurrences in `cli.min.js`. Loading is mixed: static imports, 1,398 `import()` calls (708 distinct
  chunks), and 493 synchronous `import.meta.require` calls.
- **Exported names are global, local names are not.** A cross-chunk export such as `k` (flag read) or `i`
  (telemetry) means the same function everywhere it is imported. Chunk-local helpers reuse short names
  (`t`, `Tu`, `Jt`, …) with different meanings per chunk. Every citation in this analysis names the
  module when that matters.
- **Assets moved out of the JS.** Bundled skill docs and prompt preambles that 2.1.197 inlined as string
  literals now ship as separate, often zstd-compressed, files. They are read through
  `Bun.zstdDecompressSync` after a magic-number check `[40, 181, 47, 253]` (module 391
  `chunk-130x6yb8.js`, `cli.beauty.js:372879`, `:372901`). `zstdDecompress` occurs 0 times in 2.1.197.
  This is why the env/API/model counts below are computed over JS **plus** the decompressed text assets.
- **`image-processor.node` is REMOVED** (0 occurrences in 2.1.300 `cli.min.js`; replaced by Bun's native
  image API per [Architecture](architecture.md)). `clipboard-napi.node` is **NEW**.

## Methodology: module-graph extraction replaces the single-run carve

As before, **every claim is grounded in real function bodies**, not isolated strings. The extraction
method changed, though, because the old one could not work on this binary:

- **2.1.169 / 2.1.197** used a single-run carve (`2.1.197/bundle/carve.py`). One contiguous plaintext
  CommonJS bundle sat in the ELF, and the carve cut it out by byte offset (225,406,600 in 2.1.197).
- **2.1.300** has no single bundle to carve. [`bundle/extract.py`](bundle/extract.py) finds the `.bun`
  section from the ELF section headers, parses Bun's module table (a 32-byte `Offsets` struct and
  **2,651 records × 52 bytes**), and writes each embedded file out by name:
  - `cli.min.js`: every application JS module, concatenated in module-table order, each preceded by
    `//// ===== MODULE <id> <name> (<bytes> bytes) =====`. To find a line's module, search backwards
    for the nearest separator.
  - `manifest.tsv`: id, name, size, bytecode size, flags, sha256 and `in_concat` for every record.
  - `modules/`: every file not in `cli.min.js`. Each `.zst` also has a decompressed sibling.
- `cli.beauty.js` is `js-beautify@1.15.1 --indent-size 2` over `cli.min.js`. It is deterministic and not
  committed; [`bundle/README.md`](bundle/README.md) gives the command and the SHA-256 to check a rebuild
  against. Running `extract.py` on the binary reproduces `cli.min.js`, `manifest.tsv` and `modules/`
  byte-for-byte.
- **Counting is now module-aware.** A call counts as a flag read or event fire only in a module that
  imports the accessor from its defining chunk, or in the defining chunk itself. Readable names come
  from the build's own re-export maps (for example module 907 `chunk-e1ck0rsm.js`, `cli.beauty.js:879942`,
  which exports `k as getFeatureValue_CACHED_MAY_BE_STALE` and the rest of the GrowthBook API).
- **Both builds were recounted with the same scripts.** Where the recount differs from what 2.1.197
  published, both numbers are shown, and the delta is taken from the recount.

> Note: minified identifiers are mangled and change every build. The load-bearing remaps from 2.1.197:
> flag read `it`→`k`, refresh wrapper `J7`→`MG`, telemetry fire `q`→`i`, async fire `gy`→`Js`, tool factory
> `Ys`→`Jt`, provider selector `yr`→`Ie`, userID `vW`→`_M`, machineID `z5t`→`Umt`. The full map is in
> [`bundle/_facts.md`](bundle/_facts.md) §2. Tentative inferences are flagged in each per-topic report.

## Headline findings

| Dimension | 2.1.197 published | 2.1.197 recount | **2.1.300** | Δ (recount → 300) | Method |
|---|---|---|---|---|---|
| Feature flags | 243 | 251 | **704** | **+453** (519 new / 66 gone) | distinct `tengu_*` literal first arg to any GrowthBook accessor (`k`/`vr`/`vn`/`MG`/`rb`/`V9e`/`KC`/`Mj`/`JOr`) |
| Telemetry events | 1,163 | 1,181 | **1,944** | **+763** (817 new / 54 gone) | distinct `tengu_*` literal first arg to `i`/`Js`/`AA`/`NNt`/`_0t` |
| Built-in tools | 49 | 49 | **84** sites (~92 names) | **+35** sites | literal `Jt({…})` sites − `"mcp"` − `TestingPermission` |
| API path templates | 164 | 177 | **347** | **+170** (180 new / 10 gone) | distinct `/v1/*` + `/api/*`, placeholders → `{}` |
| Model ids | 61 | 61 | **62** | **+1** (8 new / 7 gone) | `claude-(family)-N…` / `claude-N…` regex |
| `CLAUDE_*` env vars | 470 | 470 | **946** | **+476** | `\bCLAUDE_[A-Z0-9_]+` over JS + text assets |
| `ANTHROPIC_*` env vars | 56 | 56 | **72** | **+16** | same corpus |
| Env vars total | 526 | 526 | **1,018** | **+492** | sum of the two rows above |
| Slash commands | 93 | 96 | **106** | **+10** (14 new / 4 gone) | literal `name:` on `local`/`local-jsx`/`prompt` objects |
| Flag/event name overlap | — | 2 | **6** | +4 | same `tengu_*` string as both a flag and an event |
| Runtime | Bun v1.4.0 | — | **Bun v1.4.3** | bump | `bun_version` `:350265` |
| Packaging | 1 CJS bundle | — | **ESM, 2,651 embedded files** | rewrite | module table via `extract.py` |

Every 2.1.300 number comes from [`bundle/_facts.md`](bundle/_facts.md) §1. Read these caveats before
citing them:

- **Corpus.** Env, API and model counts run over `cli.min.js` **plus the 243 decompressed text assets**,
  because 2.1.300 moved bundled docs out of the JS. The JS-only figures are `CLAUDE_*` 925,
  `ANTHROPIC_*` 69, API templates 338 and model ids 50. `ANALYSIS_CONTEXT.md`'s preliminary 925/69 are
  these JS-only numbers.
- **The env-var headline overstates real knobs.** Of the new names, 16 are prefix fragments, 34 are not
  read from the environment, and 53 are read only through a raw proxy that is backed by an empty map. See
  [Environment Variables](environment-variables.md).
- **Tools.** 4 of the 84 sites are parametric factories that build 11 tools. `Artifact` is built through
  a non-literal call. Expanding both gives **92 distinct names** (47 kept, 45 new, 2 removed). See
  [Tool Definitions](tool-definitions.md).
- The preliminary 692 flags / 1,924 events in `ANALYSIS_CONTEXT.md` came from a narrower accessor set;
  the recon pass corrected them to 704 / 1,944.

### What's behind the deltas

- **+453 flags, and defaults flipped.** The resolver is now a class `vf` in module 152
  `chunk-7rwjz6p0.js`. `vn(name, def)` (`:142861`) returns `{value, source}` with source `override` /
  `disabled` / `payload` / `fallback` / `disk`. `k` (`:142865`) is `vn(...).value`. `vr` (`:142869`)
  pins the first read per session, and `V9e` (`:142885`) checks the gate's own evaluation for "off"
  first. 17 reader registries get `k`/`vn`/`vr` injected (`:142994–143022`). 199 of the 519 new flags
  default on, so most of them are kill switches for code that runs by default. See
  [Feature Flags](feature-flags.md).
- **+763 events, and the pre-sink queue is bounded.** `i()` (`:47526`, module 73) enqueues
  `{eventName, metadata, async}` while no sink is attached. 2.1.197's queue was unbounded. 2.1.300 caps it
  at `u = 1000` (`:47489`) and drops the oldest entry, counting it in `droppedEventCount`. The Datadog
  client token was **not** rotated (byte-identical to 2.1.197). The Datadog allow-list grew 159 → 244
  names. New: a HIPAA-safe telemetry mode, a CCR worker OTLP relay and a plugin telemetry mod. See
  [Telemetry](telemetry.md).
- **+35 tool sites.** The largest new groups:
  - nine `self_hosted_runner_*` tools
  - artifact add-ons (`ArtifactComments`/`Data`/`Check`, `AppifactRepl`)
  - connector, plugin and skill discovery (`ListConnectors`, `SuggestConnectors`, `SearchMcpRegistry`,
    `SuggestPluginInstall`, `SuggestSkills`, List/Search Plugins/Skills)
  - memory-store tools (`memory_list`/`read`/`write`)
  - `EndConversation`, `SendFeedback`, `SendFile`, `SubagentHandback`, `ProposeGoal`, `ObserverReport`

  `TaskOutput` and `REPL` have no factory site. The factory `Jt` (`:208924`, module 243) gained a
  remote-execution path, so a tool call can be routed to a runner. See [Tool Definitions](tool-definitions.md).
- **+170 API templates.** The new surfaces:
  - `/v1/code/runners/self-hosted/*` (a full runner control plane)
  - `/v1/organizations/*` admin APIs (58 SDK builders)
  - `/v1/tunnels/*`, `/v1/dreams/*`
  - `/v1/design/{consent,grants,mcp}`
  - `/api/frame/*`, which grew from 5 to ~40 endpoints
  - absolute CCR worker paths `/v1/code/sessions/{}/worker/*`
  - `/v1/messages/cache_touch`

  `deploy/init` and `deploy/complete` are REMOVED. The bundled SDK is `bA="0.128.0"` (`:163860`); in
  2.1.197 it was `uY="0.94.0"` (2.1.197 `:4673`). See [API Endpoints](api-endpoints.md).
- **New provider plane.** `Ie()` (`:21727–21729`) checks for a gateway first, then runs the ternary
  bedrock → foundry → anthropicAws → **anthropicGoogleCloud** (`CLAUDE_CODE_USE_ANTHROPIC_GOOGLE_CLOUD`)
  → mantle → vertex → firstParty. `anthropicGoogleCloud` occurs **0** times in 2.1.197 `cli.min.js`. Its
  default host is `https://claude.googleapis.com`, and auth is a Google bearer token (ADC), never an API
  key. See [API Endpoints](api-endpoints.md) and [Architecture](architecture.md).
- **Models (+1 net).** NEW: `claude-opus-5`, `claude-opus-5-5`, `claude-sonnet-5-5`, `claude-haiku-5-5`,
  `claude-fable-5-1`, `claude-sonnet-4-5-v1`, plus the doc-prose tokens `claude-2` / `claude-2.x`. REMOVED:
  `claude-1.3`, `claude-1.3-100k`, the `-latest` aliases and three dated ids. The catalog now carries
  pricing tiers, and a remote catalog gated by `tengu_delegated_quail` (compiled default `{mode:"off"}`)
  can override the compiled defaults. See [Model References](model-references.md).
- **Slash commands (+10).** 14 NEW, among them `/artifacts`, `/restart`, `/skill-doctor`, `/subtask`,
  `/list-agents`, `/design-consent`, `/design-revoke` and `/import`. 4 gone from the command registry:
  `/doctor` became a bundled skill, `/review` and `/update` live on as aliases, and `/init-verifiers` is
  gone outright. A NEW `policyGate` property lets server-side org policy filter commands, and it fails
  closed when no policy verdict is available. See [Hidden Commands](hidden-commands.md).
- **Plans.** Opus becomes the default for Pro, Team and Enterprise and on Bedrock/Vertex. Usage-credit
  billing is per model. There are two new limit-relief products (`/low-priority`, `/limit-reset`) and a
  declarative 36-key org-policy registry. See [Plan and Tier Gating](plan-tier-gating.md).

## Analysis scope

This version's analysis is split across sibling reports:

- [Embedded Assets](embedded-assets.md) (**NEW for this version**): all 2,651 module-table records
  grouped by kind, loader and recipient; manifest flag decoding; the UTF-16LE text-asset gotcha
- [Architecture](architecture.md) (Bun v1.4.3, ESM chunk loading, the hooks worker, mods, native addons, daemon, bridge)
- [Feature Flags](feature-flags.md) (704 flags; the `vf` resolver class and source provenance)
- [Plan and Tier Gating](plan-tier-gating.md)
- [API Endpoints](api-endpoints.md) (self-hosted runners, admin APIs, tunnels, dreams, frame platform, `anthropicGoogleCloud`)
- [Telemetry](telemetry.md) (1,944 events in 53 categories; bounded pre-sink queue; Datadog hardening)
- [System Prompt](system-prompt.md) (three-layer composer `OR` → `Uln` → `fgt`; environment and identity moved to attachments)
- [Tool Definitions](tool-definitions.md) (84 sites / ~92 names; `Jt` factory with remote execution)
- [Security Model](security-model.md) (LLM prefix classifier REMOVED; rebuilt auto-mode classifier)
- [Model References](model-references.md) (Claude 5.5 generation; remote signed catalog)
- [Environment Variables](environment-variables.md) (1,018 `CLAUDE_*`/`ANTHROPIC_*`; 1,162-entry typed registry)
- [Hidden Commands](hidden-commands.md)
- [Codenames](codenames.md) (`violin`, `harbor_kite`, `teal_corbel`, `hearth`, and the `tengu_*` zoo)
- [Device Fingerprinting](device-fingerprinting.md) (four random ids and a device keypair; what leaves the machine)

Structured datasets are in [`data/`](data/). The extraction tooling and canonical facts are in
[`bundle/`](bundle/): [`extract.py`](bundle/extract.py), [`README.md`](bundle/README.md),
[`_facts.md`](bundle/_facts.md) and [`ANALYSIS_CONTEXT.md`](bundle/ANALYSIS_CONTEXT.md).

## Marquee: the binary became a module graph

The standout change in 2.1.300 is structural, and most of the other findings follow from it:

- **Start-up links only the path in use.** `claude --version` links 7 modules. The interactive REPL path
  statically links ~686 modules / 17,163,595 bytes, about 37% of the module bodies. Daemon, bridge,
  workflows, self-hosted runner and artifact tooling load on first use
  ([Architecture §1](architecture.md)). Whether this made start-up measurably faster is **not knowable
  from source**.
- **Worker threads became practical, and the first one is for plugins.** Build info carries
  `HOOKS_WORKER_URL: "/$bunfs/root/src/plugins/functionHooks/hooks-worker/hooks-worker.js"`
  (`cli.beauty.js:295`). The host spawns one `Worker` that runs every plugin's TypeScript hooks module in
  hardened `vm` realms. On Linux it profiles that thread's CPU time through `/proc/self/task/*`.
  `hooks-worker`, `functionHooks` and `SourceTextModule` occur 0 times in 2.1.197. Plugins can also draw UI
  ("mods": `Pane` / `AbovePrompt` sites), and they get a shipped `claude-code.d.ts` SDK plus `band.tsx` /
  `pane.tsx` templates ([Embedded Assets §5](embedded-assets.md)).
- **Prompt text and skills became files.** 252 non-JS records, 4,923,889 stored bytes, are each
  referenced exactly once by one loader module. Among them are the `claude-api` corpus (103 files), the
  auto-mode rule set (`permissions_external-*.txt`: 1 HARD / 72 SOFT / 17 ALLOW rules), the loop and
  ultraplan preambles, the Claude Test plugin toolkit (30 files) and the artifact/design/slides
  templates. A `strings`-only pass over the JS would now miss all of this. That is why
  [Embedded Assets](embedded-assets.md) exists.
- **Identity, re-verified on the new layout.** `_M` (`:115569`), `Umt` (`:115581`) and `rPo`
  (`:115596`) each produce `randomBytes(32).toString("hex")`, validated as 64-hex and persisted to the
  global config. They are random, not hardware-derived.
  - `userID` still leaves raw (Messages API `metadata.user_id`, 1P events, GrowthBook, OTel).
  - `machineID` leaves only as a 12-character prefix in error reports.
  - `summonSidKey` never leaves; it is used only as an HMAC key.
  - The NEW `remoteControlMachineId` (a UUID) is sent raw on `POST /v1/environments/bridge`.
  - The NEW per-account ECDSA P-256 device key is registered server-side and **survives logout**.

  Correction to `ANALYSIS_CONTEXT.md`: 2.1.197 already had `machineID` (`z5t`, 2.1.197 `:606453`), so it
  had two random ids, not one. See [Device Fingerprinting](device-fingerprinting.md).

The takeaway: the agent fabric from 2.1.169/2.1.197 is still there (teams, coordinator, daemon, bridge,
kairos, workflows). It is now a lazily linked graph of 2,401 modules with its prompts and skills shipped as
assets, a sandboxed plugin worker, and a flag system that reports where each value came from and mostly
defaults to on. A run of `strings` over this binary sees a fraction of what it does.
