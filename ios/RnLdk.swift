import Foundation
import LDKFramework

// borrowed from JS:
let MARKER_LOG = "log"
let MARKER_REGISTER_OUTPUT = "marker_register_output"
let MARKER_REGISTER_TX = "register_tx"
let MARKER_BROADCAST = "broadcast"
let MARKER_PERSIST = "persist"
let MARKER_PAYMENT_SENT = "payment_sent"
let MARKER_PAYMENT_FAILED = "payment_failed"
let MARKER_PAYMENT_RECEIVED = "payment_received"
let MARKER_FUNDING_GENERATION_READY = "funding_generation_ready"
//

var feerate_fast = 7500 // estimate fee rate in BTC/kB
var feerate_medium = 7500 // estimate fee rate in BTC/kB
var feerate_slow = 7500 // estimate fee rate in BTC/kB

var refund_address_script = "76a91419129d53e6319baf19dba059bead166df90ab8f588ac"

var channel_manager: LDKFramework.ChannelManager?
var peer_manager: LDKFramework.PeerManager?
var keys_manager: LDKFramework.KeysManager?
var temporary_channel_id: [UInt8]? = nil
var peer_handler: SwiftSocketPeerHandler?
var chain_monitor: ChainMonitor?
var channel_manager_constructor: ChannelManagerConstructor?

class MyFeeEstimator: FeeEstimator {
    override func get_est_sat_per_1000_weight(confirmation_target: LDKConfirmationTarget) -> UInt32 {
        if (confirmation_target as AnyObject === LDKConfirmationTarget_HighPriority as AnyObject) {
            return UInt32(feerate_fast)
        }
        if (confirmation_target as AnyObject === LDKConfirmationTarget_Normal as AnyObject) {
            return UInt32(feerate_medium)
        }
        return UInt32(feerate_slow)
    }
}

class MyLogger: Logger {
    override func log(record: String?) {
        if let record = record {
            print("ReactNativeLDK: \(record)")
            sendEvent(eventName: MARKER_LOG, eventBody: ["line" : record])
        }
    }
}

class MyBroadcasterInterface: BroadcasterInterface {
    override func broadcast_transaction(tx: [UInt8]) {
        print("ReactNativeLDK: want to broadcast txhex")
        sendEvent(eventName: MARKER_BROADCAST, eventBody: ["txhex": bytesToHex(bytes: tx)])
    }
}

class MyPersister: Persist {
    override func persist_new_channel(id: OutPoint, data: ChannelMonitor) -> Result_NoneChannelMonitorUpdateErrZ {
        print("ReactNativeLDK: persist_new_channel")
        let idBytes: [UInt8] = id.to_channel_id()
        let monitorBytes: [UInt8] = data.write(obj: data)
        sendEvent(eventName: MARKER_PERSIST, eventBody: ["id": bytesToHex(bytes: idBytes), "data": bytesToHex(bytes: monitorBytes)])
        
        // simplified result instantiation calls coming shortly!
        return Result_NoneChannelMonitorUpdateErrZ()
    }
    
    override func update_persisted_channel(id: OutPoint, update: ChannelMonitorUpdate, data: ChannelMonitor) -> Result_NoneChannelMonitorUpdateErrZ {
        print("ReactNativeLDK: update_persisted_channel")
        let idBytes: [UInt8] = id.to_channel_id()
        let monitorBytes: [UInt8] = data.write(obj: data)
        sendEvent(eventName: MARKER_PERSIST, eventBody: ["id": bytesToHex(bytes: idBytes), "data": bytesToHex(bytes: monitorBytes)])
        
        // simplified result instantiation calls coming shortly!
        return Result_NoneChannelMonitorUpdateErrZ()
    }
}

class MyChannelManagerPersister : ChannelManagerPersister, ExtendedChannelManagerPersister {
    func handle_event(event: Event) {
        handleEvent(event: event)
    }
    
    override func persist_manager(channel_manager: ChannelManager) -> Result_NoneErrorZ {
        let channel_manager_bytes = channel_manager.write(obj: channel_manager)
        sendEvent(eventName: "persist_manager", eventBody: ["channel_manager_bytes": bytesToHex(bytes: channel_manager_bytes)])
        return Result_NoneErrorZ()
    }
}

class MyFilter: Filter {
    override func register_tx(txid: [UInt8]?, script_pubkey: [UInt8]) {
        print("ReactNativeLDK: register_tx")
        sendEvent(eventName: MARKER_REGISTER_TX, eventBody: ["txid": bytesToHex(bytes: txid ?? []), "script_pubkey": bytesToHex(bytes: script_pubkey)])
    }
    
    override func register_output(output: WatchedOutput) -> Option_C2Tuple_usizeTransactionZZ {
        print("ReactNativeLDK: register_output")
        let scriptPubkeyBytes = output.get_script_pubkey()
        let outpoint = output.get_outpoint()
        let outputIndex = outpoint.get_index()
        
        // watch for any transactions that spend this output on-chain
        
        let blockHashBytes = output.get_block_hash()
        // if block hash bytes are not null, return any transaction spending the output that is found in the corresponding block along with its index
        
        sendEvent(eventName: MARKER_REGISTER_OUTPUT, eventBody: ["block_hash": bytesToHex(bytes: blockHashBytes), "index": String(outputIndex), "script_pubkey": bytesToHex(bytes: scriptPubkeyBytes)])
        
        return Option_C2Tuple_usizeTransactionZZ(value: nil)
    }
}


let feeEstimator = MyFeeEstimator()
let logger = MyLogger()
let broadcaster = MyBroadcasterInterface()
let persister = MyPersister()
let filter = MyFilter()
let channel_manager_persister = MyChannelManagerPersister()


@objc(RnLdk)
class RnLdk: NSObject {
    
    @objc
    func start(_ entropyHex: String, blockchainTipHeight: NSNumber, blockchainTipHashHex: String, serializedChannelManagerHex: String, monitorHexes: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        let chain_monitor = ChainMonitor.init(chain_source: filter, broadcaster: broadcaster, logger: logger, feeest: feeEstimator, persister: persister)
        let seed = hexStringToByteArray(entropyHex)
        let timestamp_seconds = UInt64(NSDate().timeIntervalSince1970)
        let timestamp_nanos = UInt32.init(truncating: NSNumber(value: timestamp_seconds * 1000 * 1000))
        keys_manager = KeysManager(seed: seed, starting_time_secs: timestamp_seconds, starting_time_nanos: timestamp_nanos)
        guard let keysInterface = keys_manager?.as_KeysInterface() else {
            let error = NSError(domain: "start as_KeysInterface failed", code: 1, userInfo: nil)
            return reject("start", "Failed",  error)
        }
        _ = keysInterface.get_node_secret() // Bindings.LDKSecretKey_to_array(nativeType: keysInterface.cOpaqueStruct!.get_node_secret(keysInterface.cOpaqueStruct!.this_arg))
        guard let cOpaqueStruct = keysInterface.cOpaqueStruct  else {
            let error = NSError(domain: "start cOpaqueStruct failed", code: 1, userInfo: nil)
            return reject("start", "Failed",  error)
        }
        _ = Bindings.LDKThirtyTwoBytes_to_array(nativeType: cOpaqueStruct.get_secure_random_bytes(cOpaqueStruct.this_arg))
        let userConfig = UserConfig.init()
        
        if (!serializedChannelManagerHex.isEmpty) {
            var serializedChannelMonitors: [[UInt8]] = []
            let hexesArr = monitorHexes.split(separator: ",")
            for hex in hexesArr {
                serializedChannelMonitors.append(hexStringToByteArray(String(hex)))
            }
            
            let serialized_channel_manager: [UInt8] = hexStringToByteArray(serializedChannelManagerHex)
            
            do {
                channel_manager_constructor = try ChannelManagerConstructor(channel_manager_serialized: serialized_channel_manager, channel_monitors_serialized: serializedChannelMonitors, keys_interface: keysInterface, fee_estimator: feeEstimator, chain_monitor: chain_monitor, filter: filter, router: nil, tx_broadcaster: broadcaster, logger: logger)
            } catch {
                reject("start", "Failed",  error)
                return
            }
        } else {
            channel_manager_constructor = ChannelManagerConstructor(network: LDKNetwork_Bitcoin, config: userConfig, current_blockchain_tip_hash: hexStringToByteArray(blockchainTipHashHex), current_blockchain_tip_height: UInt32(truncating: blockchainTipHeight), keys_interface: keysInterface, fee_estimator: feeEstimator, chain_monitor: chain_monitor, router: nil, tx_broadcaster: broadcaster, logger: logger)
        }
        
        guard let channel_manager_constructor = channel_manager_constructor  else {
            let error = NSError(domain: "start channel_manager_constructor failed", code: 1, userInfo: nil)
            reject("start", "channel_manager_constructor failed",  error)
            return
        }
        channel_manager = channel_manager_constructor.channelManager
        channel_manager_constructor.chain_sync_completed(persister: channel_manager_persister)
        peer_manager = channel_manager_constructor.peerManager
        
        //        let ignorer = IgnoringMessageHandler()
        //        let messageHandler = MessageHandler(chan_handler_arg: channel_manager!.as_ChannelMessageHandler(), route_handler_arg:  ignorer.as_RoutingMessageHandler())
        //        peer_manager = PeerManager(message_handler: messageHandler, our_node_secret: nodeSecret, ephemeral_random_data: secureRandomBytes, logger: logger)
        
        peer_handler = SwiftSocketPeerHandler(peerManager: channel_manager_constructor.peerManager)
        
        resolve("hello ldk")
    }
    
    
    @objc
    func getVersion(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        resolve("0.0.99.3")
    }
    
    func getName() -> String {
        return "RnLdk"
    }
    
    @objc
    func getRelevantTxids(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard let channel_manager = channel_manager, let chain_monitor = chain_monitor else {
            let error = NSError(domain: "Channel manager", code: 1, userInfo: nil)
            return reject("Channel manager", "Not Initialized",  error)
        }
        
        var first = true
        var json: String = "["
        for it in channel_manager.as_Confirm().get_relevant_txids() {
            if (!first) { json += "," }
            first = false
            json += "\"" + bytesToHex32Reversed(bytes: it.data) + "\"" // reversed
        }
        
        for it in chain_monitor.as_Confirm().get_relevant_txids() {
            if (!first) { json += "," }
            first = false
            json += "\"" + bytesToHex32Reversed(bytes: it.data) + "\"" // reversed
        }
        json += "]"
        resolve(json)
    }
    
    @objc
    func transactionUnconfirmed(_ txidHex: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard let channel_manager = channel_manager, let chain_monitor = chain_monitor else {
            let error = NSError(domain: "Channel manager", code: 1, userInfo: nil)
            return reject("Channel manager", "Not Initialized",  error)
        }
        channel_manager.as_Confirm().transaction_unconfirmed(txid: hexStringToByteArray(txidHex))
        chain_monitor.as_Confirm().transaction_unconfirmed(txid: hexStringToByteArray(txidHex))
        resolve(true)
    }
    
    @objc
    func transactionConfirmed(_ headerHex: String, height: NSNumber, txPos: NSNumber, transactionHex: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard let channel_manager = channel_manager, let chain_monitor = chain_monitor else {
            let error = NSError(domain: "Channel manager", code: 1, userInfo: nil)
            return reject("Channel manager", "Not Initialized",  error)
        }
        let txData = LDKC2Tuple_usizeTransactionZ(a: UInt(truncating: txPos), b: Bindings.new_LDKTransaction(array: hexStringToByteArray(transactionHex)))
        let txarray = [txData]
        channel_manager.as_Confirm().transactions_confirmed(header: hexStringToByteArray(headerHex), txdata: txarray, height: UInt32(truncating: height))
        chain_monitor.as_Confirm().transactions_confirmed(header: hexStringToByteArray(headerHex), txdata: txarray, height: UInt32(truncating: height))
        resolve(true)
    }
    
    @objc
    func updateBestBlock(_ headerHex: String, height: NSNumber, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard let channel_manager = channel_manager, let chain_monitor = chain_monitor else {
            let error = NSError(domain: "Channel manager", code: 1, userInfo: nil)
            return reject("Channel manager", "Not Initialized",  error)
        }
        channel_manager.as_Confirm().best_block_updated(header: hexStringToByteArray(headerHex), height: UInt32(truncating: height))
        chain_monitor.as_Confirm().best_block_updated(header: hexStringToByteArray(headerHex), height: UInt32(truncating: height))
        resolve(true)
    }
    
    @objc
    func connectPeer(_ pubkeyHex: String, hostname: String, port: NSNumber, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        print("ReactNativeLDK: connecting to peer " + pubkeyHex)
        guard let peer_handler = peer_handler else {
            let error = NSError(domain: "connectPeer", code: 1, userInfo: nil)
            return reject("connectPeer", "No connect peer",  error)
        }
        guard let _ = peer_handler.connect(address: hostname, port: Int32(truncating: port),  theirNodeId: hexStringToByteArray(pubkeyHex)) else {
            let error = NSError(domain: "connectPeer", code: 1, userInfo: nil)
            return reject("connectPeer", "Exception",  error)
        }
        resolve(true)
    }
    
    @objc
    func sendPayment(_ destPubkeyHex: String, paymentHashHex: String, paymentSecretHex: String, shortChannelId: String, paymentValueMsat: NSNumber, finalCltvValue: NSNumber, LdkRoutesJsonArrayString: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        print("ReactNativeLDK: destPubkeyHex " + destPubkeyHex)
        print("ReactNativeLDK: paymentHashHex " + paymentHashHex)
        print("ReactNativeLDK: paymentSecretHex " + paymentSecretHex)
        print("ReactNativeLDK: shortChannelId " + shortChannelId)
        print("ReactNativeLDK: paymentValueMsat " + paymentValueMsat.stringValue)
        print("ReactNativeLDK: finalCltvValue " + finalCltvValue.stringValue)
        
        guard let short_channel_id_arg = UInt64(shortChannelId), let cOpaqueStruct = RouteHop(
            pubkey_arg: hexStringToByteArray(destPubkeyHex),
            node_features_arg: NodeFeatures(),
            short_channel_id_arg: short_channel_id_arg,
            channel_features_arg: ChannelFeatures(),
            fee_msat_arg: UInt64(truncating: paymentValueMsat),
            cltv_expiry_delta_arg: UInt32(truncating: finalCltvValue)
        ).cOpaqueStruct, let channel_manager = channel_manager else {
            let error = NSError(domain: "sendPayment", code: 1, userInfo: nil)
            return reject("sendPayment", "cOpaqueStruct failed",  error)
        }
        // first hop:
        // (also the last one of no route provided - assuming paying to neighbor node)
        var path: [LDKRouteHop] = [cOpaqueStruct]
        //
        if (!LdkRoutesJsonArrayString.isEmpty) {
            // full route was provided
            path.removeAll()
            
            do {
                let data = Data(LdkRoutesJsonArrayString.utf8)
                // make sure this JSON is in the format we expect
                
                if let json = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions()) as? [AnyObject] {
                    // try to read out an array
                    for hopJson in json {
                        print("hop:::: ")
                        //                        print(hopJson)
                        
                        print(hopJson["pubkey"] as? String ?? "No pubkey")
                        print(hopJson["short_channel_id"] as? String ?? "No short_channel_id")
                        print(hopJson["fee_msat"] as? NSNumber ?? "No fee_msat")
                        print(hopJson["cltv_expiry_delta"] as? NSNumber ?? "No cltv_expiry_delta")
                        //
                        if let pubkey = hopJson["pubkey"] as? String, let short_channel_id_arg = hopJson["short_channel_id"] as? String, let shortChannelIdUInt64 = UInt64(short_channel_id_arg), let fee_msat_arg = hopJson["fee_msat"] as? NSNumber, let cltv_expiry_delta_arg = hopJson["cltv_expiry_delta"] as? NSNumber, let routeHop = RouteHop(pubkey_arg: hexStringToByteArray(pubkey),
                                                                                                                                                                                                                                                                                                                                                      node_features_arg: NodeFeatures(),
                                                                                                                                                                                                                                                                                                                                                      short_channel_id_arg: shortChannelIdUInt64,
                                                                                                                                                                                                                                                                                                                                                      channel_features_arg: ChannelFeatures(),
                                                                                                                                                                                                                                                                                                                                                      fee_msat_arg: UInt64(truncating: fee_msat_arg),
                                                                                                                                                                                                                                                                                                                                                      cltv_expiry_delta_arg: UInt32(truncating: cltv_expiry_delta_arg)
                        ).cOpaqueStruct {
                            path.append(routeHop)
                        }
                        
                    }
                }
            } catch let error as NSError {
                reject("sendPayment", "Failed to load",  error)
            }
        }
        
        let route = Route(
            paths_arg: [
                path
            ]
        )
        
        let payment_hash = hexStringToByteArray(paymentHashHex)
        let payment_secret = hexStringToByteArray(paymentSecretHex)
        let payment_res = channel_manager.send_payment(route: route, payment_hash: payment_hash, payment_secret: payment_secret)
        if payment_res.isOk() {
            resolve(true)
        } else {
            let error = NSError(domain: "sendPayment", code: 1, userInfo: nil)
            reject("sendPayment", "Failed",  error)
        }
    }
    
    @objc
    func addInvoice(_ amtMsat: NSNumber, description: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard let channel_manager = channel_manager, let keys_manager = keys_manager else {
            let error = NSError(domain: "addInvoice", code: 1, userInfo: nil)
            return  reject("addInvoice", "No channel_manager initialized",  error)
        }
        let invoiceResult = Bindings.createInvoiceFromChannelManager(channelManager: channel_manager, keysManager: keys_manager.as_KeysInterface(), network: LDKCurrency_Bitcoin, amountMsat: UInt64(truncating: amtMsat), description: description)
        
        if let invoice = invoiceResult.getValue() {
            resolve(invoice.to_str(o: invoice))
        } else {
            let error = NSError(domain: "addInvoice", code: 1, userInfo: nil)
            reject("addInvoice", "Failed", error)
        }
    }
    
    @objc
    func listPeers(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard let peer_manager = peer_manager else {
            let error = NSError(domain: "listPeers", code: 1, userInfo: nil)
            return  reject("lostPeers", "No peer manager initialized",  error)
        }
        
        let peer_node_ids = peer_manager.get_peer_node_ids()
        print(peer_node_ids)
        
        var json = "["
        var first = true
        for it in peer_node_ids {
            if (!first) { json += "," }
            first = false
            json += "\"" + bytesToHex(bytes: it) + "\""
        }
        json += "]"
        resolve(json)
    }
    
    
    
    @objc
    func getNodeId(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        if let nodeId = channel_manager?.get_our_node_id() {
            resolve(bytesToHex(bytes: nodeId))
        } else {
            let error = NSError(domain: "getNodeId", code: 1, userInfo: nil)
            reject("getNodeId", "Exception",  error)
        }
    }
    
    @objc
    func closeChannelCooperatively(_ channelIdHex: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard let close_result = channel_manager?.close_channel(channel_id: hexStringToByteArray(channelIdHex)), close_result.isOk() else {
            let error = NSError(domain: "closeChannelCooperatively", code: 1, userInfo: nil)
            return reject("closeChannelCooperatively", "Failed",  error)
        }
        resolve(true)
    }
    
    @objc
    func closeChannelForce(_ channelIdHex: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard let close_result = channel_manager?.force_close_channel(channel_id: hexStringToByteArray(channelIdHex)) else {
            let error = NSError(domain: "closeChannelForce", code: 1, userInfo: nil)
            return reject("closeChannelForce", "Failed",  error)
        }
        if (close_result.isOk()) {
            resolve(true)
        } else {
            let error = NSError(domain: "closeChannelForce", code: 1, userInfo: nil)
            reject("closeChannelForce", "Failed",  error)
        }
    }
    
    @objc
    func openChannelStep1(_ pubkey: String, channelValue: NSNumber, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        temporary_channel_id = nil
        let peer_node_pubkey = hexStringToByteArray(pubkey)
        let userConfig = UserConfig.init()
        if let create_channel_result = channel_manager?.create_channel(
            their_network_key: peer_node_pubkey, channel_value_satoshis: UInt64(truncating: channelValue), push_msat: 0, user_id: 42, override_config: userConfig
        ) {
            if create_channel_result.isOk() {
                print("ReactNativeLDK: create_channel_result = true")
                resolve(true)
            } else {
                print("ReactNativeLDK: create_channel_result = false")
                let error = NSError(domain: "openChannelStep1", code: 1, userInfo: nil)
                reject("openChannelStep1", "Failed",  error)
            }
        } else {
            print("ReactNativeLDK: create_channel_result = false")
            let error = NSError(domain: "openChannelStep1", code: 1, userInfo: nil)
            reject("openChannelStep1", "Failed",  error)
        }
    }
    
    @objc
    func openChannelStep2(_ txhex: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard let temporary_channel_id = temporary_channel_id else {
            let error = NSError(domain: "openChannelStep2", code: 1, userInfo: nil)
            return reject("openChannelStep2", "Not initialized",  error)
        }
        
        guard let funding_res = channel_manager?.funding_transaction_generated(temporary_channel_id: temporary_channel_id, funding_transaction: hexStringToByteArray(txhex)) else {
            print("ReactNativeLDK: funding_res = false")
            let error = NSError(domain: "openChannelStep2", code: 1, userInfo: nil)
            reject("openChannelStep2", "Failed",  error)
            return
        }
        // funding_transaction_generated should only generate an error if the
        // transaction didn't meet the required format (or the counterparty already
        // closed the channel on us):
        if !funding_res.isOk()  {
            print("ReactNativeLDK: funding_res = false")
            let error = NSError(domain: "openChannelStep2", code: 1, userInfo: nil)
            reject("openChannelStep2", "Failed",  error)
            return
        }
        
        // At this point LDK will exchange the remaining channel open messages with
        // the counterparty and, when appropriate, broadcast the funding transaction
        // provided.
        // Once it confirms, the channel will be open and available for use (indicated
        // by its presence in `channel_manager.list_usable_channels()`).
        
        resolve(true)
    }
    
    @objc
    func listUsableChannels(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard let channel_manager = channel_manager else {
            let error = NSError(domain: "listUsableChannels", code: 1, userInfo: nil)
            return reject("listUsableChannels", "Channel manager not initialized",  error)
        }
        
        let rawChannels = channel_manager.list_usable_channels().isEmpty ? [] : channel_manager.list_usable_channels()
        var jsonArray = "["
        var first = true
        rawChannels.map { (rawDetails: LDKChannelDetails) ->  ChannelDetails in
            let it = ChannelDetails(pointer: rawDetails)
            let channelObject = self.channel2ChannelObject(it: it)
            
            if (!first) { jsonArray += "," }
            jsonArray += channelObject
            first = false
            return it
        }
        
        jsonArray += "]"
        resolve(jsonArray)
    }
    
    @objc
    func listChannels(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard let channel_manager = channel_manager else {
            let error = NSError(domain: "listChannels", code: 1, userInfo: nil)
            return reject("listChannels", "Channel Manager not initialized",  error)
        }
        
        let rawChannels = channel_manager.list_channels().isEmpty ? [] : channel_manager.list_channels()
        var jsonArray = "["
        var first = true
        rawChannels.map { (rawDetails: LDKChannelDetails) ->  ChannelDetails in
            let it = ChannelDetails(pointer: rawDetails)
            let channelObject = self.channel2ChannelObject(it: it)
            
            if (!first) { jsonArray += "," }
            jsonArray += channelObject
            first = false
            return it
        }
        
        jsonArray += "]"
        resolve(jsonArray)
    }
    
    func channel2ChannelObject(it: ChannelDetails) -> String {
        let short_channel_id = it.get_short_channel_id().getValue() ?? 0
        
        var channelObject = "{"
        channelObject += "\"channel_id\":" + "\"" + bytesToHex(bytes: it.get_channel_id()) + "\","
        channelObject += "\"channel_value_satoshis\":" + String(it.get_channel_value_satoshis()) + ","
        channelObject += "\"inbound_capacity_msat\":" + String(it.get_inbound_capacity_msat()) + ","
        channelObject += "\"outbound_capacity_msat\":" + String(it.get_outbound_capacity_msat()) + ","
        channelObject += "\"short_channel_id\":" + "\"" + String(short_channel_id) + "\","
        channelObject += "\"is_usable\":" + (it.get_is_usable() ? "true" : "false") + ","
        channelObject += "\"is_funding_locked\":" + (it.get_is_funding_locked() ? "true" : "false") + ","
        channelObject += "\"is_outbound\":" + (it.get_is_outbound() ? "true" : "false") + ","
        channelObject += "\"is_public\":" + (it.get_is_public() ? "true" : "false") + ","
        channelObject += "\"remote_node_id\":" + "\"" + bytesToHex(bytes: it.get_counterparty().get_node_id()) + "\","
        channelObject += "\"user_id\":" + String(it.get_user_id())
        channelObject += "}"
        
        return channelObject
    }
    
    @objc
    func setRefundAddressScript(_ refundAddressScriptHex: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        refund_address_script = refundAddressScriptHex
        resolve(true)
    }
    
    @objc
    func setFeerate(_ newFeerateFast: NSNumber, newFeerateMedium: NSNumber, newFeerateSlow: NSNumber, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        if (Int(truncating: newFeerateFast) < 300) {
            let error = NSError(domain: "newFeerateFast", code: 1, userInfo: nil)
            return reject("newFeerateFast", "Too Small",  error)
        }
        if (Int(truncating: newFeerateMedium) < 300) {
            let error = NSError(domain: "newFeerateMedium", code: 1, userInfo: nil)
            return reject("newFeerateMedium", "Too Small",  error)
        }
        if (Int(truncating: newFeerateSlow) < 300) {
            let error = NSError(domain: "newFeerateSlow", code: 1, userInfo: nil)
            return reject("newFeerateSlow", "Too Small",  error)
        }
        feerate_fast = Int(truncating: newFeerateFast)
        feerate_medium = Int(truncating: newFeerateMedium)
        feerate_slow = Int(truncating: newFeerateSlow)
        resolve(true)
    }
    
    @objc
    func fireAnEvent(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        sendEvent(eventName: MARKER_LOG, eventBody: ["line": "test"])
        resolve(true)
    }
    
    
    @objc
    func stop(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        channel_manager_constructor?.interrupt()
        
        channel_manager = nil
        peer_manager = nil
        keys_manager = nil
        temporary_channel_id = nil
        peer_handler = nil
        chain_monitor = nil
        channel_manager_constructor = nil
        
        resolve(true)
    }
}

func handleEvent(event: Event) {
    if let spendableOutputEvent = event.getValueAsSpendableOutputs() {
        print("ReactNativeLDK: trying to spend output")
        let outputs = spendableOutputEvent.getOutputs()
        let destinationScript = hexStringToByteArray(refund_address_script)
        guard let result = keys_manager?.spend_spendable_outputs(descriptors: outputs, outputs: [], change_destination_script: destinationScript, feerate_sat_per_1000_weight: UInt32(feerate_fast)) else {
            return
        }
        
        if result.isOk() {
            if let cOpaqueStruct = result.cOpaqueStruct {
                // success building the transaction, passing it to outer code to broadcast
                let transaction = Bindings.LDKTransaction_to_array(nativeType: cOpaqueStruct.contents.result.pointee)
                sendEvent(eventName: MARKER_BROADCAST, eventBody: ["txhex": bytesToHex(bytes: transaction)])
            }
        }
        return
    }
    
    if let paymentSentEvent = event.getValueAsPaymentSent() {
        print("ReactNativeLDK: payment sent")
        sendEvent(eventName: MARKER_PAYMENT_SENT, eventBody: ["payment_preimage": bytesToHex(bytes: paymentSentEvent.getPayment_preimage())])
        return
    }
    
    if let paymentFailedEvent = event.getValueAsPaymentFailed() {
        print("ReactNativeLDK: payment failed")
        sendEvent(eventName: MARKER_PAYMENT_FAILED, eventBody: ["payment_hash": bytesToHex(bytes: paymentFailedEvent.getPayment_hash()), "rejected_by_dest": paymentFailedEvent.getRejected_by_dest() ? "true" : "false"])
        return
    }
    
    if let _ = event.getValueAsPendingHTLCsForwardable() {
        print("ReactNativeLDK: forward HTLC")
        channel_manager?.process_pending_htlc_forwards()
        return
    }
    
    if let paymentReceivedEvent = event.getValueAsPaymentReceived() {
        print("ReactNativeLDK: payment received")
        let _ = channel_manager?.claim_funds(payment_preimage: paymentReceivedEvent.getPayment_preimage())
        sendEvent(eventName: MARKER_PAYMENT_RECEIVED, eventBody: [
            "payment_hash": bytesToHex(bytes: paymentReceivedEvent.getPayment_hash()),
            "payment_secret": bytesToHex(bytes: paymentReceivedEvent.getPayment_secret()),
            "payment_preimage": bytesToHex(bytes: paymentReceivedEvent.getPayment_preimage()),
            "amt": String(paymentReceivedEvent.getAmt()),
        ])
        return
    }
    
    //
    
    if let fundingGenerationReadyEvent = event.getValueAsFundingGenerationReady() {
        print("ReactNativeLDK: funding generation ready")
        let funding_spk = fundingGenerationReadyEvent.getOutput_script()
        if funding_spk.count == 34 && funding_spk[0] == 0 && funding_spk[1] == 32 {
            sendEvent(eventName: MARKER_FUNDING_GENERATION_READY, eventBody: [
                "channel_value_satoshis": String(fundingGenerationReadyEvent.getChannel_value_satoshis()),
                "output_script": bytesToHex(bytes: fundingGenerationReadyEvent.getOutput_script()),
                "temporary_channel_id": bytesToHex(bytes: fundingGenerationReadyEvent.getTemporary_channel_id()),
                "user_channel_id": String(fundingGenerationReadyEvent.getUser_channel_id()),
            ])
            temporary_channel_id = fundingGenerationReadyEvent.getTemporary_channel_id()
        } else {
            print("ReactNativeLDK: funding generation ready: something went wrong " + bytesToHex(bytes: fundingGenerationReadyEvent.getOutput_script()))
        }
        return
    }
}



private func sendEvent(eventName: String, eventBody: [String: String]) {
    ReactEventEmitter.sharedInstance()?.sendEvent(withName: eventName, body: eventBody)
}




private func hexStringToByteArray(_ string: String) -> [UInt8] {
    let length = string.count
    if length & 1 != 0 {
        return []
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



func bytesToHex32Reversed(bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)) -> String
{
    var bytesArray: [UInt8] = []
    bytesArray.append(bytes.0)
    bytesArray.append(bytes.1)
    bytesArray.append(bytes.2)
    bytesArray.append(bytes.3)
    bytesArray.append(bytes.4)
    bytesArray.append(bytes.5)
    bytesArray.append(bytes.6)
    bytesArray.append(bytes.7)
    bytesArray.append(bytes.8)
    bytesArray.append(bytes.9)
    bytesArray.append(bytes.10)
    bytesArray.append(bytes.11)
    bytesArray.append(bytes.12)
    bytesArray.append(bytes.13)
    bytesArray.append(bytes.14)
    bytesArray.append(bytes.15)
    bytesArray.append(bytes.16)
    bytesArray.append(bytes.17)
    bytesArray.append(bytes.18)
    bytesArray.append(bytes.19)
    bytesArray.append(bytes.20)
    bytesArray.append(bytes.21)
    bytesArray.append(bytes.22)
    bytesArray.append(bytes.23)
    bytesArray.append(bytes.24)
    bytesArray.append(bytes.25)
    bytesArray.append(bytes.26)
    bytesArray.append(bytes.27)
    bytesArray.append(bytes.28)
    bytesArray.append(bytes.29)
    bytesArray.append(bytes.30)
    bytesArray.append(bytes.31)
    
    return bytesToHex(bytes: bytesArray.reversed())
}




