/* eslint-disable no-alert */
import * as React from 'react';
import { TextInput, Alert, StyleSheet, Text, Button, ScrollView } from 'react-native';
import RnLdk from 'rn-ldk';
import AsyncStorage from '@react-native-async-storage/async-storage';
import SyncedAsyncStorage from './synced-async-storage';

const RNFS = require('react-native-fs');

export default function App() {
  const [result, setResult] = React.useState<number | undefined>();
  const [text, onChangeText] = React.useState<string>('');

  React.useEffect(() => {
    RnLdk.getVersion().then(setResult);
  }, []);

  return (
    <ScrollView automaticallyAdjustContentInsets contentInsetAdjustmentBehavior={'automatic'} contentContainerStyle={styles.container}>
      <Text>
        ver {result} (package {RnLdk.getPackageVersion()})
      </Text>

      <Button
        onPress={async () => {
          console.warn('starting...');
          const entropy = '8b626e47cf7f878f86f782354234623462346234623462343246b2eb118712e8';

          const syncedStorage = new SyncedAsyncStorage(entropy);
          await syncedStorage.selftest();
          await RnLdk.selftest();
          console.warn('selftest passed');
          await syncedStorage.synchronize();

          RnLdk.setStorage(syncedStorage);
          RnLdk.setRefundAddressScript('76a91419129d53e6319baf19dba059bead166df90ab8f588ac'); // 13HaCAB4jf7FYSZexJxoczyDDnutzZigjS
          await RnLdk.start(entropy, RNFS.DocumentDirectoryPath).then(console.warn);
        }}
        title="Start"
        color="#841584"
      />

      <Button
        onPress={async () => {
          console.warn('stopping...');
          await RnLdk.stop();
        }}
        title="Stop"
        color="#841584"
      />

      <Button
        onPress={() => {
          // RnLdk.connectPeer('02e89ca9e8da72b33d896bae51d20e7e6675aa971f7557500b6591b15429e717f1', '165.227.95.104', 9735).then(console.warn); // lnd1
          RnLdk.connectPeer('03abf6f44c355dec0d5aa155bdbdd6e0c8fefe318eff402de65c6eb2e1be55dc3e', '18.221.23.28', 9735).then(console.warn); // opennode
          RnLdk.connectPeer('030c3f19d742ca294a55c00376b3b355c3c90d61c6b6b39554dbc7ac19b141c14f', '52.50.244.44', 9735).then(console.warn); // bitrefill
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
          const address = await RnLdk.openChannelStep1('02e89ca9e8da72b33d896bae51d20e7e6675aa971f7557500b6591b15429e717f1', 100000); // lnd1
          console.log(address + '');
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

      <Button
        onPress={() => {
          RnLdk.getMaturingBalance().then((maturingBalance) => {
            console.warn({ maturingBalance });
          });
          RnLdk.getMaturingHeight().then((maturingHeight) => {
            console.warn({ maturingHeight });
          });
        }}
        title="get Maturing Balance/Height"
        color="#841584"
      />

      <Button
        onPress={async () => {
          await RnLdk.closeChannelCooperatively(text);
        }}
        title="closeChannelCooperatively"
        color="#841584"
      />

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

      <Button
        onPress={async () => {
          const bolt11 = await RnLdk.addInvoice(2000, 'Hello LDK');
          console.warn(bolt11);
        }}
        title="add invoice"
        color="#841584"
      />

      <Button
        onPress={async () => {
          try {
            const entropy = 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
            const syncedStorage = new SyncedAsyncStorage(entropy);
            await syncedStorage.selftest();
            // that should also work when RnLdk is started: `await RnLdk.getStorage().selftest();`

            await RnLdk.selftest();
            // @ts-ignore
            alert('ok');
          } catch (error) {
            // @ts-ignore
            alert(error.message);
          }
        }}
        title="self test"
        color="#841584"
      />

      <Button
        onPress={async () => {
          await AsyncStorage.clear();
          Alert.alert('purged');
        }}
        title="PURGE async storage"
        color="#841584"
      />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  box: {
    width: 60,
    height: 60,
    marginVertical: 20,
  },
});
