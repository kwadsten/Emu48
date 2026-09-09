//
//  external.h
//  emu48
//
//  Created by Da-Woon Jung on 2009-08-22.
//  Copyright 2009 dwj. All rights reserved.
//

#import "pch.h"
#import <OpenAL/al.h>

#define CALC_AUD_SAMPLE_RATE    11025
// Maximum amplitude for 16bit
#define CALC_AUD_MAX_AMPLITUDE  32700

#if TARGET_OS_IPHONE
extern void AudioInterruptListener(void *inClientData, UInt32 inInterruptionState);
#endif

@interface CalcToneGenerator : NSObject
{
    ALuint audioSource;
    ALuint audioBuffer;
}
- (void)playToneWithFrequency:(DWORD)freq duration:(DWORD)duration;
@end
