package com.rnldk

import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
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


val persister = Persist.new_impl(object : PersistInterface {
  override fun persist_new_channel(id: OutPoint,
                                   data: ChannelMonitor): Result_NoneChannelMonitorUpdateErrZ {
    val channel_monitor_bytes = data.write()
    // <insert code to write these bytes to disk, keyed by `id`>
    println("persist_new_channel")
    return Result_NoneChannelMonitorUpdateErrZ.Result_NoneChannelMonitorUpdateErrZ_OK();
  }

  override fun update_persisted_channel(
    id: OutPoint, update: ChannelMonitorUpdate, data: ChannelMonitor): Result_NoneChannelMonitorUpdateErrZ {
    val channel_monitor_bytes = data.write()
    // <insert code to update the `ChannelMonitor`'s file on disk with these
    // new bytes, keyed by `id`>
    println("update_persisted_channel");
    return Result_NoneChannelMonitorUpdateErrZ.Result_NoneChannelMonitorUpdateErrZ_OK();
  }
})


val tx_filter: Filter? = Filter.new_impl(object : FilterInterface {
  override fun register_tx(txid: ByteArray?, script_pubkey: ByteArray?) {
    // <insert code for you to watch for this transaction on-chain>
  }

  override fun register_output(outpoint: OutPoint?, script_pubkey: ByteArray?) {
    // <insert code for you to watch for any transactions that spend this
    // output on-chain>
  }
})





class RnLdkModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {

    override fun getName(): String {
        return "RnLdk"
    }

    // Example method
    // See https://reactnative.dev/docs/native-modules-android
    @ReactMethod
    fun multiply(a: Int, b: Int, promise: Promise) {

      println("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!1");

      val fee_estimator = FeeEstimator.new_impl { confirmation_target: LDKConfirmationTarget? -> 253 }
      val logger = Logger.new_impl { arg: String? -> println(arg) }

      val tx_broadcaster = BroadcasterInterface.new_impl { tx -> }

      val chain_monitor = ChainMonitor.constructor_new(tx_filter, tx_broadcaster, logger, fee_estimator, persister);

      var key_seed = ByteArray(32);
      key_seed = hexStringToByteArray("ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"); // entropy
      val keys_manager = KeysManager.constructor_new(key_seed,
        LDKNetwork.LDKNetwork_Bitcoin, System.currentTimeMillis() / 1000,
        (System.currentTimeMillis() * 1000).toInt())




      val channel_monitors: HashMap<String, ChannelMonitor> = HashMap()

      val monitor_bytes = ByteArray(0);
      val channel_monitor_read_result = UtilMethods.constructor_BlockHashChannelMonitorZ_read(monitor_bytes,
        keys_manager.as_KeysInterface())

      if (channel_monitor_read_result !is Result_C2Tuple_BlockHashChannelMonitorZDecodeErrorZ.Result_C2Tuple_BlockHashChannelMonitorZDecodeErrorZ_OK) {
//        throw Exception("bad channel_monitor_read_result");
      }








      val block_height = 666777
      val channel_manager = ChannelManager.constructor_new(
        LDKNetwork.LDKNetwork_Bitcoin, fee_estimator, chain_monitor.as_Watch(),
        tx_broadcaster, logger, keys_manager.as_KeysInterface(),
        UserConfig.constructor_default(), block_height.toLong());


//      val chain_watch = chain_monitor.as_Watch();
//      chain_watch.watch_channel(channel_monitor.get_funding_txo().a, channel_monitor);

      val router = NetGraphMsgHandler.constructor_new(hexStringToByteArray("ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"), null, logger);

      var random_bytes = ByteArray(32)
      random_bytes = hexStringToByteArray("ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"); // entropy
      println("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!  2");

      val peer_manager = PeerManager.constructor_new(
        channel_manager.as_ChannelMessageHandler(), router.as_RoutingMessageHandler(),
        keys_manager.as_KeysInterface()._node_secret, random_bytes, logger);


      var nio_peer_handler: NioPeerHandler
      try {
        nio_peer_handler = NioPeerHandler(peer_manager)
        val port = 9735;
        nio_peer_handler.bind_listener(InetSocketAddress("0.0.0.0", port));
      } catch (e: IOException) {
        println("io exception");
      }









//      val tt = org.ldk.util.TwoTuple(1, 2);
//      val chan_manager = ChannelManager.constructor_new(LDKNetwork.LDKNetwork_Bitcoin, FeeEstimator.new_impl { confirmation_target: LDKConfirmationTarget? -> 0 }, null, null, null, null, UserConfig.constructor_default(), 1)
//      val peer_manager = PeerManager.constructor_new(chan_manager.as_ChannelMessageHandler(), router.as_RoutingMessageHandler(), keys_interface.get_node_secret(), random_data, logger);

//      val nio = NioPeerHandler(peer_manager);

//      nio.connect(hexStringToByteArray("03864ef025fde8fb587d989186ce6a4a186895ee44a926bfc370e2c366597a3f8f"), InetSocketAddress("34.239.230.56", 9735));

      promise.resolve(666)

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

