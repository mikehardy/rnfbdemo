#!/bin/bash
set -e 

# Basic template create, rnfb install, link
\rm -fr rnfbdemo

echo "Testing react-native current + react-native-firebase current + Firebase SDKs current"

# Perhaps we want to try building without IDFA at all?
NOIDFA="false"
if [ "$1" == "--no-idfa" ]; then
  echo "Testing without AdMob (proves IDFA avoidance on iOS) - analytics should be fine"
  NOIDFA="true"
fi

npx react-native init rnfbdemo
cd rnfbdemo

# Flipper is not needed for a demo and causes compile errors sometimes, disable it
sed -i -e $'s/use_flipper/#use_flipper/' ios/Podfile
rm -f ios/Podfile.??
sed -i -e $'s/flipper_post_install/#flipper_post_install/' ios/Podfile
rm -f ios/Podfile.??

# This is the most basic integration
echo "Adding react-native-firebase core app package"
yarn add "@react-native-firebase/app"
echo "Adding basic iOS integration - AppDelegate import and config call"
sed -i -e $'s/AppDelegate.h"/AppDelegate.h"\\\n@import Firebase;/' ios/rnfbdemo/AppDelegate.m
rm -f ios/rnfbdemo/AppDelegate.m??
sed -i -e $'s/RCTBridge \*bridge/if ([FIRApp defaultApp] == nil) { [FIRApp configure]; }\\\n  RCTBridge \*bridge/' ios/rnfbdemo/AppDelegate.m
rm -f ios/rnfbdemo/AppDelegate.m??
echo "Adding basic java integration - gradle plugin dependency and call"
sed -i -e $'s/dependencies {/dependencies {\\\n        classpath "com.google.gms:google-services:4.3.4"/' android/build.gradle
rm -f android/build.gradle??
sed -i -e $'s/apply plugin: "com.android.application"/apply plugin: "com.android.application"\\\napply plugin: "com.google.gms.google-services"/' android/app/build.gradle
rm -f android/app/build.gradle??

# Allow explicit SDK version control by specifying our iOS Pods and Android Firebase Bill of Materials
echo "Adding upstream SDK overrides for precise version control"
echo "project.ext{set('react-native',[versions:[firebase:[bom:'26.6.0'],],])}" >> android/build.gradle
sed -i -e $'s/  target \'rnfbdemoTests\' do/  $FirebaseSDKVersion = \'7.7.0\'\\\n  target \'rnfbdemoTests\' do/' ios/Podfile
rm -f ios/Podfile??


#################################################################################
#################################################################################
# This is (hopefully temporarily) disabled as it caused duplicate symbol errors:
#################################################################################
# ▸ Linking rnfbdemo
# ❌  duplicate symbol '_OBJC_CLASS_$_PodsDummy_leveldb_library' in
# > libleveldb-library.a(leveldb-library-dummy.o)
# > leveldb-library(leveldb-library-dummy.o)
# ❌  duplicate symbol '_OBJC_METACLASS_$_PodsDummy_leveldb_library' in
# > libleveldb-library.a(leveldb-library-dummy.o)
# > leveldb-library(leveldb-library-dummy.o)
# ❌  ld: 2 duplicate symbols for architecture x86_64
# ❌  clang: error: linker command failed with exit code 1 (use -v to see invocation)
# This is a reference to a pre-built version of Firestore. It's a neat trick to speed up builds.
# sed -i -e $'s/  target \'rnfbdemoTests\' do/  pod \'FirebaseFirestore\', :git => \'https:\\/\\/github.com\\/invertase\\/firestore-ios-sdk-frameworks.git\', :tag => $FirebaseSDKVersion\\\n  target \'rnfbdemoTests\' do/' ios/Podfile
# rm -f ios/Podfile??
#################################################################################
#################################################################################

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
echo "Adding packages: Analytics, Auth, Database, Dynamic Links, Firestore, Functions, Instance-ID, In App Messaging, Messaging, ML, Remote Config, Storage"
yarn add \
  @react-native-firebase/analytics \
  @react-native-firebase/auth \
  @react-native-firebase/database \
  @react-native-firebase/dynamic-links \
  @react-native-firebase/firestore \
  @react-native-firebase/functions \
  @react-native-firebase/iid \
  @react-native-firebase/in-app-messaging \
  @react-native-firebase/messaging \
  @react-native-firebase/ml \
  @react-native-firebase/remote-config \
  @react-native-firebase/storage

# Crashlytics - repo, classpath, plugin, dependency, import, init
echo "Setting up Crashlytics - package, gradle plugin"
yarn add "@react-native-firebase/crashlytics"
sed -i -e $'s/dependencies {/dependencies {\\\n        classpath "com.google.firebase:firebase-crashlytics-gradle:2.5.1"/' android/build.gradle
rm -f android/build.gradle??
sed -i -e $'s/"com.google.gms.google-services"/"com.google.gms.google-services"\\\napply plugin: "com.google.firebase.crashlytics"/' android/app/build.gradle
rm -f android/app/build.gradle??

# Performance - classpath, plugin, dependency, import, init
echo "Setting up Performance - package, gradle plugin"
yarn add "@react-native-firebase/perf"
rm -f android/app/build.gradle??
sed -i -e $'s/dependencies {/dependencies {\\\n        classpath "com.google.firebase:perf-plugin:1.3.5"/' android/build.gradle
rm -f android/build.gradle??
sed -i -e $'s/"com.google.gms.google-services"/"com.google.gms.google-services"\\\napply plugin: "com.google.firebase.firebase-perf"/' android/app/build.gradle
rm -f android/app/build.gradle??

# In-App Messaging will not compile with react-native 0.63.x default gradle plugin (3.5.3) - bump to current stable
sed -i -e $'s/com.android.tools.build:gradle:3.5.3/com.android.tools.build:gradle:4.1.2/' android/build.gradle
rm -f android/build.gradle??

# Latest firebase gradle plugins require gradle >= 6.5, bump it to current stable
sed -i -e $'s/gradle-.*-all.zip/gradle-6.8.3-bin.zip/' android/gradle/wrapper/gradle-wrapper.properties
rm -f android/gradle/wrapper/gradle-wrapper.properties??


# I'm not going to demonstrate messaging and notifications. Everyone gets it wrong because it's hard. 
# You've got to read the docs and test *EVERYTHING* one feature at a time.
# But you have to do a *lot* of work in the AndroidManifest.xml, and make sure your MainActivity *is* the launch intent receiver
# I include it for compile testing only.

# I am not going to demonstrate shortcut badging. Shortcut badging on Android is a terrible idea to rely on.
# Only use it if the feature is "nice to have" but you're okay with it being terrible. It's an Android thing, not a react-native-firebase thing.
# (Pixel Launcher won't do it, launchers have to grant permissions, it is vendor specific, Material Design says no, etc etc)

echo "Creating default firebase.json (with settings that allow iOS crashlytics to report crashes even in debug mode)"
printf "{\n  \"react-native\": {\n    \"crashlytics_disable_auto_disabler\": true,\n    \"crashlytics_debug_enabled\": true\n  }\n}" > firebase.json

# Copy in our demonstrator App.js
echo "Copying demonstrator App.js"
rm ./App.js && cp ../App.js ./App.js


if [ "$NOIDFA" == "false" ]; then
  echo "Adding IDFA-containing packages: AdMob"
  yarn add @react-native-firebase/admob

  # Set up AdMob
  echo "Configuring up AdMob - adding test AdMob IDs in firebase.json"
  # Set up an AdMob ID (this is the official "sample id")
  sed -i -e $'s/"react-native": {/"react-native": {\\\n    "admob_android_app_id": \"ca-app-pub-3940256099942544~3347511713\",/' firebase.json
  rm -f firebase.json??
  sed -i -e $'s/"react-native": {/"react-native": {\\\n    "admob_ios_app_id": \"ca-app-pub-3940256099942544~1458002511\",/' firebase.json
  rm -f firebase.json??

  # Add AdMob and Analytics to the example
  echo "Adding AdMob to example App.js"
  sed -i -e $'s/import auth/import admob from \'@react-native-firebase\/admob\';\\\nimport auth/' App.js
  rm -f App.js??
  sed -i -e $'s/{auth()\.native/{admob\(\)\.native \&\& <Text style={styles\.module}>admob\(\)<\/Text>}\\\n        {auth\(\)\.native/' App.js
  rm -f App.js??
fi

# Set the Java application up for multidex (needed for API<21 w/Firebase) - disabled as upcoming react-native 0.64 no longer supports API<21
# echo "Configuring Android MultiDex for API<21 support - gradle toggle, library dependency, Application object inheritance"
# sed -i -e $'s/defaultConfig {/defaultConfig {\\\n        multiDexEnabled true/' android/app/build.gradle
# rm -f android/app/build.gradle??
# sed -i -e $'s/dependencies {/dependencies {\\\n    implementation "androidx.multidex:multidex:2.0.1"/' android/app/build.gradle
# rm -f android/app/build.gradle??
# sed -i -e $'s/import android.app.Application;/import androidx.multidex.MultiDexApplication;/' android/app/src/main/java/com/rnfbdemo/MainApplication.java
# rm -f android/app/src/main/java/com/rnfbdemo/MainApplication.java??
# sed -i -e $'s/extends Application/extends MultiDexApplication/' android/app/src/main/java/com/rnfbdemo/MainApplication.java
# rm -f android/app/src/main/java/com/rnfbdemo/MainApplication.java??

# Instead of showing MultiDex which is needed for API<21, bump minSdkVersion to react-native 0.64+ minimum
sed -i -e $'s/minSdkVersion = .*$/minSdkVersion = 21/' android/build.gradle
rm -f android/build.gradle??



# Another Java build tweak - or gradle runs out of memory during the build
echo "Increasing memory available to gradle for android java build"
echo "org.gradle.jvmargs=-Xmx2048m -XX:MaxPermSize=512m -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8" >> android/gradle.properties

# In case we have any patches
echo "Running any patches necessary to compile successfully"
cp -rv ../patches .
npx patch-package

# Run the thing for iOS
if [ "$(uname)" == "Darwin" ]; then
  echo "Installing pods and running iOS app"
  cd ios && pod install --repo-update && cd ..
  npx react-native run-ios

  # This is how you configure for static frameworks:
  sed -i -e $'s/config = use_native_modules!/config = use_native_modules!\\\n  config = use_frameworks!\\\n  $RNFirebaseAsStaticFramework = true/' ios/Podfile
  rm -f ios/Podfile.??
  cd ios && pod install && cd ..
  npx react-native run-ios

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
