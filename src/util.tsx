function sum(arr: number[]): number {
  // Function to calculate the sum of an array of numbers
  return arr.reduce((acc, val) => acc + val, 0);
}

class Util {
  static lndRoutetoLdkRoute(
    lndRoute: any,
    hopFees: any,
    firstChanId: string,
    minFinalCLTVExpiryFromTheInvoice: number
  ): any[] { // Adjust the return type accordingly
    const craftedRoute: any[] = [];
    const fees: number[] = [];

    for (let c = lndRoute.routes[0].hops.length - 1; c >= 0; c--) {
      const lndHop = lndRoute.routes[0].hops[c];
      const hop: any = {};

      // Setting up cltv_expiry_delta and fee_msat based on the hop
      if (c === lndRoute.routes[0].hops.length - 1) {
        hop.cltv_expiry_delta = minFinalCLTVExpiryFromTheInvoice;
        hop.fee_msat = parseInt(lndHop.amt_to_forward_msat, 10);
      } else {
        hop.fee_msat = parseInt(lndHop.fee_msat, 10);
        hop.cltv_expiry_delta = c > 0 ? lndRoute.routes[0].hops[c - 1].expiry - lndHop.expiry : 666;
        if (c === 0) hop.cltv_expiry_delta = lndRoute.routes[0].total_time_lock - lndHop.expiry;
      }

      hop.short_channel_id = lndHop.chan_id;
      hop.pubkey = lndHop.pub_key;

      fees.push(hop.fee_msat);
      craftedRoute.push(hop);
    }

    // Crafting the very first hop
    const firstCraftedHop: any = {};
    const nodePolicy = lndRoute.routes[0].hops[0].pub_key === hopFees.node2_pub ? hopFees.node1_policy : hopFees.node2_policy;

    firstCraftedHop.pubkey = lndRoute.routes[0].hops[0].pub_key === hopFees.node2_pub ? hopFees.node1_pub : hopFees.node2_pub;
    firstCraftedHop.short_channel_id = firstChanId;
    firstCraftedHop.fee_msat = Math.floor((sum(fees) * parseInt(nodePolicy.fee_rate_milli_msat, 10)) / 1000000) + parseInt(nodePolicy.fee_base_msat, 10);
    firstCraftedHop.cltv_expiry_delta = nodePolicy.time_lock_delta;

    craftedRoute.push(firstCraftedHop);

    return craftedRoute.reverse();
  }
}

export default Util;
