import LDKFramework

@objc(RnLdk)
class RnLdk: NSObject {

    @objc
    func start(entropyHex: String, blockchainTipHeight: Int, blockchainTipHashHex: String, serializedChannelManagerHex: String, monitorHexes: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    }
}
