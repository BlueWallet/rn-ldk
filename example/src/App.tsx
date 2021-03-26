import * as React from 'react';
import { StyleSheet, View, Text, Button } from 'react-native';
import RnLdk from 'rn-ldk';
import AsyncStorage from '@react-native-async-storage/async-storage';

export default function App() {
  const [result, setResult] = React.useState<number | undefined>();

  React.useEffect(() => {
    RnLdk.multiply(3, 7).then(setResult);
  }, []);

  return (
    <View style={styles.container}>
      <Text>Result: {result}</Text>

      <Button
        onPress={() => {
          console.warn('starting...');
          RnLdk.setStorage(AsyncStorage);
          RnLdk.start('ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff').then(console.warn);
        }}
        title="Start"
        color="#841584"
      />

      <Button
        onPress={() => {
          // RnLdk.connectPeer('02e89ca9e8da72b33d896bae51d20e7e6675aa971f7557500b6591b15429e717f1', '165.227.95.104', 9735).then(console.warn);
          RnLdk.connectPeer('02e89ca9e8da72b33d896bae51d20e7e6675aa971f7557500b6591b15429e717f1', '165.227.95.104', 9735).then(console.warn);
        }}
        title="connect peer"
        color="#841584"
      />

      <Button
        onPress={() => {
          RnLdk.listPeers().then(console.warn);
        }}
        title="listPeers"
        color="#841584"
      />

      <Button
        onPress={() => {
          RnLdk.storeChannelManager();
        }}
        title="storeChannelManager (do this periodically)"
        color="#841584"
      />

      <Button
        onPress={() => {
          RnLdk.checkBlockchain();
        }}
        title="checkBlockchain (do this periodically)"
        color="#841584"
      />

      <Button
        onPress={() => {
          RnLdk.updateBestBlock();
        }}
        title="debug: updateBestBlock"
        color="#841584"
      />

      <Button
        onPress={() => {
          RnLdk.fireAnEvent().then(console.warn);
        }}
        title="fireAnEvent"
        color="#841584"
      />

      <Button
        onPress={() => {
          RnLdk.openChannelStep1('02e89ca9e8da72b33d896bae51d20e7e6675aa971f7557500b6591b15429e717f1', 100000).then(console.warn);
        }}
        title="openChannelStep1"
        color="#841584"
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  box: {
    width: 60,
    height: 60,
    marginVertical: 20,
  },
});
