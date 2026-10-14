---
title: "Architecture Deep Dive"
version: "2.1.300"
baseline: "2.1.197"
build_time: "2026-10-14T12:54:55Z"
git_sha: "c6733ae1276880507ca0c5b053ae18fb0df090d6"
runtime: "Bun v1.4.3"
packaging: "ESM, code-split (2,651 embedded files)"
source: "bundle/cli.beauty.js (1,857,789 lines)"
---

# Architecture Deep Dive

> [Back to version index](../README.md)
>
> **Version**: 2.1.300 | **Build**: `2026-10-14T12:54:55Z` | **GIT_SHA**: `c6733ae1276880507ca0c5b053ae18fb0df090d6` | **Platform**: Linux x86-64 | **Runtime**: Bun **v1.4.3** (standalone compiled binary, **code-split ESM**)

This document covers Claude Code's internal architecture as reverse-engineered from the **beautified JavaScript extracted from the binary's embedded module graph** (`cli.beauty.js`, 1,857,789 lines), not from `strings`. Every claim cites a function name and a `cli.beauty.js:LINE`; where the module matters it is named as `module <id> <file>`. Sections are framed as **NEW / CHANGED / REMOVED / CARRIED vs 2.1.197**. A claim marked NEW was checked for absence in `../2.1.197/bundle/cli.beauty.js`, and the check is given inline.

Minified names are rebuilt every release. In 2.1.300, **exported names are stable across chunks** (so `k`, `i`, `vn` … are global), but chunk-local helpers reuse short names (`t`, `k`, `x`, `r`, `Ne`) with different meanings per chunk. Where a short name is local, the module it lives in is given. The per-build symbol map is in [`bundle/_facts.md`](bundle/_facts.md) §2. The load-bearing ones here are flag read `k` (was `it`), cached-with-refresh flag read `MG` (was `J7`), telemetry `i` (was `q`).

## Subsystem map (the 30-second view)

| Subsystem | What it is | 2.1.300 entry / gate | 2.1.197 |
|-----------|-----------|----------------------|---------|
| **Bun packaging** | Bun **v1.4.3** binary, **ESM, 2,401 JS modules**, lazy chunk loading | entry `Ge()` @ `528` (module 6 `cli`), main import @ `1321–1325` | one CJS bundle `// @bun @bytecode @bun-cjs` (**CHANGED**) |
| **Chunk loader** | `import()` / `import.meta.require()` of `/$bunfs/root/chunk-*.js`; zstd asset reader | `Ne = import.meta.require` @ `1408`; `tt()`/`Nyo()` @ `372879–372901` | `Promise.resolve().then(() => (init(), ns))` in-bundle (**CHANGED**) |
| **Hooks worker** | one `Worker` thread hosting every plugin's TS hooks module in hardened `vm` realms | `HOOKS_WORKER_URL` → `rJo()` @ `484533`; worker body module 161 @ `157037` | absent (**NEW**) |
| **Mods (pane/band)** | plugins drawing UI via `ui.render` into `Pane` / `AbovePrompt` sites | `plugin-authoring` skill `xe` @ `1536654`; templates via `Ne()` @ `1819726–1819730` | absent (**NEW**) |
| **Native addons** | `clipboard-napi.node` (Linux clipboard), `audio-capture.node` (voice) | loaders @ `343490`, `1822427` | `image-processor.node` + `audio-capture.node` (**CHANGED**) |
| **Image pipeline** | Bun-native `Bun.Image` replaces the embedded image addon | `Me()` @ `363474` | `image-processor.node` + sharp (**CHANGED**) |
| **Agent teams** | teammates (swarms) | `es()` @ `346198`, `tengu_amber_flint` default ON | `ll()` @ `292358` (**CARRIED**) |
| **Coordinator mode** | orchestrator-of-workers persona | `ra()` @ `199545`, prompt `WJs()` @ `372583` | `Jv()` @ `225052` (**CHANGED** prompt) |
| **Background daemon** | systemd/launchd supervisor + worker pool + PTY host + spare/preload processes | argv fast paths @ `650–709`, `daemonMain` @ `780–796`; takeover `Un()` @ `644580` | same pieces, one bundle (**CHANGED** takeover rule) |
| **Agents view (fleet)** | `claude agents` full-screen session manager | `mv()` @ `368763`; fast path @ `927–1195` | `ak()` @ `145683` (**CARRIED**) |
| **Remote control / bridge** | claude.ai / mobile drives a local session | `remote-control|rc|remote|sync|bridge` @ `710`; `n_o()` (createBridgeSession) @ `199173` | `createBridgeSession` @ `456662` (**CHANGED**: v1alpha2 path) |
| **kairos loops / scheduling** | `/loop`, `ScheduleWakeup`, cron, monitors | `fl="ScheduleWakeup"` @ `344981`, `PC()` @ `369681` | `Ah` @ `223995`, `R$()` @ `224837` (**CARRIED**; preambles moved to assets) |
| **Workflows VM** | deterministic, VM-sandboxed multi-agent scripts | `W()` @ `162182`, `WorkflowTool` registered @ `743753`, VM @ module 1036 | `o2d()` @ `146634` (**CHANGED**: no string-eval realm left) |

The 2.1.197 doc described "the same distributed runtime" carried from 2.1.169 with a runtime bump. **2.1.300 is the first build in this series whose packaging itself changed.** The single 18 MB CommonJS IIFE became a 24,477-byte ESM loader plus 2,395 lazily loaded chunks. A first-party **worker thread** for plugin code appears, as does a TypeScript plugin API ("function hooks") that can draw UI ("mods"). The daemon, bridge, teams, kairos and workflows subsystems are still present, and each now loads as its own chunk subgraph on first use.

---

## 1. Bun 1.4.3, ESM and code splitting

### 1.1 What is embedded

From `bundle/manifest.tsv` (2,651 rows, verified by recount):

| Kind | Count | Notes |
|---|---|---|
| `chunk-<hash>.js` | **2,395** | code-split application chunks |
| other app `.js` | 4 | module 6 `cli` (no extension, entry), module 9 `audio-capture.js`, module 11 `clipboard-napi.js`, module 161 `src/plugins/functionHooks/hooks-worker/hooks-worker.js` |
| `.mjs` (in concat) | 2 | `runner-scaffold-*.mjs`, `build-report-lite-*.mjs` |
| vendored `.js` (not in concat) | 3 | `mermaid.min.js`, `chart.umd.min.js`, `hljsBundle.generated.min.js` |
| `.zst` / `.md` / `.txt` | 139 / 79 / 25 | assets (skills, prompts, templates) |
| `.node` | 2 | `clipboard-napi.node` (1,072,864 B), `audio-capture.node` (492,368 B) |
| fonts (`.asset`) | 2 | `anthropicSans400.woff2`, `anthropicSerif400.woff2` |

2,397 modules carry JSC bytecode (`bytecode_bytes > 0`). That figure agrees with `ANALYSIS_CONTEXT.md`.

> **Count correction (verified):** `ANALYSIS_CONTEXT.md` and the task brief say "2,399 `chunk-<hash>.js`". The manifest has **2,395** names matching `^chunk-[a-z0-9]+\.js$`. 2,399 is the number of application `.js` modules that are *not* `.mjs` (2,395 chunks + `cli` + the two addon wrappers + `hooks-worker.js`). The total of 2,401 application JS modules in `cli.min.js` is correct.

Every chunk starts with `// @bun @bytecode`; there is no `@bun-cjs` and no `(function(exports, require, module, __filename, __dirname)` wrapper (entry header `cli.beauty.js:428`). 2.1.197's first line was `// @bun @bytecode @bun-cjs` followed by the CJS IIFE (verified with `head` on `2.1.197/bundle/cli.min.js`). **CHANGED.**

### 1.2 Evidence the runtime is Bun 1.4.3

- `cli.beauty.js:350265`: `bun_version: "1.4.3"` on the Datadog metrics payload. The `ddtags` template at `:350242` carries `bun_version:1.4.3`. 2.1.197 had `1.4.0` at `299451`/`299474`.
- `cli.beauty.js:305847`: the keybinding capability check is the same as 2.1.197 `174400`, but the literal is now `jCo("1.4.3", ">=1.2.23")` on native Bun (`Gv()`), and `process.versions.node` is gated otherwise.
- `cli.beauty.js:136711`: **NEW** `FKn() { return Gw("1.4.3", "1.4.0") }`, where `Gw(a,b)` is `semverCompare(a,b) >= 0` (`:124117`). Its callers turn on **stall-detecting streamed uploads**: `yA(body, {stallMs, tailFloorMs, signal})` at `:138871`, with a fallback to a buffered body and a size-scaled timeout. A second caller is at `:1455290`/`:1455337`. The build bakes its own Bun version into a feature check, so on this binary the check is always true.

### 1.3 Startup: a 24 KB loader with fast paths

Module 6 `cli` statically imports only **6 chunks** (`cli.beauty.js:438–459`). Its static closure is **7 modules / 35,804 bytes** of minified JS, computed by walking `import … from "/$bunfs/root/…"` edges in `cli.min.js`. Everything else is reached through `await import("/$bunfs/root/chunk-….js")` from `Ge()` (`:528`), and each argv shape loads only its own subgraph:

| Order | Trigger | Chunk(s) loaded | Line |
|---|---|---|---|
| 1 | `CCR_AGENT_PROXY_TOKEN_FILE_DESCRIPTOR` or `--session-tunnel` | `guardRelayTokenDescriptor` (sync `import.meta.require`) | `529–534` |
| 2 | `--gh-standin <port> <ca> -- …` (per-session `gh` shim; `dHs()` @ module 4) | `ghStandinMain` | `535`, `578–592` |
| 3 | `--version` / `-v` | none (inlined build-info object) | `540–553` |
| 4 | `plugin test` | `loadFastPathPolicy`, `pluginTestMain` | `594–622` |
| 5 | `--eval-mock-server` | `runEvalMockServer` | `623–634` |
| 6 | `--claude-in-chrome-mcp` / `--chrome-native-host` | MCP server / native host | `635–649` |
| 7 | `--daemon-worker` / `--bg-pty-host` / `--bg-spare` / `--preload` | `runDaemonWorker` / `runPtyHost` / `runBgSpare` / `runPreload` | `650–709` |
| 8 | `remote-control`, `rc`, `remote`, `sync`, `bridge` | `startRemoteControl` (module 785) | `710–778` |
| 9 | `daemon …` (`iHs()` skips leading `--dangerously-skip-permissions`) | `daemonMain` (module 520) | `779–797` |
| 10 | `logs/attach/stop/kill/respawn/rm` or `--bg`/`--background` | bg session handlers (module 558) | `798–926` |
| 11 | `agents` positional, or `defaultToAgentsView` config | `mountFleetViewWithComposerBack` (module 853) | `927–1195` |
| 12 | `self-hosted-runner [orchestrator\|setup\|doctor\|code-sign\|decode-token]` | per-verb mains | `1196–1239` |
| 13 | `--tmux` + `--worktree` | `execIntoTmuxWorktree` | `1240–1298` |
| 14 | everything else | `configureZodForStartup`, then `main` from **module 777 `chunk-eprgt5fw.js`** | `1321–1325` |

NEW vs 2.1.197 (string count 0 there): `--eval-mock-server`, `pluginTestMain`, `self-hosted-runner`, `--gh-standin`, `CCR_AGENT_PROXY_TOKEN_FILE_DESCRIPTOR`. CARRIED (present in 2.1.197 at its tail, `733052+`): remote-control aliases, daemon, bg verbs, agents view, `--chrome-native-host`, `execIntoTmuxWorktree`. The dispatch order is the same; what changed is that each branch now pays only for its own chunks.

**Startup JIT policy (NEW).** 10 s after start, unless the process is a preload or spare, the loader calls `Bun.unsafe.setJITPolicy?.(1)`, or with `CLAUDE_CODE_JIT_POLICY_AFTER_STARTUP` set it imports `setJitPolicyAfterStartup` (`G8e()` @ `:834272`, value defaults to `1`). See `cli.beauty.js:574–577`. `setJITPolicy` occurs 0 times in 2.1.197. What policy value `1` means inside Bun is **not established** from this source.

### 1.4 How and when chunks load

Measured over `cli.min.js` (scratch script, module-aware split on the `//// ===== MODULE` separators):

| Mechanism | Occurrences | Distinct targets | Semantics |
|---|---|---|---|
| static `import … from "/$bunfs/root/…"` / `import "/$bunfs/root/…"` | — | — | eager, resolved when the importing chunk is linked |
| `import("/$bunfs/root/chunk-….js")` | **1,398** | **708** chunks | async, on first call of the code path |
| `import.meta.require("/$bunfs/root/…")` | **493** | **275** | **synchronous** load of an ESM chunk (Bun extension) |
| `Ne("/$bunfs/root/…")` (`Ne = import.meta.require`, module 7 @ `:1408`) | 108 | 108 | sync load of assets: 79 `.md`, 25 `.txt`, 2 `.node`, 2 `.mjs` |

Reachability: starting from `cli` and following static + dynamic + `import.meta.require` edges reaches **2,389 of 2,401** modules. The 12 not reached by a literal specifier are the two addon wrappers (`audio-capture.js`, `clipboard-napi.js`; the code imports their inner chunks directly), the two `.mjs` text assets, seven chunks, and `hooks-worker.js`. The hooks worker is reached through a `new Worker(url)` built from `HOOKS_WORKER_URL` (§2), not through an import.

The interactive path is still heavy. **Module 777's static closure is 686 modules / 17,163,595 bytes** of the 46,112,451 bytes of module bodies (≈37%). Everything else (daemon, bridge, workflows, self-hosted runner, artifact tools …) loads on demand.

Four loading idioms recur:

1. **Fast-path `await import()`** in the entry (table above).
2. **Call-time imports inside subsystems.** For example, `createBridgeSession` (`n_o` @ `:199173`) awaits nine separate `import()`s (`getClaudeAIOAuthTokens`/`getClaudeAIOAuthTokensAsync`, `getOrganizationUUID`, `getOauthConfig`, `sessionsApiWire`, `getMainLoopModel`, `getOriginalCwd`, axios (`default`), `isCcrV2BridgeCreateEnabled`, `isFirstPartyProvider`) before doing any work (`:199186–199207`).
3. **Lazy command loaders.** Slash commands carry `load: () => import("/$bunfs/root/chunk-….js").then(e => ({call: e.call}))`. That pattern occurs 48 times, e.g. `__remote-workflow` @ `:476399`. In 2.1.197 the equivalent was `Promise.resolve().then(() => (initFn(), ns))`, 573 occurrences in that file, against 2 in 2.1.300.
4. **Synchronous registry assembly.** The tool registry (module 638 `chunk-8y962bdx.js`) builds its array with `import.meta.require` (21 sites in `:743600–743740`). An example is `Pt = (() => (import.meta.require(".../chunk-7s21rcrt.js").initBundledWorkflows(), import.meta.require(".../chunk-n3zt8dj4.js").WorkflowTool))()` at `:743753`. The registry must be synchronous, so it cannot `await import()`.

**Facade chunks.** **463 chunks** contain nothing but imports and an `export {…}` list once comments are stripped. Module 523 `chunk-tzb4s83r.js` (`:653831`) is one: it re-exports 17 fleet/daemon gates from module 371 `chunk-kemhagvt.js` and adds ~110 side-effect `import "/$bunfs/root/…"` lines. *Tentative:* these look like Bun's dynamic-import entry facades. A facade guarantees that every side-effecting dependency of a lazily imported symbol is linked first. This is inferred from shape, not from Bun source.

**Compressed assets.** `chunk-130x6yb8.js` (module 391) reads an embedded file and checks the zstd magic `[40, 181, 47, 253]` (`0x28B52FFD`, `:372879`). It then runs `Bun.zstdDecompressSync` on it (`:372901`), or `Bun.zstdDecompress` in the async variant `uct()`. A missing asset throws `"embedded asset is missing or corrupt"`. `zstdDecompress` occurs 0 times in 2.1.197, where docs were inlined into the JS. **NEW.** This move is also why bundled-skill and prompt text no longer appears in `cli.min.js` (`_facts.md` §1).

### 1.5 Why this matters architecturally

- **Start-up cost scales with the path.** `claude --version` links 7 modules. A bg verb links the daemon client subgraph. Only the REPL/`main` path links ~686 modules eagerly. In 2.1.197 every path parsed (or bytecode-loaded) the whole 18 MB IIFE. Whether that was a measured win is not knowable from source; the `profileCheckpoint` marks (`cli_entry`, `cli_before_main_import`, `cli_after_main_import` @ `:571`, `:1321–1325`) are where it would be measured.
- **Stable export names.** Exports keep the same name across chunks, so a symbol such as `k` means the same function everywhere it is imported. This is what makes the global symbol map in `_facts.md` §2 possible.
- **Worker threads become practical.** A worker URL can now point at its own entry module, which links only what it needs (§2). Under the CJS IIFE, a worker would have had to re-evaluate the whole bundle.

---

## 2. The hooks worker (`src/plugins/functionHooks/hooks-worker`) — NEW

`hooks-worker`, `functionHooks`, `hooksModule` and `SourceTextModule` all occur **0** times in 2.1.197.

### 2.1 Spawning (host side, module 424 `chunk-538n62w8.js`)

- The build-info object carries `HOOKS_WORKER_URL: "/$bunfs/root/src/plugins/functionHooks/hooks-worker/hooks-worker.js"` (e.g. `:549`). `Knn()` (`:484459`) reads it, and `Gnn()` (`:484448`) turns it into a `file://` URL. On Windows, paths starting with `B:/~BUN/root/` (`Wnn` @ `:484446`) pass through unchanged. A source checkout falls back to `new URL("../../../hooks-worker/hooks-worker.ts", import.meta.url)` (`:484479`).
- `rJo()` (`:484533`) allocates two `SharedArrayBuffer`s (`stamp`, `marks`) and names the thread `hooks-<first uuid segment>` (`znn()` @ `:484455`). It then returns `{ worker: new Worker(url, {name, workerData:{stamp, marks}}), stamp, marks, thread }`.
- `thread` is `Znn(name)` (`:484518`). On Linux/WSL it finds the worker's OS thread by scanning `/proc/self/task/*/comm` for that name. It then reads `/proc/self/task/<tid>/stat` + `schedstat` to measure CPU time used and asleep/running state (`c3e()` @ `:484508`). In other words, the host profiles the plugin thread from the kernel's side.
- `VG = ton()` (`:484558`) is an injectable spawner/reloader registry (`setSpawner`, `spawnWorker`, `reloadModule`, `notifyLoaded`).
- `ahn()` (`:508901`) is the only caller of `VG.spawnWorker()`. It logs `"hooks worker spawned (one for every plugin)"` (`:508910`): **all plugins share a single worker**. It then sets up per-worker state: ports, in-flight dispatches, pending loads/builds/calls/presses, heartbeat (`ping`/`pong`), overrun tracking.
- Worker death: `O7e()` (`:508959`) maps a `close` event or an `ErrorEvent` to `"the hooks worker ended"` / `"the hooks worker died: …"`.

### 2.2 Worker body (module 161, `:157037–157765`)

`N(self)` installs a `postMessage` protocol (`:157439+`):

| Message in | Effect |
|---|---|
| `ping` | `pong` (heartbeat) |
| `load {environmentId, port, args}` | loads one plugin environment and returns `loaded {registered}` or `load_error` |
| `unload` / `build` / `resolve` | lifecycle and table resolution |
| `call` | `callInterface()`; the result must be structured-cloneable ("returned a value that is not plain data") |
| `dispatch` / `dispatch_stream` / `stream_pull` / `stream_close` | runs a hook chain for an event, unary or streamed |
| `next_*` | the host side of `next(e)` in a middleware chain |
| `press` / `press_release` | UI button presses routed to plugin handlers |
| `abort` | aborts a dispatch via `AbortController` |

Each plugin environment gets its own `MessagePort` for host ops (`op`, `op_pull`, `op_abort`), and `Atomics.store` into the shared `marks`/`stamp` arrays records progress (`M()` @ `:157419`, `R()` @ `:157423`). That lets the host detect an overrun without a round-trip. Unhandled rejections are posted back as `{type: "unhandled"}`.

### 2.3 Plugin code runs as ESM inside hardened `vm` realms

The runtime the worker imports (module 157 `chunk-va6mfypr.js`, 252 KB) holds:

- `DHs()` (`:155349`): `vm.createContext(sandbox, {codeGeneration: {strings: false, wasm: false}})`, then the hardening passes `lf`, `cf`, `t9e(ctx, uIe)`.
- `DAo()` (`:155209`): every plugin file is transpiled (`k2n`) and instantiated as a **`vm.SourceTextModule`** in that context. The module has its own linker, which resolves relative imports inside the plugin root and rejects others (`FAo` / `$Hs`). An entry module may not export `then` (`:155289`).
- `t9e()` (`:150995`) is **hardenVMIntrinsics**. It applies the same preamble 2.1.197 documented: it pins `Error.prepareStackTrace`, deletes `ShadowRealm`/`WebAssembly`/`FinalizationRegistry`/`WeakRef`/`Atomics`/`SharedArrayBuffer`/`queueMicrotask`/`$vm`/`gc`/…, applies SES-style `enableOverride`, then freezes intrinsics, `JSON`/`Math`/`Reflect`/`Proxy` and `globalThis.then` (`:150996–151080+`).

**CHANGED vs 2.1.197.** 2.1.197's preamble carried the comment "eval is NOT deleted here — hardenVMIntrinsics is shared with REPLTool (`codeGeneration:{strings:true}`)". In 2.1.300 that comment is gone (string count 0). No `strings: !0` context exists anywhere in the file. Every `createContext` that calls `t9e` passes `strings: !1, wasm: !1`: hooks (`:155340`), workflows (`:941776`, `:944151`), and the error-formatter realm `Ek()` (`:151270`). The REPL tool has no factory site (`_facts.md` §1.4). Every hardened realm in this build forbids string code generation.

### 2.4 Gate

`My = "tengu_plugin_hooks_modules"` (`:133710`), default `TC = !0` (**true**, `:185712`). `w_r()` (`:185788`) returns the default instead of the served value when the value differs from the default and either `FU()` holds or GrowthBook credentials are still in flux. Hooks modules can therefore be turned *off* remotely, but stay on until a served answer is trusted. The full predicate `AJt = d_() && !Sr("hooks") && !Ir()` (`:185797`) adds conditions whose exact meaning is **not dereferenced** (*tentative:* `Sr("hooks")` looks like a per-feature disable).

---

## 3. Mods: panes and bands (plugin UI) — NEW

A **mod** is a plugin whose hooks module subscribes to engine events through `register(on)` and can draw UI. 2.1.300 ships the authoring kit as a bundled skill and plugin:

- `plugin-authoring` skill (`xe` @ module 1803, `:1536654`): *"Make a mod: a change to Claude's own interface or behaviour, such as a live pane or panel, a band above the prompt, a status line, a toast, a slash command, or a hook on tool calls or prompts."* Its `files` callback (`Ne()` @ `:1536618`) emits `types/claude-code.d.ts` generated for this exact version (`pluginDeclarationsOf(VERSION, builtinToolSchemasOf(...))`), plus `examples/pane.tsx`, `pane-state.d.ts`, `band.tsx`, `band-state.d.ts`, `tool-call.ts` and `reference.md`.
- The templates are embedded text assets loaded synchronously: `Ne("/$bunfs/root/band.tsx-1v7nt0yx.txt")`, `Ne(".../pane.tsx-9v31e0jz.txt")` … (module 2268, `:1819726–1819736`). `reference.md` and `SKILL.md` are `.zst` assets decoded by `tt()`.
- The registering plugin is `cc-plugin-plugin-authoring` (`:1536673`), and it carries its **own** `hooksModule: CU(import.meta.dir, …)` (`:1536677`). There are **11** `hooksModule:` sites among built-in plugins (`:1525111` … `:1538421`). They include "Responsive mode" (`:1526808`), a "side agent watches your back" plugin (`:1532732`) and a "Security default" plugin seated outermost on managed machines (`:1537759`). Built-in features themselves now ship as function-hook plugins on the same engine.

**The API, from the embedded templates** (`bundle/modules/pane.tsx-9v31e0jz.txt`, `band.tsx-1v7nt0yx.txt`):

- `on('session.start' | 'tool.call' | 'prompt.submit' | 'turn.complete' | 'command.run' | 'ui.render', [filter], async ($, e, next) => …)`: middleware with `next(e)`.
- `$.command.register`, `$.ui.open({id, title})`, `$.ui.toast`, `$.ui.resolve(e)` → `{Box, Text, Button}`, `$.clock.now()`, plus `atom`/`read`/`update` for state.
- `on('ui.render', {component: 'Pane', requestId})` draws a **pane**; `on('ui.render', {component: 'AbovePrompt'})` draws the **band** above the composer.

Host-side evidence:

- The full event vocabulary `gIe` (`:70463`) has 40+ events, among them `tool.call`, `tool.check`, `ui.render`, `ui.press`, `prompt.submit`, `prompt.suggest`, `session.start`…`session.end`, `turn.start`/`turn.step`/`turn.complete`, `agent.spawn` and `telemetry.log`.
- Render sites `Qin` (`:96813`) are 15 components: `AskUserQuestion`, `UserMessage`, `AssistantMessage`, `ToolUse`, `ToolResult`, `ToolGroup`, `ToolProgress`, `CommandOutput`, `Spinner`, `TurnDuration`, `InfoNotice`, `SessionMode`, `PromptHint`, `AbovePrompt`, `Pane`.
- `Zy` (`:97099`): `Pane` and `AbovePrompt` are also *"a scrolling, focusable site a remote surface draws for the hooks engine"*, so mods render on remote surfaces, not only in the TUI.
- Button `onPress` handlers travel host → worker as `press` messages (§2.2).
- Sharing: the skill prompt picks surface-specific text (`Se()` @ `:1536604`): `CLOUD_SURFACE`, `HOSTED_SURFACE` or terminal. The "offer to share" text is gated by `Kn()` → `k("tengu_spicy_pearl", !1)` (default **false**, `Wn` @ `:1536592`).

---

## 4. Native addons

| Addon | Loader | Consumer | Behaviour |
|---|---|---|---|
| `clipboard-napi.node` (**NEW**; 0 occurrences in 2.1.197) | module 10 `rAo` = `C(() => Ne("/$bunfs/root/clipboard-napi.node"))` (`:1474`); resolver `x()` (`:343490`, module 313) falls back to `./vendor/clipboard-napi/x64-linux{,-musl}/…` | Linux clipboard class `N` (`probe()` @ `:343566`) | Probe order (`probe()`): Wayland → `wl-copy`; X11 → `xclip` → `xsel`; then **`addon`**, only if `k()` holds (`:343650`: `DISPLAY` matches `^(unix)?:`, or `WAYLAND_DISPLAY` is set) and `x()?.setLinuxClipboardText` exists. Write: `setLinuxClipboardText(text)` (`:343743`), and one failed write disables the addon. Read: `getLinuxClipboardText(e, timeout)` (`:343809`). The addon is a fallback for desktops without the CLI tools. |
| `audio-capture.node` (**CARRIED**) | module 8 `nAo` (`:1436`); resolver `r()` in module 2306 (`:1822427`) | voice mode, module 1885 (`:1559216`, logs `[voice] audio-capture-napi loaded in …ms`) | Exports `isNativeAudioAvailable`, `startNativeRecording`/`stopNativeRecording`, `startNativePlayback`/`stopNativePlayback`/`writeNativePlaybackData`, `microphoneAuthorizationStatus`. Recording constants `16000` Hz, mono (`:1559223`). The module also probes `arecord` and a forwarded socket at `~/.cache/coder-audio/{port,token}` (`:1559193`; `coder-audio` occurs 0 times in 2.1.197). |
| `image-processor.node` (**REMOVED**) | 2.1.197: `require("/$bunfs/root/image-processor.node")` @ 2.1.197 `:91` | — | 0 occurrences in 2.1.300. Replaced by **`Bun.Image`**: `Me()` (`:363474`, module 359) returns `new Bun.Image(buf)`, or with a pixel cap `new Bun.Image(r, {maxPixels: Re})`, wrapped in a sharp-like facade (`metadata/resize/rotate/jpeg/png/webp/toBuffer`, `C()` @ `:363450`). Images that are too costly to decode reject with `ERR_IMAGE_DECODE_FAILED`. `Bun.Image` occurs 0 times in 2.1.197. Which Bun release introduced `Bun.Image` is **not established** here. |
| `computer_use.node` (CARRIED, not embedded) | `Ne(process.env.COMPUTER_USE_SWIFT_NODE_PATH ?? …"../prebuilds/computer_use.node")` (`:749155`) | computer-use (macOS) | Same as 2.1.197 `:280646`. |

The two embedded wrappers have a fixed shape: a lazily evaluated CJS cell `C(fn)` around `import.meta.require` of the `.node` path (module 7's `C` @ `:1373`). A load failure is swallowed and the `vendor/` paths are tried next, so a missing addon degrades to "feature unavailable" instead of a crash.

---

## 5. Multi-agent teams & coordinator

### 5.1 Teams — `es()` (`:346198`, module 319), CARRIED

```js
function t() { return process.argv.includes("--agent-teams") }
function es() {
  if (!a.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS && !t()) return !1;
  if (!k("tengu_amber_flint", !0)) return !1;   // default TRUE
  return !0;
}
```

The policy is identical to 2.1.197 `ll()`. **CHANGED**: the teammate snapshot `Glo()` now `await import("/$bunfs/root/chunk-bccw1k1n.js")` only when `es()` holds (`:346203`). The agents-view fast path calls it as `captureTeammateModeSnapshotIfEnabled` (`:1118`). Readable export: `es as isAgentSwarmsEnabled` (`:617646`).

### 5.2 Coordinator gate — `ra()` (`:199545`, module 226), CARRIED

```js
function ra() {
  if (!$e(process.env.CLAUDE_CODE_COORDINATOR_MODE)) return !1;
  if (Xp() && !Un() && !a.CLAUDE_CODE_REMOTE) return !1;
  return !0;
}
```

This has the same shape as 2.1.197 `Jv()`, including the middle guard. The meaning of `Xp()`/`Un()` is still not dereferenced. `BJs()` (`:372527`) is the resume-time mode matcher: it fires `tengu_coordinator_mode_switched` and logs `coordinator_session_mode_match`. The `.mcp.json` `role: "comms"` extension (`:93316`) lets a coordinator's user-facing MCP server pass the tool filter; it is also present in 2.1.197.

### 5.3 Coordinator prompt — `WJs()` (`:372583`), CHANGED

The headline is unchanged (*"orchestrates software engineering tasks across multiple workers"*, `:372598`). The deltas:

- **Tool names CARRIED (not renamed).** Spawn is `Agent` (`ht = "Agent"` @ `:202137`), continue is `SendMessage` (`Dn` @ `:76810`), stop is `TaskStop` (`yd` @ `:345055`). 2.1.197's `Cup()` prompt already used the same three names (`is = "Agent"` 2.1.197 `:147686`, `Dy = "SendMessage"` `:224662`, `_P = "TaskStop"` `:224027`) and the same workflow line, *"prefer it over hand-orchestrating Agent calls"* (2.1.197 `:225131`); in 2.1.300 that line is gated by `Pg()`.
- **PR subscriptions now deliver CI green** (`:372615`): *"A fully-green push arrives as one `check_suite.completed` notice (once per push) — don't poll for CI green. Per-suite CI successes and new pushes do NOT arrive."* 2.1.197 said CI successes must be polled. `CI-green` occurs 0 times in 2.1.197.
- **Peer addressing changed.** Peers are now *"identified by a `name [ref]` — the name is the address"*, still discovered with **`ListAgents`** (`Ld` @ `:356123`; CARRIED, 2.1.197 `But = "ListAgents"` @ `:224820`) and reached with `SendMessage` (`:372590`). 2.1.197 described `uds:...` (same-machine) / `bridge:...` (Remote Control) address prefixes instead. The "input, not authority" rule for `<cross-session-message>` is kept, and peers are explicitly "**not your workers**". `name [ref]` occurs 0 times in 2.1.197.
- The task-notification schema now includes status `blocked` and summaries such as `"is waiting on its own background work"` and `"stopped at its N-turn limit"`.
- `jJs()` (`:372545`) keeps the **scratchpad directory** note for cross-worker files (`:372573`; CARRIED, 2.1.197 `:225121`). **NEW** is an instruction to have workers publish HTML pages through the artifact tool rather than `.md` when that tool is present.

---

## 6. Background agents & daemon

### 6.1 Processes

Each process role is now its own argv fast path that loads only its chunk (entry table §1.3):

| Role | argv | Chunk / function |
|---|---|---|
| supervisor | `daemon [run\|status\|stop\|…]` | module 520 `daemonMain` (`chunk-cd3mm6tm.js`, `:650394+`) |
| session worker | `--daemon-worker <id>` | module 860 `runDaemonWorker` |
| PTY host | `--bg-pty-host` | module 861 `runPtyHost` |
| pre-warmed spare | `--bg-spare` | module 778 `runBgSpare` |
| preload | `--preload` | module 780 `runPreload` |

Worker env (`:646325–646400`, module 509) is CARRIED with additions. It sets `CLAUDE_CODE_SESSION_KIND: "bg"`, `CLAUDE_BG_BACKEND: "daemon"` and `CLAUDE_BG_RENDEZVOUS_SOCK`, and sets `CLAUDE_BG_RV_AUTH` / `CLAUDE_BG_PTY_AUTH` when auth exists. **NEW** `CLAUDE_CODE_HOVER_REST: "1"` is set when `k("tengu_hover_rest", !1)` is on (default false; `tengu_hover_rest` occurs 0 times in 2.1.197). The entry consumes it as `pinStorageV5FromEnv()` (`:573`). In `exec` launches every `CLAUDE_*` / `OTEL_*` var except `CLAUDE_JOB_DIR`, `CLAUDE_CONFIG_DIR` and `CLAUDE_BG_PTY_AUTH` is stripped (`:646398`).

### 6.2 Service unit and gates

The systemd user unit text (`:641852`, module 502) is byte-for-byte the 2.1.197 template (`Description=Claude Daemon`, `Restart=always`, `ExecStart=… daemon --json-path … --log-file … --origin service`). The gates are CARRIED, all in module 371 (`:368763–368800`):

| Readable export (module 523 facade, `:653964`) | Body | Default |
|---|---|---|
| `isAgentsFleetEnabled` (`mv`) | `!(CLAUDE_CODE_DISABLE_AGENT_VIEW \|\| settings.disableAgentView === true)` | **on** (no flag) |
| `isDaemonCliEnabled` (`TYe`) | `mv()` | on |
| `isDaemonServiceInstallEnabled` (`AYe`) | `k("tengu_amber_anchor", !1)` | **off**; help then says *"Service install is disabled in this version — the daemon runs on demand and exits when the last client disconnects"* (`:652978`) |
| `isDaemonServiceRecalled` (`bdo`) | `k("tengu_copper_lantern", !1)` | off |
| `getDaemonColdStart` (`e_r`/`s`) | `k("tengu_quiet_harbor", !1) ? "ask" : "transient"` | transient |
| `isDaemonWorkerRegistryEnabled` (`j8`) | `return !1` | hard off |
| `isAgentsSimpleViewEnabled` (`_do`) | `CLAUDE_CODE_FLEETVIEW_SIMPLE \|\| k("tengu_fleetview_simple", !1)` | off |
| `isPastSessionsExperimentEnabled` (`JXt`) | `CLAUDE_CODE_FLEET_PAST_SESSIONS \|\| k("tengu_fleet_past_sessions", !1)` | off |

All three daemon flags have the same names and defaults as 2.1.197 (`:145705–145713`).

### 6.3 Binary takeover — `Un()` (`:644580`), CHANGED

The gate is still `k("tengu_bg_binary_takeover", !0)` (default ON). The decision changed:

- `Hn()` (`:644567`) retires a stale daemon only if its origin is `transient`, its version differs, and its **launch target** (`daemonTarget` vs `clientTarget = Lc().target`) differs. **Those three guards are CARRIED**: 2.1.197's comparator `Yrm()` (2.1.197 `:575443–575450`) opened with the identical `daemonOrigin !== "transient"`, `daemonVersion === clientVersion` and `daemonTarget === clientTarget` early returns. **What CHANGED is the final ordering test.** 2.1.197 used semver only when `daemonTarget` was absent and otherwise `clientMtimeMs > daemonMtimeMs`. 2.1.300 always compares versions, refusing across release channels (`DZe`) and for unparseable versions (`qjt`), then `n > e` / `je.gt(client, daemon)`. `clientMtimeMs` occurs 3 times in 2.1.197 and 0 times in 2.1.300.
- A second axis, **prefix takeover** (`Fn()` @ `:644661`), handles launcher-driven restarts (`prefixAxis: "attempted" | "took-over"`). If a raw daemon reappears after a launcher restart, it logs a contract violation and fires `tengu_bg_launcher_replacement_raw`.
- It refuses to kill a lock holder without a `procStart` identity (*"skipping stale-daemon retire — lock pid … has no procStart identity"*). It then escalates SIGTERM-wait → `SIGKILL` as before and fires `tengu_bg_daemon_binary_takeover {daemon_age_ms, via_prefix, via_version, daemon_version}` (`:644653`). 2.1.197 sent only `{daemon_age_ms}` (2.1.197 `:575498`). `via_prefix`, `via_version`, `prefixAxis`, `tengu_bg_launcher_replacement_raw` and the `procStart` guard text each occur 0 times in 2.1.197 (**NEW**).
- `nr()` (`:644675`) keeps the "bg disabled" detection (`tengu_bg_daemon_bg_disabled_skip`).

### 6.4 Supervisor

`daemonMain` writes `supervisor` log lines and starts workers from `daemon.json` (`Ct({jsonPath, …})`). It then fires `i("tengu_daemon_start", {worker_kinds, worker_count, origin})` (`:652885`) and runs the same yield/upgrade/displacement loop as 2.1.197. Examples: `"lockfile now held by pid=… — displaced, yielding"` (`:652904`) and `tengu_daemon_yield_takeover` (`:652612`). The subcommand set (`run/install/uninstall/start/stop/restart/status/logs/log/list/scheduled/remote-control/hub`, default `hub` on a TTY) is CARRIED (`:653022`; 2.1.197 `:732428`). The help text now documents **Remote Control servers** under the daemon: `remote-control list|add [--dir] [--name] [--spawn-mode same-dir|worktree]|remove`, where add/remove require the installed service (`:652982`). The string `remote-control add` occurs 0 times in 2.1.197.

---

## 7. Remote control / bridge

### 7.1 Entry (module 785 `chunk-eewy40cn.js`, `:817591+`)

`claude remote-control|rc|remote|sync|bridge` (aliases CARRIED). The flow is `enterRemoteControl` = `h()` → `b()` → `C()`:

1. `refuseRemoteControlLocally` (`h`): `settings.disableRemoteControl === true` → exit; no stored OAuth token → `BRIDGE_LOGIN_ERROR` plus debug info.
2. `refuseRemoteControlIneligible` (`b`): `getBridgeDisabledDiagnosis()` (logs an org policy denial as `allow_remote_control`), `checkBridgeMinVersion()` (`version_floor`), and `policyDeniedReason("allow_remote_control", …)`.
3. `startRemoteControl` (`C`): starts GrowthBook without blocking (*"feature gates keep serving the disk cache"* on failure), runs `preflightTrustedDeviceBlocking` (exit on an un-enrolled trusted device), then `bridgeMain(...)`.

Root options placed before `remote-control` that are not on the allow-list `E` are refused rather than silently dropped (`rootOptionsRefusedMessage`).

### 7.2 Session creation — `n_o()` (readable `createBridgeSession`, `:199173`, module 224), CHANGED

The first-party gate and token/org checks are CARRIED (`bridge_session_create_3p_provider`, `_no_token`, `_no_org` @ `:199208–199212`). **NEW**: an endpoint selector.

```js
Y = isCcrV2BridgeCreateEnabled() ? "v1alpha2" : "v1"      // :199203
// JJs(): k("tengu_ccr_v2_bridge_create_cli", !1)  — default FALSE   (:290073)
```

`fxo()` (`sessionsApiWire`, `:137623`) maps `"v1alpha2"` → `POST {BASE}/v1/code/sessions` (no beta header), and `"v1"` → `POST {BASE}/v1/sessions` with `anthropic-beta: ccr-byoc-2025-07-29` (`TOr` @ `:137621`). The v1alpha2 body is built by `UBn({title, worker, events, sources, outcomes, model, cwd, reuseOutcomeBranches: true, tags})`. The v1 body keeps 2.1.197's `session_context` + `source: "remote-control"`. `tengu_ccr_v2_bridge_create_cli` occurs 0 times in 2.1.197. 2.1.197 already used `v1alpha2` → `/v1/code/sessions` for another create path (2.1.197 `:361158`), but not for the bridge.

The bridge gate surface grew. The readable re-export at `:1040970` lists ~60 `isBridge*` / `isCcrV2*` / `isRemoteControl*` predicates, e.g. `isBridgeEnvReregisterOn401Enabled`, `isBridgeStateFramesEnabled`, `isCcrV2SessionCrudEnabled`, `isUdsEnableRemoteControlEnabled`. Environment registration (`POST /v1/environments/bridge`, `:1075758`) is CARRIED. Worker registration `/v1/code/sessions/{id}/worker/register` appears at `:600644` (self-hosted runner) and `:1044396`; see `api-endpoints.md` for the new `/worker/*` family.

---

## 8. kairos — loops & scheduling

### 8.1 `/loop` preambles moved to assets (CHANGED)

The autonomous-loop preambles are no longer JS string literals. They are embedded markdown loaded synchronously (`:1454104–1454105`, module 1734):

```js
var p = Ne("/$bunfs/root/loopAutonomousPreamble-07qcyhv4.md");
var y = Ne("/$bunfs/root/loopAutonomousPreamblePersistent-3zqtkrvg.md");
function c() { if (a.CLAUDE_CODE_LOOP_PERSISTENT) return !0; return k("tengu_kairos_loop_persistent", !1) }  // default FALSE
```

The *"You're a steward, not an initiator"* text is therefore absent from `cli.beauty.js` (0 occurrences). It is present in `bundle/modules/loopAutonomousPreamble-07qcyhv4.md`, so it is **MOVED**, not removed; the persistent variant does not contain it. `L()` appends cloud-session text when `CLAUDE_CODE_REMOTE` is set, and `I()` fires `tengu_kairos_loop_persistent_activated {variant}` (`:1454124`).

### 8.2 `ScheduleWakeup` (CARRIED)

`fl = "ScheduleWakeup"` (`:344981`). The schema clamps `delaySeconds` to `[60, 3600]` and echoes `wasClamped` (`:739186`, `:739195`). The cache-window guidance (*"**Don't pick 300s.**"*, `:345011`) and the `<<autonomous-loop-dynamic>>` sentinel (`$xe` @ `:344983`) survive.

### 8.3 Cron (CARRIED)

`PC()` (`:369681`): `!CLAUDE_CODE_DISABLE_CRON && MG("tengu_kairos_cron", !0, 300000)`. Durability is `JSe()` → `MG("tengu_kairos_cron_durable", !0, 300000)` (`:369685`), where `300000` ms is the `getFeatureValue_CACHED_WITH_REFRESH` refresh interval. Durable jobs persist to `.claude/scheduled_tasks.json` (`ygo()` @ `:369689`). Recurring jobs auto-expire after `Lxe = recurringMaxAgeMs / 86400000` days. The default is `recurringMaxAgeMs: 604800000` (**7 days**, `:369336`), overridable through `MG("tengu_kairos_cron_config", …)` (`:734100`). The *":00 and :30"* fleet guidance is intact (`:369723`).

---

## 9. Workflows — deterministic VM-sandboxed orchestration

### 9.1 Availability — `W()` (`:162182`, module 171), CARRIED with typed env

```js
function W() {
  if (a.CLAUDE_CODE_WORKFLOWS === !0) { let o = k("tengu_workflows_enabled", !0); return {available: o, defaultOn: o} }
  if (a.CLAUDE_CODE_WORKFLOWS === !1) return {available: !1, defaultOn: !1};
  if (!k("tengu_workflows_enabled", !0)) return {available: !1, defaultOn: !1};
  return {available: !0, defaultOn: Rr() !== "pro"};
}
```

The policy is the same as 2.1.197 `o2d()`, but `CLAUDE_CODE_WORKFLOWS` is now read from the pre-parsed env object `a` as a boolean, rather than through truthy/falsy helpers. The kill switch `$xs()` (`:162172`) disables workflows on `azn()`, or when policy `allow_workflows` is denied, or when `settings.enableWorkflows === false`, or when `CLAUDE_CODE_WORKFLOWS === false`, or when the flag is off.

### 9.2 Registration and launch

- The tool is registered synchronously: `initBundledWorkflows()` then `WorkflowTool` via `import.meta.require` (`:743753`, module 638).
- Launch in module 1722 `chunk-n3zt8dj4.js` fires `tengu_workflow_launched` with the 2.1.197 field set (`:1449435`).
- **NEW second launcher** (module 1037 `chunk-w9c55hyw.js`, `:945162`). It validates the script (`"workflow scripts must be deterministic: Date.now()/Math.random()/new Date() are unavailable (breaks resume)"`), mints `wf_<12 chars>` run IDs, and serves **server-launched** workflows. The new hidden commands `__remote-workflow` (`:476399`) and `workflow-launch-exec` (`:476411`) lazy-load it. The same module contains the refusal text *"Code review did not run: workflows are turned off in this machine's managed settings"*. *Tentative:* server-side code review runs as a workflow.

### 9.3 VM realm (module 1036 `chunk-y8czfwnk.js`)

The workflow context is `createContext({budget, setTimeout, clearTimeout, phase, log, console}, {codeGeneration: {strings: false, wasm: false}})`, followed by `En(F), t9e(F, uIe), vn(F)` (`:941765–941781`, again `:944145–944156`). It uses the same hardening as the hooks worker (§2.3). Optionally `sealSyncHooksInVM` seals synchronous hooks inside the realm.

---

## 10. How the pieces connect

```
                    ┌──────────── module 6 `cli` (24 KB, 7-module static closure) ────────────┐
argv ──► Ge() ──────┤ fast paths: --daemon-worker / --bg-pty-host / --bg-spare / --preload     │
                    │           daemon … ─► module 520 daemonMain (supervisor, systemd/launchd) │
                    │           remote-control ─► module 785 ─► bridgeMain ─► n_o() /v1|v1alpha2│
                    │           agents ─► module 853 fleet view ─► bg sessions via daemon       │
                    │           self-hosted-runner / plugin test / gh-standin / chrome host     │
                    └─► main (module 777, 686-module static closure) ─► REPL / -p             │
                                     │
             tool registry (module 638, import.meta.require) ── Agent / SendMessage / TaskStop /
                                     │                           ListAgents / Workflow / Cron* / ScheduleWakeup
                                     │
         plugin engine ── hooks host (module 424) ══ postMessage + SAB ══ hooks worker (module 161)
                                     │                                     └─ vm.SourceTextModule per plugin,
                                     │                                        hardened realm (t9e), no eval/wasm
                       ui.render ◄───┘  Pane / AbovePrompt (TUI or remote surface) ◄── mods
```

- **Daemon ↔ bridge.** The daemon's `remote-control` subcommands manage Remote Control servers (§6.4). Bridge sessions are created through the same cloud Sessions API used by `/v1/code/sessions` worker registration (§7.2).
- **Coordinator ↔ peers.** `ListAgents`/`SendMessage` address local sessions and Remote Control sessions by `name [ref]` (§5.3). The bg workers' rendezvous sockets (§6.1) are the local transport. *Tentative:* the mapping from a peer name to a socket was not traced end-to-end in this build.
- **Workflows ↔ hooks.** Both run user-supplied JS in `vm` realms hardened by `t9e()` and banned from string codegen and wasm. Workflows run in-thread with a budget; hooks run in the shared worker thread with heartbeat and CPU accounting.
- **Mods ↔ built-ins.** 11 built-in plugins are themselves hooks modules (§3), so the hooks worker is on the path of default behaviour, behind `tengu_plugin_hooks_modules` (default true).

---

## What's new / changed vs 2.1.197 — at a glance

| Area | 2.1.197 | 2.1.300 |
|------|---------|---------|
| **Packaging** | one CJS IIFE, `// @bun @bytecode @bun-cjs`, 18 MB | **ESM**, `// @bun @bytecode`; 2,401 JS modules (2,395 `chunk-*.js`), 2,651 embedded files; entry static closure 7 modules / 35,804 B |
| **Runtime** | Bun v1.4.0 | **Bun v1.4.3** (`:350265`); `FKn()` streamed-upload gate keyed on `1.4.3 ≥ 1.4.0` (`:136711`); `Bun.unsafe.setJITPolicy` after 10 s (`:574–577`) |
| **Lazy loading** | in-bundle `Promise.resolve().then(() => (init(), ns))` (573 sites) | 1,398 `import()` sites → 708 chunks; 493 `import.meta.require` → 275; 463 facade chunks |
| **Assets** | docs inlined in JS | 139 `.zst` + 79 `.md` + 25 `.txt`, read via `Ne()` / `Bun.zstdDecompressSync` (`:372901`) |
| **Plugin runtime** | settings/plugin hooks only; no function-hooks engine (`functionHooks` 0 occurrences) | **NEW** function-hooks engine: one shared `Worker` (`:508910`), `vm.SourceTextModule` per plugin (`:155209`), gate `tengu_plugin_hooks_modules` default true |
| **Mods** | — | **NEW** `ui.render` into `Pane` / `AbovePrompt` (`:97099`), 15 render components, `plugin-authoring` skill + templates, 11 built-in hooks-module plugins |
| **VM hardening** | shared with REPLTool (`strings:true`) | no `strings:true` realm left; hooks + workflows both `{strings:false, wasm:false}` |
| **Native addons** | `image-processor.node`, `audio-capture.node` | `clipboard-napi.node` (**NEW**, Linux clipboard fallback), `audio-capture.node` (carried); image work moved to **`Bun.Image`** (`:363474`) |
| Teams | `ll()` @ `292358` | `es()` @ `346198`, same policy; teammate snapshot lazily imported |
| Coordinator | `Jv()` + `Cup()` prompt (`Agent`/`SendMessage`/`TaskStop`, `ListAgents`), `uds:`/`bridge:` peers | `ra()` same gate; prompt `WJs()`: same tool names, peers addressed as `name [ref]`, **CI-green delivered**, `blocked` status |
| Daemon | takeover for `transient` daemons with a different launch target, ordered by binary mtime | same transient/target guards; ordered by **semver + release channel** (mtime dropped), plus a **NEW prefix** axis (`:644567`, `:644661`) |
| Bridge | `POST /v1/sessions` + `ccr-byoc-2025-07-29` | adds `v1alpha2` → `POST /v1/code/sessions` behind `tengu_ccr_v2_bridge_create_cli` (default false, `:290073`) |
| kairos | preambles in JS | preambles in `.md` assets (`:1454104`); cron 7-day max age (`:369336`), refresh 300000 ms |
| Workflows | `o2d()` | `W()` same policy; **NEW** server-launched path (`__remote-workflow`, `workflow-launch-exec`, module 1037) |
| New CLI fast paths | — | `self-hosted-runner …`, `plugin test`, `--eval-mock-server`, `--gh-standin`, CCR relay-token guard |

---

## Uncertainties / tentative inferences

- **Chunk count.** The manifest gives **2,395** `chunk-*.js`, not the 2,399 in `ANALYSIS_CONTEXT.md` and the brief (§1.1). The 2,401-module and 2,651-file totals agree.
- **Facade chunks** (463) are identified by shape only. Calling them Bun dynamic-import facades is an inference.
- **Bytecode use at runtime.** 2,397 modules ship bytecode, but whether JSC uses the cached bytecode or reparses source was not verified (same caveat as 2.1.197).
- **The 37% eager share** for `main` counts minified source bytes of module 777's static closure. It does not count bytecode bytes, nor chunks that `main` itself loads lazily during start-up.
- **JIT policy `1`.** What `Bun.unsafe.setJITPolicy(1)` does is not established from this source.
- **`Bun.Image` provenance.** Which Bun release introduced it is not established here; the source only shows that 2.1.300 uses it and 2.1.197 did not.
- **Hooks-modules gate details.** `AJt = d_() && !Sr("hooks") && !Ir()` (`:185797`): `Sr`/`Ir` are not dereferenced.
- **Coordinator guard** `Xp() && !Un() && !CLAUDE_CODE_REMOTE`: still not dereferenced (same as 2.1.197's `$x()`/`_a()`).
- **Peer transport.** Mapping a `name [ref]` peer to a UDS socket or a bridge session was not traced end-to-end.
- **Server-side code review via workflows** is inferred from the refusal strings in module 1037.
- **Module 424** (`chunk-538n62w8.js`, 4.9 MB, the largest chunk) holds the hooks host. What else it bundles was not catalogued.
