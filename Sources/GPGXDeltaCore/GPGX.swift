//
//  GPGX.swift
//  GPGXDeltaCore
//
//  Created by Riley Testut on 1/21/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import Foundation
import AVFoundation

import DeltaCore
@_exported import GPGXBridge
@_exported import GPGXSwift

extension GPGXGameInput: Input
{
    public var type: InputType {
        return .game(.genesis)
    }
}

public struct GPGX: DeltaCoreProtocol
{
    public static let core = GPGX()
    
    public var name: String { "Genesis Plus GX" }
    public var identifier: String { "com.rileytestut.GPGXDeltaCore" }
    
    public var gameType: GameType { .genesis }
    public var gameInputType: Input.Type { GPGXGameInput.self }
    public var gameSaveFileExtension: String { "sav" }
    
    public let audioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48000, channels: 2, interleaved: true)!
    public let videoFormat = VideoFormat(format: .bitmap(.bgra8), dimensions: CGSize(width: 720, height: 576))

    public var supportedCheatFormats: Set<CheatFormat> {
        return []
    }

    public var emulatorBridge: EmulatorBridging { GPGXEmulatorBridge.shared as! EmulatorBridging }
    
    public var resourceBundle: Bundle { Bundle.module }
    
    private init()
    {
    }
}
