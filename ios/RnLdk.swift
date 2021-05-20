import Foundation
import LDKFramework

var feerate_fast = 7500; // estimate fee rate in BTC/kB
var feerate_medium = 7500; // estimate fee rate in BTC/kB
var feerate_slow = 7500; // estimate fee rate in BTC/kB

var channel_manager: LDKFramework.ChannelManager?;

class MyFeeEstimator: FeeEstimator {
    override func get_est_sat_per_1000_weight(confirmation_target: LDKConfirmationTarget) -> UInt32 {
        if (confirmation_target as AnyObject === LDKConfirmationTarget_HighPriority as AnyObject) {
            return UInt32(feerate_fast);
        }
        if (confirmation_target as AnyObject === LDKConfirmationTarget_Normal as AnyObject) {
            return UInt32(feerate_medium);
        }
        return UInt32(feerate_slow);
    }
}

class MyLogger: Logger {
    override func log(record: String?) {
        if let record = record {
            //let string = Bindings.UnsafeIntPointer_to_string(nativeType: record)
            print("log: \(record)")
            EventEmitter.sharedInstance()?.sendEvent(withName: "log", body: record);
        }
    }
}

class MyBroadcasterInterface: BroadcasterInterface {
    override func broadcast_transaction(tx: [UInt8]) {
        // insert code to broadcast transaction
    }
}

class MyPersister: Persist {
    override func persist_new_channel(id: OutPoint, data: ChannelMonitor) -> Result_NoneChannelMonitorUpdateErrZ {
        let idBytes: [UInt8] = id.write(obj: id)
        let monitorBytes: [UInt8] = data.write(obj: data)
        
        // persist monitorBytes to disk, keyed by idBytes
        
        // simplified result instantiation calls coming shortly!
        return Result_NoneChannelMonitorUpdateErrZ(pointer: LDKCResult_NoneChannelMonitorUpdateErrZ())
    }
    
    override func update_persisted_channel(id: OutPoint, update: ChannelMonitorUpdate, data: ChannelMonitor) -> Result_NoneChannelMonitorUpdateErrZ {
        let idBytes: [UInt8] = id.write(obj: id)
        let monitorBytes: [UInt8] = data.write(obj: data)
        
        // modify persisted monitorBytes keyed by idBytes on disk
        
        // simplified result instantiation calls coming shortly!
        return Result_NoneChannelMonitorUpdateErrZ(pointer: LDKCResult_NoneChannelMonitorUpdateErrZ())
    }
}

class MyFilter: Filter {
    
    override func register_tx(txid: [UInt8]?, script_pubkey: [UInt8]) {
        // watch this transaction on-chain
    }
    
    override func register_output(output: WatchedOutput) -> Option_C2Tuple_usizeTransactionZZ {
        let scriptPubkeyBytes = output.get_script_pubkey()
        let outpoint = output.get_outpoint()
        let txid = outpoint.get_txid()
        let outputIndex = outpoint.get_index()
        
        // watch for any transactions that spend this output on-chain
        
        let blockHashBytes = output.get_block_hash()
        // if block hash bytes are not null, return any transaction spending the output that is found in the corresponding block along with its index
        
        return Option_C2Tuple_usizeTransactionZZ(value: nil)
    }
}


let feeEstimator = MyFeeEstimator();
let logger = MyLogger();
let broadcaster = MyBroadcasterInterface();
let persister = MyPersister();
let filter = MyFilter();



/*func get_est_sat_per_1000_weight(instancePointer: UnsafeRawPointer?, confirmationTarget: LDKConfirmationTarget) -> UInt64 {
    if (confirmationTarget as AnyObject === LDKConfirmationTarget_HighPriority as AnyObject) {
        return UInt64(feerate_fast);
    }
    if (confirmationTarget as AnyObject === LDKConfirmationTarget_Normal as AnyObject) {
        return UInt64(feerate_medium);
    }
    return UInt64(feerate_slow);
}*/


func logCallback(pointer: UnsafeRawPointer?, buffer: UnsafePointer<Int8>?) -> Void {
    //let instance: Logger = RawLDKTypes.pointerToInstance(pointer: pointer!)
    //let message = String(cString: buffer!)
    //instance.log(message: message)
}

@objc(RnLdk)
class RnLdk: NSObject {

    @objc
    func start(_ entropyHex: String, blockchainTipHeight: Int, blockchainTipHashHex: String, serializedChannelManagerHex: String, monitorHexes: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {

        let chainMonitor = ChainMonitor.init(chain_source: filter, broadcaster: broadcaster, logger: logger, feeest: feeEstimator, persister: persister);
       
        let seed = stringToBytes(entropyHex);
        let timestamp_seconds = UInt64(NSDate().timeIntervalSince1970)
        let timestamp_nanos = UInt32.init(truncating: NSNumber(value: timestamp_seconds * 1000 * 1000))
        let keysManager = KeysManager(seed: seed, starting_time_secs: timestamp_seconds, starting_time_nanos: timestamp_nanos)
        
        let keysInterface = keysManager.as_KeysInterface();
        
        print(stringToBytes(blockchainTipHashHex));
        print(blockchainTipHeight)
        print(UInt32(blockchainTipHeight));
        
        resolve("yolo");
        return;
        let bestBlock = BestBlock(block_hash: stringToBytes(blockchainTipHashHex), height: UInt32(blockchainTipHeight))
        let chainParameters = ChainParameters(network_arg: LDKNetwork_Bitcoin, best_block_arg: bestBlock)
        
        let userConfig = UserConfig.init();
        
        if (true) {
            channel_manager = ChannelManager.init(fee_est: feeEstimator, chain_monitor: chainMonitor.as_Watch(), tx_broadcaster: broadcaster, logger: logger, keys_manager: keysInterface, config: userConfig, params: chainParameters);
        } else {
            let serialized_channel_manager: [UInt8] = [2, 1, 111, 226, 140, 10, 182, 241, 179, 114, 193, 166, 162, 70, 174, 99, 247, 79, 147, 30, 131, 101, 225, 90, 8, 156, 104, 214, 25, 0, 0, 0, 0, 0, 0, 10, 174, 219, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 238, 87, 135, 110, 67, 215, 108, 228, 66, 226, 192, 37, 6, 193, 120, 186, 5, 214, 209, 16, 169, 31, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] // <insert bytes you would have written in following the later step "Persist channel manager">
            let serializedChannelMonitors: [[UInt8]] = []
            do {
                let channel_manager_constructor = try ChannelManagerConstructor(channel_manager_serialized: serialized_channel_manager, channel_monitors_serialized: serializedChannelMonitors, keys_interface: keysInterface, fee_estimator: feeEstimator, chain_monitor: chainMonitor, filter: filter, tx_broadcaster: broadcaster, logger: logger)
                channel_manager = channel_manager_constructor.channelManager;
            } catch {
                resolve(false);
            }
            
        }
        resolve("hello ldk")
    }
    
    
    @objc
    func getVersion(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        resolve("0.0.5d")
    }
    
    func getName() -> String {
        return "RnLdk"
    }
    
    @objc
    func getRelevantTxids(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        
    }
    
    @objc
    func transactionUnconfirmed(_ txidHex: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
    }
    
    @objc
    func transactionConfirmed(_ headerHex: String, height: Int, txPos: Int, transactionHex: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        
    }
    
    @objc
    func updateBestBlock(_ headerHex: String, height: Int, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
    }
    
    @objc
    func connectPeer(_ pubkeyHex: String, hostname: String, port: Int, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        
    }
    
    @objc
    func sendPayment(_ destPubkeyHex: String, paymentHashHex: String, paymentSecretHex: String, shortChannelId: String, paymentValueMsat: Int, finalCltvValue: Int, LdkRoutesJsonArrayString: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
    }
    
    @objc
    func addInvoice(_ amtMsat: Int, description: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        
    }
    
    @objc
    func listPeers(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        
    }
    
    private func handleEvent(event: Event) {
        
    }
    
    @objc
    func getNodeId(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        if let nodeId = channel_manager?.get_our_node_id() {
            resolve(bytesToHex(bytes: nodeId, spacing: ""))
        } else {
            resolve("");
        }
    }
    
    @objc
    func getChannelManagerBytes(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        
    }
    @objc
    func closeChannelCooperatively(_ channelIdHex: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        
    }
    
    @objc
    func closeChannelForce(_ channelIdHex: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        
    }
    
    @objc
    func openChannelStep1(_ pubkey: String, channelValue: Int, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        
    }
    
    @objc
    func openChannelStep2(_ txhex: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        
    }
    
    @objc
    func listUsableChannels(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        
    }
    
    @objc
    func listChannels(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        
    }
    
    @objc
    func setFeerate(_ newFeerateFast: Int, newFeerateMedium: Int, newFeerateSlow: Int, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        
    }
    
    @objc
    func fireAnEvent(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        //NSString *eventName = notification.userInfo[@"name"];
        //[self sendEventWithName:@"EventReminder" body:@{@"name": eventName}];
        //EventEmitter.sharedInstance()?.sendEvent(withName: "log", body: ["txid": "111", "script_pubkey": "1111"]);
        self._sendEvent(eventName: "log", eventBody: ["txid": "111", "script_pubkey": "1111"]);
        //self.bridge.eventDispatcher.sendAppEventWithName( eventName: "trololo", body: "Woot!" );
        resolve(true);
    }
    
    func _sendEvent(eventName: String, eventBody: [String: String]) {
        EventEmitter.sharedInstance()?.sendEvent(withName: eventName, body: eventBody);
    }
    
    
}




func stringToBytes(_ string: String) -> [UInt8] {
    let length = string.count
    if length & 1 != 0 {
        return [];
    }
    var bytes = [UInt8]()
    bytes.reserveCapacity(length/2)
    var index = string.startIndex
    for _ in 0..<length/2 {
        let nextIndex = string.index(index, offsetBy: 2)
        if let b = UInt8(string[index..<nextIndex], radix: 16) {
            bytes.append(b)
        } else {
            return []
        }
        index = nextIndex
    }
    return bytes
}

func bytesToHex(bytes: [UInt8], spacing: String) -> String
{
    var hexString: String = ""
    var count = bytes.count
    for byte in bytes
    {
        hexString.append(String(format:"%02X", byte))
        count = count - 1
        if count > 0
        {
            hexString.append(spacing)
        }
    }
    return hexString
}


