import { NativeEventEmitter, NativeModules } from 'react-native';
const { RnLdk: RnLdkNative } = NativeModules;

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

  private started = false;

  /**
   * Called when native code sends us an output we should keep an eye on
   * and notify native code if there is some movement there.
   * Should not be called directly.
   *
   * @param event
   */
  _registerOutput(event: RegisterOutputMsg) {
    event.txid = this.reverseTxid(event.txid); // achtung, little-endian
    console.log('registerOutput', event);
    this.registeredOutputs.push(event);
  }

  /**
   * Called when native code sends us a transaction we should keep an eye on
   * and notify native code if there is some movement there.
   * Should not be called directly.
   *
   * @param event
   */
  _registerTx(event: RegisterTxMsg) {
    event.txid = this.reverseTxid(event.txid); // achtung, little-endian
    console.log('registerTx', event);
    this.registeredTxs.push(event);
  }

  /**
   * Called when native code sends us channel-specific backup data bytes we should
   * save to persistent storage.
   * Should not be called directly.
   *
   * @param event
   */
  async _persist(event: PersistMsg) {
    return this.setItem(RnLdkImplementation.CHANNEL_PREFIX + event.id, event.data);
  }

  /**
   * Called when native code wants us to broadcast some transaction.
   * Should not be called directly.
   *
   * @param event
   */
  async _broadcast(event: BroadcastMsg) {
    return fetch('https://blockstream.info/api/tx', {
      method: 'POST',
      body: event.txhex,
    });
  }

  private reverseTxid(hex: string): string {
    if (hex.length % 2 !== 0) throw new Error('incorrect hex ' + hex);
    const matched = hex.match(/[a-fA-F0-9]{2}/g);
    if (matched) {
      return matched.reverse().join('');
    }
    return '';
  }

  private async script2address(scriptHex: string): Promise<string> {
    const response = await fetch('https://runkit.io/overtorment/output-script-to-address/branches/master/' + scriptHex);
    return response.text();
  }

  /**
   * Fetches from network registered outputs, registered transactions and block tip
   * and feeds this into to native code, if necessary.
   * Should be called periodically.
   */
  async checkBlockchain() {
    if (!this.started) throw new Error('LDK not yet started');
    await this.updateBestBlock();

    const confirmedBlocks: any = {};

    // iterating all subscriptions for confirmed txid
    for (const regTx of this.registeredTxs) {
      let json;
      try {
        const response = await fetch('https://blockstream.info/api/tx/' + regTx.txid);
        json = await response.json();
      } catch (_) {}
      if (json && json.status && json.status.confirmed && json.status.block_height) {
        // success! tx confirmed, and we need to notify LDK about it

        let jsonPos;
        try {
          const responsePos = await fetch('https://blockstream.info/api/tx/' + regTx.txid + '/merkle-proof');
          jsonPos = await responsePos.json();
        } catch (_) {}

        if (jsonPos && jsonPos.merkle) {
          confirmedBlocks[json.status.block_height + ''] = confirmedBlocks[json.status.block_height + ''] || {};
          const responseHex = await fetch('https://blockstream.info/api/tx/' + regTx.txid + '/hex');
          confirmedBlocks[json.status.block_height + ''][jsonPos.pos + ''] = await responseHex.text();
        }
      }
    }

    // iterating all scripts for spends
    for (const regOut of this.registeredOutputs) {
      let txs: any[] = [];
      try {
        const address = await this.script2address(regOut.script_pubkey);
        const response = await fetch('https://blockstream.info/api/address/' + address + '/txs');
        txs = await response.json();
      } catch (_) {}
      for (const tx of txs) {
        if (tx && tx.status && tx.status.confirmed && tx.status.block_height) {
          // got confirmed tx for that output!

          let jsonPos;
          try {
            const responsePos = await fetch('https://blockstream.info/api/tx/' + tx.txid + '/merkle-proof');
            jsonPos = await responsePos.json();
          } catch (_) {}

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

    console.log('confirmedBlocks=', confirmedBlocks);

    for (const height of Object.keys(confirmedBlocks).sort((a, b) => parseInt(a) - parseInt(b))) {
      for (const pos of Object.keys(confirmedBlocks[height]).sort((a, b) => parseInt(a) - parseInt(b))) {
        await RnLdkNative.transactionConfirmed(await this.getHeaderHexByHeight(parseInt(height)), parseInt(height), parseInt(pos), confirmedBlocks[height][pos]);
      }
    }

    let txidArr = [];
    try {
      const jsonString = await RnLdkNative.getRelevantTxids();
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

      if (!confirmed) await RnLdkNative.transactionUnconfirmed(txid);
    }

    return true;
  }

  /**
   * Starts the process of opening a channel
   * @param pubkey Remote noed pubkey
   * @param sat Channel value
   *
   * @returns string|false Either address to deposit sats to or false if smth went wrong
   */
  async openChannelStep1(pubkey: string, sat: number): Promise<string | false> {
    if (!this.started) throw new Error('LDK not yet started');
    const script = await RnLdkNative.openChannelStep1(pubkey, sat);
    if (script) {
      const response = await fetch('https://runkit.io/overtorment/output-script-to-address/branches/master/' + script);
      return response.text();
    }

    return false;
  }

  /**
   * Finishes opening channel starter in `openChannelStep1()`. Once you created a transaction to address
   * generated by `openChannelStep1()` with the amount you specified, feed txhex to this method to
   * finalize opening a channel.
   *
   * @param txhex
   *
   * @returns boolean Success or not
   */
  async openChannelStep2(txhex: string) {
    if (!this.started) throw new Error('LDK not yet started');
    console.warn('submitting to ldk', { txhex });
    return RnLdkNative.openChannelStep2(txhex);
  }

  /**
   * @returns Array<{}>
   */
  async listUsableChannels() {
    if (!this.started) throw new Error('LDK not yet started');
    const str = await RnLdkNative.listUsableChannels();
    console.log(str);
    return JSON.parse(str);
  }

  private async getHeaderHexByHeight(height: number) {
    const response2 = await fetch('https://blockstream.info/api/block-height/' + height);
    const hash = await response2.text();
    const response3 = await fetch('https://blockstream.info/api/block/' + hash + '/header');
    return response3.text();
  }

  private async updateBestBlock() {
    const response = await fetch('https://blockstream.info/api/blocks/tip/height');
    const height = parseInt(await response.text());
    const response2 = await fetch('https://blockstream.info/api/block-height/' + height);
    const hash = await response2.text();
    const response3 = await fetch('https://blockstream.info/api/block/' + hash + '/header');
    const headerHex = await response3.text();
    return RnLdkNative.updateBestBlock(headerHex, height);
  }

  getVersion(): Promise<number> {
    return RnLdkNative.getVersion();
  }

  /**
   * Spins up the node. Should be called before anything else.
   * Assumes storage is provided.
   *
   * @param entropyHex 256 bit entropy, basically a private key for a node, e.g. 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
   * @param blockchainTipHeight
   * @param blockchainTipHashHex
   *
   * @returns boolean TRUE if all went well
   */
  async start(entropyHex: string): Promise<boolean> {
    if (!this.storage) throw new Error('Storage is not yet set');
    this.started = true;
    const keys4monitors = (await this.getAllKeys()).filter((key: string) => key.startsWith(RnLdkImplementation.CHANNEL_PREFIX));
    const monitorHexes = [];
    console.warn('keys4monitors=', keys4monitors);
    for (const key of keys4monitors) {
      const hex = await this.getItem(key);
      if (hex) monitorHexes.push(hex);
    }

    const response = await fetch('https://blockstream.info/api/blocks/tip/height');
    const blockchainTipHeight = parseInt(await response.text());
    const response2 = await fetch('https://blockstream.info/api/block-height/' + blockchainTipHeight);
    const blockchainTipHashHex = await response2.text();

    const serializedChannelManagerHex = (await this.getItem(RnLdkImplementation.CHANNEL_MANAGER_PREFIX)) || '';
    console.warn('starting with', { blockchainTipHeight, blockchainTipHashHex, serializedChannelManagerHex });
    return RnLdkNative.start(entropyHex, blockchainTipHeight, blockchainTipHashHex, serializedChannelManagerHex, monitorHexes.join(','));
  }

  /**
   * Connects to other lightning node
   *
   * @param pubkeyHex Other node pubkey
   * @param hostname Other node ip
   * @param port Other node port
   *
   * @return boolean success or not
   */
  connectPeer(pubkeyHex: string, hostname: string, port: number): Promise<boolean> {
    if (!this.started) throw new Error('LDK not yet started');
    return RnLdkNative.connectPeer(pubkeyHex, hostname, port);
  }

  /**
   * Returns list of other lightning nodes we are connected to
   *
   * @returns array
   */
  async listPeers(): Promise<string[]> {
    if (!this.started) throw new Error('LDK not yet started');
    const jsonString = await RnLdkNative.listPeers();
    try {
      return JSON.parse(jsonString);
    } catch (error) {
      console.warn(error);
    }

    return [];
  }

  fireAnEvent(): Promise<boolean> {
    return RnLdkNative.fireAnEvent();
  }

  /**
   * Method to set storage that will handle persistance. Should conform to the spec
   * (have methods setItem, getItem & getAllKeys)
   *
   * @param storage object
   */
  setStorage(storage: any) {
    if (!storage.setItem || !storage.getItem || !storage.getAllKeys) throw new Error('Bad provided storage');
    this.storage = storage;
  }

  /**
   * Extracts from native code bytes backup of channel manager (basically represents
   * main node backup) and saves it to provided storage.
   * Should be called periodically.
   */
  async storeChannelManager() {
    if (!this.started) throw new Error('LDK not yet started');
    const hex = await RnLdkNative.getChannelManagerBytes();
    console.warn({ hex });
    if (hex && this.storage) {
      await this.setItem(RnLdkImplementation.CHANNEL_MANAGER_PREFIX, hex);
    }
  }

  /**
   * Wrapper for provided storage
   *
   * @param key
   * @param value
   */
  async setItem(key: string, value: string) {
    if (!this.storage) throw new Error('No storage');
    console.log('::::::::::::::::: saving to disk', key, '=', value);
    return this.storage.setItem(key, value);
  }

  /**
   * Wrapper for provided storage
   *
   * @param key
   */
  async getItem(key: string) {
    if (!this.storage) throw new Error('No storage');
    console.log('::::::::::::::::: reading from disk', key);
    const ret = await this.storage.getItem(key);
    console.log('::::::::::::::::: --------------->>', JSON.stringify(ret));
    return ret;
  }

  /**
   * Wrapper for provided storage
   *
   * @returns string[]
   */
  async getAllKeys() {
    if (!this.storage) throw new Error('No storage');
    return this.storage.getAllKeys();
  }

  async sendPayment(destPubkeyHex: string, paymentHashHex: string, paymentSecretHex: string, shortChannelId: string, paymentValueMsat: number, finalCltvValue: number) {
    if (!this.started) throw new Error('LDK not yet started');
    return RnLdkNative.sendPayment(destPubkeyHex, paymentHashHex, paymentSecretHex, shortChannelId, paymentValueMsat, finalCltvValue);
  }
}

const RnLdk = new RnLdkImplementation();

const eventEmitter = new NativeEventEmitter();

eventEmitter.addListener('log', (event) => {
  console.log('log: ' + JSON.stringify(event));
});

eventEmitter.addListener('register_output', (event: RegisterOutputMsg) => {
  RnLdk._registerOutput(event);
});

eventEmitter.addListener('register_tx', (event: RegisterTxMsg) => {
  RnLdk._registerTx(event);
});

eventEmitter.addListener('broadcast', (event: BroadcastMsg) => {
  console.warn('broadcast: ' + event.txhex);
  RnLdk._broadcast(event);
});

eventEmitter.addListener('persist', (event: PersistMsg) => {
  console.warn('save:' + JSON.stringify(event));
  if (!event.id || !event.data) throw new Error('Unexpected data passed for persister: ' + JSON.stringify(event));
  RnLdk._persist(event);
});

export default RnLdk as RnLdkImplementation;
