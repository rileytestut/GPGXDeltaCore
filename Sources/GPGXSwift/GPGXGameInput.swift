//
//  GPGXGameInput.swift
//  GPGXDeltaCore
//
//  Created by Riley Testut on 1/27/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import DeltaCore

// Declared in GPGXSwift so we can use it from GPGXBridge.
@objc public enum GPGXGameInput: Int, _Input
{
    case up = 0x01
    case down = 0x02
    case left = 0x04
    case right = 0x08
    
    case a = 0x40
    case b = 0x10
    case c = 0x20
    
    case x = 0x400
    case y = 0x200
    case z = 0x100
    
    case start = 0x080
    case mode = 0x800
}
