#!/bin/bash
set -e 

# Basic template create, notifee install, link
\rm -fr notifeedemo

RNVERSION=0.68.0

echo "Testing react-native $RNVERSION + notifee current"
npm_config_yes=true npx react-native init notifeedemo --version=$RNVERSION --skip-install
cd notifeedemo

# New versions of react-native include annoying Ruby stuff that forces use of old rubies. Obliterate.
if [ -f Gemfile ]; then
  rm -f Gemfile* .ruby*
fi

# Now run our initial dependency install
yarn
npm_config_yes=true npx pod-install

# Notifee requires minimum sdk of 20
sed -i -e $'s/minSdkVersion = 16/minSdkVersion = 21/' android/build.gradle
rm -f android/build.gradle??

# Notifee requires Android12, bump up our compile and target versions on android as needed
sed -i -e $'s/compileSdkVersion = 28/compileSdkVersion = 31/' android/build.gradle
sed -i -e $'s/targetSdkVersion = 28/targetSdkVersion = 31/' android/build.gradle
sed -i -e $'s/compileSdkVersion = 29/compileSdkVersion = 31/' android/build.gradle
sed -i -e $'s/targetSdkVersion = 29/targetSdkVersion = 31/' android/build.gradle
sed -i -e $'s/compileSdkVersion = 30/compileSdkVersion = 31/' android/build.gradle
sed -i -e $'s/targetSdkVersion = 30/targetSdkVersion = 31/' android/build.gradle
rm -f android/build.gradle??

# Android 12 does require a tweak to the stock template AndroidManifest for compliance - TODO, not needed in RN67+, add if check
#sed -i -e $'s/android:launchMode/android:exported="true"\\\n        android:launchMode/' android/app/src/main/AndroidManifest.xml
#rm -f android/app/src/main/AndroidManifest.xml??

# Notifee requires iOS minimum of 10 - not needed in react-native >=67 (68 uses 11 already)
#sed -i -e $'s/platform :ios, \'9.0\'/platform :ios, \'10.0\'/' ios/Podfile
#rm -f ios/Podfile??

# old versions of metro has a problem with babel. Visible in really old react-native like 0.61.2
MRNBP_VERSION=`npm_config_yes=true npx json -f package.json  'devDependencies.metro-react-native-babel-preset'`
if [ "$MRNBP_VERSION" == '^0.51.1' ]; then
  echo "Bumping old metro-react-native-babel-preset version to something that works with modern babel."
  yarn add metro-react-native-babel-preset@^0.59 --dev
fi

# This is the most basic integration - adding the package, adding the necessary Android local repository
echo "Adding Notifee app package"
yarn add "@notifee/react-native"
sed -i -e $'s/google()/google()\\\n        maven \{ url "$rootDir\/..\/node_modules\/@notifee\/react-native\/android\/libs" \}/' android/build.gradle
rm -f android/build.gradle??

# A general react-native Java build tweak - or gradle runs out of memory sometimes - not needed with RN68+
#echo "Increasing memory available to gradle for android java build"
#echo "org.gradle.jvmargs=-Xmx2048m -XX:MaxPermSize=512m -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8" >> android/gradle.properties

# A quirk of this example, sometimes we have local example-specific patches
echo "Running any patches necessary to compile successfully"
cp -rv ../patches .
npm_config_yes=true npx patch-package

# Copy in our demonstrator App.js
echo "Copying demonstrator App.js"
rm ./App.js && cp ../NotifeeApp.js ./App.js

# This is just a speed optimization, very optional, but asks xcodebuild to use clang and clang++ without the fully-qualified path
# That means that you can then make a symlink in your path with clang or clang++ and have it use a different binary
# In that way you can install ccache or buildcache and get much faster compiles...
sed -i -e $'s/react_native_post_install(installer)/react_native_post_install(installer)\\\n\\\n    installer.pods_project.targets.each do |target|\\\n      target.build_configurations.each do |config|\\\n        config.build_settings["CC"] = "clang"\\\n        config.build_settings["LD"] = "clang"\\\n        config.build_settings["CXX"] = "clang++"\\\n        config.build_settings["LDPLUSPLUS"] = "clang++"\\\n      end\\\n    end/' ios/Podfile
rm -f ios/Podfile??

# This makes the iOS build much quieter. In particular libevent dependency, pulled in by react core / flipper items is ridiculously noisy.
sed -i -e $'s/react_native_post_install(installer)/react_native_post_install(installer)\\\n    \\\n    installer.pods_project.targets.each do |target|\\\n      target.build_configurations.each do |config|\\\n        config.build_settings["GCC_WARN_INHIBIT_ALL_WARNINGS"] = "YES"\\\n      end\\\n    end/' ios/Podfile

# Run the thing for iOS
if [ "$(uname)" == "Darwin" ]; then
  echo "Installing pods and running iOS app"
  npm_config_yes=true npx pod-install

  npx react-native run-ios

  # Example-specific path workaround for poorly setup Android SDK environments
  USER=`whoami`
  echo "sdk.dir=/Users/$USER/Library/Android/sdk" > android/local.properties
fi

# Example-specific build tweaks so we really exercise the module in release mode
echo "Configuring Android release build for ABI splits and code shrinking"
sed -i -e $'s/def enableSeparateBuildPerCPUArchitecture = false/def enableSeparateBuildPerCPUArchitecture = true/' android/app/build.gradle
rm -f android/app/build.gradle??
sed -i -e $'s/def enableProguardInReleaseBuilds = false/def enableProguardInReleaseBuilds = true/' android/app/build.gradle
rm -f android/app/build.gradle??
sed -i -e $'s/universalApk false/universalApk true/' android/app/build.gradle
rm -f android/app/build.gradle??

# Run it for Android (assumes you have an android emulator running)
echo "Running android app"
pushd android
./gradlew uninstallRelease
popd
npx react-native run-android --variant release --no-jetifier

# Let it start up, then uninstall it (otherwise ABI-split-generated version codes will prevent debug from installing)
sleep 10
pushd android
./gradlew uninstallRelease
popd

# may or may not be commented out, depending on if have an emulator available
# I run it manually in testing when I have one, comment if you like
npx react-native run-android --no-jetifier
