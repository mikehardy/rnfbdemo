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

usingLocalRnfbPackages() {
  [ -e "${RNFB_LOCAL_PACKAGES_DIR}/react-native-firebase-app.tgz" ]
}

# Write ~/packages/.rnfb-local-pack-meta.json from current tarballs.
# Optional arg: RNFB git checkout path for gitSha (else tries common default).
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
if os.path.isdir(os.path.join(source_checkout, ".git")):
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
    echo "Run writeRnfbLocalPackMeta (or pack via create_npm_packages.sh) before verifying."
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

# Prepare local-pack meta then verify after installs (no-op if not using local packs).
finalizeLocalRnfbInstalls() {
  if ! usingLocalRnfbPackages; then
    echo "No local RNFB tarballs at ${RNFB_LOCAL_PACKAGES_DIR}; skipping content verification"
    return 0
  fi
  writeRnfbLocalPackMeta
  verifyRnfbLocalPackagesInstalled "${1:-node_modules}"
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
