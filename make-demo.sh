#!/bin/bash
set -e 

# Previous compiles may confound future compiles, erase...
\rm -fr "$HOME/Library/Developer/Xcode/DerivedData/rnfbdemo*"

# Basic template create, rnfb install, link
\rm -fr rnfbdemo

echo "Testing react-native current + react-native-firebase current + Firebase SDKs current"

if ! which yarn > /dev/null 2>&1; then
  echo "This script uses yarn, please install yarn (for example \`npm i yarn -g\` and re-try"
  exit 1
fi

npx react-native init rnfbdemo --version=0.67.0-rc.2
cd rnfbdemo

# This is the most basic integration
echo "Adding react-native-firebase core app package"
yarn add "@react-native-firebase/app"
echo "Adding basic iOS integration - AppDelegate import and config call"
sed -i -e $'s/AppDelegate.h"/AppDelegate.h"\\\n@import Firebase;/' ios/rnfbdemo/AppDelegate.m
rm -f ios/rnfbdemo/AppDelegate.m??
sed -i -e $'s/RCTBridge \*bridge/if ([FIRApp defaultApp] == nil) { [FIRApp configure]; }\\\n  RCTBridge \*bridge/' ios/rnfbdemo/AppDelegate.m
rm -f ios/rnfbdemo/AppDelegate.m??
echo "Adding basic java integration - gradle plugin dependency and call"
sed -i -e $'s/dependencies {/dependencies {\\\n        classpath "com.google.gms:google-services:4.3.10"/' android/build.gradle
rm -f android/build.gradle??
sed -i -e $'s/apply plugin: "com.android.application"/apply plugin: "com.android.application"\\\napply plugin: "com.google.gms.google-services"/' android/app/build.gradle
rm -f android/app/build.gradle??

# Allow explicit SDK version control by specifying our iOS Pods and Android Firebase Bill of Materials
echo "Adding upstream SDK overrides for precise version control"
echo "project.ext{set('react-native',[versions:[firebase:[bom:'29.0.0'],],])}" >> android/build.gradle
sed -i -e $'s/  target \'rnfbdemoTests\' do/  $FirebaseSDKVersion = \'8.9.1\'\\\n  target \'rnfbdemoTests\' do/' ios/Podfile
rm -f ios/Podfile??

# This is a reference to a pre-built version of Firestore. It's a neat trick to speed up builds.
# If you are using firestore and database you *may* end up with duplicate symbol build errors referencing "leveldb", the FirebaseFirestoreExcludeLeveldb boolean fixes that.
#sed -i -e $'s/  target \'rnfbdemoTests\' do/  $FirebaseFirestoreExcludeLeveldb = true\\\n  pod \'FirebaseFirestore\', :git => \'https:\\/\\/github.com\\/invertase\\/firestore-ios-sdk-frameworks.git\', :tag => $FirebaseSDKVersion\\\n  target \'rnfbdemoTests\' do/' ios/Podfile
#rm -f ios/Podfile??

# Copy the Firebase config files in - you must supply them
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

# Copy in a project file that is pre-constructed - no way to patch it cleanly that I've found
# There is already a pre-constructed project file here. 
# Normal users may skip these steps unless you are maintaining this repository and need to generate a new project
# To build it do this:
# 1.  stop this script here (by uncommenting the exit line)
# 2.  open the .xcworkspace created by running the script to this point
# 3.  alter the bundleID to com.rnfbdemo
# 4.  alter the target to iPhone and iPad instead of iPhone only (Mac is not supported yet, but feel free to try...)
# 5.  right-click on rnfbdemo, "add files to rnfbdemo" select rnfbdemo/GoogleService-Info.plist for rnfbdemo and rnfbdemo-tvOS
# 6.  copy the rnfbdemo.xcodeproj and rnfbdemo.xcworkspace folders over the existing ones saved in the root directory
#exit 1
rm -rf ios/rnfbdemo.xcodeproj ios/rnfbdemo.xcworkspace
cp -r ../rnfbdemo.xcodeproj ios/
cp -r ../rnfbdemo.xcworkspace ios/

# From this point on we are adding optional modules
# First set up all the modules that need no further config for the demo 
echo "Adding packages: Analytics, App Check, App Distribution, Auth, Database, Dynamic Links, Firestore, Functions, In App Messaging, Installations, Messaging, ML, Remote Config, Storage"
yarn add \
  @react-native-firebase/analytics \
  @react-native-firebase/app-check \
  @react-native-firebase/app-distribution \
  @react-native-firebase/auth \
  @react-native-firebase/database \
  @react-native-firebase/dynamic-links \
  @react-native-firebase/firestore \
  @react-native-firebase/functions \
  @react-native-firebase/in-app-messaging \
  @react-native-firebase/installations \
  @react-native-firebase/messaging \
  @react-native-firebase/remote-config \
  @react-native-firebase/storage

# Crashlytics - repo, classpath, plugin, dependency, import, init
echo "Setting up Crashlytics - package, gradle plugin"
yarn add "@react-native-firebase/crashlytics"
sed -i -e $'s/dependencies {/dependencies {\\\n        classpath "com.google.firebase:firebase-crashlytics-gradle:2.8.0"/' android/build.gradle
rm -f android/build.gradle??
sed -i -e $'s/"com.google.gms.google-services"/"com.google.gms.google-services"\\\napply plugin: "com.google.firebase.crashlytics"/' android/app/build.gradle
rm -f android/app/build.gradle??

# Performance - classpath, plugin, dependency, import, init
echo "Setting up Performance - package, gradle plugin"
yarn add "@react-native-firebase/perf"
rm -f android/app/build.gradle??
sed -i -e $'s/dependencies {/dependencies {\\\n        classpath "com.google.firebase:perf-plugin:1.4.0"/' android/build.gradle
rm -f android/build.gradle??
sed -i -e $'s/"com.google.gms.google-services"/"com.google.gms.google-services"\\\napply plugin: "com.google.firebase.firebase-perf"/' android/app/build.gradle
rm -f android/app/build.gradle??

# I'm not going to demonstrate messaging and notifications. Everyone gets it wrong because it's hard. 
# You've got to read the docs and test *EVERYTHING* one feature at a time.
# But you have to do a *lot* of work in the AndroidManifest.xml, and make sure your MainActivity *is* the launch intent receiver
# I include it for compile testing only.

echo "Creating default firebase.json (with settings that allow iOS crashlytics to report crashes even in debug mode)"
printf "{\n  \"react-native\": {\n    \"crashlytics_disable_auto_disabler\": true,\n    \"crashlytics_debug_enabled\": true\n  }\n}" > firebase.json

# Copy in our demonstrator App.js
echo "Copying demonstrator App.js"
rm ./App.js && cp ../App.js ./App.js

# Another Java build tweak - or gradle runs out of memory during the build
echo "Increasing memory available to gradle for android java build"
echo "org.gradle.jvmargs=-Xmx2048m -XX:MaxPermSize=512m -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8" >> android/gradle.properties

# Hermes is available on both platforms and provides faster startup since it pre-parses javascript. Enable it.
sed -i -e $'s/enableHermes: false/enableHermes: true/' android/app/build.gradle
rm -f android/app/build.gradle??
sed -i -e $'s/hermes_enabled => false/hermes_enabled => true/' ios/Podfile
rm -f ios/Podfile??

# Apple builds in general have a problem with architectures on Apple Silicon and Intel, and doing some exclusions should help
sed -i -e $'s/react_native_post_install(installer)/react_native_post_install(installer)\\\n    \\\n    installer.aggregate_targets.each do |aggregate_target|\\\n      aggregate_target.user_project.native_targets.each do |target|\\\n        target.build_configurations.each do |config|\\\n          config.build_settings[\'ONLY_ACTIVE_ARCH\'] = \'YES\'\\\n          config.build_settings[\'EXCLUDED_ARCHS\'] = \'i386\'\\\n        end\\\n      end\\\n      aggregate_target.user_project.save\\\n    end/' ios/Podfile
rm -f ios/Podfile.??

# This is just a speed optimization, very optional, but asks xcodebuild to use clang and clang++ without the fully-qualified path
# That means that you can then make a symlink in your path with clang or clang++ and have it use a different binary
# In that way you can install ccache or buildcache and get much faster compiles...
sed -i -e $'s/react_native_post_install(installer)/react_native_post_install(installer)\\\n    \\\n    installer.pods_project.targets.each do |target|\\\n      target.build_configurations.each do |config|\\\n        config.build_settings["CC"] = "clang"\\\n        config.build_settings["LD"] = "clang"\\\n        config.build_settings["CXX"] = "clang++"\\\n        config.build_settings["LDPLUSPLUS"] = "clang++"\\\n      end\\\n    end/' ios/Podfile

# In case we have any patches
echo "Running any patches necessary to compile successfully"
cp -rv ../patches .
npx patch-package

# Run the thing for iOS
if [ "$(uname)" == "Darwin" ]; then
  echo "Installing pods and running iOS app"
  cd ios && pod install --repo-update && cd ..

  # Check iOS debug mode compile
  npx react-native run-ios

  # Check iOS release mode compile
  npx react-native run-ios --configuration "Release"

  #################################
  # Check static frameworks compile

  # This is how you configure for static frameworks:
  sed -i -e $'s/config = use_native_modules!/config = use_native_modules!\\\n  config = use_frameworks!\\\n  $RNFirebaseAsStaticFramework = true/' ios/Podfile

  # Static frameworks does not work with hermes and flipper - toggle them both off again
  sed -i -e $'s/use_flipper/#use_flipper/' ios/Podfile
  rm -f ios/Podfile.??
  sed -i -e $'s/flipper_post_install/#flipper_post_install/' ios/Podfile
  rm -f ios/Podfile.??
  sed -i -e $'s/hermes_enabled => true/hermes_enabled => false/' ios/Podfile
  rm -f ios/Podfile??

  # Workaround needed for static framework build only, regular build is fine.
  # https://github.com/facebook/react-native/issues/31149#issuecomment-800841668
  sed -i -e $'s/react_native_post_install(installer)/react_native_post_install(installer)\\\n    installer.pods_project.targets.each do |target|\\\n      if (target.name.eql?(\'FBReactNativeSpec\'))\\\n        target.build_phases.each do |build_phase|\\\n          if (build_phase.respond_to?(:name) \&\& build_phase.name.eql?(\'[CP-User] Generate Specs\'))\\\n            target.build_phases.move(build_phase, 0)\\\n          end\\\n        end\\\n      end\\\n    end/' ios/Podfile
  rm -f ios/Podfile.??
  cd ios && pod install && cd ..
  npx react-native run-ios

  # end of static frameworks workarounds + test
  #############################################

  # workaround for poorly setup Android SDK environments
  USER=$(whoami)
  echo "sdk.dir=/Users/$USER/Library/Android/sdk" > android/local.properties
fi

echo "Configuring Android release build for ABI splits and code shrinking"
sed -i -e $'s/def enableSeparateBuildPerCPUArchitecture = false/def enableSeparateBuildPerCPUArchitecture = true/' android/app/build.gradle
rm -f android/app/build.gradle??
sed -i -e $'s/def enableProguardInReleaseBuilds = false/def enableProguardInReleaseBuilds = true/' android/app/build.gradle
rm -f android/app/build.gradle??
sed -i -e $'s/universalApk false/universalApk true/' android/app/build.gradle
rm -f android/app/build.gradle??

# If we are on WSL the user needs to now run it from the Windows side
# Getting it to run from WSL is a real mess (it is possible, but not recommended)
# So we will stop now that we've done all the installation and file editing
if [ "$(uname -a | grep Linux | grep -c microsoft)" == "1" ]; then
  echo "Detected Windows Subsystem for Linux. Stopping now."

  # Clear out the unix-y node_modules
  \rm -fr node_modules
  echo "To run the app use Windows Powershell in the rnfbdemo directory with these commands:"
  echo "npm i"
  echo "npx react-native run-android"
  exit
fi

# Run it for Android (assumes you have an android emulator running)
echo "Running android app"
npx react-native run-android --variant release --no-jetifier

# Let it start up, then uninstall it (otherwise ABI-split-generated version codes will prevent debug from installing)
sleep 10
pushd android
./gradlew uninstallRelease
popd

# may or may not be commented out, depending on if have an emulator available
# I run it manually in testing when I have one, comment if you like
npx react-native run-android --no-jetifier
