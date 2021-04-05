import * as React from 'react';
import { TextInput, Alert, StyleSheet, View, Text, Button } from 'react-native';
import RnLdk from 'rn-ldk';
import AsyncStorage from '@react-native-async-storage/async-storage';

export default function App() {
  const [result, setResult] = React.useState<number | undefined>();
  const [text, onChangeText] = React.useState<string>('');

  React.useEffect(() => {
    RnLdk.getVersion().then(setResult);
  }, []);

  return (
    <View style={styles.container}>
      <Text>ver {result}</Text>

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
          RnLdk.connectPeer('02e89ca9e8da72b33d896bae51d20e7e6675aa971f7557500b6591b15429e717f1', '165.227.95.104', 9735).then(console.warn); // lnd1
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
          RnLdk.checkBlockchain().then(console.warn);
        }}
        title="checkBlockchain (do this periodically)"
        color="#841584"
      />

      <Button
        onPress={() => {
          RnLdk.fireAnEvent();
        }}
        title="debug: fireAnEvent"
        color="#841584"
      />

      <Button
        onPress={async () => {
          const address = await RnLdk.openChannelStep1('02e89ca9e8da72b33d896bae51d20e7e6675aa971f7557500b6591b15429e717f1', 100000);
          onChangeText(address + '');
        }}
        title="openChannelStep1"
        color="#841584"
      />

      <TextInput editable onChangeText={onChangeText} value={text} multiline maxLength={65535} />

      <Button
        onPress={() => {
          if (!text) return;
          RnLdk.openChannelStep2(text).then(console.warn);
        }}
        title="openChannelStep2"
        color="#841584"
      />

      <Button
        onPress={() => {
          RnLdk.listUsableChannels().then(console.warn);
        }}
        title="listUsableChannels"
        color="#841584"
      />

      <Button
        onPress={() => {
          RnLdk.listChannels().then(console.warn);
        }}
        title="listChannels"
        color="#841584"
      />

      {/*<Button
        onPress={async () => {
          await AsyncStorage.clear();
        }}
        title="nuke storage"
        color="#841584"
      />*/}

      <Button
        onPress={async () => {
          if (!text) return Alert.alert('no invoice provided');
          const resultPayment = await RnLdk.sendPayment(text);
          Alert.alert(resultPayment + '');
        }}
        title="send payment"
        color="#841584"
      />

      <Button
        onPress={async () => {
          const nodeId = await RnLdk.getNodeId();
          Alert.alert(nodeId);
        }}
        title="get node id"
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
