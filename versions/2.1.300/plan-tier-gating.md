# Plan and Tier Gating

> [Back to version index](../README.md)
>
> **Version**: 2.1.300 | **Build**: `2026-10-14T12:54:55Z` | **Platform**: Linux x86-64
> **GIT_SHA**: `c6733ae1276880507ca0c5b053ae18fb0df090d6` | **Runtime**: Bun v1.4.3

Source: `cli.beauty.js` (1,857,789 lines, beautified from the 2,401 JS modules embedded in the ESM,
code-split Bun v1.4.3 binary). All line numbers are `cli.beauty.js:LINE` in the 2.1.300 bundle unless
marked `2.1.197:`. Minified identifiers change every build. Cross-chunk exports keep one name across
chunks, but chunk-local helpers reuse short names (for example, the module-152 `VE` at `131203` is not the
`VE` that module `chunk-2wcr2nxj.js` exports as `getMainThreadAgentType`). Deltas are against **2.1.197**.
Every "NEW" claim was checked against `2.1.197/bundle/cli.beauty.js`.

Almost all of the plan logic lives in module 152 `chunk-7rwjz6p0.js` (auth, profile, model defaults, fast
mode) and module 187 `chunk-v7aj317d.js` (usage-credit billing, rate-limit copy, low-priority mode). Slash
commands are in module 424 `chunk-538n62w8.js`. The org-policy registry is in module 166 `chunk-y5wyfv6q.js`.

## Symbol map (2.1.197 → 2.1.300)

The logic below is the same unless the Notes column says otherwise.

| Role | 2.1.197 | 2.1.300 | Line | Notes |
|---|---|---|---|---|
| `organization_type` → plan map | `mAn()` switch | `tP` Map + `NPr()` | `118599`, `118605` | Map literal replaces the switch |
| `subscriptionType` getter | `Di()` | `Rr()` | `130940` | Adds a `$E()` bg-dispatcher fallback (`130948`) |
| async plan getter (per-credential) | — | `M9e(e)` | `131444` | **NEW** async twin family (`131423`–`131527`) |
| `rateLimitTier` getter | `TW()` | `EA()` | `131009` | Fallback `GE()` regex-validated (`131017`–`131023`) |
| `seatTier` getter | `Axi()` | `KYs()` | `131025` | |
| `oauthAccount` (scoped) | `Oc()` | `An()` | `130894` | |
| plan display label | `Exn()` | `YIr()` | `131034` | Now prefers server `plan_display_name` (`WE()` `131029`) |
| consumer-OAuth (scoped) | `Ao()` | `kt()` | `130788` | `bl() && scopes ∋ "user:inference"` |
| isMax | `zle()` | `mmt()` | `130985` | |
| isPro | `Jye()` | `qIe()` | `131005` | |
| isEnterprise | `tit()` | `sEe()` | `130997` | |
| isTeam | `PMd()` | `bKn()` | `130989` | |
| Team-5x | `Nxe()` | `SKn()` | `130993` | |
| Enterprise-usage-based | `Xye()` | `Jsn()` | `131001` | |
| isPaidConsumer (max\|\|pro) | `Txi()` | `VE()` (module-local) | `131203` | |
| any-known-plan | `DMd()` | `xQs()` | `130935` | |
| recognised store billing | `Uke()` | `VYs()` over set `KE` | `130906`–`130912` | **CHANGED**: 3 new billing types |
| usage-credits cmd enabled | `Y_t()` | `fI()` | `130914` | |
| `billingType==="usage_based"` | `fU()` | `pj()` | `177205` | |
| has billing access | `sH()` | `Rv()` | `177196` | |
| org role admin/billing/owner | (inline) | `qIr()` | `130924` | |
| default-model resolver | `$4r()` | `av()` + `qVn()` | `125660`, `126308` | **CHANGED**: Opus for more plans |
| 1M-on-by-default | `cT()` | `lq()` | `126313` | **CHANGED**: catalog-aware |
| `CLAUDE_CODE_DISABLE_1M_CONTEXT` | `Yye()` | `uI()` | `126797` | |
| "usage credits not applicable" | `hF()` | `QK()` | `177030` | |
| credits-only tier | `Ede()`/`tfp()` | `yrn()` / `H_()` | `177052`, `177036` | |
| per-model credit billing state | — | `_rn(model)` | `177159` | **NEW** |
| plan-mode Plan-agent count | `Sfc()` | `Dqn()` | `584743` | |
| plan-mode Explore-agent count | `Efc()` | `Lqn()` | `584753` | |
| org-policy read | `js()` | `on()` | `160130` | **CHANGED**: registry-driven |
| org-policy deny string | `DW()` | `Cf()` | `160283` | |
| `/upgrade` availability | `nQf()` | `ffe()` | `176932` | |
| upsell-suppression flag | `gJ()` | `_pt()` | `176924` | still `tengu_idle_amber_finch` |
| rate-limit runway text | `Ncf()` | `oko()` | `183257` | |
| privacy-settings gate | `G_e()` | `c5()` | `131207` | |
| OAuth token record | `qs()` | `Mn()` → `H0()` | `130002`, `129942` | Cached per host (`tEe.of(j().host)`) |

## Subscription Types (the plan enum)

The OAuth profile fetch `NPr()` (`118605`) maps `organization.organization_type` through the `tP` Map
(`118599`–`118604`):

| `organization_type` | internal `subscriptionType` | helper |
|---|---|---|
| `claude_max` | `"max"` | `mmt()` (`130985`) |
| `claude_pro` | `"pro"` | `qIe()` (`131005`) |
| `claude_enterprise` | `"enterprise"` | `sEe()` (`130997`) |
| `claude_team` | `"team"` | `bKn()` (`130989`) |
| (anything else / API key) | `null` | — |

The profile record (`118608`–`118625`) keeps the 2.1.197 shape (`subscriptionType, rateLimitTier,
seatTier, hasExtraUsageEnabled, billingType, ccOnboardingFlags, claudeCodeTrialEndsAt,
claudeCodeTrialDurationDays, displayName, accountCreatedAt, subscriptionCreatedAt, rawProfile`) plus
**NEW `fullName`** (`118619`, from `account.full_name`; `2.1.197:95368` copied only `display_name`).

### NEW: server-supplied plan display name

`HPr()` (`118260`) reads `organization.plan_display_name` and validates it against
`/^[\p{L}\p{N}](?:[\p{L}\p{N} .+-]{0,38}[\p{L}\p{N}+])?$/u` (`_h`, `118256`, so at most 40 characters).
A rejected value emits failure tag `plan_display_name_rejected` (`118266`). `WE()` (`131029`) returns
`` `Claude ${name}` `` when the name is valid, no plan mock is active, and `Iee()` is true. `YIr()` (`131034`)
prefers that string and falls back to the fixed labels `Claude Enterprise / Team / Max / Pro / Claude API`.
`planDisplayName` occurs 0 times in 2.1.197. The server can now relabel a plan in the UI without a client
release.

### Accessors
- `Rr()` (`130940`) is the canonical plan getter. Order: the (dead) mock `na()`/`rd()`, then `bl()`
  (OAuth-capable auth), then `Mn().subscriptionType`, then **NEW** `$E()`.
- `$E()` (`130948`) and `GE()` (`131019`) are **NEW** fallbacks. They apply only when `Iee()` (`130964`)
  holds: no `CLAUDE_CODE_OAUTH_TOKEN`, no FD token (`nn()`), and the token did not come from a bg snapshot.
  They read `uOo()` (`102496`), which returns `CLAUDE_BG_DISPATCHER_SUBSCRIPTION_TYPE` /
  `CLAUDE_BG_DISPATCHER_RATE_LIMIT_TIER` only when `CLAUDE_CODE_SESSION_KIND === "bg"`. The dispatcher
  sets them through `JFs()` (`102485`, key list `Cgt` `102483`). A bg-dispatched session therefore
  inherits its parent's plan. `GE()` drops any tier that fails `/^[a-z][a-z0-9_]{0,63}$/` (`131017`).
  Both env names occur 0 times in 2.1.197.
- `EA()` (`131009`) returns `rateLimitTier`. It checks the dead mock `pVn()` first.
- `KYs()` (`131025`) returns `seatTier`. `An()` (`130894`) returns `oauthAccount` only when `bl()` holds.
  `Ju()` (`130903`) returns it unconditionally.
- `kt()` (`130788`) is consumer OAuth: `bl() && vj(Mn()?.scopes)`, where `vj` → `G5n` (`9481`) tests for
  `"user:inference"` (`cR`, `9475`). It is the 2.1.300 equivalent of `Ao()`.
- `VIe()` (`130873`) accepts the profile scope **or the NEW scopes `user:office` / `user:ccr_inference`**
  (both occur 0 times in 2.1.197). `B0` (`129940`) is the default scope set for managed/CCR tokens:
  `["user:inference","user:ccr_inference","user:file_upload"]`.
- `pj()` (`177205`) is `billingType === "usage_based"`.
- `VYs()` (`130908`) tests for recognised store billing over set `KE` (`130906`):
  `stripe_subscription`, `stripe_subscription_contracted`, **`stripe_subscription_enterprise_self_serve`,
  `aws_marketplace`, `c4e_consumption_trial`** (the bold three are NEW, 0 occurrences in 2.1.197),
  `apple_subscription` and `google_play_subscription`.
- `fI()` (`130914`) gates `/usage-credits`: false if `DISABLE_EXTRA_USAGE_COMMAND`, true if the dead
  override `uM()` is non-null, otherwise `VYs()`.

### NEW: async per-credential twins

Module 152 now exports an async copy of every plan predicate that takes a credentials argument and awaits
`gl(e)` (`130378`) rather than the cached `Mn()`. The copies are `M9e` (plan), `XYs` (tier), `JYs`
(seat), `NQs` (max), `$Qs` (team), `FQs` (team-5x), `UQs` (enterprise), `BQs` (enterprise-usage-based),
`jQs` (pro), `QYs` (label), `WQs` (paid consumer), `DQs` (store billing) and `I1e` (consumer OAuth), at
`131423`–`131505`. `zQs()` (`131507`) builds the `/status` account block from them. They exist because one
process can now host several sessions or credentials: `Mn()` itself is cached per host
(`tEe.of(j().host)`, `130004`). That reading of their purpose is an inference.

### Combined helpers
- `VE(H)` (`131203`) is `H === "max" || H === "pro"`. `c5()` (`131207`) is `kt() && plan !== null && VE(plan)`.
- `xQs()` (`130935`) is true for any of max/enterprise/team/pro/null.
- `SKn()` (`130993`) is Team on `default_claude_max_5x`. `Jsn()` (`131001`) is Enterprise with
  `seatTier === "enterprise_usage_based"`.
- `Rv()` (`177196`) means "has billing access": max/pro, or org role `admin`/`billing`/`owner`/
  `primary_owner` (`qIr()` `130924`).
- `bie()` (`176920`) is `sEe() || Ie() !== "firstParty" || Ct()`. It excludes Enterprise and third-party
  providers from the promo and offer surfaces.

### Plan/tier env overrides and mock deadness
`H0()` (`129942`) builds the token record. When `CLAUDE_CODE_OAUTH_TOKEN` is set (`129943`), or a
managed/FD token is present (`129951`–`129959`), it reads:
- `CLAUDE_CODE_SUBSCRIPTION_TYPE` → `subscriptionType` (`129948`, `129957`)
- `CLAUDE_CODE_RATE_LIMIT_TIER` → `rateLimitTier` (`129949`, `129958`)

The bg auth-snapshot consumer also writes both onto `process.env` (`100807`–`100808`). Both names are on
the child-env passthrough allowlists (`102888`, `102965`, `165624`, `1646702`).

The mock hooks are still compiled out, as in 2.1.197:
- `pVn()` (`117958`) and `rd()` (`117964`) are `return e.enabled, null;` and always return `null`.
- `na()` (`117970`) ends in `&& !1` and is always false.
- `MPr()` (`117975`), `uM()` (`117979`) and `EDs()` (`118003`) return `null`.
- The mock-trial reader `_Co()` (`117983`) is `return null;` followed by unreachable code.

`CLAUDE_CODE_MOCK_TRIAL` occurs exactly once in 2.1.300, the same count as 2.1.197. The plan can be
overridden only through the env vars above.

## Model Access by Plan

### Default model (CHANGED)

```js
function av() {                              // 125660
  let e = (r) => Wve(r) ? Cj(r) : r;         // append [1m] if 1M is opt-in for that model
  if (kt()) { if (qVn()) return { setting: e(Hg()), envFamily: "opus" } }
  else if (au()) return { setting: e(Hg()), envFamily: "opus" };
  let n = Ie();
  if (n === "mantle") return { setting: iw()[Zft], envFamily: null, ... };
  if (n === "bedrock" || n === "vertex") {
    if (qS()) return { setting: Cm(), envFamily: "sonnet" };
    return { setting: Hg(), envFamily: "opus" }
  }
  return { setting: Cm(), envFamily: "sonnet" }
}
function qVn() {                             // 126308
  if (mmt() || SKn() || Jsn()) return !0;
  return (sEe() || bKn() || qIe()) && !qS()
}
```

`qS()` (`124729`) is true only when the user set `ANTHROPIC_DEFAULT_SONNET_MODEL` and did not set
`ANTHROPIC_DEFAULT_OPUS_MODEL`, and no model allowlist is enforced (`li().state !== "inactive"` or
`enforceAvailableModels`).

- **Pro now defaults to Opus.** Plain Team and plain Enterprise do too. Each falls back to Sonnet only when
  `qS()` is true. In 2.1.197 `$4r()` (`2.1.197:101904`) returned Opus only for `zle() || Nxe() || Xye()`
  (Max, Team-5x, Enterprise-usage-based), and Pro got Sonnet.
- **Bedrock/Vertex now default to Opus** (unless `qS()`). In 2.1.197 they reached the final
  `{ setting: nE(), envFamily: "sonnet" }`.
- **Non-subscription first-party traffic still defaults to Opus.** `au()` (`21766`) covers firstParty,
  anthropicAws, **anthropicGoogleCloud (NEW plane)** and gateway. In 2.1.197, `ud()` (`2.1.197:94671`)
  covered firstParty, anthropicAws and gateway.
- **Consumer OAuth with `subscriptionType === null`** (free or unknown) falls through to Sonnet on firstParty.
- The Opus default is `Hg()` (`125270`): `ANTHROPIC_DEFAULT_OPUS_MODEL`, then a firstParty-only override
  `Ka("opus")` → `kL()` → `wS()` (`125246`, `125237`), then `dn()` (`125276`) = `Ha("opus") ?? opus55`.
  `Ha()` (`125225`) resolves the bundled catalog alias `aliases.opus` (`JXe()` `21455`, alias table
  `21186`–`21197`, provider key map `mL` `125214`): **`claude-opus-5-5`** by default and on bedrock,
  vertex, mantle, anthropic_aws and anthropic_google_cloud, but **`claude-opus-4-6` on foundry and
  `claude-opus-4-7` on gateway**. `opus55` is only the fallback when the alias lookup fails.
- The Sonnet default is `Cm()` (`125280`) → `Na()` (`125286`) = `Ha("sonnet") ?? sonnet46`. The catalog
  alias `aliases.sonnet` (`21198`–`21208`) gives **`claude-sonnet-5-5` on firstParty** (default),
  `claude-sonnet-4-5` on bedrock/vertex/foundry/mantle and `claude-sonnet-4-6` on anthropic_aws/gateway.
  `sonnet46` is only the fallback.
- One-shot migration `tengu_reset_pro_to_opus_default` / `opusProMigrationComplete` (`813388`) exists in
  both builds. It is not new.

### Pro + Opus cost signalling (carried)

`hl()` (`178429`): `Rr() === "pro" && k("tengu_gypsum_kite", !1)` appends `" · ~2× usage vs Sonnet"`
to the Opus picker entries (`178442`, `178467`, `178479`). The 1M picker entries `Fc()` (`178446`) and
`Dc()` (`178457`) append `" · Draws from usage credits"` when `kt()`. Flag default `!1`. Unchanged.

New Pro-specific copy: `fvo()` (`163641`) labels effort `high` as `"burns fastest — medium handles most
tasks"` when `qIe() && k("tengu_slate_finch", !1)` (`163644`). That flag and string also exist in 2.1.197,
so this is carried.

### Usage-credit billing state per model (NEW, generalises 2.1.197's Fable-only gate)

In 2.1.197, only Fable could require usage credits. In 2.1.300 a model family list and a per-model state
machine replace that check:

- `HVn = ["Fable", "Haiku", "Mythos", "Opus", "Sonnet"]` (`124087`; no equivalent literal in 2.1.197).
- `dv(model)` (`126432`) maps a model to one of those families. `i5(model)` (`126442`) returns it only if
  it is `"Fable"` **or** is listed in the GrowthBook array **`tengu_calm_seal`** (default `null`; NEW, 0 in
  2.1.197). `Gve()` (`126449`) is `i5() !== void 0`. Any family can therefore be made credits-gated from
  the server. Fable is gated always.
- `D_()` (`176997`) parses **`tengu_saffron_lattice`** (default `{}`) with schema `O_` (`176935`):
  `{enabled?, planLimitsEndDate?, overageConsentRequired?, perModel?: {<model>: {enabled}}}`. `perModel`
  is **NEW**: `F_()` (`176954`) normalises spellings through `Gd()` (`176983`). On a conflict it forces
  `enabled:true` and logs `"…treating that model as billed to usage credits"` (`176968`).
  `planLimitsEndDate`/`overageConsentRequired` already existed in 2.1.197.
- `kBe(model)` (`177018`) returns `perModel[model].enabled` when present. Otherwise it is false if
  `enabled === !1`, else `overageConsentRequired === !0 || planLimitsEndDate !== void 0`.
  `ws(model)` (`177026`) is `kBe(model) || sUo()`, where `sUo` is `isUsageCreditsRequired` (readable alias
  `878167`). That latch is set by `lpn(!0)` after a server 429 that says credits are required (`184076`,
  `450245`).
- **`_rn(model)` (`177159`)** returns one of seven states:

| Return | Condition (in order) |
|---|---|
| `included_in_plan` | model not credits-gated (`i5()` undefined) |
| `pay_per_request` | `QK()`: non-firstParty, not consumer-OAuth, Enterprise-usage-based, or tier `default_claude_zero` |
| `admin_billed` | `yrn()`: Enterprise (non-usage-based) or a plan in `tengu_saffron_credits_only_tiers` |
| `included_in_plan` | `!ws(model)` |
| `needs_consent` | no recorded consent for this org/account (`bpt()` `177082`) |
| `needs_credits` | `!XPe()` (`177142`): `cachedExtraUsageDisabledReason` is `undefined` (unknown), or a non-null reason outside `vVn()` = {`org_level_disabled_until`, `org_spend_cap_reached`, `out_of_credits`} (`121309`) |
| `out_of_credits` | `cachedExtraUsageDisabledReason === "out_of_credits"` |
| `consented` | otherwise |

  `pve()` (`177171`) and `eIs()` (`177176`) collapse those states to booleans. None of the seven state
  strings except the reason enum appear in 2.1.197 (`needs_consent`/`admin_billed`/`pay_per_request`/
  `included_in_plan` all count 0).
- Consent storage is **CHANGED**. Fable still uses `fableOverageConsentV2`. Every other family uses the
  **NEW** map `usageCreditsOnlyModelConsent[family][orgUuid | "acct:"+accountUuid]` (`tl()` `177078`,
  `$_()` `177094`). Consent is keyed per org, or per account when no org exists (`rl()` `177071`), with a
  session fallback (`a$r`/`l$r`/`d$r`, readable names
  `hasUsageCreditsOnlyModelConsentSessionFallback` etc., `878167`).
- Picker: `pl = " · Requires usage credits"` (`178251`). `Ls(model)` (`178253`) appends it when
  `!QK() && kBe(model)`. `Eb()`/`Ab()` (`178268`/`178279`) build Fable entries with it. The rejection copy
  `hHo(reason, overageIncluded, displayName, scope)` (`450862`) generalises 2.1.197's Fable-5 strings to
  `` `${r} requires usage credits.` ``. Compaction refuses when policy allows only a credits-gated model
  (`517327`).
- Picker flags: **`tengu_saffron_picker_dim`** (`Yd()`, `177058`, default `!1`; also in 2.1.197) and
  **`tengu_saffron_ladder`** (`XPs()` `177062`: `ffe() && k(...) === !0`, default `!1`; **NEW**, 0 in
  2.1.197). The ladder's UI effect is not traced here. Tentative: an upgrade ladder in the picker.

`QK()` (`177030`) and `H_()` (`177036`, `tengu_saffron_credits_only_tiers`, default `["enterprise"]`,
`zd` `177034`) keep their 2.1.197 semantics. `default_claude_zero` still appears only inside `QK()`.

### Fast mode (carried, refined)

- `jo()` (`120923`) requires firstParty and no `CLAUDE_CODE_DISABLE_FAST_MODE`.
- `aI()` (`120982`) is the availability reason resolver. It returns `not_first_party`, `disabled_by_env`,
  `"unknown"` (if `tengu_penguins_off` is non-null, `120988`), **`model_not_allowed`** (Opus not in the
  allowlist, `120989`–`120991`), `preference` (managed `policySettings.fastMode === !1` or
  `fastModePerSessionOptIn`, `120994`–`120995`), **`sdk_opt_in_required`** (`120996`), `pending`, or the org
  status reason. `model_not_allowed` and `sdk_opt_in_required` are NEW strings (0 in 2.1.197).
  2.1.197 expressed the Agent-SDK exclusion and allowlist check differently.
- `Cy(reason, authKind)` (`120967`) keeps the plan copy: `free` → `"Fast mode requires a paid
  subscription"` (OAuth) or `"…Please purchase credits."`; `extra_usage_disabled` → `Ry()` (`120961`),
  which now points at `/usage-credits` or the admin path through `_Kn()` (`130929`).
- `JM(overageDisabledReason)` (`121285`) maps the shared reason enum to Fast-mode copy. Same enum as
  2.1.197.
- Env escape hatches `CLAUDE_CODE_SKIP_FAST_MODE_ORG_CHECK` (`120933`) and
  `CLAUDE_CODE_SKIP_FAST_MODE_NETWORK_ERRORS` (`121000`) are unchanged. The fast toggle's picker suffix
  `" · Draws from usage credits"` is at `938363`/`938368`.

### 1M context window (CHANGED: catalog-aware)

`lq()` (`126313`) is the 1M-on-by-default check:

```js
if (uI() || qIe() || Ie() !== "firstParty") return !1;   // DISABLE_1M, Pro, non-1P
if (kt() && Rr() === null) return !1;                    // OAuth with no plan
if (ANTHROPIC_DEFAULT_OPUS_MODEL === void 0) {           // NEW: ask the catalog
  let e = Ka("opus"); if (e !== void 0 && Wa(e) === "never") return !1
}
return !0
```

`Wa(model)` (`126863`) is **NEW**. The string `"optIn"` occurs 0 times in 2.1.197, though `native_1m`
catalog data did exist there. It returns `"never"` (1M disabled or catalog window < 1e6), `"native"` (via `CE()`;
the catalog flag `context.native_1m` is read by `_v()` `126824`), or `"optIn"` (supports the 1M beta). `Wve()` (`126323`) adds
the `[1m]` suffix only for `"optIn"` models.

The bundled catalog marks `claude-opus-5-5` `window: 1e6, native_1m: !0` (`20975`+), so the Opus 5.5 default
needs no suffix. **Tentative inference:** `Wa()` has no plan check, so for native-1M models the plan limit on
long context appears to be server-enforced. The client reacts to a 429 that contains `"Usage credits are
required for long context"` (`Dge()` `450901`). It then latches `oUo(!0)` and fires
`tengu_1m_credits_clamp_activated` (`450240`), and `fRo()` (`126910`) clamps the window to `TG = 200000`.
The clamp event exists in 2.1.197 too.

### Model-access summary

| Plan | Default model | 1M default (`lq`) | Fast mode | Credits-gated families |
|---|---|---|---|---|
| API key, firstParty / anthropicAws / anthropicGoogleCloud / gateway | **Opus** (Opus 5.5; Opus 4.7 on gateway per catalog alias) | Yes (firstParty) | firstParty only; "purchase credits" copy if `free` | `pay_per_request` (`QK()`) |
| Bedrock / Vertex | **Opus** 5.5 (NEW) unless `qS()` | No (non-1P) | No | `pay_per_request` |
| Consumer OAuth, plan `null` | Sonnet (catalog alias: Sonnet 5.5 on firstParty) | No | "requires a paid subscription" | per `_rn()` |
| Pro | **Opus** (NEW) unless `qS()` | **No** | if credits | per `_rn()`; Fable always gated |
| Max | Opus | Yes | if credits | per `_rn()` |
| Team | **Opus** (NEW; 2.1.197: Team-5x only) unless `qS()` | Yes | if credits | per `_rn()` |
| Enterprise | **Opus** (NEW; 2.1.197: usage-based only) unless `qS()` | Yes | if credits | `admin_billed` (non-usage-based) / `pay_per_request` (usage-based) |

Managed `availableModels` / `enforceAvailableModels` still constrain everything (`Fc()` `125693`).

## Plan-mode agent counts (carried; label corrected)

The 2.1.197 doc called `Sfc()` "Agent Teams teammate limits". In 2.1.300 the same logic is `Dqn()`
(`584743`), and its only prompt consumer is the plan-mode instructions `zKn()` (`588437`). There it fills
`"You can launch up to ${e} agent(s) in parallel"` for the Phase-2 Plan agents (`588461`). `Lqn()`
(`584753`) fills the Phase-1 Explore count (`588446`). The other call sites (`1513170`, `1513188`) are an
unrelated chunk-local `Dqn`/`Lqn`.

```js
if (CLAUDE_CODE_PLAN_V2_AGENT_COUNT in 1..10) return it;
if (plan === "max" && tier === "default_claude_max_20x") return 3;
if (plan === "enterprise" || plan === "team") return 3;
return 1;
```

| Plan | Plan agents | Explore agents |
|---|---|---|
| Max 20x / Team / Enterprise | 3 | 3 |
| Pro / Max (non-20x) / API / free | 1 | 3 |

Overrides: `CLAUDE_CODE_PLAN_V2_AGENT_COUNT`, `CLAUDE_CODE_PLAN_V2_EXPLORE_AGENT_COUNT` (1–10).

Other Pro-only prompt and workflow shaping:
- The Agent tool prompt adds `"**Do not spawn agents unless the user asks.** … it's the expensive path on
  this plan."` for Pro (`553163`). This is carried from `2.1.197:420576`.
- Workflows are `defaultOn: Rr() !== "pro"` (`162200`). Carried from `2.1.197:146651`.
- **NEW:** `lfe()` (`162156`) gives the workflow size guideline: Pro `"small"`, all others `"medium"`
  (`162070`–`162071`). It feeds `workflowSizeGuideline` (`966821`, `1449111`). The key occurs 0 times in
  2.1.197.

## Rate-Limit Tiers & Usage Credits

### Rate-limit types and labels (`Eie`, `183066`)

| `rateLimitType` | Label | Notes |
|---|---|---|
| `five_hour` | "session limit" | |
| `seven_day` | "weekly limit" | |
| `seven_day_opus` | "Opus limit" | |
| `seven_day_sonnet` | "Sonnet limit", or "weekly limit" for Pro/Enterprise (`Arn()` `183338`) | as 2.1.197 |
| `seven_day_overage_included` | **"Fable limit"** | **CHANGED** from `"Fable 5 limit"` (`2.1.197:232868`) |
| `overage` | "usage credit limit" / "usage" when `pj()` | |

**NEW types** appear in the limit-reset grant schema `ve` (`1204213`): `seven_day_cowork`,
`seven_day_omelette` (0 occurrences in 2.1.197 for both), plus `seven_day_oauth_apps` (present in 2.1.197).
The header-key map `Tt` (`183422`+) abbreviates `seven_day_overage_included` as `7d_oi`.

Tier ids seen in code: `default_claude_max_20x`, `default_claude_max_5x`, `enterprise_usage_based`
(seat), `default_claude_zero`.

### NEW: overage scopes and channel/group budgets

`nh()` (`184317`) parses the **NEW** header `anthropic-ratelimit-unified-overage-scope` (0 in 2.1.197) into
`service` / `channel` / `group_pool`. `bS()` (`183137`) uses it:
- `group_pool` → `"You've hit your team's shared budget"` with a raise-it-at-admin link (`183155`–`183159`).
- `channel` + spend cap → `"You've hit your channel's monthly spend limit · an org owner or channel manager
  can raise it in the channel's Claude settings"` (`183052`–`183056`, `183168`).
- `org_spend_cap_reached` on Team/Enterprise now reads `"individual spend limit"` (`zm`, `183052`;
  `org_level_disabled_until` keeps `"org's monthly spend limit"`). Without billing access the same
  `zm` copy is used. `mS = "individual usage limit"` is defined alongside; its consumers were not traced.

All of these strings count 0 in 2.1.197. The same scopes drive `hHo()` (`450862`), the error copy for a
credits-gated model.

### `overageDisabledReason` enum (unchanged set)
`out_of_credits`, `org_level_disabled`, `org_level_disabled_until`, `org_service_level_disabled`,
`org_spend_cap_reached`, `seat_tier_level_disabled`, `seat_tier_zero_credit_limit`,
`member_level_disabled`, `member_zero_credit_limit`, `group_zero_credit_limit`,
`overage_not_provisioned`, `no_limits_configured` (`183185`–`183198`, `121285`+, `450889`–`450896`).

### Per-plan runway text (`oko()`, `183257`)
- Team/Enterprise: `"Run /usage-credits to turn on extra usage for your org"` (billing access) or `"…to
  ask your admin for more"`. When usage credits are on and the limit is `overage`, the copy is
  `"Run /usage-credits to raise the cap"`.
- Max 20x: `"/usage-credits to keep using Claude Code"` if usage credits are off and `fI()`.
- Pro/Max on `five_hour` with usage credits off and `ffe()`: `"/upgrade to keep using Claude Code"`
  (`183270`).
- `JIs()` (`183287`), Pro + `seven_day`: Fable → `"try /model opus · more runway"`; Opus → `"try /model
  sonnet · ~2× runway"`; high/xhigh/max effort → `"try /effort medium"`. Carried from 2.1.197.

### NEW: tier-scaled near-limit checkpoint (`tengu_vellum_anchor`)

`US(tier)` (`183845`) returns the five-hour utilisation threshold:

| Tier | Threshold |
|---|---|
| `default_claude_max_20x` | 0.9975 |
| `default_claude_max_5x` | 0.99 |
| other | 0.95 (`LS`) |

At or above it (`184047`), the limiter arms a "near-limit wrap-up" hint, unless overage is
`allowed`/`allowed_warning`. With `k("tengu_vellum_anchor", !1)` on (`677775`), the next turn injects
`"[Usage limit approaching. Checkpoint now: finish the current step, then list up to 3 short bullets…]"`
(`aOs` `183840`), shows `"Approaching your 5-hour usage limit — Claude will wrap up the current step."`
(`lOs`), and calls `performRateLimitCheckpoint({trigger:"near_limit"})`. A sibling "grace window" text is
`iOs` (`183838`). The flag also appends `" · progress saved"` to the limit message (`qo()` `183058`,
`183187`). The policy key `allow_local_checkpoint_commit` ("Usage-limit checkpoints", denied under
HIPAA and ZDR, `159894`) gates the checkpoint commit (`1085717`). `tengu_vellum_anchor`,
`0.9975` and `"Checkpoint now"` each occur 0 times in 2.1.197.

### `/usage-credits` (CHANGED)
`w8` / `FVe` (`476432`/`476441`): description is now `"Configure usage credits or request them from your
admin when you hit a limit"` (was `"Configure usage credits to keep working when you hit a limit"`).
`isEnabled: () => fI() && !we()` (interactive) or `fI() && we()` (non-interactive). `/extra-usage`
remains a hidden alias, `"Renamed to /usage-credits"` (`476452`–`476470`). Links: `nX =
https://claude.ai/settings/usage?from=cc_cli_limit_message` and `_G =
https://claude.ai/admin-settings/usage` (`117669`–`117670`).

### `/rate-limit-options` (CHANGED: now visible)
`M6o` (`476478`): description `"Manage usage limits and upgrade options"` (was `"Show options when rate
limit is reached"`). `isEnabled: () => kt() || !1`. The **`isHidden: !0` flag was dropped**
(`2.1.197` had it). The menu component (`Mn`, `1697247`, module 2084 `chunk-4xs63za4.js`) assembles:
- `extra-usage`: `"Ask your admin for more usage"` / `"Add funds to continue with …"` / `"Switch to …"`
  (`1697385`–`1697399`), shown only when `upgradePaths` contains `overage` (`nWt(L)`).
- `upgrade` → `"Upgrade your plan"` if `upgradePaths` contains `upgrade_plan` and `/upgrade` is enabled. With
  no `upgradePaths`, it shows when the user is neither Max-20x nor team/enterprise (`1697402`).
- `cancel` (`"Stop and wait for limit to reset"`), **NEW** `auto-resume` / `cancel-auto-resume` (`"Wait here,
  then continue automatically …"`; `"continue automatically"` occurs 0 times in 2.1.197).
- **NEW** `cedar-ember`, `juniper-tide` and `low-priority` entries (next section).
- `tengu_jade_anvil_4` (`1697271`) still reorders. `tengu_pewter_summit` (`tWt`, `1203886`) still adds the
  spend-limit balance nudge for `org_level_disabled_until` (`1697323`).
  **`tengu_coral_beacon` (Team upsell) is REMOVED** (0 occurrences in 2.1.300).

### NEW: Low-priority continuation (`/low-priority`, `tengu_toasty_breeze`)

- Command `I6o` (`476488`), `name: fve` = `"low-priority"` (`177349`): `"Continue now at lower priority
  after reaching your session limit; run again to stop"`. `isEnabled: () => kt() && (iL() || Ept())`,
  hidden. Its name is an identifier, so `_facts.md` §1.6 does not count it.
- Gate `Ept()` (`177366`) is `k("tengu_toasty_breeze", {}).enabled === !0`. The flag object also supplies
  copy and `cooloffMinutes` (clamped 0–1440, default 10, `177391`–`177395`).
- Eligibility: `Xvt()` (`934499`) requires `kt()`, `billingType !== "usage_based"`, `Aa()` (firstParty),
  an interactive session, not remote mode and not `$t()`. `kVe(limits)` (`934503`) adds
  `rateLimitType === "five_hour"`.
- The server arms the offer through **NEW** headers `anthropic-ratelimit-unified-slow-offer`
  (`treatment`|`control`), `-slow-status` (`active`/`not_needed`/`slot_busy`/`weekly_limit`/
  `budget_exhausted`/`ineligible`/`off`), `-slow-retry-after`, `-slow-max-wait`,
  `-slow-budget-utilization` and `-slow-budget-reset` (`177296`–`177337`). None of them occur in 2.1.197.
  `EVe()` (`934618`) offers only on `treatment`. `lXo()` logs `tengu_lowpri_offer_capable` for either arm;
  `tengu_lowpri_offer_withheld` (`934652`) fires for a **`treatment`** arm suppressed by the cool-off
  (`TBe()` set, `reason: "cooloff"`), not for `control`.
- While active (`iL()` `177442`), requests carry **`anthropic-usage-limit: slow`** (`wpt`/`PCr`,
  `177294`; set at `182423` and `529644`). The header name itself is **not** new: 2.1.197 already sent
  `anthropic-usage-limit: extended` behind `tengu_lantern_spool` (`2.1.197:595982`), and 2.1.300 still
  does (`529645`). The `slow` value is NEW. Copy: `"/low-priority to continue now at lower priority · uses
  your weekly limit"`.
- **Inference (tentative):** this trades the five-hour session wall for slower, capacity-dependent
  service that is charged against the weekly limit.

### NEW: Limit resets (`/limit-reset`, two programs)

Command `L6o` (`476636`), `name: R7` = `"limit-reset"` (`476498`), hidden,
`isEnabled: () => kt() && (oRe() || rue())` (`476642`). The two programs both claim through **NEW**
`POST /api/organizations/{org}/reset_rate_limits` (0 in 2.1.197), module 1526 `chunk-yyhf18t7.js`:

| Program | Flag | Scope | Claim | Copy |
|---|---|---|---|---|
| `cedar_ember` | `tengu_cedar_ember` (`476499`, `rue()` `476525`) | grant-based; any of `five_hour`, `seven_day`, `seven_day_overage_included`, `seven_day_opus`, `seven_day_sonnet` (`SEn()` `934508`) | `He()` `1204351`, body `{program:"cedar_ember", grant_id, request_id}` | "Use your reset now ({left} left, until {date})" (`476501`) |
| `juniper_tide` | `tengu_nifty_lemur` (`476588`, `oRe()` `476602`) | `five_hour` only (`kVe`), once a week | `cn()` `1205598`, body `{program:"juniper_tide"}` | "Reset your session limit now … uses weekly limit · 1/week" (`476591`) |

Status is read from `/api/oauth/usage?cedar_ember=1&skip_spend=1` and `?at_wall=1&skip_spend=1`
(`182905`–`182908`). The status response (`$n`, `1204248`; `event_props` at `1204257`) carries an optional `event_props` object
(schema `Dn`, `1204216`–`1204223`). Its fields look like the server's cohort/eligibility dimensions, but
the key name suggests analytics properties; reading them as eligibility rules is an **inference**. Each
enum also accepts `unknown` via `.catch("unknown")`. Cedar has:

```
surface: claude_ai | claude_code_cli
tier: claude_pro | claude_max_5x | claude_max_20x | claude_team
tenure_bucket: under_14 | 14-29 | 30-89 | 90-364 | 365+
billing_path: stripe | apple | google_play | other
billing_period: monthly | annual
extra_usage_state: not_configured | disabled | enabled
```

Juniper (`1205519`–`1205525`) has the same fields without `claude_team`. Cedar ineligibility reasons
(`St`, `1204214`) are `config_off, tier, seat, mobile, surface, cli_version, no_grant, tenure,
other_experiment, unavailable, unknown`. Claim results are `reset, already_used, not_limited, cooldown,
ineligible, unavailable` (`1204260`).

## Upsell Mechanics

| Mechanism | Symbol / flag | Behaviour |
|---|---|---|
| `/upgrade` | `A6o` (`476421`) | `"Upgrade to Max for higher rate limits and more Opus"`, `availability:["claude-ai"]`, `isEnabled: ffe` |
| Upgrade availability | `ffe()` (`176932`) | `!_pt() && !DISABLE_UPGRADE_COMMAND && Rr() !== "enterprise"` (unchanged) |
| Upgrade URL (CHANGED) | `s(campaign)` (`1696196`) | `https://claude.ai/upgrade/max?utm_source=claude_code&utm_medium=cli&utm_campaign=…`, with campaigns `upgrade_command` (`1696199`), `rate_limit_options_menu` (`1697660`) and `pro_trial_expired_dialog` (`1711648`). 2.1.197 used a bare `https://claude.ai/upgrade/max` (`2.1.197:560247`). |
| Already-top-tier guard | `cGe()` (`1696201`) | Max 20x gets `"You're already on the highest Max subscription plan…"` and is pointed at `/usage-credits` (`1696215`) |
| Upsell kill switch | `_pt()` = `tengu_idle_amber_finch` (`176924`), `YPs()` = `tengu_quiet_slate_wren` (`176928`) | Suppress `/upgrade` and the "use your existing Claude Max/Pro plan" notice (`h2o()` `1230239`) |
| C4E slash upsell | `tengu_c4e_slash_upsell` (`476098`) | API-key users (`kit()` `476092` = `Si() && O9e()`): gated commands become `"/X is available with Claude for Enterprise — ask your admin about migrating from API-key access."` (`476125`) |
| **NEW** CC→CE migrate notice | `tengu_velvet_harbor_owl` (`1230299`, default `"off"`) | Cohort `has_ce`: headline `"Get more out of Claude Code on Claude Enterprise"` → `claude.com/enterprise`. Shown only to org roles admin/billing/owner/primary_owner (`sy()` `1230321`). Event `tengu_cc_ce_migrate_notice_shown`. |
| **NEW** Startup credit promo | `tengu_swift_lynx` (`335571`), hidden cmd `claim-credit` (`tws` `335612`, cmd `N6o` `476646`) | `isEnabled: () => kt() && !bie() && lFn() !== null`. The promo is policy-gated by `allow_promo_offers` (`re()` `936176`). Events `tengu_promo_exposure`, `tengu_promo_banner_clicked`, … (module 1019 `chunk-sb4n0rem.js`) |
| Desktop upsell | `tengu_desktop_upsell` via `KC()` dynamic config (`1541087`) | Carried |
| Pro Opus cost warning | `tengu_gypsum_kite` (`178430`) | Carried |
| Spend-limit nudge | `tengu_pewter_summit` (`1203886`) | Carried |
| Max-only tip | `console-api-key` tip (`1541777`) | `kt() && mmt()` after 10 startups: `"Build your AI product with Claude API…"` |
| `/passes` | `kVe` cmd (`475754`) | `"Share a free week of Claude Code with friends and earn usage credits"` when a referrer reward is cached (`o5e()` `335044`). Carried. |
| **REMOVED** | `tengu_coral_beacon`, `tengu_cobalt_heron`, `tengu_surreal_dali` | 0 occurrences in 2.1.300 |

## Trial Flows (Pro trial) — carried

Module 1364 `chunk-jje3q6gk.js`:
- `vbt()` (`1067538`) is the trial state, Pro only (`Rr() !== "pro"` → ineligible). Eligibility is
  `ccOnboardingFlags.e10 === !0` (`1067543`). The dead mock `_Co()` is checked first.
- `z1r()` (`1067546`): `POST /api/oauth/organizations/:orgUUID/claude_code/pro_trial`
  (auth `teleport-org`, `1067554`). Events `tengu_pro_trial_start_pressed/ok/error` (`1622266`–`1622273`).
- `G1r()` (`1067570`) is the badge: `"Trial: N day(s) left"` / `"Usage credits"` (expired).
- `S2o()` (`1067565`) means expired with `cachedExtraUsageDisabledReason !== null`, so the expired dialog
  auto-opens.
- `pro-trial-expired` (`P6o`, `476471`, hidden): `"Upgrade to Max"` / `"Add funds to continue with usage
  credits"` (`1711621`/`1711624`), event `tengu_pro_trial_expired_choice {chose_upgrade}` (`1711646`).
- CHANGED: the named `PRO_TRIAL_FALLBACK_DAYS` constant is gone (`PRO_TRIAL` occurs 0 times). A bare
  `u = 14` (`1067528`) survives and is used only on the dead mock path (`1067549`).

## Feature Availability Matrix

| Feature | API key | Pro | Max | Team | Enterprise |
|---|---|---|---|---|---|
| Opus default | **Yes** (1P-family planes) | **Yes (NEW)** unless `qS()` | Yes | **Yes (NEW)** unless `qS()` | **Yes (NEW)** unless `qS()` |
| 1M default (`lq`) | Yes on firstParty | **No** | Yes | Yes | Yes |
| Fast mode | firstParty; "purchase credits" if free | if credits | if credits | if credits | if credits |
| Credits-gated models (`_rn`) | `pay_per_request` | consent + credits | consent + credits | consent + credits | `admin_billed` / `pay_per_request` |
| Plan agents (plan mode) | 1 | 1 | 3 *(20x only)* | 3 | 3 |
| Workflow size guideline | medium | **small (NEW)** | medium | medium | medium |
| `/upgrade` | No (`availability: claude-ai`) | Yes | Yes (20x guard) | Yes | **Hidden** |
| `/usage-credits` | if `KE` billing | if `KE` billing | if `KE` billing | Yes/admin | Yes/admin |
| `/low-priority` (NEW) | No | flag + offer | flag + offer | flag + offer (non-usage-based) | non-usage-based only |
| `/limit-reset` (NEW) | No | `tier` schema includes | 5x/20x in schema | cedar only | not in tier schema |
| `/privacy-settings` (`c5`) | No | Yes | Yes | No | No |
| Startup promo / `claim-credit` | No | Yes | Yes | Yes | **No** (`bie()`) |
| CC→CE migrate notice | n/a | org admins in cohort | same | same | same |

The `/limit-reset` row is **tentative**. Eligibility is decided by the server, and the client only
parses the `tier` enum.

## Organization Policies (CHANGED: declarative registry)

2.1.197 had a hand-written taint table `UFd` and a user-visible set `FFd`. 2.1.300 replaces both with a
**registry `gTo` of 36 policy keys** (`159771`–`160050`). Each entry declares:
- `deniedUnder`: the compliance taints that deny it
- `hardBlockUnder`
- `onCacheMiss`: `allow` / `deny` / `hold`
- `onFailOpenVerdict`, `serverPopulated` and `transcriptScan`
- a `label`, a `verb`
- a **`requirementId` (`HIPAA-R1` … `HIPAA-R72`)**

`requirementId` and `deniedUnder` occur 0 times in 2.1.197.

- All 36 keys deny under `hipaa`. **Nine** also deny under `zdr`: product_feedback, memory_sync,
  cobalt_plinth (Artifacts), error_reporting, send_file, heap_dump, local_checkpoint_commit, mycelium (peer
  messaging) and container_result_files.
- `hardBlockUnder: ["hipaa"]` applies to memory_sync, projects_tool, team_onboarding and mycelium.
- `on(name)` (`160130`) resolves the policy in this order: transcript-scan keys → no cached policy
  (`onCacheMiss` / `deny` / `hold`, HIPAA hints) → `non()` web-fetch/design-sync/channels principal
  checks (`160088`–`160119`) → `F8e()` (`160169`), which merges server restrictions with compliance taints.
  It is registered as `isPolicyAllowed` (`160196`).
- `Cf(key, label, verb)` (`160283`) returns the denial string by kind: `route_missing`, `cache_miss`,
  `latched`, `org_denied` (2.1.197 had a single `DW()` string).
- Plan-relevant entries: `allow_promo_offers` ("Promotional offers", `160022`),
  `allow_local_checkpoint_commit` ("Usage-limit checkpoints", `159894`), `allow_remote_sessions` (Cloud
  sessions, `onCacheMiss: "deny"`, `159827`) and `allow_remote_control` (`159835`).
- Dropped from the policy surface vs 2.1.197: `allow_desktop_handoff`, `allow_context_tips`,
  `allow_team_discovery` and `allow_settings_sync` (each occurs 0 times in 2.1.300).
  `allow_voice_mode` and `allow_quick_web_setup` are still read (`963004`, `368526`) but are outside `gTo`.

Cloud sessions remain **not plan-gated**. They are gated on OAuth/console-profile + `on("allow_remote_sessions")`
(for example `457735`, `472847`, `475327`), as in 2.1.197.

## What's New vs 2.1.197

1. **Opus becomes the default for Pro, Team and Enterprise** (`qVn()` `126308`), and for Bedrock/Vertex
   (`av()` `125677`–`125685`), unless the user pinned Sonnet alone via env (`qS()` `124729`). The default
   Opus comes from the bundled catalog alias `aliases.opus` (`21186`): `claude-opus-5-5` on firstParty,
   Bedrock and Vertex (Foundry `claude-opus-4-6`, gateway `claude-opus-4-7`).
2. **Usage-credit billing is now per-model and per-family.** `_rn()` (`177159`) returns seven states,
   `HVn` lists Fable/Haiku/Mythos/Opus/Sonnet (`124087`), and NEW flag `tengu_calm_seal` (`126445`) opts
   further families into credits. `tengu_saffron_lattice` gains `perModel` (`176935`), and consent is
   stored per org/account in NEW `usageCreditsOnlyModelConsent`.
3. **Two NEW limit-relief products.** `/low-priority` (`tengu_toasty_breeze`, header
   `anthropic-usage-limit: slow`, `-slow-*` offer headers) and `/limit-reset` (`tengu_cedar_ember` grants
   and `tengu_nifty_lemur` weekly session reset) both use `POST /api/organizations/{org}/reset_rate_limits`.
4. **NEW overage scopes** `channel` / `group_pool` / `service` (header
   `anthropic-ratelimit-unified-overage-scope`), with channel-spend and team-shared-budget copy.
5. **NEW tier-scaled near-limit checkpoint**: thresholds 0.95 / 0.99 (Max 5x) / 0.9975 (Max 20x), behind
   `tengu_vellum_anchor` and the policy `allow_local_checkpoint_commit`.
6. **Plan identity is wider.** Server `plan_display_name`, profile `fullName`, a bg-dispatcher plan
   handoff (`CLAUDE_BG_DISPATCHER_*`), async per-credential plan predicates, new scopes `user:office` /
   `user:ccr_inference`, and three new billing types (`stripe_subscription_enterprise_self_serve`,
   `aws_marketplace`, `c4e_consumption_trial`).
7. **The 1M default consults the model catalog** (`Wa()` `126863`: `never`/`native`/`optIn`). Opus 5.5 is
   native 1M in the bundled catalog.
8. **`/rate-limit-options` is no longer hidden** and gains auto-resume and the cedar/juniper/low-priority
   entries. `/usage-credits` is reworded toward "request them from your admin".
9. **Upsell churn.** The upgrade URL gains UTM campaign tags. NEW: CC→CE migrate notice
   (`tengu_velvet_harbor_owl`) and a startup credit promo plus hidden `claim-credit` (`tengu_swift_lynx`).
   REMOVED: `tengu_coral_beacon` (Team upsell), `tengu_cobalt_heron`, `tengu_surreal_dali`, and the whole
   context-tips nudge engine (`high-effort-low-yield`, `opus-on-pro-near-limit` and
   `pro-compact-threshold` each occur 0 times).
10. **The org-policy layer is a declarative registry** of 36 keys with HIPAA requirement IDs. Nine keys
    deny under ZDR.
11. **Unchanged:** the plan enum, the max/pro/team/enterprise predicates, the plan-mode agent counts,
    Fast-mode reason copy, the Pro trial state machine, `/privacy-settings` scope, `ffe()`, and dead
    plan/tier/trial mocks.

For scale (`_facts.md`): 2.1.300 has **704** feature flags (2.1.197 recount 251), **1,944** telemetry
events (1,181), and **106** slash commands (96). `/low-priority`, `/limit-reset` and `claim-credit` are
identifier-named, so the 106 does not include them.

## Uncertainties

- **Server-side enforcement.** The client only labels and routes: Opus-for-Pro metering, `_rn()` states,
  long-context credits, and low-priority throughput are all decided by the API. In particular, whether Pro
  on the native-1M Opus 5.5 default actually gets a 1M window, or is clamped to 200K by the 429 path, cannot
  be determined from the binary.
- **Flag values.** `tengu_calm_seal` (default `null`), `tengu_saffron_lattice` (`{}`),
  `tengu_saffron_ladder` (`!1`), `tengu_toasty_breeze` (`{}`), `tengu_cedar_ember` (`{}`),
  `tengu_nifty_lemur` (`{}`), `tengu_vellum_anchor` (`!1`), `tengu_velvet_harbor_owl` (`"off"`) and
  `tengu_swift_lynx` (`null`) show only code defaults. Rollout values live in GrowthBook.
- **Mythos.** `"Mythos"` is in `HVn`, but whether any plan can select a Mythos model is outside this doc.
  The bundled catalog gives `claude-mythos-5` first-party-only provider ids (`21114`+).
- **Low-priority mechanics.** The exact server meaning of `anthropic-usage-limit: slow` and the "uses your
  weekly limit" accounting are inferred from UI copy (`177350`–`177356`).
- **Limit-reset eligibility.** `tier`, `tenure_bucket`, `billing_path`, `billing_period` and
  `extra_usage_state` are only parsed by the client. The server applies the rules.
- **`ya()` 200K clamp.** The helper at `750855` returns `Math.min(l8(…), 200000)` unless `QK()` or
  `cachedExtraUsageDisabledReason === null`. The meaning of `l8()` (`448923`) was not traced, so its effect
  is unverified.
- **The `tengu_saffron_ladder` UI effect** was not traced.
