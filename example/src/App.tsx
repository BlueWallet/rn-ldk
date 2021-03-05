import * as React from 'react';

import { StyleSheet, View, Text, Button } from 'react-native';
import RnLdk from 'rn-ldk';

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
          RnLdk.start('ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff', 666777).then(console.warn);
        }}
        title="Start"
        color="#841584"
      />

      <Button
        onPress={() => {
          RnLdk.connectPeer('02e89ca9e8da72b33d896bae51d20e7e6675aa971f7557500b6591b15429e717f1', '165.227.95.104', 9735).then(console.warn);
        }}
        title="connect peer"
        color="#841584"
      />

      <Button
        onPress={() => {
          RnLdk.subscribeCallback(() => {
            console.warn('yo im in callback!');
          });
        }}
        title="subscribeCallback"
        color="#841584"
      />

      <Button
        onPress={() => {
          RnLdk.fireAnEvent().then(console.warn);
        }}
        title="fireAnEvent"
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
