#!/bin/bash
set -e 

RN_VER=0.75.4
NOTIFEE_VER=9.1.1

# Basic template create, notifee install, link
\rm -fr notifeedemo notifeewebdemo

echo "Testing react-native ${RN_VER} + notifee ${NOTIFEE_VER}"
npm_config_yes=true npx react-native@${RN_VER} init notifeedemo --skip-install --skip-git-init --version=${RN_VER}
cd notifeedemo

# New versions of react-native include annoying Ruby stuff that forces use of old rubies. Obliterate.
if [ -f Gemfile ]; then
  rm -f Gemfile* .ruby*
fi

# Now run our initial dependency install
touch yarn.lock
yarn
npm_config_yes=true npx pod-install

# At this point we have a clean react-native project. Absolutely stock from the upstream template.

# This is the most basic integration - adding the package - local maven repo not needed with modern notifee
echo "Adding Notifee app package"
yarn add "@notifee/react-native@${NOTIFEE_VER}"

# Optional: build performance optimization to use ccache - asks xcodebuild to use clang and clang++ without the fully-qualified path
# That means that you can then make a symlink in your path with clang or clang++ and have it use a different binary
# In that way you can install ccache or buildcache and get much faster compiles...
sed -i -e $'s/post_install do |installer|/post_install do |installer|\\\n    installer.pods_project.targets.each do |target|\\\n      target.build_configurations.each do |config|\\\n        config.build_settings["CC"] = "clang"\\\n        config.build_settings["LD"] = "clang"\\\n        config.build_settings["CXX"] = "clang++"\\\n        config.build_settings["LDPLUSPLUS"] = "clang++"\\\n      end\\\n    end\\\n/' ios/Podfile
rm -f ios/Podfile??

# Optional: Cleaner build logs - libevent pulled in by react core / flipper items are ridiculously noisy otherwise
sed -i -e $'s/post_install do |installer|/post_install do |installer|\\\n    installer.pods_project.targets.each do |target|\\\n      target.build_configurations.each do |config|\\\n        config.build_settings["GCC_WARN_INHIBIT_ALL_WARNINGS"] = "YES"\\\n      end\\\n    end\\\n/' ios/Podfile
rm -f ios/Podfile??

# Copy in our demonstrator App
echo "Copying demonstrator App"
rm ./App.tsx && cp ../NotifeeApp.tsx ./App.tsx

# Test: You have to re-run patch-package after yarn since it is not integrated into postinstall
echo "Running any patches necessary to compile successfully"
cp -rv ../patches .
npm_config_yes=true npx patch-package

# Run the thing for iOS
if [ "$(uname)" == "Darwin" ]; then
  echo "Installing pods and running iOS app"
  npm_config_yes=true npx pod-install
  # Check iOS debug mode compile
  npx react-native run-ios --mode Debug

  # Check iOS release mode compile
  echo "Installing pods and running iOS app in release mode"
  npx react-native run-ios --mode Release

  # New architecture enable: RCT_NEW_ARCH_ENABLED=1 env var then pod install

  # Optional: workaround for poorly setup Android SDK environments on macs
  USER=$(whoami)
  echo "sdk.dir=/Users/$USER/Library/Android/sdk" > android/local.properties
fi

# Test: make sure proguard works
echo "Configuring Android release build for ABI splits and code shrinking"
sed -i -e $'s/def enableProguardInReleaseBuilds = false/def enableProguardInReleaseBuilds = true/' android/app/build.gradle
rm -f android/app/build.gradle??

# Test: Run it for Android (assumes you have an android emulator running)
echo "Running android app in release mode"
npx react-native run-android --mode release

# Test: Let it start up, then uninstall it (otherwise ABI-split-generated version codes will prevent debug from installing)
sleep 30
pushd android
./gradlew uninstallRelease
popd

# Test: may or may not be commented out, depending on if have an emulator available
# I run it manually in testing when I have one, comment if you like
echo "Running android app in debug mode"
npx react-native run-android --mode debug


# new architecture put this in android/gradle.properties +newArchEnabled=true

# Test web
# cd ..
# echo "Running android app in web mode"
# npm_config_yes=true npx react-native init notifeewebdemo --template criszz77/luna --skip-install
# cd notifeewebdemo
# yarn
# yarn add @notifee/react-native

# # A quirk of this example, sometimes we have local example-specific patches
# echo "Running any patches necessary to compile successfully"
# cp -rv ../patches .
# npm_config_yes=true npx patch-package

# # Copy in our demonstrator App.js
# echo "Copying demonstrator App.js"
# rm -f ./src/App.tsx && cp ../NotifeeApp.js ./src/App.tsx

# yarn web