import * as React from 'react';
import { TextInput, StyleSheet, View, Text, Button } from 'react-native';
import RnLdk from 'rn-ldk';
import AsyncStorage from '@react-native-async-storage/async-storage';

export default function App() {
  const [result, setResult] = React.useState<number | undefined>();
  const [text, onChangeText] = React.useState<string>('');

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
          RnLdk.checkBlockchain().then(console.warn);
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
          RnLdk.fireAnEvent();
        }}
        title="debug: fireAnEvent"
        color="#841584"
      />

      <Button
        onPress={() => {
          RnLdk.openChannelStep1('02e89ca9e8da72b33d896bae51d20e7e6675aa971f7557500b6591b15429e717f1', 100000).then(console.warn);
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

      {/*<Button
        onPress={async () => {
          // console.warn(await AsyncStorage.getAllKeys());
          // console.warn('key = ', await AsyncStorage.getItem('channel_monitor_3fddb9e8f087e390ca54e4247707377bdbdbdf2d60b084a3a2fd52ae22f6cf90'));
          // await AsyncStorage.clear();
        }}
        title="nuke storage"
        color="#841584"
      />*/}

      <Button
        onPress={async () => {
          RnLdk.sendPayment(
            '02e89ca9e8da72b33d896bae51d20e7e6675aa971f7557500b6591b15429e717f1',
            '046274286f4e75c2a78da711307de517daf835e1c4bdc16e68f585f219da2870' /*paym hash*/,
            '266cb828fbf94bd0c75beb4e8336a11a15f3f9a225524c555ec94ff57ec3cad3' /*paym secret*/,
            'chan_id',
            1000 /*paymentValueMsat*/,
            144 /*finalCltvValue*/
          ).then(console.warn);
        }}
        title="send payment"
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
