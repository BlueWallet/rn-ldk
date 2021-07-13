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
as rn-ldk is shipped with api-based fallback)

## Installation

```sh
npm install "https://github.com/BlueWallet/rn-ldk" --save
```

## Usage

```js
import RnLdk from "rn-ldk";
// ...
```

## License

MIT
