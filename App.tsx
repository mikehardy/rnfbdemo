/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 */

import React, {useState} from 'react';
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
import {getApp} from '@react-native-firebase/app';
import {
  FirebaseAuthTypes,
  sendEmailVerification,
  getAuth,
  onAuthStateChanged,
  signInAnonymously,
  signInWithEmailAndPassword,
  sendPasswordResetEmail,
  signOut,
  signInWithCredential,
  createUserWithEmailAndPassword,
  connectAuthEmulator,
} from '@react-native-firebase/auth';
import {
  getCrashlytics,
  setCrashlyticsCollectionEnabled,
} from '@react-native-firebase/crashlytics';

const auth = getAuth();

connectAuthEmulator(auth, 'http://localhost:9099');

onAuthStateChanged(auth, (user: FirebaseAuthTypes.User) => {
  console.log('onAuthStateChanged was called with user ' + user);
});

// for example:
// await signInWithEmailAndPassword(getAuth(), "foo", "bar");

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

function App(): JSX.Element {
  const isDarkMode = useColorScheme() === 'dark';
  const [crashlyticsEnabled, setCrashlyticsEnabled] = useState(
    getCrashlytics().isCrashlyticsCollectionEnabled,
  );

  const toggleCrashlytics = async () => {
    const enabled = crashlyticsEnabled;
    setCrashlyticsCollectionEnabled(getCrashlytics(), !enabled);
    setCrashlyticsEnabled(getCrashlytics().isCrashlyticsCollectionEnabled);
  };

  const backgroundStyle = {
    backgroundColor: isDarkMode ? Colors.darker : Colors.lighter,
  };

  const dynStyles = StyleSheet.create({
    colors: {
      color: isDarkMode ? Colors.white : Colors.black,
    },
  });

  return (
    <SafeAreaView style={backgroundStyle}>
      <StatusBar
        barStyle={isDarkMode ? 'light-content' : 'dark-content'}
        backgroundColor={backgroundStyle.backgroundColor}
      />
      <ScrollView
        contentInsetAdjustmentBehavior="automatic"
        style={backgroundStyle}>
        <Button
          title="sign in"
          onPress={async () => {
            console.log('anonymous sign in ');
            await signInAnonymously(auth);
          }}
        />
        <Button
          title="sign out"
          onPress={async () => {
            console.log('signing out');
            await signOut(auth);
          }}
        />
        <Button
          title="toggle crashlytics"
          onPress={async () => {
            console.log('toggling crashlytics');
            await toggleCrashlytics();
          }}
        />

        <View
          style={{
            backgroundColor: isDarkMode ? Colors.black : Colors.white,
            alignItems: 'center',
          }}>
          <Section title="RNFirebase Build Demo" />
          <Text />
          <Text style={dynStyles.colors}>
            JSI Executor: {global.__jsiExecutorDescription}
          </Text>
          <Text />
          <Text style={dynStyles.colors}>
            These firebase modules appear to be working:
          </Text>
          <Text />
          {getApp().name && <Text style={dynStyles.colors}>app()</Text>}
          {auth.config && <Text style={dynStyles.colors}>auth()</Text>}
          {getCrashlytics() && (
            <Text style={dynStyles.colors}>
              crashlytics() (enabled? {crashlyticsEnabled ? 'true' : 'false'})
            </Text>
          )}
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
