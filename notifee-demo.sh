#!/bin/bash
set -e 

# Basic template create, notifee install, link
\rm -fr notifeedemo

echo "Testing react-native current + notifee current"
npx react-native init notifeedemo
cd notifeedemo

# I have problems in my country with the cocoapods CDN sometimes, use github directly
if [ "$(uname -m)" == "arm64" ]; then
  echo "arm64 detected, disabling flipper"
  sed -i -e 's/use_flipper/#&/' ios/Podfile
  sed -i -e 's/flipper_post_install/#&/' ios/Podfile
else
  sed -i -e $'s/def add_flipper_pods/source \'https:\/\/github.com\/CocoaPods\/Specs.git\'\\\n\\\ndef add_flipper_pods/' ios/Podfile
fi

rm -f ios/Podfile.??

# This is the most basic integration
echo "Adding Notifee app package"
yarn add "@notifee/react-native"

# Set the Java application up for multidex (needed for API<21 w/Firebase)
echo "Configuring Android MultiDex for API<21 support - gradle toggle, library dependency, Application object inheritance"
sed -i -e $'s/defaultConfig {/defaultConfig {\\\n        multiDexEnabled true/' android/app/build.gradle
rm -f android/app/build.gradle??
sed -i -e $'s/dependencies {/dependencies {\\\n    implementation "androidx.multidex:multidex:2.0.1"/' android/app/build.gradle
rm -f android/app/build.gradle??
sed -i -e $'s/import android.app.Application;/import androidx.multidex.MultiDexApplication;/' android/app/src/main/java/com/notifeedemo/MainApplication.java
rm -f android/app/src/main/java/com/notifeedemo/MainApplication.java??
sed -i -e $'s/extends Application/extends MultiDexApplication/' android/app/src/main/java/com/notifeedemo/MainApplication.java
rm -f android/app/src/main/java/com/notifeedemo/MainApplication.java??

# Another Java build tweak - or gradle runs out of memory during the build in big projects
echo "Increasing memory available to gradle for android java build"
echo "org.gradle.jvmargs=-Xmx2048m -XX:MaxPermSize=512m -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8" >> android/gradle.properties

# In case we have any patches
echo "Running any patches necessary to compile successfully"
cp -rv ../patches .
npx patch-package

# Copy in our demonstrator App.js
echo "Copying demonstrator App.js"
rm ./App.js && cp ../NotifeeApp.js ./App.js

# Run the thing for iOS
if [ "$(uname)" == "Darwin" ]; then
  echo "Installing pods and running iOS app"
  if [ "$(uname -m)" == "arm64" ]; then
    echo "Installing pods with prefix arch -arch x86_64"
    cd ios && arch -arch x86_64 pod install && cd ..
  else
    cd ios && pod install --repo-update && cd ..
  fi
  npx react-native run-ios
  # workaround for poorly setup Android SDK environments
  USER=`whoami`
  echo "sdk.dir=/Users/$USER/Library/Android/sdk" > android/local.properties
fi

echo "Configuring Android release build for ABI splits and code shrinking"
sed -i -e $'s/def enableSeparateBuildPerCPUArchitecture = false/def enableSeparateBuildPerCPUArchitecture = true/' android/app/build.gradle
rm -f android/app/build.gradle??
sed -i -e $'s/def enableProguardInReleaseBuilds = false/def enableProguardInReleaseBuilds = true/' android/app/build.gradle
rm -f android/app/build.gradle??
sed -i -e $'s/universalApk false/universalApk true/' android/app/build.gradle
rm -f android/app/build.gradle??

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
