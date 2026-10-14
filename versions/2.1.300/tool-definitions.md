# Tool Definitions

> [Back to version index](../README.md)
>
> **Version**: 2.1.300 | **Build**: `2026-10-14T12:54:55Z` | **GIT_SHA**: `c6733ae1276880507ca0c5b053ae18fb0df090d6` | **Platform**: Linux x86-64 | **Runtime**: Bun 1.4.3

See [data/tools.yaml](data/tools.yaml) for the structured dataset.

This build has **84 built-in tool sites** (2.1.197: 49), the canonical count in
[`bundle/_facts.md` §1.4](bundle/_facts.md). The sites expand to **92 distinct tool names**:
**47 kept** from 2.1.197, **45 NEW**, and **2 REMOVED** (`TaskOutput`, `REPL`).

How the two numbers relate:

- 86 module-aware literal `Jt({…})` sites, minus the `"mcp"` template and `TestingPermission`, leaves 84.
- 4 of those 84 sites are parametric factories, and they build 11 names between them.
- `Artifact` is built through a non-literal `Jt(…)` call, so the literal count misses it.
- 84 − 4 + 11 + 1 = **92**. Of the 84 sites, 46 are kept single-name tools, 34 are new single-name tools and 4 are parametric.

Line numbers refer to `bundle/cli.beauty.js`. Short minified names are **chunk-local** in this
code-split build, so every name below is given with its chunk (module) where that matters.

## How Tools Are Built

Every built-in tool goes through the factory **`Jt(spec)`** (2.1.197: `Ys`), at `:208924` in module 243
`chunk-181yxhab.js`. The factory is no longer a one-line `defineProperties`:

```js
function Jt(e) {
  let n = e.create,                                   // NEW: per-call implementation factory
      s = (S, R) => (Ko(e.name, R), n.call(e, S)),
      r = (S, R, E, C, P) => ({ tool: s(cAr(S), S?.session), call: { …runEngine, ask, signal, … } }),
      h = {
        create: …,
        call: (S, R, …) => {
          let F = GZ(R?.session, e.name);             // NEW: is this tool routed to a remote runner?
          if (x?.permissionCheckedFor !== void 0 && x.permissionCheckedFor !== F) return Promise.reject(… "NOT_RUN");
          if (F) return Qo(e, F, S, …);               // remote execution
          …
        },
        validateInput, checkPermissions /* passthrough when routed */, permissionCheckFailureDecision
      },
      y = Object.assign(Object.defineProperties({ ...yl, userFacingName: () => e.name },
                                                Object.getOwnPropertyDescriptors(e)), h);
  return y
}
```

The default trait bag **`yl`** (`:208905`) is: `isEnabled:()=>!0`, `isConcurrencySafe:()=>!1`,
`isReadOnly:()=>!1`, `isDestructive:()=>!1`, `remoteExecution: gAr` (`= {supported:!1}`, `:208894`),
`toAutoClassifierInput:()=>""`. If a tool omits a field, the default applies. A tool with no `isEnabled`
is therefore **always on**, a tool with no `isReadOnly` is **not read-only**, and a tool with no
`shouldDefer` is **not deferred**.

Members per tool object (verified by parsing the top-level keys of all 86 sites):

| Member | Purpose | vs 2.1.197 |
|---|---|---|
| `name` | user-facing name, held in a string const (e.g. `ze = "Bash"`) | same |
| `searchHint` | one-liner for ToolSearch and simple-mode descriptions | same |
| `description()` / `prompt()` | full description / prompt text | same |
| `get inputSchema()` / `get outputSchema()` | lazy Zod schema | same |
| `isReadOnly` / `isConcurrencySafe` / `isDestructive` / `isEnabled` | traits | same |
| `shouldDefer`, `alwaysLoad`, `strict`, `aliases`, `maxResultSizeChars` | misc traits | same; `shouldDefer` can now be a **getter** |
| **`create(call)`** | returns the per-call implementation; `Jt` wraps it with `call`/`validateInput`/`checkPermissions` | **NEW** |
| **`backgrounding`** | `"never"` \| `"self"` \| `"detach"` (87 occurrences of `backgrounding:`; 0 in 2.1.197) | **NEW** |
| **`remoteExecution`** | `{supported, decidingInputFields?, refusedInputFields?}` | **NEW** |
| **`enablesCodeExecution`** | marks code-executing tools | **NEW** |
| `requiresUserInteraction()` | user-facing prompts (AskUserQuestion, ExitPlanMode, PublishPlugin, …) | existed (8 occurrences in 2.1.197, 43 now) |
| **`whenToUse`** | short hint printed on a deferred tool's name line (Artifact head) | **NEW** |

### Remote execution (NEW)

Tools can now run on another machine, called a "tool host". `GZ(session, name)` (`:205196`) looks the
tool up in a per-session runner map. When a runner exists, `Jt`:

- sends `call()` to `Qo(...)`;
- makes `checkPermissions` return `{behavior:"passthrough"}`;
- makes `permissionCheckFailureDecision` deny with *"… its permission check could not be completed."*

Tools that declare `remoteExecution.supported`:

- **Bash.** `decidingInputFields: [command, run_in_background, dangerouslyDisableSandbox]`, `refusedInputFields: qdr`.
- **Read.** `[file_path, offset, limit, pages, allow_large]`.
- **Write.** `[file_path, content]`.
- **Edit.** `[file_path, old_string, new_string, replace_all]`.
- **Glob, Grep.** `{supported:!0}`.
- **TaskStop.** Getter `{supported: jW()}`.
- **PowerShell.** Getter `an() ? Qs : gAr`.

The machine is selected with an input property `_host` (`$r`, `chunk-405k96bq.js:197661`). The serialiser
strips that property when forwarding is unavailable (see below). The string `"_host"` occurs 0 times in 2.1.197.

## How Tool Schemas Are Serialised for the API

The serialiser is **`QF(tool, ctx)`**, `:446462` in module 424 `chunk-538n62w8.js` (2.1.197: `Etr`).

```js
// QF(e, n) — simplified
Vn = KNo(...) /* replay from recorded snapshot */ ?? zIe.get(cacheKey);
if (!Vn) {
  Kn = b1t(e, { remoteToolForwarding: await vGe([e]) });   // schema
  mo = await GNo(e, {...});                                  // description
  io = e.isMcp ? mo : HCe(mo, n.querySource);                // prompt ablation (NEW)
  go = n.withoutToolDescribeHooks ? {description: io, isDeferred: ko}
                                  : await HYs(e, io, ko);    // tool-describe hooks (NEW)
  Vn = { name, description: go.description, input_schema: Kn };
  if (Q /* model has structured-outputs beta */) {
    if (e.strict === !0) { let So = Ywr(Kn); if (So.ok) { Vn.strict = !0; Vn.input_schema = So.schema } else warn(...) }
    else if (e.strictInputJSONSchema && k("tengu_structured_output_strict", !1)) { Vn.strict = !0; ... }
  }
  if (C1t(provider, cfg)) Vn.eager_input_streaming = !0;
}
eo = { name, description, input_schema, ...strict, ...eager_input_streaming };
if (n.deferLoading) eo.defer_loading = !0;
if (n.cacheControl) eo.cache_control = n.cacheControl;
if (e.name === Ku /* WebSearch */ && ebr()) eo.citations = { enabled: !0 };   // NEW
if (jU()) { /* strip to name/description/input_schema/cache_control (+defer_loading if !btn()) */ }
```

Details (all from `:446393`–`:446598`):

- **Description, `GNo()` (`:446393`; was `glm`).** It returns the full `prompt()`, except under
  `CLAUDE_CODE_SIMPLE` (`sBe()`, `:161269`). In that mode it returns `searchHint`, or the first paragraph
  of `prompt()` when there is no hint. Same shape as 2.1.197.
- **Prompt ablation, `HCe()` (`:446224`, NEW).** It removes every string listed in
  `CLAUDE_CODE_REMOVE_PROMPT_STRINGS`, a JSON array. The client-data key `remove_prompt_strings` is the
  fallback. Each removal fires `tengu_remove_prompt_strings_applied`. MCP tool descriptions are exempt.
- **Tool-describe hooks (NEW).** `HYs = Pe.resolveToolDescription` (`:128004`; registry `xU()`
  `:127935`) can rewrite a tool's description **and** its deferral. The override is recorded with
  `recordDeferral`, and `isDeferredTool` consults it first.
- **Schema, `b1t()` (`:446243`).** It uses `inputJSONSchema` verbatim or converts the Zod schema with
  `CH()`. The team-field strip runs when teams are off. `_host` is removed when the tool supports remote
  execution but `vGe()` reports no forwarding.
- **`strict: true`.** All three conditions must hold:
  1. The model's beta list contains `bae` (`aKn`, `:127578`). `bae = k("structured_outputs", "structured-outputs-2025-12-15")`
     (`:92281`), so the header string itself is flag-overridable. That beta is
     attached only when `tengu_tool_pear` (default `!1`) **and** `rKn(model)` hold (`:127468`).
  2. The tool declares `strict:!0`.
  3. `Ywr(schema)` (`:300383`) accepts the schema. If it rejects it, the client logs *"has strict: true but its
     schema is not strict-compatible … sending non-strict"*.

  The flag still gates the feature, but now through the beta. 2.1.197 checked it inline. The same
  **8** tools declare `strict:!0`: Bash, Read, Write, Edit, Grep, PowerShell, TodoWrite, ReportFindings.
  `strictInputJSONSchema` is a second, NEW path, gated by `tengu_structured_output_strict`.
- **`eager_input_streaming`, `C1t()` (`:446432`).**
  `CLAUDE_CODE_ENABLE_FINE_GRAINED_TOOL_STREAMING !== false && (firstParty && Si() && tengu_fgts ||
  vertex/bedrock eagerInputStreaming with no custom base URL) || env === true`. The shape is unchanged.
- **`citations: {enabled: true}` on WebSearch (NEW).** Added when `ebr()` (`:361655`):
  `CLAUDE_CODE_WEBSEARCH_CITATIONS && Aa() && !jU()`. The env var occurs 0 times in 2.1.197.
- **Beta stripping.** `jU()` (`:92358`) is `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS || HIPAA`, as in
  2.1.197. When it is on, keys outside `{name, description, input_schema, cache_control}` are stripped, and
  the strip is logged once (`:446380`). NEW: `defer_loading` survives the strip when tool search is forced
  on (`!btn()`).
- **Recorded replay (NEW).** `KNo()` (`:446437`) can send a tool from a recorded prompt-snapshot entry
  instead of rebuilding it. It returns early unless `kZ()` (`:186504`, `CLAUDE_CODE_REMOTE && we()`) holds and
  a recorded entry exists; a fresh send from the record also needs `tengu_binary_balloon` (read via `vn`,
  default `!1`, `sendsFromRecord()` `:446355`). Artifact, redescribed tools and strict tools are excluded.
- **Memo cache key (`:446495`).** It grew from 2.1.197's `L:`/`F:` prefixes to roughly 20 prefixes that
  fold in per-tool context: `C1/CL/C0` for SendMessage, `A1/A0` for ListAgents, `P1/P0` for the Agent plan
  tier, `M1/M0` for Monitor, `W1/W0` for ScheduleWakeup, `WA1/WA0` for WebFetch with Artifact present,
  `PS1/PS0` for SearchPlugins, plus the artifact and inbox bits. Each tool is therefore serialised once per
  combination of those contexts.

### Schema property stripping

The strip is unchanged in content. The map is now `BNo` (`:446256`):
`ExitPlanMode → [launchSwarm, teammateCount]`, `Agent → [name, team_name, mode]`. It applies when
`!es()`. `es()` (`chunk-fcn14yvq.js:346198`) is
`(CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS || argv includes "--agent-teams") && k("tengu_amber_flint", !0)`.
2.1.197's `ll()` has the same logic: env or argv, **and** the flag. The 2.1.197 doc said "env **or** flag".

## Tool Registry

The registry is `H4 = { getAllBaseTools: Xb, getTools: uN, assembleToolPool: _Gt }` (`:743821`), in module 638
`chunk-8y962bdx.js`.

- **`Xb()` (`:743763`)** lists every built-in. Most tools come from other chunks through
  `import.meta.require` (`:743717`–`:743757`). Artifact is registered lazily:
  `Wr(ARTIFACT_TOOL_HEAD, () => ArtifactTool)`. Conditional inclusions:
  - Bash: `Bl()`.
  - TaskCreate/Get/Update/List: `NP()`.
  - LSP: `MFe()`, which is `$e("true")`, i.e. always.
  - Enter/ExitWorktree: `wwt()`.
  - The nine self-hosted runner tools: `Hr()` → `getWizardOperatorToolsEnabled()`.
  - RefreshMcpTools: env `CLAUDE_CODE_ENABLE_REFRESH_MCP_TOOLS`.
  - ToolSearch: `Ty()`.
  - PowerShell: `zt()`.
  - Glob/Grep: filtered through `Zre()`.

  Six slots (`rn, nn, sn, an, ea, ln`) are `null`, and `un()` returns `null`. A *tentative* reading is that
  these are tools compiled out of the external build.
- **`uN()` (`:743779`)** does the following:
  - Removes the MCP resource tools and StructuredOutput from the base list (`:743793`).
  - Filters by `isEnabled()`.
  - Re-adds Glob/Grep when Bash is absent (`:743806`).
  - Appends WaitForMcpServers when needed (`:743810`).
  - Under `CLAUDE_CODE_SIMPLE`, returns only Bash (if `Bl()`), PowerShell (if enabled), Read and Edit. In
    coordinator mode it adds Agent, TaskStop, SendMessage and Workflow (`:743788`).
- **Glob/Grep hiding.** `Zre()` (`:392570`) returns `{Glob, Grep}` when `nT() && Bl()`. `nT()` is true
  unless one of these holds:
  - the user opted in to search tools by naming Glob or Grep in `--allowedTools`/`--tools`
    (`qUo(...)`, `:731374`);
  - `CLAUDE_CODE_ENTRYPOINT` is `local-agent`.

  In the default case Glob and Grep are therefore **dropped while Bash is available**. The same mechanism
  exists in 2.1.197 (`bC()`/`Wft()`, 2.1.197 `:290570`), but the 2.1.197 doc did not cover it.

## Full Tool List

Columns:

- **Category** is the tool's `isReadOnly`. *write* means the method returns `!1` or is absent (default
  false). *dynamic* means it depends on the input.
- **Deferred** is the effective default (see the next section).
- **Δ** compares against 2.1.197: `=` unchanged, **C** changed, **N** new.

### Core (always loaded)

| Tool | Var / name const | Line | Category | Deferred | Enabled when | Δ |
|---|---|---|---|---|---|---|
| **Bash** | `Ai` / `ze` | `:583502` | dynamic | no | registry `Bl()` (`:207748`): always off Windows; Windows needs Git Bash | **C**: `isReadOnly = !Ev(ze) && Xat(…)`; `Ev()` (`:205202`) forces false in diskless sessions (`me()` = `isDiskless`); remoteExecution |
| **Read** | `Pw` / `Je` | `:550051` | read-only | no | always | **C**: remoteExecution; `maxResultSizeChars: 1/0` |
| **Write** | `dE` / `Yt` | `:442728` | write | no | always | **C**: remoteExecution |
| **Edit** | `Eg` / `dt` | `:575659` | write | no | always | **C**: remoteExecution |
| **Glob** | `PO` / `no` | `:444031` | read-only | no | hidden by `Zre()` while Bash is present (see above) | = (remoteExecution added) |
| **Grep** | `IO` / `xr` | `:444275` | read-only | no | same as Glob | = (remoteExecution added) |
| **PowerShell** | `Qa` / `xt` | `:1028901` | dynamic (`rn(e)`) | no | `$w()` (`:207740`): off Windows only if `CLAUDE_CODE_USE_POWERSHELL_TOOL === true`; on Windows the env value, else true without Git Bash, else `tengu_cobalt_ridge` (default `!1`) | = |
| **Agent** (alias `Task`) | `bGt` / `ht` | `:728479` | read-only | no | always | = |
| **AskUserQuestion** | `fQ` / `Xo` | `:734881` | read-only | no | `mY()` (`:417771`) | = |
| **StructuredOutput** | `_e()` → `Avs` / `Ha` | `:300539` | read-only | never | always | **C**: now built by a factory function `_e(overrides, onResult)` |
| **ToolSearch** | `Kur` / `Ci` | `:451605` | read-only | never | `Ty()` (`:219761`) | = |
| **SendUserMessage** (alias `Brief`) | `uo` / `tm` | `:739053` | read-only | never | `qO() \|\| Mxe()`; `Mxe` = `CLAUDE_CODE_PEWTER_OWL_TOOL` / `pewter_owl_tool` | = |
| **SendUserFile** | `Se` / `Hy` | `:1442856` | read-only | **getter** `L()` | unless `CLAUDE_CODE_ATTACHMENTS_BY_PATH`: firstParty, `!Ct()` and `allow_send_file`; then `tengu_send_user_file` (default `!0`); then `(Sc() \|\| R()) && !qO()` (`:1442877`–`:1442883`) | **C**: deferral moved onto the tool |
| **ReportFindings** | `bo` / `GR` | `:739849` | read-only | no* | always | **C**: forced deferred by `tengu_shiny_stardust`; `maxResultSizeChars: 256` |
| **SubagentHandback** 🆕 | `hTn` / `Tv` | `:725055` | write | never (`alwaysLoad:!0`) | always | **N**: "deliver your final report to the agent that spawned you" |

### Deferred by default (`shouldDefer:!0`)

| Tool | Var / name const | Line | Category | Enabled when | Δ |
|---|---|---|---|---|---|
| **WebFetch** | `Sb` / `dr` | `:490196` | read-only | `!CLAUDE_CODE_DISABLE_WEB_FETCH && on("allow_web_fetch")` | **C**: new env kill switch; `backgrounding:"detach"` |
| **WebSearch** | `ko` / `Ku` | `:739474` | read-only | `on("allow_web_search")` and provider: firstParty / anthropicAws / **anthropicGoogleCloud** (`wD`, `:21770`) → on; gateway → off; vertex → model check; foundry → on (already on in 2.1.197, 2.1.197 `:426528`) | **C**: `allow_web_search` entitlement and the `anthropicGoogleCloud` branch are new |
| **NotebookEdit** | `bbe` / `Ki` | `:576386` | write | always | = |
| **TodoWrite** | `_o` / `xC` | `:740104` | write | `!NP() && TV()` | **C**: `TV()` model gate (below) |
| **TaskCreate / TaskGet / TaskUpdate / TaskList** | `xr`/`bE`, `Dr`/`i6`, `Nr`/`uT`, `Ur`/`aA` | `:743052`–`:743598` | write / ro / write / ro | `roe() = NP() && TV()` | **C**: `TV()` model gate |
| **TaskStop** (aliases `KillShell`, `KillBash`) | `Be` / `yd` | `:738871` | write | always | = (remoteExecution added) |
| **EnterPlanMode** | `iwn` / `mT` | `:733976` | read-only | `K4.isEnabled()` | = |
| **ExitPlanMode** | `K4` / `xu` | `:716089` | write | same logic as `mY()` | = |
| **ListMcpResourcesTool / ReadMcpResourceTool / ReadMcpResourceDirTool** | `r0`/`gY`, `o0`/`u1`, `tV`/`SV` | `:735328`, `:735667`, `:735515` | read-only | always (added outside the base list) | = |
| **Monitor** | `Ne` (base `$e` `:711514`) / `ml` | `:711551` | write (no `isReadOnly`) | `l6() && Bl()`; `l6 = k("tengu_amber_sentinel", !1)` | = |
| **CronCreate / CronDelete / CronList** | `I`/`af`, `C`/`Hw`, `I`/`Dxe` | `:1445572`, `:1445855`, `:1446119` | write / write / ro | `PC() = !CLAUDE_CODE_DISABLE_CRON && MG("tengu_kairos_cron", !0)` | = |
| **RemoteTrigger** | `dt` / `eU` | `:1441453` | dynamic | `firstParty && kt() && !CLAUDE_CODE_REMOTE && on("allow_remote_sessions") && on("allow_routines")` | **C**: `tengu_surreal_dali` gone (0 occurrences); read-only actions now include `list_runs`, `get_run_log` |
| **PushNotification** | `F` / `jP` | `:1434417` | read-only | `MG("tengu_kairos_push_notifications", !1, g)` | = |
| **SendMessage** | `Ns` / `Dn` | `:1429525` | dynamic | always; removed in diskless sessions | = |
| **EnterWorktree / ExitWorktree** | `_r`/`j0`, `Er`/`DFe` | `:742489`, `:742824` | write | registry `wwt()` | = |
| **LSP** | `It` / `ZF` | `:741843` | read-only | `tNe()` (body not resolved) | = |
| **DesignSync** | `et` / `SJt` | `:1435198` | dynamic | `WF()` (`:372217`): `on("allow_design_sync") && !nonessential-traffic-off && firstParty` | **C**: `CLAUDE_CODE_ENABLE_DESIGN_SYNC` is still registered (`:10977`) but `WF()` does not read it |
| **SendFile** 🆕 | `we` / `rK` | `:1431889` | write | `RLe() = Gi() && k("tengu_send_file", !1)` | **N**: "send files to another Claude Code session" |
| **FetchInboxMessage** 🆕 | `fe` / `cot` | `:1037456` | read-only | `isReplBridgeActive() \|\| Hen() !== undefined` | **N** |
| **EndConversation** 🆕 | `Y` / `ZP` | `:1439779` | read-only | main-loop model known and `Xsr(model)` | **N**: "only for sustained user abuse, or when the user explicitly asks to see it demonstrated" |
| **ProposeGoal** 🆕 | `X` / `OFn` | `:1444737` | read-only | interactive, not remote, not bg, `aht() !== "disabled"` | **N** |
| **OfferChromeSetup** 🆕 | `no` / `qSe` | `:738776` | read-only | `FZn()` (`:738694`) | **N** |
| **PublishPlugin** 🆕 | `Ctr` / `YSe` | `:1248732` | write | `k("tengu_copper_gazette", !1) === !0` | **N** |
| **SearchMcpRegistry / SuggestConnectors / ListConnectors** 🆕 | `R`/`A5e`, `g`/`G4t`, `z`/`V4t` | `:1441964`, `:1442214`, `:1442474` | read-only | `tCe() = CLAUDE_CODE_REMOTE && firstParty` | **N** |
| **ListPlugins / ListSkills** 🆕 | `se({…})` → `U`/`yEr`, `G`/`WEs` | site `:1030914` | read-only | `MKe()` (`:1030503`) | **N** (parametric) |
| **ArtifactComments / ArtifactData / ArtifactCheck** 🆕 | `m({addon})` → `w_`, `rg`, `vM` | site `:1424322` | delegates to Artifact | `WKe(addon)` | **N** (parametric) |
| **enable\_\_mcp\_\_claude-in-chrome, enable\_\_mcp\_\_remote-devices\_\_Claude\_Browser, enable\_\_mcp\_\_remote-devices\_\_computer, request\_computer** 🆕 | `d({name})` → `R`,`U`,`B`,`c` | site `:1432841` | read-only | `tre() !== null \|\| (cW() && GE() && vr("tengu_merry_tide", !1))` | **N** (parametric; `ENABLE_STUB_TOOLS` `:1433009`) |
| **self\_hosted\_runner\_\*** ×9 🆕 | `L,E,C,w,P,A,k,j,N` | `:1440089`–`:1440701` | 7 read-only; `requeue_session`, `spawn_local` write | registry `getWizardOperatorToolsEnabled()` | **N** |

(The 🆕 rows sit in this table because they are deferred by default.)

The nine self-hosted runner tools:

- `get_pool`
- `list_sessions`
- `list_runners`
- `list_secrets` (metadata only)
- `read_health` (`/healthz`)
- `read_metrics` (Prometheus `/metrics`)
- `requeue_session`
- `spawn_local`
- `tail_log` (with secret redaction)

### Never deferred (explicit `shouldDefer:!1` or `alwaysLoad`)

| Tool | Var / name const | Line | Category | Enabled when | Δ |
|---|---|---|---|---|---|
| **ScheduleWakeup** | `mo` / `fl` | `:739199` | write | always | **C**: `shouldDefer` `!0` → **`!1`**; its isDeferredTool exception is removed |
| **Artifact** | `QE` (head `oye` `:1399128`) / `cn` | `:1422795` | dynamic (wrapped) | head `isEnabled`: `fCr() === null` (`:355681`) | **C**: lazy head + `whenToUse`; comment/db/verify verbs split into add-on tools (map `xFt`, `:432423`) |
| **memory\_list / memory\_read / memory\_write** 🆕 | `Ro`/`dS`, `Iur`/`Vf`, `g0n`/`Oc` | `:740249`, `:444880`, `:282672` | ro / ro / write | `Cwe()` = memory mode `"tools"` (`:223445`) | **N** |
| **SubagentHandback** 🆕 | see Core | | | | **N** |

### Loaded up front, gated (no `shouldDefer`)

| Tool | Var / name const | Line | Category | Enabled when | Δ |
|---|---|---|---|---|---|
| **Skill** | `Ntt` / `_o` | `:733483` | write | `!getDisableSlashCommands()` | = |
| **Workflow** (alias `RunWorkflow`) | `di` / `Cu` | `:1449102` | write | `Pg()` = no disable reason (`gvo()`, `:162131`) | **C**: forced deferred by `tengu_shiny_stardust` |
| **WaitForMcpServers** | `woo` / `HH` | `:520225` | read-only | `vjr(model, clients)` (`:520221`) | = |
| **ShareOnboardingGuide** | `Vt` / `Uxe` | `:738391` | write | `TRt()` (`:458828`): `allow_team_onboarding` + `tengu_flint_harbor_share` (default `!1`) | **C**: forced deferred by `tengu_shiny_stardust` |
| **ShowOnboardingRolePicker** | `Qt` / `XSe` | `:738588` | read-only | `CLAUDE_CODE_REMOTE` | = |
| **Projects** | `On` / `pit` | `:1438453` | dynamic | `on("allow_projects_tool") && xe() !== undefined` | = |
| **ListAgents** 🆕 (alias `ListPeers`) | `x` / `Ld` | `:1391311` | read-only | `Gi()` (`chunk-dy20ypn9.js:348684`): false if `messagingBeyondOwnAgentsDisabled`; else `CLAUDE_CODE_HARBOR_KITE` if set; else on Windows `tengu_harbor_kite_win` (default `!0`) and `tengu_harbor_kite` (default `!0`) | **N** as a tool object; 2.1.197 had only the string |
| **Poll** 🆕 | `Qe` / `km` | `:1433456` | read-only | `W1()` (`:299898`), which requires `isPollEventIngressWired()` | **N**: "wait for and receive queued harness events" |
| **GetTask** 🆕 | `er` / `hh` | `:741287` | read-only | `vr("tengu_violin_rosin", !1) === !0 && …` | **N**: "check on a background shell command by task ID" |
| **ReadNotifications** 🆕 | `Ht` / `LP` | `:738300` | read-only | `yEn() = j() \|\| J()` | **N** |
| **RefreshMcpTools** 🆕 | `Ot` / `Mz` | `:742315` | read-only | env `CLAUDE_CODE_ENABLE_REFRESH_MCP_TOOLS` + MCP clients present | **N** |
| **SendFeedback** 🆕 | `Ko` / `Ho` | `:741070` | write | `pV()` (`:736641`) | **N**: "draft product or model-behavior feedback report queue" |
| **ObserverReport** 🆕 | `It` / `Te` | `:1262866` | write | always | **N**; not in `Xb()`; the path that injects it was not traced |
| **ClaudeDesign** 🆕 | `At` / `pY` | `:1436593` | dynamic | `zDe()` (`:785826`): DesignSync conditions + `tengu_omelette_fouet` (default `!1`) | **N** |
| **AppifactRepl** 🆕 | `Bi` / `Zut` | `:1426247` | write | `MJr() && sM()` | **N**: "run appifact SDK JavaScript against an artifact" |
| **propose\_skills** 🆕 | `bn` / `Sse` | `:1444062` | read-only | env-driven (`CLAUDE_CODE_SYNC_SKILLS`, `CLAUDE_CODE_SKILL_PROPOSALS`, …) | **N** |
| **SuggestPluginInstall / SuggestSkills** 🆕 | `j`/`nUe`, `F`/`VZt` | `:1031104`, `:1031220` | read-only | `MKe()` | **N**; `shouldDefer` getter |
| **SearchPlugins / SearchSkills** 🆕 | `ae({…})` → `K`/`F5e`, `q`/`jEs` | site `:1031273` | read-only | `MKe()` | **N**; `shouldDefer` getter `!(loadedUpFront?.())` |

### Non-tools (excluded from the count)

| Object | Site | Notes |
|---|---|---|
| `"mcp"` template | `chunk-6kzyz5jz.js:1202193` (`VDe`) | `isMcp:!0`; prototype for MCP server tools |
| `TestingPermission` | `:740165` (`Ed`, name const `Co`) | `isEnabled:()=>!1` |

2.1.197's `` `eval_registered__${name}` `` factory has no `Jt` site in 2.1.300. The prefix survives only
in classifiers (`_facts.md` §1.4).

### Removed vs 2.1.197

- **`TaskOutput`** has no `Jt` site.
  - It and its old aliases `AgentOutputTool`, `BashOutputTool`, `AgentOutput` and `BashOutput` are now in
    the **removed-tool set** `DCe` (`:447264`). That set also holds `Frame`, `FrameRead`, `TeamCreate`,
    `TeamDelete`, `SuggestBackgroundPR` and `AutofixPr`.
  - `DCe` makes `--tools` and permission rules that name these tools log *"names a removed tool"* and
    skip the entry (`:731223`, `:731498`).
  - The legacy alias map (`:7958`) dropped the four `*Output → TaskOutput` entries it had in 2.1.197
    (2.1.197 `:58550`).
  - `GetTask` is *tentatively* its successor. That inference rests on its purpose only.
- **`REPL`** has no `Jt` site. The name const `Wd = "REPL"` (`:218616`) survives in the async-agent
  allow-set and in a `getTools` filter (`:743799`).
- `ConnectGitHub` (`uUe`, `:371252`) is likewise referenced in tool sets but has **no tool object**.
  It is neither in 2.1.197's 49 nor in this build's 92.

### Corrections to the 2.1.197 doc (verified against 2.1.197 source)

Parsing the 2.1.197 `Ys({…})` objects the same way shows:

- **No `shouldDefer` in 2.1.197:** `Skill` (2.1.197 `:390269`), `Workflow` (`:416399`),
  `ShareOnboardingGuide` (`:434426`) and `REPL` (`:425346`). The 2.1.197 doc listed them as deferred.
- **Wrong `isReadOnly`:** `ShareOnboardingGuide` returned `!1`, and `Monitor` had no `isReadOnly`. The
  2.1.197 doc called both read-only.
- **`Hu()`** in 2.1.197's Monitor gate is the bash-available check. It is the counterpart of `Bl()` here.

## Feature gates that changed behaviour

| Gate | Line | Controls | Logic |
|---|---|---|---|
| **`TV()`** (NEW) | `:551549` | TodoWrite, Task* tools | true if any of: a bg session or bg takeover (`hc()`); opt-in by naming the tools in `--allowedTools`/`--tools` (`XUo(Pcr.some(...))`, `:731374`); main-loop canonical model unknown, an `application-inference-profile`, or in the legacy set `c6r` (exactly: claude-3-opus, -3-sonnet, -3-haiku, -3-5-sonnet, -3-5-haiku, -3-7-sonnet, opus-4-0/4-1/4-5/4-6/4-7, sonnet-4-0/4-5/4-6, haiku-4-5; `:551538`); or `CLAUDE_CODE_ENABLE_TODO_TOOLS === true` (0 occurrences in 2.1.197). **So on any other main-loop model (e.g. the new 5-series ids) TodoWrite and the Task tools are off by default.** |
| `NP()` | `:358183` | Task* tools | false only if `CLAUDE_CODE_ENABLE_TASKS === false` |
| `Bl()` | `:207748` | Bash, Monitor | non-Windows always; Windows needs Git Bash |
| `l6()` | `:369549` | Monitor | `tengu_amber_sentinel` (default `!1`) |
| `PC()` | `:369681` | Cron* | `!CLAUDE_CODE_DISABLE_CRON && tengu_kairos_cron` (default `!0`) |
| `Gi()` | `:348684` | ListAgents, SendFile | cross-session messaging gate |
| `MKe()` | `:1030503` | plugin/skill discovery | false if `allow_plugin_skill_search` is `org_denied`/`latched`/`unregistered`, or non-null under HIPAA; true if `tCe()`; else `Pp() && firstParty && o.read()` |
| `tCe()` | `:1030454` | connector tools | `CLAUDE_CODE_REMOTE && Jn()` (`Jn` = firstParty, `:21740`) |
| `Ct()` | `:10169` | Design, ShareOnboardingGuide, SendUserFile | `VUt() === "essential-traffic"`, i.e. `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` set (`:10162`) |

## Agent / sub-agent tool sets

The sets live in `chunk-n8n456d8.js` (module 384), `:371486`–`:371504`. They are consumed by `gd()` (`:723120`)
and by the coordinator filter (`:745236`). Every name was resolved through module 384's imports.

- **Not available inside subagents** (`mdt = U("external")`):
  - ExitPlanMode, EnterPlanMode, AskUserQuestion
  - memory\_list/read/write
  - Poll (external build only), Workflow (external build only)
  - ConnectGitHub, OfferChromeSetup, propose\_skills
  - WaitForMcpServers, RefreshMcpTools
  - ScheduleWakeup, ReadNotifications, ProposeGoal, PublishPlugin, EndConversation, AppifactRepl
- **Allowed for async agents** (`gdt = G("external")`):
  - Read, Write, Edit, NotebookEdit, Glob, Grep
  - Bash, PowerShell
  - WebSearch, WebFetch
  - TodoWrite, Skill, StructuredOutput, ToolSearch
  - Enter/ExitWorktree, REPL, LSP, Monitor
  - TaskStop, GetTask, SendMessage, Artifact
  - Search/List Plugins/Skills
- **Extra for teammates** (`evs`): TaskCreate/Get/List/Update, SendMessage, CronCreate/Delete/List.
- **Coordinator mode** (`RFn`): Agent, TaskStop, SendMessage, StructuredOutput, Skill, ReadNotifications,
  ListAgents, Workflow.
- **Removed in diskless sessions** (`Jws`, applied when `isDiskless()`, `:723137`): SuggestPluginInstall,
  SuggestSkills, PushNotification, ShowOnboardingRolePicker, SendMessage.

## Permission Modes

The enum is unchanged: `["default", "acceptEdits", "bypassPermissions", "plan", "dontAsk", "auto"]`. It is
held in the sorted const `TD` (`:25394`) and the Zod enum `de` (`:93448`).

| Mode | Description (verbatim, Zod `.describe()` `:93448`) |
|---|---|
| `default` | Standard behavior, prompts for dangerous operations. |
| `acceptEdits` | Auto-accept file edit operations. |
| `bypassPermissions` | Bypass all permission checks (requires allowDangerouslySkipPermissions). |
| `plan` | Planning mode, no actual tool execution. |
| `dontAsk` | Don't prompt for permissions, deny if not pre-approved. |
| `auto` | Use a model classifier to approve/deny permission prompts. |

- **NEW alias `manual`.** `Ah(e)` (`:25399`) maps `"manual"` to `"default"`, and `ag()` resolves modes
  through it. The mapping occurs 0 times in 2.1.197.
- **`bubble`** is still internal, used only for the fork subagent (`:491772`). It is filtered out of user
  modes at `:35784`.
- **Plan mode.** `nZ()` (`:542089`) returns `{behavior:"ask", message:"Cannot call <tool> while in plan
  mode.", decisionReason:{type:"mode", mode:"plan"}}`. It fires when `_et()` holds: the mode is plan, the
  tool is an MCP tool or remotely routed (`mKr`, `:542066`), and it is not read-only for this input. File
  tools keep their own message, *"Cannot write to <path> while in plan mode."* (`:230289`).
- **Bypass.** `het()` (`:542062`) allows the call under `bypassPermissions`, or under the
  bypass-available mode when the call is not `forRemoteExecution`. A tool can opt out with
  `excludedFromModeBypassAllow`.
- `auto` still uses the `afk-mode-2026-01-31` beta (`UU`, `:92295`).

## Deferred-Tool / Tool-Search System

### `isDeferredTool` = `r9` (`:365086`)

`r9` is defined in module 362 `chunk-49fkwz9n.js` and re-exported as `isDeferredTool`, next to
`isDeferredToolByEngine` (`NFe`) and `isDeferredToolInConversation` (`hZ`), by module 1127
`chunk-0h1n293r.js` (export block just before `:977792`). (`chunk-qq53j93e.js` only supplies the ToolSearch name `Ci`.)

```
r9(e) = deferralOf(e.name)            // NEW: a tool-describe hook's recorded decision wins
        ?? NFe(e)
NFe(e):
  e.alwaysLoad === true                -> false
  O(e) = s(e) || E(e) || l(e)          -> false
     s: name in eM() non-deferrable list
        (e.isMcp -> fall through)
        ToolSearch, StructuredOutput   -> never deferred      (StructuredOutput is NEW here)
        Agent && isForkSubagentEnabled()
        SendUserMessage (BRIEF_TOOL_NAME)
        PushNotification && l(e) && tengu_drifting_heron === false   (ZAs() :219749, default !0; redundant with l below)
     E: EnterWorktree && CLAUDE_CODE_SESSION_KIND === "bg"
     l: PushNotification && CLAUDE_CODE_ENTRYPOINT in {remote_trigger, remote_cowork_trigger}
  eUn()                                -> false   (stub; returns !1 in this build, :300923)
  T(e):
     e.isMcp                           -> true    (all MCP tools deferred)
     tengu_shiny_stardust && name in {ReportFindings, Workflow, ShareOnboardingGuide} -> true   (NEW)
     name in keys(tengu_quirky_kazoo)  -> true    (NEW)
     else e.shouldDefer === true
```

Changes vs 2.1.197's `x4`:

- **Removed exceptions.** `SendUserFile` and `ScheduleWakeup` are no longer exceptions. SendUserFile now
  carries a `shouldDefer` getter. ScheduleWakeup sets `shouldDefer:!1`.
- **New force-defer flags.**
  - `tengu_shiny_stardust` (`vr`, default `!1`, `:219728`).
  - `tengu_quirky_kazoo` (`vr`, default `[]`, `:219732`). It is either an array of names, or an object
    mapping a name to a one-line hint. `QAs()` (`:219742`) prints that hint on the deferred-tool line as
    `Name: hint` through `Ogo()` (`formatDeferredToolLine`, `:365145`).
- **`eM()` (`:219708`) is unchanged in logic.** It is the union of the `tengu_non_deferrable_builtins`
  flag and the managed `non_deferrable_builtins` setting. The flag value may be an object keyed by a
  model-id substring, with a `"*"` fallback, resolved by `y()` (`:219695`). 2.1.197's `tla()`/`mup()` did
  the same, so the 2.1.197 doc's "or" was imprecise.
- **`isDeferredToolInConversation`** (`hZ`, `:365130`) is a NEW in-conversation variant. It takes
  `{toolSearchAbsent, placements, nonDeferrableBuiltins}`, so the deferral decision depends on what is
  already loaded and where the tool is placed.

### ToolSearch

The description is built by `Wwr()` (`:365150`) as `c + (u$s() ? p : m) + h`. When
`Po().toolSearchFetchRule` is set (`:113300`), the variant `p` adds: *"calling the tool fails with
InputValidationError. When any instruction, system reminder, or other tool's description names a
deferred tool, fetch it with query "select:<name>" before calling it."* Query forms are unchanged:
`select:A,B`, keyword, `+require`. Beta headers: `advanced-tool-use-2025-11-20` (`hPo`) and
`tool-search-tool-2025-10-19` (`gqn`) (`:92283`–`:92284`).

### Modes & env (`$we()` `:219660`, `Ty()` `:219761`)

| `ENABLE_TOOL_SEARCH` | Mode |
|---|---|
| experimental betas off (`btn()`) | `standard` |
| **`force`** (not HIPAA, firstParty; `ENABLE_TOOL_SEARCH` in the admin-tier env view `xje()`/`u0o` `:43347`, or the host-managed-provider value `kMo()`/`GDo` `:42512` unless experimental betas are disabled there): `l()` (`:219604`) | **`tst`**, NEW (`isToolSearchForceOverride`, 0 occurrences in 2.1.197) |
| `auto:0` | `tst` |
| `auto:100` | `standard` |
| `auto` / `auto:N` | `tst-auto` (N clamped 0–100, `gSo` `:219647`) |
| truthy | `tst` |
| defined but falsy | `standard` |
| unset | `tst` |

`Ty()` then turns the ToolSearch tool off in `standard` mode. It also turns it off on `firstParty` when
`ENABLE_TOOL_SEARCH` is unset, there is no force, and `ANTHROPIC_BASE_URL` is not a first-party host
(`!Si()`); it logs *"[ToolSearch:optimistic] disabled: …"*. Two per-model exclusions apply where tool
search is used (e.g. `vjr` `:520221`):

- `rie()` (`:219753`): flag `tengu_tool_search_unsupported_models`, matched as substrings.
- `nie()` (`:219679`): on Vertex, `claude-3*` and opus/sonnet/haiku below 4.5.

## What's New / Changed vs 2.1.197 (summary)

- **Tools 49 → 84 sites / 92 names.** 45 NEW, 2 REMOVED (TaskOutput, REPL). The factory was renamed
  `Ys` → **`Jt`** and is now an execution wrapper. It adds `create()`, remote-execution routing,
  `backgrounding` and `enablesCodeExecution`.
- **TodoWrite and Task\* are off by default on non-legacy models.** The new gate is `TV()`; the escape
  hatch is `CLAUDE_CODE_ENABLE_TODO_TOOLS=true`.
- **The serialiser was renamed `Etr` → `QF`.** It adds:
  - prompt ablation (`CLAUDE_CODE_REMOVE_PROMPT_STRINGS`);
  - tool-describe hooks;
  - recorded-snapshot replay (`tengu_binary_balloon`);
  - WebSearch `citations`;
  - `strict` routed through the structured-outputs beta, with a schema-compatibility check;
  - a much larger memo key.
- **Deferral.**
  - New force-defer flags: `tengu_shiny_stardust`, `tengu_quirky_kazoo`.
  - Hook-recorded deferral.
  - `whenToUse` hints on deferred-tool lines.
  - ScheduleWakeup is now never deferred; SendUserFile's deferral is a getter; StructuredOutput is never deferred.
- **`ENABLE_TOOL_SEARCH=force`** is a new override.
- **Permission modes** are unchanged, plus the new `manual` → `default` alias.
- **Provider support.** WebSearch is now enabled on `anthropicGoogleCloud` (foundry was already on in
  2.1.197), and every provider is now behind the new `allow_web_search` entitlement.

## Uncertainties

- `tNe()` (the LSP `isEnabled`), `Xat()` (Bash read-only classifier), `W1()`'s first two conjuncts and
  `hv(tools)` were not decoded.
- The path that adds `ObserverReport` and `StructuredOutput` to a session's tool list was not traced; both
  are absent from `getAllBaseTools`.
- That the six `null` registry slots are compiled-out tools is an inference.
- That `GetTask` replaces `TaskOutput` is an inference from its purpose string only.
- The categories for parametric add-on tools (`ArtifactComments/Data/Check`) depend on the wrapped
  Artifact tool's per-action `isReadOnly`, which was not enumerated.
