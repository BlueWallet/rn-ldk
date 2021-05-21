import Foundation
import LDKFramework

// borrowed from JS:
let MARKER_LOG = "log";
let MARKER_REGISTER_OUTPUT = "marker_register_output";
let MARKER_REGISTER_TX = "register_tx";
let MARKER_BROADCAST = "broadcast";
let MARKER_PERSIST = "persist";
let MARKER_PAYMENT_SENT = "payment_sent";
let MARKER_PAYMENT_FAILED = "payment_failed";
let MARKER_PAYMENT_RECEIVED = "payment_received";
let MARKER_FUNDING_GENERATION_READY = "funding_generation_ready";
//

var feerate_fast = 7500; // estimate fee rate in BTC/kB
var feerate_medium = 7500; // estimate fee rate in BTC/kB
var feerate_slow = 7500; // estimate fee rate in BTC/kB

var channel_manager: LDKFramework.ChannelManager?;
var peer_manager: LDKFramework.PeerManager?;

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
            print("ReactNativeLDK: \(record)")
            _sendEvent(eventName: MARKER_LOG, eventBody: ["line" : record])
        }
    }
}

class MyBroadcasterInterface: BroadcasterInterface {
    override func broadcast_transaction(tx: [UInt8]) {
        print("ReactNativeLDK: want to broadcast txhex")
        _sendEvent(eventName: MARKER_BROADCAST, eventBody: ["txhex": bytesToHex(bytes: tx)])
    }
}

class MyPersister: Persist {
    override func persist_new_channel(id: OutPoint, data: ChannelMonitor) -> Result_NoneChannelMonitorUpdateErrZ {
        print("ReactNativeLDK: persist_new_channel")
        let idBytes: [UInt8] = id.write(obj: id)
        let monitorBytes: [UInt8] = data.write(obj: data)
        _sendEvent(eventName: MARKER_PERSIST, eventBody: ["id": bytesToHex(bytes: idBytes), "data": bytesToHex(bytes: monitorBytes)]);
        
        // simplified result instantiation calls coming shortly!
        return Result_NoneChannelMonitorUpdateErrZ(pointer: LDKCResult_NoneChannelMonitorUpdateErrZ())
    }
    
    override func update_persisted_channel(id: OutPoint, update: ChannelMonitorUpdate, data: ChannelMonitor) -> Result_NoneChannelMonitorUpdateErrZ {
        print("ReactNativeLDK: update_persisted_channel");
        let idBytes: [UInt8] = id.write(obj: id)
        let monitorBytes: [UInt8] = data.write(obj: data)
        _sendEvent(eventName: MARKER_PERSIST, eventBody: ["id": bytesToHex(bytes: idBytes), "data": bytesToHex(bytes: monitorBytes)]);
        
        // simplified result instantiation calls coming shortly!
        return Result_NoneChannelMonitorUpdateErrZ(pointer: LDKCResult_NoneChannelMonitorUpdateErrZ())
    }
}

class MyFilter: Filter {
    
    override func register_tx(txid: [UInt8]?, script_pubkey: [UInt8]) {
        print("ReactNativeLDK: register_tx");
        _sendEvent(eventName: MARKER_REGISTER_TX, eventBody: ["txid": bytesToHex(bytes: txid ?? []), "script_pubkey": bytesToHex(bytes: script_pubkey)]);
    }
    
    override func register_output(output: WatchedOutput) -> Option_C2Tuple_usizeTransactionZZ {
        print("ReactNativeLDK: register_output");
        let scriptPubkeyBytes = output.get_script_pubkey()
        let outpoint = output.get_outpoint()
        let outputIndex = outpoint.get_index()
        
        // watch for any transactions that spend this output on-chain
        
        let blockHashBytes = output.get_block_hash()
        // if block hash bytes are not null, return any transaction spending the output that is found in the corresponding block along with its index
        
        _sendEvent(eventName: MARKER_REGISTER_OUTPUT, eventBody: ["block_hash": bytesToHex(bytes: blockHashBytes), "index": String(outputIndex), "script_pubkey": bytesToHex(bytes: scriptPubkeyBytes)]);
        
        return Option_C2Tuple_usizeTransactionZZ(value: nil)
    }
}


let feeEstimator = MyFeeEstimator();
let logger = MyLogger();
let broadcaster = MyBroadcasterInterface();
let persister = MyPersister();
let filter = MyFilter();


@objc(RnLdk)
class RnLdk: NSObject {

    @objc
    func start(_ entropyHex: String, blockchainTipHeight: NSNumber, blockchainTipHashHex: String, serializedChannelManagerHex: String, monitorHexes: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {

        let chainMonitor = ChainMonitor.init(chain_source: filter, broadcaster: broadcaster, logger: logger, feeest: feeEstimator, persister: persister);
       
        let seed = hexToBytes(entropyHex);
        let timestamp_seconds = UInt64(NSDate().timeIntervalSince1970)
        let timestamp_nanos = UInt32.init(truncating: NSNumber(value: timestamp_seconds * 1000 * 1000))
        let keysManager = KeysManager(seed: seed, starting_time_secs: timestamp_seconds, starting_time_nanos: timestamp_nanos)
        let keysInterface = keysManager.as_KeysInterface();
        let nodeSecret = Bindings.LDKSecretKey_to_array(nativeType: keysInterface.cOpaqueStruct!.get_node_secret(keysInterface.cOpaqueStruct!.this_arg))
        let secureRandomBytes = Bindings.LDKThirtyTwoBytes_to_array(nativeType: keysInterface.cOpaqueStruct!.get_secure_random_bytes(keysInterface.cOpaqueStruct!.this_arg))
        let userConfig = UserConfig.init();
        
        if (serializedChannelManagerHex != "") {
            var serializedChannelMonitors: [[UInt8]] = [];
            let hexesArr = monitorHexes.split(separator: ",");
            for hex in hexesArr {
                serializedChannelMonitors.append(hexToBytes(String(hex)))
            }
            
            let serialized_channel_manager: [UInt8] = hexToBytes(serializedChannelManagerHex);
            
            do {
                let channel_manager_constructor = try ChannelManagerConstructor(channel_manager_serialized: serialized_channel_manager, channel_monitors_serialized: serializedChannelMonitors, keys_interface: keysInterface, fee_estimator: feeEstimator, chain_monitor: chainMonitor, filter: filter, tx_broadcaster: broadcaster, logger: logger)
                
                channel_manager = channel_manager_constructor.channelManager;
            } catch {
                resolve(false);
                return;
            }
        } else {
            let channel_manager_constructor = ChannelManagerConstructor(network: LDKNetwork_Bitcoin, config: userConfig, current_blockchain_tip_hash: hexToBytes(blockchainTipHashHex), current_blockchain_tip_height: UInt32(truncating: blockchainTipHeight), keys_interface: keysInterface, fee_estimator: feeEstimator, chain_monitor: chainMonitor, tx_broadcaster: broadcaster, logger: logger);
            channel_manager = channel_manager_constructor.channelManager;
            
        }
        
        let ignorer = IgnoringMessageHandler()
        let messageHandler = MessageHandler(chan_handler_arg: channel_manager!.as_ChannelMessageHandler(), route_handler_arg:  ignorer.as_RoutingMessageHandler())
        
        peer_manager = PeerManager(message_handler: messageHandler, our_node_secret: nodeSecret, ephemeral_random_data: secureRandomBytes, logger: logger)
        
        
        resolve("hello ldk")
    }
    
    
    @objc
    func getVersion(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        resolve("0.0.11")
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
            resolve(bytesToHex(bytes: nodeId))
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
        let rawChannels = channel_manager?.list_channels() ?? []
        var jsonArray = "[";
        var first = true;
        rawChannels.map { (rawDetails: LDKChannelDetails) ->  ChannelDetails in
             let it = ChannelDetails(pointer: rawDetails)
            let short_channel_id = it.get_short_channel_id().getValue() ?? 0;

            var channelObject = "{";
            channelObject += "\"channel_id\":" + "\"" + bytesToHex(bytes: it.get_channel_id()) + "\",";
            channelObject += "\"channel_value_satoshis\":" + String(it.get_channel_value_satoshis()) + ",";
            channelObject += "\"inbound_capacity_msat\":" + String(it.get_inbound_capacity_msat()) + ",";
            channelObject += "\"outbound_capacity_msat\":" + String(it.get_outbound_capacity_msat()) + ",";
            channelObject += "\"short_channel_id\":" + "\"" + String(short_channel_id) + "\",";
            channelObject += "\"is_live\":" + (it.get_is_live() ? "true" : "false") + ",";
            channelObject += "\"remote_network_id\":" + "\"" + bytesToHex(bytes: it.get_remote_network_id()) + "\",";
            channelObject += "\"user_id\":" + String(it.get_user_id());
            channelObject += "}";

            if (!first) { jsonArray += ","; }
            jsonArray += channelObject;
            first = false;
            return it;
        }
        
        jsonArray += "]";
        resolve(jsonArray);
    }
    
    @objc
    func setFeerate(_ newFeerateFast: NSNumber, newFeerateMedium: NSNumber, newFeerateSlow: NSNumber, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        if (Int(newFeerateFast) < 300) { return resolve(false); }
        if (Int(newFeerateMedium) < 300) { return resolve(false); }
        if (Int(newFeerateSlow) < 300) { return resolve(false); }
    
        feerate_fast = Int(newFeerateFast);
        feerate_medium = Int(newFeerateMedium);
        feerate_slow = Int(newFeerateSlow);
        resolve(true);
    }
    
    @objc
    func fireAnEvent(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseResolveBlock) {
        _sendEvent(eventName: "log", eventBody: ["txid": "this is", "script_pubkey": "a debug event"]);
        resolve(true);
    }
}



func _sendEvent(eventName: String, eventBody: [String: String]) {
    EventEmitter.sharedInstance()?.sendEvent(withName: eventName, body: eventBody);
}




func hexToBytes(_ string: String) -> [UInt8] {
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

func bytesToHex(bytes: [UInt8]) -> String
{
    var hexString: String = ""
    var count = bytes.count
    for byte in bytes
    {
        hexString.append(String(format:"%02X", byte))
        count = count - 1
    }
    return hexString.lowercased()
}


