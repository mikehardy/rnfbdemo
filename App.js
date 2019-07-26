/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 * @flow
 */

import React, {Component} from 'react';
import {Platform, StyleSheet, Text, View} from 'react-native';
import firebase from 'react-native-firebase';

firebase.admob().initialize('ca-app-pub-3940256099942544~3347511713');

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
        <Text style={styles.welcome}>React Native Firebase Demo</Text>
        <Text style={styles.instructions}>To get started, edit App.js</Text>
        <Text style={styles.instructions}>{instructions}</Text>
        <Text>The following modules are installed natively and working:</Text>
        {firebase.admob.nativeModuleExists && <Text style={styles.module}>admob()</Text>}
        {firebase.analytics.nativeModuleExists && <Text style={styles.module}>analytics()</Text>}
        {firebase.auth.nativeModuleExists && <Text style={styles.module}>auth()</Text>}
        {firebase.config.nativeModuleExists && <Text style={styles.module}>config()</Text>}
        {firebase.crashlytics.nativeModuleExists && <Text style={styles.module}>crashlytics()</Text>}
        {firebase.database.nativeModuleExists && <Text style={styles.module}>database()</Text>}
        {firebase.firestore.nativeModuleExists && <Text style={styles.module}>firestore()</Text>}
        {firebase.functions.nativeModuleExists && <Text style={styles.module}>functions()</Text>}
        {firebase.iid.nativeModuleExists && <Text style={styles.module}>iid()</Text>}
        {firebase.links.nativeModuleExists && <Text style={styles.module}>links()</Text>}
        {firebase.messaging.nativeModuleExists && <Text style={styles.module}>messaging()</Text>}
        {firebase.notifications.nativeModuleExists && <Text style={styles.module}>notifications()</Text>}
        {firebase.perf.nativeModuleExists && <Text style={styles.module}>perf()</Text>}
        {firebase.storage.nativeModuleExists && <Text style={styles.module}>storage()</Text>}
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
