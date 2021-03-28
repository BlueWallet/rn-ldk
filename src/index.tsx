import { NativeEventEmitter, NativeModules } from 'react-native';
const { RnLdk } = NativeModules;

interface RegisterOutputMsg {
  txid: string;
  index: string;
  script_pubkey: string;
}

interface RegisterTxMsg {
  txid: string;
  script_pubkey: string;
}

interface BroadcastMsg {
  txhex: string;
}

interface PersistMsg {
  id: string;
  data: string;
}

class RnLdkImplementation {
  static CHANNEL_MANAGER_PREFIX = 'channel_manager';
  static CHANNEL_PREFIX = 'channel_monitor_';

  private storage: any = false;
  private registeredOutputs: RegisterOutputMsg[] = [];
  private registeredTxs: RegisterTxMsg[] = [];

  registerOutput(event: RegisterOutputMsg) {
    event.txid = this.reverseTxid(event.txid); // achtunhg, little-endian
    console.log('registerOutput', event);
    this.registeredOutputs.push(event);
  }

  registerTx(event: RegisterTxMsg) {
    event.txid = this.reverseTxid(event.txid); // achtunhg, little-endian
    console.log('registerTx', event);
    this.registeredTxs.push(event);
  }

  reverseTxid(hex: string): string {
    if (hex.length % 2 !== 0) throw new Error('incorrect hex ' + hex);
    const matched = hex.match(/[a-fA-F0-9]{2}/g);
    if (matched) {
      return matched.reverse().join('');
    }
    return '';
  }

  async script2address(scriptHex: string): Promise<string> {
    const response = await fetch('https://runkit.io/overtorment/output-script-to-address/branches/master/' + scriptHex);
    return response.text();
  }

  async checkBlockchain() {
    console.warn('1');
    await this.updateBestBlock();
    console.warn('2');

    const confirmedBlocks: any = {};

    // iterating all subscriptions for confirmed txid
    for (const regTx of this.registeredTxs) {
      let json;
      try {
        console.warn('3');
        const response = await fetch('https://blockstream.info/api/tx/' + regTx.txid);
        json = await response.json();
      } catch (_) {}
      console.warn('4');
      if (json && json.status && json.status.confirmed && json.status.block_height) {
        // success! tx confirmed, and we need to notify LDK about it

        let jsonPos;
        try {
          console.warn('5');
          const responsePos = await fetch('https://blockstream.info/api/tx/' + regTx.txid + '/merkle-proof');
          jsonPos = await responsePos.json();
        } catch (_) {}
        console.warn('6');

        if (jsonPos && jsonPos.merkle) {
          confirmedBlocks[json.status.block_height + ''] = confirmedBlocks[json.status.block_height + ''] || {};
          const responseHex = await fetch('https://blockstream.info/api/tx/' + regTx.txid + '/hex');
          confirmedBlocks[json.status.block_height + ''][jsonPos.pos + ''] = await responseHex.text();
          console.warn('7');
        }
      }
    }

    // iterating all scripts for spends
    for (const regOut of this.registeredOutputs) {
      let txs: any[] = [];
      try {
        console.warn('8');
        const address = await this.script2address(regOut.script_pubkey);
        const response = await fetch('https://blockstream.info/api/address/' + address + '/txs');
        txs = await response.json();
      } catch (_) {}
      console.warn('9');
      for (const tx of txs) {
        if (tx && tx.status && tx.status.confirmed && tx.status.block_height) {
          // got confirmed tx for that output!

          let jsonPos;
          try {
            console.warn('10');
            const responsePos = await fetch('https://blockstream.info/api/tx/' + tx.txid + '/merkle-proof');
            jsonPos = await responsePos.json();
          } catch (_) {}
          console.warn('11');

          if (jsonPos && jsonPos.merkle) {
            const responseHex = await fetch('https://blockstream.info/api/tx/' + tx.txid + '/hex');
            confirmedBlocks[tx.status.block_height + ''] = confirmedBlocks[tx.status.block_height + ''] || {};
            confirmedBlocks[tx.status.block_height + ''][jsonPos.pos + ''] = await responseHex.text();
            console.warn('12');
          }
        }
      }
    }

    // now, got all data packed in `confirmedBlocks[block_number][tx_position]`
    // lets feed it to LDK:

    console.log('confirmedBlocks=', confirmedBlocks);

    for (const height of Object.keys(confirmedBlocks).sort((a, b) => parseInt(a) - parseInt(b))) {
      for (const pos of Object.keys(confirmedBlocks[height]).sort((a, b) => parseInt(a) - parseInt(b))) {
        console.warn('13');
        await RnLdk.transactionConfirmed(await this.getHeaderHexByHeight(parseInt(height)), parseInt(height), parseInt(pos), confirmedBlocks[height][pos]);
        console.warn('14');
      }
    }

    let txidArr = [];
    try {
      console.warn('15');
      const jsonString = await RnLdk.getRelevantTxids();
      console.warn('getRelevantTxids: jsonString=', jsonString);
      txidArr = JSON.parse(jsonString);
    } catch (error) {
      console.warn('getRelevantTxids:', error);
    }

    // we need to check if any of txidArr got unconfirmed, and then feed it back to LDK if they are unconf
    for (const txid of txidArr) {
      let confirmed = false;
      try {
        const response = await fetch('https://blockstream.info/api/tx/' + txid + '/merkle-proof');
        const tx: any = await response.json();
        if (tx && tx.block_height) confirmed = true;
      } catch (_) {
        confirmed = false;
      }

      if (!confirmed) await RnLdk.transactionUnconfirmed(txid);
    }

    return true;
  }

  async openChannelStep1(pubkey: string, sat: number) {
    const script = await RnLdk.openChannelStep1(pubkey, sat);
    if (script) {
      const response = await fetch('https://runkit.io/overtorment/output-script-to-address/branches/master/' + script);
      return response.text();
    }

    return false;
  }

  async openChannelStep2(txhex: string) {
    console.warn('submitting to ldk', { txhex });
    return RnLdk.openChannelStep2(txhex);
  }

  async listUsableChannels() {
    const str = await RnLdk.listUsableChannels();
    console.log(str);
    return JSON.parse(str);
  }

  async getHeaderHexByHeight(height: number) {
    const response2 = await fetch('https://blockstream.info/api/block-height/' + height);
    const hash = await response2.text();
    const response3 = await fetch('https://blockstream.info/api/block/' + hash + '/header');
    return response3.text();
  }

  async updateBestBlock() {
    const response = await fetch('https://blockstream.info/api/blocks/tip/height');
    const height = parseInt(await response.text());
    const response2 = await fetch('https://blockstream.info/api/block-height/' + height);
    const hash = await response2.text();
    const response3 = await fetch('https://blockstream.info/api/block/' + hash + '/header');
    const headerHex = await response3.text();
    return RnLdk.updateBestBlock(headerHex, height);
  }

  multiply(a: number, b: number): Promise<number> {
    return RnLdk.multiply(a, b);
  }

  async start(entropyHex: string, blockchainTipHeight?: number, blockchainTipHashHex?: string): Promise<boolean> {
    const keys4monitors = (await this.getAllKeys()).filter((key: string) => key.startsWith(RnLdkImplementation.CHANNEL_PREFIX));
    const monitorHexes = [];
    console.warn('keys4monitors=', keys4monitors);
    for (const key of keys4monitors) {
      const hex = await this.getItem(key);
      if (hex) monitorHexes.push(hex);
    }

    if (!blockchainTipHeight) {
      const response = await fetch('https://blockstream.info/api/blocks/tip/height');
      blockchainTipHeight = parseInt(await response.text());
      const response2 = await fetch('https://blockstream.info/api/block-height/' + blockchainTipHeight);
      blockchainTipHashHex = await response2.text();
    }
    const serializedChannelManagerHex = (await this.getItem(RnLdkImplementation.CHANNEL_MANAGER_PREFIX)) || '';
    console.warn('starting with', { blockchainTipHeight, blockchainTipHashHex, serializedChannelManagerHex });
    return RnLdk.start(entropyHex, blockchainTipHeight, blockchainTipHashHex, serializedChannelManagerHex, monitorHexes.join(','));
  }

  connectPeer(pubkeyHex: string, hostname: string, port: number): Promise<boolean> {
    return RnLdk.connectPeer(pubkeyHex, hostname, port);
  }

  listPeers(): Promise<string> {
    return RnLdk.listPeers();
  }

  fireAnEvent(): Promise<boolean> {
    return RnLdk.fireAnEvent();
  }

  setStorage(storage: any) {
    if (!storage.setItem || !storage.getItem || !storage.getAllKeys) throw new Error('Bad provided storage');
    this.storage = storage;
  }

  async storeChannelManager() {
    const hex = await RnLdk.getChannelManagerBytes();
    console.warn({ hex });
    if (hex && this.storage) {
      await this.setItem(RnLdkImplementation.CHANNEL_MANAGER_PREFIX, hex);
    }
  }

  persist(event: PersistMsg) {
    return this.setItem(RnLdkImplementation.CHANNEL_PREFIX + event.id, event.data);
  }

  async setItem(key: string, value: string) {
    if (!this.storage) throw new Error('No storage');
    console.log('::::::::::::::::: saving to disk', key, '=', value);
    return this.storage.setItem(key, value);
  }

  async getItem(key: string) {
    if (!this.storage) throw new Error('No storage');
    console.log('::::::::::::::::: reading from disk', key);
    const ret = await this.storage.getItem(key);
    console.log('::::::::::::::::: --------------->>', JSON.stringify(ret));
    return ret;
  }

  async getAllKeys() {
    if (!this.storage) throw new Error('No storage');
    return this.storage.getAllKeys();
  }

  broadcast(event: BroadcastMsg) {
    return fetch('https://blockstream.info/api/tx', {
      method: 'POST',
      body: event.txhex,
    });
  }
}

const LDK = new RnLdkImplementation();

const eventEmitter = new NativeEventEmitter();

eventEmitter.addListener('log', (event) => {
  console.log('log: ' + JSON.stringify(event));
});

eventEmitter.addListener('register_output', (event: RegisterOutputMsg) => {
  LDK.registerOutput(event);
});

eventEmitter.addListener('register_tx', (event: RegisterTxMsg) => {
  LDK.registerTx(event);
});

eventEmitter.addListener('broadcast', (event: BroadcastMsg) => {
  console.warn('broadcast: ' + event.txhex);
  LDK.broadcast(event);
});

eventEmitter.addListener('persist', (event: PersistMsg) => {
  console.warn('save:' + JSON.stringify(event));
  if (!event.id || !event.data) throw new Error('Unexpected data passed for persister: ' + JSON.stringify(event));
  // LDK.setItem(event.id, event.data);
  LDK.persist(event);
});

export default LDK as RnLdkImplementation;
