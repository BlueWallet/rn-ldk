import { NativeEventEmitter, NativeModules } from 'react-native';
const { RnLdk } = NativeModules;

class RnLdkImplementation {
  private storage: any = false;

  multiply(a: number, b: number): Promise<number> {
    return RnLdk.multiply(a, b);
  }

  async start(entropyHex: string, blockHeight?: number): Promise<boolean> {
    if (!blockHeight) {
      const response = await fetch("https://blockstream.info/api/blocks/tip/height");
      blockHeight = parseInt(await response.text());
      console.warn(blockHeight)
    }
    return RnLdk.start(entropyHex, blockHeight);
  }

  connectPeer(
    pubkeyHex: string,
    hostname: string,
    port: number
  ): Promise<boolean> {
    return RnLdk.connectPeer(pubkeyHex, hostname, port);
  }

  listPeers(): Promise<string> {
    return RnLdk.listPeers();
  }

  subscribeCallback(cb: Function): void {
    return RnLdk.subscribeCallback(cb);
  }

  fireAnEvent(): Promise<boolean> {
    return RnLdk.fireAnEvent();
  }

  setStorage(storage: any) {
    if (!storage.setItem || !storage.getItem)
      throw new Error('Bad provide storage');
    this.storage = storage;
  }

  setItem(key: string, value: string) {
    if (!this.storage) throw new Error('Bad provide storage');
    return this.storage.setItem(key, value);
  }

  getItem(key: string) {
    if (!this.storage) throw new Error('Bad provide storage');
    return this.storage.getItem(key);
  }
}

const LDK = new RnLdkImplementation();

const eventEmitter = new NativeEventEmitter();
eventEmitter.addListener('EventReminder', (event) => {
  console.warn(JSON.stringify(event));
});

eventEmitter.addListener('log', (event) => {
  console.log('log: ' + JSON.stringify(event));
});

eventEmitter.addListener('txhex', (event) => {
  console.warn('broadcast: ' + event.txhex);
  // TODO: post to https://blockstream.info/api/tx
});

eventEmitter.addListener('persist', (event) => {
  console.warn('save:' + JSON.stringify(event));
  if (!event.id || !event.data)
    throw new Error(
      'Unexpected data passed for persister: ' + JSON.stringify(event)
    );
  LDK.setItem(event.id, event.data);
});

export default LDK as RnLdkImplementation;
