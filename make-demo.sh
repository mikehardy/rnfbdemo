#!/bin/bash
set -e 

RN_VER=0.73.0-rc.3

#######################################################################################################
#######################################################################################################
# This whole section is test setup, and environment verification, it does not represent integration yet
# Test: We need to verify our environment first, so we fail fast for easily detectable things
if [ "$(uname)" == "Darwin" ]; then
  # If the keychain is unlocked then this fails in the middle, let's check that now and fail fast
  if ! security show-keychain-info login.keychain > /dev/null 2>&1; then
    echo "Login keychain is not unlocked, codesigning will fail so macCatalyst build wll fail."
    echo "run 'security unlock-keychain login.keychain' to unlock the login keychain then re-run"
    exit 1
  fi

  # We do not want to run under Rosetta 2, brew doesn't work and compiles might not work after
  arch_name="$(uname -m)"
  if [ "${arch_name}" = "x86_64" ]; then
    if [ "$(sysctl -in sysctl.proc_translated)" = "1" ]; then
      echo "Running on Rosetta 2"
      echo "This is not supported. Run \`env /usr/bin/arch -arm64 /bin/bash --login\` then try again"
      exit 1
    else
      echo "Running on native Intel"
    fi
  elif [ "${arch_name}" = "arm64" ]; then
    echo "Running on ARM"
  else
    echo "Unknown architecture: ${arch_name}"
  fi

  # We need a development team or macCatalyst build will fail
  if [ "$XCODE_DEVELOPMENT_TEAM" == "" ]; then
    printf "\n\n\n\n\n**********************************\n\n\n\n"
    printf "You must set XCODE_DEVELOPMENT_TEAM environment variable to your team id to test macCatalyst"
    printf "Try running it like: XCODE_DEVELOPMENT_TEAM=2W4T2B656C ./make-demo.sh (but with your id)"
    printf "\n\n\n\n\n**********************************\n\n\n\n"
    exit 1
  fi
fi

# Test: Previous compiles may confound future compiles, erase...
\rm -fr "$HOME/Library/Developer/Xcode/DerivedData/rnfbdemo*"

# Test: Basic template create, rnfb install, link
\rm -fr rnfbdemo

echo "Testing react-native ${RN_VER}"

if ! which yarn > /dev/null 2>&1; then
  echo "This script uses yarn, please install yarn (for example \`npm i yarn -g\` and re-try"
  exit 1
fi
#######################################################################################################
#######################################################################################################

# Initialize a fresh project.
# We say "skip-install" because we control our ruby version and cocoapods (part of install) does not like it
npm_config_yes=true npx react-native@${RN_VER} init rnfbdemo --skip-install --version=${RN_VER}
cd rnfbdemo

# New versions of react-native include annoying Ruby stuff that forces use of old rubies. Obliterate.
if [ -f Gemfile ]; then
  rm -f Gemfile* .ruby*
fi

# Now run our initial dependency install
yarn
NO_FLIPPER=1 USE_FRAMEWORKS=static npm_config_yes=true npx pod-install

# At this point we have a clean react-native project. Absolutely stock from the upstream template.

#############################################################################################################
# Required: Static Frameworks linkage set up in cocoapods, and various related workarounds for compatibility.
#############################################################################################################

# CLEANUP - this is controlled now via environment variables when you run pod install:
# NO_FLIPPER=1 USE_FRAMEWORKS=static

# For ease of reproduction from command line where you may forget to set the environment variables,
# we will manually force the Podfile to static frameworks and disabled flipper

# Required: turn on static frameworks with static linkage, and tell react-native-firebase that is how we are linking
sed -i -e $'s/config = use_native_modules!/config = use_native_modules!\\\n  use_frameworks! :linkage => :static\\\n  $RNFirebaseAsStaticFramework = true/' ios/Podfile

# Required Workaround: Static frameworks does not work with flipper - toggle it off (follow/vote: https://github.com/facebook/flipper/issues/3861)
sed -i -e $'s/:flipper_configuration/# :flipper_configuration/' ios/Podfile
rm -f ios/Podfile.??
#############################################################################################################


##################################################################################################
# This section is only required for the script to work fully automatic.
# In your project you will use Xcode user interface to add your GoogleService-Info.plist file
##################################################################################################
# Set up python virtual environment so we can do some local mods to Xcode project with mod-pbxproj
# FIXME need to verify that python3 exists (recommend brew) and has venv module installed
if [ "$(uname)" == "Darwin" ]; then
  echo "Setting up python virtual environment + mod-pbxproj for Xcode project edits"
  python3 -m venv virtualenv
  source virtualenv/bin/activate
  pip install pbxproj

  # set PRODUCT_BUNDLE_IDENTIFIER to com.rnfbdemo - this may be bound to development team?
  # you may need to change it
  sed -i -e $'s/org.reactjs.native.example/com/' ios/rnfbdemo.xcodeproj/project.pbxproj
  rm -f ios/rnfbdemo.xcodeproj/project.pbxproj-e

  # Toggle on iPad: add build flag: TARGETED_DEVICE_FAMILY = "1,2"
  pbxproj flag ios/rnfbdemo.xcodeproj --target rnfbdemo TARGETED_DEVICE_FAMILY "1,2"
fi
##################################################################################################

# Optional: Apple M1 workaround - builds may have a problem with architectures on Apple Silicon and Intel, some exclusions may help
# sed -i -e $'s/post_install do |installer|/post_install do |installer|\\\n    installer.aggregate_targets.each do |aggregate_target|\\\n      aggregate_target.user_project.native_targets.each do |target|\\\n        target.build_configurations.each do |config|\\\n          config.build_settings[\'ONLY_ACTIVE_ARCH\'] = \'YES\'\\\n          config.build_settings[\'EXCLUDED_ARCHS\'] = \'i386\'\\\n        end\\\n      end\\\n      aggregate_target.user_project.save\\\n    end\\\n/' ios/Podfile
# rm -f ios/Podfile.??

# Optional: build performance optimization to use ccache - asks xcodebuild to use clang and clang++ without the fully-qualified path
# That means that you can then make a symlink in your path with clang or clang++ and have it use a different binary
# In that way you can install ccache or buildcache and get much faster compiles...
sed -i -e $'s/post_install do |installer|/post_install do |installer|\\\n    installer.pods_project.targets.each do |target|\\\n      target.build_configurations.each do |config|\\\n        config.build_settings["CC"] = "clang"\\\n        config.build_settings["LD"] = "clang"\\\n        config.build_settings["CXX"] = "clang++"\\\n        config.build_settings["LDPLUSPLUS"] = "clang++"\\\n      end\\\n    end\\\n/' ios/Podfile
rm -f ios/Podfile??

# Optional: Cleaner build logs - libevent pulled in by react core / flipper items are ridiculously noisy otherwise
sed -i -e $'s/post_install do |installer|/post_install do |installer|\\\n    installer.pods_project.targets.each do |target|\\\n      target.build_configurations.each do |config|\\\n        config.build_settings["GCC_WARN_INHIBIT_ALL_WARNINGS"] = "YES"\\\n      end\\\n    end\\\n/' ios/Podfile
rm -f ios/Podfile??

# Test: You have to re-run patch-package after yarn since it is not integrated into postinstall, so run it again
echo "Running any patches necessary to compile successfully"
cp -rv ../patches .
npm_config_yes=true npx patch-package

# Test: Run the thing for iOS
if [ "$(uname)" == "Darwin" ]; then

  # Optional: Check catalyst build
  if ! [ "$XCODE_DEVELOPMENT_TEAM" == "" ]; then

    #################################################################################################
    # This section is so the script may work fully automatic.
    # If you are targeting macCatalyst, you will use the Xcode UI to add your development team.
    # add file rnfbdemo/rnfbdemo.entitlements, with reference to rnfbdemo target, but no build phase
    echo "Adding macCatalyst entitlements file / build flags to Xcode project"
    cp ../rnfbdemo.entitlements ios/rnfbdemo/
    pbxproj file ios/rnfbdemo.xcodeproj rnfbdemo/rnfbdemo.entitlements --target rnfbdemo -C
    # add build flag: CODE_SIGN_ENTITLEMENTS = rnfbdemo/rnfbdemo.entitlements
    pbxproj flag ios/rnfbdemo.xcodeproj --target rnfbdemo CODE_SIGN_ENTITLEMENTS rnfbdemo/rnfbdemo.entitlements
    # add build flag: SUPPORTS_MACCATALYST = YES
    pbxproj flag ios/rnfbdemo.xcodeproj --target rnfbdemo SUPPORTS_MACCATALYST YES
    # add build flag 				DEVELOPMENT_TEAM = 2W4T2B656C;
    pbxproj flag ios/rnfbdemo.xcodeproj --target rnfbdemo DEVELOPMENT_TEAM "$XCODE_DEVELOPMENT_TEAM"
    #################################################################################################

    # Required for macCatalyst: Podfile workarounds for signing and library paths are built-in 0.70+ with a specific flag:
    sed -i -e $'s/mac_catalyst_enabled => false/mac_catalyst_enabled => true/' ios/Podfile

    echo "Installing pods and running iOS app in macCatalyst mode"
    NO_FLIPPER=1 USE_FRAMEWORKS=static npm_config_yes=true npx pod-install

    # Now run it with our mac device name as device target, that triggers catalyst build
    # Need to check if the development team id is valid? error 70 indicates team not added as account / cert not present / xcode does not have access to keychain?

    # For some reason, the device id returned if you use the computer name is wrong.
    # It is also wrong from ios-deploy or xcrun xctrace list devices
    # The only way I have found to get the right ID is to provide the wrong one then parse out the available one
    CATALYST_DESTINATION=$(xcodebuild -workspace ios/rnfbdemo.xcworkspace -configuration Debug -scheme rnfbdemo -destination id=7153382A-C92B-5798-BEA3-D82D195F25F8 2>&1|grep macOS|grep Catalyst|head -1 |cut -d':' -f5 |cut -d' ' -f1)

    # WIP This requires a CLI patch to the iOS platform to accept a UDID it cannot probe, and to set type to catalyst
    # CLEANUP? NO_FLIPPER=1 npx react-native run-ios --udid "$CATALYST_DESTINATION"
    # FIXME this is not working anymore - fatal error: 'React/RCTComponentViewProtocol.h' file not found
    NO_FLIPPER=1 USE_FRAMEWORKS=static npx react-native run-ios --udid "$CATALYST_DESTINATION" --mode Debug

    # !! The build failure is mostly hidden, you see '"scodebuild" exited with error code `65`'
    # you may see the actual build command used slightly higher in the output window, it will look like:
    #
    # > xcodebuild -workspace rnfbdemo.xcworkspace -configuration Debug -scheme rnfbdemo -destination id=00008112-000E45A20C2BC01E
    #
    # ...but with a different destination id to match your desktop
    #
    # If you run that command from `rnfbdemo/ios` you will get the actual compile output
    # There you can see the actual error.

  fi
fi
