import LDKFramework

@objc(RnLdk)
class RnLdk: NSObject {

    @objc
    func start(_ entropyHex: String, blockchainTipHeight: Int, blockchainTipHashHex: String, serializedChannelManagerHex: String, monitorHexes: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    }
    
    
    @objc
    func getVersion(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        resolve("0.0.18")
    }
}
