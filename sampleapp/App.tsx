/* eslint-disable react-native/no-inline-styles */

import React, { useEffect } from "react";
import {
  Alert,
  Button,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  View,
} from 'react-native';

import { SafeAreaView, SafeAreaProvider } from 'react-native-safe-area-context';
import { configureFaceTec, getFaceTecInstance } from 'facetec-sdk-module';

type Props = {};

const isDarkMode = false;

const backgroundStyle = {
  backgroundColor: isDarkMode ? '#000000' : '#FFFFFF',
};

configureFaceTec({
  deviceKeyIdentifier: process.env.EXPO_PUBLIC_FACETEC_DEVICE_KEY_IDENTIFIER!,
  serverBaseUrl: process.env.EXPO_PUBLIC_FACETEC_SERVER_BASE_URL!,
  allowCancelledForDev: true,
});

export default function App() {

  useEffect(() => {
    getFaceTecInstance().initialize().catch(err => {
      console.error("Failed to initialize face scanner SDK:", err);
      Alert.alert("FaceTecScanner", "Failed to initialize face scanner SDK: " + err.message);
    });
  }, []);

  return (
    <SafeAreaProvider>
      <SafeAreaView style={backgroundStyle}>
        <StatusBar barStyle={isDarkMode ? 'light-content' : 'dark-content'} />
        <ScrollView
          contentInsetAdjustmentBehavior="automatic"
          style={backgroundStyle}>
          <View>
            <Text style={styles.header}>FaceTec EXPO56 Sample App</Text>
            <Button
              title="Start Liveness Check"
              onPress={() => {
                getFaceTecInstance().startLivenessCheck();
              }}
            />  
          </View>
        </ScrollView>
      </SafeAreaView>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  header: {
    backgroundColor: '#417FB2',
    fontSize: 25,
    padding: 10,
    marginTop: 15,
    color: 'white',
  },
});
