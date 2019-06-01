# rnfb-demo

Demonstrator App for react-native-firebase

## Install / use

1. Fork and clone the repo
1. run `make-demo.sh` on a mac, that has react-native-cli installed as a global package

### Firebase Config

Go to the Firebase Console, create a new project, and set up demo apps

1. Android package name must be 'com.rnfbdemo'
1. iOS bundle name must be 'com.rnfbdemo'
1. Download / install the google-services.json for your new rnfbdemo android app to `android/app/google-services.json`
1. Drop the Google-services.plist file into `ios/rnfbdemo/Google-services.plist`

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

1. How to correctly install and link the core module in a react-native-firebase project

...and that's it for now. None of the other parts are configured or demonstrated yet
