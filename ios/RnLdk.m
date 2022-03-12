#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(RnLdk, NSObject)

RCT_EXTERN_METHOD(start:(NSString *)entropyHex
                  blockchainTipHeight:(nonnull NSNumber)blockchainTipHeight
                  blockchainTipHashHex:(NSString *)blockchainTipHashHex
                  serializedChannelManagerHex:(NSString *)serializedChannelManagerHex
                  monitorHexes:(NSString *)monitorHexes
                  writablePath:(NSString *)writablePath
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getVersion:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getRelevantTxids:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(transactionUnconfirmed:(NSString *)txidHex
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(transactionConfirmed:(NSString *)headerHex
                  height:(nonnull NSNumber)height
                  txPos:(nonnull NSNumber)txPos
                  transactionHex:(NSString *)transactionHex
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)


RCT_EXTERN_METHOD(updateBestBlock:(NSString *)headerHex
                  height:(nonnull NSNumber)height
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(connectPeer:(NSString *)pubkeyHex
                  hostname:(NSString *)hostname
                  port:(nonnull NSNumber)port
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(disconnectByNodeId:(NSString *)pubkeyHex
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)


RCT_EXTERN_METHOD(sendPayment:(NSString *)destPubkeyHex
                  paymentHashHex:(NSString *)paymentHashHex
                  paymentSecretHex:(NSString *)paymentSecretHex
                  shortChannelId:(NSString *)shortChannelId
                  paymentValueMsat:(nonnull NSNumber)paymentValueMsat
                  finalCltvValue:(nonnull NSNumber)finalCltvValue
                  LdkRoutesJsonArrayString:(NSString *)LdkRoutesJsonArrayString
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(addInvoice:(nonnull NSNumber)amtMsat
                  description:(NSString *)description
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(listPeers:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)


RCT_EXTERN_METHOD(getNodeId:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)


RCT_EXTERN_METHOD(closeChannelCooperatively:(NSString *)channelIdHex
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(closeChannelForce:(NSString *)channelIdHex
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(openChannelStep1:(NSString *)pubkey
                  channelValue:(nonnull NSNumber)channelValue
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)


RCT_EXTERN_METHOD(setRefundAddressScript:(NSString *)refundAddressScriptHex
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(openChannelStep2:(NSString *)txhex
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(payInvoice:(NSString *)bolt11
                  (nonnull NSNumber)amtSat
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(listUsableChannels:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)


RCT_EXTERN_METHOD(listChannels:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)


RCT_EXTERN_METHOD(setFeerate:(nonnull NSNumber)newFeerateFast
                  newFeerateMedium:(nonnull NSNumber)newFeerateMedium
                  newFeerateSlow:(nonnull NSNumber)newFeerateSlow
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)


RCT_EXTERN_METHOD(fireAnEvent:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(stop:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getMaturingBalance:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getMaturingHeight:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(saveNetworkGraph:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)

@end
