/**
 * @format
 */

import {AppRegistry} from 'react-native';
import {
  getMessaging,
  setBackgroundMessageHandler,
} from '@react-native-firebase/messaging';
import App from './App';
import {name as appName} from './app.json';

setBackgroundMessageHandler(getMessaging(), async (message) => {
  setImmediate(() => {
    console.log(
      'This is running from setBackgroundMessageHandler::setImmediate',
    );
  });

  console.log(
    'setBackgroundMessageHandler JS executing. Received message: ' +
      JSON.stringify(message),
  );

  // // Display a notification
  // await notifee.displayNotification({
  //   title: 'Notification Title',
  //   body: 'Main body content of the notification',
  //   android: {
  //     channelId: 'misc',
  //     // pressAction is needed if you want the notification to open the app when pressed
  //     pressAction: {
  //       id: 'default',
  //     },
  //   },
  // });
});

// notifee.onBackgroundEvent(async event => {
//   setImmediate(() => {
//     console.log('This is running from notifee.onBacgroundEvent::setImmediate');
//   });

//   console.log('notifee.onBackgroundEvent with event: ' + JSON.stringify(event));
// });

AppRegistry.registerComponent(appName, () => App);
