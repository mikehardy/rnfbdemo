/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 */

import React from 'react';
import type {PropsWithChildren} from 'react';
import {
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
import auth from '@react-native-firebase/auth';
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

  return (
    <SafeAreaView style={backgroundStyle}>
      <StatusBar
        barStyle={isDarkMode ? 'light-content' : 'dark-content'}
        backgroundColor={backgroundStyle.backgroundColor}
      />
      <ScrollView
        contentInsetAdjustmentBehavior="automatic"
        style={backgroundStyle}>
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
