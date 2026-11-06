//
//  GPGXEmulatorBridge.h
//  GPGXBridge
//
//  Created by Riley Testut on 1/21/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol DLTAEmulatorBridging;

NS_ASSUME_NONNULL_BEGIN

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything" // Silence "Cannot find protocol definition" warning due to forward declaration.
@interface GPGXEmulatorBridge : NSObject <DLTAEmulatorBridging>
#pragma clang diagnostic pop

@property (class, nonatomic, readonly) GPGXEmulatorBridge *sharedBridge;

@end

// Characters valid in a Genesis Game Genie code (uppercase only).
FOUNDATION_EXPORT NSString *const GPGXGameGenieValidCharacters;

NS_ASSUME_NONNULL_END
