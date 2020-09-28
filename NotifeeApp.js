/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 * @flow
 */

import React, {Component} from 'react';
import {Button, Platform, StyleSheet, Text, View} from 'react-native';
import notifee, {
  AndroidLaunchActivityFlag,
  IOSAuthorizationStatus,
  IOSNotificationPermissions,
} from '@notifee/react-native';

async function onDisplayNotification() {
  // Create a channel
  try {
    const channelId = await notifee.createChannel({
      id: 'default',
      name: 'Default Channel',
    });

    const settings = await notifee.requestPermission();

    if (settings.authorizationStatus === IOSAuthorizationStatus.DENIED) {
      console.log('User denied permissions request');
    } else if (
      settings.authorizationStatus === IOSAuthorizationStatus.AUTHORIZED
    ) {
      console.log('User granted permissions request');
    } else if (
      settings.authorizationStatus === IOSAuthorizationStatus.PROVISIONAL
    ) {
      console.log('User provisionally granted permissions request');
    }

    // Display a notification
    await notifee.displayNotification({
      title: 'Notification Title',
      body: 'Main body content of the notification',
      android: {
        channelId,
        pressAction: {
          id: 'default',
          launchActivity: 'default',
          launchActivityFlags: [AndroidLaunchActivityFlag.SINGLE_TOP],
        },
      },
    });
  } catch (e) {
    console.log('Failed to display notification?', e);
  }
}

const instructions = Platform.select({
  ios: 'Press Cmd+R to reload,\n' + 'Cmd+D or shake for dev menu',
  android:
    'Double tap R on your keyboard to reload,\n' +
    'Shake or press menu button for dev menu',
});

type Props = {};
export default class App extends Component<Props> {
  render() {
    return (
      <View style={styles.container}>
        <Text style={styles.welcome}>Notifee React Native Demo</Text>
        <Text style={styles.instructions}>To get started, edit App.js</Text>
        <Text style={styles.instructions}>{instructions}</Text>
        <Button
          title="Display Notification"
          onPress={() => onDisplayNotification()}
        />
      </View>
    );
  }
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#F5FCFF',
  },
  welcome: {
    fontSize: 20,
    textAlign: 'center',
    margin: 10,
  },
  instructions: {
    textAlign: 'center',
    color: '#333333',
    marginBottom: 5,
  },
});
