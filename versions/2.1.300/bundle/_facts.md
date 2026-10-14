# Canonical Facts — Claude Code v2.1.300

> **SOURCE OF TRUTH for the v2.1.300 analysis.** Every other doc (overview, comparison, per-topic)
> MUST cite the numbers and symbols below. Computed directly from the extracted, beautified module graph.
>
> **Version**: 2.1.300 | **Build**: `2026-10-14T12:54:55Z` | **Platform**: Linux x86-64 (ELF, 266,972,344 bytes)
> **GIT_SHA**: `c6733ae1276880507ca0c5b053ae18fb0df090d6` | **Runtime**: Bun **v1.4.3** (was v1.4.0 in 2.1.197)
> **Packaging**: ESM, code-split. 2,651 embedded files (2,401 application JS modules + assets), no source maps.
> **Primary artifact**: `cli.beauty.js` (1,857,789 lines). `cli.min.js` = the 2,401 JS modules concatenated in
> module-table order, separated by `//// ===== MODULE <id> <name> =====` lines.
> **Baseline**: v2.1.197 (`../../2.1.197/bundle/_facts.md`).

---

## 1. Headline counts (vs 2.1.197)

Each row uses one script run identically over both builds. When that recount differs from the number
2.1.197 published, both are shown.

| Dimension | 2.1.197 published | 2.1.197 recount | **2.1.300** | Δ (recount → 300) | Method |
|---|---|---|---|---|---|
| **Feature flags** | 243 | **251** | **704** | **+453** | distinct `tengu_*` string literal passed as first argument to any public GrowthBook accessor (§1.1) |
| **Telemetry events** | 1,163 | **1,181** | **1,944** | **+763** | distinct `tengu_*` string literal passed as first argument to any public analytics emitter (§1.2) |
| **Built-in tools** | 49 | 49 | **84** | **+35** | literal tool-factory call sites, minus `"mcp"` and `TestingPermission`. There is no `eval_registered__` literal site in 300 (§1.3) |
| **`CLAUDE_*` env vars** | 470 | 470 | **946** | **+476** | distinct `\bCLAUDE_[A-Z0-9_]+` over app JS + embedded text assets (§1.4) |
| **`ANTHROPIC_*` env vars** | 56 | 56 | **72** | **+16** | distinct `\bANTHROPIC_[A-Z0-9_]+`, same corpus |
| **Env vars total** | 526 | 526 | **1,018** | **+492** | sum of the two rows above |
| **API path templates** | 164 | **177** | **347** | **+170** | distinct `/v1/*` + `/api/*` templates, placeholders normalised to `{}` (§1.5) |
| **Slash commands** | 93 | **96** | **106** | **+10** | distinct literal `name:` on a `type:"local"\|"local-jsx"\|"prompt"` command object (§1.6) |
| **Model ids** | 61 | **61** | **62** | **+1** | distinct `claude-(opus\|sonnet\|haiku\|fable)-N…` or `claude-N…` (§1.7) |

### Why a corpus matters (read this before citing env/API/model numbers)

The 2.1.197 `cli.min.js` was one bundle. Bundled skill docs were **inlined** in it: the string
`Claude Model Catalog` appears once in 2.1.197 `cli.min.js` and **zero** times in 2.1.300 `cli.min.js`.
In 2.1.300 those docs ship as separate assets in `bundle/modules/`. To compare like with like, the
grep-derived rows (env, API, models) for 2.1.300 run over **`cli.min.js` + the 243 decompressed text
assets in `modules/`**. That corpus leaves out `.zst` (each has a decompressed sibling), `.node`, fonts,
and the three vendored libraries (`mermaid.min.js`, `chart.umd.min.js`, `hljsBundle.generated.min.js`).
Those libraries are also absent from the 2.1.197 bundle (`Chart.js v` occurs 0 times there).

JS-only values for 2.1.300, if you need them: `CLAUDE_*` **925**, `ANTHROPIC_*` **69** (994 total),
API templates **338** (`/v1/*` 214), model ids **50** (family 36). The **925 / 69** figures in
`ANALYSIS_CONTEXT.md` are these JS-only numbers. They are correct, but they are not the apples-to-apples numbers.

### 1.1 Feature flags: accessor set (CONFIRMED and EXTENDED)

The readable-name re-export in module 907 `chunk-e1ck0rsm.js` (`cli.beauty.js:879942`) gives the
real names of the minified accessors. All of them are defined in module 152 `chunk-7rwjz6p0.js`:

| Symbol | Real name (module 907 alias) | Def line | Distinct literal flags | Call sites |
|---|---|---|---|---|
| `k(name, def)` | `getFeatureValue_CACHED_MAY_BE_STALE` | `:142865` | 634 | 698 (incl. 7 `...k(` spreads) |
| `vr(name, def)` | `getFeatureValue_SESSION_PINNED` | `:142869` | 44 | 45 (1 via alias) |
| `vn(name, def)` | `getFeatureValueWithSource_CACHED_MAY_BE_STALE` | `:142861` | 23 | 27 |
| `rb(name)` | `checkGate_CACHED_OR_BLOCKING` | `:142882` | 7 | 12 |
| `MG(name, def, _)` | `getFeatureValue_CACHED_WITH_REFRESH` | `:142879` | 7 | 7 |
| `V9e(name)` | `checkGate_OWN_OFF_FIRST` | `:142885` | 0 literal | — |
| **`KC(name, def)`** (ADDED) | `getDynamicConfig_CACHED_MAY_BE_STALE` (`= k`) | `:142994` | 4 | 4 |
| **`Mj(name, def)`** (ADDED) | `getDynamicConfig_BLOCKS_ON_INIT` (`= JOr`) | `:142990` | 3 | 3 |
| **`JOr(name, def)`** (ADDED) | `getFeatureValue_DEPRECATED` (`getFeatureValueBlocking`) | `:142857` | 1 | 1 |
| `Lxo(name)`, `QOr(name)` | `peekSessionPinnedFeatureValue`, `isGateOffInOwnEvaluation` | `:142875`, `:142889` | 0 literal | — |

- **Union = 704.** The preliminary accessor set (`k/vn/vr/MG/rb/V9e`) yields **692** with plain call
  matching, which reproduces `ANALYSIS_CONTEXT`. It yields **695** once the 7 `...k("tengu_…")` spread
  calls are matched (e.g. `cli.beauty.js:725198`, `:967217`, `:967880`). Adding `KC`/`Mj`/`JOr` and the
  destructured dynamic-import aliases (below) brings the total to **704**. The 9 names that only the full
  method catches are: `tengu_bridge_placeholder_sweep`, `tengu_bridge_repl_v2_config`,
  `tengu_bridge_unarchive_on_resume`, `tengu_desktop_upsell`, `tengu_juniper_relay_config`,
  `tengu_max_version_config`, `tengu_session_stable_address`, `tengu_startup_announcements`, `tengu_version_config`.
- **Destructured aliases count.** Lazy paths do
  `let {getFeatureValue_CACHED_MAY_BE_STALE: S} = await import("/$bunfs/root/chunk-e1ck0rsm.js")` and
  then call `S("tengu_…")`. Examples: the entry `cli` module at `:1150`→`:1154`
  (`tengu_noble_wozniak`), `Rs()` at `:1050397` (`tengu_bridge_placeholder_sweep`), and
  `OX()` at `:103974` (`getFeatureValue_SESSION_PINNED` → `tengu_session_stable_address`).
- **The match is module-aware.** A call counts only in a module that imports the accessor from its
  defining chunk, or in the defining chunk itself. Chunk-local helpers that reuse short names (`i`, `k`, `t`)
  are not counted. Example: module 23 `chunk-pz70czba.js` exports `t` = debug logger (`:7632`), and it
  is called with messages such as `"tengu_max_version_config has invalid version…"`.
- **2.1.197 recount (same method): 251.** 2.1.197's readable map is `it`=CACHED_MAY_BE_STALE,
  `J7`=CACHED_WITH_REFRESH, `sRn`=DEPRECATED, `ik`=getDynamicConfig_CACHED_MAY_BE_STALE,
  `Q7`=getDynamicConfig_BLOCKS_ON_INIT, `QYr`=checkSecurityRestrictionGate, `$U`=checkGate_CACHED_OR_BLOCKING.
  The published 243 covered only `it/J7/QYr/$U` with no spread. Running that narrow method again gives 243
  (244 with the `...it(` spread).
- **Churn (canonical sets):** 519 flags NEW, 66 REMOVED, 185 kept.
- **Wrapper-forwarded names (2.1.300 only, supplementary): 736 flags.** These are 32 more names that
  reach `k`/`vn`/`vr`/`Mj` through verified wrappers rather than a direct accessor call. They are excluded
  from the headline because 2.1.197 was never counted this way. The wrappers:
  - `da(name,{safe})` (module 201 `chunk-e6k0pk7h.js`, `:188448`, returns `!safe` only if
    `vn(...).source==="payload"`)
  - `Hn` / `lo` (array denylists over `k(name,[])`, `:1601974`, `:1590229`)
  - `PZe` (zod-parsed `k(name,null)`, `:526462`)
  - `Z3t` / `cfr` (env override then `vr`, `:491491`)
  - `O4s` (`f5(vn(name).source)`, `:280606`)
  - `BP` (React hook over `Mj`, `:1332247`)
  - registry readers: module 152's tail (`:142994–143022`) injects `k`/`vn`/`vr` into **17 reader
    registries** (`D$s, Sm, cw, sw, Z1s, kh, xw, kw, uy, LBs, Bw, BFs, zWs, J$s, jFs, Ww, my`). Examples are
    `N.read("tengu_tool_memory_cgroup")` `:51722`, `e("tengu_warm_sunrise")` `:101687` and
    `e("tengu_foamy_spring")` `:120228`.
  - `this.getFeatureValueWithSource("tengu_gb_eval_authed_enable")` inside the flag class `:134017`.
- Flags whose name is held in a variable/constant (e.g. `e(DB, !0)` `:133542`) are not literal first
  args and are not counted, in either build. For scale: distinct `tengu_*` string literals overall are
  2.1.197 **1,484** and 2.1.300 **3,056**.

### 1.2 Telemetry events: emitter set (CONFIRMED and EXTENDED)

| Symbol | Real name | Def line / module | Distinct literal events | Call sites |
|---|---|---|---|---|
| `i(name, md)` | `logEvent` | `:47526`, module 73 `chunk-62mje8eg.js` | 1,913 (+ alias) | 2,870 (+13 via alias) |
| `Js(name, md)` | `logEventAsync` | `:47538`, module 73 | 39 | 52 |
| **`AA(name, md)`** (ADDED) | `logEventTo1PAwaitable` | `:142375`, module 152 | 6 | 21 |
| **`NNt(name, md)`** (ADDED) | `logEventTo1P` | `:142353`, module 152 | 1 | 1 |
| **`_0t(name, md)`** (ADDED) | `trackDatadogEvent` | `:349779`, module 332 `chunk-c17p1pm2.js` | 1 | 1 |

- Readable aliases: `i as logEvent, Js as logEventAsync` (`:880378`); `NNt as logEventTo1P,
  AA as logEventTo1PAwaitable` (`:880069`); `_0t as trackDatadogEvent` (`:880192`).
- `AA`/`NNt` write straight to the first-party event logger and skip the `i()` sink queue.
  `_0t` sends only events that are in a hard-coded allowlist Set `O` (`:349582`) to the Datadog intake.
- **Union = 1,944.** `i`/`Js` alone give **1,929**, not the preliminary 1,924. All 1,929 match `"…"`
  double-quoted literals. There are no single-quoted or backtick literals, and none is a false positive
  from a chunk-local `i` (the module-aware and naive counts agree). The 15 names reachable only through
  `AA`/`NNt`/`_0t` or destructured `{logEvent: X}` aliases are the `tengu_daemon_*` install/control and
  crash events, the `tengu_device_hook*` events, `tengu_remote_tools_announce` /
  `tengu_remote_passthrough_published`, `tengu_wif_user_oauth_refresh_*`, `tengu_tui_optout_reason`
  and `tengu_bug_report_description`. Two examples of the destructured `{logEvent: X}` alias are
  `:1799470` and `:1800098`.
- **2.1.197 recount (same method): 1,181.** 2.1.197 also had `gy`=`logEventAsync` (20 events),
  `MU`=`logEventTo1PAwaitable` (5), `Nit`=`logEventTo1P` (1) and `gft`=`trackDatadogEvent` (1). The
  published 1,163 counted `q` only. Running `q`-only again gives 1,163 exactly.
- **Churn (canonical sets):** 817 events NEW, 54 REMOVED, 1,127 kept.
- **Wrapper-forwarded (supplementary): 1,964 events.** These are 20 more names sent through local
  forwarders into `i()`:
  - `C` (held-startup-telemetry gate, `:355793`)
  - `MPt` (`:418700`)
  - `iO` (`:422663`)
  - `kGe` (`:445319`)
  - `me` (plugin CLI, `:1654110`)
  - `mo` / `J` (`:584278`, `:1029487`)
  - `v = i` default parameter (`:848706`)

### 1.3 Flag/event name overlap: 6 names (2.1.197 had 2)

The same `tengu_*` string serves as a feature's own gate key and as its telemetry event name. These are
not mis-parses. Both calls are real:

| Name | Flag read | Event fire |
|---|---|---|
| `tengu_ccr_orphan_restore_wake` | `enabled: k(…, !0)` `:1507734` | `i(…)` `:1507744` |
| `tengu_copper_lantern` | `k(…, !1)` `:368798` | `i(…, {})` `:652916`. Also listed in the Datadog allowlist `O` `:349582` |
| `tengu_event_loop_stall` | `remoteFlag: () => k(…, !1) === !0` `:672854` | `i(…, {stall_duration_ms, …})` `:1469288` |
| `tengu_mcp_proxy_needs_approval_retry` | `k(…, !0)` `:1593453`, `:1606006` | `i(…)` `:1593471`, `:1606083` |
| `tengu_send_file` | `Gi() && k(…, !1)` `:818843` | `i(…)` `:1431989` … `:1432147` |
| `tengu_send_user_file` | `k(…, !0)` `:1442881` | `i(…)` `:1443103` |

The 2.1.197 overlap under the same method is `tengu_copper_lantern` and `tengu_send_user_file`. The
2.1.197 `_facts.md` calls the mechanisms "disjoint". That is true of the accessor functions, but not of
the name sets.

### 1.4 Built-in tools = 84

- The tool factory is **`Jt(spec)`**, `cli.beauty.js:208924`, in module 243 `chunk-181yxhab.js`. It was
  `Ys` in 2.1.197. It spreads defaults `yl` and adds `userFacingName: () => e.name` (`:209054–209057`).
- There are **86** module-aware `Jt({…})` literal call sites. The naive `Jt({` count is 92; the other 6
  are unrelated chunk-local `Jt`s, such as zod's `new Jt({type:"record"…})`. Subtracting the same
  non-tools as 2.1.197:
  - the generic `"mcp"` template (module `chunk-6kzyz5jz.js`)
  - `TestingPermission` (`Co`, `chunk-8y962bdx.js`)

  That leaves **84**. 2.1.300 has no `` `eval_registered__…` `` factory site: the prefix survives only in
  classifiers at `:136508`, `:361761` and `:1219178`.
- **Caveats (tentative, for the tools doc):** Four of the 84 sites are **parametric factories** that build
  11 tools in total:
  - `se`/`ae` in `chunk-2bj4r20r.js` → ListPlugins, ListSkills, SearchPlugins, SearchSkills
  - `m(e)` in `chunk-kg51pe87.js` `:1424322` → ArtifactComments, ArtifactData, ArtifactCheck
  - `d({name})` in `chunk-y2tvp62y.js` `:1432841` → `enable__mcp__claude-in-chrome`,
    `enable__mcp__remote-devices__Claude_Browser`, `enable__mcp__remote-devices__computer`, `request_computer`

  The **Artifact** tool (`cn="Artifact"`) is built through a non-literal call,
  `QE = Jt(Cc(cAn(O5o(zg,…))))` at `:1422795`, so the literal method misses it. Expanding the parametric
  sites and adding Artifact gives roughly **92 distinct tool names**. Treat that figure as an estimate.
  Nine `self_hosted_runner_*` tools are included in the 84 (module `chunk-9rf10hh1.js`).
- **Tool names absent from the 2.1.197 bundle** (exact `"Name"` string count = 0 there):
  - AppifactRepl, ClaudeDesign, EndConversation, FetchInboxMessage, GetTask
  - ListConnectors, ObserverReport, OfferChromeSetup, ProposeGoal, PublishPlugin
  - ReadNotifications, RefreshMcpTools, SearchMcpRegistry, SendFeedback, SendFile
  - SubagentHandback, SuggestConnectors, SuggestPluginInstall, SuggestSkills
  - `memory_list` / `memory_read` / `memory_write`, `propose_skills`, `self_hosted_runner_*`
  - List/Search Plugins/Skills, ArtifactComments/Data/Check, `request_computer`, `enable__mcp__*`

  `TaskOutput` and `REPL` (both in 2.1.197 `tools.yaml`) have no `Jt` site in 2.1.300. `GetTask` ("check on
  a background shell command by task ID") looks like TaskOutput's successor, but that is a **tentative**
  inference.

### 1.5 API path templates = 347

- Scanner: each `/v1/` or `/api/` occurrence that is not preceded by `[\w.-/]` is read greedily over
  `[A-Za-z0-9_./:%{}-]`. A `${…}` is consumed with balanced braces and becomes `{}`. Named params `{x}` and
  `:orgUUID` also become `{}`. Trailing `/.:` is stripped. Doc and asset extensions
  (`.md/.txt/.html/.json/.js/.css/.png/.svg/.yaml…`) and the bare `/v1` and `/api` are dropped.
- 2.1.197 under this scanner: **177** (`/v1/*` **111**, `/api/*` 66). The published 164 had `/v1/*` = 110.
  The script that produced 164 is not in the repo, so its exact `/api/*` rule cannot be reproduced. Use
  177 → 347 for the delta.
- 2.1.300: **347** (`/v1/*` 221, `/api/*` 126); JS-only 338. Against the 2.1.197 recount: **180 NEW,
  10 REMOVED**.
- Some of the new templates are noise from third-party clients: `/api/v2/rum` (Datadog), `/api/v4` (GitLab).
  So are doc examples that come only from assets: `/v1/chat/completions`, `/v1/example`. 2.1.197 had the
  same class of noise (e.g. `/api/v3`).

### 1.6 Slash commands = 106

- Method: for every `type:"local"|"local-jsx"|"prompt"`, take the enclosing object literal and read its
  top-level `name:`. Distinct string literals are counted. Same script on both builds: 2.1.197 = **96**
  (published 93), 2.1.300 = **106**.
- **NEW (14):** `__remote-workflow`, `artifacts`, `auto-mode-setup`, `bug`, `cloud-plugins`,
  `design-consent`, `design-revoke`, `import`, `list-agents`, `output-style`, `restart`, `skill-doctor`,
  `subtask`, `workflow-launch-exec`.
- **Gone from the command-object registry (4):** `doctor`, `init-verifiers`, `review`, `update`.
  - `doctor` is **MOVED**, not removed. It is now `Zs({name:"doctor", aliases:["checkup"], …})`, where
    `Zs` is re-exported as `registerBundledSkill` (`cli.beauty.js:880844`). Bundled skills are outside
    this method in both builds.
  - `update` survives only as the CLI subcommand (`--update`/`--upgrade` → `update` argv rewrite).
  - No `name:"review"` or `"init-verifiers"` command object exists in 2.1.300.
- 2.1.300 has 11 command objects whose name is an identifier, not a literal (2.1.197 had 4). They are
  not in either count.

### 1.7 Model ids = 62

- Regex `(?<![\w-])claude-(?:(opus|sonnet|haiku|fable)-[0-9][A-Za-z0-9.-]*|[0-9][A-Za-z0-9.-]*)`,
  with trailing `.-` stripped, reproduces 2.1.197 **exactly**: 61 total, 36 family.
- 2.1.300: **62** (family 40). JS-only it is 50. Twelve ids now live only in bundled `.md` assets,
  e.g. `claude-opus-4-7-fast`, `claude-opus-4-6-fast`, `claude-3-opus-20240229`. The in-code
  model→retirement-date table that 2.1.197 carried (`"claude-2.1":"July 21st, 2025"`, …) is no longer in
  2.1.300's JS.
- **NEW (8):** `claude-opus-5`, `claude-opus-5-5`, `claude-sonnet-5-5`, `claude-haiku-5-5`,
  `claude-fable-5-1`, `claude-sonnet-4-5-v1`, plus the doc-prose tokens `claude-2` and `claude-2.x`.
- **REMOVED (7):** `claude-1.3`, `claude-1.3-100k`, `claude-3-5-haiku-latest`,
  `claude-3-7-sonnet-latest`, `claude-4-opus-20250514`, `claude-haiku-4`, `claude-sonnet-4-6-20251114`.
  (`claude-instant-*` existed in 2.1.197 but the family regex never matched it, so it is not in either count.)

---

## 2. Per-build symbol map (this build only; minified names change every build)

Cross-chunk export names are global in 2.1.300. Chunk-local names (`t`, `e`, `Tu`, `Zs`, `Jt`…) are
reused with different meanings in different chunks, so check the module first.

| Role | 2.1.300 symbol | Line | Module | 2.1.197 was |
|---|---|---|---|---|
| Telemetry fire (sync) | `i(eventName, metadata)` | `:47526` | 73 `chunk-62mje8eg.js` | `q` |
| Telemetry fire (async) | `Js(eventName, metadata)` | `:47538` | 73 | `gy` |
| Sink attach | `KNo(sink)` → `attachAnalyticsSink` | `:47512` | 73 | — |
| 1P logger direct | `NNt` / `AA` (`logEventTo1P` / `…Awaitable`) | `:142353` / `:142375` | 152 `chunk-7rwjz6p0.js` | `Nit` / `MU` |
| Datadog track | `_0t` (`trackDatadogEvent`) | `:349779` | 332 `chunk-c17p1pm2.js` | `gft` |
| Flag read w/ provenance | `vn(name, def)` → `{value, source}` | `:142861` | 152 | — (NEW) |
| Flag read (primary) | `k(name, def)` = `vn(...).value` | `:142865` | 152 | `it` |
| Flag read, session-pinned | `vr(name, def)` (caches in `pinnedFeatureValues`) | `:142869` | 152 | — (NEW) |
| Flag read wrapper | `MG(name, def, _)` → `k` | `:142879` | 152 | `J7` |
| Flag read, blocking | `JOr` (`getFeatureValue_DEPRECATED`) | `:142857` | 152 | `sRn` |
| Dynamic config | `KC` (cached) / `Mj` (blocks on init) | `:142994` / `:142990` | 152 | `ik` / `Q7` |
| Async gate | `rb(name)` (`checkGate_CACHED_OR_BLOCKING`) | `:142882` | 152 | `$U` |
| Async gate, own-off-first | `V9e(name)` → `QOr(name) ? !1 : rb(name)` | `:142885` | 152 | — (NEW) |
| Source classifier | `f5(source)` (`isServedFeatureSource`) | `:142897` | 152 | — |
| Readable re-export map | `export { … }` of GrowthBook API | `:879942` | 907 `chunk-e1ck0rsm.js` | `ft(X,{…})` getters |
| Reader-injection tail | 17 `register(k\|vn\|vr)` calls | `:142994–143022` | 152 | — |
| Tool factory | `Jt(spec)` | `:208924` | 243 `chunk-181yxhab.js` | `Ys` |
| userID | `_M(e, seed)` | `:115569` | 152 | `vW` |
| machineID | `Umt(e)` | `:115581` | 152 | — (NEW) |
| summonSidKey | `rPo(e)` | `:115596` | 152 | — (NEW) |
| ID bootstrap | `Uee(e)` → `_M(e), Umt(e)` | `:115592` | 152 | — |
| Provider selector | `Ie()`: gateway check, then ternary | `:21726` (ternary `:21728`) | — | `yr()` |

---

## 3. Headline deltas vs 2.1.197 (with evidence)

- **Packaging rewrite: one CJS bundle became ESM code-split.** 2,651 embedded files and 2,401 JS
  modules, with chunks importing each other by absolute `/$bunfs/root/chunk-*.js` path. Header is
  `// @bun @bytecode` (no `@bun-cjs`). Bun v1.4.0 → **v1.4.3**. These facts come from
  `ANALYSIS_CONTEXT.md`. The consequence for counting: bundled docs moved out of the JS (§1).
- **Feature flags 251 → 704 (+453, ×2.8).** 519 NEW, 66 REMOVED. The flag reader is now a class with
  source provenance (`vn`), and two accessor kinds are NEW: session-pinned reads (`vr`) and
  "own-off-first" gates (`V9e`). 17 reader registries receive `k`/`vn`/`vr` by dependency injection
  (`:142994–143022`).
- **Telemetry events 1,181 → 1,944 (+763).** 817 NEW, 54 REMOVED. `i()` now **queues** events in a
  bounded queue until a sink attaches, instead of dropping them: max `u = 1000` entries, oldest shifted
  out with `droppedEventCount++` (`:47489–47502`). `KNo` flushes the queue on a microtask.
- **Flag/event name reuse grew from 2 to 6** (§1.3).
- **Built-in tools 49 → 84 (+35).** The largest new groups:
  - nine `self_hosted_runner_*` tools
  - artifact add-on tools (ArtifactComments/Data/Check, AppifactRepl)
  - connector, plugin and skill discovery (`ListConnectors`, `SuggestConnectors`, `SearchMcpRegistry`,
    `SuggestPluginInstall`, `SuggestSkills`, List/Search Plugins/Skills)
  - memory-store tools (`memory_list/read/write`)
  - `EndConversation`, `SendFeedback`, `SendFile`, `SubagentHandback`, `ProposeGoal`, `ObserverReport`
- **Env vars 526 → 1,018 (+492).** `CLAUDE_*` 470 → 946, `ANTHROPIC_*` 56 → 72. The new `ANTHROPIC_*`
  names include `ANTHROPIC_GOOGLE_CLOUD_{BASE_URL,LOCATION,PROJECT,WORKSPACE_ID}` (the new provider
  plane), `ANTHROPIC_FOUNDRY_AUTH_TOKEN`, `ANTHROPIC_DEFAULT_MODEL`, `ANTHROPIC_TELEMETRY_GROUP` and
  `ANTHROPIC_WORK_SECRET`. `ANTHROPIC_BEDROCK_MANTLE_API_KEY` is REMOVED. Caveat: the identifier grep
  also catches non-env constants. In 2.1.197 that included `CLAUDE_OPUS_4_8`; in 2.1.300's JS it includes
  12 `CLAUDE_*` and 2 `ANTHROPIC_*` names ending in `_`, which are prefix fragments. 2.1.197 had the
  same class of noise.
- **New provider plane `anthropicGoogleCloud`.** `Ie()` `:21726–21728`:
  gateway → bedrock → foundry → anthropicAws → **anthropicGoogleCloud** (`CLAUDE_CODE_USE_ANTHROPIC_GOOGLE_CLOUD`)
  → mantle → vertex → firstParty. The string `anthropicGoogleCloud` occurs **0** times in 2.1.197 `cli.min.js`.
- **API path templates 177 → 347 (+170).** The new surfaces:
  - `/v1/code/runners/self-hosted/*`
  - `/v1/organizations/*` admin APIs: api_keys, service_accounts, federation_issuers/rules, workspaces,
    invites, users, rate_limits
  - `/v1/tunnels/*`
  - `/v1/dreams/*`
  - `/v1/design/{consent,grants,mcp}`
  - many `/api/frame/*` endpoints (comments, blob, contract, types, versions, subscribe)
  - `/v1/code/sessions/{}/worker/*` (register, heartbeat, events, otlp, diagnostics)
  - `/v1/messages/cache_touch`
  - `/api/oauth/organizations/{}/plugin_ratings*`
- **Persistent install identifiers: four random ones (two NEW) plus a NEW device keypair.** `userID` (`_M`,
  was `vW`) and `machineID` (`Umt`, was `z5t` — both already present and documented in 2.1.197) now gain a
  `Ps` 64-hex validator. NEW: `summonSidKey` (`rPo`, `randomBytes(32)` hex) and `remoteControlMachineId`
  (`f7s`, `crypto.randomUUID()`, `:115613–115625`), plus a per-account ECDSA P-256 device key in
  `~/.claude/.device-keys.json` (`:999861`). All random, none hardware-derived; 0 occurrences of
  `summonSidKey`, `remoteControlMachineId`, `.device-keys.json` or `remote_devices` in 2.1.197.
  Transmission ([device-fingerprinting](../device-fingerprinting.md)): `userID` raw (Messages API metadata,
  1P events, GrowthBook, OTel, plugin telemetry); `machineID` only as a 12-hex `host_name_redacted` in
  error reports; `summonSidKey` never sent (HMAC key for the per-artifact summon `sid`);
  `remoteControlMachineId` raw as `machine_id` in `POST /v1/environments/bridge`; the device public key to
  `POST /api/organizations/:orgUUID/cowork/remote_devices`. *(Corrected after verification: an earlier brief
  wrongly said 2.1.197 had only one identifier.)*
- **Model ids 61 → 62 (+1 net, 8 new / 7 removed).** The Claude 5.5 generation appears (`claude-opus-5-5`,
  `claude-sonnet-5-5`, `claude-haiku-5-5`), along with `claude-opus-5` and `claude-fable-5-1`. Legacy
  `claude-1.x` and the `-latest` aliases are gone. The in-code deprecation-date table was dropped from the JS.
- **Slash commands 96 → 106 (+10).** 14 new, 4 gone. `/doctor` moved to a bundled skill.
