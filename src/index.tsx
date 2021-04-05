import { NativeEventEmitter, NativeModules } from 'react-native';
import utils from './util';
const { RnLdk: RnLdkNative } = NativeModules;

const MARKER_LOG = 'log';

const MARKER_REGISTER_OUTPUT = 'marker_register_output';
interface RegisterOutputMsg {
  block_hash: string;
  index: string;
  script_pubkey: string;
}

const MARKER_REGISTER_TX = 'register_tx';
interface RegisterTxMsg {
  txid: string;
  script_pubkey: string;
}

const MARKER_BROADCAST = 'broadcast';
interface BroadcastMsg {
  txhex: string;
}

const MARKER_PERSIST = 'persist';
interface PersistMsg {
  id: string;
  data: string;
}

const MARKER_PAYMENT_SENT = 'payment_sent';
interface PaymentSentMsg {
  payment_preimage: string;
}

const MARKER_PAYMENT_FAILED = 'payment_failed';
interface PaymentFailedMsg {
  rejected_by_dest: boolean;
  payment_hash: string;
}

const MARKER_PAYMENT_RECEIVED = 'payment_received';
interface PaymentReceivedMsg {
  payment_hash: string;
  payment_secret: string;
  amt: string;
}

const MARKER_PERSIST_MANAGER = 'persist_manager';
interface PersistManagerMsg {
  channel_manager_bytes: string;
}

const MARKER_FUNDING_GENERATION_READY = 'funding_generation_ready';
interface FundingGenerationReadyMsg {
  channel_value_satoshis: string;
  output_script: string;
  temporary_channel_id: string;
  user_channel_id: string;
}

class RnLdkImplementation {
  static CHANNEL_MANAGER_PREFIX = 'channel_manager';
  static CHANNEL_PREFIX = 'channel_monitor_';

  private storage: any = false;
  private registeredOutputs: RegisterOutputMsg[] = [];
  private registeredTxs: RegisterTxMsg[] = [];
  private fundingsReady: FundingGenerationReadyMsg[] = [];

  private started = false;

  /**
   * Called by native code when LDK successfully sent payment.
   * Should not be called directly.
   *
   * @param event
   */
  _paymentSent(event: PaymentSentMsg) {
    // TODO: figure out what to do with it
    console.log('payment sent:', event);
  }

  /**
   * Called by native code when LDK received payment
   * Should not be called directly.
   *
   * @param event
   */
  _paymentReceived(event: PaymentReceivedMsg) {
    // TODO: figure out what to do with it
    console.log('payment received:', event);
  }

  /**
   * Called by native code when LDK failed to send payment.
   * Should not be called directly.
   *
   * @param event
   */
  _paymentFailed(event: PaymentFailedMsg) {
    // TODO: figure out what to do with it
    console.log('payment failed:', event);
  }

  /**
   * Called when native code sends us an output we should keep an eye on
   * and notify native code if there is some movement there.
   * Should not be called directly.
   *
   * @param event
   */
  _registerOutput(event: RegisterOutputMsg) {
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

  _fundingGenerationReady(event: FundingGenerationReadyMsg) {
    console.log('funding ready:', event);
    this.fundingsReady.push(event);
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

  _persistManager(event: PersistManagerMsg) {
    return this.setItem(RnLdkImplementation.CHANNEL_MANAGER_PREFIX, event.channel_manager_bytes);
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

    for (const height of Object.keys(confirmedBlocks).sort((a, b) => parseInt(a, 10) - parseInt(b, 10))) {
      for (const pos of Object.keys(confirmedBlocks[height]).sort((a, b) => parseInt(a, 10) - parseInt(b, 10))) {
        await RnLdkNative.transactionConfirmed(await this.getHeaderHexByHeight(parseInt(height, 10)), parseInt(height, 10), parseInt(pos, 10), confirmedBlocks[height][pos]);
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
    this.fundingsReady = []; // reset it
    const result = await RnLdkNative.openChannelStep1(pubkey, sat);
    if (!result) return false;
    let timer = 30;
    while (timer-- > 0) {
      await new Promise((resolve) => setTimeout(resolve, 500)); // sleep
      if (this.fundingsReady.length > 0) {
        const funding = this.fundingsReady.pop();
        if (funding) {
          const response = await fetch('https://runkit.io/overtorment/output-script-to-address/branches/master/' + funding.output_script);
          return response.text();
        }
        break;
      }
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
   * @returns node pubkey
   */
  async getNodeId(): Promise<string> {
    if (!this.started) throw new Error('LDK not yet started');
    return RnLdkNative.getNodeId();
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

  /**
   * @returns Array<{}>
   */
  async listChannels() {
    if (!this.started) throw new Error('LDK not yet started');
    const str = await RnLdkNative.listChannels();
    return JSON.parse(str);
  }

  private async getHeaderHexByHeight(height: number) {
    const response2 = await fetch('https://blockstream.info/api/block-height/' + height);
    const hash = await response2.text();
    const response3 = await fetch('https://blockstream.info/api/block/' + hash + '/header');
    return response3.text();
  }

  private async getCurrentHeight() {
    const response = await fetch('https://blockstream.info/api/blocks/tip/height');
    return parseInt(await response.text(), 10);
  }

  private async updateBestBlock() {
    const height = await this.getCurrentHeight();
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
    const blockchainTipHeight = parseInt(await response.text(), 10);
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
   * Prodives LKD current feerate to use with all onchain transactions.
   *
   * @param satByte
   */
  setFeerate(satByte: number): Promise<boolean> {
    return RnLdkNative.setFeerate(satByte * 250);
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

  async sendPayment(bolt11: string, numSatoshis: number = 666): Promise<boolean> {
    if (!this.started) throw new Error('LDK not yet started');
    const usableChannels = await this.listUsableChannels();
    // const usableChannels = await this.listChannels(); // FIXME debug only
    if (usableChannels.length === 0) throw new Error('No usable channels');

    const response = await fetch('https://lambda-decode-bolt11.herokuapp.com/decode/' + bolt11);
    const decoded = await response.json();
    if (isNaN(parseInt(decoded.millisatoshis, 10))) {
      decoded.millisatoshis = numSatoshis;
    }
    let payment_hash = '';
    let min_final_cltv_expiry = 144;
    let payment_secret = '';
    let shortChannelId = '';
    let weAreGonaRouteThrough = '';

    for (const tag of decoded.tags) {
      if (tag.tagName === 'payment_hash') payment_hash = tag.data;
      if (tag.tagName === 'min_final_cltv_expiry') min_final_cltv_expiry = parseInt(tag.data, 10);
      if (tag.tagName === 'payment_secret') payment_secret = tag.data;
    }

    if (!payment_hash) throw new Error('No payment_hash');
    if (!payment_secret) throw new Error('No payment_secret');

    for (const channel of usableChannels) {
      console.log('parseInt(decoded.millisatoshis, 10) = ', parseInt(decoded.millisatoshis, 10));
      if (parseInt(channel.outbound_capacity_msat, 10) >= parseInt(decoded.millisatoshis, 10)) {
        if (channel.remote_network_id === decoded.payeeNodeKey) {
          // we are paying to our direct neighbor
          return RnLdkNative.sendPayment(decoded.payeeNodeKey, payment_hash, payment_secret, channel.short_channel_id, parseInt(decoded.millisatoshis, 10), min_final_cltv_expiry, '');
        }

        shortChannelId = channel.short_channel_id;
        weAreGonaRouteThrough = channel.remote_network_id;
        break;
      }
    }

    if (shortChannelId === '') throw new Error('No usable channel with enough outbound capacity');

    // otherwise lets plot a route from our neighbor we are going to pay through to destination
    // using public queryroute api

    const from = weAreGonaRouteThrough;
    const to = decoded.payeeNodeKey;

    let jsonRoutes;
    let hopFees;
    let url = '';
    try {
      const amtSat = Math.round(parseInt(decoded.millisatoshis, 10) / 1000);
      url = `http://lndhub-staging.herokuapp.com/queryroutes/${from}/${to}/${amtSat}`;
      console.warn('querying route via', url);
      let responseRoute = await fetch(url);
      jsonRoutes = await responseRoute.json();
      if (jsonRoutes && jsonRoutes.routes && jsonRoutes.routes[0] && jsonRoutes.routes[0].hops) {
        for (let hop of jsonRoutes.routes[0].hops) {
          const url2 = `https://lndhub.herokuapp.com/getchaninfo/${hop.chan_id}`;
          const responseChaninfo = await (await fetch(url2)).json();
          console.log('responseChan=', responseChaninfo, { url2 });
          hopFees = responseChaninfo;
          // hop.feeschaninfo = responseChaninfo;
          /*if (hop.pub_key === responseChaninfo.node2_pub) {
            hopFees = hop.chanfees = responseChaninfo.node2_policy;
          } else {
            hopFees = hop.chanfees = responseChaninfo.node1_policy;
          }*/
          break;
          // breaking because we assume that outgoing chan for our routing node gona have the same fee policy
          // as our own channel with this routing node
        }
      } else throw new Error('Could not find route');
    } catch (_) {
      throw new Error('Could not find route');
    }

    const ldkRoute = utils.lndRoutetoLdkRoute(jsonRoutes, hopFees, shortChannelId, await this.getCurrentHeight());

    console.log('got route:', JSON.stringify(jsonRoutes, null, 2));
    console.log('got LDK route:', JSON.stringify(ldkRoute, null, 2));

    // return false;
    // TODO: pass route

    return RnLdkNative.sendPayment(decoded.payeeNodeKey, payment_hash, payment_secret, shortChannelId, parseInt(decoded.millisatoshis, 10), min_final_cltv_expiry, JSON.stringify(ldkRoute, null, 2));
  }
}

const RnLdk = new RnLdkImplementation();

const eventEmitter = new NativeEventEmitter();

eventEmitter.addListener(MARKER_LOG, (event) => {
  console.log('log: ' + JSON.stringify(event));
});

eventEmitter.addListener(MARKER_REGISTER_OUTPUT, (event: RegisterOutputMsg) => {
  RnLdk._registerOutput(event);
});

eventEmitter.addListener(MARKER_REGISTER_TX, (event: RegisterTxMsg) => {
  RnLdk._registerTx(event);
});

eventEmitter.addListener(MARKER_BROADCAST, (event: BroadcastMsg) => {
  console.warn('broadcast: ' + event.txhex);
  RnLdk._broadcast(event);
});

eventEmitter.addListener(MARKER_PERSIST, (event: PersistMsg) => {
  if (!event.id || !event.data) throw new Error('Unexpected data passed for persister: ' + JSON.stringify(event));
  RnLdk._persist(event);
});

eventEmitter.addListener(MARKER_PERSIST_MANAGER, (event: PersistManagerMsg) => {
  RnLdk._persistManager(event);
});

eventEmitter.addListener(MARKER_PAYMENT_FAILED, (event: PaymentFailedMsg) => {
  RnLdk._paymentFailed(event);
});

eventEmitter.addListener(MARKER_PAYMENT_RECEIVED, (event: PaymentReceivedMsg) => {
  RnLdk._paymentReceived(event);
});

eventEmitter.addListener(MARKER_PAYMENT_SENT, (event: PaymentSentMsg) => {
  RnLdk._paymentSent(event);
});

eventEmitter.addListener(MARKER_FUNDING_GENERATION_READY, (event: FundingGenerationReadyMsg) => {
  RnLdk._fundingGenerationReady(event);
});

export default RnLdk as RnLdkImplementation;
