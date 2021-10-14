//
//  EventEmitter.m
//  BlueWallet
//
//  Created by Marcos Rodriguez on 12/25/20.
//  Copyright © 2020 BlueWallet. All rights reserved.
//

#import "ReactEventEmitter.h"

static ReactEventEmitter *sharedInstance;

@implementation ReactEventEmitter


RCT_EXPORT_MODULE();

+ (BOOL)requiresMainQueueSetup {
    return YES;
}

+ (ReactEventEmitter *)sharedInstance {
    return sharedInstance;
}

- (instancetype)init {
    sharedInstance = [super init];
    return sharedInstance;
}

- (NSArray<NSString *> *)supportedEvents {
    return @[@"broadcast",@"register_tx",@"log",@"marker_register_output",@"broadcast",@"persist",@"payment_sent",@"payment_failed",@"payment_received",@"persist_manager",@"funding_generation_ready",@"channel_closed"];
}

- (void)sendNotification:(NSDictionary *)userInfo
{
  [sharedInstance sendEventWithName:@"onNotificationReceived" body:userInfo];
}


- (void)openSettings
{
  [sharedInstance sendEventWithName:@"openSettings" body:nil];
}




@end
