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
    
    func getName() -> String {
        return "RnLdk"
    }
    
    @objc
    func getRelevantTxids(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        
    }
    
    @objc
    func transactionUnconfirmed(txidHex: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
    }
    
    @objc
    func transactionConfirmed(headerHex: String, height: Int, txPos: Int, transactionHex: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        
    }
    
    @objc
    func updateBestBlock(headerHex: String, height: Int, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
    }
    
    @objc
    func connectPeer(pubkeyHex: String, hostname: String, port: Int, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        
    }
    
    @objc
    func sendPayment(destPubkeyHex: String, paymentHashHex: String, paymentSecretHex: String, shortChannelId: String, paymentValueMsat: Int, finalCltvValue: Int, LdkRoutesJsonArrayString: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
    }
    
    @objc
    func addInvoice(amtMsat: Int, description: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        
    }
    
    @objc
    func listPeers(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        
    }
    
    private func handleEvent(event: Event) {
        
    }
    
    @objc
    func getNodeId(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        
    }
    
    @objc
    func getChannelManagerBytes(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        
    }
    @objc
    func closeChannelCooperatively(channelIdHex: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        
    }
    
    @objc
    func closeChannelForce(channelIdHex: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        
    }
    
    @objc
    func openChannelStep1(pubkey: String, channelValue: Int, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        
    }
    
    @objc
    func openChannelStep2(txhex: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        
    }
    
    @objc
    func listUsableChannels(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        
    }
    
    @objc
    func listChannels(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        
    }
    
    @objc
    func setFeerate(newFeerateFast: Int, newFeerateMedium: Int, newFeerateSlow: Int, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        
    }
    
    @objc
    func fireAnEvent(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        
    }
    
    
}
