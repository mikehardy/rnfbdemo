#!/bin/bash
set -e 

# Basic template create, rnfb install, link
\rm -fr rnfbdemo
react-native init rnfbdemo
cd rnfbdemo
npm i react-native-firebase
cd ios
cp ../../Podfile .
pod install
cd ..
react-native link react-native-firebase

# Perform the minimal edit to integrate it on iOS
sed -i -e $'s/AppDelegate.h"/AppDelegate.h"\\\n#import "Firebase.h"/' ios/rnfbdemo/AppDelegate.m
rm -f ios/rnfbdemo/AppDelegate.m??
sed -i -e $'s/RCTBridge \*bridge/[FIRApp configure];\\\n  RCTBridge \*bridge/' ios/rnfbdemo/AppDelegate.m
rm -f ios/rnfbdemo/AppDelegate.m??

# Copy the Firebase config files in
cp ../GoogleService-Info.plist ios/rnfbdemo/
cp ../google-services.json android/app/

# Run the thing (assumes you have an android emulator running)
react-native run-ios
#npx react-native run-android
