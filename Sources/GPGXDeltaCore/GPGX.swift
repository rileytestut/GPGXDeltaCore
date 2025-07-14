//
//  GPGX.swift
//  GPGXDeltaCore
//
//  Created by Riley Testut on 1/21/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import Foundation
import AVFoundation

@preconcurrency import DeltaCore

#if SWIFT_PACKAGE
@_exported import GPGXBridge
@_exported import GPGXSwift
#endif

extension GPGXGameInput: Input
{
    public var type: InputType {
        return .game(.genesis)
    }
}

public struct GPGX: DeltaCoreProtocol, Sendable
{
    public static let core = GPGX()
    
    public var name: String { "Genesis Plus GX" }
    public var identifier: String { "com.rileytestut.GPGXDeltaCore" }
    
    public var gameType: GameType { .genesis }
    public var gameInputType: Input.Type { GPGXGameInput.self }
    public var gameSaveFileExtension: String { "sav" }
    
    public var audioFormat: AVAudioFormat { AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48000, channels: 2, interleaved: true)! }
    public var videoFormat: VideoFormat { VideoFormat(format: .bitmap(.bgra8), dimensions: CGSize(width: 720, height: 576)) }

    public var supportedCheatFormats: Set<CheatFormat> {
        return []
    }
    
    #if SWIFT_PACKAGE
    public var emulatorBridge: EmulatorBridging { GPGXEmulatorBridge.shared as! EmulatorBridging }
    public var resourceBundle: Bundle { Bundle.module }
    #else
    public var emulatorBridge: EmulatorBridging { GPGXEmulatorBridge.shared }
    #endif
    
    private init()
    {
    }
}
