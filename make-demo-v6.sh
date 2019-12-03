#!/bin/bash
set -e 

# Basic template create, rnfb install, link
\rm -fr rnfbdemo

echo "Testing react-native current + react-native-firebase v6.current + Firebase SDKs current"
npx react-native init rnfbdemo
cd rnfbdemo

echo "Adding react-native-firebase dependencies"
yarn add "@react-native-firebase/app"
yarn add "@react-native-firebase/auth"

# Perform the minimal edit to integrate it on iOS
echo "Adding initialization code in iOS"
sed -i -e $'s/AppDelegate.h"/AppDelegate.h"\\\n@import Firebase;/' ios/rnfbdemo/AppDelegate.m
rm -f ios/rnfbdemo/AppDelegate.m??
sed -i -e $'s/RCTBridge \*bridge/if ([FIRApp defaultApp] == nil) { [FIRApp configure]; }\\\n  RCTBridge \*bridge/' ios/rnfbdemo/AppDelegate.m
rm -f ios/rnfbdemo/AppDelegate.m??

# Minimal integration on Android is just the JSON, base+core, progaurd
echo "Adding basic java integration"
sed -i -e $'s/dependencies {/dependencies {\\\n        classpath "com.google.gms:google-services:4.3.3"/' android/build.gradle
rm -f android/build.gradle??
echo "apply plugin: 'com.google.gms.google-services'" >> android/app/build.gradle

# Allow explicit SDK version control by specifying our iOS Pods and Android Firebase Bill of Materials
echo "project.ext{set('react-native',[versions:[firebase:[bom:'24.1.0'],],])}" >> android/build.gradle
sed -i -e $'s/  target \'rnfbdemoTests\' do/  $FirebaseSDKVersion = \'6.13.0\'\\\n  target \'rnfbdemoTests\' do/' ios/Podfile

# Copy the Firebase config files in - you must supply them
echo "Copying in Firebase app definition files"
cp ../GoogleService-Info.plist ios/rnfbdemo/
cp ../google-services.json android/app/

# Copy in a project file that is pre-constructed - no way to patch it cleanly that I've found
# There is already a pre-constructed project file here. 
# Normal users may skip these steps unless you are maintaining this repository and need to generate a new project
# To build it do this:
# 1.  stop this script here (by uncommenting the exit line)
# 2.  open the .xcworkspace created by running the script to this point
# 3.  alter the bundleID to com.rnfbdemo
# 4.  alter the target to 'both' instead of iPhone only
# 5.  "add files to " project and select rnfbdemo/GoogleService-Info.plist for rnfbdemo and rnfbdemo-tvOS
#exit 1
rm -f ios/rnfbdemo.xcodeproj/project.pbxproj
cp ../project.pbxproj ios/rnfbdemo.xcodeproj/

# Analytics - 
echo "Setting up Analytics"
yarn add "@react-native-firebase/analytics"

# Crashlytics - repo, classpath, plugin, dependency, import, init
echo "Setting up Crashlytics"
yarn add "@react-native-firebase/crashlytics"
sed -i -e $'s/google()/maven { url "https:\/\/maven.fabric.io\/public" }\\\n        google()/' android/build.gradle
rm -f android/build.gradle??
sed -i -e $'s/dependencies {/dependencies {\\\n        classpath "io.fabric.tools:gradle:1.28.1"/' android/build.gradle
rm -f android/build.gradle??
sed -i -e $'s/"com.android.application"/"com.android.application"\\\napply plugin: "io.fabric"\\\ncrashlytics { enableNdk true }/' android/app/build.gradle
rm -f android/app/build.gradle??

# Database
echo "Setting up Database"
yarn add "@react-native-firebase/database"

# Firestore
echo "Setting up Firestore"
yarn add "@react-native-firebase/firestore"

# Functions
echo "Setting up Functions"
yarn add "@react-native-firebase/functions"

# Performance - classpath, plugin, dependency, import, init
echo "Setting up Performance"
yarn add "@react-native-firebase/perf"
rm -f android/app/build.gradle??
sed -i -e $'s/dependencies {/dependencies {\\\n        classpath "com.google.firebase:perf-plugin:1.3.1"/' android/build.gradle
rm -f android/build.gradle??
sed -i -e $'s/"com.android.application" {/"com.android.application"\\\napply plugin: "com.google.firebase.firebase-perf"/' android/app/build.gradle
rm -f android/app/build.gradle??

# Storage
echo "Setting up Storage"
yarn add "@react-native-firebase/storage"

# I'm not going to demonstrate messaging and notifications. Everyone gets it wrong because it's hard. 
# You've got to read the docs and test *EVERYTHING* one feature at a time.
# But you have to do a *lot* of work in the AndroidManifest.xml, and make sure your MainActivity *is* the launch intent receiver

# I am not going to demonstrate shortcut badging. Shortcut badging on Android is a terrible idea to rely on.
# Only use it if the feature is "nice to have" but you're okay with it being terrible. It's an Android thing, not a react-native-firebase thing.
# (Pixel Launcher won't do it, launchers have to grant permissions, it is vendor specific, Material Design says no, etc etc)

# Set up AdMob
echo "Setting up AdMob"
yarn add "@react-native-firebase/admob"
# Set up an AdMob ID (this is the official "sample id")
# Note this can be done in firebase.json as well: https://invertase.io/oss/react-native-firebase/v6/admob/quick-start#important:-adding-your-admob-app-id
printf "{\n  \"react-native\": {\n    \"admob_android_app_id\": \"ca-app-pub-3940256099942544~3347511713\",\n    \"admob_ios_app_id\": \"ca-app-pub-3940256099942544~1458002511\"\n  }\n}" > firebase.json

# AdMob has a specific error in react-native-firebase with regard to modern Firebase iOS SDKs, the path moved
# I think this is not needed for react-native-firebase v6 though
# sed -i -e $'s/Google-Mobile-Ads-SDK\/Frameworks\/frameworks/Google-Mobile-Ads-SDK\/Frameworks\/GoogleMobileAdsFramework-Current/' node_modules/react-native-firebase/ios/RNFirebase.xcodeproj/project.pbxproj
# rm -f node_modules/react-native-firebase/ios/RNFirebase.xcodeproj/project.pbxproj??

# Set the Java application up for multidex (needed for API<21 w/Firebase)
echo "Configuring MultiDex for API<21 support"
sed -i -e $'s/defaultConfig {/defaultConfig {\\\n        multiDexEnabled true/' android/app/build.gradle
rm -f android/app/build.gradle??
sed -i -e $'s/dependencies {/dependencies {\\\n    implementation "androidx.multidex:multidex:2.0.1"/' android/app/build.gradle
rm -f android/app/build.gradle??
sed -i -e $'s/import android.app.Application;/import androidx.multidex.MultiDexApplication;/' android/app/src/main/java/com/rnfbdemo/MainApplication.java
rm -f android/app/src/main/java/com/rnfbdemo/MainApplication.java??
sed -i -e $'s/extends Application/extends MultiDexApplication/' android/app/src/main/java/com/rnfbdemo/MainApplication.java
rm -f android/app/src/main/java/com/rnfbdemo/MainApplication.java??

# Another Java build tweak - or gradle runs out of memory during the build
echo "Increasing memory available to gradle for android java build"
echo "org.gradle.jvmargs=-Xmx2048m -XX:MaxPermSize=512m -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8" >> android/gradle.properties

# Copy in our demonstrator App.js
rm ./App.js && cp ../AppV6.js ./App.js

# Javascript Jetifier: this makes sure Java code in npm-managed modules are transformed all the time
# It is used automatically now, built in to the @react-native-community/cli process by default

# Run the thing for iOS
if [ "$(uname)" == "Darwin" ]; then
  echo "Installing pods and running iOS app"
  cd ios && pod install && cd ..
  react-native run-ios
  # workaround for poorly setup Android SDK environments
  USER=`whoami`
  echo "sdk.dir=/Users/$USER/Library/Android/sdk" > android/local.properties
fi

# Run it for Android (assumes you have an android emulator running)
echo "Running android app"
npx jetify
cd android && ./gradlew assembleRelease # prove it works
cd ..
# only commenting this out because I frequently don't have an emulator available
# I run it manually in testing when I have one, uncomment if you like
npx react-native run-android
