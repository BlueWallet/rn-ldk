# rn-ldk

Lightweight lightning node for React Native

### Introducing brand-new Lightning implementation running on mobile, both iOS and Android!

Powered by **Lightning Dev Kit**, a flexible lightning implementation written in Rust.

Some of the features include:

* Fund your channels straight from your hardware wallet, or wallets (in case of multisig)
* Encrypted channel backups are stored in cloud. Mnemonic backup phrase is all you need to restore your lightning wallet and all channels on another device and start using it in seconds! Use same channels on several devices, if you wish
* Synced to blockchain via Electrum, sync takes seconds, even on low-bandwidth connections
* Routing is provided via API, no graph sync (optional)
* Create a channel with any node on the Lightning network, no limitations (to keep the netwok decentralized)

### Technicalities

Binaries come from:

* android https://github.com/lightningdevkit/ldk-garbagecollected
* ios https://github.com/lightningdevkit/ldk-swift

A thin wrapper layer is implemented in Kotlin & Swift to provide convenient better-abstracted methods to Javascript.
Javascript part itself has *zero dependencies*, as a drawback some functions have to be provided externally (optional,
as rn-ldk is shipped with API-based fallback)

Data is stored on the side of RN, for this purpose we provide AsyncStorage to RnLdk, but anything conforming
to AsyncStorage interface will work.

Mainnet only.

Example React Native project is bundled with this repo (as a playground for testing).

## Installation

```sh
npm install "https://github.com/BlueWallet/rn-ldk" --save
```

## Usage

```js
import RnLdk from "rn-ldk";
import AsyncStorage from '@react-native-async-storage/async-storage';

// start the node!
const entropy = 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'; // change that
RnLdk.setStorage(AsyncStorage);
RnLdk.setRefundAddressScript('76a91419129d53e6319baf19dba059bead166df90ab8f588ac'); // 13HaCAB4jf7FYSZexJxoczyDDnutzZigjS
RnLdk.start(entropy).then(console.warn);

// lets create a channel

// connect to a peer first:
RnLdk.connectPeer('02e89ca9e8da72b33d896bae51d20e7e6675aa971f7557500b6591b15429e717f1', '165.227.95.104', 9735).then(console.warn); // lnd1.bluewallet.io
// initiate channel opening:
const address = await RnLdk.openChannelStep1('02e89ca9e8da72b33d896bae51d20e7e6675aa971f7557500b6591b15429e717f1', 100000);
// create a PSBT funding this address
// ...
// provide txhex to finalizing method:
RnLdk.openChannelStep2(text).then(console.warn);

// if all goes well, txhex is broadcasted and after tx gets enough confirmations channel will be usable!

// make sure your peer is connected:
RnLdk.listPeers().then(console.warn);
// observe your channel:
RnLdk.listUsableChannels().then(console.warn);

// pay some invoice:
const resultPayment = await RnLdk.sendPayment(text);

// you're awesome!
```

## License

MIT
