# Hidden Commands

> [Back to version index](../README.md)
>
> **Version**: 2.1.300 | **Build**: `2026-10-14T12:54:55Z` | **Platform**: Linux x86-64
> **GIT_SHA**: `c6733ae1276880507ca0c5b053ae18fb0df090d6` | **Runtime**: Bun v1.4.3

See [data/commands.yaml](data/commands.yaml) for the full structured dataset (registry + bundled-skill commands + upsell stubs + filtering pipeline). This page covers the hidden, disabled and gated commands, the easter eggs, and what changed since **2.1.197**.

All line numbers are `cli.beauty.js:LINE` in the 2.1.300 bundle unless marked `2.1.197:`. The registry and almost every command object live in module 424 `chunk-538n62w8.js` (`:379693`–`:595167`). A few commands are lazy chunks (modules 1219–1229, `:1021358`–`:1022760`).

**Headline: 96 → 106 command names (+10).** The canonical count from `_facts.md` §1.6 is distinct literal `name:` on a `type:"local"|"local-jsx"|"prompt"` object. That method also recounts 2.1.197 as **96**; 2.1.197 published 93. Churn: **14 NEW**, **4 gone**.

- **NEW (14):** `__remote-workflow`, `artifacts`, `auto-mode-setup`, `bug`, `cloud-plugins`, `design-consent`, `design-revoke`, `import`, `list-agents`, `output-style`, `restart`, `skill-doctor`, `subtask`, `workflow-launch-exec`.
- **Gone (4):** `doctor`, `init-verifiers`, `review`, `update`.
  - `/doctor` moved to a bundled skill.
  - `/review` lives on as an alias of the bundled `/code-review` skill.
  - `/update` lives on as an alias of the new `/restart`.
  - `/init-verifiers` is gone outright.

The canonical method misses commands whose `name:` is an identifier. Three of those are **NEW** and hidden: `/low-priority`, `/limit-reset`, `/claim-credit`. Details below.

The biggest behaviour changes are in the gating:

- **Two commands lost their GrowthBook gates:** `/radio` (was `tengu_velvet_static`, default `!1`) and `/recap` (was `tengu_sedge_lantern`, default `!0`). `/mobile` and `/install-slack-app` were already enabled in 2.1.197 and are unchanged.
- **`/agents` is now a hidden tombstone.** `/daemon` stays compiled off, as it already was in 2.1.197; only the mechanism moved.
- **A new `policyGate` property** (0 occurrences in 2.1.197) makes server-side org policy a command filter.

## How status is decided (verified from source)

`getCommands` (`rf`, `:477227`) awaits `a3o` (`:477230`). That function keeps a loaded command only if it passes `G_e(cmd) && mc(cmd)` (`:477239`, again at `:477247` and `:477311`).

- **`isCommandEnabled`** (`mc`, `:231719`, module `chunk-kxsypegk.js`; readable alias `mc as isCommandEnabled` `:1553451`):
  ```
  function mc(e) {
    if (!qmo(e)) return !1;          // NEW: policyGate check
    return e.isEnabled?.() ?? !0     // no isEnabled => enabled (unchanged)
  }
  ```
  - `qmo` (`:231724`): reads `e.policyGate`. Null ⇒ allow. A throwing getter ⇒ deny. Otherwise it returns `U4n(policy)`.
  - `U4n` (`:70128`) returns `t().verdict?.commandPolicyGateAllows(e) ?? !1`, so it **fails closed** when there is no verdict.
  - This is **NEW**. `policyGate` occurs 0 times in 2.1.197 and 35 times in 2.1.300 (raw substring, `cli.beauty.js`; 16 of them are `policyGate:` keys).
- **`meetsAvailabilityRequirement`** (`G_e`, `:417561`). The role is inferred from its shape, which matches 2.1.197 `VTt`; no readable alias for it was found.
  - First, `if (wr().commandsOffHere?.(e)) return !1`. **NEW** hook, but `commandsOffHere` is only ever initialised to `void 0` (`:47367`) and never assigned in this build.
  - No `availability` ⇒ allow.
  - `"claude-ai"` ⇒ `kt()` (`isClaudeAISubscriber`, `:130788`, alias `:1041805`).
  - `"console"` ⇒ `!kt() && !Oee() && Si()`.
  - **NEW token `"console-profile"`** ⇒ `Xae() === "user_oauth" && OU()` (`:99251`, `:128372`). It is used by `/autofix-pr`, `/teleport` and `/remote-env`, and occurs 0 times in 2.1.197.
  - An unknown token fails.
- `isHidden: !0` (or a getter returning true) keeps a command **runnable but unlisted**.
- **Disabled stub** `{isEnabled:()=>!1, isHidden:!0, name:"stub"}`: **18** literal copies in 2.1.300, 17 in 2.1.197. Examples are `Rqe` `:457763`, `m2t` `:458600`, `$7t` `:475920` and `AQt`/`PQt`/`IQt` `:476814`–`:476828`.

### The builtin table is now runtime-assembled (`buildBuiltinCommandTable`)

`xY()` (getBuiltinCommands, `:477116`) → `lG()` (`:477077`, memoised in `wr().builtinCommandTable`) → **`mus()`** (`:476930`, readable `mus as buildBuiltinCommandTable` `:1553451`).

New in this build: part of the table comes from **runtime-gated groups** `HQt()` (`:476887`), read through `IX(group)` (`:476921`). `IX` returns `whenOpen` when `open()` is true and `whenClosed` otherwise.

| Group | `open()` | whenOpen | whenClosed |
|---|---|---|---|
| `fleetFork` | `mv() && !$e(a.IS_DEMO)`. `mv()` = `!cPt()`, i.e. not `CLAUDE_CODE_DISABLE_AGENT_VIEW` and not setting `disableAgentView` (`:368753`) | `/fork` ("Copy this conversation into a new background session…", `L7t` `:475818`), `/subtask` (`N7t` `:475825`) | `/fork` ("Spawn a background agent that inherits the full conversation", `O7t` `:475810`) |
| `fleetBackground` | `mv()` | `/background` (`:1021384`), `/stop` (`:1021543`) | — |
| `daemon` | **`j8()` = `return !1`** (`:368789`) | `/daemon` (`:1022742`) | — |
| `skillDoctor` | `L0()` = `k("tengu_lantern_prism", !1) \|\| CLAUDE_CODE_LANTERN_PRISM` (`:351210`) | `/skill-doctor` ×2 (`:475669`, `:475676`) | — |
| `logout` | `!Oee() \|\| Wx(Fr())`, i.e. first-party, or a pinned gateway-auth slot | `/logout` (`:458572`) | — |

`getRuntimeGatedBuiltinCommands` (`fus`, `:476926`) flattens both branches of every group. `zQt` (`:477064`) feeds that list to `cpe` to reserve the names, so a skill or plugin cannot take `/daemon` or `/logout` even when the command is absent.

### Per-build symbol map

| Role | 2.1.300 | Line | 2.1.197 was |
|---|---|---|---|
| `getCommands` | `rf` → `a3o` | `:477227` / `:477230` | `gA` |
| `getBuiltinCommands` | `xY` → `lG` → `mus` | `:477116` / `:477077` / `:476930` | `EVo` → `yen` |
| `getRuntimeGatedBuiltinCommands` | `fus` (over `HQt`/`IX`) | `:476926` | — (NEW) |
| `isCommandEnabled` | `mc` (+ `qmo` policyGate) | `:231719` | `rx` |
| `meetsAvailabilityRequirement` | `G_e` | `:417561` | `VTt` |
| `REMOTE_SAFE_COMMANDS` | `Hmr` | `:476933` | `Zcr` |
| `BRIDGE_SAFE_COMMANDS` | `kHn` | `:476934` | `TVo` |
| `filterCommandsForRemoteMode` | `Mso` | `:476961` | `CVo` |
| `isBridgeSafeCommand` | `Cit` | `:476936` | — |
| `INTERNAL_ONLY_COMMANDS` (tentative) | `RNa` | `:476884` | `Tsm` |
| `ANT_GATED_COMMANDS` (tentative) | `CNa` | `:476885` | `vsm` |
| enterprise upsell wrapper | `rG` (gate `Z7t`) | `:476129` / `:476097` | `uTt` |
| "moved to /config" factory | `e2t` | `:458074` | (present) |

Readable re-export map for the command registry: module 1863 `chunk-gvp2dw01.js`, `:1553451`.

**`INTERNAL_ONLY` / `ANT_GATED` are vestigial.** The readable strings `INTERNAL_ONLY_COMMANDS` and `ANT_GATED_COMMANDS` occur **0** times in 2.1.300 (once each in 2.1.197, `2.1.197:581232`, `:581234`).

- `RNa` = `[…stubs…, JKt (commit-push-pr), RVe/EVe (/version), …]` has the same shape as 2.1.197's `Tsm`.
- `CNa` = `[Qye, NX, XVe, QVe, JVe, OX].filter(Boolean)`. All six are `null` (`:476835`–`:476848`), so it is empty, as `vsm` was.
- Each identifier occurs **exactly once** in the bundle, at its own definition, so neither list is read anywhere. The mapping to the old names is **tentative**: it rests on contents only.

### Key gate helpers (resolved across chunks)

| Helper | Def line (module) | Meaning | 2.1.197 analogue |
|---|---|---|---|
| `we()` | `:2598` (module 19, minified) | `!n().host.launchOptions.isInteractive()`, i.e. HEADLESS. Alias `getIsNonInteractiveSession` `:878167` | `Cr()` |
| `Un()` | `:2604` (module 19) | `surfaceCapabilities.caps().workspace === "remote"`. Alias `getIsRemoteMode` | `_a()` |
| `Sc()` | `:2604` (module 19) | `replBridgeActive()`. Alias `isReplBridgeActive` | — |
| `kt()` | `:130788` | `bl() && vj(Mn()?.scopes)`, i.e. claude.ai subscriber OAuth. Alias `isClaudeAISubscriber` | `Ao()` |
| `on(policy)` | `:160130` | org-policy check. Alias `isPolicyAllowed` `:1042297` | `js(cap)` |
| `Jn()` | `:21740` | `Ie() === "firstParty"` | `xc()` |
| `ra()` | `:199545` | coordinator mode (`CLAUDE_CODE_COORDINATOR_MODE`, off locally under `Xp()` unless remote) | `Jv()` |
| `Lt()` | `:48032` | `Un() \|\| Tr() !== null` (remote or thin-client transport) | — |
| `Ct()` | `:10169` | `VUt() === "essential-traffic"` | — |
| `k(flag, def)` | `:142865` | GrowthBook `getFeatureValue_CACHED_MAY_BE_STALE` (`_facts` §2) | `it()` |

## Hidden / Disabled / Gated commands

| Command | Aliases | Status | Why hidden / disabled |
|---------|---------|--------|-----------------------|
| `/radio` | -- | **Enabled, listed** (`:476053`) | **CHANGED: now ungated.** The object is just `{type:"local", name:"radio", description:"Listen to Claude FM lo-fi radio", supportsNonInteractive:!1, load}`: no `isEnabled`, no `isHidden`. It is in the table (`J7t`, `mus` `:476931`). Its `call` (module 1023 `chunk-sm6xwabv.js`, `:937062`) opens `https://clau.de/radio`. The old gate flag `tengu_velvet_static` occurs **0** times in 2.1.300 (1 in 2.1.197, `2.1.197:556542`). |
| `/stickers` | -- | **Enabled** (`:476045`) | Fun command. No gate. Opens `https://www.stickermule.com/claudecode` (`chunk-frf5n9he.js`). Unchanged. |
| `/heapdump` | -- | **Hidden + policy-gated** (`:475898`) | `isHidden:!0`, `supportsNonInteractive:!0`, `fleetHostCall` → `performHeapDump()`. **NEW gate:** `policyGate:{policy:"allow_heap_dump"}`; the string occurs 0 times in 2.1.197. The description now says the dump goes to the Desktop, "on Linux with no Desktop folder, the home directory". |
| `/low-priority` (name = const `fve`, `:177349`) | -- | **NEW, hidden** (`:476489`) | `isEnabled: () => kt() && (iL() \|\| Ept())`, `isHidden:!0`. "Continue now at lower priority after reaching your session limit; run again to stop".<br>• `iL()` = `ze().state.phase === "active"` (`:177442`)<br>• `Ept()` = `k("tengu_toasty_breeze", {}).enabled === !0` (`:177361`–`:177367`)<br>Surfaced through the notice line `/${fve} to continue now at lower priority` (`:177352`). The `"low-priority"` string occurs 0 times in 2.1.197. |
| `/limit-reset` (const `R7`, `:476498`) | -- | **NEW, hidden** (`:476637`) | `local-jsx`. `isEnabled: () => kt() && (oRe() \|\| rue())`, `isHidden:!0`.<br>• `oRe()` = `k("tengu_nifty_lemur", {}).enabled` (`:476588`, `:476602`)<br>• `rue()` = `k("tengu_cedar_ember", {}).enabled` (`:476499`, `:476525`)<br>"Reset your session limit now and keep working; once a week, still counts toward your weekly limit". 0 occurrences in 2.1.197. |
| `/claim-credit` (const `tws`, `:335612`) | -- | **NEW, hidden** (`:476647`) | `isEnabled: () => kt() && !bie() && lFn() !== null`, `isHidden:!0`. "Open the page of the offer shown at start-up".<br>• `lFn()` reads flag `tengu_swift_lynx` (`:335571`, `:335630`)<br>• `bie()` = `sEe() \|\| Ie() !== "firstParty" \|\| Ct()` (`:176920`)<br>0 occurrences in 2.1.197. |
| `/pro-trial-expired` | -- | **Hidden** (`:476472`) | `isHidden:!0`, no `isEnabled`. System screen shown when the Pro trial ends. Unchanged. |
| `/rate-limit-options` | -- | **Gated** (`:476479`) | `isEnabled: () => kt() \|\| !1`. **CHANGED:** the object no longer carries `isHidden` (2.1.197 had `isHidden:!0`, `2.1.197:560711`). |
| `/pause-memory` | `/memory-pause`, `/toggle-memory` | **Disabled** (`:458148`) | Still `isEnabled: () => !1`. Now has `get isHidden(){ return !P7t() && $e(a.IS_DEMO) }` (`P7t` = `bG() \|\| Un()`, `:333516`) and a two-mode description: automemory only, or account memory plus local auto-memory. Shipped off, as in 2.1.197. |
| `/loops` | -- | **Disabled** (`:475794`) | `isEnabled: () => !1`. Unchanged. Distinct from the `/loop` skill. |
| `/wellbeing` | `/breaks`, `/break-reminder`, `/downtime` | **Disabled** (`:476722`) | `isEnabled: () => !1`. Unchanged. |
| `/version` | -- | **Disabled** (`:475926`, `:475952`) | Both the `local-jsx` and `local` variants have `isEnabled: () => !1`. The headless twin's `isHidden` is now a getter (`!we()`). Unchanged in effect. |
| `/desktop` | `/app` | **Effectively off** (`:457853`) | `availability:["claude-ai"]`, `isEnabled: Ebe`, `get isHidden(){return !Ebe()}`. `Ebe()` = `lWo() && !Lt()`, and **`lWo()` is `return !1`** (`:457845`), so it is always off. **CHANGED gate:** the `allow_desktop_handoff` capability check from 2.1.197 is gone; the hard-coded false remains. |
| `/daemon` | -- | **Compiled off (unchanged status, CHANGED mechanism)** (`:1022742`) | The object has no `isEnabled`. In 2.1.197 it was also off: the table spread was `...qcr && jce() ? [qcr] : []` (`2.1.197:581712`) and `jce()` was `return !1` (`2.1.197:145700`). It now enters the table only through `IX("daemon")`, whose `open()` is `j8()` = **`return !1`** (`:368789`). The name stays reserved through `fus()`. |
| `/agents` | -- | **Hidden tombstone (CHANGED)** (`:475843`) | `type:"local"`, `isHidden:!0`. Description "(removed) Ask Claude to create/manage subagents, or edit .claude/agents/". `call` (`n6o`, `:475832`) prints "The /agents wizard has been removed." and points to `.claude/agents/` and `~/.claude/agents/`. Was an active wizard in 2.1.197 (`2.1.197:554234`). |
| `/vim` | -- | **Hidden redirect** (`:458088`) | `e2t("vim","Editor mode")`: `local-jsx`, `isHidden:!0`, description "Editor mode moved to /config". `isEnabled: () => Rbe()` = `k("tengu_maple_sundial", !1)` (`:458070`). Not in the canonical count (identifier name). The flag also exists in 2.1.197. |
| `/output-style` (redirect copy) | -- | **Hidden redirect** (`:458088`) | `e2t("output-style","Output style",{workspace:!0})`, same `tengu_maple_sundial` gate. The **NEW** real `/output-style` (`sKe`, `:458093`) is `isEnabled: () => we() \|\| !Rbe()`. That makes it the live command whenever the flag is off; when the flag is on, only headless runs get it. |
| `/extra-usage` | -- | **Hidden** (`:476453`, `:476463`) | "Renamed to /usage-credits". `isHidden:!0`. Same `fI()` gate as `/usage-credits`. |
| `/__remote-workflow` | -- | **NEW, hidden** (`:476398`) | `type:"local"`, `isHidden:!0`, `disableModelInvocation:!0`, `supportsNonInteractive:!0`. "Run the workflow script delivered in this session environment (server-launched sessions only)". In the table as `hQt`. |
| `/workflow-launch-exec` | -- | **NEW, hidden** (`:476410`) | Same shape. "Execute a server-launched workflow handoff (workflow_launch event sessions only)". In the table as `yQt`. |
| `/design-consent` | -- | **NEW, hidden** (`:458534`) | `local`, `isHidden:!0`, `isEnabled: () => WF()`, `policyGate: L$e` (`{policy:"allow_design_sync"}`, `:372213`). "Grant Claude agent access to your Design projects". |
| `/design-revoke` | -- | **NEW, hidden** (`:458544`) | Same gate as `/design-consent`. "Revoke Claude agent access to your Design projects". |
| `/design-login` | -- | **Gated (CHANGED gate)** (`:458554`, factory `d2t()`) | `isEnabled: () => WF()`, `policyGate: L$e`. `WF()` (`:372217`) = `on("allow_design_sync") && !Ct() && Jn()`. Flag `tengu_slate_quill` (2.1.197 `RSt()`) occurs **0** times in 2.1.300, so this is now policy + first-party only. |
| `/mobile` | `/ios`, `/android` | **Enabled (unchanged)** (`:458628`) | `{type:"local-jsx", name:"mobile", aliases, description, requires:{ink:!0}}` with no gate, in the table (`mKe`) and in `REMOTE_SAFE` (`Hmr`). Same in 2.1.197 (`2.1.197:524099`, `Qjo`, in `yen` and `Zcr` at `2.1.197:581712`/`:581747`). The `isEnabled:()=>!1, isHidden:!0` object right after it (`2.1.197:524109`) is a separate disabled stub, not `/mobile`. |
| `/install-slack-app` | -- | **Enabled for claude.ai (unchanged)** (`:458592`) | Only `availability:["claude-ai"]` and `supportsNonInteractive:!1`. In the table (`p2t`). Identical in 2.1.197 (`2.1.197:506168`, `lGl`, in `yen`); the disabled object that follows it (`2.1.197:506178`, and `m2t` `:458600` here) is a separate stub. |
| `/recap` | -- | **Enabled (CHANGED)** (`:1022057`, module 1223 `chunk-yp7yp4hg.js`) | No `isEnabled`. Was `isEnabled: () => it("tengu_sedge_lantern", !0)` in 2.1.197 (`2.1.197:572207`), i.e. on by default but remotely killable; that exact flag name occurs 0 times in 2.1.300 (only `tengu_sedge_lantern_config`, `:1367304`, which this verification did not trace). Included as `...DX ? [DX] : []` and `DX` is an unconditional `import.meta.require(...).default` (`:476844`). |
| `/voice` | -- | **Conditionally hidden** (`:458643`) | `availability:["claude-ai"]`. **CHANGED:** there is no `isEnabled` any more; only `get isHidden(){return !rdt()}`. `rdt()` (`:333541`) = `ywr() && on("allow_voice_mode")`, so the command is hidden, not disabled, when voice is unsupported. |
| `/setup-bedrock` / `/setup-vertex` | -- | **Conditionally hidden** (`:458707`, `:458716`) | `isHidden` getter `!CLAUDE_CODE_USE_BEDROCK` / `!CLAUDE_CODE_USE_VERTEX`. **NEW** `isEnabled: () => _ee("bedrock"\|"vertex") === void 0`. |
| `/passes` | -- | **Conditionally hidden** (`:475755`) | `isHidden` getter `!eligible \|\| !hasCache` from `odt()` (`:334983`). The description adds "and earn usage credits" when `o5e()` finds a referrer reward. |
| `/fast` | -- | **Conditionally hidden** (`:475724`) | `isHidden` getter `!jo()`. `jo()` = `Ie()==="firstParty" && !CLAUDE_CODE_DISABLE_FAST_MODE` (`:120923`). Headless twin `yVe` (`:475740`). |
| `/advisor` | -- | **Gated** (`:476061`, `:476078`) | `isEnabled`/`isHidden` on `gk()` (`:313842`) = `_It() && (CLAUDE_CODE_ENABLE_EXPERIMENTAL_ADVISOR_TOOL \|\| k("tengu_sage_compass2",{enabled:…}).enabled)`. |
| `/remote-control` | `/rc` | **Gated** (`:1022709`, module 1228) | `isHidden` getter `!qR()`. `isEnabled` is local `e()`: `qR() || (oU() && !q0() && !Nz() && ja().source==="none" && Ep(…).source==="none" && !cuo.isC4EUpsellCommandEnabled())`, i.e. also enabled for a signed-out user with no API key or token, unless the C4E upsell stub is active. `qR()` (`:289595`) = `!Nz() && !q0() && Tct()`; `Tct()` checks flag `tengu_ccr_bridge` or a pro/max/team/enterprise subscription (`:289563`). |
| `/session` | `/remote` | **Gated** (`:458751`) | `isEnabled: () => Un()`. **CHANGED:** `isHidden` getter is now `!zA("fanout")`. |
| `/teleport` | `/tp` | **Gated (CHANGED)** (`:459237`) | `availability:["claude-ai","console-profile"]`, `isEnabled: () => kt() \|\| RNt()`, `policyGate: Uue` (`{policy:"allow_remote_sessions"}`, `:368456`), `get isHidden(){return !mc(this)}`. Console OAuth profiles (`RNt`, `:138335`) can now teleport. |
| `/remote-env` | -- | **Gated (CHANGED)** (`:476387`) | Same gate as `/teleport`. |
| `/autofix-pr` | -- | **Gated (CHANGED)** (`:457738`) | `availability:["claude-ai","console-profile"]`, `isEnabled: () => jKt() && !we()`. `jKt()` = `(kt() \|\| RNt()) && on("allow_remote_sessions")` (`:457734`). `policyGate: Uue`. |
| `/web-setup` | -- | **Gated (CHANGED)** (`:368543`, module 367) | `availability:["claude-ai"]`, `isEnabled: ixe` = `!Ct() && on("allow_remote_sessions") && on("allow_quick_web_setup")` (`:368525`). Flag `tengu_cobalt_lantern` occurs 0 times in 2.1.300. |
| `/ultraplan` | -- | **Gated** (`:475632`) | `availability:["claude-ai"]`, `isEnabled: () => $V()` = `k("tengu_ultraplan_config",null)?.enabled === !0 && Tct() && !Un()` (`:475099`). |
| `/ultrareview` | -- | **Gated** (`:458730`, `:458738`) | `isEnabled: () => U0()` = `sOt() && Tct()` (`:333599`). The `/code-review` skill maps subcommand `ultra` to `"ultrareview"` (`:788509`). |

### NEW gated commands (visible when their gate is on)

| Command | Line | Gate (decoded) |
|---|---|---|
| `/artifacts` | `:457720` | `isEnabled: () => sM() && zc() === null`; `zc()` = env `CLAUDE_CODE_EVAL_ARTIFACT_STUB_DIR` (`:75689`). `immediate:!0`. **NEW** property `runsBesideTurns: Zjo` = `k("tengu_cobalt_plinth_sainfoin", !1)` (`:457729`). "Browse your published and shared artifacts". |
| `/import` (+ headless twin) | `:458224`, `:458235` | `tRe()` = `k("tengu_import", !1)` (`:458185`), so **off by default**. "Import config from another AI coding agent" `[codex\|gemini\|cursor] [--dry-run]`. Fallback text: "`claude import` is not yet available in this build". |
| `/auto-mode-setup` (+ twin) | `:457697`, `:457709` | Interactive: `Tqe() && !we()`; headless: `wqe() && we()`.<br>• `wqe()` = `!CLAUDE_CODE_REMOTE && hoe() && o4e().value !== ""` (`:457681`–`:457687`)<br>• `Tqe()` adds `u_()?.envOnboarding === !0` |
| `/cloud-plugins` | `:453330` | `Nrn() && !CLAUDE_CODE_DISABLE_PLUGIN_FORWARDING`; `Nrn()` = `Xf() && fRr()` (`:280629`). "Choose whether cloud sessions use the plugins enabled on this machine". |
| `/skill-doctor` (+ twin) | `:475669`, `:475676` | Only when the `skillDoctor` group is open: `tengu_lantern_prism` or `CLAUDE_CODE_LANTERN_PRISM`. "Show which loaded skills are unused and costing context". |
| `/list-agents` | `/peers` | `:1021358`, module 1219. `isEnabled: () => Gi()` (`:348684`): off if `messagingBeyondOwnAgentsDisabled`; env `CLAUDE_CODE_HARBOR_KITE` overrides; on Windows also needs `tengu_harbor_kite_win` (default `!0`); else `k("tengu_harbor_kite", !0)`. So **on by default**. |
| `/subtask` | `:475825` | `!ra()` and the `fleetFork` group open. "Send a subagent off with your full context; its result comes back here". |
| `/restart` | `/update` | `:476333`. `isEnabled: lQt`; `lQt()` = `cQt() && v6o()` (`:476329`).<br>• `cQt()`: TTY on stdin+stdout, macOS/linux, `K8()`, no `L_()`, not a bg session, `!Lt()`, `!my()` (`:476309`)<br>• `v6o()`: flag `tengu_fancy_wand` (`:476300`)<br>"Restart on ${version} and keep this session". **Absorbs `update` as an alias.** |
| `/bug` | `/share` | `:457781`. Ungated. "Report a bug or share your conversation". `/feedback` (`:457769`) is now "Send feedback to Anthropic or report a bug". |

### Bundled-skill commands (the second mechanism, `registerBundledSkill`)

Skills registered through `Zs` (module 363 `chunk-snd38m61.js`, `:365324`; readable alias `:880844`) build a `type:"prompt"` command with `userInvocable: e.userInvocable ?? !0`. Bundled skills are **outside** the 106-name count (`_facts.md` §1.6). The baseline doc listed only `/loop` and `/schedule`. There are 37 registration sites in 2.1.300 versus 20 `Bd({` sites in 2.1.197; the user-relevant ones and their changes:

| Skill | Line | Gate / note |
|---|---|---|
| `/doctor` (`/checkup`) | `:789214` | **MOVED** from a `local-jsx` registry command (`2.1.197:500794`). `isEnabled: () => !a.DISABLE_DOCTOR_COMMAND`, **`survivesBundledKillSwitch:!0`**. |
| `/code-review` (`/review`) | `:788505` | **CHANGED:** gains alias `review`, which replaces the removed prompt command `/review` (`2.1.197:536906`, "Review a GitHub pull request…"). `subcommands:{ultra:"ultrareview"}`. |
| `/loop` (`/proactive`) | `:1544194` | `isEnabled: PC` = `!CLAUDE_CODE_DISABLE_CRON && MG("tengu_kairos_cron", !0, …)` (`:369681`). |
| `/schedule` (`/routines`) | `:1544978` | **CHANGED gate:** `Jn() && kt() && !CLAUDE_CODE_REMOTE && on("allow_routines")` plus `policyGate: Uue`. Flag `tengu_surreal_dali` occurs **0** times in 2.1.300. |
| `/setup-claude` (`/setup-cowork`) | `:1543704` | **NEW.** `isEnabled: () => I_() \|\| cW()`. |
| `/commit`, `/pr` | `:788629`, `:789725` | **NEW** (consts `:310243-310244`). `isEnabled: () => rOr()`. |
| `/explain-usage` | `:789256` | **NEW.** `I_() \|\| cW()`. |
| `/workflow-authoring` | `:1379699` | **NEW.** `isEnabled: () => Pg()` (workflows available, `:162131`). |
| `/dataviz`, `/whiteboard`, `/prototype`, `/workshop`, `/artifact-capabilities`, `/artifact-diagramming`, `/artifact-components`, `/artifact-pr-review`, `/artifact-report`/`-data-table`/`-explainer`, `/doc`, `/slides` | `:786563`–`:789869`, `:784869` | **NEW** artifact-family skills; consts at `:310230-310251` and `:784841`. `artifact-design` already existed in 2.1.197. `/slides` uses `policyKey:"allow_cobalt_plinth_juniper"`. |
| `/claude-code-docs` | `:1545573` | Existing (`2.1.197:675022`). |

`/commit-push-pr` (const `Qvo` `:310245`, object `mWo` `:457965`) still exists, but its table entry `JKt` appears only in the never-read `RNa` list. So it is **not** a builtin slash command in this build; the new `/commit` and `/pr` skills cover that ground.

### Enterprise upsell-stubs (`rG()` wrapper, `:476129`)

`rG(cmd)` returns a hidden `type:"local"` command: `isHidden:!0`, `isEnabled: Z7t`, description suffixed "— available with Claude for Enterprise". When run it fires `i("tengu_c4e_slash_upsell_shown", {command, variant})`.

- `Z7t()` (`:476097`) = `!k6o() && kit() && !we() && k("tengu_c4e_slash_upsell", !1)`.
- `k6o()` = `kt()` (`:476156`).
- `kit()` = `Si() && O9e()`, where `O9e()` = `Jn() && !kt()`.

Flag semantics are unchanged (default off; the flag also existed in 2.1.197).

**NEW: `_6o` (`:476114`) picks one of three variants:**

- `policy_disabled`, when `managedDisabled.isDisabled()`.
- `signed_out`: "…requires a claude.ai subscription. Run /login…"
- `c4e`: "…ask your admin about migrating from API-key access."

`isC4EUpsellCommandEnabled: Z7t` is exported through `$hs` (`:476100`) and read by `/remote-control` to suppress itself.

The set `eQt` (`:476159`) is unchanged: `/ultraplan`, `/ultrareview`, `/teleport` (`/tp`), `/remote-control` (`/rc`, now with `managedDisabled: Nz()`), `/schedule` (`/routines`), `/autofix-pr`.

## What's new / changed vs 2.1.197

**Added to the registry (14, canonical):** `__remote-workflow`, `artifacts`, `auto-mode-setup`, `bug`, `cloud-plugins`, `design-consent`, `design-revoke`, `import`, `list-agents`, `output-style`, `restart`, `skill-doctor`, `subtask`, `workflow-launch-exec`.

**Added (identifier-named, outside the canonical count):** `/low-priority`, `/limit-reset`, `/claim-credit`. All three are hidden and gated by `kt()` plus a GrowthBook flag. Each name string has 0 occurrences in 2.1.197.

**Removed / moved:**

- `/doctor` became a bundled skill (`:789214`).
- `/review` became an alias of `/code-review` (`:788507`).
- `/update` became an alias of `/restart` (`:476335`).
- `/init-verifiers` is gone: 0 occurrences in 2.1.300.

**Status changes:**

- Ungated: `/radio` (flag `tengu_velvet_static`, default off, removed) and `/recap` (flag `tengu_sedge_lantern`, default on, removed). `/mobile` and `/install-slack-app` are unchanged (both already enabled in 2.1.197).
- Turned off: `/agents` (hidden tombstone). `/daemon` remains off (2.1.197 `jce()=!1`, now runtime group `j8()=!1`).
- Gates rewritten onto org-policy keys (`on()` / `policyGate`):
  - `/design-login`: `tengu_slate_quill` gone, `allow_design_sync` + first-party.
  - `/web-setup`: `tengu_cobalt_lantern` gone, `allow_quick_web_setup`.
  - `/schedule`: `tengu_surreal_dali` gone, `allow_routines`.
  - `/heapdump`: `allow_heap_dump`.
  - `/insights`: `allow_insights`.
  - `/chrome`: `allow_claude_browser_extension`.
  - `/team-onboarding`: `allow_team_onboarding`, now as a `policyGate`.
- Console OAuth profiles admitted: `/teleport`, `/remote-env` and `/autofix-pr` add availability `console-profile` and `RNt()`.
- `/desktop`: still hard-off, but the `allow_desktop_handoff` capability check is gone.
- `/voice`: `isEnabled` dropped; hidden only.
- `/rate-limit-options`: `isHidden` dropped.

**Unchanged off-switches:** `/loops`, `/wellbeing`, `/version` ×2 and `/pause-memory` are still `isEnabled: () => !1`.

## Filtering / allow-list mechanisms

- **Availability tokens:** `claude-ai`, `console`, and **NEW** `console-profile` (`G_e`, `:417561`).
- **Org policy (NEW):** `policyGate:{policy}`, checked in `mc` → `qmo` → `verdict.commandPolicyGateAllows`, fail-closed (`:231719`–`:231733`, `:70128`). Policy keys seen on commands:
  - `allow_remote_sessions` (`Uue`)
  - `allow_design_sync` (`L$e`)
  - `allow_heap_dump`
  - `allow_insights`
  - `allow_team_onboarding`
  - `allow_claude_browser_extension`
- **Mode-aware dual variants.** Each command ships an interactive `local-jsx` copy and a `local` copy gated on `we()` (headless); the copy that does not fit the mode is hidden. Verified pairs: `/add-dir`, `/auto-mode-setup`, `/autocompact`, `/color`, `/config`, `/context`, `/effort`, `/exit`, `/extra-usage`, `/fast`, `/focus`, `/goal`, `/import`, `/mcp`, `/model`, `/rename`, `/skill-doctor`, `/stop`, `/ultrareview`, `/usage`, `/usage-credits`, `/version`, `/advisor`.
  - **NEW** `thinClientDispatch:"twin"` (1 occurrence in 2.1.197, 4 in 2.1.300) on `/add-dir`, `/mcp` and `/skill-doctor`. `H4e` (`:476949`) uses it to find the bridge-safe `local` twin of a `local-jsx` command.
- **Remote / bridge allow-lists:** `REMOTE_SAFE_COMMANDS` (`Hmr`, `:476933`) and `BRIDGE_SAFE_COMMANDS` (`kHn`, `:476934`).
  - `Mso` (`:476961`) admits a command in remote mode if it is a builtin/bundled prompt that passes `fPt`, or if it is in `Hmr`.
  - `Cit` (`:476936`) excludes every `local-jsx`. A prompt is bridge-safe unless `disableBridgeInvocation`. `/restart` (`Vye`) is in `kHn` but `Cit` explicitly returns false for it (`e !== Vye || !1`).
- **New command properties** (counts are occurrences in 2.1.197 → 2.1.300):
  - `terminalOriented` (0 → 13)
  - `advertisedOnHostedSessions` (0 → 2, on `/focus`)
  - `keepsScrollPosition` (0 → 2, on `/btw`)
  - `runsBesideTurns` (0 → 4, on `/artifacts`)
  - `policyGate` (0 → 35 raw occurrences)
