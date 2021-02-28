package com.rnldk

import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import org.ldk.batteries.*
import org.ldk.enums.*
import org.ldk.structs.*
import org.ldk.structs.FeeEstimator


class RnLdkModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {

    override fun getName(): String {
        return "RnLdk"
    }

    // Example method
    // See https://reactnative.dev/docs/native-modules-android
    @ReactMethod
    fun multiply(a: Int, b: Int, promise: Promise) {
//      val tt = org.ldk.util.TwoTuple(1, 2);
      val chan_manager = ChannelManager.constructor_new(LDKNetwork.LDKNetwork_Bitcoin, FeeEstimator.new_impl { confirmation_target: LDKConfirmationTarget? -> 0 }, null, null, null, null, UserConfig.constructor_default(), 1)
//      val peer_manager = PeerManager.constructor_new(chan_manager.as_ChannelMessageHandler(), router.as_RoutingMessageHandler(), keys_interface.get_node_secret(), random_data, logger);

//      val nio = NioPeerHandler(peer_manager);

//      nio.connect(hexStringToByteArray("03864ef025fde8fb587d989186ce6a4a186895ee44a926bfc370e2c366597a3f8f"), InetSocketAddress("34.239.230.56", 9735));

      promise.resolve(a * b)

    }


}

/*



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
*/
