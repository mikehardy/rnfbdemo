#!/bin/bash
set -e 

# Basic template create, rnfb install, link
\rm -fr rnfbdemo
react-native init rnfbdemo
cd rnfbdemo
npm i react-native-firebase
react-native link react-native-firebase
cd ios
cp ../../Podfile .
pod install
cd ..

# Perform the minimal edit to integrate it on iOS
sed -i -e $'s/AppDelegate.h"/AppDelegate.h"\\\n#import "Firebase.h"/' ios/rnfbdemo/AppDelegate.m
rm -f ios/rnfbdemo/AppDelegate.m??
sed -i -e $'s/RCTBridge \*bridge/[FIRApp configure];\\\n  RCTBridge \*bridge/' ios/rnfbdemo/AppDelegate.m
rm -f ios/rnfbdemo/AppDelegate.m??

# Minimal integration on Android
sed -i -e $'s/dependencies {/dependencies {\\\n        classpath "com.google.gms:google-services:4.2.0"/' android/build.gradle
rm -f android/build.gradle??
echo "apply plugin: 'com.google.gms.google-services'" >> android/app/build.gradle
sed -i -e $'s/dependencies {/dependencies {\\\n    implementation "com.google.android.gms:play-services-base:16.1.0"/' android/app/build.gradle
rm -f android/app/build.gradle??
sed -i -e $'s/dependencies {/dependencies {\\\n    implementation "com.google.firebase:firebase-core:16.0.9"/' android/app/build.gradle
rm -f android/app/build.gradle??
echo "-keep class io.invertase.firebase.** { *; }" >> android/app/proguard-rules.pro
echo "-dontwarn io.invertase.firebase.**" >> android/app/proguard-rules.pro


# Copy the Firebase config files in
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

# Add our messaging dependency for Java
sed -i -e $'s/dependencies {/dependencies {\\\n    implementation "com.google.firebase:firebase-messaging:18.0.0"/' android/app/build.gradle
rm -f android/app/build.gradle??

# Add shortcut badging for Java, because people like it even though shortcut badging on Android is discouraged and is terrible and basically unsupportable
# (Pixel Launcher won't do it, launchers have to grant permissions, it is vendor specific, Material Design says no, etc etc)
sed -i -e $'s/dependencies {/dependencies {\\\n    implementation "me.leolin:ShortcutBadger:1.1.22@aar"/' android/app/build.gradle
rm -f android/app/build.gradle??

# Set the Java application up for multidex (needed for API<21 w/Firebase)
sed -i -e $'s/dependencies {/dependencies {\\\n    implementation "com.android.support:multidex:1.0.3"/' android/app/build.gradle
rm -f android/app/build.gradle??
sed -i -e $'s/import android.app.Application;/import android.support.multidex.MultiDexApplication;/' android/app/src/main/java/com/rnfbdemo/MainApplication.java
rm -f android/app/src/main/java/com/rnfbdemo/MainApplication.java??
sed -i -e $'s/extends Application/extends MultiDexApplication/' android/app/src/main/java/com/rnfbdemo/MainApplication.java
rm -f android/app/src/main/java/com/rnfbdemo/MainApplication.java??

# Set up AdMob Java stuff
sed -i -e $'s/dependencies {/dependencies {\\\n    implementation "com.google.firebase:firebase-ads:15.0.1"/' android/app/build.gradle
rm -f android/app/build.gradle??
sed -i -e $'s/RNFirebasePackage;/admob.RNFirebaseAdMobPackage;\\\nimport io.invertase.firebase.RNFirebasePackage;/' android/app/src/main/java/com/rnfbdemo/MainApplication.java
rm -f android/app/src/main/java/com/rnfbdemo/MainApplication.java??
sed -i -e $'s/new RNFirebasePackage()/new RNFirebasePackage(),\\\n          new RNFirebaseAdMobPackage()/' android/app/src/main/java/com/rnfbdemo/MainApplication.java
rm -f android/app/src/main/java/com/rnfbdemo/MainApplication.java??


# Set up an AdMob ID (this is the official "sample id")
sed -i -e $'s/NSAppTransportSecurity/GADApplicationIdentifier<\/key>\\\n	<string>ca-app-pub-3940256099942544~1458002511<\/string>\\\n        <key>NSAppTransportSecurity/' ios/rnfbdemo/Info.plist
rm -f ios/rnfbdemo/Info.plist??
sed -i -e $'s/<\/application>/  <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="YOUR_ADMOB_APP_ID"\/>\\\n    <\/application>/' android/app/src/main/AndroidManifest.xml
rm -f android/app/src/main/AndroidManifest.xml??

# Copy in our demonstrator App.js
rm ./App.js && cp ../App.js .

# Run the thing for iOS
react-native run-ios

# Run it for Android (assumes you have an android emulator running)
USER=`whoami`
echo "sdk.dir=/Users/$USER/Library/Android/sdk" > android/local.properties
npx react-native run-android
