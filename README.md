# rnfb-demo

Demonstrator App for react-native-firebase - reasonably up to date with current stable versions

## Install / use

### Windows pre-install steps

Maintaining the script for both a Unix-style and non-Unix-style is not feasible with time available.
So the way to run this on Windows is to make Windows behave more Unix-style.

1. Install "WSL" - the Windows Subsystem For Linux (Ubuntu 20LTS flavor)
1. Open your Ubuntu WSL shell and install the [Node Version Manager / "nvm"](https://github.com/nvm-sh/nvm/blob/master/README.md#installing-and-updating)
  1. `curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.0/install.sh | bash`

### macOS / Linux (developed on Ubuntu 20) / Windows WSL steps

1. Fork and clone the repo
1. Make sure yarn is installed (`npm i -g yarn`)
1. Do the various Config section steps below
1. run `make-demo.sh`

## One-time Configuration steps

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
