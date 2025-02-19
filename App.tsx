/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 */

import React, { useEffect, useState } from 'react';
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

import { getApp, getApps } from '@react-native-firebase/app';
import { getAnalytics } from '@react-native-firebase/analytics';
import appCheck, { initializeAppCheck } from '@react-native-firebase/app-check';
import { getAppDistribution} from '@react-native-firebase/app-distribution';
import { connectAuthEmulator, FirebaseAuthTypes, getAuth, onAuthStateChanged, signInAnonymously, signOut } from '@react-native-firebase/auth';
import { getCrashlytics }  from '@react-native-firebase/crashlytics';
import { getDatabase } from '@react-native-firebase/database';
import { getDynamicLinks } from '@react-native-firebase/dynamic-links';
import { getFirestore } from '@react-native-firebase/firestore';
import { getFunctions } from '@react-native-firebase/functions';
import { getInAppMessaging } from '@react-native-firebase/in-app-messaging';
import { getInstallations } from '@react-native-firebase/installations';
import { getMessaging, getToken, onMessage } from '@react-native-firebase/messaging';
import { getPerformance } from '@react-native-firebase/perf';
import { getRemoteConfig } from '@react-native-firebase/remote-config';
import { getStorage } from '@react-native-firebase/storage';

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

onMessage(getMessaging(), (message) => {
  console.log('messaging.onMessage received: ' + JSON.stringify(message));
})

function App(): JSX.Element {
  const isDarkMode = useColorScheme() === 'dark';
  const [appCheckPresent, setAppCheckPresent] = useState(false);

  useEffect(() => {
    console.log('initializating AppCheck...');
    const rnfbProvider = appCheck().newReactNativeFirebaseAppCheckProvider();
    rnfbProvider.configure({
      android: {
        provider: __DEV__ ? 'debug' : 'playIntegrity',
        debugToken: 'invalid debug token',
      },
      apple: {
        provider: __DEV__ ? 'debug' : 'appAttestWithDeviceCheckFallback',
        debugToken: 'invalid debug token',
      },
      web: {
        provider: 'reCaptchaV3',
        siteKey: 'unknown',
      },
    });
    initializeAppCheck(getApp(), { provider: rnfbProvider}).then(() => {
      console.log('AppCheck is initialized.');
      setAppCheckPresent(true);
    });
  }, []);

  const backgroundStyle = {
    backgroundColor: isDarkMode ? Colors.darker : Colors.lighter,
  };

  const dynStyles = StyleSheet.create({
    colors: {
      color: isDarkMode ? Colors.white : Colors.black,
    },
  });

  connectAuthEmulator(getAuth(), 'http://localhost:9099');

  onAuthStateChanged(getAuth(), (user: FirebaseAuthTypes.User) => {
    console.log('onAuthStateChanged was called with user uid ' + user.uid);
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
              token: await getToken(getMessaging()),
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
          <Button title="sign in" onPress={async () => { console.log('anonymous sign in '); await signInAnonymously(getAuth())}} />
          <Button title="sign out" onPress={async () => { console.log('signing out'); await signOut(getAuth()); }} />
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
          {getApps().length && <Text style={dynStyles.colors}>app()</Text>}
          {getAnalytics().native && <Text style={dynStyles.colors}>analytics()</Text>}
          {appCheckPresent && <Text style={dynStyles.colors}>appCheck()</Text>}
          {getAppDistribution().native && <Text style={dynStyles.colors}>appDistribution()</Text>}
          {getAuth().native && <Text style={dynStyles.colors}>auth()</Text>}
          {getCrashlytics().native && <Text style={dynStyles.colors}>crashlytics()</Text>}
          {getDatabase().native && <Text style={dynStyles.colors}>database()</Text>}
          {getDynamicLinks().native && <Text style={dynStyles.colors}>dynamicLinks()</Text>}
          {getFirestore().native && <Text style={dynStyles.colors}>firestore()</Text>}
          {getFunctions().native && <Text style={dynStyles.colors}>functions()</Text>}
          {getInAppMessaging().native && <Text style={dynStyles.colors}>inAppMessaging()</Text>}
          {getInstallations().native && <Text style={dynStyles.colors}>installations()</Text>}
          {getMessaging().native && <Text style={dynStyles.colors}>messaging()</Text>}
          {getPerformance().native && <Text style={dynStyles.colors}>perf()</Text>}
          {getRemoteConfig().native && <Text style={dynStyles.colors}>remoteConfig()</Text>}
          {getStorage().native && <Text style={dynStyles.colors}>storage()</Text>}
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
