#!/bin/bash
# Shared helpers for rnfbdemo / rnfbexpodemo integration scripts.
#
# Local unpublished RNFB packages (Yarn Berry note):
# React Native CLI templates pin packageManager to Yarn 3.x. Yarn 3 resolves
# `file:/path/to/pkg.tgz` WITHOUT a content hash in the lockfile locator, and
# caches by path+workspace name. Replacing ~/packages/*.tgz (or rm -fr + re-init
# with the same Android package name) then `yarn add …@file:…` (even twice —
# the classic Yarn 1 workaround) can leave node_modules on STALE contents.
# Yarn 4 embeds `::hash=<content>` in file: resolutions and refreshes correctly.
# Demo scripts must force Yarn 4 in the project before any local file: installs,
# then verify installed member digests against the packed tarballs.
# Yarn Berry defaults to PnP; Expo CLI (and typical RN tooling) expect classic
# node_modules — ensureYarnNodeModulesLinker before the first yarn install.

RNFB_LOCAL_PACKAGES_DIR="${RNFB_LOCAL_PACKAGES_DIR:-$HOME/packages}"
RNFB_LOCAL_PACK_META="${RNFB_LOCAL_PACK_META:-$RNFB_LOCAL_PACKAGES_DIR/.rnfb-local-pack-meta.json}"
RNFB_YARN4_VERSION="${RNFB_YARN4_VERSION:-4.14.1}"

verifyLocalYarnVersion() {
  # Host check before project init: templates often pin Yarn 3.x; we accept 3 or 4 here.
  # ensureProjectYarnBerry4 later forces Yarn 4 inside the app for content-hashed file: installs.
  if ! YARN_VERSION=$(yarn --version|cut -f1 -d'.') || { [ "$YARN_VERSION" != "3" ] && [ "$YARN_VERSION" != "4" ]; }; then
    echo "This script requires Yarn major version 3 or 4 before project init (got ${YARN_VERSION:-unknown})."
    echo "Install yarn (for example \`corepack enable && corepack prepare yarn@stable --activate\`) and re-try"
    exit 1
  fi
}

verifyJqVersion() {
  JQ_VERSION_WANTED="jq-1.7"
  if ! JQ_VERSION=$(jq --version) || [[ "$JQ_VERSION" != *"$JQ_VERSION_WANTED"* ]]; then
    echo "This script uses $JQ_VERSION_WANTED (found ${JQ_VERSION}), please install jq (for example \`brew install\` on macOS or \`choco install jq\` on windows with choco, then re-try"
  fi
}

verifyDarwinPrequisites() {
  if [ "$(uname)" == "Darwin" ]; then
    # If the keychain is unlocked then this fails in the middle, let's check that now and fail fast
    if ! security show-keychain-info login.keychain > /dev/null 2>&1; then
      echo "Login keychain is not unlocked, codesigning will fail so macCatalyst build wll fail."
      echo "run 'security unlock-keychain login.keychain' to unlock the login keychain then re-run"
      exit 1
    fi

    # We do not want to run under Rosetta 2, brew doesn't work and compiles might not work after
    arch_name="$(uname -m)"
    if [ "${arch_name}" = "x86_64" ]; then
      if [ "$(sysctl -in sysctl.proc_translated)" = "1" ]; then
        echo "Running on Rosetta 2"
        echo "This is not supported. Run \`env /usr/bin/arch -arm64 /bin/bash --login\` then try again"
        exit 1
      else
        echo "Running on native Intel"
      fi
    elif [ "${arch_name}" = "arm64" ]; then
      echo "Running on ARM"
    else
      echo "Unknown architecture: ${arch_name}"
    fi
  fi
}

warnIfLocalRnfbPackagesPresent() {
  if [ -e "${RNFB_LOCAL_PACKAGES_DIR}/react-native-firebase-app.tgz" ]; then
    echo "#################################################################"
    echo
    echo "  Local packages in ${RNFB_LOCAL_PACKAGES_DIR} - abort and delete if unwanted"
    echo
    echo "#################################################################"
    sleep 5
  fi
}

# RN / Expo templates often pin Yarn 3.x via packageManager. Force Yarn 4 so
# file: tarball installs are content-hashed (see header comment).
ensureProjectYarnBerry4() {
  local current major
  current="$(yarn --version 2>/dev/null || true)"
  major="$(echo "$current" | cut -f1 -d'.')"
  if [ "$major" = "4" ]; then
    echo "Project Yarn is already ${current} (content-hashed file: installs OK)"
    return 0
  fi
  echo "Project Yarn is '${current}' (templates often pin 3.x)."
  echo "Upgrading project to Yarn ${RNFB_YARN4_VERSION} so local file: tarballs are content-hashed..."
  yarn set version "${RNFB_YARN4_VERSION}"
  current="$(yarn --version)"
  major="$(echo "$current" | cut -f1 -d'.')"
  if [ "$major" != "4" ]; then
    echo "ERROR: failed to switch project Yarn to 4.x (now ${current})"
    exit 1
  fi
  echo "Project Yarn is now ${current}"
}

# Expo CLI (and typical RN tooling) expect classic node_modules, not Yarn PnP.
# Call after ensureProjectYarnBerry4 and before the first yarn install. Idempotent.
ensureYarnNodeModulesLinker() {
  local current
  current="$(yarn config get nodeLinker 2>/dev/null || true)"
  if [ "$current" = "node-modules" ]; then
    echo "Yarn nodeLinker already node-modules (classic installs)"
    return 0
  fi
  echo "Setting Yarn nodeLinker to node-modules (Expo CLI expects node_modules, not PnP)..."
  yarn config set nodeLinker node-modules
  current="$(yarn config get nodeLinker 2>/dev/null || true)"
  if [ "$current" != "node-modules" ]; then
    echo "ERROR: failed to set Yarn nodeLinker to node-modules (now '${current}')"
    exit 1
  fi
  echo "Yarn nodeLinker is now node-modules"
}

usingLocalRnfbPackages() {
  [ -e "${RNFB_LOCAL_PACKAGES_DIR}/react-native-firebase-app.tgz" ]
}

# Write ~/packages/.rnfb-local-pack-meta.json from current tarballs.
# Call explicitly after packing/refreshing tarballs — not from verify/finalize.
# Optional arg / RNFB_SOURCE_CHECKOUT: git checkout whose HEAD becomes gitSha.
# For the main-compat matrix packs, use the worktree that ran create_npm_packages.sh
# (e.g. $HOME/work/invertase/RNFB-worktrees/v26-validation-fixes). Default falls
# back to the primary clone path when unset.
writeRnfbLocalPackMeta() {
  local source_checkout="${1:-${RNFB_SOURCE_CHECKOUT:-$HOME/work/invertase/react-native-firebase}}"
  local packages_dir="${RNFB_LOCAL_PACKAGES_DIR}"
  local meta_path="${RNFB_LOCAL_PACK_META}"

  if [ ! -d "${packages_dir}" ]; then
    echo "ERROR: local packages dir not found: ${packages_dir}"
    exit 1
  fi

  python3 - "$packages_dir" "$meta_path" "$source_checkout" <<'PY'
import hashlib, json, os, subprocess, sys, tarfile, time

packages_dir, meta_path, source_checkout = sys.argv[1:4]

def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def member_interesting(name: str) -> bool:
    # package/ prefix stripped by caller
    if name == "package.json":
        return True
    if "/RNFB" in name and name.endswith((".m", ".mm", ".h")):
        return True
    # Distinguishing Android native sources (stale installs often differ here too)
    if name.startswith("android/") and name.endswith((".java", ".kt")):
        return True
    if name.startswith("ios/generated/") and not name.endswith("/"):
        return True
    if name.endswith("app.plugin.js"):
        return True
    return False

git_sha = None
# Regular clones have .git as a directory; linked worktrees use a .git *file*
# pointing at the main repo's worktrees/<name> metadata. Either is enough for
# `git -C … rev-parse HEAD`.
git_marker = os.path.join(source_checkout, ".git")
if os.path.isdir(git_marker) or os.path.isfile(git_marker):
    try:
        git_sha = subprocess.check_output(
            ["git", "-C", source_checkout, "rev-parse", "HEAD"],
            text=True,
        ).strip()
    except Exception:
        git_sha = None

packages = {}
for fname in sorted(os.listdir(packages_dir)):
    if not (fname.startswith("react-native-firebase-") and fname.endswith(".tgz")):
        continue
    pkg_slug = fname[len("react-native-firebase-") : -len(".tgz")]
    tgz_path = os.path.join(packages_dir, fname)
    members = {}
    with tarfile.open(tgz_path, "r:gz") as tf:
        for info in tf.getmembers():
            if not info.isfile():
                continue
            name = info.name
            if name.startswith("package/"):
                rel = name[len("package/") :]
            else:
                continue
            if not member_interesting(rel):
                continue
            extracted = tf.extractfile(info)
            if extracted is None:
                continue
            members[rel] = sha256_bytes(extracted.read())
    packages[pkg_slug] = {
        "tgz": fname,
        "npmName": f"@react-native-firebase/{pkg_slug}",
        "tgzSha256": sha256_file(tgz_path),
        "members": members,
    }

meta = {
    "schemaVersion": 1,
    "createdAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "packagesDir": packages_dir,
    "gitSha": git_sha,
    "packages": packages,
}
os.makedirs(os.path.dirname(meta_path) or ".", exist_ok=True)
with open(meta_path, "w", encoding="utf-8") as f:
    json.dump(meta, f, indent=2, sort_keys=True)
    f.write("\n")
print(f"Wrote local pack meta ({len(packages)} packages) -> {meta_path}")
if git_sha:
    print(f"  gitSha: {git_sha}")
PY
}

# Install one @react-native-firebase/<pkg> from local tarball or npm version.
# Requires: already inside the app project; Yarn 4+; RNFB_VER for registry fallback.
installRnfbPackage() {
  local pkg="$1"
  local tgz="${RNFB_LOCAL_PACKAGES_DIR}/react-native-firebase-${pkg}.tgz"
  if [ -e "${tgz}" ]; then
    echo "Adding @react-native-firebase/${pkg} from local tarball ${tgz}"
    # Single add is enough on Yarn 4 (content-hashed). Double-add is a Yarn 1 myth and is insufficient on Yarn 3.
    yarn add "@react-native-firebase/${pkg}@file:${tgz}"
  else
    if [ -z "${RNFB_VER:-}" ]; then
      echo "ERROR: no local tarball for ${pkg} and RNFB_VER is unset"
      exit 1
    fi
    echo "Adding @react-native-firebase/${pkg}@${RNFB_VER} from registry"
    yarn add "@react-native-firebase/${pkg}@${RNFB_VER}"
  fi
}

# After local installs: prove node_modules members match packed tarball fingerprints.
# Does NOT trust package.json version strings alone.
verifyRnfbLocalPackagesInstalled() {
  local meta_path="${RNFB_LOCAL_PACK_META}"
  local node_modules_root="${1:-node_modules}"

  if [ ! -f "${meta_path}" ]; then
    echo "ERROR: missing local pack meta at ${meta_path}"
    echo "Local RNFB tarballs are in use but pack meta was not written."
    echo "Do not invent meta at verify time — run ./write-local-pack-meta.sh (or"
    echo "writeRnfbLocalPackMeta) with the checkout that packed the tarballs"
    echo "(set RNFB_SOURCE_CHECKOUT or pass the path), or pack via"
    echo "create_npm_packages.sh then write meta, then re-verify."
    exit 1
  fi

  python3 - "$meta_path" "$node_modules_root" <<'PY'
import hashlib, json, os, sys

meta_path, nm_root = sys.argv[1:3]
with open(meta_path, encoding="utf-8") as f:
    meta = json.load(f)

def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

errors = []
checked = 0
for slug, info in sorted(meta.get("packages", {}).items()):
    npm_name = info.get("npmName") or f"@react-native-firebase/{slug}"
    pkg_dir = os.path.join(nm_root, *npm_name.split("/"))
    if not os.path.isdir(pkg_dir):
        # Optional packs (e.g. vertexai / phone-number-verification) may be absent from demos.
        continue
    members = info.get("members") or {}
    if not members:
        errors.append(f"{npm_name}: pack meta has no member digests")
        continue
    for rel, expected in sorted(members.items()):
        checked += 1
        actual_path = os.path.join(pkg_dir, rel)
        if not os.path.isfile(actual_path):
            errors.append(
                f"{npm_name}: missing installed member {rel} (expected sha256={expected[:12]}…)"
            )
            continue
        actual = sha256_file(actual_path)
        if actual != expected:
            errors.append(
                f"{npm_name}: member mismatch {rel}\n"
                f"  packed:    {expected}\n"
                f"  installed: {actual}\n"
                f"  path: {actual_path}"
            )

if errors:
    print("ERROR: local RNFB install does not match packed tarball contents:", file=sys.stderr)
    for e in errors:
        print(f"  - {e}", file=sys.stderr)
    print(
        "\nYarn 3.x file: installs can serve stale path-cached tarballs; "
        "ensure the project is on Yarn 4+ and re-install from ~/packages.",
        file=sys.stderr,
    )
    sys.exit(1)

if checked == 0:
    pkg_count = len(meta.get("packages") or {})
    print(
        "ERROR: local RNFB packs are in use but verified 0 member digests "
        f"(meta packages={pkg_count}, node_modules_root={nm_root}). "
        "Expected installed @react-native-firebase/* packages matching the pack meta; "
        "check that demos installed local tarballs and that pack meta has member digests.",
        file=sys.stderr,
    )
    sys.exit(1)

git_sha = meta.get("gitSha") or "(unknown)"
print(
    f"OK: verified {checked} member digest(s) across installed local RNFB packages "
    f"against {meta_path} (gitSha={git_sha})"
)
PY
}

# Verify installed local packs against existing pack meta (no-op if not using local packs).
# Does NOT rewrite ~/packages/.rnfb-local-pack-meta.json — provenance (gitSha/createdAt)
# is owned by writeRnfbLocalPackMeta / the pack workflow.
finalizeLocalRnfbInstalls() {
  if ! usingLocalRnfbPackages; then
    echo "No local RNFB tarballs at ${RNFB_LOCAL_PACKAGES_DIR}; skipping content verification"
    return 0
  fi
  verifyRnfbLocalPackagesInstalled "${1:-node_modules}"
}

# Xcode 26 / Apple Clang 21 fails consteval builds against fmt 11.0.2.
# Documented floor is fmt ≥ 12.1.0 (same rationale as RNFB OKF install/patch/fmt
# gate — bump the RN third-party pin; do not invent FMT_USE_CONSTEVAL / Podfile /
# base.h / c++17-for-fmt-only workarounds). Some RN / Expo templates still ship
# 11.0.2; call this after yarn and before any pod-install / expo prebuild.
# Idempotent: no-op when fmt.podspec is already ≥ the floor.
ensureReactNativeFmtAtLeast() {
  local rn_root="${1:-node_modules/react-native}"
  local min_ver="${2:-12.1.0}"
  local fmt_podspec="${rn_root}/third-party-podspecs/fmt.podspec"

  if [ ! -f "${fmt_podspec}" ]; then
    echo "ensureReactNativeFmtAtLeast: no ${fmt_podspec} (skipping; RN may be absent)"
    return 0
  fi

  python3 - "$rn_root" "$min_ver" <<'PY'
import os, re, sys

rn_root, min_ver = sys.argv[1:3]

def parse_ver(s: str):
    parts = []
    for p in s.split("."):
        try:
            parts.append(int(p))
        except ValueError:
            parts.append(0)
    while len(parts) < 3:
        parts.append(0)
    return tuple(parts[:3])

def ver_lt(a: str, b: str) -> bool:
    return parse_ver(a) < parse_ver(b)

fmt_podspec = os.path.join(rn_root, "third-party-podspecs", "fmt.podspec")
with open(fmt_podspec, encoding="utf-8") as f:
    text = f.read()

m = re.search(r'spec\.version\s*=\s*"([^"]+)"', text)
if not m:
    print(f"ERROR: could not parse spec.version in {fmt_podspec}", file=sys.stderr)
    sys.exit(1)
current = m.group(1)
if not ver_lt(current, min_ver):
    print(f"React Native fmt pin already {current} (>= {min_ver}); leaving podspecs unchanged")
    sys.exit(0)

print(
    f"React Native ships fmt {current} (< {min_ver}); bumping third-party pin to {min_ver} "
    f"for Xcode 26 / Apple Clang 21 (documented floor)"
)

# Mirror RNFB tests/patches/react-native+*.patch: fmt.podspec version+tag, and every
# CocoaPods dependency pin on fmt under node_modules/react-native.
updated_files = []

new_text, n_ver = re.subn(
    r'(spec\.version\s*=\s*")[^"]+(")',
    rf"\g<1>{min_ver}\2",
    text,
    count=1,
)
new_text, n_tag = re.subn(
    r'(:tag\s*=>\s*")[^"]+(")',
    rf"\g<1>{min_ver}\2",
    new_text,
    count=1,
)
if n_ver != 1 or n_tag != 1:
    print(
        f"ERROR: expected to rewrite version+tag once in {fmt_podspec} "
        f"(version={n_ver}, tag={n_tag})",
        file=sys.stderr,
    )
    sys.exit(1)
with open(fmt_podspec, "w", encoding="utf-8") as f:
    f.write(new_text)
updated_files.append(os.path.relpath(fmt_podspec))

dep_re = re.compile(
    r'''((?:s|ss|spec)\.dependency\s+["']fmt["']\s*,\s*["'])([^"']+)(["'])'''
)
for dirpath, _dirnames, filenames in os.walk(rn_root):
    for name in filenames:
        if not name.endswith(".podspec"):
            continue
        path = os.path.join(dirpath, name)
        if os.path.samefile(path, fmt_podspec):
            continue
        with open(path, encoding="utf-8") as f:
            body = f.read()
        if "fmt" not in body:
            continue

        def repl(match: re.Match) -> str:
            old = match.group(2)
            if ver_lt(old, min_ver):
                return f"{match.group(1)}{min_ver}{match.group(3)}"
            return match.group(0)

        new_body, n = dep_re.subn(repl, body)
        if n and new_body != body:
            with open(path, "w", encoding="utf-8") as f:
                f.write(new_body)
            updated_files.append(os.path.relpath(path))

print(f"Updated {len(updated_files)} podspec(s) to fmt {min_ver}:")
for p in updated_files:
    print(f"  - {p}")
PY
}

# Boot preferred iOS Simulator via simctl + Launch Services (`open -a Simulator`).
# Does NOT use System Events / osascript — agents often correctly deny Automation TCC
# (-1743). RN CLI (`react-native run-ios`) never needed System Events; keep Expo Layer A
# on the same footing.
ensureIosSimulatorReady() {
  local device_name="${1:-iPhone 17}"
  local line udid
  echo "Ensuring iOS Simulator '${device_name}' is booted (simctl + open -a Simulator; no System Events)..."
  # Prefer an exact name match; avoid "iPhone 17 Pro" when asking for "iPhone 17".
  line="$(xcrun simctl list devices available | grep -E "^[[:space:]]*${device_name} \\(" | head -1)"
  if [ -z "$line" ]; then
    echo "ERROR: No available simulator named '${device_name}'"
    xcrun simctl list devices available
    exit 1
  fi
  udid="$(echo "$line" | sed -E 's/.*\(([A-F0-9-]{36})\).*/\1/')"
  if ! echo "$line" | grep -q '(Booted)'; then
    xcrun simctl boot "$udid" 2>/dev/null || true
  fi
  open -a Simulator --args -CurrentDeviceUDID "$udid"
  local i
  for i in $(seq 1 60); do
    if xcrun simctl list devices | grep -F "$udid" | grep -q '(Booted)'; then
      echo "Simulator '${device_name}' ($udid) is Booted"
      return 0
    fi
    sleep 1
  done
  echo "ERROR: Simulator '${device_name}' ($udid) did not reach Booted"
  exit 1
}

# Expo CLI post-install calls activateWindowAsync → ensureSimulatorAppRunningAsync, which
# probes Simulator via osascript→System Events. With Automation TCC denied that throws
# even when Simulator.app is already running and the app is already installed.
# If expo run:ios fails only on that path after Build Succeeded / install, complete Layer A
# with `xcrun simctl launch` (no Apple Events). Prefer this over patching node_modules/@expo/cli.
runExpoIosDebugWithoutSystemEventsTcc() {
  local bundle_id="${1:-io.invertase.testing}"
  local device_name="${2:-iPhone 17}"
  local log_file expo_exit
  log_file="$(mktemp /tmp/rnfbdemo-expo-ios.XXXXXX.log)"

  ensureIosSimulatorReady "$device_name"

  set +e
  npm_config_yes=true npx expo run:ios --configuration Debug --no-bundler --device "$device_name" 2>&1 | tee "$log_file"
  expo_exit=${PIPESTATUS[0]}
  set -e

  if [ "$expo_exit" -eq 0 ]; then
    rm -f "$log_file"
    return 0
  fi

  if grep -qE 'System Events|ensureSimulatorAppRunning|activateWindowAsync' "$log_file" \
    && grep -qE 'Build Succeeded|Installing on' "$log_file" \
    && xcrun simctl get_app_container booted "$bundle_id" >/dev/null 2>&1; then
    echo "Expo run:ios failed on System Events activate-window (Automation TCC). App is installed; completing Layer A launch via simctl (no System Events)..."
    xcrun simctl launch booted "$bundle_id"
    echo "simctl launch succeeded for ${bundle_id}"
    rm -f "$log_file"
    return 0
  fi

  echo "ERROR: expo run:ios failed (exit ${expo_exit}); log retained at ${log_file}"
  return "$expo_exit"
}

# Set org.gradle.jvmargs in android/gradle.properties without gluing onto a last
# line that lacks a trailing newline (Expo prebuild can emit that). Raw
# `echo … >>` then produces `…=[]org.gradle.jvmargs=…`, which breaks
# ExpoAutolinkingPlugin JSON.parse. Idempotent: skip when the desired line is
# already present as its own line and no glued mid-line copy remains. Otherwise
# replace any existing `^org.gradle.jvmargs=` (Expo templates ship one), un-glue
# mid-line copies from a prior bad append, and append only if the key was absent.
ensureGradleJvmArgs() {
  local props="${1:-android/gradle.properties}"
  local jvmargs_line="${2:-org.gradle.jvmargs=-Xmx4092m -Dfile.encoding=UTF-8}"
  local tmp line prefix wrote

  if [ ! -f "$props" ]; then
    echo "ERROR: ensureGradleJvmArgs: ${props} not found"
    exit 1
  fi

  # Ensure the file ends with a newline so line-oriented rewrite sees the last line.
  if [ -s "$props" ] && [ "$(tail -c1 "$props" | wc -l | tr -d ' ')" -eq 0 ]; then
    printf '\n' >> "$props"
  fi

  if grep -qxF "$jvmargs_line" "$props" && ! grep -qE '.+org\.gradle\.jvmargs=' "$props"; then
    echo "gradle.properties already has desired org.gradle.jvmargs (${props})"
    return 0
  fi

  tmp="$(mktemp)"
  wrote=0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      org.gradle.jvmargs=*)
        if [ "$wrote" -eq 0 ]; then
          printf '%s\n' "$jvmargs_line" >> "$tmp"
          wrote=1
        fi
        ;;
      *org.gradle.jvmargs=*)
        # Prior bad append glued onto this line — keep the prefix only.
        prefix="${line%%org.gradle.jvmargs=*}"
        printf '%s\n' "$prefix" >> "$tmp"
        ;;
      *)
        printf '%s\n' "$line" >> "$tmp"
        ;;
    esac
  done < "$props"

  if [ "$wrote" -eq 0 ]; then
    printf '%s\n' "$jvmargs_line" >> "$tmp"
  fi
  command mv -f "$tmp" "$props"
  echo "Set ${jvmargs_line} in ${props}"
}

# Secondary: non-TTY `run-ios` will not spawn Metro in a new window.
# Start Metro in the background if port 8081 is not already serving.
ensureMetroPackagerRunning() {
  if curl -sf "http://localhost:8081/status" >/dev/null 2>&1; then
    echo "Metro packager already running on 8081"
    return 0
  fi
  echo "Starting Metro packager in background (needed for non-TTY run-ios Debug)..."
  # Prefer Expo when present: Expo apps always ship react-native/cli.js, so
  # checking RN CLI first would make the expo start branch unreachable.
  if [ -f "node_modules/expo/package.json" ]; then
    npx expo start --port 8081 >/tmp/rnfbdemo-metro.log 2>&1 &
  else
    npx react-native start --port 8081 >/tmp/rnfbdemo-metro.log 2>&1 &
  fi
  local i
  for i in $(seq 1 60); do
    if curl -sf "http://localhost:8081/status" >/dev/null 2>&1; then
      echo "Metro packager is up on 8081"
      return 0
    fi
    sleep 1
  done
  echo "ERROR: Metro packager did not become ready on 8081 (see /tmp/rnfbdemo-metro.log)"
  tail -50 /tmp/rnfbdemo-metro.log 2>/dev/null || true
  exit 1
}
