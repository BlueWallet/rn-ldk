package com.rnldk

import com.facebook.react.bridge.*
import com.facebook.react.modules.core.DeviceEventManagerModule.RCTDeviceEventEmitter
import org.ldk.batteries.ChannelManagerConstructor
import org.ldk.batteries.NioPeerHandler
import org.ldk.enums.LDKConfirmationTarget
import org.ldk.enums.LDKNetwork
import org.ldk.structs.*
import org.ldk.structs.FeeEstimator
import org.ldk.structs.Filter.FilterInterface
import org.ldk.structs.Persist
import org.ldk.structs.Persist.PersistInterface
import org.ldk.structs.Result_NoneAPIErrorZ.Result_NoneAPIErrorZ_OK
import org.ldk.util.TwoTuple
import java.io.IOException
import java.net.InetSocketAddress


val feerate = 7500; // estimate fee rate in BTC/kB

var nio_peer_handler: NioPeerHandler? = null;
var channel_manager: ChannelManager? = null;
var peer_manager: PeerManager? = null;
var chain_monitor: ChainMonitor? = null;
var temporary_channel_id: ByteArray? = null;

class RnLdkModule(private val reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {

  override fun getName(): String {
    return "RnLdk"
  }

  @ReactMethod
  fun getVersion(promise: Promise) {
    promise.resolve("0.0.8")
  }

  @ReactMethod
  fun start(entropyHex: String, blockchainTipHeight: Int, blockchainTipHashHex: String, serializedChannelManagerHex: String, monitorHexes: String, promise: Promise) {
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
      println("ReactNativeLDK: " + "broadcaster sends an event asking to broadcast some txhex...")
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
        params.putString("id", byteArrayToHex(id.to_channel_id()))
        params.putString("data", byteArrayToHex(channel_monitor_bytes))
        that.sendEvent("persist", params);
        return Result_NoneChannelMonitorUpdateErrZ.Result_NoneChannelMonitorUpdateErrZ_OK();
      }

      override fun update_persisted_channel(id: OutPoint, update: ChannelMonitorUpdate, data: ChannelMonitor): Result_NoneChannelMonitorUpdateErrZ {
        val channel_monitor_bytes = data.write()
        println("ReactNativeLDK: update_persisted_channel");
        val params = Arguments.createMap()
        params.putString("id", byteArrayToHex(id.to_channel_id()))
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
      override fun register_tx(txid: ByteArray, script_pubkey: ByteArray) {
        println("ReactNativeLDK: register_tx");
        val params = Arguments.createMap()
        params.putString("txid", byteArrayToHex(txid))
        params.putString("script_pubkey", byteArrayToHex(script_pubkey))
        that.sendEvent("register_tx", params);
      }

      override fun register_output(outpoint: OutPoint, script_pubkey: ByteArray) {
        println("ReactNativeLDK: register_output");
        val params = Arguments.createMap()
        params.putString("txid", byteArrayToHex(outpoint._txid))
        params.putString("index", outpoint._index.toString())
        params.putString("script_pubkey", byteArrayToHex(script_pubkey))
        that.sendEvent("register_output", params);
      }
    })

    chain_monitor = ChainMonitor.constructor_new(tx_filter, tx_broadcaster, logger, fee_estimator, persister);

    // INITIALIZE THE KEYSMANAGER ##################################################################
    // What it's used for: providing keys for signing lightning transactions
    val keys_manager = KeysManager.constructor_new(hexStringToByteArray(entropyHex), System.currentTimeMillis() / 1000, (System.currentTimeMillis() * 1000).toInt())

    // READ CHANNELMONITOR STATE FROM DISK #########################################################

    // Initialize the hashmap where we'll store the `ChannelMonitor`s read from disk.
    // This hashmap will later be given to the `ChannelManager` on initialization.


    var channelMonitors = arrayOf<ByteArray>();
    if (monitorHexes != "") {
      println("ReactNativeLDK: initing channel monitors...");
      val channelMonitorHexes = monitorHexes.split(",").toTypedArray();
      val channel_monitor_list = ArrayList<ByteArray>()
      channelMonitorHexes.iterator().forEach {
        val channel_monitor_bytes = hexStringToByteArray(it);
        channel_monitor_list.add(channel_monitor_bytes);
      }
      channelMonitors = channel_monitor_list.toTypedArray();
    }

    // INITIALIZE THE CHANNELMANAGER ###############################################################
    // What it's used for: managing channel state


    if (serializedChannelManagerHex != "") {
      // loading from disk
      val channel_manager_constructor = ChannelManagerConstructor(hexStringToByteArray(serializedChannelManagerHex), channelMonitors, keys_manager.as_KeysInterface(), fee_estimator, chain_monitor?.as_Watch(), tx_filter, tx_broadcaster, logger);
      channel_manager = channel_manager_constructor.channel_manager;
      channel_manager_constructor.chain_sync_completed();
    } else {
      // fresh start
      val channel_manager_constructor = ChannelManagerConstructor(LDKNetwork.LDKNetwork_Bitcoin, UserConfig.constructor_default(), hexStringToByteArray(blockchainTipHashHex), blockchainTipHeight, keys_manager.as_KeysInterface(), fee_estimator, chain_monitor?.as_Watch(), tx_broadcaster, logger);
      channel_manager = channel_manager_constructor.channel_manager;
      channel_manager_constructor.chain_sync_completed();
    }


//      val chain_watch = chain_monitor.as_Watch();
//      chain_watch.watch_channel(channel_monitor.get_funding_txo().a, channel_monitor);


    // INITIALIZE THE NETGRAPHMSGHANDLER ###########################################################
    // What it's used for: generating routes to send payments over
    val router = NetGraphMsgHandler.constructor_new(keys_manager.as_KeysInterface()._secure_random_bytes, null, logger);

    // INITIALIZE THE PEERMANAGER ##################################################################
    // What it's used for: managing peer data
    peer_manager = PeerManager.constructor_new(channel_manager?.as_ChannelMessageHandler(), router.as_RoutingMessageHandler(), keys_manager.as_KeysInterface()._node_secret, keys_manager.as_KeysInterface()._secure_random_bytes, logger);

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
  fun transactionConfirmed(headerHex: String, height: Int, txPos: Int, transactionHex: String, promise: Promise) {
    val tx = TwoTuple(txPos.toLong(), hexStringToByteArray(transactionHex));
    val txarray = arrayOf(tx);
    channel_manager?.transactions_confirmed(hexStringToByteArray(headerHex), height, txarray);
    promise.resolve(true);
  }

  @ReactMethod
  fun transactionUnconfirmed(txidHex: String, promise: Promise) {
    channel_manager?.transaction_unconfirmed(hexStringToByteArray(txidHex));
    promise.resolve(true);
  }

  @ReactMethod
  fun getRelevantTxids(promise: Promise) {
    if (channel_manager === null) {
      promise.resolve("[]");
      return;
    }
    var first = true;
    var json: String = "[";
    channel_manager?._relevant_txids?.iterator()?.forEach {
      if (!first) json += ",";
      first = false;
      json += "\"" + byteArrayToHex(it.reversedArray()) + "\"";
    }
    json += "]";
    promise.resolve(json);
  }

  @ReactMethod
  fun updateBestBlock(headerHex: String, height: Int, promise: Promise) {
    channel_manager?.update_best_block(hexStringToByteArray(headerHex), height);
    promise.resolve(true);
  }

  @ReactMethod
  fun connectPeer(pubkeyHex: String, hostname: String, port: Int, promise: Promise) {
    println("ReactNativeLDK: connecting to peer " + pubkeyHex);
    try {
//      nio_peer_handler?.connect(hexStringToByteArray("02e89ca9e8da72b33d896bae51d20e7e6675aa971f7557500b6591b15429e717f1"), InetSocketAddress("165.227.95.104", 9735));
      nio_peer_handler?.connect(hexStringToByteArray(pubkeyHex), InetSocketAddress(hostname, port), 9000);
      promise.resolve(true)
    } catch (e: IOException) {
      promise.resolve(false)
    }
  }

  @ReactMethod
  fun sendPayment(destPubkeyHex: String, paymentHashHex: String, paymentSecretHex: String, shortChannelId: String, paymentValueMsat: Int, finalCltvValue: Int, promise: Promise) {
    val counterparty_pubkey = hexStringToByteArray(destPubkeyHex);
    val r = Route.constructor_new(
      arrayOf(
        arrayOf(
          RouteHop.constructor_new(
            counterparty_pubkey,
            NodeFeatures.constructor_known(),
            744031822077165568, //  fixme: shortChannelId,
            ChannelFeatures.constructor_known(),
            paymentValueMsat.toLong(),
            finalCltvValue
          )
        )
      )
    );
    val payment_hash = hexStringToByteArray(paymentHashHex);
    val payment_secret = hexStringToByteArray(paymentSecretHex);
    val payment_res = channel_manager?.send_payment(r, payment_hash, payment_secret);
    if (payment_res is Result_NonePaymentSendFailureZ.Result_NonePaymentSendFailureZ_OK) {
      promise.resolve(true);
    } else {
      promise.resolve(false);
    }
  }

  @ReactMethod
  fun listPeers(promise: Promise) {
    if (peer_manager === null) {
      promise.resolve("[]");
      return;
    }
    val peer_node_ids: Array<ByteArray> = peer_manager!!.get_peer_node_ids()
    var json: String = "[";
    var first = true;
    peer_node_ids.iterator().forEach {
      if (!first) json += ",";
      first = false;
      json += "\"" + byteArrayToHex(it) + "\"";
    }
    json += "]";
    promise.resolve(json);
  }

  @ReactMethod
  fun handleEvents(promise: Promise) {
    val channel_manager_events: Array<Event> = channel_manager!!.as_EventsProvider().get_and_clear_pending_events()
    //    val chain_monitor_events: Array<Event> = chain_watch.as_EventsProvider().get_and_clear_pending_events()

    val all_events: Array<Event> = channel_manager_events
    for (e in all_events) {
      // <insert code to handle each event>
    }

    promise.resolve(true);
  }

  @ReactMethod
  fun timerChanFreshness(promise: Promise) {
    channel_manager?.timer_chan_freshness_every_min();
    promise.resolve(true);
  }

  @ReactMethod
  fun getChannelManagerBytes(promise: Promise) {
    val channel_manager_bytes_to_write = channel_manager?.write()
    if (channel_manager_bytes_to_write !== null) {
      promise.resolve(byteArrayToHex(channel_manager_bytes_to_write));
    } else {
      promise.resolve("");
    }
  }

  @ReactMethod
  fun openChannelStep1(pubkey: String, channelValue: Int, promise: Promise) {
    temporary_channel_id = null;
    val peer_node_pubkey = hexStringToByteArray(pubkey);
    val create_channel_result = channel_manager?.create_channel(
      peer_node_pubkey, channelValue.toLong(), 0, 42, null
    );

    if (create_channel_result !is Result_NoneAPIErrorZ.Result_NoneAPIErrorZ_OK) {
      println("ReactNativeLDK: " + "create_channel_result !is Result_NoneAPIErrorZ.Result_NoneAPIErrorZ_OK, = " + create_channel_result);
      promise.resolve(false);
      return;
    }

    var events: Array<Event>?;
    var counter = 0;
    do {
      Thread.sleep(500L);
      nio_peer_handler?.check_events();
      events = channel_manager?.as_EventsProvider()?.get_and_clear_pending_events()
      if (events?.size != 1) {
        println("ReactNativeLDK: " + "event 33 not yet arrived = " + events?.size);
      }
      if (counter++ >= 30) {
        println("ReactNativeLDK: " + "waiting for event 33 timeout");
        promise.resolve(false);
        return;
      }
    } while (events?.size != 1);

    if (events[0] !is Event.FundingGenerationReady) {
      println("ReactNativeLDK: " + "events[0] !is Event.FundingGenerationReady, = " + events[0]);
      promise.resolve(false);
      return;
    }
    if ((events[0] as Event.FundingGenerationReady).channel_value_satoshis != channelValue.toLong()) {
      println("ReactNativeLDK: " + "channel value = " + (events[0] as Event.FundingGenerationReady).channel_value_satoshis);
      promise.resolve(false);
      return;
    }
    if ((events[0] as Event.FundingGenerationReady).user_channel_id.toInt() != 42) {
      println("ReactNativeLDK: " + "user_id = " + (events[0] as Event.FundingGenerationReady).user_channel_id.toInt());
      promise.resolve(false);
      return;
    }
    val funding_spk = (events[0] as Event.FundingGenerationReady).output_script
    if (!(funding_spk.size == 34 && funding_spk[0].toInt() == 0 && funding_spk[1].toInt() == 32)) {
      println("ReactNativeLDK: " + "funding_spk = " + byteArrayToHex(funding_spk));
      promise.resolve(false);
      return;
    }

    temporary_channel_id = (events[0] as Event.FundingGenerationReady).temporary_channel_id
    println("ReactNativeLDK: " + "temporary_channel_id = " + byteArrayToHex(temporary_channel_id!!));
    println("ReactNativeLDK: " + "funding script = " + byteArrayToHex(funding_spk!!));

    promise.resolve(byteArrayToHex(funding_spk));
  }

  @ReactMethod
  fun openChannelStep2(txhex: String, promise: Promise) {
    if (temporary_channel_id == null) return promise.resolve(false);

    val funding_res = channel_manager?.funding_transaction_generated(temporary_channel_id, hexStringToByteArray(txhex), 0);
    // funding_transaction_generated should only generate an error if the
    // transaction didn't meet the required format (or the counterparty already
    // closed the channel on us):
    if (funding_res !is Result_NoneAPIErrorZ_OK) {
      println("ReactNativeLDK: " + "funding_res !is Result_NoneAPIErrorZ_OK");
      promise.resolve(false);
      return;
    }

    // Ensure we immediately send a `funding_created` message to the counterparty.
    nio_peer_handler?.check_events()

    // At this point LDK will exchange the remaining channel open messages with
    // the counterparty and, when appropriate, broadcast the funding transaction
    // provided.
    // Once it confirms, the channel will be open and available for use (indicated
    // by its presence in `channel_manager.list_usable_channels()`).

    promise.resolve(true);
  }

  @ReactMethod
  fun listUsableChannels(promise: Promise) {
    val channels = channel_manager?.list_usable_channels();

    var jsonArray = "[";

    var first = true;
    channels?.iterator()?.forEach {
      var channelObject = "{";
      channelObject += "\"channel_id\":" + "\"" + byteArrayToHex(it._channel_id) + "\",";
      channelObject += "\"channel_value_satoshis\":" + it._channel_value_satoshis + ",";
      channelObject += "\"inbound_capacity_msat\":" + it._inbound_capacity_msat + ",";
      channelObject += "\"outbound_capacity_msat\":" + it._outbound_capacity_msat + ",";
      channelObject += "\"is_live\":" + it._is_live + ",";
      channelObject += "\"remote_network_id\":" + "\"" + byteArrayToHex(it._remote_network_id) + "\",";
      channelObject += "\"user_id\":" + it._user_id;
      channelObject += "}";

      if (!first) jsonArray += ",";
      jsonArray += channelObject;
    }

    jsonArray += "]";


    promise.resolve(jsonArray);
  }


  @ReactMethod
  fun fireAnEvent(promise: Promise) {
//    val params = Arguments.createMap()
//    params.putString("eventProperty", "someValue")
//    sendEvent("EventReminder", params);
    println("ReactNativeLDK: " + "broadcaster sends an event asking to broadcast some txhex...")
    val params = Arguments.createMap();
    params.putString("txhex", "ffff");
    this.sendEvent("broadcast", params);
    promise.resolve(true);
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
