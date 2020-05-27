# rnfb-demo

Demonstrator App for react-native-firebase

## Install / use

1. Fork and clone the repo
1. Do the various Config section steps below
1. run `make-demo-v6.sh` for react-native-firebase v6+, `make-demo.sh` for react-native-firebase v5.x (or `make-demo-rn59.sh` if you want to show react-native-firebase v5 + react-native@0.59 vs 0.60) on a mac, that has react-native-cli installed as a global package

### Firebase Config

Go to the Firebase Console, create a new project, and set up demo apps

1. Android package name must be 'com.rnfbdemo'
1. iOS bundle name must be 'com.rnfbdemo'
1. Download / install the google-services.json for your new rnfbdemo android app to the root of this repo (it will be copied into place)
1. Drop the Google-services.plist file the root of this repo (it will be copied in to place)

### Apple Developer Config

To test remote notifications while offline, you'll have to do a lot of Apple setup. I'm not going to help anyone with this, sorry, but here are the requirements:

1. You must have an developer account with apple
1. You will need to configure a push notification certificate and key
1. You will need a provisioning profile with background-fetch and push notifications entitlements
1. You will need to add that push notification key to your firebase cloud messaging configuration
1. You might want to make an actual test application so you can distribute it with testflight to test things
1. You will have to do all that yourself. Maybe create wiki pages in this project to share tips, but Apple/XCode/iOS profile / cert / entitlements issues are not issues for this repo

## Current status

Currently this repo demonstrates:

1. How to correctly install and link the most popular modules in a react-native-firebase project
1. Has a very basic App.js that just shows they were installed correctly so you can see the app boots and loads native modules

...and that's it for now, but it's enough to show the basics on what you need to do to integrate react-native-firebase with your project
