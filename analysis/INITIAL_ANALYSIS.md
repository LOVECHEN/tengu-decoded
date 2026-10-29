# Initial Content Analysis

Baseline inspected: upstream `main` at
`068b7a24325bbf92af5f024bdb9525a654251155`, observed and archived on
2026-10-29 as
`archive/heads/main/20261029T121832Z-068b7a24325b`.

## What the repository contains

This is a versioned reverse-engineering corpus for four Linux x86-64 Claude
Code builds: 2.1.32, 2.1.169, 2.1.197, and 2.1.300. It contains three distinct
evidence layers:

1. Extracted primary material: raw strings, carved or reconstructed JavaScript,
   Bun module manifests, embedded assets, and native addons.
2. Structured indexes: YAML inventories for flags, telemetry events, tools,
   commands, models, endpoints, environment variables, security checks, and
   identity flows.
3. Interpretive reports: per-version technical analyses and cross-version
   comparisons.

The strongest evidence is the extracted source and manifests. The prose reports
are useful indexes but should be treated as claims to verify against those
artifacts, especially where they label an inference as tentative.

## Corpus and provenance

The repository has 527 tracked paths under `versions/`. The largest primary
artifacts are:

| Artifact | Role | Locally verified SHA-256 |
|---|---|---|
| `versions/2.1.169/bundle/cli.min.js` | 16.5 MB carved Bun CommonJS source | `640946f13b684166b29175d18ce9aad0e5d911926078eb53f8b297f4a4b2fe7c` |
| `versions/2.1.197/bundle/cli.min.js` | 18.1 MB carved Bun CommonJS source | `2d5d978b89c834e54bd75fae94dbb4bc4ef222c895fac3f1df56672aea77153a` |
| `versions/2.1.300/bundle/cli.min.js` | 46.3 MB concatenation of 2,401 ESM modules | `cb3807a756a304ce64e95fb9755b264d021c364a399b8e401ea8a5b22f137a31` |

The 2.1.300 checksum matches the value published in its bundle README. Its
manifest describes 2,651 records: 2,401 application modules plus separately
stored skills, prompt text, browser libraries, fonts, native addons, and other
assets. The original 266,972,344-byte ELF is not committed, so byte-for-byte
re-extraction still requires obtaining the named upstream binary independently.

## Main technical findings

### Packaging and extension surface

Between 2.1.197 and 2.1.300 the packaged application changed from one Bun
CommonJS bundle to a code-split ESM graph. The corpus identifies 2,395 lazy
chunks, a small entry loader, 1,398 dynamic imports, and embedded plugin and
skill assets. This is more than a packaging change: it exposes a hooks worker,
plugin UI primitives, self-hosted runner support, and more code paths that are
loaded only when gated features are active.

### Remote configuration

The reports count 704 feature flags in 2.1.300, up from a same-method recount of
251 in 2.1.197. The resolver records value provenance and supports session-pinned
reads. A large fraction of new flags default on, so many act as remote kill
switches rather than dormant opt-ins. Any behavioral reconstruction therefore
needs both the compiled default and the server-delivered value source.

### Identity and device state

The 2.1.300 analysis identifies four persisted random installation identifiers
and a per-account ECDSA P-256 device key. The identifiers are CSPRNG-generated,
not hardware-derived. Their outbound behavior differs: `userID` is broadly used
in first-party and optional telemetry, `machineID` is truncated in error data,
`summonSidKey` stays local as an HMAC key, and `remoteControlMachineId` is sent
raw to the remote-control bridge. The device public key is registered with a
remote-device endpoint.

### Telemetry

The structured dataset lists 1,944 event names for 2.1.300. The dispatch layer
has a 1,000-entry pre-sink queue with drop-oldest behavior, first-party event
logging, an allow-listed Datadog mirror, optional OpenTelemetry, and plugin
telemetry. The reports state that the embedded Datadog client token remained
unchanged from 2.1.197. Payload analysis should distinguish event-name presence
from actual runtime reachability and account for provider-plane and privacy-mode
gates.

### Security and execution control

The earlier Haiku-based Bash prefix classifier is reported removed in 2.1.300;
prefix extraction is deterministic, while model classification remains in the
separate auto-mode permission path. The corpus also documents sandbox backends,
read confinement, credential masking, destructive-command warnings, secret
redaction, server-side arbitration, and a plugin test toolkit. These mechanisms
are distributed across gates and policy inputs, so no single function describes
the effective permission boundary.

### Backend and model surface

The 2.1.300 indexes enumerate 347 API path templates and new surfaces for
self-hosted runners, organization administration, tunnels, dreams, remote
workers, and frame artifacts. They also identify a new
`anthropicGoogleCloud` provider plane and a signed remote model catalog capable
of overriding compiled model defaults. The compiled catalog names a Claude 5.5
generation and records pricing and capability metadata.

## Quality assessment

The corpus is unusually reproducible for application reverse engineering: it
ships source-scale extracts, structured inventories, extraction scripts, hashes,
symbol remaps, and explicit uncertainty sections. The 2.1.300 reports also
correct preliminary counts and distinguish published 2.1.197 counts from
same-method recounts.

Important limitations remain:

- The analyzed platform is Linux x86-64; macOS and Windows native paths may
  differ.
- Minified identifiers are build-specific and local names can be reused across
  chunks.
- Static presence does not establish reachability, server configuration, or
  production rollout.
- The repository omits the original ELF binaries and the generated 2.1.300
  beautified file, although it includes deterministic extraction and
  regeneration instructions.
- Counts use different corpora in some places. For example, the 2.1.300 headline
  environment count includes decompressed text assets, while JS-only counts are
  lower.

## Follow-up priorities

Future observations should prioritize semantic diffs in the feature resolver,
identifier transmission sites, telemetry sinks and opt-outs, permission and
sandbox gates, provider routing, tool schemas, model catalog verification, and
new embedded assets. Generated update reports under `analysis/upstream-updates/`
provide the changed path and commit set; high-impact changes should then be
checked directly against extracted source rather than summarized only from the
upstream prose.
