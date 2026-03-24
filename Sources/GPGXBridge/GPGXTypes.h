//
//  GPGXTypes.h
//  GPGXDeltaCore
//
//  Created by Riley Testut on 1/27/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

#if SWIFT_PACKAGE
@import CDeltaCore;
#else
#import <DeltaCore/DeltaCore.h>
#endif

// Extensible Enums
FOUNDATION_EXPORT GameType const GameTypeGenesis NS_SWIFT_NAME(genesis);

FOUNDATION_EXPORT CheatType const CheatTypeGameGenie;
FOUNDATION_EXPORT CheatType const CheatTypeActionReplay;
