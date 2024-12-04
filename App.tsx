/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 */

import React from 'react';
import type {PropsWithChildren} from 'react';
import {
  Button,
  SafeAreaView,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  useColorScheme,
  View,
} from 'react-native';

import {Colors, Header} from 'react-native/Libraries/NewAppScreen';

import firebase from '@react-native-firebase/app';
import analytics from '@react-native-firebase/analytics';
import appCheck from '@react-native-firebase/app-check';
import appDistribution from '@react-native-firebase/app-distribution';
import auth, { FirebaseAuthTypes } from '@react-native-firebase/auth';
import crashlytics from '@react-native-firebase/crashlytics';
import database from '@react-native-firebase/database';
import dynamicLinks from '@react-native-firebase/dynamic-links';
import firestore from '@react-native-firebase/firestore';
import functions from '@react-native-firebase/functions';
import inAppMessaging from '@react-native-firebase/in-app-messaging';
import installations from '@react-native-firebase/installations';
import messaging from '@react-native-firebase/messaging';
import perf from '@react-native-firebase/perf';
import remoteConfig from '@react-native-firebase/remote-config';
import storage from '@react-native-firebase/storage';

type SectionProps = PropsWithChildren<{
  title: string;
}>;

function Section({children, title}: SectionProps): JSX.Element {
  const isDarkMode = useColorScheme() === 'dark';
  return (
    <View style={styles.sectionContainer}>
      <Text
        style={[
          styles.sectionTitle,
          {
            color: isDarkMode ? Colors.white : Colors.black,
          },
        ]}>
        {title}
      </Text>
      <Text
        style={[
          styles.sectionDescription,
          {
            color: isDarkMode ? Colors.light : Colors.dark,
          },
        ]}>
        {children}
      </Text>
    </View>
  );
}

firebase.messaging().onMessage((message) => {
  console.log('messaging.onMessage received: ' + JSON.stringify(message));
})

function App(): JSX.Element {
  const isDarkMode = useColorScheme() === 'dark';

  const backgroundStyle = {
    backgroundColor: isDarkMode ? Colors.darker : Colors.lighter,
  };

  const dynStyles = StyleSheet.create({
    colors: {
      color: isDarkMode ? Colors.white : Colors.black,
    },
  });

  firebase.auth().useEmulator('http://localhost:9099');

  firebase.auth().onAuthStateChanged((user) => {
    console.log('onAuthStateChanged was called with user ' + user);
  });

  const sendSilent = async () => {
    console.log('sending a silent notification now');
  };

  const sendVisible = async () => {
    console.log('sending a visible notification now');
    // https://sendfcm-6rg4g7hv7q-uc.a.run.app
    const fcmRequest = await fetch(
      'https://us-central1-react-native-firebase-testing.cloudfunctions.net/sendFCM',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          data: {
            delay: 10000,
            message: {
              // TODO all the mesage stuff here
              token: await firebase.messaging().getToken(),
              notification: {
                title: 'hello world title',
                body: 'hello world body',
              },
              android:{
                priority: 'high'
              },
            }
          },
        }),
        redirect: 'follow',
      },
    );
    const { result } = await fcmRequest.json();
    console.log('got sendFCM result: ' + JSON.stringify(result, null, 2));
  };

  return (
    <SafeAreaView style={backgroundStyle}>
      <StatusBar
        barStyle={isDarkMode ? 'light-content' : 'dark-content'}
        backgroundColor={backgroundStyle.backgroundColor}
      />
      <ScrollView
        contentInsetAdjustmentBehavior="automatic"
        style={backgroundStyle}>
          <Button title="sign in" onPress={async () => { console.log('anonymous sign in '); await firebase.auth().signInAnonymously()}} />
          <Button title="sign out" onPress={async () => { console.log('signing out'); await firebase.auth().signOut(); }} />
          <Button title="Send Silent Notification to Device" onPress={async () => { console.log('silent notification'); await sendSilent()}} />
          <Button title="Send Visible Notification to Device" onPress={async () => { console.log('visible notification'); await sendVisible()}} />

        <View
          style={{
            backgroundColor: isDarkMode ? Colors.black : Colors.white,
            alignItems: 'center',
          }}>
          <Section title="RNFirebase Build Demo" />
          <Text />
          <Text style={dynStyles.colors}>JSI Executor: {global.__jsiExecutorDescription}</Text>
          <Text />
          <Text style={dynStyles.colors}>These firebase modules appear to be working:</Text>
          <Text />
          {firebase.apps.length && <Text style={dynStyles.colors}>app()</Text>}
          {analytics().native && <Text style={dynStyles.colors}>analytics()</Text>}
          {appCheck().native && <Text style={dynStyles.colors}>appCheck()</Text>}
          {appDistribution().native && <Text style={dynStyles.colors}>appDistribution()</Text>}
          {auth().native && <Text style={dynStyles.colors}>auth()</Text>}
          {crashlytics().native && <Text style={dynStyles.colors}>crashlytics()</Text>}
          {database().native && <Text style={dynStyles.colors}>database()</Text>}
          {dynamicLinks().native && <Text style={dynStyles.colors}>dynamicLinks()</Text>}
          {firestore().native && <Text style={dynStyles.colors}>firestore()</Text>}
          {functions().native && <Text style={dynStyles.colors}>functions()</Text>}
          {inAppMessaging().native && <Text style={dynStyles.colors}>inAppMessaging()</Text>}
          {installations().native && <Text style={dynStyles.colors}>installations()</Text>}
          {messaging().native && <Text style={dynStyles.colors}>messaging()</Text>}
          {perf().native && <Text style={dynStyles.colors}>perf()</Text>}
          {remoteConfig().native && <Text style={dynStyles.colors}>remoteConfig()</Text>}
          {storage().native && <Text style={dynStyles.colors}>storage()</Text>}
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  sectionContainer: {
    marginTop: 32,
    paddingHorizontal: 24,
  },
  sectionTitle: {
    fontSize: 24,
    fontWeight: '600',
  },
  sectionDescription: {
    marginTop: 8,
    fontSize: 18,
    fontWeight: '400',
  },
  highlight: {
    fontWeight: '700',
  },
});

export default App;
