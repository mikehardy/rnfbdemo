#!/bin/bash
set -e 

# Basic template create, rnfb install, link
\rm -fr rnfbdemo

echo "Testing react-native 0.60 + react-native-firebase v5.current + Firebase SDKs current"
react-native init rnfbdemo
cd rnfbdemo

echo "Adding react-native-firebase dependency"
yarn add "https://github.com/invertase/react-native-firebase.git#v5.x.x"

# Perform the minimal edit to integrate it on iOS
echo "Adding initialization code in iOS"
sed -i -e $'s/AppDelegate.h"/AppDelegate.h"\\\n#import "Firebase.h"/' ios/rnfbdemo/AppDelegate.m
rm -f ios/rnfbdemo/AppDelegate.m??
sed -i -e $'s/RCTBridge \*bridge/[FIRApp configure];\\\n  RCTBridge \*bridge/' ios/rnfbdemo/AppDelegate.m
rm -f ios/rnfbdemo/AppDelegate.m??

# Minimal integration on Android is just the JSON, base+core, progaurd
echo "Adding basic java integration"
sed -i -e $'s/dependencies {/dependencies {\\\n        classpath "com.google.gms:google-services:4.3.0"/' android/build.gradle
rm -f android/build.gradle??
echo "apply plugin: 'com.google.gms.google-services'" >> android/app/build.gradle
sed -i -e $'s/dependencies {/dependencies {\\\n    implementation "com.google.android.gms:play-services-base:17.0.0"/' android/app/build.gradle
rm -f android/app/build.gradle??
sed -i -e $'s/dependencies {/dependencies {\\\n    implementation "com.google.firebase:firebase-core:17.0.1"/' android/app/build.gradle
rm -f android/app/build.gradle??
echo "-keep class io.invertase.firebase.** { *; }" >> android/app/proguard-rules.pro
echo "-dontwarn io.invertase.firebase.**" >> android/app/proguard-rules.pro

# Copy the Firebase config files in - you must supply them
echo "Copying in Firebase app definition files"
cp ../GoogleService-Info.plist ios/rnfbdemo/
cp ../google-services.json android/app/

# Copy in a project file that is pre-constructed - no way to patch it cleanly that I've found
# To build it do this:
# 1.  stop this script here (by uncommenting the exit line)
# 2.  open the .xcworkspace created by running the script to this point
# 3.  alter the bundleID to com.rnfbdemo
# 4.  alter the target to 'both' instead of iPhone only
# 5.  "add files to " project and select rnfbdemo/GoogleService-Info.plist for rnfbdemo and rnfbdemo-tvOS
#exit 1
rm -f ios/rnfbdemo.xcodeproj/project.pbxproj
cp ../project.pbxproj ios/rnfbdemo.xcodeproj/

# Crashlytics - repo, classpath, plugin, dependency, import, init
echo "Setting crashlytics up in Java"
sed -i -e $'s/google()/maven { url "https:\/\/maven.fabric.io\/public" }\\\n        google()/' android/build.gradle
rm -f android/build.gradle??
sed -i -e $'s/dependencies {/dependencies {\\\n        classpath "io.fabric.tools:gradle:1.28.1"/' android/build.gradle
rm -f android/build.gradle??
sed -i -e $'s/"com.android.application"/"com.android.application"\\\napply plugin: "io.fabric"/' android/app/build.gradle
rm -f android/app/build.gradle??
sed -i -e $'s/dependencies {/dependencies {\\\n    implementation("com.crashlytics.sdk.android:crashlytics:2.9.9@aar") { transitive=true } /' android/app/build.gradle
rm -f android/app/build.gradle??
sed -i -e $'s/public class/import io.invertase.firebase.fabric.crashlytics.RNFirebaseCrashlyticsPackage;\\\n\\\npublic class/' android/app/src/main/java/com/rnfbdemo/MainApplication.java
rm -f android/app/src/main/java/com/rnfbdemo/MainApplication.java??
sed -i -e $'s/return packages;/packages.add(new RNFirebaseCrashlyticsPackage());\\\n      return packages;/' android/app/src/main/java/com/rnfbdemo/MainApplication.java
rm -f android/app/src/main/java/com/rnfbdemo/MainApplication.java??

# Performance - classpath, plugin, dependency, import, init
echo "Setting up Performance module in Java"
rm -f android/app/build.gradle??
sed -i -e $'s/dependencies {/dependencies {\\\n        classpath "com.google.firebase:perf-plugin:1.3.0"/' android/build.gradle
rm -f android/build.gradle??
sed -i -e $'s/"com.android.application" {/"com.android.application"\\\napply plugin: "com.google.firebase.firebase-perf"/' android/app/build.gradle
rm -f android/app/build.gradle??
sed -i -e $'s/dependencies {/dependencies {\\\n    implementation "com.google.firebase:firebase-perf:18.0.1"/' android/app/build.gradle
rm -f android/app/build.gradle??
sed -i -e $'s/public class/import io.invertase.firebase.perf.RNFirebasePerformancePackage;\\\n\\\npublic class/' android/app/src/main/java/com/rnfbdemo/MainApplication.java
rm -f android/app/src/main/java/com/rnfbdemo/MainApplication.java??
sed -i -e $'s/return packages;/packages.add(new RNFirebasePerformancePackage());\\\n      return packages;/' android/app/src/main/java/com/rnfbdemo/MainApplication.java
rm -f android/app/src/main/java/com/rnfbdemo/MainApplication.java??

# Analytics - dependency, import, init
echo "Setting up Analytics in Java"
sed -i -e $'s/dependencies {/dependencies {\\\n    implementation "com.google.firebase:firebase-analytics:17.0.1"/' android/app/build.gradle
rm -f android/app/build.gradle??
sed -i -e $'s/public class/import io.invertase.firebase.analytics.RNFirebaseAnalyticsPackage;\\\n\\\npublic class/' android/app/src/main/java/com/rnfbdemo/MainApplication.java
rm -f android/app/src/main/java/com/rnfbdemo/MainApplication.java??
sed -i -e $'s/return packages;/packages.add(new RNFirebaseAnalyticsPackage());\\\n      return packages;/' android/app/src/main/java/com/rnfbdemo/MainApplication.java
rm -f android/app/src/main/java/com/rnfbdemo/MainApplication.java??

# Firestore - dependency, import, init
echo "Setting up Firestore in Java"
sed -i -e $'s/dependencies {/dependencies {\\\n    implementation "com.google.firebase:firebase-firestore:20.2.0"/' android/app/build.gradle
rm -f android/app/build.gradle??
sed -i -e $'s/public class/import io.invertase.firebase.firestore.RNFirebaseFirestorePackage;\\\n\\\npublic class/' android/app/src/main/java/com/rnfbdemo/MainApplication.java
rm -f android/app/src/main/java/com/rnfbdemo/MainApplication.java??
sed -i -e $'s/return packages;/packages.add(new RNFirebaseFirestorePackage());\\\n      return packages;/' android/app/src/main/java/com/rnfbdemo/MainApplication.java
rm -f android/app/src/main/java/com/rnfbdemo/MainApplication.java??

# I'm not going to demonstrate messaging and notifications. Everyone gets it wrong because it's hard. 
# You've got to read the docs and test *EVERYTHING* one feature at a time.
# But you have to do a *lot* of work in the AndroidManifest.xml, and make sure your MainActivity *is* the launch intent receiver

# I am not going to demonstrate shortcut badging. Shortcut badging on Android is a terrible idea to rely on.
# Only use it if the feature is "nice to have" but you're okay with it being terrible. It's an Android thing, not a react-native-firebase thing.
# (Pixel Launcher won't do it, launchers have to grant permissions, it is vendor specific, Material Design says no, etc etc)

# Set up AdMob Java stuff - dependency, import, init
echo "Setting up AdMob"
sed -i -e $'s/dependencies {/dependencies {\\\n    implementation "com.google.firebase:firebase-ads:18.1.1"/' android/app/build.gradle
rm -f android/app/build.gradle??
sed -i -e $'s/public class/import io.invertase.firebase.admob.RNFirebaseAdMobPackage;\\\n\\\npublic class/' android/app/src/main/java/com/rnfbdemo/MainApplication.java
rm -f android/app/src/main/java/com/rnfbdemo/MainApplication.java??
sed -i -e $'s/return packages;/packages.add(new RNFirebaseAdMobPackage());\\\n      return packages;/' android/app/src/main/java/com/rnfbdemo/MainApplication.java
rm -f android/app/src/main/java/com/rnfbdemo/MainApplication.java??

# Set up an AdMob ID (this is the official "sample id")
sed -i -e $'s/NSAppTransportSecurity/GADApplicationIdentifier<\/key>\\\n	<string>ca-app-pub-3940256099942544~1458002511<\/string>\\\n        <key>NSAppTransportSecurity/' ios/rnfbdemo/Info.plist
rm -f ios/rnfbdemo/Info.plist??
sed -i -e $'s/<\/application>/  <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="ca-app-pub-3940256099942544~3347511713"\/>\\\n    <\/application>/' android/app/src/main/AndroidManifest.xml
rm -f android/app/src/main/AndroidManifest.xml??

# AdMob has a specific error in react-native-firebase with regard to modern Firebase iOS SDKs, the path moved
sed -i -e $'s/Google-Mobile-Ads-SDK\/Frameworks\/frameworks/Google-Mobile-Ads-SDK\/Frameworks\/GoogleMobileAdsFramework-Current/' node_modules/react-native-firebase/ios/RNFirebase.xcodeproj/project.pbxproj
rm -f node_modules/react-native-firebase/ios/RNFirebase.xcodeproj/project.pbxproj??

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

# Copy in our demonstrator App.js
rm ./App.js && cp ../App.js .

# Javascript Jetifier: this makes sure Java code in npm-managed modules are transformed all the time
# It is used automatically now, built in to the @react-native-community/cli process by default

# Copy in our Podfile (it isn't built dynamically, sorry)
cp ../Podfile ./ios/Podfile

# Run the thing for iOS
if [ "$(uname)" == "Darwin" ]; then
  echo "Installing pods and running iOS app"
  cd ios && pod install --repo-update && cd ..
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
#react-native run-android
