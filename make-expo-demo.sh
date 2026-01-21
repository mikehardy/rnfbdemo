#!/bin/bash
set -e 

source ./common-functions.sh

EXPO_VER=54
RNFB_VER=23.8
FB_IOS_VER=12.8.0
FB_ANDROID_VER=34.7.0
FB_GRADLE_SERVICES_VER=4.4.4
FB_GRADLE_PERF_VER=2.0.2
FB_GRADLE_CRASH_VER=3.0.6
FB_GRADLE_APP_DIST_VER=5.2.0

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

#######################################################################################################
#######################################################################################################



# Let's test react-native-firebase +expo integration! Here is how you do it.


# Initialize a fresh project.
echo rnfbexpodemo | yarn dlx create-expo-app@latest --template expo-template-default@${EXPO_VER}

cd rnfbexpodemo

# Now run our initial dependency install
touch yarn.lock
yarn

# Fixes and workarounds:
# 1- We need to update react-native-screens or it has an android compile error
# TEST - I don't think this is necessary with expo@~54 (current version), was just 54.0.0...
# if [[ "$EXPO_VER" == *"54"* ]]; then
#   echo "Explicitly adding react-native-screens updated version to Expo 54 for Android build to work..."
#   npx expo add react-native-screens
# fi

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
if [ -e $HOME/packages/react-native-firebase-app.tgz ]; then
  yarn add @react-native-firebase/app@file:$HOME/packages/react-native-firebase-app.tgz
else
 yarn add "@react-native-firebase/app@${RNFB_VER}"
fi


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

# TODO - temporarily ignoring app-check on Expo 54 - the config plugin runs successfully but `import RNFBAppCheck` fails in AppDelegate.swift
NON_APP_PACKAGES="ai analytics app-distribution auth crashlytics database firestore functions in-app-messaging installations messaging ml perf remote-config storage"
if [[ "$EXPO_VER" == *"53"* ]]; then
  NON_APP_PACKAGES="${NON_APP_PACKAGES} app-check"
fi

for RNFBPKG in $NON_APP_PACKAGES; do
  echo "Adding react-native-firebase package '${RNFBPKG}'..."
  if [ -e $HOME/packages/react-native-firebase-${RNFBPKG}.tgz ]; then
    yarn add @react-native-firebase/${RNFBPKG}@file:$HOME/packages/react-native-firebase-${RNFBPKG}.tgz
  else
   yarn add "@react-native-firebase/${RNFBPKG}@${RNFB_VER}"
  fi

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

# Optional: do you want to configure firebase behavior via firebase.json?
echo "Creating default firebase.json (with settings that allow iOS crashlytics to report crashes even in debug mode)"
printf "{\n  \"react-native\": {\n    \"crashlytics_disable_auto_disabler\": true,\n    \"crashlytics_debug_enabled\": true\n  }\n}" > firebase.json

# Optional: allow explicit SDK version control by specifying our iOS Pods and Android Firebase Bill of Materials

# TODO - demonstrate firebase-ios-sdk version pin in Expo context
#echo "Adding upstream SDK overrides for precise version control"
#echo "project.ext{set('react-native',[versions:[firebase:[bom:'${FB_ANDROID_VER}'],],])}" >> android/build.gradle
#sed -i -e $"s/target 'rnfbdemo' do/\$FirebaseSDKVersion = '${FB_IOS_VER}'\ntarget 'rnfbdemo' do/" ios/Podfile
#rm -f ios/Podfile??

# Test: Copy in our demonstrator App.tsx
echo "Copying demonstrator App.tsx..."
rm -f './app/(tabs)/index.tsx' && cp ../App-expo.tsx './app/(tabs)/index.tsx'

# Test: You have to re-run patch-package after yarn since it is not integrated into postinstall
echo "Running any patches necessary to compile successfully"
# cp -rv ../patches .
# npm_config_yes=true npx patch-package

echo "Running expo prebuild..."
npx expo prebuild

# Android builds fail lintVitalRelease out of the box with OutOfMemory, increase it
# There are a few ways to configure gradle, including modifying your global ~/.gradle/gradle.properties file
# This script should be self-contained though so we modify things internally
echo "Increasing memory available to gradle for android java build"
echo "org.gradle.jvmargs=-Xmx4092m -Dfile.encoding=UTF-8" >> android/gradle.properties

# Run the Expo dev server, but in a new Terminal so it does not hang up the script
echo "cd $PWD" > ./start-dev-server.command
echo "npm_config_yes=true npx expo start" >> ./start-dev-server.command
chmod 755 ./start-dev-server.command
open ./start-dev-server.command

# Test: Run the thing for iOS
if [ "$(uname)" == "Darwin" ]; then

  # TODO, how to do these in Expo context?
  # These are the background modes you need for push notifications and processing (just in case)
  # /usr/libexec/PlistBuddy -c "Add :UIBackgroundModes array" ios/rnfbdemo/Info.plist 
  # /usr/libexec/PlistBuddy -c "Add :UIBackgroundModes:0 string fetch" ios/rnfbdemo/Info.plist 
  # /usr/libexec/PlistBuddy -c "Add :UIBackgroundModes:0 string processing" ios/rnfbdemo/Info.plist 
  # /usr/libexec/PlistBuddy -c "Add :UIBackgroundModes:0 string remote-notification" ios/rnfbdemo/Info.plist 

  echo "Running iOS app in debug mode"
  npm_config_yes=true npx expo run:ios --configuration Debug # --simulator "iPhone 17"

  # Check iOS release mode compile
  # echo "Installing pods and running iOS app in release mode"
  # npx react-native run-ios --mode Release --simulator "iPhone 17"

  # Check catalyst build

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
  echo "npx expo run:android --variant debug"
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
npx expo run:android --variant debug
