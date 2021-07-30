#!/bin/bash
set -e 

# Basic template create, rnfb install, link
\rm -fr rnfbdemo

echo "Testing react-native current + react-native-firebase current + Firebase SDKs current"

npx react-native init rnfbdemo --version=0.65.0-rc.3
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
sed -i -e $'s/dependencies {/dependencies {\\\n        classpath "com.google.gms:google-services:4.3.8"/' android/build.gradle
rm -f android/build.gradle??
sed -i -e $'s/apply plugin: "com.android.application"/apply plugin: "com.android.application"\\\napply plugin: "com.google.gms.google-services"/' android/app/build.gradle
rm -f android/app/build.gradle??

# Allow explicit SDK version control by specifying our iOS Pods and Android Firebase Bill of Materials
echo "Adding upstream SDK overrides for precise version control"
echo "project.ext{set('react-native',[versions:[firebase:[bom:'28.3.0'],],])}" >> android/build.gradle
sed -i -e $'s/  target \'rnfbdemoTests\' do/  $FirebaseSDKVersion = \'8.4.0\'\\\n  target \'rnfbdemoTests\' do/' ios/Podfile
rm -f ios/Podfile??

# This is a reference to a pre-built version of Firestore. It's a neat trick to speed up builds.
# If you are using firestore and database you *may* end up with duplicate symbol build errors referencing "leveldb", the FirebaseFirestoreExcludeLeveldb boolean fixes that.
sed -i -e $'s/  target \'rnfbdemoTests\' do/  $FirebaseFirestoreExcludeLeveldb = true\\\n  pod \'FirebaseFirestore\', :git => \'https:\\/\\/github.com\\/invertase\\/firestore-ios-sdk-frameworks.git\', :tag => $FirebaseSDKVersion\\\n  target \'rnfbdemoTests\' do/' ios/Podfile
rm -f ios/Podfile??

# Copy the Firebase config files in - you must supply them
echo "Copying in Firebase android json and iOS plist app definition files downloaded from console"
if [ "$(uname)" == "Darwin" ]; then
  cp ../GoogleService-Info.plist ios/rnfbdemo/
fi
cp ../google-services.json android/app/

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
echo "Adding packages: Analytics, Auth, Database, Dynamic Links, Firestore, Functions, In App Messaging, Messaging, ML, Remote Config, Storage"
yarn add \
  @react-native-firebase/analytics \
  @react-native-firebase/auth \
  @react-native-firebase/database \
  @react-native-firebase/dynamic-links \
  @react-native-firebase/firestore \
  @react-native-firebase/functions \
  @react-native-firebase/in-app-messaging \
  @react-native-firebase/messaging \
  @react-native-firebase/remote-config \
  @react-native-firebase/storage

# Crashlytics - repo, classpath, plugin, dependency, import, init
echo "Setting up Crashlytics - package, gradle plugin"
yarn add "@react-native-firebase/crashlytics"
sed -i -e $'s/dependencies {/dependencies {\\\n        classpath "com.google.firebase:firebase-crashlytics-gradle:2.7.1"/' android/build.gradle
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

# In case we have any patches
echo "Running any patches necessary to compile successfully"
cp -rv ../patches .
npx patch-package

# Run the thing for iOS
if [ "$(uname)" == "Darwin" ]; then
  echo "Installing pods and running iOS app"
  cd ios && pod install --repo-update && cd ..

  npx react-native run-ios || true

  # For some reason (codegen related), I had to run this a second time after first build fails for it to work?
  cd ios && pod install && cd ..

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
npx react-native run-android --variant release

# Let it start up, then uninstall it (otherwise ABI-split-generated version codes will prevent debug from installing)
sleep 10
pushd android
./gradlew uninstallRelease
popd

# may or may not be commented out, depending on if have an emulator available
# I run it manually in testing when I have one, comment if you like
npx react-native run-android
