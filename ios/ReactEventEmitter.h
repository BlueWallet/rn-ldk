//
//  EventEmitter.h
//  BlueWallet
//
//  Created by Marcos Rodriguez on 12/25/20.
//  Copyright © 2020 BlueWallet. All rights reserved.
//

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface ReactEventEmitter : RCTEventEmitter <RCTBridgeModule>

+ (ReactEventEmitter *)sharedInstance;
- (void)sendNotification:(NSDictionary *)userInfo;
- (void)openSettings;

@end
