# RNFB main compatibility matrix (ephemeral) — restructured

**Status:** DONE — Matrix C1+C2+C3 + E1+E2+E3 GREEN; **L1-meta** committed.
**Goal:** Verify `invertase/react-native-firebase` **origin/main** (+ packed worktree fixes) boots via this repo’s self-contained demos on currently supported React Native CLI and Expo (current + previous 2 each).
**Demo repo:** `/Users/mike/work/invertase/rnfbdemo`
**RNFB worktree (all upstream product fixes):** `/Users/mike/work/invertase/RNFB-worktrees/v26-validation-fixes` · branch `v26-validation-fixes` ← `origin/main` @ `2aec61fff`
**Primary RNFB clone:** admin only (fetch / worktree add|remove|prune) — do not implement there
**Local packages dir:** `~/packages` via worktree `.github/workflows/scripts/create_npm_packages.sh` (re-pack after each upstream fix before matrix)

**Constraint:** `make-demo.sh` / `make-expo-demo.sh` must stay **docs-faithful** (step-by-step what RNFB docs say). Temporary H0 workarounds in the demo (hand-edited ResultT, DerivedData header inject, `CLANG_ENABLE_EXPLICIT_MODULES=NO`, AppDelegate import skips) are **not** the durable fix — either fix upstream or prove the docs need a documented extra step.

### Matrix pass bar (blocking — corrected 2026-07-27)

`make-demo.sh` / `make-expo-demo.sh` only automate **build + install + process start** (`MAKE_DEMO_EXIT=0`, `BUILD SUCCEEDED` / `BUILD SUCCESSFUL`). That is **necessary but not sufficient**.

There is a second, previously manual, verification step: after Debug launch, confirm the **single-page demo** finished startup init and rendered without JS failure. **Device logs + Metro logs are the shared proxy** for that (until/unless we automate it into the scripts).

#### Layer A — script / native (automated today)

- Exit 0 through scripted iOS (both RNCore modes on CLI) + Catalyst + Android as applicable.
- No native compile/link failure.

#### Layer B — runtime-clean (required for cell green; reviewer verifies)

After **Debug** `run-ios` / `run-android` (Metro-served JS):

1. **Metro log** (e.g. `/tmp/rnfbdemo-metro.log` or the packager tee the script/agent used): scan for fatal JS — `TypeError`, `RedBox`, unhandled rejections from demo bootstrap. Benign RN warnings alone do not fail the cell.
2. **Device logs** — Android: `adb logcat` (`ReactNativeJS`); iOS: simulator/`os_log` / Xcode console equivalent for JS. Same fatal patterns.
3. **Startup init succeeded** — demo `App.tsx` path should show expected progress logs, at minimum:
   - AppCheck: `initializating AppCheck...` followed by `AppCheck is initialized.` (not `TypeError: undefined is not a function`)
   - Messaging permission / registration: handled or bounded timeout/reject — not an indefinite hang
4. **UI proxy** — single page lists working modules; `appCheck()` appears after successful init (or document why not).

**Release** builds (no Metro): Layer B uses **device logs only**.

**Evidence package for C\*/E\* review** must include Layer A exit/log **and** Layer B excerpts (Metro and/or device) showing clean startup — or an explicit user-accepted deferral for a named residual.

**Orchestration rule for C\*/E\*:** each full demo script run is validation/review. Fail Layer A **or** Layer B → reopen `implementation_gate`, implementer, re-review. Never overlap two demo scripts on one host.

### Long-run C\*/E\* dispatch playbook (blocking — added 2026-07-27)

**Canonical instructions live in the script headers** (`make-demo.sh`, `make-expo-demo.sh` — “Success criteria + how agents should run/poll”). This queue section is the session checklist; do not fork a second playbook.

These cells are **long wall-clock** (often ~30–90+ minutes when from-source RNCore / cold pods / dual modes), **not** multi-hour babysitting jobs — but they **will** kill a chatty agent that polls with repeated long `AwaitShell` loops (`[resource_exhausted]`). Treat each cell as a **single shell-owned tee run**.

#### Who runs it

| Step | Subagent | Why |
|------|----------|-----|
| Layer A (`make-demo` / `make-expo-demo`) | **`shell`** only | One process owns the build; minimal tool chatter |
| Layer B (logcat / Metro / sim JS) | Same `shell` agent after exit, or a **fresh short** shell/reviewer | Cheap; do not start until Layer A footer exists |
| Product fix after FAIL | `generalPurpose` implementer | Only after a completed fail with real evidence |

**Do not** dispatch `generalPurpose` to sit through the whole compile with milestone greps + 15‑minute awaits. That pattern caused C1c abort and a torn tee (`…upb_miMAKE_DEMO_EXIT=1`).

#### Exact Layer A pattern (mirror of script header)

```bash
cd /Users/mike/work/invertase/rnfbdemo
# Preflight: AVD up; port 8081 free; keychain unlocked; no other make-demo/xcodebuild
# Optional: unset YARN_CACHE_FOLDER YARN_ENABLE_GLOBAL_CACHE NPM_CONFIG_CACHE
RN_VER=<cell> ./make-demo.sh 2>&1 | tee /tmp/rnfbdemo-<cell>.log
echo MAKE_DEMO_EXIT=${PIPESTATUS[0]} | tee -a /tmp/rnfbdemo-<cell>.log
```

Expo: `./make-expo-demo.sh` → `/tmp/rnfbdemo-E*.log` same `PIPESTATUS` footer (set `EXPO_VER` as the script expects).

Shell tool: `required_permissions: ["all"]`. Prefer **one** Shell invocation that blocks until the script finishes (`block_until_ms` ~2–3h CLI / ~1–2h Expo). If backgrounded, poll **only** for a **standalone** `^MAKE_DEMO_EXIT=` line — sparse checks (minutes apart), not continuous transcript grepping.

#### Freeze / hygiene

- **Never** edit `make-demo.sh` / `make-expo-demo.sh` / sourced helpers while a run is in progress.
- **Never** re-pack `~/packages` mid-run.
- **Never** overlap two demo scripts on one host.
- Kill leftover Metro on **8081** only when no demo is mid-run (or after a proven aborted run).
- Keep TestingAVD (or named AVD) **up through Android**; cold-boot before dispatch if `adb devices` empty.

#### Interpreting completion / aborts

| Log footer | Meaning |
|------------|---------|
| Own line `MAKE_DEMO_EXIT=0` | Layer A complete PASS — proceed Layer B |
| Own line `MAKE_DEMO_EXIT=<nonzero>` | Layer A FAIL — capture first native/JS error; reopen implementer |
| `MAKE_DEMO_EXIT` glued mid-line / no footer / log stopped mid-xcodebuild | **Incomplete** (agent/shell kill) — **not** a product fail; re-dispatch same cell; do not flip gates to failed |

#### Layer B (after Layer A PASS only)

Write `/tmp/rnfbdemo-<cell>-layerb.log` with excerpts proving AppCheck `AppCheck is initialized.` on iOS + Android Debug paths and no bootstrap `TypeError`. Cell green only when A+B both PASS.

#### Orchestrator after return

Update this queue immediately: close gates on green; on incomplete → keep open + note re-dispatch id; on real FAIL → open `implementation_gate`. Then pick next: C1 → C3 → E1 → E2 → E3 (C2 already green). Skip L1-meta until after matrix unless it blocks a cell.

### RNCore dual-path requirement (CLI matrix — blocking)

Each **C\*** cell must pass **both** iOS RNCore integration modes (RN 0.81+):

| Mode | Env | Meaning |
|------|-----|---------|
| **from-source** | `RCT_USE_RN_DEP=0` `RCT_USE_PREBUILT_RNCORE=0` | Build React Native from source (no prebuilt RN core) |
| **prebuilt (default)** | `RCT_USE_RN_DEP=1` `RCT_USE_PREBUILT_RNCORE=1` | Use prebuilt RN core (template/default path) |

`make-demo.sh` must exercise **both** rounds (Debug + Release as already structured). A C\* row is green only when **both** modes succeed **and** the runtime-clean pass bar above is met.

**Expo (E\*):** apply the same dual-path rule **only where** the Expo/RN template surfaces `RCT_USE_PREBUILT_RNCORE`; otherwise document n/a and run the stock Expo path once.

---

## Straight answers (from H0 evidence)

### 1) ResultT — are we incompatible with RN 0.86?

**Yes, as shipped on `origin/main` today, for New Arch / TurboModule builds against RN 0.86’s headers.**

- RN 0.86 `RCTTypedModuleConstants.h` requires codegen `Constants::Builder` to define `using ResultT = Constants;`.
- RN 0.86 `@react-native/codegen` emits that alias (`serializeConstantsStruct.js`).
- RNFB’s **committed** `packages/*/ios/generated/**/*TurboModules.h` were generated with older codegen (repo pins `@react-native/codegen` **0.78.3** / tests RN **0.78.3**) and **lack** `ResultT` on clean `origin/main`.
- H0 hand-patched ResultT into generated headers in the dirty primary clone — **not durable** (codegen wipe / not in `~/packages` until regenerate+pack).

→ **Phase U1** (upstream): align codegen + regenerate `ios/generated` (and Android if needed) so RN 0.86 compiles without hand edits.

### 2) Header inject / explicit modules — complete build failure with documented steps?

**Strongly indicated complete iOS build failure on this host (Xcode 26 + `use_frameworks` + case-insensitive APFS), not a “nice to have.”**

H0 added non-doc steps because modular includes broke:

| Hack | Why it appeared |
|------|-----------------|
| `ensureReactDebugHeadersInReactFramework` | `#include <react/debug/...>` resolves to **React.framework** (module name `react`) instead of **React-debug**; injects symlinks under `React.framework/Headers/debug/` in DerivedData |
| `CLANG_ENABLE_EXPLICIT_MODULES=NO` in Podfile post_install | ccache + explicit modules breakage under Xcode 26 |
| Avoid `import RNFBAppCheck` in Swift AppDelegate | explicit-module dependency issues |

**Unknown until U2 proves it:** whether stock docs (`pod-install` + `run-ios`) fail on a **clean** tree without these hacks on Xcode 26 / RN 0.86. That proof is U2’s first deliverable. Prefer upstream/docs fix over demo-only inject.

→ **Phase U2** (upstream + docs / possible RN interaction).

### 3) Main-queue hang with no effective timeout?

**Yes. Site known; durable fix must be in RNFB messaging.**

- Hang site: `registerDeviceForRemoteMessages` → `RNFBMessagingModule.registerForRemoteNotifications`.
- On ARM64 simulator, APNs registration can stall; existing ~10s `dispatch_after` was on the **main queue**. If main is stalled, the timeout **never fires** → JS promise hangs forever.
- `getMessaging()` itself is fine on correct **25.1.0** packages (L0 fixed the stale 23.8.3 red herring).
- Incomplete patch in dirty primary clone only moved the timer to a global queue but still **rejects on main** — review correctly blocked that as insufficient.
- Demo JS `Promise.race` (15s) **does** bound the hang for matrix survival; that is a belt-and-suspenders demo guard, **not** the library fix.

→ **Phase U3** (upstream messaging). Demo timeout remains **D1** hygiene until U3 ships in tarballs.

### 4) Anything else required to build and run?

| Issue | Blocks build? | Blocks run/matrix? | Where |
|-------|---------------|--------------------|-------|
| ResultT missing | **Yes** (compile) | — | **U1** RNFB |
| react/debug headers + explicit modules | **Yes** (compile) — U2 proved | — | **U2** RNFB/docs — fix drafted |
| Messaging APNs hang | No | **Yes** (indefinite) | **U3** RNFB (+ **D1** demo bound) |
| AppCheck `TypeError: undefined is not a function` | No | Partial (AppCheck path only; app may still launch) | **D2** demo (verify import/API; escalate to RNFB only if package bug) |
| Yarn stale `file:` installs | Was yes (wrong code) | Was yes | **L0** done (demo scripts) |
| Non-TTY Metro | Was yes (Debug redbox) | — | **L0** done |
| H0-DIAG / temporary demo hacks | No | Pollutes docs-faithfulness | **D1** cleanup after U* |

---

## Priority phases (upstream first)

### U1 — ResultT / codegen vs RN 0.86 (RNFB worktree)

**Repo:** `RNFB-worktrees/v26-validation-fixes`  
**Problem:** Committed TurboModule generated headers lack `ResultT`; RN 0.86 typed constants require it → iOS compile failure.  
**Outcomes:** Regenerate with RN-0.86-compatible codegen (bump pin / run `codegen:all` / `codegen:verify`); no hand edits; pack to `~/packages`; prove clean compile of messaging+app (at least) against RN 0.86 without ResultT patches in demo.  
**Validation:** unit-focused → area; OKF change-authoring in worktree.

### U2 — Xcode 26 modular `react/debug` + explicit modules (RNFB / docs)

**Repo:** worktree (+ docs); demo alignment in **D1**  
**Problem:** Docs-faithful iOS build fails on Xcode 26.6 with RNFB 25 TurboModules + `use_frameworks! :static`. Not RN-version-specific.  
**Outcomes:** (1) Repro without H0 hacks — **done**; (2) root cause — **done**; (3) durable fix — **drafted, compile-validated**; (4) docs/demo alignment — **partial** (docs AppCheck section fixed; `make-demo.sh` still uses `import RNFBAppCheck` — fix in D1).

**Durable fix (uncommitted on worktree @ U1+1):**

| File | Change |
|------|--------|
| `packages/storage/RNFBStorage.podspec` | Add `private_header_files` for `ios/RNFBStorage/*.h` + `ios/generated/**/*.h` |
| `packages/messaging/RNFBMessaging.podspec` | Same + `HEADER_SEARCH_PATHS` for generated specs |
| `packages/app-check/RNFBAppCheck.podspec` | `public_header_files` (thin module + providers); `private_header_files` for `ios/generated/**/*.h`; `HEADER_SEARCH_PATHS`; drop `.swift` from `source_files` |
| `packages/app-check/ios/RNFBAppCheck/RNFBAppCheckModule.h` | **Bridging-header safe:** only `@interface` + `sharedInstance`; no TurboModule/C++ imports |
| `packages/app-check/ios/RNFBAppCheck/RNFBAppCheckModule.mm` | Class extension holds `<NativeRNFBTurboAppCheckSpec, RCTInvalidating>` + turbo imports |
| `docs/app-check/usage/index.mdx` | Remove erroneous `import RNFBAppCheck` from 0.77–0.79 section; note bridging header only |

**Why Storage/Messaging were outliers:** 11/14 turbo pods already had `private_header_files`; only **AppCheck, Storage, Messaging** lacked it. Auth/Firestore pattern puts codegen headers in `PrivateHeaders/` so modular `#include <react/debug/...>` does not traverse the public framework module surface.

**Why AppCheck needs header split (not just private headers):** `RNFBAppCheckModule.h` previously `#import "RNFBAppCheckTurboModules.h"` (C++ codegen). Any Swift `import RNFBAppCheck` or bridging header import of that header triggers Clang dep-scan of C++ STL under explicit modules + ccache. Expo config plugin (`packages/app-check/plugin/src/ios/appDelegate.ts`) already documents bridging-header-only integration — `make-demo.sh` and docs 0.77–0.79 section were wrong.

**Validation (2026-07-25, local node_modules patch + pod install):**

| Log | Result |
|-----|--------|
| `/tmp/rnfbdemo-U2-rn86.log` | FAIL @ blocker 2a (AppCheck module scan) |
| `/tmp/rnfbdemo-U2-rn85.log` | FAIL @ same blocker 2a |
| `/tmp/rnfbdemo-U2-clang-explicit-off.log` | FAIL @ blocker 2b (`react/debug/flags.h` in RNFBStorage) |
| `/tmp/rnfbdemo-U2-fix.log` | **Compile past both blockers** — RNFBStorage, RNFBMessaging, RNFBAppCheck, AppDelegate.swift all compile; link failed on unrelated `_RNFBVersionString` (test harness / `CODE_SIGNING_ALLOWED=NO`, not U2) |

**U2 `implementation_gate` close criteria (remaining):**
- [ ] Commit worktree changes (suggested: `fix(ios): private codegen headers and bridging-safe AppCheck module`)
- [ ] `independent-review` on podspec + header split
- [ ] Re-pack `~/packages` (P1 partial) and full `make-demo.sh` iOS compile without H0 hacks
- [ ] D1: update `make-demo.sh` AppCheck integration to bridging header (match Expo plugin + fixed docs), not `import RNFBAppCheck`
- [ ] Spot-check RN 0.85 + 0.86 after pack refresh

**Do NOT:** merge PR #8933 as U2 fix; use `CLANG_ENABLE_EXPLICIT_MODULES=NO` or DerivedData symlink inject as the product fix; change public iOS build docs beyond AppCheck bridging-header correction without full matrix proof.

### U3 — Messaging `registerForRemoteNotifications` timeout (RNFB)

**Repo:** worktree `packages/messaging`  
**Problem:** Native 10s timeout ineffective when main is stalled; JS hangs forever.  
**Outcomes:** Timeout/reject that works even if main is blocked (or alternate design that cannot hang); tests/evidence; pack messaging tgz; prove native and/or JS sees rejection within bound **without** relying on erase-simulator.  
**Validation:** unit/area on messaging; H0 log pattern as regression case.

### D1 — Demo fail-fast + docs-faithfulness cleanup (rnfbdemo)

**After U1–U3 packed:** keep a bounded JS/script timeout around registration; remove H0-DIAG; remove ResultT hand-edits / DerivedData inject / explicit-modules Podfile hacks **unless** U2 promoted them to documented steps; re-pack meta + L0 guard green.

### D2 — AppCheck provider TypeError (rnfbdemo first)

**Problem:** `[H0] AppCheck provider setup failed: TypeError: undefined is not a function` in H0 evidence.  
**Outcomes:** Determine demo import/API misuse vs package bug; fix demo or open U4 if upstream. Does **not** block U1–U3.

### P1 — Re-pack `~/packages` from worktree after U1–U3

Refresh tarballs + `.rnfb-local-pack-meta.json` from `v26-validation-fixes` tip before matrix.

---

## Done / retained

| ID | Notes |
|----|-------|
| G0 | Gap analysis |
| S0 | SDK/gradle pins synced |
| P0 | Initial pack from main (stale once U* land — replace via P1) |
| L0 | Yarn 4 + digest guard + Metro non-TTY — `review_gate` closed; `commit_gate` open until user asks |

**H0** (monolith) → **superseded / split** into U1, U2, U3, D1, D2. Keep H0 row as archive pointer only.

---

## Fixed pins (align to RNFB `sdkVersions` on worktree tip)

```bash
RNFB_VER=25.1.0   # informational when local tarballs present
FB_IOS_VER=12.15.0
FB_ANDROID_VER=34.15.0
FB_GRADLE_SERVICES_VER=4.5.0
FB_GRADLE_PERF_VER=2.0.2
FB_GRADLE_CRASH_VER=3.0.7
FB_GRADLE_APP_DIST_VER=5.3.0
```

RN matrix: **0.86.0**, **0.85.3**, **0.84.1** · Expo: **57**, **56**, **55**

### Pre-flight before each demo

```bash
security show-keychain-info login.keychain >/dev/null
adb devices | grep -E 'emulator|device' | grep -v List
adb shell am force-stop com.invertase.testing 2>/dev/null || true
rm -fr "$HOME/Library/Developer/Xcode/DerivedData/rnfbdemo"* "$HOME/Library/Developer/Xcode/DerivedData/rnfbexpodemo"*
```

Never overlap two demo scripts on one host.

---

## Current snapshot

| ID | Item | next_work_type | validation_tier | platform | implementation_gate | review_gate | commit_gate | Notes |
|----|------|----------------|-----------------|----------|---------------------|-------------|-------------|-------|
| G0 | Gap analysis | — | — | — | closed | n/a | n/a | Done |
| S0 | Sync SDK/gradle pins | — | — | scripts | closed | closed | open | Done |
| P0 | Initial pack from main | — | — | host | closed | closed | n/a | Superseded by P1 after U* |
| L0 | Local unpublished packages guard | — | n/a | scripts | closed | closed | closed | **Committed** `fix: make local packages work` |
| H0 | *(archive)* messaging hang investigation | — | — | — | n/a | n/a | n/a | Split → U1/U2/U3/D1/D2. Log `/tmp/rnfbdemo-H0.log` |
| U1 | **ResultT / codegen for RN 0.86** | `independent-review` | `area-focused` | ios (RNFB) | closed | open | open | Interim on `v26-validation-fixes`; CP-264 durable regen |
| **OKF-IF** | **Install/fmt gate before `:build`** | — | none | okf-bundle | closed | closed | closed | `commit_subject`: `docs(okf): require yarn and fmt>=12.1.0 before native build`. Owner: `#install-patch-fmt-gate-blocking`. DRY pass fixed `running-e2e` restatement. |
| **OKF-Nx-patch** | **Nx must not cache-skip `patch-package`** | — | `area-focused` | nx/okf | closed | closed | closed | `commit_subject`: `fix(tooling): never Nx-cache-skip patch-package prepare`. MonoTool-AD-12; tests prepare `cache:false`; fmt verify 12.1.0. |
| **U2** | **Xcode 26 react/debug + explicit modules** | — | `area-focused` | ios (RNFB) | closed | closed | closed | **Committed** subject `fix(ios): private codegen headers and bridging-safe AppCheck module`. Residual tracked as **U2-src**. |
| **U2-src** | **From-source RNCore still hits react/debug** | — | `area-focused` | ios (RNFB) | closed | closed | closed | **Committed** `fix(storage, ios): preserve RN framework HEADER_SEARCH_PATHS in podspec` (amended: OKF row 9 Example → Firestore). Review `/tmp/rnfbdemo-U2-src-review.log`. |
| **U3** | **Messaging APNs timeout (main stall)** | — | `area-focused` | ios (RNFB messaging) | closed | closed | closed | `commit_subject`: `fix(messaging, ios): make APNs registration timeout independent of main queue`. Evidence: iOS 67 pass, Android 85 pass, `.agents/reports/U3/coverage-evidence.md`. |
| **D1** | **Demo fail-fast + remove non-doc hacks** | — | `unit-focused` | scripts | closed | closed | closed | **Committed** `fix(demo): use AppCheck bridging header instead of Swift module import` |
| **D1-RNCore** | **Enable both RNCore modes in make-demo** | — | `area-focused` | scripts | closed | closed | closed | **Committed** `test(demo): exercise from-source and prebuilt RNCore iOS rounds` (+ `RN_VER=${RN_VER:-0.86.0}` for matrix). Exercised green in C1b. |
| **D2** | **AppCheck TypeError** | — | `area-focused` | demo | closed | closed | closed | **Committed** `fix(demo): use modular AppCheck provider construction`. Review PASS ([D2 review](bfccdd1b-97e3-474c-9415-fc36163360b0)): Android Layer B `/tmp/rnfbdemo-D2-review-logcat.log`. Minors: metro version skew hygiene; UI label nit; upstream docs await wording. |
| **L1-meta** | **Pack meta gitSha rewritten on verify** | — | — | scripts | closed | closed | closed | **Committed** `fix(demo): stop rewriting local RNFB pack meta on verify`. Review GREEN ([review](01fd5cce-aa51-4980-8b5f-dcb0926f35d7)); helper `write-local-pack-meta.sh`. |
| **P1** | **Re-pack ~/packages from worktree** | — | — | host | closed | n/a | n/a | Done with U2-src / C1b repack. |
| **C1** | CLI RN **0.86.0** — **both RNCore modes** | — | `full` | ios+android | closed | closed | n/a | **GREEN** ([C1e](5151e7c9-63cf-46e6-aa52-8f9e61987877)): Layer A `MAKE_DEMO_EXIT=0` (~81m, both RNCore); Layer B AppCheck init iOS+Android, no fatal JS. Logs `/tmp/rnfbdemo-C1e.log`, `/tmp/rnfbdemo-C1e-layerb.log`. |
| **C2** | CLI RN **0.85.3** — **both RNCore modes** | — | `full` | ios+android | closed | closed | n/a | **GREEN** ([C2c](bab8fd75-7bbf-46c9-bd12-b793ba261b52)): Layer A `MAKE_DEMO_EXIT=0`; Layer B AppCheck init iOS+Android. Logs `/tmp/rnfbdemo-C2c.log`, `/tmp/rnfbdemo-C2c-layerb.log`. |
| **C3** | CLI RN **0.84.1** — **both RNCore modes** | — | `full` | ios+android | closed | closed | n/a | **GREEN** ([C3c](24aaf9a3-d788-4491-8077-8288f10fbb83)): Layer A `MAKE_DEMO_EXIT=0` (~23m, both RNCore); fmt 12.1.0; Layer B AppCheck Android + iOS OK. Logs `/tmp/rnfbdemo-C3c.log`, `/tmp/rnfbdemo-C3c-layerb.log`. Prior: C3a fmt FAIL; C3b env AVD dropout. |
| **C3-fmt** | **Bump RN fmt≥12.1.0 in demo scripts (Xcode 26)** | — | — | scripts | closed | closed | closed | **Committed** `fix(demo): bump RN fmt pin to 12.1.0 for Xcode 26`. Helper `ensureReactNativeFmtAtLeast`; wired in make-demo + make-expo-demo. Proven by [C3c](24aaf9a3-d788-4491-8077-8288f10fbb83). |
| **E1** | Expo SDK **57** | — | `full` | ios+android | closed | closed | n/a | **GREEN** ([E1g](de26bc15-b094-4c10-9038-c89a1d3c1862)): Layer A `MAKE_DEMO_EXIT=0`; Layer B AppCheck iOS+Android. Logs `/tmp/rnfbdemo-E1g.log`, `/tmp/rnfbdemo-E1g-layerb.log`. Dual RNCore n/a. |
| **E1-create** | **Fix Expo template create (Node 24 / create-expo-app)** | — | — | scripts | closed | closed | closed | Shipped in combined commit. Confirmed E1g. |
| **E1-yarn** | **Force Yarn node-modules linker for Expo** | — | — | scripts | closed | closed | closed | Shipped in combined commit. Confirmed E1g. |
| **E1-sim** | **Expo iOS launch without System Events TCC** | — | — | scripts | closed | closed | closed | Shipped in combined commit. Confirmed E1g (simctl fallback). |
| **E1-gradle** | **Safe gradle.properties jvmargs append** | — | — | scripts | closed | closed | closed | Shipped in combined commit. Confirmed E1g. `commit_subject` (shared): `fix(expo-demo): make Expo SDK matrix bootstrap agent-safe`. |
| **E2** | Expo SDK **56** | — | `full` | ios+android | closed | closed | n/a | **GREEN** ([E2a](da8b2947-82b6-487a-a4a8-ed732f391624)): Layer A `MAKE_DEMO_EXIT=0`; Layer B AppCheck iOS+Android. Logs `/tmp/rnfbdemo-E2a.log`, `/tmp/rnfbdemo-E2a-layerb.log`. Dual RNCore n/a. |
| **E3** | Expo SDK **55** | — | `full` | ios+android | closed | closed | n/a | **GREEN** ([E3a](9573cd33-0eb4-4307-84d6-4600587216de)): Layer A `MAKE_DEMO_EXIT=0`; Layer B AppCheck iOS+Android. Logs `/tmp/rnfbdemo-E3a.log`, `/tmp/rnfbdemo-E3a-layerb.log`. Dual RNCore n/a. |

## Current gates

- **Pickup order:** Queue drained for demo-matrix scope (C*/E* + L1-meta). Remaining upstream items (e.g. U1 review) live on RNFB worktree, not this demo queue.
- **Pass bar:** build/install exit 0 **and** Metro/device-log runtime-clean (see script header comments + § Matrix pass bar). Build-only cell greens are provisional until requalified.
- **C\*/E\* rule:** each `make-demo.sh` / `make-expo-demo.sh` invocation is validation/review. Failures reopen implementation, then fresh review.
- **Dual RNCore:** C\* green only when **from-source (`PREBUILT=0`) and prebuilt (`PREBUILT=1`)** both succeed **and** runtime-clean.
- Upstream commits/PRs only from worktree `v26-validation-fixes` (not primary clone).
- Never overlap two demo scripts on one host.

---

## U2 evidence + fix handoff (2026-07-25)

**Host:** Xcode 26.6 · docs-faithful `make-demo.sh` (no H0 hacks) · local packs from worktree `991c92895` (U1 ResultT interim)

### Gap-analysis logs (blockers confirmed)

| Log | RN | Outcome | First hard error |
|-----|-----|---------|------------------|
| `/tmp/rnfbdemo-U2-rn86.log` | 0.86.0 | compile FAIL | Blocker **2a**: Swift `import RNFBAppCheck` → `'utility'/'optional'/'tuple' file not found` during `RNFBAppCheck` module dep-scan |
| `/tmp/rnfbdemo-U2-rn85.log` | 0.85.3 | compile FAIL | **Same** blocker 2a — not 0.86-specific |
| `/tmp/rnfbdemo-U2-clang-explicit-off.log` | 0.86 (probe) | compile FAIL | Blocker **2b**: `'react/debug/flags.h' file not found` in RNFBStorage (after `CLANG_ENABLE_EXPLICIT_MODULES=NO` cleared 2a) |

**Ruled out as first failure:** ResultT (0 errors with U1 packs); `FirebaseCoreInternal`/`FirebaseSharedSwift` (compiled OK); PR #8933 SPM path (not on main; unrelated to observed errors).

### Root cause

**Blocker 2a — AppCheck Swift import + explicit modules**

1. `make-demo.sh` injects `import RNFBAppCheck` (lines 225–227) — **wrong**; Expo plugin uses bridging header only (`packages/app-check/plugin/src/ios/appDelegate.ts`).
2. `RNFBAppCheckModule.h` previously `#import "RNFBAppCheckTurboModules.h"` (C++ codegen with `<optional>`, etc.).
3. Under Xcode 26 explicit modules + RN ccache launcher, Swift/App bridging triggers Clang dep-scan of the `RNFBAppCheck` framework module → C++ STL headers not found.

**Blocker 2b — react/debug modular include**

1. `use_frameworks! :static` + New Arch: `#include <react/debug/flags.h>` resolves module `react` to **React-Core** (`React.framework`), not **React-debug** (`React_debug.framework`).
2. **RNFBStorage**, **RNFBMessaging**, **RNFBAppCheck** lacked `private_header_files` for `ios/generated/**/*.h` — unlike Auth/Firestore/Database/etc. Codegen headers in public `Headers/` pull in React timing headers → modular include failure.
3. U2 probe: `CLANG_ENABLE_EXPLICIT_MODULES=NO` clears 2a but hits 2b at RNFBStorage — confirms two independent issues.

### Durable fix (drafted, uncommitted on worktree)

Worktree: `/Users/mike/work/invertase/RNFB-worktrees/v26-validation-fixes` (6 files, on top of U1 commit `991c92895`)

| File | Change |
|------|--------|
| `packages/storage/RNFBStorage.podspec` | `private_header_files`: `ios/RNFBStorage/*.h`, `ios/generated/**/*.h` |
| `packages/messaging/RNFBMessaging.podspec` | Same + `HEADER_SEARCH_PATHS` for generated specs |
| `packages/app-check/RNFBAppCheck.podspec` | `public_header_files` (thin module + providers); `private_header_files` for generated; `HEADER_SEARCH_PATHS`; remove `.swift` from `source_files` |
| `packages/app-check/ios/.../RNFBAppCheckModule.h` | Bridging-safe: `@interface` + `sharedInstance` only |
| `packages/app-check/ios/.../RNFBAppCheckModule.mm` | Class extension: `<NativeRNFBTurboAppCheckSpec, RCTInvalidating>` + turbo imports |
| `docs/app-check/usage/index.mdx` | Remove `import RNFBAppCheck` from 0.77–0.79 section |

### Fix validation log

`/tmp/rnfbdemo-U2-fix.log` — patched node_modules + `pod install` + clean DerivedData:

- **RNFBStorage** TurboModule compile: **OK** (blocker 2b cleared)
- **RNFBMessaging** TurboModule compile: **OK**
- **RNFBAppCheck** compile: **OK**
- **AppDelegate.swift** + bridging header: **OK** (blocker 2a cleared)
- Link step: failed `_RNFBVersionString` — **unrelated to U2** (test harness / signing); compile gate for U2 is satisfied

### Remaining for next agent

1. **`independent-review`** podspec + header split on worktree
2. **Commit** (suggested: `fix(ios): private codegen headers and bridging-safe AppCheck module`)
3. **P1 partial re-pack** `~/packages` from worktree tip
4. **D1:** Fix `make-demo.sh` AppCheck block — replace `import RNFBAppCheck` with bridging header `#import "RNFBAppCheckModule.h"` + `SWIFT_OBJC_BRIDGING_HEADER` in generated Xcode project (match Expo plugin)
5. Full `make-demo.sh` iOS compile on RN 0.86 + spot 0.85
6. Then **U3** messaging timeout

### U2-L — RNFBVersionString link failure (packaging / harness — out of U2 scope)

**Discovered during U2 review** (`/tmp/rnfbdemo-U2-review.log`). Not caused by U2 podspec changes.

| Field | Value |
|-------|--------|
| Symptom | Linker `Undefined symbol _RNFBVersionString` from Crashlytics/Firestore |
| Root cause | `RNFBVersion.m` is gitignored generated output of `packages/app/scripts/genversion-ios.js`; absent when node_modules synced from source without `build:version` |
| U2 relation | **None** — U2 compile gate passes without link; full app link succeeds after generating the file (`/tmp/rnfbdemo-U2-review-linkfix.log` BUILD SUCCEEDED) |
| Fix options | (1) P1 pack script runs version gen before tgz; (2) document harness step; (3) commit generated file policy change (unlikely) |
| Gate | Track here until P1 or harness fixed; **does not block U2 commit** |

### U2 review findings (2026-07-25, reviewer `292c3668`)

| severity | file | issue | status |
|----------|------|-------|--------|
| **serious** | `RNFBMessaging.podspec` | `private_header_files` privatizes `RNFBMessagingModule.h` | **fixed** — `public_header_files` added |
| minor | `RNFBAppCheck.podspec` | Provider/Factory headers unnecessarily public | **fixed** |
| minor | `docs/app-check/usage/index.mdx` | "no module map" wording imprecise | **fixed** |
| nit | Messaging module header still imports turbo in public header | informational only (no Swift bridging path) | defer |
| nit | bridging header import style (`<>` vs `""`) | cosmetic | defer |

### D1 make-demo.sh AppCheck fix (spec for implementer)

Replace current block (~lines 223–228):

```bash
# WRONG (causes blocker 2a):
sed -i -e $'s/import UIKit/import UIKit\\\nimport RNFBAppCheck/' ...
```

With docs-faithful bridging-header flow (already in Expo plugin + fixed docs):

1. Create/populate `ios/<ProjectName>/<ProjectName>-Bridging-Header.h` with `#import "RNFBAppCheckModule.h"`
2. Set `SWIFT_OBJC_BRIDGING_HEADER` on app target (pbxproj or `pbxproj` CLI)
3. AppDelegate: `RNFBAppCheckModule.sharedInstance()` before `FirebaseApp.configure()` — **no** `import RNFBAppCheck`

## Evidence templates

### U2 (filled 2026-07-25)

| Field | Value |
|-------|--------|
| item | U2 |
| worktree | `/Users/mike/work/invertase/RNFB-worktrees/v26-validation-fixes` |
| root_cause | 2a: Swift AppCheck import + C++ codegen in public module header under explicit modules. 2b: missing `private_header_files` on Storage/Messaging/AppCheck codegen → modular `react/debug` include via wrong framework |
| files touched | 6 files (see U2 handoff section) — **uncommitted** |
| pack refreshed | no (validation via node_modules patch) |
| proof | `/tmp/rnfbdemo-U2-fix.log` — compile past both blockers |
| log | `/tmp/rnfbdemo-U2-rn86.log`, `rn85.log`, `clang-explicit-off.log`, `fix.log` |

### U1 / U3

| Field | Value |
|-------|--------|
| item | U1 / U2 / U3 |
| worktree | `/Users/mike/work/invertase/RNFB-worktrees/v26-validation-fixes` |
| root_cause | … |
| files touched | … |
| pack refreshed | yes/no |
| proof | compile / timeout / clean docs path |
| log | `/tmp/rnfbdemo-U*.log` |

### C*/E*

| Field | Value |
|-------|-------|
| item | C1 / … |
| command | `./make-demo.sh` or `./make-expo-demo.sh` |
| RN_VER / EXPO_VER | … |
| local packages verified | yes (L0 guard) |
| **Layer A** exit_code | |
| **Layer A** log | `/tmp/rnfbdemo-….log` |
| iOS / Android build outcome | |
| **Layer B** Metro log path | `/tmp/rnfbdemo-metro.log` (Debug) |
| **Layer B** device log evidence | `adb logcat` / iOS JS log excerpts |
| AppCheck init | `AppCheck is initialized.` / FAIL + excerpt |
| fatal JS (TypeError/RedBox) | none / FAIL + excerpt |
| cell verdict | green only if A **and** B pass |
