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
    this.registeredOutputs.push(event);
  }

  registerTx(event: RegisterTxMsg) {
    this.registeredTxs.push(event);
  }

  async script2address(scriptHex: string): Promise<string> {
    const response = await fetch('https://runkit.io/overtorment/output-script-to-address/branches/master/' + scriptHex);
    return response.text();
  }

  async checkBlockchain() {
    const confirmedBlocks: any = {};

    // iterating all subscriptions for confirmed txid
    for (const regTx of this.registeredTxs) {
      const response = await fetch('https://blockstream.info/api/tx/' + regTx.txid);
      const json = await response.json();
      if (json && json.status && json.status.confirmed && json.status.block_height) {
        // success! tx confirmed, and we need to notify LDK about it

        const responsePos = await fetch('https://blockstream.info/api/tx/' + regTx.txid + '/merkle-proof');
        const jsonPos = await responsePos.json();

        if (jsonPos && jsonPos.merkle) {
          confirmedBlocks[json.status.block_height + ''] = confirmedBlocks[json.status.block_height + ''] || {};
          const responseHex = await fetch('https://blockstream.info/api/tx/' + regTx.txid + '/hex');
          confirmedBlocks[json.status.block_height + ''][jsonPos.pos + ''] = await responseHex.text();
        }
      }
    }

    // iterating all scripts for spends
    for (const regOut of this.registeredOutputs) {
      const address = this.script2address(regOut.script_pubkey);
      const response = await fetch('https://blockstream.info/api/address/' + address + '/txs');
      const txs: any[] = await response.json();
      for (const tx of txs) {
        if (tx && tx.status && tx.status.confirmed && tx.status.block_height) {
          // got confirmed tx for that output!

          const responsePos = await fetch('https://blockstream.info/api/tx/' + tx.txid + '/merkle-proof');
          const jsonPos = await responsePos.json();

          if (jsonPos && jsonPos.merkle) {
            const responseHex = await fetch('https://blockstream.info/api/tx/' + tx.txid + '/hex');
            confirmedBlocks[tx.status.block_height + ''] = confirmedBlocks[tx.status.block_height + ''] || {};
            confirmedBlocks[tx.status.block_height + ''][jsonPos.pos + ''] = await responseHex.text();
          }
        }
      }
    }

    // now, got all data packed in `confirmedBlocks[block_number][tx_position]`
    // lets feed it to LDK:

    for (const height of Object.keys(confirmedBlocks).sort((a, b) => parseInt(a) - parseInt(b))) {
      for (const pos of Object.keys(confirmedBlocks[height]).sort((a, b) => parseInt(a) - parseInt(b))) {
        await RnLdk.transactionConfirmed(await this.getHeaderHexByHeight(parseInt(height)), parseInt(height), parseInt(pos), confirmedBlocks[height][pos]);
      }
    }

    let txidArr = [];
    try {
      const jsonString = await RnLdk.getRelevantTxids();
      txidArr = JSON.parse(jsonString);
    } catch (error) {
      console.warn(error);
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

    await this.updateBestBlock();
  }

  async openChannelStep1(pubkey: string, sat: number) {
    return RnLdk.openChannelStep1(pubkey, sat);
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
    if (!blockchainTipHeight) {
      const response = await fetch('https://blockstream.info/api/blocks/tip/height');
      blockchainTipHeight = parseInt(await response.text());
      const response2 = await fetch('https://blockstream.info/api/block-height/' + blockchainTipHeight);
      blockchainTipHashHex = await response2.text();
    }
    const serializedChannelManagerHex = (await this.getItem(RnLdkImplementation.CHANNEL_MANAGER_PREFIX)) || '';
    console.warn('starting with', { blockchainTipHeight, blockchainTipHashHex, serializedChannelManagerHex });
    return RnLdk.start(entropyHex, blockchainTipHeight, blockchainTipHashHex, serializedChannelManagerHex);
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
    if (!storage.setItem || !storage.getItem) throw new Error('Bad provided storage');
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

  broadcast(event: BroadcastMsg) {
    return fetch('https://blockstream.info/api/tx', {
      method: 'POST',
      body: event.txhex,
    });
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

eventEmitter.addListener('register_output', (event: RegisterOutputMsg) => {
  LDK.registerOutput(event);
  console.log('register_output: ' + JSON.stringify(event));
});

eventEmitter.addListener('register_tx', (event: RegisterTxMsg) => {
  LDK.registerTx(event);
  console.log('register_tx: ' + JSON.stringify(event));
});

eventEmitter.addListener('txhex', (event: BroadcastMsg) => {
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
