#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(RnLdk, NSObject)

RCT_EXTERN_METHOD(start:(NSString *)entropyHex
                  blockchainTipHeight:(nonnull NSNumber)blockchainTipHeight
                  blockchainTipHashHex:(NSString *)blockchainTipHashHex
                  serializedChannelManagerHex:(NSString *)serializedChannelManagerHex
                  monitorHexes:(NSString *)monitorHexes
                  resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getVersion:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)



@end
