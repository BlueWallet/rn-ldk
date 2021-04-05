const assert = require('assert');
import utils from '../util';

it('can construct 3 hops single (non-mpp) route', () => {
  const currentblockHeight = 677883;

  const lndRoute = {
    routes: [
      {
        hops: [
          {
            custom_records: {},
            chan_id: '734240670981095424',
            chan_capacity: '16777215',
            amt_to_forward: '10',
            fee: '1',
            expiry: 677923,
            amt_to_forward_msat: '10000',
            fee_msat: '1005',
            pub_key: '03864ef025fde8fb587d989186ce6a4a186895ee44a926bfc370e2c366597a3f8f',
            tlv_payload: true,
            mpp_record: null,
          },
          {
            custom_records: {},
            chan_id: '697176133925208065',
            chan_capacity: '50000000',
            amt_to_forward: '10',
            fee: '0',
            expiry: 677923,
            amt_to_forward_msat: '10000',
            fee_msat: '0',
            pub_key: '037cc5f9f1da20ac0d60e83989729a204a33cc2d8e80438969fadf35c1c5f1233b',
            tlv_payload: true,
            mpp_record: null,
          },
        ],
        total_time_lock: 678067,
        total_fees: '1',
        total_amt: '11',
        total_fees_msat: '1005',
        total_amt_msat: '11005',
      },
    ],
    success_prob: 0.052672253383759804,
  };
  const hopFees = {
    channel_id: '734240670981095424',
    chan_point: '7e4eb5abc3f41d02d7810fd4451ce796392d51de78bc89de847f680112c362ae:0',
    last_update: 1617614218,
    node1_pub: '02e89ca9e8da72b33d896bae51d20e7e6675aa971f7557500b6591b15429e717f1', // node connected to LDK
    node2_pub: '03864ef025fde8fb587d989186ce6a4a186895ee44a926bfc370e2c366597a3f8f',
    capacity: '16777215',
    node1_policy: { time_lock_delta: 40, min_htlc: '1000', fee_base_msat: '1000', fee_rate_milli_msat: '1', disabled: false, max_htlc_msat: '16777215000', last_update: 1617614218 },
    node2_policy: { time_lock_delta: 144, min_htlc: '1', fee_base_msat: '1000', fee_rate_milli_msat: '100', disabled: false, max_htlc_msat: '16777215000', last_update: 1616406311 },
  };

  const firstChanId = '744894938589888512';

  const expectedHops = [
    {
      pubkey: hopFees.node1_pub,
      short_channel_id: firstChanId,
      fee_msat: Math.floor(((10000 + 1005) * parseInt(hopFees.node1_policy.fee_rate_milli_msat, 10)) / 1000000) + parseInt(hopFees.node1_policy.fee_base_msat, 10),
      cltv_expiry_delta: hopFees.node1_policy.time_lock_delta, // node1_policy.time_lock_delta
    },
    {
      pubkey: '03864ef025fde8fb587d989186ce6a4a186895ee44a926bfc370e2c366597a3f8f',
      short_channel_id: '734240670981095424',
      fee_msat: 1005, // lnd's first hop fee_msat
      cltv_expiry_delta: lndRoute.routes[0].total_time_lock - 677923, // route.total_time_lock - expiry from second to last hop
    },
    {
      pubkey: '037cc5f9f1da20ac0d60e83989729a204a33cc2d8e80438969fadf35c1c5f1233b',
      short_channel_id: '697176133925208065',
      fee_msat: 10000, // lasthop.amt_to_forward_msat
      cltv_expiry_delta: lndRoute.routes[0].total_time_lock - currentblockHeight, // route.total_time_lock - currentblockHeight
    },
  ];

  assert.deepEqual(utils.lndRoutetoLdkRoute(lndRoute, hopFees, firstChanId, currentblockHeight), expectedHops);
});
