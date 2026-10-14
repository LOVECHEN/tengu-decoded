# Environment Variables

> [Back to version index](../README.md)
>
> **Version**: 2.1.300 | **Build**: `2026-10-14T12:54:55Z` | **GIT_SHA**: `c6733ae1276880507ca0c5b053ae18fb0df090d6` | **Platform**: Linux x86-64 | **Runtime**: Bun **1.4.3** (was 1.4.0 in 2.1.197)

The full dataset is in [data/environment-vars.yaml](data/environment-vars.yaml). It has 1,367 variables, each with a type, a category, a `cli.beauty.js:LINE` ref and the flags `new` / `changed` / `opt_out` / `danger` / `secret` / `privacy` / `inert_raw_proxy`. It also has separate lists for 34 names that are not read from the environment, 16 prefix fragments, 39 removed names and 32 dropped 2.1.197 dataset artifacts. **In this build, `new=true` means the name does not appear in 2.1.197.** For a `CLAUDE_*` or `ANTHROPIC_*` name, that is the set difference over the canonical corpus. For any other name, it means there is no token for it in 2.1.197's `cli.min.js`. All line numbers are for 2.1.300's `bundle/cli.beauty.js` unless they are marked 2.1.197.

## What's new vs 2.1.197

| | 2.1.197 | 2.1.300 | Source |
|---|---|---|---|
| `CLAUDE_*` distinct (canonical corpus) | 470 | **946** | `_facts.md` §1 |
| `ANTHROPIC_*` distinct (canonical corpus) | 56 | **72** | `_facts.md` §1 |
| **Prefixed total** | 526 | **1,018** (+492) | `_facts.md` §1 |
| JS-only (no bundled `.md`/`.txt` assets) | — | 925 + 69 = 994 | `_facts.md` §1 |
| `CLAUDE_*` new / removed | — | **506 / 30** | recomputed here, same corpus |
| `ANTHROPIC_*` new / removed | — | **17 / 1** | recomputed here |
| Typed env **registry** size | 673 (8 maps) | **1,162** (8 maps) | parsed from source, both builds |
| Registry parser kinds | str 349, bool 239, int 68, triBool 16, enum 1 | str 554, bool 363, int 128, triBool 97, enum 12, **rawStr 8** | parsed |
| Registry entries whose parser kind changed | — | **24** | parsed, both builds |

The +492 headline overstates real knobs. Of the new prefixed names:

- 16 are **prefix fragments** that end in `_`, e.g. `CLAUDE_CODE_USE_`, `CLAUDE_CODE_DISABLE_DIR_`, `ANTHROPIC_SECRET_PLACEHOLDER_`.
- 34 new matches are **not environment variables**. Examples: `ANTHROPIC_TELEMETRY_GROUP` is a settings-UI group label (`:1164207`). `ANTHROPIC_API_HOST` = `"api.anthropic.com"` is an egress constant (`:1157341`). `ANTHROPIC_TIER_NAMES` = `["sonnet","opus","haiku","fable","mythos"]` is a constant (`:1134015`). `CLAUDE_AI_*_SCOPE` are OAuth scope constants (`:1041216`). There are also asset-only tokens such as `CLAUDE_TEST_*` and `ANTHROPIC_OPEN_TELEMETRY_*`, which appear only in bundled skill/doc files.
- **53 of the new names**, and 55 names overall, are read only through the raw proxy `nr`. (Verification pass: every `nr.NAME` read site in the corpus was mapped to its module, and every such module imports `nr` from module 34 under that name. The first draft flagged 48. It missed `CLAUDE_CODE_MEMORY_API_TOKEN`, `CLAUDE_REMOTE_TOOLS_BRIDGE_URL` and five uncatalogued `CCR_*` startup-timing names, which are now in the YAML.) That proxy is backed by an empty map, so **those names cannot be set from the environment in this build** (see below).

## How the registry works (module 34 `chunk-t4xwnzyq.js`, `cli.beauty.js:10646–13971`)

The structure is the same as in 2.1.197, but it was moved into one ESM chunk and its internals were rewritten.

- **Eight sub-maps** are declared with `Lr(map, { NAME: () => parser, … })`:

  | Map | Line | Names | Content |
  |---|---|---|---|
  | `N` | `:10705` | 63 | auth, credentials |
  | `l` | `:10771` | 65 | OTel / `ANT_OTEL_*` telemetry |
  | `B` | `:10839` | 329 | `CLAUDE_*` features |
  | `b` | `:11171` | 195 | host/system/terminal/CI |
  | `F` | `:11369` | 342 | misc features |
  | `d` | `:11714` | 45 | model selection |
  | `f` | `:11762` | 53 | network/timeouts |
  | `K` | `:11818` | 70 | providers/endpoints |

- **Merged** into `cN = {...N, ...K, ...d, ...B, ...f, ...b, ...l, ...F}` (`:13840`).
- **Proxies** (exported):
  - `a = ple(cN, R)`: parsed values, with the helper object `R` (`:12580`) as prototype. Code reads `a.CLAUDE_CODE_USE_BEDROCK` and so on. The `ANALYSIS_CONTEXT` calls this the "normalized env object `a`".
  - `nr = ple(SN, null)` where **`SN = {}`** (`:13927–13928`). This is the raw proxy. Because its map is empty, every `nr.NAME` read returns `undefined`. 2.1.197 had the same pattern: `IMu = {}, QO = JEs(IMu, null)` (2.1.197 `:46725`). So the 2.1.197 doc's "raw string" reading of `QO.CLAUDE_CODE_AUTO_MODE_TEMPERATURE` described a value that could not be set from the environment in either build. **Inference, verified mechanically:** an empty map means the getter falls through to `Object.create(null)`. Code at those sites always takes its `?? flag/default` branch.
  - `NT = ple(udsInboxShape, null)` (`:13929–13930`) is new. It holds the UDS-inbox variables such as `CLAUDE_CODE_MESSAGING_SOCKET`.
- **Getter semantics:** `tt(name, parser, sentinel)` re-parses only when the raw string changes (`:13874–13881`). `.set(k, v)` and `.unset(k)` write to `process.env` (`:13860–13869`). Both behaviours already existed in 2.1.197's `JEs` (2.1.197 `:46674`), so they are UNCHANGED.
- **NEW: `CLAUDE_CODE_LAZY_ENV_GETTERS`.** When truthy, `ple()` builds a `Proxy` (`RN`, `:13888`) that installs getters on first access, instead of defining every getter eagerly (`:13851–13853`). The string is absent from 2.1.197.
- **Parser factory `H`** is in module 28 `chunk-7vmm8g6w.js`. It is **no longer zod-based**: 2.1.197's `Be` used `at.preprocess(...)`.

  | Parser | Behaviour |
  |---|---|
  | `H.str()` | trimmed string or `undefined` |
  | `H.rawStr()` *(NEW)* | the string untouched, no trim. Used by 8 names, including `NO_COLOR`, `FORCE_COLOR`, `CURSOR_TRACE_ID`, `CLAUDE_CODE_TMUX_TRUECOLOR`, `CLAUDE_ARTIFACT_HOST_GRANT`, `CLAUDE_CODE_AUTO_MODE_TIER` |
  | `H.bool()` | `$e(x)`: `"1"/"true"/"yes"/"on"` (lower-cased, trimmed) → `true`, else `false` |
  | `H.triBool()` | `true` if truthy, `false` if `ys(x)` (`"0"/"false"/"no"/"off"`), else `undefined` |
  | `H.int(opts)` | finite number. Options are `min`, `max` and, **NEW**, `digitsOnly` (must match `/^[+-]?\d+$/`) and `wholeValue` |
  | `H.enum([...])` | trimmed value if it is in the allow-list, else `undefined` |

  The string `digitsOnly` occurs 0 times in 2.1.197 and 28 times in 2.1.300. `wholeValue` occurs 0 and 6 times.

### Parser-kind changes (24, CHANGED)

Both registries were parsed and compared. Most changes go from `bool` to `triBool`. With `triBool`, an unset variable stays `undefined`, so a GrowthBook flag or a default can apply, and only an explicit `0/false/no/off` forces the feature off. Under `bool`, unset already meant `false`.

| Change | Names |
|---|---|
| bool → triBool | `CLAUDE_CODE_ENABLE_TASKS`, `CLAUDE_CODE_FORK_SUBAGENT`, `CLAUDE_CODE_ENABLE_FINE_GRAINED_TOOL_STREAMING`, `CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS`, `CLAUDE_CODE_BG_TASKS_REPORT_RUNNING`, `CLAUDE_CODE_USE_POWERSHELL_TOOL`, `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB`, `CLAUDE_CODE_REPL`, `CLAUDE_ENABLE_BYTE_WATCHDOG`, `MCP_CONNECTION_NONBLOCKING`, `ENABLE_MCP_LARGE_OUTPUT_FILES`, `ENABLE_CLAUDEAI_MCP_SERVERS`, `ENABLE_PID_BASED_VERSION_LOCKING`, `_CLAUDE_CODE_ASSUME_FIRST_PARTY_BASE_URL` |
| bool → str | `ENABLE_TOOL_SEARCH` (now a mode string, logged as `ENABLE_TOOL_SEARCH=${…}` at `:219764`), `CLAUDE_CODE_SYNTAX_HIGHLIGHT`, `CLAUDE_CODE_MOCK_REMOTE_SETTINGS`, `CLAUDE_CODE_TEST_NO_PWSH`, `CLAUDE_CODE_TEST_NO_GIT_BASH` |
| bool → rawStr | `CLAUDE_CODE_TMUX_TRUECOLOR`, `CLAUDE_CODE_TEST_FORCE_DENY` |
| str → rawStr | `NO_COLOR`, `FORCE_COLOR`, `CURSOR_TRACE_ID` |

## NEW provider plane: Claude Platform on Google Cloud

2.1.300 adds an eighth plane value, `anthropicGoogleCloud`. 2.1.197's `yr()` returned seven: gateway, bedrock, foundry, anthropicAws, mantle, vertex and firstParty (2.1.197 `:94636–94638`, which read `process.env` through `ct()`; 2.1.300's `Ie()` reads the parsed proxy `a`). The string `anthropicGoogleCloud` occurs 0 times in 2.1.197 `cli.min.js` (`_facts.md` §3).

| Variable | Type | Effect |
|---|---|---|
| **`CLAUDE_CODE_USE_ANTHROPIC_GOOGLE_CLOUD`** | bool (`K`) | Selects the plane. Its display label is "Claude Platform on Google Cloud" (`:21678`). It is the 4th check in `Ie()` (`:21729`): gateway → bedrock → foundry → anthropicAws → **anthropicGoogleCloud** → mantle → vertex → firstParty |
| **`ANTHROPIC_GOOGLE_CLOUD_BASE_URL`** | str | Endpoint. `Fw()` defaults it to `https://claude.googleapis.com` (`:181966`). It is an endpoint row in `sJe` with the companions `CLAUDE_CODE_SKIP_ANTHROPIC_GOOGLE_CLOUD_AUTH` and `ANTHROPIC_CUSTOM_HEADERS` (`:35328–35331`) |
| **`ANTHROPIC_GOOGLE_CLOUD_PROJECT`** | str | GCP project. The SDK client falls back to `GOOGLE_CLOUD_PROJECT` (`:920816`) |
| **`ANTHROPIC_GOOGLE_CLOUD_LOCATION`** | str | Defaults to `"global"`. The URL is `https://claude.googleapis.com/v1alpha/projects/{p}/locations/{l}/workspaces/{w}/invoke` (`:920805–920806`, `:920829`) |
| **`ANTHROPIC_GOOGLE_CLOUD_WORKSPACE_ID`** | str | Required. The SDK throws "No workspace ID found…" unless `skipAuth` is set and a `baseURL` is given (`:920829`) |
| **`CLAUDE_CODE_SKIP_ANTHROPIC_GOOGLE_CLOUD_AUTH`** | bool | **Danger.** Skips `UIr()` gcp auth refresh (`:803966`) and constructs the client with `skipAuth: true` (`:181760–181775`) |

How the plane is wired:

- Auth goes through the **same `gcpAuthRefresh` helper as Vertex**: `Ol.gcpAuthRefresh` lists `CLAUDE_CODE_USE_VERTEX`, `CLAUDE_CODE_USE_ANTHROPIC_GOOGLE_CLOUD`, `ANTHROPIC_VERTEX_BASE_URL` and `ANTHROPIC_GOOGLE_CLOUD_BASE_URL` (`:35301`). `qGt()` is true for either plane (`:449489`).
- The client `AnthropicGoogleCloud` is loaded lazily from `chunk-t9fmvy6h.js` (`:181758–181765`). It rejects `apiKey`/`authToken`/`credentials`/`config`/`profile` and authenticates **only with a Google bearer token** (`:920828`).
- The plane's variables are part of the host-managed provider set `Hq` (`:35277`). The bundled `cc-plugin-telemetry` mod also reads `CLAUDE_CODE_USE_ANTHROPIC_GOOGLE_CLOUD` through `env.get` (`:1535062`).
- As with every other 3P plane, **crash/error reporting is skipped** when it is selected (`:10261`).

## Privacy, telemetry and identity

### Unchanged switches

`VUt()` (`:10162–10167`) has the same logic as 2.1.197 `qHs()` (2.1.197 `:48902–48907`):

```
CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC (any non-empty) -> "essential-traffic"
DISABLE_TELEMETRY (any non-empty)                         -> "no-telemetry"
DO_NOT_TRACK ($e: 1/true/yes/on)                          -> "no-telemetry"
```

`DISABLE_TELEMETRY` and `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` are tested with raw JavaScript truthiness. **`DISABLE_TELEMETRY=0` still disables telemetry.** This is true even though both names are registered as `bool`. `DO_NOT_TRACK=0` does not disable telemetry. `DISABLE_ERROR_REPORTING` is also a raw truthiness test (`:10261`). The content-logging switches `OTEL_LOG_USER_PROMPTS`, `OTEL_LOG_TOOL_CONTENT`, `OTEL_LOG_TOOL_DETAILS`, `OTEL_LOG_ASSISTANT_RESPONSES` and `OTEL_LOG_RAW_API_BODIES` are still opt-in (`kl` `:35281`).

### NEW: settings files can no longer inject many env keys

None of the guard messages below exist in 2.1.197. `grep -c` for "no settings file can set this key", "a project's settings can only set it" and "repo-committed settings can't re-point" each returns 0 in 2.1.197 and 1 in 2.1.300.

- **`iRr` (`:165624`): 151 string literals plus spreads.** The spreads are `TT` (= `"CLAUDE_CODE_PROCESS_WRAPPER"`, `:164915`), `Cgt` (2 BG-dispatcher names, `:102483`), `jln` (48 `OTEL_EXPORTER_OTLP_*`-style exporter keys, module 63) and the empty arrays `Y` and `oe`, so the set resolves to **202 names**. (The first draft said 149, which matches neither figure.) These are keys that `.claude/settings.json` and `.claude/settings.local.json` cannot set. `H()` strips them and warns `"<KEY> in .claude/settings.json is ignored: …"` (`:165632–165648`). The set includes:
  - `CLAUDE_CODE_PROCESS_WRAPPER`
  - `CLAUDE_CODE_CUSTOM_OAUTH_URL`
  - `CLAUDE_CODE_CLIENT_DATA_URL`
  - `CLAUDE_CODE_REMOVE_PROMPT_STRINGS`
  - `CLAUDE_CODE_PLUGIN_ATTRIBUTION` and `CLAUDE_CODE_SKILL_ATTRIBUTION`
  - `CLAUDE_CODE_FORWARD_USER_INTENT`
  - `CLAUDE_CODE_SUBSCRIPTION_TYPE` and `CLAUDE_CODE_RATE_LIMIT_TIER`
  - the `*_RM_PROMPT` safety switches
  - `CLAUDE_CONFIG_DIR`
  - `OTEL_LOG_RAW_API_BODIES`
  - `HOME`, `TMPDIR` and similar path variables
- **The exception is a value that only tightens privacy.** A project may set:
  - `API_FORCE_IDLE_TIMEOUT`, `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`, `CLAUDE_CODE_DISABLE_WEB_FETCH`, `DISABLE_ERROR_REPORTING`, `DISABLE_TELEMETRY` and `DO_NOT_TRACK`, as long as the value is truthy (`kHo` `:35414`, `Ml` `:35438–35440`)
  - `OTEL_LOG_USER_PROMPTS`, `OTEL_LOG_TOOL_CONTENT` and `OTEL_LOG_TOOL_DETAILS`, only to a false value. It may also set the OTel exporters only to `none`, and only when no other source already defines that key (`RYn` `:35292–35296`)
  - `ENABLE_BETA_TRACING_DETAILED` and `OTEL_LOG_RAW_API_BODIES`, only to a false value (`By` `:35415`)
- **Host-only sets that no settings file of any scope can set.** `V()` (`:165819–165826`) removes these from every settings env:
  - `X`, 80 string literals (plus two empty spreads): remote/CCR/bridge injection (`:165785`)
  - `J`, 35 string literals plus `YMe` (= `"CLAUDE_CODE_HOST_SKILL_CATALOG"`) and the empty spread `Ee`: host-declared, e.g. `CLAUDE_CODE_ENTRYPOINT`, `CLAUDE_CODE_HOST_SESSION_ID`, `CLAUDE_CHROME_PAIRED_DEVICE_ID` (`:165787`)
  - `ge`: remote workflow
  - `CLAUDE_STAGE_FILE_ROOT`
  - anything that starts with `CLAUDE_CODE_DISABLE_DIR_`
- **Credential-transport keys.** `j` (39 string literals plus the spreads `aJe` and `Wln`, `:165681`) covers the host credential-transport keys: `CLAUDE_CODE_HOST_CREDS_FILE`, the `*_FILE_DESCRIPTOR` token pipes, and `CLAUDE_CODE_MESSAGING_TOKEN`. These are never accepted from settings (`b()` `:165702–165708`).
- **Chrome hardening (`v`, `:165789–165793`).** `CLAUDE_CHROME_CLASSIFIER_FLOOR`, `CLAUDE_CHROME_PERMISSION_MODE` and `CLAUDE_CODE_ENABLE_CFC` can only be set to their safer values (`1` / `ask` / `0`) where that guard applies.

### NEW privacy- and telemetry-relevant variables

| Variable | Effect | Ref |
|---|---|---|
| `CLAUDE_CODE_GB_DISK_CACHE_WHEN_TELEMETRY_OFF` | `e6s()` = this var `&& !DISABLE_GROWTHBOOK && LD() && Jn()`. `LD()` is `VUt() !== "default"` (`:10173`), and the imported `Jn()` is `Ie() === "firstParty"` (module 39, `:21740`). So the GrowthBook disk cache can be used when telemetry is off, but only on the first-party plane. The var is also in the flag-env snapshot list `Wgs` with `DISABLE_TELEMETRY`/`DO_NOT_TRACK` (`:186931`) | `:142793` |
| `CLAUDE_CODE_DISABLE_VITALS_EMITTER` / `VITALS_EMITTER_BIN` | Kill switch for the "guest vitals" emitter, which is also off under essential-traffic-only. The binary path must be absolute | `:606511`, `:606524` |
| `CLAUDE_CODE_GZIP_DATADOG_LOGS` | Gzip the Datadog intake POST. Default `Dr()` | `:349653` |
| `CLAUDE_CODE_OTEL_CONTENT_MAX_LENGTH` | Cap on content length in OTel attributes. The minimum of this and the `OTEL_*_LENGTH_LIMIT` values is used | `:286296` |
| `OTEL_LOG_MANAGED_SETTINGS` | Log managed settings over OTel. It is in the OTel-logging list `kl` and in `F_` (`:38252`) | `:35281` |
| `CLAUDE_CODE_EMIT_STARTUP_TIMING` | Emit startup timing outside `CLAUDE_CODE_REMOTE` | `:186279` |
| `CLAUDE_CODE_FORWARD_USER_INTENT` | Gate `yNt()`. Projects cannot set it. What is forwarded was **not traced** | `:132865` |
| `CLAUDE_CODE_ENABLE_SHARE_BUNDLE` | `/share` uploads a whole-transcript bundle | `:763221`, `:1734121` |
| `CLAUDE_CODE_PLUGIN_ATTRIBUTION` / `CLAUDE_CODE_SKILL_ATTRIBUTION` | Attribution channels, deleted from child-process env | `:102927`, `:102972` |
| `CLAUDE_CODE_ATTRIBUTION_ANNOUNCEMENT` / `_STATUS_TIMEOUT_MS` / `CLAUDE_CODE_DISABLE_ATTRIBUTION_CROSS_REPO` / `_BASELINE_REUSE` | Attribution UX and opt-outs. The announcement defaults to flag `CNo` = `true` | `:445768` |
| `CLAUDE_CODE_DISABLE_ORG_MEMORY` | Turn off organization memory | `:220957` |
| `CLAUDE_CODE_DISABLE_WEB_FETCH` | Turn off WebFetch. Projects may always set it to a truthy value | `:490232`, `:35414` |

Identity carriers. All are NEW and none is a credential:

- `CLAUDE_BG_DISPATCHER_SUBSCRIPTION_TYPE` / `_RATE_LIMIT_TIER` are handed to background children (`:102488–102491`).
- `CLAUDE_BRIDGE_REATTACH_OWNER_ACCT` / `_ORG` (`:376419–376420`) and `CLAUDE_CODE_BRIDGE_OWNER_ACCOUNT_UUID` / `_ORG_UUID` (`:24581–24584`) carry the owner account and organization.
- `CLAUDE_RUNNER_ACCOUNT_EMAIL` / `CLAUDE_RUNNER_ACCOUNT_ID` are set **for** self-hosted runner hook scripts, from the work order's JWT claims (`claims.account_email`, `claims.account_id`, `:617889–617890`), together with `CLAUDE_RUNNER_ORDER_ID` = `claims.jti` and `CLAUDE_RUNNER_POOL_ID`.
- `CLAUDE_CHROME_PAIRED_DEVICE_ID` (`:876427`) and `CLAUDE_CODE_DESKTOP_APP_VERSION` (`:24629`).
- `CLAUDE_PID`, which is exported to children as `process.pid` (`:322185`).
- `COMPUTERNAME`, read by a computer-name lookup on win32 (`:869462`). Its consumer was not traced.

**No environment variable was found that overrides the persistent `userID`/`machineID`/`summonSidKey`.** Three registry names match `MACHINE|USER_ID|SUMMON|ANON`. None of them is an identity override: `CLAUDE_CODE_BRIDGE_CHILD_MACHINE_SETTINGS` is a bridge-child settings gate (`:335122`), `SPACE_CREATOR_USER_ID` is the Hugging Face Spaces deployment detector (`:12563`), and `CLAUDE_CODE_DISABLE_AWAITING_USER_IDLE` only matches the substring. The first draft said there were zero matches, which was wrong. Where those IDs are transmitted is still not established (`_facts.md` §3).

**NEW credential variables:**

- `CLAUDE_CODE_ARTIFACTS_API_TOKEN`
- `CLAUDE_CODE_MEMORY_API_TOKEN` (read only via the inert `nr`)
- `CLAUDE_CODE_SLACK_TAG_TOKEN`
- `CLAUDE_CODE_GATEWAY_TOKEN_FILE_DESCRIPTOR`
- `CLAUDE_CODE_MCP_SERVE_AUTH_TOKEN`
- `CLAUDE_CODE_MESSAGING_TOKEN`
- `CCR_AGENT_PROXY_CA_CERT_B64`
- `ANTHROPIC_WORK_SECRET` (`:171585`)
- `ANTHROPIC_FOUNDRY_AUTH_TOKEN`: **RE-ADDED** after 2.1.197 removed it

The tokens are in the subprocess secret-scrub list `vo` (`:62623`, 95 names, also matched with an `INPUT_` prefix) and the GitHub-Action input list `rMo` (`:62807`).

## Notable NEW families (all absent in 2.1.197)

- **Artifacts (40 vars).** `CLAUDE_CODE_ARTIFACT_*`. Most are `triBool` overrides of a codenamed flag, e.g.:
  - `_COMMENTS` → `tengu_teal_corbel` (`:698965`)
  - `_MULTI_FILE` → `tengu_cobalt_plinth_bracken` (`:690415`)
  - `_DELETE` → `tengu_cobalt_plinth_alder` (`:783026`)
  - `_VERIFY` → `tengu_osier_pylon_trace` (`:777425`)

  Some default to `true`: `_DB` (`:775904`), `_PIN` (`:783544`), `_PATH_PIN` (`:782334`), `_PUBLISH_EDITS` (`:373024`), `_QUICKSTART` (`:778126`). There are new base-URL variables (`_ASSET_`, `_LIVE_`, `_SYNC_`, `_VIEWER_BASE_URL`), all in the first-party base-URL list `sB` (`:35308`). `CLAUDE_CODE_ARTIFACT_DIRECT_UPLOAD` was REMOVED.
- **Self-hosted runner (BYOC) hook environment (30 vars).** `CLAUDE_RUNNER_*` is mostly set **for** hook scripts, not read from the user:
  - repo URL/ref, checkout path, session id/uuid (`:601381–601388`)
  - work-order claims (`:617883–617895`)
  - `CLAUDE_RUNNER_SKIP_GIT_VERIFY` (danger, `:601465`)
  - `CLAUDE_RUNNER_USE_GIT_PROXY` (`:614727`)
- **Remote tools / bridge / CCR (44 vars).**
  - `CLAUDE_CODE_REMOTE_TOOLS_*`, 8 of them inert (`nr`)
  - `CLAUDE_BRIDGE_REATTACH_*`
  - `CLAUDE_CODE_CCR_EARLY_*` (`:804846`, `:413210`, `:774128`)
  - `CCR_AGENT_PROXY_*` (`:1469716`)
  - `CCR_ON_BRANCH_DEFAULT_GUARD`, an enum `enforce|observe|off`. Raw presence forces `enforce`, otherwise flag `tengu_on_branch_default_guard_observe` applies (`:474333–474334`)
- **Auto-mode classifier knobs (17 new `CLAUDE_CODE_AUTO_MODE_*`).** 15 are read only via the inert `nr` (`:332983`–`:575484`). The live ones are `CLAUDE_CODE_AUTO_MODE_SERVER` (`:431420`) and `CLAUDE_CODE_AUTO_MODE_TIER` (rawStr, `:454373`).
- **Codenamed gates (40).** Examples: `CLAUDE_CODE_AMBER_ASTROLABE`, `_BASALT_COVE`, `_BISON_CAIRN`, `_GORSE_PLOVER`, `_HARBOR_KITE*`, `_STREAMED_BUMBLEBEE`, `_SQUISHY_NEWT`, `_PARSED_WILLOW`, `_COZY_TEAPOT` (enum `strict|relaxed`), `_CURRIED_TRINKET` (enum `control|lean|short|short_v2|capped`). Many feed the prompt-gate helper `cU(name, …)` (`:161182–161259`), or override a `tengu_*` flag through `Z3t`/`cfr` (`:491664`, `:725297`).
- **Safety relaxations (danger).** Each disables a guardrail:
  - `CLAUDE_CODE_DISABLE_DANGEROUS_RM_TIMEOUT` (`:431005`)
  - `_DISABLE_SUBSTITUTION_RM_PROMPT` (`:428434`)
  - `_DISABLE_INLINE_SHELL_RM_PROMPT` (`:428891`)
  - `_DISABLE_POWERSHELL_CMD_RM_DENY` (`:1025736`)
  - `_DISABLE_MEMORY_MASS_DELETE_HOLD` (threshold becomes `Infinity`, `:317073`)
  - `CLAUDE_CODE_SANDBOX_LEAVE_DENIES_TO_SRT_WIN` ("a settings file cannot set it", `:273324`)
  - `CLAUDE_CODE_DISABLE_BEDROCK_CONTENT_TYPE_GUARD` (`:182505`)

  The opposite direction: `CLAUDE_CODE_RESTRICTED` (`:928`), `CLAUDE_CODE_RESTRICT_PERSONAL_CONFIG` (personal skills cannot pre-approve tools, `:224441`) and `CLAUDE_CODE_STRICT_INLINE_SHELL_RM_PROMPT` (`:428537`).
- **Model / inference:**
  - `ANTHROPIC_DEFAULT_MODEL` (`:125457`)
  - `ANTHROPIC_BEDROCK_REGION_PREFIX`, an enum `us|eu|apac|jp|au|global` (`:116148`)
  - `CLAUDE_CODE_PROMPT_CACHE_TTL` / `_SUBAGENT_PROMPT_CACHE_TTL`, enum `5m|1h` (`:36933`)
  - `CLAUDE_CODE_NO_MODEL_FALLBACK` / `_DISABLE_MODEL_ACCESS_FALLBACK` (`:124423`)
  - `CLAUDE_CODE_OVERLOADED_RETRY_BASE_DELAY_MS` (500–32000) and `_MAX_DELAY_MS` (32000–64000) (`:524855`)
  - `CLAUDE_CODE_RETRY_WATCHDOG_MAX_WAIT_MS` (`:524843`)
  - `CLAUDE_CODE_REMOVE_PROMPT_STRINGS`, a JSON array of prompt strings to remove ("prompt ablation", `:446209`)
  - `CLAUDE_CODE_MODEL_CATALOG(_URL)` (`:792222`, `:758925`)
  - `CLAUDE_CODE_SUBAGENT_MODEL_FORCE`
  - `CLAUDE_CODE_WORKFLOW_SUBAGENT_MODEL`
  - `CLAUDE_CODE_3P_PROBE_WROTE_*_DEFAULT` / `3P_SEEDED_*`, set by the 3P model probe (`:124377–124384`)
- **Subagents / workflows:**
  - `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` (`:486634`)
  - `_MAX_SUBAGENT_SPAWN_DEPTH` (`:372312`)
  - `CLAUDE_CODE_WORKFLOW_MAX_CONCURRENT_AGENTS` (1–256, `:942633`)
  - `_WORKFLOW_SIZE_WARNING_*` (`:1304826`)
  - `CLAUDE_REMOTE_WORKFLOW_SCRIPT/ARGS` (`:940574`)
- **MCP:**
  - `MCP_PROTOCOL_NEGOTIATION=legacy` opts out of MCP protocol version 2026-07-28 (`:1602156`; in-binary changelog `:773348`)
  - `MCP_DISCOVERY_CACHE*` (`:492539`, `:806350–806380`)
  - `MCP_SDK_GENERATION` `v1|v2` (`:373313`)
  - `CLAUDE_CODE_MCP_PREWAIT_SERVERS(_MS)` (`:1490043`)
  - `CLAUDE_CODE_ENABLE_REFRESH_MCP_TOOLS`, which adds a RefreshMcpTools tool (`:743766`)
  - `CLAUDE_CODE_MCP_SERVE_*`
- **Memory / context:**
  - `CLAUDE_CODE_POST_TURN_MEMORY` (+`_CONFIG` JSON, `_SYNC`), a post-turn extraction pass that stays off without a valid config (`:112255`, `:745978`)
  - `CLAUDE_CODE_MEMORY_PUSH_DELETE_MODE` `corroborate|immediate|never` (`:317056`)
  - `CLAUDE_CODE_SILENT_TURN_REMINDER*` (`:553391–553415`)
  - `CLAUDE_CODE_SLEEP_COMPACT(_AFTER_MS)`
  - `CLAUDE_CODE_FILE_READ_MAX_PDF_PAGES_PER_MESSAGE/_PER_TURN` (`:549680`)
- **Accessibility:** `CLAUDE_AX_ANNOUNCEMENT_HOLD_MS` (default 1000, capped at 10000, `:101613`), `_PREPARK_MS`, `_STARTUP_QUIET_MS`, `_REWRITE_HELD_ANNOUNCEMENT`.
- **Test / eval harness (danger):**
  - `CLAUDE_CODE_TEST_ALLOW_REAL_NETWORK` (test runtimes otherwise block the network, `:92119–92139`)
  - `CLAUDE_CODE_EVAL_CONFINED` (32 read sites)
  - `CLAUDE_CODE_EVAL_ALLOW_FLAG_OVERRIDES` (operator allowlist for `growthbook_overrides`, `:1649768`; read via `nr`, so inert)
- **Third-party and host variables newly read:**
  - AWS: `AWS_ENDPOINT_URL_STS` (precedence STS → `AWS_ENDPOINT_URL` → `sts.{region}.amazonaws.com`, `:85537`), `AWS_ENDPOINT_URL_BEDROCK(_RUNTIME)`
  - `CLOUDSDK_ACTIVE_CONFIG_NAME`
  - `SUDO_UID/GID/USER` (`:1642954`)
  - `ANDROID_HOME`
  - `BUN_CHROME_PATH`
  - `WEZTERM_PANE`, `ALACRITTY_WINDOW_ID`
  - `PROGRAMDATA`, `ALLUSERSPROFILE`, `HOMESHARE`, `OneDrive*`
  - `CDPATH`, which is neutralised: commands run as `CDPATH= cd -- …` (`:52803`)

## Inert in this build (read only through `nr`, 55 names)

These are read only as `nr.NAME`, and `nr` is backed by `SN = {}` (`:13927`), so setting them in the environment has no effect. Code at the read sites falls through to the GrowthBook flag or a constant. Examples:

| Variable | Read site | Fallback |
|---|---|---|
| `CLAUDE_CODE_AUTO_MODE_TEMPERATURE` | `:457336` | (2.1.197 also inert via `QO`) |
| `CLAUDE_CODE_COORDINATOR_PROPAGATE_NESTED_MEMORY` | — | 2.1.197 doc listed it as a live knob, but there it was read through the inert `QO` |
| `CLAUDE_CODE_DISPATCH_V2D` / `_V2S` | `:526103–526105` | flags `tengu_dreamy_frost` / `tengu_cedar_lattice` |
| `CLAUDE_CODE_REMOTE_TOOLS_JUMP_QUEUE` | `:321312` | `tengu_valiant_rain` |
| `CLAUDE_CODE_FLEET_PAST_SESSIONS` | `:368782` | `tengu_fleet_past_sessions` |
| `CLAUDE_CODE_ARTIFACT_MCP` | `:781497` | `true` |
| `CLAUDE_RUNNER_TRUST_CANONICAL_PREWARM` | `:610887` | — |
| `CLAUDE_CODE_MEMORY_API_TOKEN` | `:138496` | — (the scrub lists `vo`/`rMo` still name it) |
| `CLAUDE_REMOTE_TOOLS_BRIDGE_URL` | `:1113298` | URL derived from `W5()` |
| `CCR_RUNNER_STARTUP_TIMING` | `:186282` | The CCR runner **sets** it in the child env (`:612052`), but the child only reads it through `nr`, so the payload is dropped |
| `CCR_PREWARM_VDA` / `_STAT` / `CCR_DELTA_RESET` / `CCR_PREFETCH_NETWORK` | `:186300–186303`, `:603220` | Startup-timing fields are `undefined`, and `Kt()` is always false |

Tentative: an internal build could fill `SN` at build time. Nothing in this binary does.

## Removed in 2.1.300 (present in 2.1.197)

Each name below is a standalone token in 2.1.197 `cli.min.js` (count ≥ 1) and has **0 occurrences** in the 2.1.300 corpus:

| Variable | Note |
|---|---|
| `ANTHROPIC_BEDROCK_MANTLE_API_KEY` | Mantle key removed. `AWS_BEARER_TOKEN_BEDROCK` remains in the Mantle/AWS key list `Py` (`:35279`) |
| `CLAUDE_CODE_ENABLE_DESIGN_MCP` | Design MCP env toggle gone. The 2.1.197 doc called it new |
| `CLAUDE_CODE_ARTIFACT_DIRECT_UPLOAD` | Superseded by the `CLAUDE_CODE_ARTIFACT_*` family |
| `CLAUDE_PREVIEW_CLASSIFIER_FLOOR` | `CLAUDE_CHROME_CLASSIFIER_FLOOR` remains (Chrome-hardening map `v`) |
| `CLAUDE_CODE_SHOJI_ENGINE` | Shoji render-engine env removed |
| `CLAUDE_CODE_SKILL_DESC_REFRAME`, `CLAUDE_CODE_SKILL_NAME`, `CLAUDE_CODE_SKILL_DESCRIPTION`, `CLAUDE_API_SKILL_DESCRIPTION` | Skill-description env plumbing removed |
| `MAX_CLAUDE_MD_BYTES` | The CLAUDE.md byte cap that 2.1.197 called new is gone |
| `CLAUDE_CODE_FABLE_BRIDGE_DIALOG_TIMEOUT_MS`, `CLAUDE_REPL_VERBOSE`, `CLAUDE_REPL_VARIANT` | — |
| `CLAUDE_CODE_AUTO_MODE_SIBLING_CONTEXT` | — |
| `CLAUDE_CONTEXT_COLLAPSE`, `CLAUDE_CONTEXT_COLLAPSE_MODEL` | — |
| `CLAUDE_CODE_MID_CONVERSATION_SYSTEM`, `CLAUDE_CODE_VERIFY_PROMPT`, `CLAUDE_CODE_OWNERSHIP_FRAME`, `CLAUDE_CODE_INVESTIGATE_FIRST`, `CLAUDE_CODE_PLAN_MODE_INTERVIEW_PHASE` | Prompt-experiment switches |
| `CLAUDE_CODE_COMMIT_LOG`, `CLAUDE_CODE_JSONL_TRANSCRIPT` | — |
| `CLAUDE_CODE_FORCE_SANDBOX`, `CLAUDE_CODE_FORCE_FULL_LOGO` | — |
| `CLAUDE_BRIDGE_USE_CCR_V2`, `CLAUDE_CODE_POST_FOR_SESSION_INGRESS_V2`, `CLAUDE_SUBAGENT_BG_SHELL_MAX_MS`, `CLAUDE_INTERNAL_WARM_RESUME_QA` | — |
| `CLAUDE_AI_OAUTH_SCOPES` | A constant in 2.1.197, not an env var |
| `CLAUDE_OPUS_4_8`, `CLAUDE_SONNET_4_6` | Model-key tokens (not env) |
| `SYSTEM_OIDCREQUESTURI`, `API_MAX_INPUT_TOKENS`, `API_TARGET_INPUT_TOKENS`, `USE_API_CLEAR_TOOL_USES`, `USE_API_CLEAR_TOOL_RESULTS`, `TEAM_MEMORY_SYNC_URL` | Non-prefixed, removed |

The set difference gives 30 removed `CLAUDE_*` and 1 removed `ANTHROPIC_*`. All 31 are in the table above.

The 2.1.197 dataset also had 32 entries that were never standalone tokens even in 2.1.197. Examples are `CLAUDE_4_8_OPUS` (only a suffix of `VERTEX_REGION_CLAUDE_4_8_OPUS`), `CLAUDE_FABLE_5`, `*_alias` markers, `CLAUDE_CODE_AUTOCOMPACT_PCT_OVERRIDE` (the real name is `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`) and `ENABLE_BTW`. They are dropped and listed under `dataset_artifacts_2_1_197` in the YAML. They are not removals.

## Per-domain summary (YAML category counts, 1,367 variables)

| Category | Count | | Category | Count |
|---|---|---|---|---|
| host-system | 163 | | ide-terminal-ui | 59 |
| runtime-misc | 117 | | proxy-network | 52 |
| model-inference | 101 | | context-compaction | 50 |
| telemetry | 90 | | plugins-skills | 48 |
| auth-identity | 86 | | mcp | 47 |
| bridge-remote | 77 | | artifacts *(new category)* | 40 |
| sdk-entrypoint | 65 | | codename-gate *(new category)* | 40 |
| providers | 64 | | background-daemon | 36 |
| permissions-sandbox | 63 | | privacy-optout | 31 |
| runner-byoc *(new category)* | 30 | | loops-workflows | 29 |
| feature-toggle | 17 | | session-remote | 13 |
| ui | 12 | | testing-eval *(new category)* | 11 |
| runtime-paths | 10 | | cowork | 9 |
| background-agents | 5 | | loops-teams | 2 |

The 193 `host-system` and other entries that existed in 2.1.197 but were never catalogued, such as `GITHUB_ACTOR_ID`, `SSH_CONNECTION` and `AWS_SECRET_ACCESS_KEY`, are included with type and ref. Their purpose field says they were not decoded individually.

## Uncertainties

- **Purposes of new variables come from their read sites.** Where a variable only appears in a set (e.g. `CLAUDE_CODE_ARTIFACT_REPL`, `CLAUDE_CODE_ARTIFACT_ROOM`, seen only in `iRr`) or its effect was not followed past the read, the YAML says "behaviour beyond the read site not decoded".
- **Codename semantics are unknown.** For the codenamed gates (`*_ASTROLABE`, `*_BUMBLEBEE`, …), only the mechanism (env override of a flag or prompt gate) is verified.
- **Inert claim, scope.** `SN = {}` is not exported from module 34, and no `Object.assign(SN…)` or `SN[` write exists. `ple()` defines getters only for the map's own keys (`:13853–13872`), so `nr.X` is `undefined`. Every `nr.<UPPER_NAME>` read in the corpus was mapped to its module, and each of those modules imports `nr` from `chunk-t4xwnzyq.js` with no alias. The other `nr.` hits are in modules 976 and 1481, which use an unrelated local `nr` (`ACCESS_TOKEN`, `MCP_SERVERS_GROUP`). There are three dynamic `nr[…]` hits (`:884772`, `:1015817`, `:1340150`). All three use unrelated local `nr` bindings: a vendored re-export loop and two numeric tables.
- **Category assignments are editorial.** Carried entries keep their 2.1.197 category. Their purposes are carried from 2.1.197, and any line numbers inside them are rewritten as `2.1.197 cli.beauty.js:` because they point into the old build.
- **The `ref` column is a pointer, not a definition.** It is the first non-list read site the indexer found, so for some names it is a list membership such as the host-managed set or the child-env scrub.
