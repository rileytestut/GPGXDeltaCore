//
//  GPGXEmulatorBridge.h
//  GPGXBridge
//
//  Created by Riley Testut on 1/21/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

#import "GPGXEmulatorBridge.h"

@import Foundation;

@import DeltaCore;
@import GenesisPlusGX;

CGFloat GPGXVideoWidth = 720;
CGFloat GPGXVideoHeight = 576;

CGFloat GPGXFramesPerSecondPAL = 53203424.0 / (3420.0 * 313.0);
CGFloat GPGXFramesPerSecondNTSC = 53693175.0 / (3420.0 * 262.0);

int GPGXGameSaveSize = 0x10000;

@interface GPGXEmulatorBridge ()

@property (nonatomic, copy, nullable, readwrite) NSURL *gameURL;

@property (nonatomic, readonly) NSMutableData *audioBuffer;
@property (nonatomic, readonly) NSMutableData *videoBuffer;

@end

@implementation GPGXEmulatorBridge
@synthesize audioRenderer = _audioRenderer;
@synthesize videoRenderer = _videoRenderer;
@synthesize saveUpdateHandler = _saveUpdateHandler;

+ (instancetype)sharedBridge
{
    static GPGXEmulatorBridge *_emulatorBridge = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _emulatorBridge = [[self alloc] init];
    });
    
    return _emulatorBridge;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _audioBuffer = [[NSMutableData alloc] initWithLength:2048 * 2 * sizeof(int16_t)];
        _videoBuffer = [[NSMutableData alloc] initWithLength:GPGXVideoWidth * GPGXVideoHeight * sizeof(uint32_t)];
    }
    
    return self;
}

#pragma mark - Emulation State -

- (void)startWithGameURL:(NSURL *)gameURL
{
    set_config_defaults();
    
    /* initialize bitmap */
    memset(&bitmap, 0, sizeof(bitmap));
    bitmap.width      = GPGXVideoWidth;
    bitmap.height     = GPGXVideoHeight;
    bitmap.pitch      = bitmap.width * sizeof(uint32_t);
    bitmap.data       = (uint8_t *)self.videoBuffer.mutableBytes;
    
    if (!load_rom((char *)gameURL.fileSystemRepresentation))
    {
        NSLog(@"Failed to load ROM: %@", gameURL);
        return;
    }
    
    audio_init(48000, vdp_pal ? GPGXFramesPerSecondPAL : GPGXFramesPerSecondNTSC);
    
    system_init();
    system_reset();
}

- (void)stop
{
    audio_shutdown();
}

- (void)pause
{
}

- (void)resume
{
}

#pragma mark - Game Loop -

- (void)runFrameAndProcessVideo:(BOOL)processVideo
{
    if (system_hw == SYSTEM_MCD)
    {
        system_frame_scd(!processVideo);
    }
    else if ((system_hw & SYSTEM_PBC) == SYSTEM_MD)
    {
        system_frame_gen(!processVideo);
    }
    else
    {
        system_frame_sms(!processVideo);
    }
    
    CGRect viewport = CGRectMake(bitmap.viewport.x, bitmap.viewport.y, bitmap.viewport.w, bitmap.viewport.h);
    if (!CGRectEqualToRect(viewport, self.videoRenderer.viewport))
    {
        self.videoRenderer.viewport = viewport;
    }
        
    int samples = audio_update(self.audioBuffer.mutableBytes);
    [self.audioRenderer.audioBuffer writeBuffer:self.audioBuffer.mutableBytes size:samples * 4];
    
    if (processVideo)
    {
        memcpy(self.videoRenderer.videoBuffer, self.videoBuffer.mutableBytes, self.videoBuffer.length);
        [self.videoRenderer processFrame];
    }
}

#pragma mark - Inputs -

- (void)activateInput:(NSInteger)inputValue value:(double)value at:(NSInteger)playerIndex
{
    input.pad[playerIndex * 4] |= inputValue;
}

- (void)deactivateInput:(NSInteger)inputValue at:(NSInteger)playerIndex
{
    input.pad[playerIndex * 4] &= ~inputValue;
}

- (void)resetInputs
{
    for(int player = 0; player < 2; player++)
    {
        input.pad[player * 4] = 0;
    }
}

#pragma mark - Game Saves -

- (void)saveGameSaveToURL:(NSURL *)URL
{
    NSData *saveData = [NSData dataWithBytes:sram.sram length:GPGXGameSaveSize];
    
    NSError *error = nil;
    if (![saveData writeToURL:URL options:NSDataWritingAtomic error:&error])
    {
        NSLog(@"[GPGXDeltaCore] Error saving Game Save to %@. %@", URL, error);
        return;
    }
    
    sram.crc = (unsigned int)crc32(0, sram.sram, GPGXGameSaveSize);
}

- (void)loadGameSaveFromURL:(NSURL *)URL
{
    NSError *error = nil;
    NSData *saveData = [NSData dataWithContentsOfURL:URL options:0 error:&error];
    if (saveData == nil)
    {
        NSLog(@"[GPGXDeltaCore] Error loading Game Save from %@. %@", URL, error);
        return;
    }
    
    memcpy(sram.sram, saveData.bytes, GPGXGameSaveSize);
    sram.crc = (unsigned int)crc32(0, sram.sram, GPGXGameSaveSize);
}

#pragma mark - Save States -

- (void)saveSaveStateToURL:(NSURL *)URL
{
    NSMutableData *saveStateData = [NSMutableData dataWithLength:STATE_SIZE];
    state_save(saveStateData.mutableBytes);
    
    NSError *error = nil;
    if (![saveStateData writeToURL:URL options:NSDataWritingAtomic error:&error])
    {
        NSLog(@"[GPGXDeltaCore] Error saving Save State to %@. %@", URL, error);
        return;
    }
}

- (void)loadSaveStateFromURL:(NSURL *)URL
{
    NSError *error = nil;
    NSData *saveStateData = [NSData dataWithContentsOfURL:URL options:0 error:&error];
    if (saveStateData == nil)
    {
        NSLog(@"[GPGXDeltaCore] Error loading Save State from %@. %@", URL, error);
        return;
    }
    
    state_load((unsigned char *)saveStateData.bytes);
}

#pragma mark - Cheats -

- (BOOL)addCheatCode:(NSString *)cheatCode type:(NSString *)type
{
    return YES;
}

- (void)resetCheats
{
}

- (void)updateCheats
{
}

#pragma mark - Getters/Setters -

- (NSTimeInterval)frameDuration
{
    return vdp_pal ? (1.0 / GPGXFramesPerSecondPAL) : (1.0 / GPGXFramesPerSecondNTSC);
}

#pragma mark - GenesisPlusGX -

void osd_input_update(void)
{
}

@end
