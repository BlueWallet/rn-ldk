package com.rnldk

import com.facebook.react.bridge.*
import com.facebook.react.modules.core.DeviceEventManagerModule.RCTDeviceEventEmitter
import org.json.JSONArray
import org.ldk.batteries.ChannelManagerConstructor
import org.ldk.batteries.ChannelManagerConstructor.EventHandler
import org.ldk.batteries.NioPeerHandler
import org.ldk.enums.ConfirmationTarget
import org.ldk.enums.Currency
import org.ldk.enums.Network
import org.ldk.structs.*
import org.ldk.structs.FeeEstimator
import org.ldk.structs.Filter.FilterInterface
import org.ldk.structs.Persist
import org.ldk.structs.Persist.PersistInterface
import org.ldk.structs.Result_NoneAPIErrorZ.Result_NoneAPIErrorZ_OK
import org.ldk.util.TwoTuple
import java.io.IOException
import java.net.InetSocketAddress


// borrowed from JS:
const val MARKER_LOG = "log";
const val MARKER_REGISTER_OUTPUT = "marker_register_output";
const val MARKER_REGISTER_TX = "register_tx";
const val MARKER_BROADCAST = "broadcast";
const val MARKER_PERSIST = "persist";
const val MARKER_PAYMENT_SENT = "payment_sent";
const val MARKER_PAYMENT_FAILED = "payment_failed";
const val MARKER_PAYMENT_RECEIVED = "payment_received";
const val MARKER_PERSIST_MANAGER = "persist_manager";
const val MARKER_FUNDING_GENERATION_READY = "funding_generation_ready";
//

var feerate_fast = 7500; // estimate fee rate in BTC/kB
var feerate_medium = 7500; // estimate fee rate in BTC/kB
var feerate_slow = 7500; // estimate fee rate in BTC/kB

var refund_address_script = "76a91419129d53e6319baf19dba059bead166df90ab8f588ac";

var nio_peer_handler: NioPeerHandler? = null;
var channel_manager: ChannelManager? = null;
var peer_manager: PeerManager? = null;
var chain_monitor: ChainMonitor? = null;
var temporary_channel_id: ByteArray? = null;
var keys_manager: KeysManager? = null;
var channel_manager_constructor: ChannelManagerConstructor? = null;

class RnLdkModule(private val reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {

  override fun getName(): String {
    return "RnLdk"
  }

  @ReactMethod
  fun getVersion(promise: Promise) {
    promise.resolve(org.ldk.impl.version.get_ldk_java_bindings_version() + ", " + org.ldk.impl.bindings.get_ldk_c_bindings_version() + ", " + org.ldk.impl.bindings.get_ldk_version());
  }

  @ReactMethod
  fun start(entropyHex: String, blockchainTipHeight: Int, blockchainTipHashHex: String, serializedChannelManagerHex: String, monitorHexes: String, promise: Promise) {
    println("ReactNativeLDK: " + "start")
    val that = this;

    // INITIALIZE THE FEEESTIMATOR #################################################################
    // What it's used for: estimating fees for on-chain transactions that LDK wants broadcasted.
    val fee_estimator = FeeEstimator.new_impl { confirmation_target: ConfirmationTarget? ->
      var ret = feerate_fast;
      if (confirmation_target != null) {
        if (confirmation_target.equals(ConfirmationTarget.LDKConfirmationTarget_HighPriority)) ret = feerate_fast;
        if (confirmation_target.equals(ConfirmationTarget.LDKConfirmationTarget_Normal)) ret = feerate_medium;
        if (confirmation_target.equals(ConfirmationTarget.LDKConfirmationTarget_Background)) ret = feerate_slow;
      }
      return@new_impl ret;
    }

    // INITIALIZE THE LOGGER #######################################################################
    // What it's used for: LDK logging
    val logger = Logger.new_impl { arg: String? ->
      println("ReactNativeLDK: " + arg)
      val params = Arguments.createMap()
      params.putString("line", arg)
      that.sendEvent(MARKER_LOG, params)
    }

    // INITIALIZE THE BROADCASTERINTERFACE #########################################################
    // What it's used for: broadcasting various lightning transactions
    val tx_broadcaster = BroadcasterInterface.new_impl { tx ->
      println("ReactNativeLDK: " + "broadcaster sends an event asking to broadcast some txhex...")
      val params = Arguments.createMap()
      params.putString("txhex", byteArrayToHex(tx))
      that.sendEvent(MARKER_BROADCAST, params)
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
        that.sendEvent(MARKER_PERSIST, params);
        return Result_NoneChannelMonitorUpdateErrZ.ok();
      }

      override fun update_persisted_channel(id: OutPoint, update: ChannelMonitorUpdate, data: ChannelMonitor): Result_NoneChannelMonitorUpdateErrZ {
        val channel_monitor_bytes = data.write()
        println("ReactNativeLDK: update_persisted_channel");
        val params = Arguments.createMap()
        params.putString("id", byteArrayToHex(id.to_channel_id()))
        params.putString("data", byteArrayToHex(channel_monitor_bytes))
        that.sendEvent(MARKER_PERSIST, params);
        return Result_NoneChannelMonitorUpdateErrZ.ok();
      }
    })

    // now, initializing channel manager persister that is responsoble for backing up channel_manager bytes

    val channel_manager_persister = object : EventHandler {
      override fun handle_event(event: Event) {
        that.handleEvent(event);
      }

      override fun persist_manager(channel_manager_bytes: ByteArray?) {
        if (channel_manager_bytes != null) {
          val params = Arguments.createMap()
          params.putString("channel_manager_bytes", byteArrayToHex(channel_manager_bytes))
          that.sendEvent(MARKER_PERSIST_MANAGER, params);
        }
      }
    }

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
        that.sendEvent(MARKER_REGISTER_TX, params);
      }

      override fun register_output(output: WatchedOutput): Option_C2Tuple_usizeTransactionZZ {
        println("ReactNativeLDK: register_output");
        val params = Arguments.createMap()
        val blockHash = output._block_hash;
        if (blockHash is ByteArray) {
          params.putString("block_hash", byteArrayToHex(blockHash))
        }
        params.putString("index", output._outpoint._index.toString())
        params.putString("script_pubkey", byteArrayToHex(output._script_pubkey))
        that.sendEvent(MARKER_REGISTER_OUTPUT, params);
        return Option_C2Tuple_usizeTransactionZZ.none();
      }
    })

    val filter = Option_FilterZ.some(tx_filter);
    System.out.println("yo");
    System.out.println(filter);
    chain_monitor = ChainMonitor.of(filter, tx_broadcaster, logger, fee_estimator, persister);

    // INITIALIZE THE KEYSMANAGER ##################################################################
    // What it's used for: providing keys for signing lightning transactions
    keys_manager = KeysManager.of(hexStringToByteArray(entropyHex), System.currentTimeMillis() / 1000, (System.currentTimeMillis() * 1000).toInt())

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


    try {
      if (serializedChannelManagerHex != "") {
        // loading from disk
        channel_manager_constructor = ChannelManagerConstructor(hexStringToByteArray(serializedChannelManagerHex), channelMonitors, keys_manager?.as_KeysInterface(), fee_estimator, chain_monitor, tx_filter, null, tx_broadcaster, logger);
        channel_manager = channel_manager_constructor!!.channel_manager;
        channel_manager_constructor!!.chain_sync_completed(channel_manager_persister);
        peer_manager = channel_manager_constructor!!.peer_manager;
        nio_peer_handler = channel_manager_constructor!!.nio_peer_handler;
      } else {
        // fresh start
        channel_manager_constructor = ChannelManagerConstructor(Network.LDKNetwork_Bitcoin, UserConfig.with_default(), hexStringToByteArray(blockchainTipHashHex), blockchainTipHeight, keys_manager?.as_KeysInterface(), fee_estimator, chain_monitor, null, tx_broadcaster, logger);
        channel_manager = channel_manager_constructor!!.channel_manager;
        channel_manager_constructor!!.chain_sync_completed(channel_manager_persister);
        peer_manager = channel_manager_constructor!!.peer_manager;
        nio_peer_handler = channel_manager_constructor!!.nio_peer_handler;
      }
      promise.resolve("hello ldk");
    } catch (e: Exception) {
      println("ReactNativeLDK: can't start, " + e.message);
      promise.reject(e.message);
    }
  }

  @ReactMethod
  fun transactionConfirmed(headerHex: String, height: Int, txPos: Int, transactionHex: String, promise: Promise) {
    val tx = TwoTuple_usizeTransactionZ.of(txPos.toLong(), hexStringToByteArray(transactionHex))
    val txarray = arrayOf(tx);
    channel_manager?.as_Confirm()?.transactions_confirmed(hexStringToByteArray(headerHex), txarray, height);
    chain_monitor?.as_Confirm()?.transactions_confirmed(hexStringToByteArray(headerHex), txarray, height);

    promise.resolve(true);
  }

  @ReactMethod
  fun transactionUnconfirmed(txidHex: String, promise: Promise) {
    channel_manager?.as_Confirm()?.transaction_unconfirmed(hexStringToByteArray(txidHex));
    chain_monitor?.as_Confirm()?.transaction_unconfirmed(hexStringToByteArray(txidHex));
    promise.resolve(true);
  }

  @ReactMethod
  fun getRelevantTxids(promise: Promise) {
    if (channel_manager === null) {
      promise.reject("Channel manager is not initted");
      return;
    }
    var first = true;
    var json: String = "[";
    channel_manager?.as_Confirm()?._relevant_txids?.iterator()?.forEach {
      if (!first) json += ",";
      first = false;
      json += "\"" + byteArrayToHex(it.reversedArray()) + "\"";
    }
    chain_monitor?.as_Confirm()?._relevant_txids?.iterator()?.forEach {
      if (!first) json += ",";
      first = false;
      json += "\"" + byteArrayToHex(it.reversedArray()) + "\"";
    }
    json += "]";
    promise.resolve(json);
  }

  @ReactMethod
  fun updateBestBlock(headerHex: String, height: Int, promise: Promise) {
    channel_manager?.as_Confirm()?.best_block_updated(hexStringToByteArray(headerHex), height);
    chain_monitor?.as_Confirm()?.best_block_updated(hexStringToByteArray(headerHex), height);
    promise.resolve(true);
  }

  @ReactMethod
  fun connectPeer(pubkeyHex: String, hostname: String, port: Int, promise: Promise) {
    println("ReactNativeLDK: connecting to peer " + pubkeyHex);
    try {
      nio_peer_handler?.connect(hexStringToByteArray(pubkeyHex), InetSocketAddress(hostname, port), 9000);
      promise.resolve(true)
    } catch (e: IOException) {
      promise.reject("connectPeer exception: " + e.message);
    }
  }

  @ReactMethod
  fun disconnectByNodeId(pubkeyHex: String, promise: Promise) {
    println("ReactNativeLDK: disconnecting peer " + pubkeyHex);
    try {
      peer_manager?.disconnect_by_node_id(hexStringToByteArray(pubkeyHex), false);
      promise.resolve(true);
    } catch (e: IOException) {
      promise.reject("disconnect_by_node_id exception: " + e.message);
    }
  }

  @ReactMethod
  fun sendPayment(destPubkeyHex: String, paymentHashHex: String, paymentSecretHex: String, shortChannelId: String, paymentValueMsat: Int, finalCltvValue: Int, LdkRoutesJsonArrayString: String, promise: Promise) {
    println("ReactNativeLDK: destPubkeyHex " + destPubkeyHex);
    println("ReactNativeLDK: paymentHashHex " + paymentHashHex);
    println("ReactNativeLDK: paymentSecretHex " + paymentSecretHex);
    println("ReactNativeLDK: shortChannelId " + shortChannelId);
    println("ReactNativeLDK: shortChannelId LONG " + (shortChannelId.toLong().toString()));
    println("ReactNativeLDK: paymentValueMsat " + paymentValueMsat);
    println("ReactNativeLDK: finalCltvValue " + finalCltvValue);

    // first hop:
    // (also the last one of no route provided - assuming paying to neighbor node)
    var path = arrayOf(
      RouteHop.of(
        hexStringToByteArray(destPubkeyHex),
        NodeFeatures.known(),
        shortChannelId.toLong(),
        ChannelFeatures.known(),
        paymentValueMsat.toLong(),
        finalCltvValue
      )
    );

    if (LdkRoutesJsonArrayString != "") {
      // full route was provided
      path = arrayOf<RouteHop>(); // reset path and start from scratch
      val hopsJson = JSONArray(LdkRoutesJsonArrayString);
      for (c in 1..hopsJson.length()) {
        val hopJson = hopsJson.getJSONObject(c - 1);

        path = path.plusElement(RouteHop.of(
          hexStringToByteArray(hopJson.getString("pubkey")),
          NodeFeatures.known(),
          hopJson.getString("short_channel_id").toLong(),
          ChannelFeatures.known(),
          hopJson.getString("fee_msat").toLong(),
          hopJson.getString("cltv_expiry_delta").toInt()
        ));
      }
    }


    val route = Route.of(
      arrayOf(
        path
      )
    );

    val payment_hash = hexStringToByteArray(paymentHashHex);
    val payment_secret = hexStringToByteArray(paymentSecretHex);
    val payment_res = channel_manager?.send_payment(route, payment_hash, payment_secret);
    if (payment_res is Result_NonePaymentSendFailureZ.Result_NonePaymentSendFailureZ_OK) {
      promise.resolve(true);
    } else {
      promise.reject("sendPayment failed");
    }
  }

  @ReactMethod
  fun addInvoice(amtMsat: Int, description: String, promise: Promise) {
    var amountStruct = Option_u64Z.none();
    if (amtMsat != 0) {
      amountStruct = Option_u64Z.some(amtMsat.toLong());
    }

    val invoice = UtilMethods.create_invoice_from_channelmanager(
      channel_manager,
      keys_manager?.as_KeysInterface(),
      Currency.LDKCurrency_Bitcoin,
      amountStruct,
      description
    );

    if (invoice is Result_InvoiceSignOrCreationErrorZ.Result_InvoiceSignOrCreationErrorZ_OK) {
      println("Got invoice: " + invoice.res.to_str())
      promise.resolve(invoice.res.to_str());
    } else {
      promise.reject("addInvoice failed");
    }
  }

  @ReactMethod
  fun listPeers(promise: Promise) {
    if (peer_manager === null) {
      promise.reject("no peer manager inited");
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

  private fun handleEvent(event: Event) {
    if (event is Event.SpendableOutputs) {
      println("ReactNativeLDK: " + "trying to spend output");
      val txResult = keys_manager?.spend_spendable_outputs(
        event.outputs,
        emptyArray<TxOut>(),
        hexStringToByteArray(refund_address_script),
        feerate_fast
      );

      if (txResult is Result_TransactionNoneZ.Result_TransactionNoneZ_OK) {
        // success building the transaction, passing it to outer code to broadcast
        val params = Arguments.createMap();
        params.putString("txhex", byteArrayToHex(txResult.res))
        this.sendEvent(MARKER_BROADCAST, params)
      }
    }

    if (event is Event.PaymentSent) {
      println("ReactNativeLDK: " + "payment sent, preimage: " + byteArrayToHex((event as Event.PaymentSent).payment_preimage));
      val params = Arguments.createMap();
      params.putString("payment_preimage", byteArrayToHex((event as Event.PaymentSent).payment_preimage));
      this.sendEvent(MARKER_PAYMENT_SENT, params);
    }

    if (event is Event.PaymentPathFailed) {
      println("ReactNativeLDK: " + "payment failed, payment_hash: " + byteArrayToHex(event.payment_hash));
      val params = Arguments.createMap();
      params.putString("payment_hash", byteArrayToHex(event.payment_hash));
      params.putString("rejected_by_dest", event.rejected_by_dest.toString());
      this.sendEvent(MARKER_PAYMENT_FAILED, params);
    }

    if (event is Event.PaymentReceived) {
      println("ReactNativeLDK: " + "payment received, payment_hash: " + byteArrayToHex(event.payment_hash));
      var paymentPreimage: ByteArray? = null;
      var paymentSecret: ByteArray? = null;

      if (event.purpose is PaymentPurpose.InvoicePayment) {
        paymentPreimage = (event.purpose as PaymentPurpose.InvoicePayment).payment_preimage;
        paymentSecret = (event.purpose as PaymentPurpose.InvoicePayment).payment_secret;
        channel_manager?.claim_funds(paymentPreimage);
      } else if (event.purpose is PaymentPurpose.SpontaneousPayment) {
        paymentPreimage = (event.purpose as PaymentPurpose.SpontaneousPayment).spontaneous_payment;
        channel_manager?.claim_funds(paymentPreimage);
      }

      val params = Arguments.createMap();
      params.putString("payment_hash", byteArrayToHex(event.payment_hash));
      if (paymentSecret != null) {
        params.putString("payment_secret", byteArrayToHex(paymentSecret));
      }
      if (paymentPreimage != null) {
        params.putString("payment_preimage", byteArrayToHex(paymentPreimage));
      }
      params.putString("amt", event.amt.toString());
      this.sendEvent(MARKER_PAYMENT_RECEIVED, params);
    }

    if (event is Event.PendingHTLCsForwardable) {
      channel_manager?.process_pending_htlc_forwards();
    }

    if (event is Event.FundingGenerationReady) {
      println("ReactNativeLDK: " + "FundingGenerationReady");
      val funding_spk = event.output_script;
      if (funding_spk.size == 34 && funding_spk[0].toInt() == 0 && funding_spk[1].toInt() == 32) {
        val params = Arguments.createMap();
        params.putString("channel_value_satoshis", event.channel_value_satoshis.toString());
        params.putString("output_script", byteArrayToHex(event.output_script));
        params.putString("temporary_channel_id", byteArrayToHex(event.temporary_channel_id));
        params.putString("user_channel_id", event.user_channel_id.toString());
        temporary_channel_id = event.temporary_channel_id;
        this.sendEvent(MARKER_FUNDING_GENERATION_READY, params);
      }
    }
  }

  @ReactMethod
  fun getNodeId(promise: Promise) {
    val byteArr = channel_manager?._our_node_id;
    if (byteArr != null) {
      promise.resolve(byteArrayToHex(byteArr));
    } else {
      promise.reject("getNodeId failed");
    }
  }

  @ReactMethod
  fun closeChannelCooperatively(channelIdHex: String, promise: Promise) {
    val close_result = channel_manager?.close_channel(hexStringToByteArray(channelIdHex))
    if (close_result is Result_NoneAPIErrorZ_OK) {
      promise.resolve(true);
    } else {
      promise.reject("closeChannelCooperatively failed");
    }
  }

  @ReactMethod
  fun closeChannelForce(channelIdHex: String, promise: Promise) {
    val close_result = channel_manager?.force_close_channel(hexStringToByteArray(channelIdHex));
    if (close_result is Result_NoneAPIErrorZ_OK) {
      promise.resolve(true);
    } else {
      promise.reject("closeChannelForce failed");
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
      promise.reject("openChannelStep1 failed");
      return;
    }

    promise.resolve(true);
  }

  @ReactMethod
  fun openChannelStep2(txhex: String, promise: Promise) {
    if (temporary_channel_id == null) return promise.reject("openChannelStep2 failed: channel opening is not initiated..?");

    val funding_res = channel_manager?.funding_transaction_generated(temporary_channel_id, hexStringToByteArray(txhex));
    // funding_transaction_generated should only generate an error if the
    // transaction didn't meet the required format (or the counterparty already
    // closed the channel on us):
    if (funding_res !is Result_NoneAPIErrorZ_OK) {
      println("ReactNativeLDK: " + "funding_res !is Result_NoneAPIErrorZ_OK");
      promise.reject("openChannelStep2 failed");
      return;
    }

    // At this point LDK will exchange the remaining channel open messages with
    // the counterparty and, when appropriate, broadcast the funding transaction
    // provided.
    // Once it confirms, the channel will be open and available for use (indicated
    // by its presence in `channel_manager.list_usable_channels()`).

    promise.resolve(true);
  }

  @ReactMethod
  fun listUsableChannels(promise: Promise) {
    if (channel_manager == null) {
      promise.reject("Channel manager not inited");
      return;
    }

    val channels = channel_manager?.list_usable_channels();

    var jsonArray = "[";

    var first = true;
    channels?.iterator()?.forEach {
      val channelObject = this.channel2channelObject(it);

      if (!first) jsonArray += ",";
      jsonArray += channelObject;
      first = false;
    }

    jsonArray += "]";


    promise.resolve(jsonArray);
  }

  @ReactMethod
  fun listChannels(promise: Promise) {
    if (channel_manager == null) {
      promise.reject("Channel manager not inited");
      return;
    }
    val channels = channel_manager?.list_channels();
    var jsonArray = "[";
    var first = true;
    channels?.iterator()?.forEach {
      val channelObject = this.channel2channelObject(it);

      if (!first) jsonArray += ",";
      jsonArray += channelObject;
      first = false;
    }
    jsonArray += "]";
    promise.resolve(jsonArray);
  }

  private fun channel2channelObject(it: ChannelDetails): String {
    var short_channel_id: Long = 0;
    if (it._short_channel_id is Option_u64Z.Some) {
      short_channel_id = (it._short_channel_id as Option_u64Z.Some).some
    }

    var confirmations_required = 0;
    if (it._confirmations_required is Option_u32Z.Some) {
      confirmations_required = (it._confirmations_required as Option_u32Z.Some).some;
    }

    var force_close_spend_delay: Short = 0;
    if (it._force_close_spend_delay is Option_u16Z.Some) {
      force_close_spend_delay = (it._force_close_spend_delay as Option_u16Z.Some).some;
    }

    var unspendable_punishment_reserve: Long = 0;
    if (it._unspendable_punishment_reserve is Option_u64Z.Some) {
      unspendable_punishment_reserve = (it._unspendable_punishment_reserve as Option_u64Z.Some).some;
    }

    var channelObject = "{";
    channelObject += "\"channel_id\":" + "\"" + byteArrayToHex(it._channel_id) + "\",";
    channelObject += "\"channel_value_satoshis\":" + it._channel_value_satoshis + ",";
    channelObject += "\"inbound_capacity_msat\":" + it._inbound_capacity_msat + ",";
    channelObject += "\"outbound_capacity_msat\":" + it._outbound_capacity_msat + ",";
    channelObject += "\"short_channel_id\":" + "\"" + short_channel_id + "\",";
    channelObject += "\"is_usable\":" + it._is_usable + ",";
    channelObject += "\"is_funding_locked\":" + it._is_funding_locked + ",";
    channelObject += "\"is_outbound\":" + it._is_outbound + ",";
    channelObject += "\"is_public\":" + it._is_public + ",";
    channelObject += "\"remote_node_id\":" + "\"" + byteArrayToHex(it._counterparty._node_id) + "\","; // @deprecated fixme
    val fundingTxoTxid = it._funding_txo?._txid;
    if (fundingTxoTxid is ByteArray) {
      channelObject += "\"funding_txo_txid\":" + "\"" + byteArrayToHex(fundingTxoTxid) + "\",";
    }
    val fundingTxoIndex = it._funding_txo?._index;
    if (fundingTxoIndex != null) {
      channelObject += "\"funding_txo_index\":" + fundingTxoIndex + ",";
    }
    channelObject += "\"counterparty_unspendable_punishment_reserve\":" + it._counterparty._unspendable_punishment_reserve + ",";
    channelObject += "\"counterparty_node_id\":" + "\"" + byteArrayToHex(it._counterparty._node_id) + "\",";
    channelObject += "\"unspendable_punishment_reserve\":" + unspendable_punishment_reserve + ",";
    channelObject += "\"confirmations_required\":" + confirmations_required + ",";
    channelObject += "\"force_close_spend_delay\":" + force_close_spend_delay + ",";
    channelObject += "\"user_id\":" + it._user_id;
    channelObject += "}";

    return channelObject;
  }

  @ReactMethod
  fun setRefundAddressScript(refundAddressScriptHex: String, promise: Promise) {
    refund_address_script = refundAddressScriptHex;
    promise.resolve(true);
  }

  @ReactMethod
  fun setFeerate(newFeerateFast: Int, newFeerateMedium: Int, newFeerateSlow: Int, promise: Promise) {
    if (newFeerateFast < 300) return promise.reject("newFeerateFast is too small");
    if (newFeerateMedium < 300) return promise.reject("newFeerateMedium is too small");
    if (newFeerateSlow < 300) return promise.reject("newFeerateSlow is too small");
    feerate_fast = newFeerateFast;
    feerate_medium = newFeerateMedium;
    feerate_slow = newFeerateSlow;
    promise.resolve(true);
  }


  @ReactMethod
  fun fireAnEvent(promise: Promise) {
    val params = Arguments.createMap()
    params.putString("line", "test");
    this.sendEvent(MARKER_LOG, params);
    promise.resolve(true);
  }

  @ReactMethod
  fun stop(promise: Promise) {
    println("ReactNativeLDK: stop")
    channel_manager_constructor?.interrupt();

    nio_peer_handler = null;
    channel_manager = null;
    peer_manager = null;
    chain_monitor = null;
    temporary_channel_id = null;
    keys_manager = null;
    channel_manager_constructor = null;

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
