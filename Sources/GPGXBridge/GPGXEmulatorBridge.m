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

#if SWIFT_PACKAGE
@import GenesisPlusGX;
#else

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything"
#import "shared.h"
#pragma clang diagnostic pop

#endif

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything"
#import "shared.h"
#pragma clang diagnostic pop

#define u8 uint8_t
#define u16 uint16_t
#define u32 uint32_t
#define u64 uint64_t

#define MAX_CHEATS (350)
#define MAX_DESC_LENGTH (63)

static char ggvalidchars[] = "ABCDEFGHJKLMNPRSTVWXYZ0123456789";
static char arvalidchars[] = "0123456789ABCDEF";

static int maxcheats = 0;
static int maxROMcheats = 0;
static int maxRAMcheats = 0;

typedef struct
{
  char code[12];
  char text[MAX_DESC_LENGTH];
  u8 enable;
  u16 data;
  u16 old;
  u32 address;
  u8 *prev;
} CHEATENTRY;

static CHEATENTRY cheatlist[MAX_CHEATS];
static u8 cheatIndexes[MAX_CHEATS];

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
    RAMCheatUpdate();
    
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

- (void)activateInput:(NSInteger)inputValue value:(double)value playerIndex:(NSInteger)playerIndex
{
    input.pad[playerIndex * 4] |= inputValue;
}

- (void)deactivateInput:(NSInteger)inputValue playerIndex:(NSInteger)playerIndex
{
    input.pad[playerIndex * 4] &= ~inputValue;
}

- (void)resetInputs
{
    for (int playerIndex = 0; playerIndex < 2; playerIndex++)
    {
        input.pad[playerIndex * 4] = 0;
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
    NSMutableCharacterSet *legalCharacterSet = nil;
    if ([type isEqualToString:CheatTypeActionReplay])
    {
        legalCharacterSet = [[NSMutableCharacterSet characterSetWithCharactersInString:[NSString stringWithUTF8String:arvalidchars]] mutableCopy];
        [legalCharacterSet addCharactersInString:@":"];
    }
    else if ([type isEqualToString:CheatTypeGameGenie])
    {
        legalCharacterSet = [[NSMutableCharacterSet characterSetWithCharactersInString:[NSString stringWithUTF8String:ggvalidchars]] mutableCopy];
        [legalCharacterSet addCharactersInString:@"-"];
    }
    else
    {
        NSLog(@"Unsupported cheat type: %@", type);
        return NO;
    }

    [legalCharacterSet addCharactersInString:@" "];
    BOOL addedCheat = NO;
    
    NSString *normalized = [[cheatCode stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    if (normalized.length == 0)
    {
        return NO;
    }

    NSRange illegalRange = [normalized rangeOfCharacterFromSet:[legalCharacterSet invertedSet]];
    if (illegalRange.location != NSNotFound)
    {
        NSLog(@"Offending character: %C", [normalized characterAtIndex:illegalRange.location]);
        return NO;
    }

    NSString *sanitizedCode = [normalized stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    if ([type isEqualToString:CheatTypeGameGenie])
    {
        BOOL is16BitFormat = (sanitizedCode.length == 9 && [sanitizedCode characterAtIndex:4] == '-');
        // We can cut this or comment it out for now, as we
        // don't really support the Sega Game Gear (8-bit)
        BOOL is8BitFormat = (sanitizedCode.length == 11 &&
                             [sanitizedCode characterAtIndex:3] == '-' &&
                             [sanitizedCode characterAtIndex:7] == '-');
        if (!is16BitFormat && !is8BitFormat)
        {
            NSLog(@"Invalid Game Genie format: %@", sanitizedCode);
            return NO;
        }
    }
    else if ([type isEqualToString:CheatTypeActionReplay])
    {
        BOOL isValidLength = (sanitizedCode.length == 9 || sanitizedCode.length == 11);
        BOOL hasExpectedSeparator = (sanitizedCode.length > 6 && [sanitizedCode characterAtIndex:6] == ':');
        if (!isValidLength || !hasExpectedSeparator)
        {
            NSLog(@"Invalid Action Replay format: %@", sanitizedCode);
            return NO;
        }
    }
    
    char cheatCString[32];
    if (![sanitizedCode getCString:cheatCString maxLength:sizeof(cheatCString) encoding:NSUTF8StringEncoding])
    {
        NSLog(@"Failed to convert to cString: %@", sanitizedCode);
        return NO;
    }
    
    if (maxcheats >= MAX_CHEATS)
    {
        NSLog(@"Maximum number of cheats reached.");
        return NO;
    }

    NSInteger length = decode_cheat(cheatCString, maxcheats);
    if (length == 0)
    {
        NSLog(@"Failed to decode cheat: %@", sanitizedCode);
        return NO;
    }

    cheatlist[maxcheats].enable = 1;
    maxcheats++;
    addedCheat = YES;
    
    return addedCheat;
}

- (void)resetCheats
{
    clear_cheats();
    maxcheats = 0;
}

- (void)updateCheats
{
    apply_cheats();
    ROMCheatUpdate();
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

// Adapted from GPGX: gx/gui/cheats.c
static u32 decode_cheat(char *string, int index)
{
  char *p;
  int i,n;
  u32 len = 0;
  u32 address = 0;
  u16 data = 0;
  u8 ref = 0;

  /* 16-bit Game Genie code (ABCD-EFGH) */
  if ((strlen(string) >= 9) && (string[4] == '-'))
  {
    /* 16-bit system only */
    if ((system_hw & SYSTEM_PBC) != SYSTEM_MD)
    {
      return 0;
    }

    for (i = 0; i < 8; i++)
    {
      if (i == 4) string++;
      p = strchr (ggvalidchars, *string++);
      if (p == NULL) return 0;
      n = p - ggvalidchars;

      switch (i)
      {
        case 0:
        data |= n << 3;
        break;

        case 1:
        data |= n >> 2;
        address |= (n & 3) << 14;
        break;

        case 2:
        address |= n << 9;
        break;

        case 3:
        address |= (n & 0xF) << 20 | (n >> 4) << 8;
        break;
    
        case 4:
        data |= (n & 1) << 12;
        address |= (n >> 1) << 16;
        break;

        case 5:
        data |= (n & 1) << 15 | (n >> 1) << 8;
        break;

        case 6:
        data |= (n >> 3) << 13;
        address |= (n & 7) << 5;
        break;

        case 7:
        address |= n;
        break;
      }
    }

    /* code length */
    len = 9;
  }

  /* 8-bit Game Genie code (DDA-AAA-XXX) */
  else if ((strlen(string) >= 11) && (string[3] == '-') && (string[7] == '-'))
  {
    /* 8-bit system only */
    if ((system_hw & SYSTEM_PBC) == SYSTEM_MD)
    {
      return 0;
    }

    /* decode 8-bit data */
    for (i=0; i<2; i++)
    {
      p = strchr (arvalidchars, *string++);
      if (p == NULL) return 0;
      n = (p - arvalidchars) & 0xF;
      data |= (n  << ((1 - i) * 4));
    }

    /* decode 16-bit address (low 12-bits) */
    for (i=0; i<3; i++)
    {
      if (i==1) string++; /* skip separator */
      p = strchr (arvalidchars, *string++);
      if (p == NULL) return 0;
      n = (p - arvalidchars) & 0xF;
      address |= (n  << ((2 - i) * 4));
    }

    /* decode 16-bit address (high 4-bits) */
    p = strchr (arvalidchars, *string++);
    if (p == NULL) return 0;
    n = (p - arvalidchars) & 0xF;
    n ^= 0xF; /* bits inversion */
    address |= (n  << 12);

    /* RAM address are also supported */
    if (address >= 0xC000)
    {
      /* convert to 24-bit Work RAM address */
      address = 0xFF0000 | (address & 0x1FFF);
    }

    /* decode reference 8-bit data */
    for (i=0; i<2; i++)
    {
      string++; /* skip separator and 2nd digit */
      p = strchr (arvalidchars, *string++);
      if (p == NULL) return 0;
      n = (p - arvalidchars) & 0xF;
      ref |= (n  << ((1 - i) * 4));
    }
    ref = (ref >> 2) | ((ref & 0x03) << 6);  /* 2-bit right rotation */
    ref ^= 0xBA;  /* XOR */

    /* update old data value */
    cheatlist[index].old = ref;

    /* code length */
    len = 11;
  }

  /* Action Replay code */
  else if (string[6] == ':')
  {
    if ((system_hw & SYSTEM_PBC) == SYSTEM_MD)
    {
      /* 16-bit code (AAAAAA:DDDD) */
      if (strlen(string) < 11) return 0;

      /* decode 24-bit address */
      for (i=0; i<6; i++)
      {
        p = strchr (arvalidchars, *string++);
        if (p == NULL) return 0;
        n = (p - arvalidchars) & 0xF;
        address |= (n << ((5 - i) * 4));
      }

      /* decode 16-bit data */
      string++;
      for (i=0; i<4; i++)
      {
        p = strchr (arvalidchars, *string++);
        if (p == NULL) return 0;
        n = (p - arvalidchars) & 0xF;
        data |= (n << ((3 - i) * 4));
      }

      /* code length */
      len = 11;
    }
    else
    {
      /* 8-bit code (xxAAAA:DD) */
      if (strlen(string) < 9) return 0;

      /* decode 16-bit address */
      string+=2;
      for (i=0; i<4; i++)
      {
        p = strchr (arvalidchars, *string++);
        if (p == NULL) return 0;
        n = (p - arvalidchars) & 0xF;
        address |= (n << ((3 - i) * 4));
      }

      /* ROM addresses are not supported */
      if (address < 0xC000) return 0;

      /* convert to 24-bit Work RAM address */
      address = 0xFF0000 | (address & 0x1FFF);

      /* decode 8-bit data */
      string++;
      for (i=0; i<2; i++)
      {
        p = strchr (arvalidchars, *string++);
        if (p == NULL) return 0;
        n = (p - arvalidchars) & 0xF;
        data |= (n  << ((1 - i) * 4));
      }

      /* code length */
      len = 9;
    }
  }

  /* Valid code found ? */
  if (len)
  {
    /* update cheat address & data values */
    cheatlist[index].address = address;
    cheatlist[index].data = data;
  }

  /* return code length (0 = invalid) */
  return len;
}

// Adapted from GPGX: gx/gui/cheats.c
static void apply_cheats(void)
{
  u8 *ptr;
  
  /* clear ROM&RAM patches counter */
  maxROMcheats = maxRAMcheats = 0;

  int i;
  for (i = 0; i < maxcheats; i++)
  {
    if (cheatlist[i].enable)
    {
      if (cheatlist[i].address < cart.romsize)
      {
        if ((system_hw & SYSTEM_PBC) == SYSTEM_MD)
        {
          /* patch ROM data */
          cheatlist[i].old = *(u16 *)(cart.rom + (cheatlist[i].address & 0xFFFFFE));
          *(u16 *)(cart.rom + (cheatlist[i].address & 0xFFFFFE)) = cheatlist[i].data;
        }
        else
        {
          /* add ROM patch */
          maxROMcheats++;
          cheatIndexes[MAX_CHEATS - maxROMcheats] = i;

          /* get current banked ROM address */
          ptr = &z80_readmap[(cheatlist[i].address) >> 10][cheatlist[i].address & 0x03FF];

          /* check if reference matches original ROM data */
          if (((u8)cheatlist[i].old) == *ptr)
          {
            /* patch data */
            *ptr = cheatlist[i].data;

            /* save patched ROM address */
            cheatlist[i].prev = ptr;
          }
          else
          {
            /* no patched ROM address yet */
            cheatlist[i].prev = NULL;
          }
        }
      }
      else if (cheatlist[i].address >= 0xFF0000)
      {
        /* add RAM patch */
        cheatIndexes[maxRAMcheats++] = i;
      }
    }
  }
}

// Adapted from GPGX: gx/gui/cheats.c
static void clear_cheats(void)
{
  int i = maxcheats;

  /* disable cheats in reversed order in case the same address is used by multiple patches */
  while (i > 0)
  {
    if (cheatlist[i-1].enable)
    {
      if (cheatlist[i-1].address < cart.romsize)
      {
        if ((system_hw & SYSTEM_PBC) == SYSTEM_MD)
        {
          /* restore original ROM data */
          *(u16 *)(cart.rom + (cheatlist[i-1].address & 0xFFFFFE)) = cheatlist[i-1].old;
        }
        else
        {
          /* check if previous banked ROM address has been patched */
          if (cheatlist[i-1].prev != NULL)
          {
            /* restore original data */
            *cheatlist[i-1].prev = cheatlist[i-1].old;

            /* no more patched ROM address */
            cheatlist[i-1].prev = NULL;
          }
        }
      }
    }

    i--;
  }
}

// Adapted from GPGX: gx/gui/cheats.c
void RAMCheatUpdate(void)
{
  int index, cnt = maxRAMcheats;
  
  while (cnt)
  {
    /* get cheat index */
    index = cheatIndexes[--cnt];

    /* apply RAM patch */
    if (cheatlist[index].data & 0xFF00)
    {
      /* word patch */
      *(u16 *)(work_ram + (cheatlist[index].address & 0xFFFE)) = cheatlist[index].data;
    }
    else
    {
      /* byte patch */
      work_ram[cheatlist[index].address & 0xFFFF] = cheatlist[index].data;
    }
  }
}

// Adapted from GPGX: gx/gui/cheats.c
void ROMCheatUpdate(void)
{
  int index, cnt = maxROMcheats;
  u8 *ptr;
  
  while (cnt)
  {
    /* get cheat index */
    index = cheatIndexes[MAX_CHEATS - cnt];

    /* check if previous banked ROM address was patched */
    if (cheatlist[index].prev != NULL)
    {
      /* restore original data */
      *cheatlist[index].prev = cheatlist[index].old;

      /* no more patched ROM address */
      cheatlist[index].prev = NULL;
    }

    /* get current banked ROM address */
    ptr = &z80_readmap[(cheatlist[index].address) >> 10][cheatlist[index].address & 0x03FF];

    /* check if reference matches original ROM data */
    if (((u8)cheatlist[index].old) == *ptr)
    {
      /* patch data */
      *ptr = cheatlist[index].data;

      /* save patched ROM address */
      cheatlist[index].prev = ptr;
    }

    /* next ROM patch */
    cnt--;
  }
}

@end
