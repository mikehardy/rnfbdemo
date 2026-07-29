#!/bin/bash
set -e

# ---------------------------------------------------------------------------
# Success criteria + how agents should run/poll this script (durable)
#
# This script automates native integration: template create, RNFB install, pods/
# gradle, and `run-ios` / `run-android`. A zero exit means compile, install, and
# process start succeeded — necessary, not sufficient.
#
# Wall-clock: often ~30–90+ minutes (from-source RNCore, cold pods, dual modes +
# Android). Not "multi-hour babysitting," but long enough to kill a chatty agent
# that polls with repeated long AwaitShell / milestone greps ([resource_exhausted])
# and tears the tee mid-xcodebuild (garbage footer like "...MAKE_DEMO_EXIT=1").
#
# === Layer A — run exactly like this (one shell owns the process) ===
#
#   cd <rnfbdemo-repo>
#   # Preflight: AVD up (adb devices); port 8081 free; login keychain unlocked;
#   # no other make-demo/xcodebuild. Optional if yarn dlx fails under Cursor:
#   #   unset YARN_CACHE_FOLDER YARN_ENABLE_GLOBAL_CACHE NPM_CONFIG_CACHE
#   RN_VER=<ver> ./make-demo.sh 2>&1 | tee /tmp/rnfbdemo-<cell>.log
#   echo MAKE_DEMO_EXIT=${PIPESTATUS[0]} | tee -a /tmp/rnfbdemo-<cell>.log
#
# Prefer one Shell call that blocks until finish (block_until_ms ~2–3h,
# required_permissions: ["all"]). If backgrounded, poll ONLY for a standalone
# line matching ^MAKE_DEMO_EXIT= — sparse checks (minutes apart), not continuous
# transcript grepping. Never edit this file (or sourced helpers) mid-run — bash
# keeps a file offset; inserts can abort with exit 127. Never re-pack ~/packages
# mid-run; never overlap two demo scripts on one host.
#
# Footer meanings:
#   Own line MAKE_DEMO_EXIT=0       → Layer A PASS → do Layer B
#   Own line MAKE_DEMO_EXIT=<n>     → Layer A FAIL → real product/build error
#   MAKE_DEMO_EXIT glued mid-line / no footer / log stops mid-xcodebuild
#                                   → INCOMPLETE (agent/shell kill) — re-run;
#                                     do not treat as product fail
#
# Bare $? after tee is tee's status — always use ${PIPESTATUS[0]} (or pipefail).
#
# === Layer B — after Layer A PASS only (runtime-clean) ===
#
# The demo is a single screen that runs startup init (App Check, messaging,
# module getters) then renders healthy modules. Cell green only after BOTH:
#
# 1) Build — MAKE_DEMO_EXIT=0 (iOS from-source + prebuilt RNCore, Catalyst/
#    Android as scripted).
# 2) Runtime — after Debug launch, Metro + device JS logs (Release: device only).
#    Require "AppCheck is initialized.", no fatal TypeError/RedBox from bootstrap,
#    messaging completes or fails within its bounded timeout (not hang forever).
#    On-screen module list should include appCheck after init.
#
# Write evidence (e.g. /tmp/rnfbdemo-<cell>-layerb.log) with Metro / adb logcat /
# iOS JS excerpts. Do not mark a version cell green on build exit alone.
#
# === Host cleanup (no demo) ===
#
#   ./make-demo.sh --cleanup
#   (also honored when --cleanup appears among other args)
#
# Kills whatever is listening on TCP 8081 (Metro). Does not kill Android
# emulator, iOS Simulator, or xcodebuild. Exits 0 after cleanup.
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common-functions.sh"

# Early exit: host Metro cleanup only (see header).
for __demo_arg in "$@"; do
  if [ "${__demo_arg}" = "--cleanup" ]; then
    cleanupDemoHostMetro
    exit $?
  fi
done
unset __demo_arg

RN_VER=${RN_VER:-0.86.0}
RNFB_VER=25.1.0
FB_IOS_VER=12.15.0
FB_ANDROID_VER=34.15.0
FB_GRADLE_SERVICES_VER=4.5.0
FB_GRADLE_PERF_VER=2.0.2
FB_GRADLE_CRASH_VER=3.0.7
FB_GRADLE_APP_DIST_VER=5.3.0

# This should match what you have defined in firebase console, so that
# it matches what is in your google-services.json and GoogleService-Info.plist

# These will work if you have access to the Invertase Apple Development team,
# If you do not have access to that account and want to test on real devices
# (macCatalyst to you rmac, or a real iOS device) you'll need a bundle ID that
# is unclaimed and your device will need to be registered with the XCODE_DEVELOPMENT_TEAM
# you use
FB_ANDROID_PACKAGE_NAME="com.invertase.testing"
FB_IOS_PACKAGE_NAME="io.invertase.testing"

#######################################################################################################
#######################################################################################################
# This whole section is test setup, and environment verification, it does not represent integration yet
# Test: We need to verify our environment first, so we fail fast for easily detectable things
verifyDarwinPrequisites

# Test: Previous compiles may confound future compiles, erase...
\rm -fr "$HOME/Library/Developer/Xcode/DerivedData/rnfbdemo*"

# Test: Basic template create, rnfb install, link
\rm -fr rnfbdemo

echo "Testing react-native ${RN_VER} + react-native-firebase ${RNFB_VER} + firebase-ios-sdk ${FB_IOS_VER} + firebase-android-sdk ${FB_ANDROID_VER}"

verifyLocalYarnVersion
warnIfLocalRnfbPackagesPresent

# End of test setup / environment verification section
#######################################################################################################
#######################################################################################################
#######################################################################################################
#######################################################################################################

# Okay! Let's test react-native-firebase integration! Here is how you do it.


# Initialize a fresh project.
# We say "skip-install" because we control our ruby version and cocoapods (part of install) does not like it
echo Y | yarn dlx @react-native-community/cli init rnfbdemo --pm yarn --package-name ${FB_ANDROID_PACKAGE_NAME} --skip-install --skip-git-init --version=${RN_VER}

cd rnfbdemo

# New versions of react-native include annoying Ruby stuff that forces use of old rubies. Obliterate.
if [ -f Gemfile ]; then
  rm -f Gemfile* .ruby*
fi

# RN templates pin Yarn 3.x via packageManager; Yarn 3 file: tarball installs can be stale.
# Force Yarn 4 before the first install / any local @file: adds.
ensureProjectYarnBerry4
# Classic node_modules (not PnP) — same helper as Expo; RN tooling expects node_modules.
ensureYarnNodeModulesLinker

# Now run our initial dependency install
touch yarn.lock
yarn

# Xcode 26 prerequisite: RN templates that still ship fmt 11.0.2 must bump to ≥12.1.0
# before any pod-install (Apple Clang 21 consteval). Idempotent when already patched.
ensureReactNativeFmtAtLeast

if [ "$(uname)" == "Darwin" ]; then
  echo "Setting Apple PRODUCT_BUNDLE_IDENTIFIER to ${FB_IOS_PACKAGE_NAME}"
  # It is difficult to change the Android package name, so we use it for init.
  # The iOS name is trivial though, just a PRODUCT_BUNDLE_IDENTIFIER change in pbxproj
  sed -i -e "s/${FB_ANDROID_PACKAGE_NAME}/${FB_IOS_PACKAGE_NAME}/"g ios/rnfbdemo.xcodeproj/project.pbxproj
  rm -f ios/rnfbdemo.xcodeproj/project.pbxproj-e
  # Gemfile was removed above (RN Ruby pins). Use npx pod-install, and always in a
  # subshell — `cd ios && bundle … && cd ..` left cwd in ios/ on failure (set -e does
  # not abort mid &&-list), which broke later relative AppDelegate paths.
  (cd ios && RCT_USE_RN_DEP=0 RCT_USE_PREBUILT_RNCORE=0 npm_config_yes=true npx pod-install) || \
    echo "Early template pod install skipped; will install after RNFB packages are added"
fi

# At this point we have a clean react-native project. Absolutely stock from the upstream template.

# Required: This is the most basic part of the integration - include google services plugin and call to firebase init on iOS
echo "Adding react-native-firebase core app package"
installRnfbPackage app

echo "Adding basic iOS integration - AppDelegate import and config call"
sed -i -e $'s/import UIKit/import UIKit\\\nimport FirebaseCore/' ios/rnfbdemo/AppDelegate.swift
rm -f ios/rnfbdemo/AppDelegate.swift-e
sed -i -e $'s/let delegate/FirebaseApp.configure()\\\n    let delegate/' ios/rnfbdemo/AppDelegate.swift
rm -f ios/rnfbdemo/AppDelegate.swift-e
echo "Adding basic java integration - gradle plugin dependency and call"
sed -i -e $"s/dependencies {/dependencies {\n        classpath \"com.google.gms:google-services:${FB_GRADLE_SERVICES_VER}\"/" android/build.gradle
rm -f android/build.gradle??
sed -i -e $'s/apply plugin: "com.android.application"/apply plugin: "com.android.application"\\\napply plugin: "com.google.gms.google-services"/' android/app/build.gradle
rm -f android/app/build.gradle??

#############################################################################################################
# Required: Static Frameworks linkage set up in cocoapods, and various related workarounds for compatibility.
#############################################################################################################

# You have two options here:
# - One is to dynamically turn on static frameworks with environment variables at build time
# - Two is to permanently turn on static frameworks with Podfile edits

# The default way a new react-native app is built from template uses method One, environment variables.
# I worry that some developer somewhere will not have these environment variables set correctly though,
# causing an unexpected build failure.

# So we choose option Two, where we permanently enable static frameworks in the Podfile.

# Required: turn on static frameworks with static linkage, and tell react-native-firebase that is how we are linking
sed -i -e $'s/config = use_native_modules!/config = use_native_modules!\\\n  use_frameworks! :linkage => :static\\\n  $RNFirebaseAsStaticFramework = true/' ios/Podfile
rm -f ios/Podfile??

# Required: copy your Firebase config files in - you must supply them, downloaded from firebase web console
echo "For this demo to work, you must create an \`rnfbdemo\` project in your firebase console,"
echo "then download the android json and iOS plist app definition files to the root directory"
echo "of this repository"

echo "Copying in Firebase android json and iOS plist app definition files downloaded from console"

if [ "$(uname)" == "Darwin" ]; then
  if [ -f "../GoogleService-Info.plist" ]; then
    cp ../GoogleService-Info.plist ios/rnfbdemo/
  else
    echo "Unable to locate the file 'GoogleServices-Info.plist', did you create the firebase project and download the iOS file?"
    exit 1
  fi
fi
if [ -f "../google-services.json" ]; then
  cp ../google-services.json android/app/
else
  echo "Unable to locate the file 'google-services.json', did you create the firebase project and download the android file?"
  exit 1
fi


##################################################################################################
# This section is only required for the script to work fully automatic.
# In your project you will use Xcode user interface to add your GoogleService-Info.plist file
##################################################################################################
# Set up python virtual environment so we can do some local mods to Xcode project with mod-pbxproj
# FIXME need to verify that python3 exists (recommend brew) and has venv module installed
if [ "$(uname)" == "Darwin" ]; then
  echo "Setting up python virtual environment + mod-pbxproj for Xcode project edits"
  python3 -m venv virtualenv
  # shellcheck disable=SC1091
  source virtualenv/bin/activate
  pip install pbxproj

  # Add our Google Services file to the Xcode project
  pbxproj file ios/rnfbdemo.xcodeproj rnfbdemo/GoogleService-Info.plist --target rnfbdemo

  # Toggle on iPad: add build flag: TARGETED_DEVICE_FAMILY = "1,2"
  pbxproj flag ios/rnfbdemo.xcodeproj --target rnfbdemo TARGETED_DEVICE_FAMILY "1,2"
fi
##################################################################################################


# From this point on we are adding optional modules. We test them all so we add them all. You only need to add what you need.
# First install all the modules. Modules that need more config will get that later in script
# phone-number-verification: install+autolink only — Android-only APIs, no modular
# getter/.native surface for App.tsx module list (local tarball:
# ~/packages/react-native-firebase-phone-number-verification.tgz).
NON_APP_PACKAGES="ai analytics app-check app-distribution auth crashlytics database firestore functions in-app-messaging installations messaging ml perf phone-number-verification remote-config storage"

for RNFBPKG in $NON_APP_PACKAGES; do
  echo "Adding react-native-firebase package '${RNFBPKG}'..."
  installRnfbPackage "${RNFBPKG}"
done

# Blocking: prove local tarball contents (not just semver) landed in node_modules
finalizeLocalRnfbInstalls

# Optional: Crashlytics - repo, classpath, plugin, dependency, import, init
echo "Setting up Crashlytics - package, gradle plugin"
sed -i -e $"s/dependencies {/dependencies {\n        classpath \"com.google.firebase:firebase-crashlytics-gradle:${FB_GRADLE_CRASH_VER}\"/" android/build.gradle
rm -f android/build.gradle??
sed -i -e $'s/"com.google.gms.google-services"/"com.google.gms.google-services"\\\napply plugin: "com.google.firebase.crashlytics"/' android/app/build.gradle
rm -f android/app/build.gradle??
sed -i -e $'s/proguardFiles getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro"/proguardFiles getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro"\\\n            firebaseCrashlytics {\\\n                nativeSymbolUploadEnabled true\\\n                unstrippedNativeLibsDir "build\/intermediates\/merged_native_libs\/release\/out\/lib"\\\n            }/' android/app/build.gradle
rm -f android/app/build.gradle??

# Optional: Performance - classpath, plugin, dependency, import, init
echo "Setting up Performance - package, gradle plugin"
rm -f android/app/build.gradle??
sed -i -e $"s/dependencies {/dependencies {\n        classpath \"com.google.firebase:perf-plugin:${FB_GRADLE_PERF_VER}\"/" android/build.gradle
rm -f android/build.gradle??
sed -i -e $'s/"com.google.gms.google-services"/"com.google.gms.google-services"\\\napply plugin: "com.google.firebase.firebase-perf"/' android/app/build.gradle
rm -f android/app/build.gradle??

# Optional: App Distribution - classpath, plugin, dependency, import, init
echo "Setting up App Distribution - package, gradle plugin"
sed -i -e $"s/dependencies {/dependencies {\n        classpath \"com.google.firebase:firebase-appdistribution-gradle:${FB_GRADLE_APP_DIST_VER}\"/" android/build.gradle
rm -f android/build.gradle??
sed -i -e $'s/"com.google.gms.google-services"/"com.google.gms.google-services"\\\napply plugin: "com.google.firebase.appdistribution"/' android/app/build.gradle
rm -f android/app/build.gradle??

# Required for Firestore - android build tweak - or gradle runs out of memory during the build
# ensureGradleJvmArgs: avoid gluing onto a last line that lacks a trailing newline
echo "Increasing memory available to gradle for android java build"
ensureGradleJvmArgs android/gradle.properties "org.gradle.jvmargs=-Xmx3072m -Dfile.encoding=UTF-8"

# I'm not going to demonstrate messaging and notifications. Everyone gets it wrong because it's hard. 
# You've got to read the docs and test *EVERYTHING* one feature at a time.
# But you have to do a *lot* of work in the AndroidManifest.xml, and make sure your MainActivity *is* the launch intent receiver
# I include it for compile testing only.

# Optional: do you want to configure firebase behavior via firebase.json?
echo "Creating default firebase.json (with settings that allow iOS crashlytics to report crashes even in debug mode)"
printf "{\n  \"react-native\": {\n    \"crashlytics_disable_auto_disabler\": true,\n    \"crashlytics_debug_enabled\": true\n  }\n}" > firebase.json

# Optional: allow explicit SDK version control by specifying our iOS Pods and Android Firebase Bill of Materials
echo "Adding upstream SDK overrides for precise version control"
echo "project.ext{set('react-native',[versions:[firebase:[bom:'${FB_ANDROID_VER}'],],])}" >> android/build.gradle
sed -i -e $"s/target 'rnfbdemo' do/\$FirebaseSDKVersion = '${FB_IOS_VER}'\ntarget 'rnfbdemo' do/" ios/Podfile
rm -f ios/Podfile??

# Optional: build performance - use pre-built version of Firestore - https://github.com/invertase/firestore-ios-sdk-frameworks
# If you are using firestore and database you *may* end up with duplicate symbol build errors referencing "leveldb", the FirebaseFirestoreExcludeLeveldb boolean fixes that.
#sed -i -e $'s/target \'rnfbdemo\' do/target \'rnfbdemo\' do\\\n  $FirebaseFirestoreExcludeLeveldb = true\\\n  pod \'FirebaseFirestore\', :git => \'https:\\/\\/github.com\\/invertase\\/firestore-ios-sdk-frameworks.git\', :tag => $FirebaseSDKVersion\\\n/' ios/Podfile
#rm -f ios/Podfile??

# Required for AppCheck on iOS (docs-faithful): bridging header + sharedInstance before FirebaseApp.configure().
# Do NOT add `import RNFBAppCheck` in Swift — the pod is Obj-C only and does not produce a Swift module.
# Match: docs/app-check/usage (RN >= 0.77) and packages/app-check Expo plugin bridging-header flow.
echo "Adding AppCheck iOS integration - bridging header and AppDelegate sharedInstance()"
BRIDGING_HEADER="ios/rnfbdemo/rnfbdemo-Bridging-Header.h"
if [ ! -f "${BRIDGING_HEADER}" ]; then
  cat > "${BRIDGING_HEADER}" <<'EOF'
//
// Use this file to import your target's public headers that you would like to expose to Swift.
//
EOF
fi
if ! grep -q 'RNFBAppCheckModule.h' "${BRIDGING_HEADER}"; then
  printf '\n#import "RNFBAppCheckModule.h"\n' >> "${BRIDGING_HEADER}"
fi
if [ "$(uname)" == "Darwin" ]; then
  # Stock RN 0.86 template has no bridging header / SWIFT_OBJC_BRIDGING_HEADER — set both.
  if ! grep -q 'SWIFT_OBJC_BRIDGING_HEADER' ios/rnfbdemo.xcodeproj/project.pbxproj; then
    pbxproj flag ios/rnfbdemo.xcodeproj --target rnfbdemo SWIFT_OBJC_BRIDGING_HEADER "rnfbdemo/rnfbdemo-Bridging-Header.h"
  fi
fi
# Insert sharedInstance before existing FirebaseApp.configure(); never `import RNFBAppCheck`
sed -i -e '/^import RNFBAppCheck$/d' ios/rnfbdemo/AppDelegate.swift
rm -f ios/rnfbdemo/AppDelegate.swift-e
if ! grep -q 'RNFBAppCheckModule.sharedInstance' ios/rnfbdemo/AppDelegate.swift; then
  sed -i -e $'s/FirebaseApp.configure/RNFBAppCheckModule.sharedInstance()\\\n    FirebaseApp.configure/' ios/rnfbdemo/AppDelegate.swift
  rm -f ios/rnfbdemo/AppDelegate.swift-e
fi

# Optional: build performance optimization to use ccache - asks xcodebuild to use clang and clang++ without the fully-qualified path
# That means that you can then make a symlink in your path with clang or clang++ and have it use a different binary
# In that way you can install ccache or buildcache and get much faster compiles...
sed -i -e $'s/# :ccache_enabled/:ccache_enabled/' ios/Podfile
rm -f ios/Podfile??
# The built-in react-native ccache configuration does not work well, but
# my local one works great - use it
if [ -e ~/.ccache/ccache.conf ]; then
  echo "Using local ccache.conf in preference to built-in react-native conf"
  export CCACHE_CONFIGPATH=~/.ccache/ccache.conf
fi

# Optional: Cleaner build logs - libevent pulled in by react core items are ridiculously noisy otherwise
sed -i -e $'s/post_install do |installer|/post_install do |installer|\\\n    installer.pods_project.targets.each do |target|\\\n      target.build_configurations.each do |config|\\\n        config.build_settings["GCC_WARN_INHIBIT_ALL_WARNINGS"] = "YES"\\\n      end\\\n    end\\\n/' ios/Podfile
rm -f ios/Podfile??

# Test: Copy in our demonstrator App.tsx and index.js
echo "Copying demonstrator App.tsx and index.js"
rm ./App.tsx ./index.js && cp ../App.tsx ./App.tsx && cp ../index.js ./index.js

# Test: You have to re-run patch-package after yarn since it is not integrated into postinstall
echo "Running any patches necessary to compile successfully"
cp -rv ../patches .
npm_config_yes=true npx patch-package

# Re-assert fmt ≥12.1.0 after package adds / patches (no-op if already current).
ensureReactNativeFmtAtLeast

# Test: Run the thing for iOS
if [ "$(uname)" == "Darwin" ]; then

  #################################################################################################
  # This section is so the script may work fully automatic.
  # If you are targeting macCatalyst, you will use the Xcode UI to add your development team.
  # add file rnfbdemo/rnfbdemo.entitlements, with reference to rnfbdemo target, but no build phase
  echo "Adding macCatalyst entitlements file / build flags to Xcode project"
  cp ../rnfbdemo.entitlements ios/rnfbdemo/
  pbxproj file ios/rnfbdemo.xcodeproj rnfbdemo/rnfbdemo.entitlements --target rnfbdemo -C
  # add build flag: CODE_SIGN_ENTITLEMENTS = rnfbdemo/rnfbdemo.entitlements
  pbxproj flag ios/rnfbdemo.xcodeproj --target rnfbdemo CODE_SIGN_ENTITLEMENTS rnfbdemo/rnfbdemo.entitlements
  # add build flag: SUPPORTS_MACCATALYST = YES
  pbxproj flag ios/rnfbdemo.xcodeproj --target rnfbdemo SUPPORTS_MACCATALYST YES
  # for local signing / no dev team: add build flag 				CODE_SIGN_IDENTITY = "-";
  pbxproj flag ios/rnfbdemo.xcodeproj --target rnfbdemo CODE_SIGN_IDENTITY "-"
  # Only "-" may be added by pbxproj (it cannot handle ""), but only "" works. Adjust it.
  sed -i -e $'s/CODE_SIGN_IDENTITY = "-"/CODE_SIGN_IDENTITY = ""/g' ios/rnfbdemo.xcodeproj/project.pbxproj
  rm -f ios/rnfbdemo.xcodeproj/project.pbxproj??

  # These are the background modes you need for push notifications and processing (just in case)
  /usr/libexec/PlistBuddy -c "Add :UIBackgroundModes array" ios/rnfbdemo/Info.plist 
  /usr/libexec/PlistBuddy -c "Add :UIBackgroundModes:0 string fetch" ios/rnfbdemo/Info.plist 
  /usr/libexec/PlistBuddy -c "Add :UIBackgroundModes:0 string processing" ios/rnfbdemo/Info.plist 
  /usr/libexec/PlistBuddy -c "Add :UIBackgroundModes:0 string remote-notification" ios/rnfbdemo/Info.plist 


  echo "Installing pods and running iOS app in debug mode"
  pod repo update

  # Let's do one round with non-prebuilts (a react-native 0.81+ feature)
  export RCT_USE_RN_DEP=0
  export RCT_USE_PREBUILT_RNCORE=0
  npm_config_yes=true npx pod-install

  # Check iOS debug mode compile then release mode
  # Non-TTY agents cannot spawn Metro in a new window; ensure packager is up first.
  ensureMetroPackagerRunning
  echo "Running iOS app in debug mode"
  ensureHermesEngineConfiguration Debug
  ensurePrebuiltRncoreConfiguration Debug
  npx react-native run-ios --mode Debug --simulator "iPhone 17" --no-packager
  echo "Running iOS app in release mode"
  # Prebuilt Hermes Debug→Release (and back) must swap outside xcodebuild so
  # Debug reacthermes (HERMES_ENABLE_DEBUGGER) never links Release hermesvm
  # (no facebook::hermes::cdp::*). Same serial pattern as RNCore below.
  # Prebuilt RNCore Debug→Release must swap tarballs outside xcodebuild (RN 0.87+
  # race: in-Xcode replace deletes Headers/module.modulemap while other pods compile).
  ensureHermesEngineConfiguration Release
  ensurePrebuiltRncoreConfiguration Release
  npx react-native run-ios --mode Release --simulator "iPhone 17" --no-packager

  # Now Let's do a round with prebuilts (a react-native 0.81+ feature)
  export RCT_USE_RN_DEP=1
  export RCT_USE_PREBUILT_RNCORE=1
  npm_config_yes=true npx pod-install

  # Check iOS debug mode compile then release mode
  ensureMetroPackagerRunning
  echo "Running iOS app in debug mode"
  ensureHermesEngineConfiguration Debug
  ensurePrebuiltRncoreConfiguration Debug
  npx react-native run-ios --mode Debug --simulator "iPhone 17" --no-packager
  echo "Running iOS app in release mode"
  ensureHermesEngineConfiguration Release
  ensurePrebuiltRncoreConfiguration Release
  npx react-native run-ios --mode Release --simulator "iPhone 17" --no-packager

  # Check catalyst build

  # Required for macCatalyst: Podfile workarounds for signing and library paths are built-in 0.70+ with a specific flag:
  sed -i -e $'s/mac_catalyst_enabled => false/mac_catalyst_enabled => true/' ios/Podfile
  rm -f ios/Podfile??

  ####################################################################################
  # macCatalyst requires a workaround to disable 'GoogleAdsOnDeviceConversion' Pod
  # https://github.com/firebase/firebase-ios-sdk/issues/14995#issuecomment-3017883367
  # shellcheck disable=SC2016
  sed -e ':a' -e 'N' -e '$!ba' -e 's/ccache_enabled => true\n    )/ccache_enabled => true\n    )\n\n    # Exclude GoogleAdsOnDeviceConversion from macCatalyst builds\n    installer.pods_project.targets.each do |target|\n      libs = ["GoogleAdsOnDeviceConversion"]\n\n      target.build_configurations.each do |config|\n        xcconfig_path = config.base_configuration_reference.real_path\n        xcconfig = File.read(xcconfig_path)\n        values = ""\n\n        libs.each { |lib|\n          if xcconfig["-framework \\"#{lib}\\""]\n            puts "Found #{lib} on target #{target.name}"\n            xcconfig.sub!(" -framework \\"#{lib}\\"", "")\n            values += " -framework \\"#{lib}\\""\n          end\n        }\n\n        if values.length > 0\n          puts "Preparing #{target.name} for Catalyst\\n\\n"\n          new_xcconfig = xcconfig + "OTHER_LDFLAGS[sdk=iphone*] = $(inherited)" + values\n          File.open(xcconfig_path, "w") { |file| file << new_xcconfig }\n        end\n      end\n    end/g' ios/Podfile > ios/Podfile-e
  mv -f ios/Podfile-e ios/Podfile

  # Let's do one round with non-prebuilts (a react-native 0.81+ feature)
  export RCT_USE_RN_DEP=0
  export RCT_USE_PREBUILT_RNCORE=0
  echo "Installing pods and running iOS app in macCatalyst mode"
  npm_config_yes=true npx pod-install

  # Now run it with our mac device udid as device target, that triggers catalyst build

  # For some reason, the device id returned if you use the computer name is wrong.
  # It is also wrong from ios-deploy or xcrun xctrace list devices
  # The only way I have found to get the right ID is to provide the wrong one then parse out the available one
  # This requires a CLI patch to the iOS platform to accept a UDID it cannot probe, and to set type to catalyst
  # https://github.com/react-native-community/cli/pull/2642
  CATALYST_DESTINATION=$(xcodebuild -workspace ios/rnfbdemo.xcworkspace -configuration Debug -scheme rnfbdemo -destination id=7153382A-C92B-5798-BEA3-D82D195F25F8 2>&1|grep macOS|grep Catalyst|head -1 |cut -d':' -f5 |cut -d' ' -f1 |cut -d',' -f1)
  # After prior Release iOS, hermes-engine destroot is Release (no CDP). Catalyst
  # Debug must serially restore Debug Hermes before xcodebuild or app link fails.
  ensureHermesEngineConfiguration Debug
  npx react-native run-ios --udid "$CATALYST_DESTINATION" --mode Debug --no-packager

  # Let's do one round with prebuilts (a react-native 0.81+ feature)
  export RCT_USE_RN_DEP=1
  export RCT_USE_PREBUILT_RNCORE=1
  echo "Installing pods and running iOS app in macCatalyst mode"
  npm_config_yes=true npx pod-install
  ensureHermesEngineConfiguration Debug
  ensurePrebuiltRncoreConfiguration Debug
  npx react-native run-ios --udid "$CATALYST_DESTINATION" --mode Debug --no-packager

  ####################################################################################

  # Optional: workaround for poorly setup Android SDK environments on macs
  USER=$(whoami)
  echo "sdk.dir=/Users/$USER/Library/Android/sdk" > android/local.properties
fi

# Test: make sure proguard works
echo "Configuring Android release build for ABI splits and code shrinking"
sed -i -e $'s/def enableProguardInReleaseBuilds = false/def enableProguardInReleaseBuilds = true/' android/app/build.gradle
rm -f android/app/build.gradle??

# Test: If we are on WSL the user needs to now run it from the Windows side
# Getting it to run from WSL is a real mess (it is possible, but not recommended)
# So we will stop now that we've done all the installation and file editing
if [ "$(uname -a | grep Linux | grep -c microsoft)" == "1" ]; then
  echo "Detected Windows Subsystem for Linux. Stopping now."

  # Windows has some sort of gradle error with gradle-8.10.2 but gradle 8.12 works
  # "java.io.UncheckedIOException: Could not move temporary workspace"
  sed -i -e $'s/8.10.2/8.12/' android/gradle/gradle-wrapper.properties
  rm -f android/gradle/gradle-wrapper.properties

  # Clear out the unix-y node_modules
  \rm -fr node_modules
  echo "To run the app use Windows Powershell in the rnfbdemo directory with these commands:"
  echo "npm i"
  echo "npx react-native run-android --mode debug"
  exit
fi

# Test: uninstall it (just in case, otherwise ABI-split-generated version codes will prevent debug from installing)
pushd android
./gradlew uninstallRelease
popd

# Test: Run it for Android (assumes you have an android emulator running)
echo "Running android app in release mode"
npx react-native run-android --mode release

# Test: Let it start up, then uninstall it (otherwise ABI-split-generated version codes will prevent debug from installing)
sleep 30
pushd android
./gradlew uninstallRelease
popd

# Test: may or may not be commented out, depending on if have an emulator available
# I run it manually in testing when I have one, comment if you like
echo "Running android app in debug mode"
npx react-native run-android --mode debug


# new architecture put this in android/gradle.properties +newArchEnabled=true
