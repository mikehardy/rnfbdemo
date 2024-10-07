/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 * @flow
 */

import React, {useEffect} from 'react';
import {Button, Platform, StyleSheet, Text, View} from 'react-native';
import notifee, {
  AndroidLaunchActivityFlag,
  AuthorizationStatus,
  EventType,
} from '@notifee/react-native';

notifee.onBackgroundEvent(async ({type, detail}) => {
  const {notification, pressAction} = detail;
  console.log(
    `[onBackgroundEvent] notification id: ${
      notification !== undefined ? notification.id : 'undefined'
    },  event type: ${EventType[type]}, press action: ${pressAction?.id}`,
  );
});

async function createChannel() {
  let channelId = 'default';
  try {
    channelId = await notifee.createChannel({
      id: 'default',
      name: 'Default Channel',
    });
  } catch (e) {
    console.log('Unable to create a channel: ', JSON.stringify(e));
  }
  return channelId;
}

async function requestPermissions() {
  try {
    const settings = await notifee.requestPermission();

    if (settings.authorizationStatus === AuthorizationStatus.DENIED) {
      console.log('User denied permissions request');
    } else if (
      settings.authorizationStatus === AuthorizationStatus.AUTHORIZED
    ) {
      console.log('User granted permissions request');
    } else if (
      settings.authorizationStatus === AuthorizationStatus.PROVISIONAL
    ) {
      console.log('User provisionally granted permissions request');
    }
  } catch (e) {
    console.log('Unable to request permissions: ', JSON.stringify(e));
  }
}

async function onDisplayNotification() {
  try {
    const channelId = await createChannel();
    await requestPermissions();

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

async function setCategories() {
  await notifee.setNotificationCategories([
    {
      id: 'post',
      actions: [
        {
          id: 'like',
          title: 'Like Post',
        },
        {
          id: 'dislike',
          title: 'Dislike Post',
        },
      ],
    },
  ]);
}

async function onDisplayNotificationWithActions() {
  // Create a channel
  try {
    const channelId = await createChannel();
    await requestPermissions();

    // Display a notification
    await notifee.displayNotification({
      title: 'New post from John',
      body: 'Hey everyone! Check out my new blog post on my website.',
      ios: {
        categoryId: 'post',
      },
      android: {
        channelId,
        actions: [
          {
            title: 'Like',
            pressAction: {
              id: 'like',
              launchActivity: 'default',
              launchActivityFlags: [AndroidLaunchActivityFlag.SINGLE_TOP],
            },
          },
          {
            title: 'Dislike',
            pressAction: {
              id: 'dislike',
              launchActivity: 'default',
              launchActivityFlags: [AndroidLaunchActivityFlag.SINGLE_TOP],
            },
          },
        ],
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

export default function App() {
  useEffect(() => {
    setCategories();
    return notifee.onForegroundEvent(({type, detail}) => {
      const {notification, pressAction} = detail;
      const pressActionLabel = pressAction
        ? `, press action: ${pressAction?.id}`
        : '';
      console.log(
        `[onForegroundEvent] notification id: ${
          notification !== undefined ? notification.id : 'undefined'
        },  event type: ${EventType[type]}${pressActionLabel}`,
      );

      switch (type) {
        case EventType.DISMISSED:
          console.log(
            '[onForegroundEvent] User dismissed notification',
            notification,
          );
          break;
        case EventType.PRESS:
          console.log(
            '[onForegroundEvent] User pressed notification',
            notification,
          );
          break;
        case EventType.ACTION_PRESS:
          console.log(
            '[onForegroundEvent] User pressed an action',
            notification,
            detail.pressAction,
          );
          // On Android the notification does not dismiss automatically if it was an interaction press, so we dismiss it ourselves
          console.log(
            '[onBackgroundEvent] ACTION_PRESS: cancelling notification',
          );
          if (notification !== undefined && notification.id !== undefined) {
            notifee.cancelNotification(notification.id);
          }
          break;
      }
    });
  }, []);

  return (
    <View style={styles.container}>
      <Text style={styles.welcome}>Notifee React Native Demo</Text>
      <Text style={styles.instructions}>To get started, edit App.js</Text>
      <Text style={styles.instructions}>{instructions}</Text>
      <Button
        title="Display Notification"
        onPress={() => onDisplayNotification()}
      />
      <Button
        title="Display Notification With Actions"
        onPress={() => onDisplayNotificationWithActions()}
      />
    </View>
  );
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
