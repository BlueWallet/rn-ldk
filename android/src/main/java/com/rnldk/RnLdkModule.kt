package com.rnldk

import com.facebook.react.bridge.*
import com.facebook.react.modules.core.DeviceEventManagerModule.RCTDeviceEventEmitter
import org.ldk.batteries.NioPeerHandler
import org.ldk.enums.LDKConfirmationTarget
import org.ldk.enums.LDKNetwork
import org.ldk.structs.*
import org.ldk.structs.FeeEstimator
import org.ldk.structs.Filter.FilterInterface
import org.ldk.structs.Persist
import org.ldk.structs.Persist.PersistInterface
import java.io.IOException
import java.net.InetSocketAddress


val feerate = 253; // estimate fee rate in BTC/kB

var nio_peer_handler: NioPeerHandler? = null;

class RnLdkModule(private val reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {

  override fun getName(): String {
    return "RnLdk"
  }

  // Example method
  // See https://reactnative.dev/docs/native-modules-android
  @ReactMethod
  fun multiply(a: Int, b: Int, promise: Promise) {
    promise.resolve(777)
  }

  @ReactMethod
  fun start(entropyHex: String, blockHeight: Int, promise: Promise) {
    println("ReactNativeLDK: " + "start")
    val that = this;


    // INITIALIZE THE FEEESTIMATOR #################################################################
    // What it's used for: estimating fees for on-chain transactions that LDK wants broadcasted.
    val fee_estimator = FeeEstimator.new_impl { confirmation_target: LDKConfirmationTarget? -> feerate }

    // INITIALIZE THE LOGGER #######################################################################
    // What it's used for: LDK logging
    val logger = Logger.new_impl { arg: String? ->
      println("ReactNativeLDK: " + arg)
      val params = Arguments.createMap()
      params.putString("line", arg)
      that.sendEvent("log", params)
    }

    // INITIALIZE THE BROADCASTERINTERFACE #########################################################
    // What it's used for: broadcasting various lightning transactions
    val tx_broadcaster = BroadcasterInterface.new_impl { tx ->
      val params = Arguments.createMap()
      params.putString("txhex", byteArrayToHex(tx))
      that.sendEvent("broadcast", params)
    }

    // INITIALIZE PERSIST ##########################################################################
    // What it's used for: persisting crucial channel data in a timely manner
    val persister = Persist.new_impl(object : PersistInterface {
      override fun persist_new_channel(id: OutPoint, data: ChannelMonitor): Result_NoneChannelMonitorUpdateErrZ {
        val channel_monitor_bytes = data.write()
        println("ReactNativeLDK: persist_new_channel")
        val params = Arguments.createMap()
        params.putString("id", id.toString())
        params.putString("data", byteArrayToHex(channel_monitor_bytes))
        that.sendEvent("persist", params);
        return Result_NoneChannelMonitorUpdateErrZ.Result_NoneChannelMonitorUpdateErrZ_OK();
      }

      override fun update_persisted_channel(id: OutPoint, update: ChannelMonitorUpdate, data: ChannelMonitor): Result_NoneChannelMonitorUpdateErrZ {
        val channel_monitor_bytes = data.write()
        println("ReactNativeLDK: update_persisted_channel");
        val params = Arguments.createMap()
        params.putString("id", id.toString())
        params.putString("data", byteArrayToHex(channel_monitor_bytes))
        that.sendEvent("persist", params);
        return Result_NoneChannelMonitorUpdateErrZ.Result_NoneChannelMonitorUpdateErrZ_OK();
      }
    })

    // INITIALIZE THE CHAINMONITOR #################################################################
    // What it's used for: monitoring the chain for lighting transactions that are relevant to our
    // node, and broadcasting force close transactions if need be

    // Filter allows LDK to let you know what transactions you should filter blocks for. This is
    // useful if you pre-filter blocks or use compact filters. Otherwise, LDK will need full blocks.
    val tx_filter: Filter? = Filter.new_impl(object : FilterInterface {
      override fun register_tx(txid: ByteArray?, script_pubkey: ByteArray?) {
        // <insert code for you to watch for this transaction on-chain>
      }

      override fun register_output(outpoint: OutPoint?, script_pubkey: ByteArray?) {
        // <insert code for you to watch for any transactions that spend this
        // output on-chain>
      }
    })

    val chain_monitor = ChainMonitor.constructor_new(tx_filter, tx_broadcaster, logger, fee_estimator, persister);

    // INITIALIZE THE KEYSMANAGER ##################################################################
    // hat it's used for: providing keys for signing lightning transactions
    val keys_manager = KeysManager.constructor_new(hexStringToByteArray(entropyHex), LDKNetwork.LDKNetwork_Bitcoin, System.currentTimeMillis() / 1000, (System.currentTimeMillis() * 1000).toInt())

    // READ CHANNELMONITOR STATE FROM DISK #########################################################

    // Initialize the hashmap where we'll store the `ChannelMonitor`s read from disk.
    // This hashmap will later be given to the `ChannelManager` on initialization.
    val channel_monitors: HashMap<String, ChannelMonitor> = HashMap()

    val monitor_bytes = ByteArray(0); // TODO
    val channel_monitor_read_result = UtilMethods.constructor_BlockHashChannelMonitorZ_read(monitor_bytes,
      keys_manager.as_KeysInterface())

    if (channel_monitor_read_result !is Result_C2Tuple_BlockHashChannelMonitorZDecodeErrorZ.Result_C2Tuple_BlockHashChannelMonitorZDecodeErrorZ_OK) {
//        throw Exception("bad channel_monitor_read_result");
    }


    // INITIALIZE THE CHANNELMANAGER ###############################################################
    // What it's used for: managing channel state
    val channel_manager = ChannelManager.constructor_new(LDKNetwork.LDKNetwork_Bitcoin, fee_estimator, chain_monitor.as_Watch(), tx_broadcaster, logger, keys_manager.as_KeysInterface(), UserConfig.constructor_default(), blockHeight.toLong());


//      val chain_watch = chain_monitor.as_Watch();
//      chain_watch.watch_channel(channel_monitor.get_funding_txo().a, channel_monitor);


    // INITIALIZE THE NETGRAPHMSGHANDLER ###########################################################
    // What it's used for: generating routes to send payments over
    val router = NetGraphMsgHandler.constructor_new(keys_manager.as_KeysInterface()._secure_random_bytes, null, logger);

    // INITIALIZE THE PEERMANAGER ##################################################################
    // What it's used for: managing peer data
    val peer_manager = PeerManager.constructor_new(channel_manager.as_ChannelMessageHandler(), router.as_RoutingMessageHandler(), keys_manager.as_KeysInterface()._node_secret, keys_manager.as_KeysInterface()._secure_random_bytes, logger);

    try {
      nio_peer_handler = NioPeerHandler(peer_manager)
      nio_peer_handler?.bind_listener(InetSocketAddress("0.0.0.0", 9735));
      promise.resolve(true)
    } catch (e: IOException) {
      println("io exception " + e.message);
      promise.resolve(false)
    }
  }

  @ReactMethod
  fun connectPeer(pubkeyHex: String, hostname: String, port: Int, promise: Promise) {
    try {
//      nio_peer_handler?.connect(hexStringToByteArray("02e89ca9e8da72b33d896bae51d20e7e6675aa971f7557500b6591b15429e717f1"), InetSocketAddress("165.227.95.104", 9735));
      nio_peer_handler?.connect(hexStringToByteArray(pubkeyHex), InetSocketAddress(hostname, port));
      promise.resolve(true)
    } catch (e: IOException) {
      promise.resolve(false)
    }
  }


  @ReactMethod
  fun fireAnEvent(promise: Promise) {
    val params = Arguments.createMap()
    params.putString("eventProperty", "someValue")
    sendEvent("EventReminder", params);
  }

  private fun sendEvent(eventName: String, params: WritableMap) {
    this.reactContext.getJSModule(RCTDeviceEventEmitter::class.java).emit(eventName, params)
  }
}


fun hexStringToByteArray(strArg: String): ByteArray {
  val HEX_CHARS = "0123456789ABCDEF"
  val str = strArg.toUpperCase();

  if (str.length % 2 != 0) return hexStringToByteArray("");

  val result = ByteArray(str.length / 2)

  for (i in 0 until str.length step 2) {
    val firstIndex = HEX_CHARS.indexOf(str[i]);
    val secondIndex = HEX_CHARS.indexOf(str[i + 1]);

    val octet = firstIndex.shl(4).or(secondIndex)
    result.set(i.shr(1), octet.toByte())
  }

  return result
}


fun byteArrayToHex(bytesArg: ByteArray): String {
  return bytesArg.joinToString("") { String.format("%02X", (it.toInt() and 0xFF)) }.toLowerCase()
}
