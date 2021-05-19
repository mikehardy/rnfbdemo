/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 * @flow
 */

import React, { Component } from 'react';
import { Platform, StyleSheet, Text, View } from 'react-native';
import firebase from '@react-native-firebase/app';
import analytics from '@react-native-firebase/analytics';
import auth from '@react-native-firebase/auth';
import crashlytics from '@react-native-firebase/crashlytics';
import database from '@react-native-firebase/database';
import dynamic_links from '@react-native-firebase/dynamic-links';
import firestore from '@react-native-firebase/firestore';
import functions from '@react-native-firebase/functions';
import in_app_messaging from '@react-native-firebase/in-app-messaging';
import messaging from '@react-native-firebase/messaging';
import perf from '@react-native-firebase/perf';
import remote_config from '@react-native-firebase/remote-config';
import storage from '@react-native-firebase/storage';

const instructions = Platform.select({
  ios: 'Press Cmd+R to reload,\n' + 'Cmd+D or shake for dev menu',
  android:
    'Double tap R on your keyboard to reload,\n' +
    'Shake or press menu button for dev menu',
});

export default class App extends Component {
  render() {
    return (
      <View style={styles.container}>
        <Text style={styles.welcome}>React Native Firebase V6 Demo</Text>
        <Text style={styles.instructions}>To get started, edit App.js</Text>
        <Text style={styles.instructions}>{instructions}</Text>
        <Text>The following modules are installed natively and working:</Text>
        {firebase.apps.length && <Text style={styles.module}>app()</Text>}
        {analytics().native && <Text style={styles.module}>analytics()</Text>}
        {auth().native && <Text style={styles.module}>auth()</Text>}
        {crashlytics().native && <Text style={styles.module}>crashlytics()</Text>}
        {database().native && <Text style={styles.module}>database()</Text>}
        {dynamic_links().native && <Text style={styles.module}>dynamic-links()</Text>}
        {firestore().native && <Text style={styles.module}>firestore()</Text>}
        {functions().native && <Text style={styles.module}>functions()</Text>}
        {in_app_messaging().native && <Text style={styles.module}>in-app-messaging()</Text>}
        {messaging().native && <Text style={styles.module}>messaging()</Text>}
        {perf().native && <Text style={styles.module}>perf()</Text>}
        {remote_config().native && <Text style={styles.module}>remote-config()</Text>}
        {storage().native && <Text style={styles.module}>storage()</Text>}
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
