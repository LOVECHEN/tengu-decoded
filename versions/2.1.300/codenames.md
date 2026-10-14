# Internal Codenames

> [Back to version index](../README.md)
>
> **Version**: 2.1.300 | **Build**: `2026-10-14T12:54:55Z` | **GIT_SHA**: `c6733ae1276880507ca0c5b053ae18fb0df090d6` | **Platform**: linux-x86_64 | **Runtime**: Bun v1.4.3
>
> Reference: [2.1.197 codenames](../2.1.197/codenames.md) · [2.1.169 codenames](../2.1.169/codenames.md) · [Glossary](../../docs/glossary.md)

This build has **704 feature flags** (2.1.197 recount: 251; published 243). The flag churn is **519 NEW,
66 REMOVED, 185 kept**, and there are **1,944 telemetry events**. All counts come from
[`_facts.md`](bundle/_facts.md) §1.1–§1.2. Most flag names are still `tengu_<adjective>_<noun>` labels
with no meaning. The codenames that carry meaning are the nouns and prefixes that recur across several
flags and resolve to one feature.

The packaging changed this build: the app is now ESM and code-split into 2,401 JS modules. The flag
reader is now a class in module 152 `chunk-7rwjz6p0.js`:

- `k(name, def)` = `getFeatureValue_CACHED_MAY_BE_STALE` (`:142865`)
- `vn` returns `{value, source}` (`:142861`)
- `vr` is session-pinned (`:142869`)
- `MG` is the refresh wrapper (`:142879`)
- `rb` and `V9e` are async gates (`:142882`, `:142885`)
- `KC` and `Mj` read dynamic config (`:142994`, `:142990`)

Readable names come from the module 907 re-export at `cli.beauty.js:879942`. Every flag name is still a
`tengu_`-prefixed literal. **Many flags in this build are held in a `var` constant** (for example
`var a = "tengu_violin_maple"` at `:280554`) and then read as `k(a, …)`. A first-argument literal scan
misses those. Where a family count matters, this doc gives two numbers:

- the direct-accessor count, from a module-unaware regex over `k|vn|vr|MG|rb|V9e|KC|Mj|JOr`. It finds
  698 flags, which is close to the canonical 704 but not identical.
- the any-literal count: every quoted `tengu_[a-z0-9_]+` string, which finds 3,051. `_facts.md` gives
  3,056 with a different regex. This set includes event names.

Treat both as **family-sizing numbers**, not canonical totals.

---

## How to tell a real codename from random noise

The random name generator lives in module 147 `chunk-bzcqvyw4.js` at `cli.beauty.js:104996–104998`
(it was `:102667` in 2.1.197). It has three arrays, drawn from with `crypto.randomBytes(4)`:

| Array | 2.1.300 size | 2.1.197 size | Change |
|---|---|---|---|
| `t`: adjectives | 219 | 219 | identical |
| `o`: nouns | 409 | 409 | **+`heron`, `magpie`, `nautilus`, `possum`; −`hedgehog`, `manatee`, `narwhal`, `porcupine`** |
| `g`: gerunds | 109 | 109 | identical |

The 2.1.197 doc gave "~270" adjectives and "~400" nouns. The exact recount of the 2.1.197 arrays is
219, 409 and 109.

`harbor`, `lantern`, `hearth`, `kite`, `tide`, `heron`, `brook`, `lark`, `willow` and `cerf` are all in
the random noun pool, and `tidy` and `lucky` are in the adjective pool. Seeing one of them in **one**
flag means nothing. The test is the same one used for 2.1.169 and 2.1.197: **does the same noun or
prefix recur across several flags, and do its call sites resolve to one feature?**

**A second signal is new in 2.1.300: themed suffix vocabularies.** The three biggest new clusters do not
take their suffixes from the random pool. Each uses its own themed word list. The words below were
checked against pool `o`; none of them are in it.

- **`violin_*`** uses violin-making terms: `amati`, `strad`, `guarneri`, `luthier`, `rosin`, `fhole`,
  `purfling`, `scroll`, `tailgut`, `endpin`, `pernambuco`, `bassbar`, `chinrest` and others.
- **`cobalt_plinth_*`** uses plant names: `alder`, `aspen`, `bracken`, `campion`, `comfrey`, `damson`,
  `fennel`, `hornbeam`, `lovage`, `madder`, `mallow`, `medlar`, `orpine`, `sainfoin`, `samphire`,
  `sorrel`, `tansy`, `thrift`, `yew` and others.
- **`lantern_*`** uses candle terms: `wick`, `wick_braid`, `sconce`, `snuffer`.
- **`teal_corbel_*`** uses architecture terms: `finial`, `newel`.

When the suffixes share a theme like this, every flag in the cluster almost always belongs to one
feature.

---

## Confirmed meaningful codenames

| Codename | Domain / Feature | Evidence (flags / files / call sites) |
|----------|------------------|----------------------------------------|
| **tengu** | Claude Code (the product) | Prefix on all 704 flags and 1,944 events. Unchanged. |
| **violin** | **Remote tools / device bridge.** The local machine serves its tools, settings, plugins and hooks to a remote (cloud) session. | **NEW: 48 distinct `tengu_violin_*` literals, 28 of them direct-accessor flags. The string `violin` occurs 0 times in 2.1.197.** <br>• Core module 272 `chunk-6jnsysfj.js` (`:280521–280631`). The module 907 aliases at `:880978` give the meaning: `nx`/`Xf` = `isViolinWoodEnabled(Cached)` (`tengu_violin_wood`), `b0t`/`Jf` = `isDeviceIdentityEnabled(Cached)` (`violin_wood` OR `violin_maple`), `m$`/`bU` = `isSettingsToCloudEnabled(Cached)` (`violin_wood` AND `violin_strad`), `Nrn`/`S0t` = `isCloudPluginForwardingEnabledCached`/`…FlagOn` (`violin_wood` AND `violin_amati`). <br>• `Xf()` is the master switch for tool serving. `cs()` returns `{servedToolsUnavailable:"flag_off"}` when it is off (`:1522613`). It also sets `toolServingOn: Xf()` on the device bridge (`:1088052`) and `localDeviceFlag` (`:1081222`). <br>• In the same chunk as the env knobs `CLAUDE_CODE_REMOTE_TOOLS_SESSION_CHANNEL` / `_JUMP_QUEUE` / `_ASK_SEATS` / `_SPECULATIVE_CLASSIFIER` (`:321296–321377`) sit `tengu_violin_tailpiece`, `_mute` (`"served-tools-muted"`), `_plan_classifier`, `_bassbar` and `_speculative_classifier`. <br>• Hook forwarding is gated by `Xf() && fRr()` (`violin_amati`), unless `CLAUDE_CODE_DISABLE_HOOK_FORWARDING` is set (`:1258559`). `violin_rib` gates `gatherHostInventory` (`:1113361`). `violin_luthier` sits beside `CLAUDE_CODE_REMOTE_TOOLS_SERVE` (module 1997, `:1627795`). <br>• Satellites in `[remote-tools]`-logging modules: 1405 `chunk-h3y7d1e6.js` (`neck`, `nut`, `eye`, `arching`, `tailgut`, `hair`, `ferrule`, `purfling`, `ebony`), 1485/1492/1506 (`table`, `fhole`, `spruce`, `endpin`, `finetuner`, beside `tengu_remote_tool_serving`), and 1757 (`pernambuco`, `winding`, beside `tengu_remote_tool_targets` and `tengu_dir_sync_*`). <br>• `violin_tip` → `isSleepNoticeOnCached` (`:1516810`) and `violin_winding` → `isAwayRecheckOnCached` (`:1465151`). These are the device sleep/away notices. |
| **cobalt_plinth** | **Artifacts** subsystem | **EXPANDED: 30 distinct literals (2.1.197: 5). 28 are new, and 3 were removed (`_direct`, `_putguard`, `_reader_persist`).** <br>• The master gate `N()` is `k("tengu_cobalt_plinth", pe())` (`:355615`). The env check in front of it is dead code: `$e(a.CLAUDE_CODE_ARTIFACT) && !1 \|\| …`. **CHANGED default:** 2.1.197 used `it("tengu_cobalt_plinth", !1)` (`:224993`). Now the default is `pe()`, which is true when the auth kind is `undefined`, `"prosumer_oauth"` or `"no_auth"` (`:355609–355611`). Policy `allow_cobalt_plinth` is still checked (`:159843`, `:355636`). <br>• Most satellites pair with a `CLAUDE_CODE_ARTIFACT_*` env override: `_alder` → `ARTIFACT_DELETE` (`:783026`), `_aspen` → `ARTIFACT_PREVIEW` (`:775721`), `_bracken` → `ARTIFACT_MULTI_FILE` (`:690415`), `_damson` → `ARTIFACT_TOOLSET` (it latches and fires `tengu_artifact_toolset`, `:690277`), `_willow` → `ARTIFACT_OPEN_ACTION` (`:783658`). <br>• Others: `_dataviz` (charts guidance prompt, `:786722`), `_sill` (numeric cap, `:690410`), `_sorb` (design-quickstart guard, `:1413841`), `_thrift` (`:355899`), `_sedge` (`:352803`), `_yew` (`:781578`), `_lovage` (`:75232`), and `_orpine` (in the flag reader's fallback set `_r`, `:133709`). <br>• `_fern` **CHANGED** default `!1` → `!0` (`:690397`; 2.1.197 `:405997`). |
| **teal_corbel** (+ artifact-comment satellites) | **Artifact comments** (the ArtifactComments tool / responder) | **NEW.** <br>• `teal_corbel` → `CLAUDE_CODE_ARTIFACT_COMMENTS ?? k(…, !1)` (`:698965`). Its provenance reader returns `"env"` or the `vn` source (`:698969`). Also `_finial` (default `!0`, `:706232`) and `_newel` (`:1403902`). <br>• Artifact-comment flags with **unrelated random names**: `bracken_sluice` → `CLAUDE_CODE_ARTIFACT_COMMENT_RESPONDER` (`:706538`), `gorse_pylon` → `…_COMMENT_FAST_ACK` (`:706994`), `gorse_sill` → `…_COMMENT_FAST_ACK_FIXED` (`:707028`), and `onyx_sluice` (`"cp_read_disabled"`, `:699948`). Also `copper_hinge_wren` → `CLAUDE_CODE_ARTIFACT_HOT` (`:690443`). The domain is real. The *names* `sluice`, `gorse` and `copper` are not codenames. |
| **harbor** | Channels **+ cross-session (peer) messaging** | **EXPANDED: 25 literals (2.1.197: 14).** <br>• The core gate is unchanged in meaning: `fF()` = `on("allow_channels") && k("tengu_harbor", !1)` (`:775498`). `harbor_ledger` is the channel allowlist (`:775492`). `harbor_permissions` (`:1248861`), `harbor_moth` (`:808699`), and `harbor_willow`, which has the new `meadow_lantern` client-data fallback (`:162781`). <br>• **NEW sub-family `harbor_kite*` = cross-session messaging.** `Gi()` is re-exported as `isCrossSessionMessagingEnabled`. It returns false when `messagingBeyondOwnAgentsDisabled` is set, then checks env `CLAUDE_CODE_HARBOR_KITE`, then a Windows sub-gate `tengu_harbor_kite_win` (default `!0`), then `tengu_harbor_kite` (default `!0`) (`:348684–348690`). The refusal string is `"Cross-session messaging is not available in this session."` <br>• `harbor_kite_cloud` = `hasCloudPeerAccess`. It needs `Gi()`, `firstParty` and policy `allow_remote_sessions`, plus env `CLAUDE_CODE_HARBOR_KITE_CLOUD` or the flag (`:1042688–1042692`). <br>• `harbor_kite_limits` = the `[peer-guard]` token bucket, read via `MG` with refresh `300000` ms. Its fields include `bucketCapacity`, `refillPerSecond`, `maxSelfHops`, `maxChainLength` and `maxQueuedPeerMessages` (default 50) (`:347205–347231`). Also `_pacing_off` (`:347466`, env `CLAUDE_CODE_HARBOR_KITE_PACING_OFF`) and `_mode_emit` (`:1271282`). <br>• `Gi()` also gates `tengu_fleetview_peers` (`:849695`) and `tengu_send_file` (`_facts.md` §1.3, `:818843`). <br>• Adjective-prefixed `_harbor` flags are still opportunistic: `silent_harbor` (prompt section, `:492180`), `quiet_harbor` (`"ask"`/`"transient"`, `:368802`), `slate_harbor_experiment` (`CLAUDE_CODE_NEW_INIT`, `:458250`), and the new `smooth_harbor` (extra-usage path in `RGr`, `:526734`) and `zinc_harbor` (`vr`, `:409987`). `bubbly_harbor`, `plaid_harbor`, `woven_harbor`, `zippy_harbor` and `velvet_harbor_owl` are NEW and unclassified. `harbor_prism` is REMOVED. |
| **lantern** (prefix form `lantern_*`) | **Usage-limit grace window / wrap-up** | **NEW as a cluster.** In 2.1.197 `lantern` was only noise (`*_lantern`, plus a lone `lantern_spool`). <br>• `tengu_lantern_wick_mode` accepts `"wrap-up"`/`"next-steps"`/`"off"` (`:183826–183831`), next to the injected text `"[Usage limit reached — grace window active. Wrap up: finish or checkpoint; …]"` (`:183825`). `_wick_text` is at `:183832`. <br>• Per-model variants `_wick_release`, `_wick_braid`, `_wick_braid_text`, `_wick_braid_release`, `_wick_text_by_model`, `_wick_release_by_model` (`:677682–677687`) and `_wick_resume_by_model` (`:677978`). The reader `q9r()` looks up `[model, normalized, "default"]` in an object flag. <br>• `lantern_sconce` sets the `graceWindow` (`:1361024`) and is forwarded to the IDE, along with `_sconce_copy`, in `YC()` (`:1502911–1502926`). `lantern_snuffer` covers `workflowWaitsOutUsageLimit` (`:526737`, `:1361293`). `lantern_spool` and `lantern_hinge` gate the extra-usage path in `RGr()` (`:526720–526738`). <br>• `lantern_prism` + env `CLAUDE_CODE_LANTERN_PRISM` (`:351211`) is in a different module, and its domain is not established. <br>• The `<adjective>_lantern` flags remain noise (`birch_`, `cedar_`, `keen_`, `quiet_`, `hazel_`, …). |
| **hearth** | **hearthbot**: an MCP relay bot for Projects / chat-thread sessions on CCR | **NEW (2.1.197 has one stray `hearth` token).** <br>• `var Jl = "hearthbot"` defines the tools `mcp__hearthbot__reply`, `__fetch_messages`, `__fetch_thread` and `__fetch_project_timeline`, and the mount `/v2/ccr-sessions/{}/hearthbot/mcp` (`:76677–76686`). Also `/v1/code/mcp/hearthbot` (`:77681`). <br>• State fields `hearthRelayThreadTs`, `hearthRelayMessageIds` and `hearthRelayRows` (`:132185`). Binding helpers `readHearthBinding` and `createHeadlessHearthMount` (`:1509219–1509229`, `:1802626–1802722`). <br>• Flags `tengu_hearth_resolved_rows` (`"off"`/`"full"`/`"model_only"`, `:345248`) and `tengu_hearth_member_relay_rows_enabled`, with env `CLAUDE_CODE_AUTO_MODE_HEARTH_MEMBER_RELAY_ROWS` (`:345254`). <br>• Related **NEW** entrypoint `remote_projects` maps to the `claude_code_remote` surface (`:378–390`; 0 occurrences in 2.1.197). <br>• `witty_hearth` (`:463065`) is probably noise. |
| **kairos** | Loops / scheduling / brief / push / cron | **Holds.** `kairos_brief` (`CLAUDE_CODE_BRIEF \|\| MG(…)`, `:368699`), `kairos_cron` (`!CLAUDE_CODE_DISABLE_CRON && MG(…, !0)`, `:369682`), `kairos_cron_durable` (default `!0`, `:369686`), `kairos_push_notifications` (`:369430`), `kairos_loop_persistent` (`:1454109`), `kairos_loop_keepalive` (default `!0`, `:734177`). **NEW** `kairos_ready_nudge`: an object `{probability, maxImpressions (default 5), impressionKey}` that is only read when `hpe()` (push notifications) is on (`:814924`, minified). **REMOVED:** `kairos_loop_dynamic`, `kairos_loop_prompt` (0 literals). |
| **bridge** + **ccr** | Remote control / remote-bridge REPL / CCR session transport | **Greatly expanded.** Direct-accessor flags: `bridge_*` 31 (25 new), `ccr_*` 31 (27 new). Any-literal: `bridge` 108 (2.1.197: 38), `ccr` 50 (2.1.197: 9). <br>• Core gate `Tct()` = `oU() && c() && (k("tengu_ccr_bridge", !1) \|\| g())` (`:289564`); async `rb("tengu_ccr_bridge")` (`:289614`). <br>• New examples: `bridge_auth_revive` (default `!0`, `:290010`), `bridge_rc_child_artifact` (`:290152`), `bridge_repl_v2_config` (back, via `JOr`, `:1050642`), `ccr_orphan_restore_wake` (`:1507734`), plus the `ccr_stream_*`/`ccr_*_keepalive*` transport-tuning family. <br>• `bridge_attestation_enforce(_config)` survives behind the `da()` wrapper (`:292370`). **REMOVED** (0 literals): `bridge_vivid`, `bridge_system_init`, `ccr_delta_rehydrate`. |
| **baku** | Remote entrypoint variant | **Holds.** `remote_baku` → `claude_code_remote` in `oh()` (`:385`). It is a member of the remote-entrypoint sets at `:24578` and `:24768` (the second set is shared with `claude_in_slack`, `claude-in-teams`, `remote_cowork`, …). 5 occurrences (2.1.197: 4). |
| **mantle** | Provider plane: Anthropic **Bedrock-Mantle** | **Holds.** Model rows carry `mantle:"anthropic.claude-fable-5"` / `"anthropic.claude-fable-5-1"` (`:21022–21068`). `checkMantleDefaultAvailability` fires `tengu_mantle_probe_result` / `tengu_mantle_default_check` (`:1462394–1462408`). **NEW** event `tengu_mantle_default_fallback` (`:768503`). The plane order now places `anthropicGoogleCloud` before mantle (`_facts.md` §3). |
| **amber** | Agent teams / autonomy / downsell (mixed) | **Holds, still muddy.** The core is intact: `amber_flint` (default `!0`) with env `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`/`--agent-teams` (`es()`, `:346200`), `amber_sextant` (default `!0`) gating the `autonomy_append` section `Zir()` (`:491977`), `amber_creek` → `downsellGateCached`/`"downsell_on"` (`:350530`, `:350565`), and `amber_lattice` → plugin allowlist (`:536770`). **NEW** opportunistic members: `amber_ferry` (`:1473803`), `amber_kestrel` (`:728686`), `amber_larch` (bash heredoc complexity, `:429237`), `amber_packet` (`:518616`), `amber_tollgate` (`install-from-source`, `:1692972`), `amber_tally` (`:1288020`), `amber_moleskin` (`:448862`). New env var `CLAUDE_CODE_AMBER_ASTROLABE`. **REMOVED:** `amber_heron`, `amber_quill`, `amber_wren`. |
| **saffron** | Billing: credits / overage / plan limits | **Holds (core).** `saffron_lattice` (`:176998`), `saffron_credits_only_tiers` (`:177037`), `saffron_picker_dim` (`:177059`) and **NEW** `saffron_ladder` (`ffe() && …`, `:177063`) all sit in billing module 187 `chunk-v7aj317d.js`. Opportunistic **NEW** members: `saffron_wren` gates the goal check-in interval (`CLAUDE_CODE_GOAL_CHECKIN_MINUTES`, `:749172`), which is not billing. `saffron_ferry` (default `!0`) is IDE-forwarded in `YC()` (`:1502921`). `saffron_kite` (`:729016`). **REMOVED:** `saffron_anchor`. |
| **lapis** (`lapis_anchor`) | Token-budget reminder | **Holds, CHANGED.** The reader `kir()` now checks env/settings, then **client data** (`Cl()?.tengu_lapis_anchor`, which logs `"ignoring clientData … falling through to GrowthBook"`), then `k(K9e, "padded-countdown")` (`:491586–491630`). **Default changed `"off"` → `"padded-countdown"`** (2.1.197 `:454944`). NEW names: `_threshold` (`:491514`), `_user_turn`, and event `_from_client_data` (`:491590–491591`). The names are held in `var`s, so the direct-accessor scan misses them. |
| **convolute_arcades** / **tender_quilt** | Safety-refusal **model switch** | **NEW in 2.1.300 (0 occurrences in 2.1.197; see the correction below).** `var Rl = "convolute_arcades"`, header `x-cc-tender-quilt` (`:179815–179816`). `QPe()` returns `"convolute_arcades"`, `"tender_quilt"` or `"none"` (`:179835`). `zEo()` swaps the model only for refusal categories `yy = new Set(["cyber","frontier_llm"])` (`:179847–179856`). The user string is `"automatically switched from ${e} after a message was flagged — run /model to switch back"` (`:179813`). Events `tengu_convolute_arcades_tools`/`_retry`/`_retry_outcome` (`:751498`, `:757068`). |
| **tether** | Threaded / stateful request mode (tentative) | **NEW (`tether` occurs 0 times in 2.1.197).** `HS()`/`IWr()`: env `CLAUDE_CODE_TETHER_LIVE`, otherwise gated by `tengu_curious_tower`, a random name and **not** a `tether` flag (`:523239–523250`). State `rootLatestRequestThreaded`. Events `tengu_tether_decision` (with `historyEditClaims`: compact/snip/rewind/…, `:523985`), `tengu_tether_live_outcome` (`:523694`), `tengu_tether_echo_audit`, `tengu_tether_unrecognised_400`. This codename appears in code, env and events, but **not in flag names**. |
| **juniper** | Split (**not** one feature) | `juniper_relay` gates the **SendFeedback** path. `T9r()` requires `firstParty` and respects `CLAUDE_CODE_SEND_FEEDBACK` (`:736630–736639`). `juniper_relay_config` is read via `KC` (`:740429`). `juniper_tide_*` events cover a **usage-limit wall offer** experiment: asked, wall, shown, selected, result (`:1205814–1205908`), plus menu event `tengu_rate_limit_options_menu_select_juniper_tide` (`:1697571`). `juniper_sundial` + env `CLAUDE_CODE_JUNIPER_SUNDIAL` (`:553827`), `juniper_bassoon` (`:1336452`), `juniper_vale`. Treat `juniper_relay*` and `juniper_tide*` as two sub-codenames. |
| **sage_compass** | Server-side **advisor** tool | **Holds.** `tengu_sage_compass2` read as an object (`gk()`, `:313845`). |
| **grove** | Policy & privacy notice | **Holds.** `POST /api/oauth/account/grove_notice_viewed` (`:958259`), `groveConfigCache` (`:958297`). |
| **ultraplan** | `/ultraplan` | **Holds.** `tengu_ultraplan_config?.enabled === !0 && Tct() && !Un()` (`:475100`). This build adds a dependency on the CCR bridge gate `Tct()`. `tengu_ultraplan_prompt_identifier` (`:475115`). |
| **fleetview** | Fleet / PR-batch view | **Holds, expanded.** `fleetview_pr_batch` (default `!0`, `:849770`) and **NEW** `fleetview_peers` (gated on `Gi()` = harbor_kite, `:849695`). New env `CLAUDE_CODE_FLEETVIEW_SIMPLE` and `CLAUDE_CODE_FLEET_PAST_SESSIONS`. **REMOVED:** `fleetview_onboarding_v2`. |
| **copper** | Upsell + job-mode | **Holds.** `copper_lantern` (`:368798`; also a telemetry event and Datadog-allowlisted, `:349582`) and `copper_thistle` (`:1321413`). The new `copper_*` names (`_kestrel`, `_kite`, `_gazette`, `_hinge_wren`) are opportunistic. |
| **pewter_owl** | Unreleased-model preview gate | **Holds.** `tengu_pewter_owl_model` (string default `""`, `:368643`), env `CLAUDE_CODE_PEWTER_OWL(_TOOL)`. |
| **rotunda** | Fallback-credit header strip | **Holds.** 10 `rotunda_pennant_*` literals (2.1.197: 9). The new one is `_chain_exhausted`. `tengu_rotunda_pennant_strip` is at `:528463`. |
| **Prompt-section slots** (`heron_brook`, `brook_heron`, `willow_tern`, `autonomy_append`) | System-prompt arms | The composer list at `:492180–492188` names these sections: `heron_brook`, **NEW** `brook_heron`, **NEW** `willow_tern`, `autonomy_append`, **NEW** `endconv_deferred_hint`, **NEW** `opus5_reduced_delegation`, **NEW** `overcorrection`. <br>• `heron_brook`: `Dln()` reads client data first, then `k("tengu_heron_brook","")` (`:491906–491919`). It falls back to `Vir()`, the Haiku 5.5 early-stopping arm (`haiku_5_5_early_stopping_guidance` + `vr("tengu_idempotent_wolf", !0)`, `:491938–491941`). <br>• `brook_heron` = an effort-scoped section `Jir()` (`:491966`). <br>• `willow_tern` = the "# Writing for the user" section `Xir()` (`:491957`). `brook_heron` and `willow_tern` occur 0 times in 2.1.197. |
| **hushed_lark** / **lucky_cerf** | Prompt nudges (NEW) | `hushed_lark` sets the number of turns before the **silent-turn reminder** (default 5). `_text` holds the reminder text, overridable by `CLAUDE_CODE_SILENT_TURN_REMINDER_TEXT`/`_TURNS` (`:553387–553417`). `lucky_cerf` is a per-model list gating the **"A fresh agent costs more than it looks"** subagent-cost guidance. `_text` overrides it (`:161165–161173`, `:443296–443300`). These are prompt arms in the same style as 2.1.197's `sparrow_ledger`. |
| **shoji_engine** | Stream-wire validator → now only a feature-usage name | **CHANGED.** The flag `tengu_shoji_engine` and the `"wire_violation"` telemetry are **gone** (0 literals). What survives is `g("shoji_engine")` (`:766462`). `g` is the `tengu_feature_ok` emitter in module 74 `chunk-6w4kc9tx.js` (`:47892`). `shoji_engine` is a member of array `gH` (**1,427 names**, module 152, `:135922`). `gH` is concatenated with `_H` (3 `plugin_directory_*` names), `yH` (`ide_mods_surface_attach`) and three empty arrays into `Uk` (**1,431 names**, `:135928`), which becomes the closed `feature_name` enum `UH = Ae(...Uk)` → `Hf={feature_name: UH}` (`:136095–136097`). In 2.1.197, `"shoji_engine"` appeared only at call sites, not in an enum list. |

---

## Model codenames (non-flag)

| Codename | What it is | Evidence |
|----------|-----------|----------|
| **fable** | Real model **family**, now at two versions | Model table rows `claude-fable-5` (`:21022`) and **NEW** `claude-fable-5-1` / "Fable 5.1" (`:21068`). Both have `bedrock` and `mantle` ids. `family: "fable"` occurs 8 times (2.1.197: 1). The identity string at `:491890`: *"Claude Fable 5.1 … part of the Mythos-class model tier that sits above Claude Opus … Claude Fable 5.1 and Claude Mythos 5.1 share the same underlying model … includes additional safety measures for dual-use capabilities, while Claude Mythos 5.1 is available without those measures to only approved organizations."* The equivalent Fable 5 string is at `:491891`. |
| **mythos** | Real model **family**: `claude-mythos-5`, **NEW** `claude-mythos-5-1` | Rows at `:21114` ("Mythos 5") and `:21146` ("Mythos 5.1"). Both have `bedrock: null, mantle: null`. `claude-mythos-5-1` occurs 8 times in 2.1.300 and 0 times in 2.1.197. The `_facts.md` §1.7 model-id regex does not match the `mythos` family, so this id is not in the 62 count. |
| **opus-5 / opus-5-5 / sonnet-5-5 / haiku-5-5** | New generation ids (not codenames) | Model table rows `claude-opus-5` (`:20928`), `claude-opus-5-5` (`:20975`), `claude-sonnet-5-5` (`:20681`), `claude-haiku-5-5` (`:20458`). See `_facts.md` §1.7. The prompt section `opus5_reduced_delegation` (`:492182`) and the arm `haiku_5_5_early_stopping_guidance` (`:491939`) show that per-model prompt arms now exist for this generation. |
| **pewter_owl** | Preview-model gate | Carried (see above). |
| ~~velvet_falcon~~ / ~~fruitcake~~ / ~~macaroon~~ | Gone | 0 occurrences in 2.1.300 (same as 2.1.197). |

---

## Auto-generated `adjective_noun` flag names (no semantic meaning)

These use the random-pool style, appear in one flag each (or in clusters that fail the call-site test),
and are throwaway labels. The list is representative, not exhaustive, and every name below is NEW in
2.1.300. Several of them nonetheless gate **important** features, so a random name says nothing about
how much the feature matters:

- `valiant_rain`: `CLAUDE_CODE_REMOTE_TOOLS_JUMP_QUEUE` (`:321312`)
- `unified_waterfall`: `CLAUDE_CODE_REMOTE_TOOLS_ASK_SEATS` (`:321341`)
- `eventual_haven` (`:321352`)
- `curious_tower`: the tether gate (`:523249`)
- `sleepy_snowflake`: `CLAUDE_CODE_SLEEPY_SNOWFLAKE` (`:523255`)
- `idempotent_wolf`: the Haiku 5.5 arm (`:491940`)

Other new single or loose names:

`tidy_*` (8: `cloud`, `eclipse`, `fern`, `frost`, `lemon`, `origami`, `sloth`, `widget`, scattered across
modules 187, 325, 424, 569, 2081; no common domain), `calm_*` (7), `shore` (5: `concurrent_`, `cosmic_`,
`deep_`, `quirky_`, `sleepy_`), `panda` (4), `humble_*` (4), `mossy_*` (4), `breezy_*` (4), `dapper_*` (4),
`kestrel` (8 as a noun with different adjectives), `plover` (8), `heron` (8), `twinkling_{boole,cosmos,hoare}`,
`fizzy_{grove,minsky,treasure}`, `noble_{mountain,snowflake,wozniak}`, `melodic_*`, `quirky_*`,
`valiant_*`, `moonlit_*`, `glade` (3), `locket` (3), `meteor` (3), `orbit` (3).

Several adjective prefixes now have 3–8 members (`tidy`, `calm`, `humble`, `dapper`). None of them passed
the call-site test: their members land in unrelated modules. They look like a batch of names minted
together, not a feature codename. **Tentative.**

---

## Status of the 2.1.197 codenames

| 2.1.197 codename | Domain | 2.1.300 status |
|------------------|--------|----------------|
| **tengu** | Product prefix | **Holds.** |
| **kairos** | Loops/schedule/brief/push/cron | **Holds.** `ready_nudge` new; `loop_dynamic`/`loop_prompt` removed. |
| **harbor** | Channels/teams | **Holds, expanded**: the `harbor_kite*` cross-session messaging sub-family; `harbor_prism` removed. |
| **bridge** + **ccr** | Remote control | **Holds, roughly 3× larger.** `bridge_vivid`, `bridge_system_init` and `ccr_delta_rehydrate` removed. |
| **baku** | Remote entrypoint | **Holds.** |
| **mantle** | Bedrock-Mantle plane | **Holds**; new `mantle_default_fallback` event. |
| **amber** | Teams/autonomy/downsell | **Holds** (core); `heron`/`quill`/`wren` removed, 7 opportunistic names added. |
| **cobalt_plinth** | Artifacts | **Holds, 5 → 30 literals**; default now auth-dependent (`pe()`). |
| **saffron** | Billing | **Holds**; `saffron_anchor` removed, `saffron_ladder` added. |
| **lapis** | Token-budget reminder | **Holds**; default now `"padded-countdown"`, client-data override. |
| **shoji_engine** | Wire validator | **Flag REMOVED**; survives only as a `feature_name` in `tengu_feature_ok`. |
| **cobalt_heron** | Pro→Max nudge | **REMOVED** (0 literals). |
| **sage_compass** | Advisor tool | **Holds.** |
| **grove** | Policy notice | **Holds.** |
| **orchid_mantis** | `/schedule` offer prompt | **REMOVED.** `tengu_orchid_mantis` and `_v2` have 0 literals. |
| **ultraplan** | `/ultraplan` | **Holds**; now also requires `Tct()`. |
| **fleetview** | Fleet/PR-batch | **Holds**; `onboarding_v2` removed, `peers` added. |
| **frame** (`frame_publish_context`) | Frame publish | **Flag REMOVED** (0 literals). `/api/frame/*` endpoints remain (8 `/api/frame/deploy` occurrences in `cli.min.js`). `CLAUDE_CODE_COWORK_FRAME_ARTIFACTS` is NEW. |
| **copper** | Upsell/job-mode | **Holds** (`copper_lantern`, `copper_thistle`). |
| **coral** | Billing upgrade UI | **`coral_beacon` REMOVED.** `coral_anchor` (NEW, `:461353`) is unrelated by call site. **Codename lapsed.** |
| **marble** | Model access | **`marble_lark` REMOVED.** `marble_heron` (NEW, `:677836`) is unrelated. **Codename lapsed.** |
| **rotunda** | Credit strip | **Holds.** |
| **convolute_arcades** | Request retry | **Correction:** the 2.1.197 doc called this "carried from 2.1.169". In fact `convolute_arcades` occurs **0** times in 2.1.197 `cli.min.js` and 12 times in 2.1.300. Treat it as **NEW (re-introduced) in 2.1.300**, with the meaning above. |
| **sparrow_ledger** / **walnut_prism** | Prompt arms | **REMOVED** (0 literals). `verified_vs_assumed` is still read directly (`:492018`). |
| **heron_brook** | Prompt arm | **Holds**; now client-data-first, with a Haiku 5.5 fallback. |
| **pewter_owl** | Preview-model gate | **Holds.** |
| **team_discovery** | Team auto-discovery | **REMOVED.** `tengu_team_discovery` and `allow_team_discovery` both have 0 occurrences. |
| **fable** / **mythos** | Model families | **Hold, version 5.1 added** to both. |

---

## What's new vs 2.1.197

New codename clusters and promotions in 2.1.300:

- **violin**: remote-tools / device bridge (48 literals, 0 in 2.1.197). This is the largest new family.
  It covers the local machine serving its tools, settings, plugins and hooks to cloud sessions, plus
  device identity and sleep/away notices.
- **harbor_kite**: cross-session (peer) messaging with a token-bucket peer guard, and a cloud-peer
  variant.
- **lantern_*** (prefix form): the usage-limit **grace window / wrap-up** prompts, per model.
- **teal_corbel** (+ `bracken_sluice`/`gorse_pylon`/`gorse_sill`/`onyx_sluice`): **artifact comments**.
- **cobalt_plinth** grew from 5 to 30 literals (artifact delete, preview, multi-file, toolset, open
  action, dataviz, …). Its master gate defaults on for prosumer/no-auth sessions.
- **hearth**: the `hearthbot` MCP relay for Projects / thread sessions; entrypoint `remote_projects`.
- **convolute_arcades / tender_quilt**: safety-refusal model switch (`cyber`, `frontier_llm`).
- **tether**: threaded request mode (env, state and events only; gated by a random-name flag).
- **juniper_relay** (SendFeedback) and **juniper_tide** (usage-wall offer) as two sub-codenames.
- **hushed_lark** (silent-turn reminder) and **lucky_cerf** (subagent-cost guidance): new prompt arms.
  New prompt sections are `brook_heron`, `willow_tern`, `opus5_reduced_delegation`, `overcorrection`
  and `endconv_deferred_hint`.
- **Closed `feature_name` enum** of 1,431 names: `gH` (1,427, `:135922`) plus 4 names from `_H`/`yH`, joined into `Uk` at `:135928`. This is a new codebook of internal feature
  names (for example `hfi_*`, `byoc_*`, `swarm_*`, `workshop_*`, `laptop_memory_*`, `rtc_*`, `cedar_ember`,
  `shoji_engine`), used by `tengu_feature_ok/bad/sad`.
- Models: `claude-fable-5-1` and `claude-mythos-5-1` (version 5.1 of both families), and the 5.5
  generation of `opus`, `sonnet` and `haiku`.

Removed since 2.1.197: 57 flag names that have **zero** literals left in 2.1.300. The codename-relevant
ones are `orchid_mantis(_v2)`, `team_discovery`, `shoji_engine`, `cobalt_heron`, `frame_publish_context`,
`coral_beacon`, `marble_lark`, `sparrow_ledger`, `walnut_prism`, `harbor_prism`, `saffron_anchor`,
`kairos_loop_dynamic`, `kairos_loop_prompt`, `cobalt_plinth_{direct,putguard,reader_persist}`,
`amber_{heron,quill,wren}`, `bridge_vivid`, `bridge_system_init`, `ccr_delta_rehydrate` and
`fleetview_onboarding_v2`. Eight more names look "removed" under a direct-accessor diff, but they are
still present as literals read through constants or wrappers: `bridge_attestation_enforce(_config)`
(via `da()`), `lapis_anchor(_budget)` (via `var`), `chair_sermon`, `mcp_normalize_root_combinators`,
`media_byte_cap` and `review_bughunter_config`.

---

## Uncertainties

- **Family counts are approximate.** The direct-accessor scan here finds 698 flags against the canonical
  704, and the any-literal scan finds 3,051 against the canonical 3,056. Cite `_facts.md` for totals and
  use the numbers here only to size families.
- **violin satellites:** the *family* domain is solid. Module aliases, `[remote-tools]` logging and
  `CLAUDE_CODE_REMOTE_TOOLS_*` env all point to it. But most individual satellites (`neck`, `nut`,
  `arching`, `hair`, `ferrule`, `table`, `fhole`, `waist`, `lapping`, `adjuster`, `varnish`, `scroll`,
  `overstand`, `rosin`, …) were assigned to the family by module placement and naming theme. The exact
  sub-behaviour of each was **not** decoded. `violin_rosin` (`:372481`) gates a bash-task snapshot path
  (`:515200`), and it is not obvious how that relates to remote tools.
- **`lantern_prism`** (`CLAUDE_CODE_LANTERN_PRISM`, `:351211`) has the `lantern_` prefix, but it is not
  established that it belongs to the grace-window cluster.
- **`tether`** = "threaded/stateful requests" is **tentative**. It rests on `rootLatestRequestThreaded`
  and the `historyEditClaims` fields, not on a decoded server contract.
- **`juniper`** is two (or more) features under one noun. Of the six direct-accessor `juniper_*` flags,
  only `juniper_relay` and `juniper_relay_config` are clearly SendFeedback.
- **`Cl()`** is read here as the client-data cache. The `lapis` reader's log line
  `"ignoring clientData … falling through to GrowthBook"` (`:491594`) supports this, but `Cl` is a
  chunk-local name that is reused elsewhere (it is also aliased as `listToolsRaw` in another chunk).
- **`amber`** and **`saffron`** keep gaining unrelated members (for example `saffron_wren` = goal
  check-in interval). Only the core flags listed in the table are reliable.
- **`hearth`** = Projects / chat-thread relay is inferred from the hearthbot tool names, the
  `/v2/ccr-sessions/{}/hearthbot/mcp` mount, `hearthRelayThreadTs` and the `[bridge:projects]` log tag.
  Which chat product the thread timestamps come from is **not** established.
- The `feature_name` enum (`Uk`, built mainly from `gH`) is new as a closed list. Whether 2.1.197 enforced an equivalent schema
  elsewhere was not exhaustively checked; its call sites passed free-form names through `$e(e)`
  (2.1.197 `:47509`).
