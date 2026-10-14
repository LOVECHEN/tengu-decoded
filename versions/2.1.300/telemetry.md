# Telemetry

> [Back to version index](../README.md)
>
> **Version**: 2.1.300 | **Build**: `2026-10-14T12:54:55Z` | **GIT_SHA**: `c6733ae1276880507ca0c5b053ae18fb0df090d6` | **Platform**: Linux x86-64 | **Runtime**: Bun 1.4.3

See [data/telemetry-events.yaml](data/telemetry-events.yaml) for the structured dataset. It lists all **1,944** canonical events (`bundle/_facts.md` §1.2) in **53 categories**, plus the 54 removed names. One of them, `tengu_remote_tool_classifier`, is visible only in `cli.min.js` because the beautifier mangled its line (§9).

Every claim cites the beautified source `bundle/cli.beauty.js:LINE`. 2.1.300 is ESM and code-split, so the module (`chunk-*.js`) is given where it matters. Minified names change on every build. Cross-chunk export names are global within this build; chunk-local names are not. Tags: **NEW**, **CHANGED** and **REMOVED** are relative to **2.1.197**, and each NEW claim was checked against `../2.1.197/bundle/cli.beauty.js`.

---

## 1. How an event flows (dispatch pipeline)

### 1.1 Emitters (module 73 `chunk-62mje8eg.js`)

| Symbol | Readable name | Line | 2.1.197 |
|---|---|---|---|
| `i(eventName, metadata)` | `logEvent` | `:47526` | `q` |
| `Js(eventName, metadata)` | `logEventAsync` | `:47538` | `gy` |
| `KNo(sink)` | attach sink | `:47512` | `yAr` |
| `FUt(obj)` | strip `_PROTO_*` keys | `:47479` | `AQe` |

`_facts.md` §1.2 gives these counts: **1,944 distinct `tengu_*` events**, 2,870 `i()` call sites plus 13 via an alias, and 52 `Js()` sites. Three other emitters bypass `i()`:

- `AA` / `NNt` (`logEventTo1PAwaitable` / `logEventTo1P`, module 152, `:142375` / `:142353`) write straight to the 1P logger.
- `_0t` (`trackDatadogEvent`, module 332, `:349779`) writes straight to Datadog.

### 1.2 Pre-sink queue (CHANGED: now bounded and drop-oldest)

```js
var u = 1000;                                                       // :47489
function l() { return { eventQueue: [], sink: null, droppedEventCount: 0 } }   // :47491
function s(t, e) { if (t.eventQueue.length >= u) t.eventQueue.shift(), t.droppedEventCount++;
                   t.eventQueue.push(e) }                           // :47499
```

- With no sink attached, `i()` / `Js()` enqueue `{eventName, metadata, async}` (`:47528–47534`, `:47540–47546`).
- **CHANGED:** the 2.1.197 queue (`fis()` / `q`, `2.1.197:4111–4150`) was **unbounded** and had no `droppedEventCount`. 2.1.300 caps it at **1,000** entries and evicts the oldest first.
- State is held in a `G` container and resolved through `ds(c)` = `c.of(y.host)`, the process-root host (module 19). Tentative: this makes the queue process-global rather than per-session.
- `KNo` returns `!1` if a sink is already attached (2.1.197 returned `undefined`). Otherwise it swaps the queue out and replays it on a **microtask** (`:47512–47524`).

### 1.3 The sink (module 468 `chunk-xbbmrbwk.js`)

`pQ()` → `KNo(y(p))` (`:620010`) installs `{logEvent: m, logEventAsync: v}` (`:620014`). `pQ` is called from the entry paths at `:620942`, `:621336`, `:653194`, `:861519` and `:876661`. For every event, the sync path `m` (`:619966`) and the async path `v` (`:619994`) do the following:

1. **Re-entrancy guard (UNCHANGED).** If `l` is set, the nested event is dropped with an error log: `logEvent reentered while collecting metadata` (`:619968`).
2. **Sampling (UNCHANGED logic).** `VOr(name)` (`:142266`) reads `tengu_event_sampling_config[name].sample_rate` via `KC` (`:142260`). `KOr` (`:142272`):
   - non-number or outside [0,1] → `null` (keep)
   - `>=1` → `null` (keep)
   - `<=0` → `0` (drop)
   - otherwise `Math.random() < rate ? rate : 0`

   A result of `0` drops the event. A kept fractional rate is stamped into the payload as `sample_rate`.
3. **NEW: wait for model-catalog mask hydration.** If `sxo()` is false (`:136561`: not diskless, mask not hydrated, retry window passed), emission waits on `N9e()` (`:136566`). `N9e` loads `~/.claude/cache/model-catalog/masked-ids.json` (`oxo`, `:136535`).
   - `oJt(metadata)` (module 410, `:378695`) → `IVn` (`:123322`) then rewrites model-id values in model-like keys (`model`, `*_model(s)`, `fallbackFrom`, …) through the mask.
   - Masked or unreleased model ids are therefore scrubbed **before** any backend sees them. Neither `masked-ids` nor `servedCatalog` appears in 2.1.197 (0 hits each).
4. **NEW: `tengu_quizzical_giraffe` stamp.** For 11 events in set `h` (`:619922`), `_()` (`:619933`) adds `tengu_quizzical_giraffe: "on"|"off"|"unset"`. The value comes from `vn()` provenance: `fallback`/`disabled` → `unset`. The 11 events are `tengu_started`, the OAuth-refresh lifecycle, `tengu_api_error`, `tengu_feature_bad` and `tengu_feature_sad`.
   - The same flag gates OAuth populate at init: `y = e.preparesSession !== !1 || k("tengu_quizzical_giraffe", !1) !== !0` (`:772820`).
   - Tentative: this looks like a staged rollout that is measured on auth-health events.
5. **Fan-out gate.** `g(r) = r || Oj()` (`:619949`), where `r = p()` is the Datadog switch:
   - `!LNt("datadog") && k("tengu_log_datadog_events", !1)` (`:619924`)
   - The event is processed only if Datadog **or** 1P is enabled.
6. **Datadog mirror.** `if (r) _0t(name, FUt(payload))` (`:619961`, `:620006`).
7. **1P.** `NNt(name, payload)` (sync, `:619962`) or `AA(...)` (awaited, `:620007`).

**Net effect (UNCHANGED):** in a default install, the only outbound destination for `tengu_*` events is Anthropic's first-party endpoint. Datadog is flag-gated and default **off**.

---

## 2. Telemetry stack

| Service | Purpose | Endpoint / sink | Default | Primary control |
|---|---|---|---|---|
| **1P event logging** (OTLP-logs SDK, custom exporter `Ap`) | Every `tengu_*` event plus GrowthBook exposures | `https://api.anthropic.com/api/event_logging/v2/batch`; `api-staging` when `ANTHROPIC_BASE_URL` is staging (`:141443–141444`) | **ON** when `Oj()` = `!iy()` | `DISABLE_TELEMETRY`, `DO_NOT_TRACK`, `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`; non-firstParty plane; gateway; **NEW** `CLAUDE_CODE_CUSTOM_OAUTH_URL`; remote kill `tengu_frond_boric.firstParty` |
| **Datadog logs** (module 332) | Mirror of a hard-coded allow-list of **244** names | `https://http-intake.logs.us5.datadoghq.com/api/v2/logs` (`:349576`), header `DD-API-KEY` (`:349658`) | **OFF** | flag `tengu_log_datadog_events` (default `!1`); kill `tengu_frond_boric.datadog`; BYOC suppression unless `CLAUDE_CODE_BYOC_ENABLE_DATADOG`; `CLAUDE_CODE_DATADOG_FLUSH_INTERVAL_MS`; **NEW** `CLAUDE_CODE_GZIP_DATADOG_LOGS` |
| **Datadog error tracking** (modules 331/333/334) | Crash and `logError` reports with stack, fingerprint, frames | `https://browser-intake-us5-datadoghq.com/api/v2/logs` (`:349907`), query `dd-api-key` (`:349926`) | **OFF** | flag `tengu_orford_ness` (default `!1`, `:349389`); `DISABLE_ERROR_REPORTING`; org restriction `allow_error_reporting`; min version `2.1.193` |
| **Org "BigQuery" metrics** (class `ge`, module 1771) | OTel metrics to Anthropic for API-console and Team/Enterprise orgs | `${BASE_API_URL}/api/claude_code/metrics` (`:1470494`); opt-in check at `/api/claude_code/organizations/metrics_enabled` (`:958017`) | ON when `Ve()` (`:1470484`) and the org has `metrics_logging_enabled` | kill-switch env (`LD()`); **NEW** interval flag `tengu_cozy_dusk` |
| **OpenTelemetry (user 3P)** (module 1771) | Metrics, logs and traces to the operator's own collector | `OTEL_EXPORTER_OTLP_*`; **NEW** CCR relay `/v1/code/sessions/{id}/worker/otlp/…` (`:194015`) | **OFF** | `CLAUDE_CODE_ENABLE_TELEMETRY` (`isTelemetryEnabled` `Nt`, `:1470670`) plus the `OTEL_*` family |
| **Plugin telemetry mod** (NEW, module 1802) | `$.telemetry.log` / `$.telemetry.mark` from plugins and mods → 1P rows | `https://api.anthropic.com/api/event_logging/v2/batch` (`:1534583`) | ON when `!iy()` (`isAvailable`, `:1534436`) | same opt-outs, re-implemented in `ne()` (`:1534612`) |
| **GrowthBook** | Flags (remote-eval) plus exposure logging on the 1P pipe | remote-eval at `https://api.anthropic.com/` (`BB`, `:133727`); SDK default `cdn.growthbook.io` (`:111391`) is overridden | ON when `Ng()` = `!DISABLE_GROWTHBOOK && Oj()` (`:142788`) | `DISABLE_GROWTHBOOK`; **NEW** `CLAUDE_CODE_GB_DISK_CACHE_WHEN_TELEMETRY_OFF` (`:142793`) |
| **Perfetto** | Local trace | none | **effectively OFF** in this build (§2.4) | `CLAUDE_CODE_PERFETTO_TRACE` |
| **Beta tracing (detailed)** | Detailed OTel spans | `BETA_TRACING_ENDPOINT` | **OFF** | `ENABLE_BETA_TRACING_DETAILED` + `BETA_TRACING_ENDPOINT` + not diskless, **and** (non-interactive **or** flag `tengu_trace_lantern`) (`WR`, `:286333`) |
| ~~Segment~~ | — | — | **ABSENT** (0 hits for `segment.io` / `api.segment` in both builds) | n/a |
| ~~Sentry SDK~~ | — | — | **ABSENT as a CLI client** (0 `@sentry` hits) | see §2.5 |

### 2.1 Changes vs 2.1.197

- **Datadog client token: NOT rotated.**
  - The literal is `uRr` (`:349577`), prefix `pubea56…`. It is byte-identical to the 2.1.197 token at `2.1.197:606714`, and the full 35-character string occurs exactly once in each build.
  - The same token is reused for the error-tracking intake (`:349926`).
  - Still US5. Defaults are unchanged:
    - flush **15,000 ms** (`F`, `:349578`)
    - batch **100** (`I`, `:349579`)
    - timeout **5,000 ms** (`M`, `:349580`)
- **GrowthBook client key: unchanged.** Prefix `sdk-zAZe…` (`HB`, `:133729`); one occurrence in each build.
- **Datadog allow-list: 159 → 244 names.** That is +95 and −10, with 235 `tengu_*` plus 9 `chrome_bridge_*`. Details in §5.
- **Datadog hardening (all NEW, 0 hits in 2.1.197):**
  - **Egress refusal backoff.** If a proxy refuses the host, posting stops for **300,000 ms** and the logs are dropped (`D`, `egressRefusedAt`, `:349649–349672`).
  - **Gzip.** Used when `CLAUDE_CODE_GZIP_DATADOG_LOGS ?? Dr()` is truthy. `Dr()` (module 121 `chunk-ft7q67h0.js`, `:92559`) is `CLAUDE_CODE_REMOTE === true && CLAUDE_CODE_ENVIRONMENT_KIND === undefined`, so gzip is on by default **only in CCR remote sessions** and off for a local CLI unless the variable is set. If the intake refuses gzip, it falls back to uncompressed and latches that choice (`:349653–349685`).
  - **MCP per-server rate limit.** At most 10 per 60 s per (event, server) pair, for the MCP events in list `q`, with a 200-key map that evicts the oldest-inserted key (`Z`) and a dropped counter reported as `droppedSinceLastForward` (`X`, `:349623`).
  - **Per-event field allow-lists.** `tengu_remote_tool_*` events forward only the listed fields (`z`, `:349583`).
  - **Hash/name field stripping.** 35 keys are removed (`N`, `:349601`).
  - **HIPAA-mode schema redaction.** `wNs` (`:136318`) applies when `txo()`.
  - **Per-feature sampling.** `tengu_feature_ok` is sampled per feature through flag `tengu_agile_glade` (`_e`, `:349766`).
- **Master gate CHANGED.** `iy()` (module 40, `:22061`) now also disables telemetry when `CLAUDE_CODE_CUSTOM_OAUTH_URL` is set (`RHr`, `:22057`). See §4.
- **NEW: HIPAA-safe telemetry mode** (§3.4). `hipaa_redacted` has 0 hits in 2.1.197 and 1 in 2.1.300.
- **NEW: diskless "tenant" mode for 1P.** This is the `claude-code-server` tenant (§2.2): no disk spool, a grant-gated send, and a `x-test-mode` header.
- **NEW: CCR worker OTLP relay** (§2.3).
- **NEW: plugin telemetry mod** (§2.6).
- **NEW: Claude Desktop/Cowork 3P policy schema is vendored in.**
  - It defines `disableEssentialTelemetry`, `disableNonessentialTelemetry` and `usageMetricsEnabled`, with `readers: ["desktop","code"]` (module 1481 `chunk-ds2x9wed.js`, `:1167648`, `:1167690`, `:1167765`).
  - No consumer outside module 1481 was found (`:1176473–1176476` is inside it). Whether the CLI honours these keys is **not established**.
  - `ANTHROPIC_TELEMETRY_GROUP` (`:1164207`) is an i18n label in that schema. It is **not** an environment variable, so the `_facts.md` §3 env-var list over-counts it.

### 2.2 1P pipeline internals (module 152 `chunk-7rwjz6p0.js`)

**Exporter class `Ap`** (`:141409`, was `BYr`). Constructor defaults (`:141444`):

| Setting | Default |
|---|---|
| timeout | 10,000 ms |
| `maxBatchSize` | 200 |
| `batchDelayMs` | 100 |
| `baseBackoffDelayMs` | 500 |
| `maxBackoffDelayMs` | 30,000 |
| `maxAttempts` | **8** |
| `oauthRefreshTimeoutMs` (`mW`) | 2,000 ms (NEW) |
| `keyHelperJoinTimeoutMs` (`_W`) | 3,000 ms (NEW) |

- Backoff is `min(max(base, base*attempts²), max)` (`:141806`).
- Only records with instrumentation scope `com.anthropic.claude_code.events` are exported (`:141726`).

**Provider setup.** `K1e(storageV5, grant)` (`:142458`) creates the provider.

- Batch config comes from GrowthBook `tengu_1p_event_batch_config` (`jC`, `:142281`). Recognised fields: `scheduledDelayMillis`, `maxExportBatchSize`, `maxQueueSize`, `skipAuth`, `maxAttempts`, `path`, `baseUrl`.
- Fallbacks:
  - delay ← `OTEL_LOGS_EXPORT_INTERVAL` or **10,000 ms** (`IW`)
  - batch **200** (`DW`)
  - queue **8,192** (`NW`); in diskless mode the queue is capped at **1,024** (`UC`, `FW`, `:142454`)
- Pre-init queue cap is **1,024** (`Dp`, `:142284`).
- Resource attributes: `service.name=claude-code`, `service.version=2.1.300` (`:142472–142484`), plus `wsl.version` on WSL.
- The batch config is re-read on every GrowthBook refresh (`reinitialize1PEventLoggingIfConfigChanged`, `LW`, `:142539`; wired at `:772816–772818`).

**Failed-event spool.**

- Default: `~/.claude/telemetry/1p_failed_events.<session>.<run>.json` (`vp`, `:141396`; `Er()`, `:141403`; path at `:141455`).
- **NEW:** when storage v5 is active (`z() && storageV5`), failures go to a v5 log stream instead (`namespace:"log", channel:"telemetry"`, `:141621–141626`). Legacy flat files are migrated into that stream (`migrateLegacyFlatBatches`, `:141653`).

**Sending.** `sendBatchWithRetry` (`:141953`):

- Headers are `Content-Type`, `User-Agent` and `x-service-name: claude-code`. Auth is attached only when `shouldSkipAuthForSend` allows it (`:141884`).
- **NEW:** if the endpoint host matches the WIF base URL, auth uses a workload-identity token (`authHeadersForSend`, `:141929`).
- If neither OAuth nor an API key applies, `bW()` (`:142190`) attaches the env `sk-ant-api…` / `sk-ant-oat…` credential on `api.anthropic.com` over https.
- A 401 is retried once **without** auth (`:142013–142022`).
- Ingest may return `accepted_count`; the difference is reported as `rejected_by_ingest` (`EW`, `:142231`; `:142010`).

**NEW: tenant grant (diskless `claude-code-server` mode).** `po()` = `me()` = diskless launch (`:134726`).

- Under a tenant (`underATenantsRules`, `:141900`), the exporter needs a `FirstPartyEventsGrant`. The default grant `yW()` is `mayPost: () => !1, sendMode: "dry_run"`; it drops everything and logs an error (`:142159–142170`).
- `sendMode` is one of `dry_run` / `test_mode` / `production` (`mk`, `:134729`). A non-production send adds the header `x-test-mode: true` (`:141992–141994`).
- Tenant mode also:
  - disables redirects (`maxRedirects: 0`)
  - persists nothing to disk
  - reports drops to the grant: `previous_run`, `refused`, `not_vouched`, `no_credential`, `no_store`, `given_up`, `unsent_at_exit`, `rejected_by_ingest`, `export_threw`
- The string `claude-code-server` has 16 hits in 2.1.300 and 0 in 2.1.197.

**Record emit.** `PW` (`:142328`) emits `body = event name` and `attributes = { event_name, event_id (uuid), core_metadata, user_metadata (pl(!0)), event_metadata, user_id (_M()) }`.

**Wire transform.** `transformLogsToEvents` (`:142032`) produces `ClaudeCodeInternalEvent` rows and `GrowthbookExperimentEvent` rows.

- `_PROTO_*` keys are lifted into first-class columns: `skill_name`, `plugin_name`, `marketplace_name`, `mcp_server_name`, `mcp_tool_name`, `head_sha`, `is_clean_tree_at_start`, `changed_file_count_at_start`, `untracked_file_count_at_start`. They are then removed from `additional_metadata` (`:142094–142128`).
- **NEW:** `_PROTO_git_remote_url` is destructured and **discarded**; it is never placed on the wire (`:142105`).
- `additional_metadata` is base64 JSON.

### 2.3 OpenTelemetry (user-configurable) and the CCR relay

- **Gate.** `isTelemetryEnabled` = `$e(CLAUDE_CODE_ENABLE_TELEMETRY)` (`Nt`, `:1470670`).
  - The init wrapper `OHe` (module "init", `:772934`) runs eagerly when `H1() || CLAUDE_CODE_ENABLE_TELEMETRY` is set. Otherwise it is deferred to a `telemetry_init` hook (`:814381–814385`).
  - **CHANGED:** when remote managed settings are pending (`Drr()`), init waits for the fetch first and logs `Waiting for remote managed settings fetch before telemetry init`. That string has 0 hits in 2.1.197.
- **NEW: CCR worker OTLP relay** (module 210, `:194015–194061`). In a CCR remote session (`CLAUDE_CODE_REMOTE` and no bridge carrier, `:194027`):
  - If `OTEL_EXPORTER_OTLP_{LOGS,METRICS}_ENDPOINT` equals `${SESSION_INGRESS_URL origin}/v1/code/sessions/${CLAUDE_CODE_REMOTE_SESSION_ID}/worker/otlp/{customer/logs | customer/metrics | metrics}`, the exporter sends there.
  - Its auth header comes from `CLAUDE_CODE_SESSION_ACCESS_TOKEN` (`:1470716`).
  - Traces may target `/worker/otlp/traces` (`sCr`, `:194071`).
  - The path is ignored if the user set their own `OTEL_EXPORTER_OTLP_*_HEADERS` (`Ovo`, `:194036`).
  - `worker/otlp` has 0 hits in 2.1.197.
- **NEW: gateway-named collector.** When the Cloud gateway's managed settings name the collector, batches are dropped once that gateway session ends (`:1470716–1470722`, tentative reading).
- **New CC-specific variables vs 2.1.197** (identifier diff over `cli.min.js`):
  - `CLAUDE_CODE_OTEL_CONTENT_MAX_LENGTH`: default **61,440** chars (`Nt`, `:286293`), clamped by the three OTel attribute-length limits (`:286296`).
  - `OTEL_LOG_MANAGED_SETTINGS` (`:799827–799833`).
  - `OTEL_METRICS_INCLUDE_REPOSITORY`: default `!1` (`:194378`, `:194455`).
  - The `OTEL_EXPORTER_OTLP_{LOGS,METRICS,TRACES,PROFILES}_{CERTIFICATE,CLIENT_*,COMPRESSION,INSECURE}` family. Tentative: this is most likely the vendored OTel SDK upgrade, not CC logic.
- **Content redaction.** User prompts in spans are still `<REDACTED>` unless `OTEL_LOG_USER_PROMPTS` is set. The opt-in set is `OTEL_LOG_RAW_API_BODIES`, `OTEL_LOG_USER_PROMPTS`, `OTEL_LOG_ASSISTANT_RESPONSES`, `OTEL_LOG_TOOL_CONTENT`, `OTEL_LOG_TOOL_DETAILS`, `OTEL_LOG_MANAGED_SETTINGS` (`kl`, `:35281`).
- **Enhanced telemetry.** `CLAUDE_CODE_ENHANCED_TELEMETRY_BETA ?? ENABLE_ENHANCED_TELEMETRY_BETA` (`Puo`, `:286719`).
- **Org "BigQuery" metrics exporter** (`ge`, `:1470490`). It runs inside the same telemetry init whenever `Ve()` holds (`:1470674`). The exporter existed in 2.1.197 (`2.1.197:306706`) but the 2.1.197 doc did not list it.
  - `Ve()` = `!LD() && (O9e() || (kt() && sub ∈ {enterprise, team}))` (`:1470484`). `O9e()` = firstParty plane and not claude.ai auth, i.e. API-console users (`:130888`).
  - **NEW:** the export interval is GrowthBook `tengu_cozy_dusk`, default **300,000 ms**, clamped to [300,000, 3,600,000] (`Dt`, `Pe`/`Lt`, `:1470602`, `:1470670`). The flag has 0 hits in 2.1.197, where the interval was a hard-coded 300,000 ms (`ZJp`, `2.1.197:337815`). The default is unchanged; only the remote tunability is new.

### 2.4 Perfetto: effectively dead in this build (inferred)

`Oys()` (`:286633`) only logs `[Perfetto] initializePerfettoTracing called, env value: …`. Its recorder getter `E()` returns `zt.of(j().host).recorder`, which starts as `null` (`:286625`). No assignment to that container's `recorder` was found: the one `.recorder =` hit, at `:761330`, belongs to an unrelated class.

2.1.197 had the same log-only initializer (`2.1.197:275203`). The 2.1.197 doc's claim of "local file writing" was therefore not supported by the code it cited. The same applies here. Treat this as **inferred**.

### 2.5 Sentry / Segment status

- **Segment: absent.** 0 hits for `segment.io` / `api.segment` in either build.
- **Sentry: no CLI client.** `@sentry` has 0 hits. The 11 `sentry` hits in 2.1.300 break down as:
  - credential-file patterns, e.g. `.sentryclirc` (`:315982`)
  - an MCP doc example (`mcp.sentry.dev`, `:1201383`)
  - a React error boundary named `SentryErrorBoundary`, which only calls the local logger `l()` (`:1097732`)
  - the vendored Claude Desktop egress manifest in module 1481 (`SENTRY_INGEST_HOST = "o1158394.ingest.us.sentry.io"`, `:1157366`; `toggleKey: "disableEssentialTelemetry"`, `:1176289–1176303`). That manifest lists the **Desktop renderer's** endpoints. The CLI never posts to them; no call site was found.

### 2.6 NEW: plugin telemetry mod (`cc-plugin-telemetry`, module 1802)

- Registered as a built-in plugin capability (`:45971`, `:773164`). `isAvailable: () => !iy()` (`:1534436–1534441`).
- **`$.telemetry.log({event, props})`**: event names are auto-prefixed `tengu_plugin_` unless they already start with `tengu_` (`z`, `:1534522`; `He`, `:1534528`).
- **`$.telemetry.mark({feature, kind: ok|sad|bad, reason?})`**: emits `tengu_feature_<kind>` with `feature_name` and `error_code` (`Z`, `:1534539`; `Ge`, `:1534557`).
- Prop rules (`v=32`, `:1534486`; `A=16`, `:1534507`; validators `:1534488–1534520`):
  - at most **16** props
  - snake_case keys
  - values are finite numbers, booleans, or a closed `Choice {value, of:[…≤32 tokens]}`
  - **free-text strings are refused**
- Rows are POSTed to `https://api.anthropic.com/api/event_logging/v2/batch` with one retry on 5xx/408/429 (`je`, `:1534598`; fetch at `:1534971`).
- Its own opt-out logic `ne()` (`:1534612–1534618`) checks:
  - `NODE_ENV=test`
  - `DISABLE_TELEMETRY`, `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`, `DO_NOT_TRACK`
  - any of Bedrock/Vertex/Foundry/AnthropicAws/**AnthropicGoogleCloud**/Mantle, unless `providerManagedByHost`
  - the gateway
  - a custom OAuth URL

---

## 3. Payload identity and device fields

### 3.1 `core_metadata`: `GOr()` (`:141165`)

| Field | Notes |
|---|---|
| `model` | via `Nve`, which masks the id |
| `sessionId` | |
| `userType: "external"` | |
| `betas` | |
| `envContext` | incl. `claudeCodeRemoteSessionId` |
| `isClaudeAiAuth` | |
| `entrypoint` | |
| `sessionKind`, `hasAttacher` | |
| `agentSdkVersion` | |
| `desktopAppVersion` | **NEW** |
| `isInteractive`, `clientType` | |
| `processMetrics` | rss, heap, CPU% (`lW`, `:141126`) |
| `sweBenchRunId/InstanceId/TaskId` | always present; `""` when unset |
| `subscriptionType` | |
| `rh` | sha256 of the normalised git remote, first 16 hex (`QLo`, `:59932`) |
| `head_sha` | |
| `is_clean_tree_at_start`, `changed_file_count_at_start`, `untracked_file_count_at_start` | **NEW** |
| `rendererMode` | |
| `remoteControlLane` | **NEW** |
| `projectsSession` | **NEW** |
| `promptId` → `cc_prompt_id` | **NEW** |

- `head_sha` and the tree-state counts are sent only when `c5()` holds: claude.ai auth **and** subscription `max` or `pro` (`:131207`, `VE`, `:131203`). The git state is from `EC`, `:140359`.
- **NEW-ness check** (0 hits in 2.1.197): `is_clean_tree_at_start`, `cc_prompt_id`, `desktop_app_version`, `remote_control_lane`, `projects_session`.

### 3.2 Wire `env` block: `MC()` (`:141245`)

| Group | Fields |
|---|---|
| Platform | `platform`, `platform_raw`, `arch`, `node_version`, `terminal`, `shell`, `package_managers`, `runtimes` |
| Environment flags | `is_running_with_bun`, `is_ci`, `is_claubbit`, `is_claude_code_remote`, `is_local_agent_mode`, `is_conductor`, `is_github_action`, `is_claude_code_action`, `is_claude_ai_auth` |
| Build | `version`, `build_time`, `deployment_environment` |
| Optional | `remote_environment_type`, `claude_code_container_id`, `claude_code_remote_session_id`, `tags` |
| GitHub Actions | `github_*` fields |
| OS / VCS | `wsl_version`, `linux_distro_*`, `linux_kernel`, `vcs`, `version_base` |

- `auth = {account_uuid, organization_uuid}`.
- `github_actions_metadata = {actor_id, repository_id, repository_owner_id}`.

### 3.3 Identifiers (module 152)

- **`_M()` userID** (`:115569`) is the 1P `device_id` / `user_id`. It is a random 32-byte hex value persisted in global config; it is not derived from hardware.
- **Datadog `userBucket`** = `sha256(_M())[0:8] % 30` (`getUserBucket`, `:349720`; `Q=30`, `:349687`).
- **machineID `Umt()`** (`:115581`) **is transmitted.** Datadog error tracking sends `host_name_redacted: Umt().slice(0, 12)`, the first 12 hex characters (`:350262`). This answers the open question in `ANALYSIS_CONTEXT.md`.
  - **Correction:** machineID is **not NEW**. 2.1.197 already had `z5t()`, "getOrCreateMachineID", random 32-byte hex (`2.1.197:606453`), sent the same way (`2.1.197:299471`).
  - `summonSidKey` (`rPo`) was not seen in any telemetry payload. Its destination is **not established** here.
- **GrowthBook user attributes** (`nT`, `:142573`):
  - `id`/`deviceID`, `sessionId`, `platform`, `apiBaseUrlHost`
  - org/account UUIDs, `userType`, `subscriptionType`, `rateLimitTier`, `organizationRole`, `subscriptionCreatedAt`, `firstTokenTime`
  - `email`, `appVersion`, `githubActionsMetadata`, `releaseChannel`, `entrypoint`
  - `sessionOrigin`, `ccrDerivedSurface`, `atisPin`, `hasUsedRemoteSession`, `hasRemoteEnvironment`, `slackTagConnected`
  - **NEW** (0 hits in 2.1.197): `slackTagConnected`, `atisPin`, `ccrDerivedSurface`, `sessionOrigin`.
  - `cacheKeyAttributes` grew from `["id","organizationUUID"]` (`2.1.197:145303`) to `["id","organizationUUID","slackTagConnected","atisPin","ccrDerivedSurface"]` (`:134100`).
- **GrowthBook exposures** (`Mxo`, `:142397`) emit `growthbook_experiment` on the 1P logger with: `event_type:"GrowthbookExperimentEvent"`, `experiment_id`, `variation_id`, `device_id?`, `account_uuid?`, `organization_uuid?`, `session_id?`, `user_attributes{appVersion}`, `experiment_metadata?`, `environment:"production"`.
  - **CHANGED:** exposures are skipped entirely in diskless mode (`po()`, `:142398`).

### 3.4 NEW: HIPAA-safe telemetry mode

**Activation.** `L9e()` / `txo()` → `Zk()` (`:135950–135962`) is true when either:

- the compliance taint `hipaa` is present (`Ta("hipaa")`), or
- the policy verdict is absent **and** one of these holds:
  - the entrypoint (`CLAUDE_CODE_ENTRYPOINT`, `wH`, `:135965`) is `local-agent`/`local_agent`, starts with `remote` or `claude-coworker`, or is in set `iNr` (`:24578`), which also holds `claude_in_slack`, `claude-in-slack` and `claude-in-teams`
  - a HIPAA principal was seen before (`PUs`, `:70180`)

**1P effect.** Every row passes through `rin` → `$H` → `$f` / `Gf` / `Wf` (`:136181–136275`):

- Top-level fields must pass strict validators (`et`, `:135990`):
  - uuid for `event_id`
  - the `session_…` / `cse_…` id grammar
  - 64-hex for `device_id`
  - enumerated `client_type`, `entrypoint` and `platform`
- Any other string becomes `"hipaa_redacted"` (`Kf`, `:136179`).
- `additional_metadata` is reduced to `sample_rate` plus a per-event schema (`Yk`, `:136103`). Schemas exist for these events:
  - `tengu_retention_sweep`
  - `tengu_feature_ok`, `tengu_feature_bad`, `tengu_feature_sad`
  - `tengu_org_policy_denied`
  - `tengu_policy_limits_fetch`
  - `tengu_remote_settings_fetch`
  - `tengu_signed_cache_shadow`
  - `tengu_frontmatter_grant_withheld`
  - `tengu_org_config_gate_shadow`
- `feature_name` must be one of **1,431** registered feature names (`Uk`, `:135922–135928`).

**Datadog effect.** In this mode `wNs` (`:136318`) applies the same validation. The exporter refuses to post any record built before redaction became active (`builtUnredacted`, `:349709`, `:349846`).

**OTel effect.** OTel attributes have an equivalent allow-list (`ENs`, `:136338`).

**Novelty.** `Ta("hipaa")` has 0 hits in 2.1.197 and 25 in 2.1.300.

### 3.5 NEW: device attestation on client events (adjacent, not telemetry)

`sin()` (`:136799`) signs some session payloads with a device key and attaches `device_attestation`. Callers are at `:137867–137909`.

- A failed signing emits `tengu_client_event_signed {ok:false, error}` (`:136859`).
- Feature health is reported as `client_event_signer` ok/sad.
- `clientEventSign*` has 0 hits in 2.1.197.
- Tentative: this is used for CCR/remote session events, not for the analytics pipe.

---

## 4. Controls and opt-out matrix

**Master predicate** (module 40 `chunk-z02b3r95.js`):

```js
function l()  { if (a.CLAUDE_CODE_PROVIDER_MANAGED_BY_HOST) return !1; return !Jn() }   // :22048
function RHr(){ return a.CLAUDE_CODE_CUSTOM_OAUTH_URL !== void 0 }                       // :22057  NEW
function iy() { return LD() || l() || Fr() !== null || RHr() }                           // :22061
```

`Oj() = !iy()` (`:142325`). `NNt` and `AA` return immediately when `!Oj()` (`:142354`, `:142376`). They also return when `LNt("firstParty")`, the `tengu_frond_boric` kill map (`:142255–142259`, `:142367`).

| Condition | Function | Effect |
|---|---|---|
| Kill-switch env | `LD()` → `VUt() !== "default"` (module 32, `:10162–10175`) | `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` → `essential-traffic`; `DISABLE_TELEMETRY` or truthy `DO_NOT_TRACK` → `no-telemetry` |
| Not firstParty plane | `l()` → `!Jn()` (`Jn` = `Ie() === "firstParty"`, `:21740`) | Bedrock / Foundry / AnthropicAws / **AnthropicGoogleCloud** / Mantle / Vertex / gateway → off |
| Gateway credential present | `Fr() !== null` (module 19, `credentialSlots.gatewayAuth()`) | off |
| **NEW:** custom OAuth URL | `RHr()` | `CLAUDE_CODE_CUSTOM_OAUTH_URL` set → off. The variable existed in 2.1.197 (`2.1.197:40672`) but was not part of `Wj()` (`2.1.197:141945`) |

| Variable / flag | Effect | Evidence |
|---|---|---|
| `DISABLE_TELEMETRY` / `DO_NOT_TRACK` / `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | Disable 1P, Datadog, error tracking, GrowthBook (via `Oj`), BigQuery metrics (via `LD`), and the plugin telemetry mod | `:10162`, `:22061`, `:142788`, `:1470484`, `:1534612` |
| `DISABLE_ERROR_REPORTING` | Disables Datadog error tracking | `TMs`, `:349420` |
| `DISABLE_GROWTHBOOK` | Disables flags and exposures | `Ng`, `:142789` |
| `CLAUDE_CODE_GB_DISK_CACHE_WHEN_TELEMETRY_OFF` (NEW) | Lets cached GrowthBook values be read from disk while telemetry is off. firstParty plane only | `e6s`, `:142792–142794` |
| `CLAUDE_CODE_CUSTOM_OAUTH_URL` (NEW in gate) | Disables all `iy()`-gated telemetry | `:22057–22062` |
| `CLAUDE_CODE_PROVIDER_MANAGED_BY_HOST` | Makes `l()` return false, so the 3P-plane condition is **skipped** (1P can stay on); Datadog and error tracking stay off because they check `Ie() === "firstParty"` themselves | `:22048–22050`, `:349780`, `:349423` |
| `CLAUDE_CODE_ENVIRONMENT_KIND=byoc` | Suppresses Datadog unless `CLAUDE_CODE_BYOC_ENABLE_DATADOG` is set | `wUs`, `:22053`; `:349713` |
| `CLAUDE_CODE_GZIP_DATADOG_LOGS` (NEW) | Forces Datadog gzip on or off (default `Dr()`: on only in CCR remote sessions) | `:349653`, `:92559` |
| `CLAUDE_CODE_DATADOG_FLUSH_INTERVAL_MS` / `CLAUDE_CODE_DD_ERROR_TRACKING_FLUSH_INTERVAL_MS` | Flush intervals; defaults 15,000 / 30,000 ms | `:349854`, `:349914` |
| `CLAUDE_CODE_ENABLE_TELEMETRY` | Enables user OTel exporters | `:1470670` |
| `OTEL_LOG_*`, `OTEL_METRICS_INCLUDE_*` | Content and identity opt-ins for user OTel | `:35281`, `:194378` |
| `CLAUDE_CODE_ENABLE_FEEDBACK_SURVEY_FOR_OTEL` | Re-enables feedback surveys when telemetry is off | `nte`/`kq`, `:22069–22076` |
| GrowthBook `tengu_log_datadog_events` (default `!1`) | Datadog mirror on/off | `:619920`, `:619927` |
| GrowthBook `tengu_frond_boric` `{firstParty, datadog}` | Remote kill of 1P / Datadog without a release | `:142255–142258` |
| GrowthBook `tengu_event_sampling_config` | Per-event sample rate | `:142260` |
| GrowthBook `tengu_1p_event_batch_config` | 1P batch, queue, path and auth overrides | `:142279` |
| GrowthBook `tengu_orford_ness` (default `!1`) | Datadog error tracking | `:349389–349398` |
| GrowthBook `tengu_agile_glade` (NEW) | Per-feature sample rate for `tengu_feature_ok` on Datadog | `:349769` |
| GrowthBook `tengu_swift_whistle` (NEW) | 1P: attach auth even without the OAuth profile scope | `xW`, `:142321`; `:142493` |
| GrowthBook `tengu_cozy_dusk` (NEW) | BigQuery metrics interval | `:1470670` |
| GrowthBook `tengu_trace_lantern` (not new: `2.1.197:274854`) | Allows beta tracing in interactive sessions. **CHANGED:** the gate `WR` now also requires not diskless (`!me()`) | `:286333–286335` |
| GrowthBook `tengu_quizzical_giraffe` (NEW) | Stamped on 11 auth-health events; also gates OAuth populate | `:619921`, `:772820` |

**SDK surface.** The SDK `system/init` message carries `analytics_disabled` (`:94583`). A second schema copy now tells IDE hosts to fold it into their own telemetry gate (`:95684`).

### 4.1 Third-party planes, including NEW `anthropicGoogleCloud`

The provider selector `Ie()` (module 39, `:21727–21729`) checks, in order: gateway → bedrock → foundry → anthropicAws → **anthropicGoogleCloud** (`CLAUDE_CODE_USE_ANTHROPIC_GOOGLE_CLOUD`) → mantle → vertex → firstParty.

| Backend | Behaviour on any non-firstParty plane, incl. `anthropicGoogleCloud` | Evidence |
|---|---|---|
| 1P event logging | **Dropped**: `l()` true → `iy()` true → `NNt`/`AA` return | `:22048–22062`, `:142354` |
| Datadog logs | **Dropped**: `_0t` returns when `Ie() !== "firstParty"`; `initializeDatadog` is also false when `iy()` | `:349780`, `:349713` |
| Datadog error tracking | **Dropped**: `Ie() !== "firstParty"` | `:349423` |
| GrowthBook | **Off**: `Ng()` requires `Oj()`; the disk-cache escape hatch requires `Jn()` | `:142788–142794` |
| BigQuery metrics | **Off**: `O9e()` requires `Jn()`; `kt()` → `bl()` returns false when `!Jn()` | `:130888`, `:130788`, `:128561` |
| Plugin telemetry mod | **Off**: `useAnthropicGoogleCloud` is in its 3P list | `:1534614` |
| User OTel | **Unaffected**: goes to the operator's own collector | `:1470670` |

**Exception (both builds).** `CLAUDE_CODE_PROVIDER_MANAGED_BY_HOST` short-circuits `l()`. With a 3P plane plus that variable, 1P logging stays **on** unless another condition fires. The 2.1.197 doc said this variable "forces off". The 2.1.197 code (`mUd`, `2.1.197:141936–141939`) shows it does the opposite.

---

## 5. Datadog allow-list

When Datadog is enabled, `_0t` forwards only the names in `O` (`:349582`): **244** = 235 `tengu_*` + 9 `chrome_bridge_*` (was 159 = 152 + 7).

**Added (95):**

| Group | Events |
|---|---|
| Artifacts | `tengu_artifact_disabled_session/_reject_breaker/_tool_recovered/_tool_withheld` |
| Auto-mode | env onboarding ×4, setup wizard ×3, `destructive_mcp_rule_allow`, `insights_auto_mode_recommendation` |
| MCP | `tengu_mcp_degraded/_first_tools_list/_list_changed/_listen_reopen/_message_stream_outcome/_listing_prior_rejected/_project_servers_approved/_sdk_generation/_server_connection_succeeded/_failed/_tripwire` |
| Remote tools | `tengu_remote_tool_forward/_serve/_targets/_restart_adoption*`, `tengu_remote_stream_regained` |
| Turn handoff | `tengu_turn_handoff_*` ×7 |
| Orphaned permissions | ×4 |
| Resume | `tengu_resume_*` ×5 |
| Tether | `tengu_tether_*` ×4 |
| Policy limits | `tengu_policy_limits_*` ×3 |
| Propose skills | `tengu_propose_skills*` ×3 |
| Remote control | `tengu_rc_pill_clicked`, `tengu_ranch_rc_*` |
| Teleport | `tengu_teleport_menu`, `tengu_teleport_permission_mode_refused` |
| Chrome bridge | `chrome_bridge_tool_call_disconnected/_lost` |
| Others | 15 more (see the YAML `datadog: true` flags) |

**Removed (10):** `tengu_auto_mode_opt_in_dialog_*` ×5, `tengu_schedule_offer_shown`, `tengu_sdk_control_roundtrip`, `tengu_team_mem_entries_capped`, `tengu_team_mem_sync_pull`, `tengu_team_mem_sync_push`.

**Forwarded tag keys** (`U`, `:349596`) grew from 29 to 38. The 9 new keys are `attach_cold`, `daemon_booted`, `first_frame_kind`, `surface`, `via`, `projectsRole`, `remoteControlLane`, `projectsSession`, `uncoveredTailReason`. None was removed.

**`_0t` also:**

- strips `envContext` / `head_sha` / tree counts from the metadata
- adds `userBucket`
- removes 35 hash/name keys (`N`)
- collapses `mcp__*` tool names to `"mcp"` (`K`, `:349609`)
- keeps `model` only if it contains `claude` and maps it to a known id or `"other"` (`ne`, `:349752`)
- explodes `status` into `http_status` / `http_status_range`
- strips dev build suffixes from `version` (`te`, `:349748`)
- builds `ddtags`, then sets `service`/`hostname: "claude-code"`, `env: "external"`, `ddsource: "nodejs"` (`:349836–349843`)

### 5.1 Datadog error tracking (existed in 2.1.197, undocumented there)

**Gate** `TMs()` (`:349419–349447`). All of the following must hold:

- `DISABLE_ERROR_REPORTING` unset
- not diskless
- `!iy()`
- firstParty plane on the first-party base URL (`Si()`)
- version ≥ `2.1.193`
- compliance verdict `allowed_taints_clean` or `allowed_untaintable` (`Xko`, `:349400`). The restriction is `allow_error_reporting`; it is blocked for HIPAA/ZDR taints, scopeless OAuth, an `ANTHROPIC_AUTH_TOKEN` env credential, or an API key helper.
- flag `tengu_orford_ness`

**Report** (`K`, module 334, `:350206–350271`):

| Field | Content |
|---|---|
| `error.kind`, `error.message` | message capped at 4,000 chars |
| `error.stack` | capped at 16,000 chars |
| `error.fingerprint` | sha256 of the top 3 frames, first 16 hex |
| `error_frames` | at most 20 |
| `user_bucket` | |
| **`host_name_redacted`** | `Umt().slice(0,12)` |
| `host_platform`, `host_os_release` | |
| `entrypoint`, `node_version`, `bun_version: "1.4.3"` | |
| `model` | masked to a known id or `other` |
| `feature_flags` | up to **50** boolean flag values (`x`, `:350154`) |

- **NEW tags:** `child_exit_status`, `remote_control_lane`, `projects_session`.
- **Cap:** 100 reports per process, plus a `cap-reached-sentinel` report (`n=100`, `:349911`; `Cko`, `:349993`).
- Sent via the browser intake, batch 25, timeout 10,000 ms (`:349907–349911`).

---

## 6. Event categories (1,944 enumerated = canonical)

Canonical churn vs the 2.1.197 recount (`_facts.md` §1.2) is **1,181 → 1,944**: **817 new, 54 removed, 1,127 kept**.

This file's enumeration finds 815 new and 1,129 kept. The difference is 2 `tengu_wif_user_oauth_refresh_*` names: they were alias-only in 2.1.197, `_facts` did not count them there, so `_facts` treats them as new while this file treats them as kept.

Kept names keep their 2.1.197 category. New names are assigned by prefix rules, which are judgment calls; see the YAML for the canonical per-name assignment.

| Category | 2.1.300 | of which NEW | 2.1.197 published | Description |
|---|---:|---:|---:|---|
| Background & Daemon | 130 | 36 | 91 | bg worker/daemon lifecycle, adopt/respawn/dispatch, launcher, PTY host, cloud lease |
| Teleport / Remote | 120 | 81 | 37 | teleport, remote sessions, turn handoff, dir sync, preview tunnels, CCR bundles |
| Billing / Upsell / Rate Limit | 93 | 50 | 44 | rate-limit menu, low-priority queue, quota auto-resume, cedar_ember / juniper_tide offers, promos |
| API & Model | 92 | 43 | 48 | queries, errors, retries, thinking/effort retries, gzip request body, structured outputs |
| Plugins / Marketplace / Skills | 89 | 30 | 63 | plugin lifecycle, plugin directory, function-hook mods, skills sync |
| OAuth & Authentication | 79 | 13 | 64 | login flows, token refresh/locks (lock-compromised variants), console key selection |
| MCP | 75 | 22 | 45 | server lifecycle, discovery source, proxy approval, auto-backgrounded tasks |
| Settings & Config | 72 | 23 | 50 | settings change staging/review, served settings, untrusted-source ignores |
| Permission | 66 | 49 | 25 | auto-mode (31 new names), sandbox scrub/grants, safety-check dialogs, orphaned permissions |
| Session Lifecycle | 62 | 20 | 42 | init, exit, resume, retention sweep, end-conversation |
| Bridge / REPL | 60 | 33 | 30 | bridge env/owner/ingress/policy, REPL attach, remote-control pills |
| Compaction | 58 | 16 | 42 | idle/sleep compaction, precomputed rehydrate, transcript compact |
| Streaming & Performance | 50 | 16 | 35 | stdout backpressure, wire-shape record/replay, turn timing |
| Auto-Update | 47 | 6 | 43 | updater refusals (not owner/typed/launch file), manifest signature |
| **Device Bridge / Device Hooks** (NEW) | 45 | 45 | 0 | device bind/bridge, device hooks consent/lease/templates, device MCP consent, re-enroll |
| Agents | 43 | 19 | 28 | agent proxy queues, max-turns, view-leader commands, worktree escape |
| Tool Usage | 43 | 12 | 31 | cgroup/CPU by phase, schema sizes, withheld tools |
| User Input | 41 | 17 | 24 | left-arrow carry, stacked slash commands, spatial focus, import |
| File Operations & History | 40 | 7 | 33 | projects writes, rewind expiry, worktree locks |
| IDE / External / CLI Commands | 39 | 5 | 33 | gh PR status, git-created PRs, PR prep guidance |
| Conversation Flow | 38 | 14 | 26 | context announcements, reminder folding, cross-session inbox |
| Session / Auto Memory | 35 | 18 | 18 | memdir lint/pin/backfill, account memory, memory sync warnings |
| Feedback & Survey | 33 | 15 | 17 | **feedback drafts** (created/submitted/expired…), turn-off prompts |
| Refusal Fallback / Retraction | 32 | 6 | 26 | fallback bridge forwarding, same-model retry |
| Loops / Kairos / Scheduling | 31 | 12 | 21 | **goals** (proposed/evaluated/cleared), proactivity cycle |
| Teams & Team Memory | 28 | 9 | 25 | conflict recovery, foreign partitions, rejoin |
| Hooks | 25 | 4 | 21 | hook rewrite checks, prompt timeout |
| Bash / Shell Tool | 24 | 7 | 19 | bash task ack/deliver, no-bash fallback |
| **Remote Headless Client** (NEW) | 23 | 23 | 0 | `tengu_remote_headless_client_*` lifecycle, worker init/ready, queue overflow |
| **Artifacts** (NEW) | 21 | 21 | 0 | Artifact ask/grant, preview (browser/emulator), verify, routine publish |
| Ask-User / Dialog | 20 | 6 | 14 | AFK auto-advance, timeouts, park on stream close |
| Claude.ai MCP & Chrome | 20 | 7 | 13 | chrome extension/bridge connected, install upsell |
| Privacy & Policy | 20 | 7 | 15 | policy-limits principal change, signed cache, client event signing |
| **Home Seed / Home Settings** (NEW) | 18 | 18 | 0 | home seed plan/apply/upload/recovery, home settings mode prompts |
| Rotunda / Credits (internal) | 18 | 8 | 10 | convolute arcades tools, tether decisions |
| Images / PDF / Media | 17 | 5 | 12 | webp direct, web-fetch dedup/transport |
| **Org Memory** (NEW) | 17 | 17 | 0 | org memory decisions, project select/switch, root mounts, writes |
| Provider Setup | 17 | 1 | 26 | Bedrock/Vertex upgrade wizards removed (−10) |
| **Remote Tools** (NEW) | 18 | 18 | 0 | remote tool forward/serve/serving, permission classifier, restart adoption, tool-host adverts |
| Error & Recovery | 16 | 1 | 15 | `tengu_otel_headers_helper_failed` |
| Agent SDK | 16 | 7 | 9 | control cancel/progress, workspace trust, side-question cancel |
| Transcript | 14 | 5 | 9 | id-scan fallback, parent wait |
| Workflows | 14 | 3 | 11 | authoring skill autoload, size warning |
| **Cloud Launch & Cloud Plugins** (NEW) | 13 | 13 | 0 | cloud create/cancel/checklist, cloud plugin admission/consent/forwarding |
| Advisor Tool | 12 | 6 | 6 | settings sync, tool error/result |
| Tool Search | 12 | 1 | 12 | uncompilable ignore pattern |
| **Dead-Code Probes** (NEW) | 10 | 10 | 0 | `tengu_dead_probe_*` one-shot hits on legacy code paths |
| Ultraplan | 10 | 0 | 10 | unchanged |
| **Codename Experiments** (NEW) | 8 | 8 | 0 | `brook_heron`, `gentle_parasol`, `sleepy_snowflake`, `streamed_bumblebee`, `toasty_thimble`, `willow_tern` `_applied`; `playful_lobster_fired`; `breezy_horizon` |
| Voice | 7 | 0 | 7 | unchanged |
| CLAUDE.md | 5 | 0 | 5 | unchanged |
| At-Mention | 4 | 1 | 5 | agent/MCP-resource at-mention events removed |
| Plan Mode | 4 | 1 | 3 | `tengu_plan_exit_dialog_shown` |

### 6.1 Notable NEW families (verified call sites)

- **Device bridge and device hooks, 45 names.** Examples: `tengu_device_bind_account` (`:1000661`) and `tengu_device_hooks_*`. Several are fired through a destructured `{logEvent: l}` alias (`:1800098`, e.g. `tengu_device_hooks_lease_expired` at `:1800108`).
- **Remote headless client and remote tools, 41 names.** Examples: `tengu_remote_headless_client_started` (`:1521637`) and `tengu_remote_tool_forward` (`:1468523`, Datadog-allow-listed with a field allow-list).
- **Artifacts, 21 names.** Example: `tengu_artifact_ask {toolUseID, …}` (`:1403826`).
- **Org memory and home seed, 35 names.** Example: `tengu_org_memory_decision` (`:221310`).
- **Rate-limit alternatives:**
  - low-priority queue `tengu_lowpri_*` ×7 (`tengu_lowpri_request`, `:177671`)
  - `tengu_quota_auto_resume_*` ×7 (`fired`, `:678253`)
  - codename offers `tengu_cedar_ember_*` / `tengu_juniper_tide_*` (×5 each) and matching `rate_limit_options_menu_select_*` entries
- **Goals.** `tengu_goal_proposed {promptLength, askUser, forcedAsk}` (`:1444800`).
- **Dead-code probes.** These fire once per site through a `firedSites` Set. Example: `tengu_dead_probe_legacy_local_settings {site}` (`:64681`). Tentative purpose: deciding whether legacy paths can be deleted.
- **Feature health framework.** `tengu_feature_ok/bad/sad` are emitted by helpers `g`/`m`/`p` and their async twins (module 74, `:47893–47935`) with `feature_name` and `error_code`. 2.1.300 registers **1,431** feature names (`Uk`, `:135922–135928`). Name helpers include `tool_*`, `cmd_*` and `hook_*` (`:47880–47890`).
- **Gzip request bodies.** `tengu_gzip_request_body_fallback {rollout, rejection, status, viaCloudflare, …}` (`:166656`).

### 6.2 Removed vs 2.1.197 (54 names)

The full list is under `removed:` in the YAML.

- Bedrock/Vertex setup-cancel and upgrade flows (×10)
- `tengu_auto_mode_opt_in_dialog_*` ×5
- `tengu_repl_inner_executing`, `tengu_repl_inner_watchdog_fired`, `tengu_repl_verbose_render`
- `tengu_team_mem_sync_pull/_push`, `tengu_team_mem_entries_capped`, `tengu_team_mem_secret_skipped`
- `tengu_permission_explainer_*` ×3
- `tengu_speculation`, `tengu_sdk_control_roundtrip`, `tengu_schedule_offer_shown`
- others

**8 of the 54 still exist but moved behind wrapper forwarders** (`_facts.md` §1.2): `tengu_plugin_{enable,install,uninstall,update}_command` (via `me`, `:1654110`), `tengu_bash_ast_too_complex`, `tengu_bash_dangerous_rm_too_complex` (via `iO`), `tengu_memdir_entrypoint_near_cap` and `tengu_team_mem_prompt_index_near_cap` (via `kGe`).

---

## 7. Sample payload shapes (verified)

```js
// 1P exposure row (module 152)                                   cli.beauty.js:142442
n.emit({ body: "growthbook_experiment", attributes: { event_type: "GrowthbookExperimentEvent",
  event_id, experiment_id, variation_id, device_id?, account_uuid?, organization_uuid?,
  session_id?, user_attributes: _({appVersion}), experiment_metadata?, environment: "production" }})

// Feature health (module 74)                                     cli.beauty.js:47891
i("tengu_feature_ok",  { ...extra, feature_name: c(name) })
i("tengu_feature_bad", { ...extra, feature_name: c(name), error_code: $ke(code) })

// OTel headers helper failure (NEW)                              cli.beauty.js:131191
i("tengu_otel_headers_helper_failed", { failure_kind: c(S), exit_code })

// Codename sysprompt injection (NEW)                             cli.beauty.js:491971
i("tengu_brook_heron_applied", { len: s.length, effort: ue(r) })

// Quota auto-resume (NEW)                                        cli.beauty.js:678253
i("tengu_quota_auto_resume_fired", { rearm, waited_ms, early: 1 })

// Retention sweep (NEW; HIPAA schema at :136104)                 cli.beauty.js:821153
i("tengu_retention_sweep", { skipped: !0, skipReason: c(n), ... })

// Datadog record shape                                           cli.beauty.js:349836
{ ddsource: "nodejs", ddtags: "event:<name>,<k>:<v>,...", message: name,
  service: "claude-code", hostname: "claude-code", env: "external", ...snake_case(fields) }
```

The `c()`, `b()` and `ue()` wrappers (module `chunk-r28c5jws.js`, e.g. `function c(n){return r(n)}`) are identity functions at runtime. They work as type-level "verified safe label" casts and do **no** runtime sanitisation.

---

## 8. Corrections to the 2.1.197 telemetry doc (found while verifying)

| 2.1.197 doc said | The code shows | Evidence |
|---|---|---|
| GrowthBook endpoint `https://cdn.growthbook.io` | That is only the vendored SDK default. CC configures remote-eval at `https://api.anthropic.com/` in **both** builds | 2.1.197: `n = "https://api.anthropic.com/"` (`2.1.197:145291`); 2.1.300: `BB` (`:133727`), used at `:134096` |
| Second Datadog endpoint (`browser-intake-us5`) is the Chrome-bridge RUM logger | It is the **error-tracking** client (`dd-error-tracking`, `tengu_orford_ness`) in both builds | `2.1.197:299067–299221`; `:349907–350000` |
| `CLAUDE_CODE_PROVIDER_MANAGED_BY_HOST` "also forces off" | It **skips** the 3P-plane disable condition | `2.1.197:141936–141939`; `:22048–22050` |
| Perfetto writes a local trace file | The initializer only logs in both builds; no recorder assignment was found | `2.1.197:275203`; `:286633` |
| machineID implicitly absent (the context file lists `Umt` as NEW) | machineID existed in 2.1.197 (`z5t`) and was already sent as `host_name_redacted` | `2.1.197:606453`, `2.1.197:299471` |

---

## 9. Uncertainties

- **Beautifier blind spot (resolved).** `_facts.md` reports 1,944 (1,929 via `i`/`Js`). A regex over `cli.beauty.js` finds only 1,928 via `i`/`Js`; the same regex over `cli.min.js` finds 1,929. The extra name is `tengu_remote_tool_classifier` (3 `i()` sites, 0 hits in 2.1.197), whose beautified text at `:1469088` is mangled (`tengu_remote_tool_classifier ",{decision:…`). Event counts taken from `cli.beauty.js` alone can therefore under-count.
- **Category assignment** of the 815 new names is rule-based (prefix rules, then nearest 2.1.197 prefix). Per-category NEW counts are this analysis's mapping, not ground truth.
- **Remote payloads cannot be read from the binary.** This covers the contents of `tengu_frond_boric`, `tengu_event_sampling_config`, `tengu_1p_event_batch_config`, `tengu_log_datadog_events`, `tengu_orford_ness`, `tengu_agile_glade` and `tengu_cozy_dusk`. Only fallbacks are known.
- **Perfetto being dead** is an inference from the absence of a recorder assignment. A dynamic or indirect setter could exist.
- **CLI consumption** of the vendored Desktop/Cowork keys (`disableEssentialTelemetry` / `disableNonessentialTelemetry`) is not established.
- **`summonSidKey` (`rPo`)** destination is not established. It was not seen in any telemetry payload.
- **Gateway-named OTel collector behaviour** (`:1470716–1470722`) was read from minified one-line code and is tentative.
- **Pre-sink queue scope.** Whether the bounded pre-sink queue (`ds(c)` → `y.host`) is process-global or per-session depends on `G`/`ds` semantics in module 18/19. The reading here is tentative.
