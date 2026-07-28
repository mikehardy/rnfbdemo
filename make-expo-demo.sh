#!/bin/bash
set -e

# ---------------------------------------------------------------------------
# Success criteria + how agents should run/poll this script (durable)
#
# This script automates Expo + RNFB integration: template create, install, native
# project, and platform runs. A zero exit means compile, install, and process
# start succeeded — necessary, not sufficient.
#
# Wall-clock: often tens of minutes (pods/gradle + iOS/Android). Long enough to
# kill a chatty agent that polls with repeated long AwaitShell / milestone greps
# ([resource_exhausted]) and tears the tee mid-build (garbage MAKE_DEMO_EXIT
# glued mid-line). Same playbook as make-demo.sh.
#
# === Layer A — run exactly like this (one shell owns the process) ===
#
#   cd <rnfbdemo-repo>
#   # Preflight: AVD up; port 8081 free; login keychain unlocked; no other
#   # make-expo-demo/xcodebuild. Optional if yarn dlx fails under Cursor:
#   #   unset YARN_CACHE_FOLDER YARN_ENABLE_GLOBAL_CACHE NPM_CONFIG_CACHE
#   EXPO_VER=<sdk> ./make-expo-demo.sh 2>&1 | tee /tmp/rnfbdemo-<cell>.log
#   echo MAKE_DEMO_EXIT=${PIPESTATUS[0]} | tee -a /tmp/rnfbdemo-<cell>.log
#
# Prefer one Shell call that blocks until finish (block_until_ms ~1–2h,
# required_permissions: ["all"]). If backgrounded, poll ONLY for a standalone
# line matching ^MAKE_DEMO_EXIT= — sparse checks (minutes apart). Never edit
# this file (or sourced helpers) mid-run. Never re-pack ~/packages mid-run;
# never overlap two demo scripts on one host.
#
# Footer meanings: same as make-demo.sh — own-line MAKE_DEMO_EXIT=0 PASS;
# nonzero FAIL; glued/missing footer = INCOMPLETE → re-run, not product fail.
# Always use ${PIPESTATUS[0]} after tee (bare $? is tee status).
#
# === Layer B — after Layer A PASS only (runtime-clean) ===
#
# Cell green only after BOTH:
#
# 1) Build — MAKE_DEMO_EXIT=0 for the Expo SDK under test.
# 2) Runtime — after Debug launch, Metro + device JS logs (Release: device only).
#    Require "AppCheck is initialized.", no fatal TypeError/RedBox from bootstrap,
#    messaging completes or fails within its bounded timeout (not hang forever).
#    On-screen module list should include appCheck after init.
#
# Write evidence (e.g. /tmp/rnfbdemo-<cell>-layerb.log). Do not mark a cell
# green on build exit alone. Dual RNCore: only if the Expo/RN template surfaces
# RCT_USE_PREBUILT_RNCORE; otherwise document n/a and run stock path once.
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common-functions.sh"

EXPO_VER=${EXPO_VER:-55}
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
# Prepare: We need to verify our environment first, so we fail fast for easily detectable things
verifyDarwinPrequisites
verifyLocalYarnVersion
verifyJqVersion

# Prepare: Clean up previous compiles and local directory
\rm -fr "$HOME/Library/Developer/Xcode/DerivedData/rnfbexpodemo*"
\rm -fr rnfbexpodemo

# Test: Basic template create, rnfb install, link
echo "Testing expo ${EXPO_VER} + react-native-firebase ${RNFB_VER} + firebase-ios-sdk ${FB_IOS_VER} + firebase-android-sdk ${FB_ANDROID_VER}"

warnIfLocalRnfbPackagesPresent

# End of test setup / environment verification section
#######################################################################################################
#######################################################################################################
#######################################################################################################
#######################################################################################################



# Let's test react-native-firebase +expo integration! Here is how you do it.


# Initialize a fresh project.
# Docs: https://docs.expo.dev/more/create-expo — during the SDK 57 transition use
# `--template default@sdk-N` (not bare create / not expo-template-default@N alone).
# Pass the app name as argv; --yes + CI=1 accept defaults and skip the nested-git
# prompt when run inside this repo. Prefer npx over `yarn dlx`: create-expo-app@4.0.0
# template extract via yarn dlx fails on Node 24 with ERR_INVALID_ARG_TYPE
# (ReadableStream vs Buffer/string). --no-install avoids npm install/package-lock;
# we force Yarn 4 and install below.
CI=1 npm_config_yes=true npx create-expo-app@latest rnfbexpodemo --template "default@sdk-${EXPO_VER}" --yes --no-install

cd rnfbexpodemo

# Templates may pin Yarn 3.x; force Yarn 4 before file: installs (content-hashed).
ensureProjectYarnBerry4
# Expo CLI expects node_modules (not PnP); set before first yarn.
ensureYarnNodeModulesLinker

# Now run our initial dependency install
touch yarn.lock
yarn

# Xcode 26 prerequisite: Expo templates that pull RN with fmt 11.0.2 must bump to
# ≥12.1.0 before prebuild/pod-install (Apple Clang 21 consteval). Idempotent when OK.
ensureReactNativeFmtAtLeast

# Fixes and workarounds:

# For Expo 53, we need to add react-native-edge-to-edge or android has a compile error
if [[ "$EXPO_VER" == *"53"* ]]; then
  echo "Explicitly adding react-native-edge-to-edge to Expo 53 for Android build to work..."
  npx expo add react-native-edge-to-edge
fi

# Need to edit all the app.json stuff here
cat app.json | jq --arg FB_IOS_PACKAGE_NAME "$FB_IOS_PACKAGE_NAME" '.expo.ios.bundleIdentifier |= $FB_IOS_PACKAGE_NAME' > app.json.tmp && mv -f app.json.tmp app.json
cat app.json | jq '.expo.ios.googleServicesFile |= "./GoogleService-Info.plist"' > app.json.tmp && mv -f app.json.tmp app.json
cat app.json | jq --arg FB_ANDROID_PACKAGE_NAME "$FB_ANDROID_PACKAGE_NAME" '.expo.android.package |= $FB_ANDROID_PACKAGE_NAME' > app.json.tmp && mv -f app.json.tmp app.json
cat app.json | jq '.expo.android.googleServicesFile |= "./google-services.json"' > app.json.tmp && mv -f app.json.tmp app.json


# At this point we have a clean react-native project. Absolutely stock from the upstream template.

# Required: This is the most basic part of the integration - all react-native-firebase apps require the app package
echo "Adding react-native-firebase core app package"
installRnfbPackage app


#############################################################################################################
# Required: Static Frameworks linkage set up in cocoapods, and various related workarounds for compatibility.
#############################################################################################################

# Here is how to configure the static frameworks linking that firebase-ios-sdk requires:
# 1- install the expo-build-properties package
npm_config_yes=true npx expo install expo-build-properties
# 2- remove the bare "expo-build-properties" app.json entry created by just installing the package
cat app.json | jq '.expo.plugins |= map(select(index("expo-build-properties")|not))' > app.json.tmp && mv -f app.json.tmp app.json
# 3- Now add expo-build-properties as the FIRST config plugin, with configuration (the jq syntax here prepends it, so it is first)
cat app.json | jq '.expo.plugins |= [["expo-build-properties", {"ios": {"forceStaticLinking": ["RNFBApp"], "useFrameworks": "static", "ccacheEnabled": true }}]] + .' > app.json.tmp && mv -f app.json.tmp app.json

# Now lets add our config plugin for app:
cat app.json | jq '.expo.plugins += ["@react-native-firebase/app"]' > app.json.tmp && mv -f app.json.tmp app.json

# Required: copy your Firebase config files in - you must supply them, downloaded from firebase web console
echo "For this demo to work, you must create an \`rnfbdemo\` project in your firebase console,"
echo "then download the android json and iOS plist app definition files to the root directory"
echo "of this repository"

echo "Copying in Firebase android json and iOS plist app definition files downloaded from console"

if [ "$(uname)" == "Darwin" ]; then
  if [ -f "../GoogleService-Info.plist" ]; then
    cp ../GoogleService-Info.plist ./
  else
    echo "Unable to locate the file 'GoogleServices-Info.plist', did you create the firebase project and download the iOS file?"
    exit 1
  fi
fi
if [ -f "../google-services.json" ]; then
  cp ../google-services.json ./
else
  echo "Unable to locate the file 'google-services.json', did you create the firebase project and download the android file?"
  exit 1
fi

# From this point on we are adding optional modules. We test them all so we add them all. You only need to add what you need.
# First set up all the modules that need no further config for the demo 
NON_APP_PACKAGES="ai analytics app-check app-distribution auth crashlytics database firestore functions in-app-messaging installations messaging ml perf remote-config storage"

for RNFBPKG in $NON_APP_PACKAGES; do
  echo "Adding react-native-firebase package '${RNFBPKG}'..."
  installRnfbPackage "${RNFBPKG}"

  # If this react-native-firebase package has an Expo plugin, add it to app.json
  if [ -e "./node_modules/@react-native-firebase/${RNFBPKG}/app.plugin.js" ]; then
    echo "Info: Found Expo Config Plugin for ${RNFBPKG}, adding to plugin config..."
    cat app.json | jq --arg RNFBPKG "@react-native-firebase/$RNFBPKG" '.expo.plugins += [$RNFBPKG]' > app.json.tmp && mv -f app.json.tmp app.json
  fi

  # If native pod exists, get Pod name from podspec and add to forceStaticLinking config
  if ! ls ./node_modules/@react-native-firebase/${RNFBPKG}/*.podspec > /dev/null 2>&1; then
    echo "Info: No native Apple CocoaPod for ${RNFBPKG}, continuing..."
  else
    echo "Info: Found native Apple CocoaPod ${RNFB_POD_NAME} for ${RNFBPKG}. Configuring static linking..."
    RNFB_POD_NAME=$(cat ./node_modules/@react-native-firebase/${RNFBPKG}/*.podspec|grep '\.name.*=.*RNFB'|cut -d'"' -f2)
    cat app.json | jq --arg RNFB_POD_NAME "$RNFB_POD_NAME" '.expo.plugins[0][1].ios.forceStaticLinking += [$RNFB_POD_NAME]' > app.json.tmp && mv -f app.json.tmp app.json
  fi

done

# Blocking: prove local tarball contents (not just semver) landed in node_modules
finalizeLocalRnfbInstalls

# Optional: do you want to configure firebase behavior via firebase.json?
echo "Creating default firebase.json (with settings that allow iOS crashlytics to report crashes even in debug mode)"
printf "{\n  \"react-native\": {\n    \"crashlytics_disable_auto_disabler\": true,\n    \"crashlytics_debug_enabled\": true\n  }\n}" > firebase.json

# Optional: allow explicit SDK version control by specifying our iOS Pods and Android Firebase Bill of Materials

# TODO - demonstrate firebase-ios-sdk version pin in Expo context
# It uses an environment variable
#echo "Adding upstream SDK overrides for precise version control"
#echo "project.ext{set('react-native',[versions:[firebase:[bom:'${FB_ANDROID_VER}'],],])}" >> android/build.gradle
#sed -i -e $"s/target 'rnfbdemo' do/\$FirebaseSDKVersion = '${FB_IOS_VER}'\ntarget 'rnfbdemo' do/" ios/Podfile
#rm -f ios/Podfile??

# Test: Copy in our demonstrator App file (Expo drops it into first spot on a tabbed nav)
echo "Copying demonstrator App.tsx..."
rm -f './src/app/index.tsx' && cp ../App.tsx './src/app/index.tsx'

# Test: You have to re-run patch-package after yarn since it is not integrated into postinstall
echo "Running any patches necessary to compile successfully"
# cp -rv ../patches .
# npm_config_yes=true npx patch-package

# Re-assert fmt ≥12.1.0 after package adds (no-op if already current) before prebuild pods.
ensureReactNativeFmtAtLeast

echo "Running expo prebuild..."
npx expo prebuild

# Android builds fail lintVitalRelease out of the box with OutOfMemory, increase it
# There are a few ways to configure gradle, including modifying your global ~/.gradle/gradle.properties file
# This script should be self-contained though so we modify things internally.
# Use ensureGradleJvmArgs: Expo prebuild may omit a trailing newline on the last
# gradle.properties line; raw `echo >>` would glue jvmargs onto that line.
echo "Increasing memory available to gradle for android java build"
ensureGradleJvmArgs android/gradle.properties "org.gradle.jvmargs=-Xmx4092m -Dfile.encoding=UTF-8"

# Non-TTY agents cannot spawn Metro via open/new Terminal; ensure packager is up first.
# expo run:* --no-bundler is the Expo equivalent of react-native --no-packager.
ensureMetroPackagerRunning

# Test: Run on web (macOS-specific URL open command, PRs welcome for other platforms)
if [ "$(uname)" == "Darwin" ]; then
  # If AI is imported on web currently, you get "Cannot access 'Backend' before initialization"
  # This seems to be a bundling error where Backend is indeed referenced in the metro bundle prior to its definition.
  sed -i -e $'s|import { getAI |//import { getAI |' src/app/index.tsx
  rm -f src/app/index.tsx??

  echo "Opening web app..."
  open http://localhost:8081

  # The web app will blow up once we re-configure it for native, allow time for a look
  sleep 10

  # Re-enable AI for other platforms
  sed -i -e $'s|//import { getAI |import { getAI |' src/app/index.tsx
  rm -f src/app/index.tsx??

fi

# Test: Run the thing for iOS
if [ "$(uname)" == "Darwin" ]; then

  # TODO, demonstrate adding entitlements using Expo app.json items
  # These are the background modes you need for push notifications and processing (just in case)
  # /usr/libexec/PlistBuddy -c "Add :UIBackgroundModes array" ios/rnfbdemo/Info.plist 
  # /usr/libexec/PlistBuddy -c "Add :UIBackgroundModes:0 string fetch" ios/rnfbdemo/Info.plist 
  # /usr/libexec/PlistBuddy -c "Add :UIBackgroundModes:0 string processing" ios/rnfbdemo/Info.plist 
  # /usr/libexec/PlistBuddy -c "Add :UIBackgroundModes:0 string remote-notification" ios/rnfbdemo/Info.plist 

  # Expo CLI activate-window uses System Events; agents denying Automation TCC get -1743
  # after a successful build/install. Boot via simctl + open -a Simulator, then fall back
  # to simctl launch if Expo still trips on that activate path (see common-functions.sh).
  echo "Running iOS app in debug mode"
  runExpoIosDebugWithoutSystemEventsTcc "${FB_IOS_PACKAGE_NAME}" "iPhone 17"

  # TODO Check iOS release mode compile
  # echo "Installing pods and running iOS app in release mode"
  # npx react-native run-ios --mode Release --simulator "iPhone 17"

  # TODO Check catalyst build

  # Required for macCatalyst: Podfile workarounds for signing and library paths are built-in 0.70+ with a specific flag:
  # sed -i -e $'s/mac_catalyst_enabled => false/mac_catalyst_enabled => true/' ios/Podfile
  # rm -f ios/Podfile??

  ####################################################################################
  # macCatalyst requires a workaround to disable 'GoogleAdsOnDeviceConversion' Pod
  # https://github.com/firebase/firebase-ios-sdk/issues/14995#issuecomment-3017883367
  # shellcheck disable=SC2016
  # sed -e ':a' -e 'N' -e '$!ba' -e 's/ccache_enabled => true\n    )/ccache_enabled => true\n    )\n\n    # Exclude GoogleAdsOnDeviceConversion from macCatalyst builds\n    installer.pods_project.targets.each do |target|\n      libs = ["GoogleAdsOnDeviceConversion"]\n\n      target.build_configurations.each do |config|\n        xcconfig_path = config.base_configuration_reference.real_path\n        xcconfig = File.read(xcconfig_path)\n        values = ""\n\n        libs.each { |lib|\n          if xcconfig["-framework \\"#{lib}\\""]\n            puts "Found #{lib} on target #{target.name}"\n            xcconfig.sub!(" -framework \\"#{lib}\\"", "")\n            values += " -framework \\"#{lib}\\""\n          end\n        }\n\n        if values.length > 0\n          puts "Preparing #{target.name} for Catalyst\\n\\n"\n          new_xcconfig = xcconfig + "OTHER_LDFLAGS[sdk=iphone*] = $(inherited)" + values\n          File.open(xcconfig_path, "w") { |file| file << new_xcconfig }\n        end\n      end\n    end/g' ios/Podfile > ios/Podfile-e
  # mv -f ios/Podfile-e ios/Podfile

  # echo "Installing pods and running iOS app in macCatalyst mode"
  # npm_config_yes=true npx pod-install

  # Now run it with our mac device udid as device target, that triggers catalyst build

  # For some reason, the device id returned if you use the computer name is wrong.
  # It is also wrong from ios-deploy or xcrun xctrace list devices
  # The only way I have found to get the right ID is to provide the wrong one then parse out the available one
  # This requires a CLI patch to the iOS platform to accept a UDID it cannot probe, and to set type to catalyst
  # https://github.com/react-native-community/cli/pull/2642
  # CATALYST_DESTINATION=$(xcodebuild -workspace ios/rnfbdemo.xcworkspace -configuration Debug -scheme rnfbdemo -destination id=7153382A-C92B-5798-BEA3-D82D195F25F8 2>&1|grep macOS|grep Catalyst|head -1 |cut -d':' -f5 |cut -d' ' -f1 |cut -d',' -f1)
  # npx react-native run-ios --udid "$CATALYST_DESTINATION" --mode Debug
  ####################################################################################

  # Optional: workaround for poorly setup Android SDK environments on macs
  # USER=$(whoami)
  # echo "sdk.dir=/Users/$USER/Library/Android/sdk" > android/local.properties
fi

# Test: make sure proguard works
# echo "Configuring Android release build for ABI splits and code shrinking"
# sed -i -e $'s/def enableProguardInReleaseBuilds = false/def enableProguardInReleaseBuilds = true/' android/app/build.gradle
# rm -f android/app/build.gradle??

# Test: If we are on WSL the user needs to now run it from the Windows side
# Getting it to run from WSL is a real mess (it is possible, but not recommended)
# So we will stop now that we've done all the installation and file editing
if [ "$(uname -a | grep Linux | grep -c microsoft)" == "1" ]; then
  echo "Detected Windows Subsystem for Linux. Stopping now."

  # Windows has some sort of gradle error with gradle-8.10.2 but gradle 8.12 works
  # "java.io.UncheckedIOException: Could not move temporary workspace"
  # sed -i -e $'s/8.10.2/8.12/' android/gradle/gradle-wrapper.properties
  # rm -f android/gradle/gradle-wrapper.properties

  # Clear out the unix-y node_modules
  \rm -fr node_modules
  echo "To run the app use Windows Powershell in the rnfbdemo directory with these commands:"
  echo "npm i"
  echo "npx expo run:android --variant debug --no-bundler"
  exit
fi

# Test: uninstall it (just in case, otherwise ABI-split-generated version codes will prevent debug from installing)
# pushd android
# ./gradlew uninstallRelease
# popd

# Test: Run it for Android (assumes you have an android emulator running)
# echo "Running android app in release mode"
# npx expo run:android --variant release

# Test: Let it start up, then uninstall it (otherwise ABI-split-generated version codes will prevent debug from installing)
# sleep 30
# pushd android
# ./gradlew uninstallRelease
# popd

# Test: may or may not be commented out, depending on if have an emulator available
# I run it manually in testing when I have one, comment if you like
echo "Running android app in debug mode"
npx expo run:android --variant debug --no-bundler
