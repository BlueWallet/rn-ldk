function sum(arr: number[]) {
  let ret = 0;
  for (const num of arr) ret += num;
  return ret;
}

class Util {
  static lndRoutetoLdkRoute(lndRoute: any, hopFees: any, firstChanId: string, currentblockHeight: number) {
    const ret = [];
    let firstIteration = true;
    let fees: number[] = []; // aggregating fees of LND hops

    // iterating hops provided by LND's queryroutes
    for (let c = lndRoute.routes[0].hops.length - 1; c >= 0; c--) {
      let hop: any = {};
      const lndHop = lndRoute.routes[0].hops[c];

      if (firstIteration) {
        // last hop is a bit special
        hop.cltv_expiry_delta = lndRoute.routes[0].total_time_lock - currentblockHeight;
        hop.fee_msat = parseInt(lndRoute.routes[0].hops[c].amt_to_forward_msat, 10);
      } else {
        hop.fee_msat = parseInt(lndRoute.routes[0].hops[c].fee_msat, 10);
        if (c >= 0 && c < lndRoute.routes[0].hops.length - 2) {
          // intermediate hops have expiry as a difference between neighbor hops
          hop.cltv_expiry_delta = lndRoute.routes[0].hops[c + 1].expiry - lndRoute.routes[0].hops[c].expiry;
        } else {
          hop.cltv_expiry_delta = lndRoute.routes[0].total_time_lock - lndHop.expiry;
        }
      }

      hop.short_channel_id = lndHop.chan_id;
      hop.pubkey = lndHop.pub_key;

      fees.push(hop.fee_msat);
      firstIteration = false;
      ret.push(hop);
    }

    // now, crafting the very first hop out of provided chaninfo
    const firstCraftedHop: any = {};

    let nodePolicy;
    let nodePubkey;
    if (lndRoute.routes[0].hops[0].pub_key === hopFees.node2_pub) {
      nodePolicy = hopFees.node1_policy;
      nodePubkey = hopFees.node1_pub;
    } else {
      nodePolicy = hopFees.node2_policy;
      nodePubkey = hopFees.node2_pub;
    }
    firstCraftedHop.pubkey = nodePubkey;
    firstCraftedHop.short_channel_id = firstChanId;
    firstCraftedHop.fee_msat = Math.floor((sum(fees) * parseInt(nodePolicy.fee_rate_milli_msat, 10)) / 1000000) + parseInt(nodePolicy.fee_base_msat, 10);
    firstCraftedHop.cltv_expiry_delta = nodePolicy.time_lock_delta;

    ret.push(firstCraftedHop);
    return ret.reverse();
  }
}

export default Util;
