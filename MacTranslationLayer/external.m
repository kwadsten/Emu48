//
//  external.m
//  emu48
//
//  Based on external.c
//
//  Created by Da-Woon Jung on 2009-08-22.
//  Copyright 2009 dwj. All rights reserved.
//

#import "external.h"
#import "EMU48.H"
#import "OPS.H"
#import <OpenAL/alc.h>
#if TARGET_OS_IPHONE
#import <AudioToolbox/AudioToolbox.h>
#endif
#import "CalcBackend.h"

//| 38G  | 39G  | 40G  | 48SX | 48GX | 49G  | Name
//#F0E4F #80F0F #80F0F #706D2 #80850 #80F0F =SFLAG53_56

// memory address for flags -53 to -56
// CdB for HP: add apples beep management
#define SFLAG53_56	(  (cCurrentRomType=='6')								\
	                 ? 0xE0E4F												\
					 : (  (cCurrentRomType=='A')							\
					    ? 0xF0E4F											\
					    : (  (cCurrentRomType!='E' && cCurrentRomType!='X' && cCurrentRomType!='P' && cCurrentRomType!='2' && cCurrentRomType!='Q')	\
					       ? (  (cCurrentRomType=='S')						\
					          ? 0x706D2										\
						      : 0x80850										\
						     )												\
						   : 0x80F0F										\
					      )													\
					   )													\
					)


static __inline VOID BeepWave(DWORD dwFrequency,DWORD dwDuration)
{
    [[CalcBackend sharedBackend] playToneWithFrequency:dwFrequency duration:dwDuration];
}

static VOID Beeper(DWORD freq,DWORD dur)
{
#if !TARGET_OS_IPHONE
	if (1 == [[NSUserDefaults standardUserDefaults] integerForKey: @"WaveBeep"])
#endif
	{
		BeepWave(freq,dur);					// wave output over sound card
	}
#if !TARGET_OS_IPHONE
    else
    {
        NSBeep();
    }
#endif
}


VOID External(CHIPSET* w)					// Beep patch
{
	BYTE  fbeep;
	DWORD freq,dur;

	freq = Npack(w->D,5);					// frequency in Hz
	dur = Npack(w->C,5);					// duration in ms
	Nread(&fbeep,SFLAG53_56,1);				// fetch system flags -53 to -56

	w->carry = TRUE;						// setting of no beep
	if (!(fbeep & 0x8) && freq)				// bit -56 clear and frequency > 0 Hz
	{
		if (freq > 4400) freq = 4400;		// high limit of HP (SX)

		Beeper(freq,dur);					// beeping

		// estimate cpu cycles for beeping time (2MHz / 4MHz)
		w->cycles += dur * ((cCurrentRomType=='S') ? 2000 : 4000);           

		// original routine return with...
		w->P = 0;							// P=0
		w->intk = TRUE;						// INTON
		w->carry = FALSE;					// RTNCC
	}
	w->pc = rstkpop();
	return;
}

VOID RCKBp(CHIPSET* w)						// ROM Check Beep patch
{
	DWORD dw2F,dwCpuFreq;
	DWORD freq,dur;
	BYTE f,d;

	f = w->C[1];							// f = freq ctl
	d = w->C[0];							// d = duration ctl
	
	if (cCurrentRomType == 'S')				// Clarke chip with 48S ROM
	{	
		// CPU strobe frequency @ RATE 14 = 1.97MHz
		dwCpuFreq = ((14 + 1) * 524288) >> 2;

		dw2F = f * 126 + 262;				// F=f*63+131
	}
	else									// York chip with 48G and later ROM
	{
		// CPU strobe frequency @ RATE 27 = 3.67MHz
		// CPU strobe frequency @ RATE 29 = 3.93MHz
		dwCpuFreq = ((27 + 1) * 524288) >> 2;

		dw2F = f * 180 + 367;				// F=f*90+183.5
	}

	freq = dwCpuFreq / dw2F;
	dur = (dw2F * (256 - 16 * d)) * 1000 / 2 / dwCpuFreq;

	if (freq > 4400) freq = 4400;			// high limit of HP

	Beeper(freq,dur);						// beeping

	// estimate cpu cycles for beeping time (2MHz / 4MHz)
	w->cycles += dur * ((cCurrentRomType=='S') ? 2000 : 4000);           

	w->P = 0;								// P=0
	w->carry = FALSE;						// RTNCC
	w->pc = rstkpop();
	return;
}


#if TARGET_OS_IPHONE
void AudioInterruptListener(void *inClientData, UInt32 inInterruptionState)
{
    [[CalcBackend sharedBackend] interruptToneWithState: inInterruptionState];
}
#endif

@implementation CalcToneGenerator

- (id)init
{
    self = [super init];
    if (self)
    {
        ALenum      error;
        ALCcontext *context = NULL;
        ALCdevice  *device  = NULL;
        BOOL        initialized = NO;

        // System’s default output device
        device = alcOpenDevice(NULL);
        while (device)
        {
            context = alcCreateContext(device, 0);
            if (context)
            {
                alcMakeContextCurrent(context);

                alGenBuffers(1, &audioBuffer);
                if((error = alGetError()) != AL_NO_ERROR)
                {
                    alcDestroyContext(context);
                    alcCloseDevice(device);
                    break;
                }

                alGenSources(1, &audioSource);
                if(alGetError() != AL_NO_ERROR) 
                {
                    alDeleteBuffers(1, &audioBuffer);
                    alcDestroyContext(context);
                    alcCloseDevice(device);
                    break;
                }

                initialized = YES;
                break;
            }
        }
        // clear any errors
        alGetError();

        if (initialized)
        {
            
#if TARGET_OS_IPHONE
            AudioSessionSetActive(true);
#endif
        }
        else
        {
            [self release];
            self = nil;
        }
    }
    return self;
}

- (void)dealloc
{
    ALCcontext *context = NULL;
    ALCdevice  *device  = NULL;

#if TARGET_OS_IPHONE
    AudioSessionSetActive(false);
#endif
    alDeleteSources(1, &audioSource);
    alDeleteBuffers(1, &audioBuffer);
    context = alcGetCurrentContext();
    device  = alcGetContextsDevice(context);
    alcDestroyContext(context);
    alcCloseDevice(device);
    [super dealloc];
}

- (void)playToneWithFrequency:(DWORD)freq duration:(DWORD)duration
{
    ALint L;          //lenth of sample
    ALdouble F;       //frequency of sample
    ALfloat volume;
    ALshort *samples; //signed 16-bit
    ALint T;          //time

    // generate square wave
    L = CALC_AUD_SAMPLE_RATE*duration/1000;
    samples = malloc(L * sizeof(ALshort));
    volume = [[NSUserDefaults standardUserDefaults] floatForKey: @"WaveVolume"];
    if (volume < 0.f) volume = 0.f;
    if (volume > 1.f) volume = 1.f;

    F = 2.*freq/CALC_AUD_SAMPLE_RATE;
    for (T = 0; T < L; ++T)
        samples[T] = ((ALshort)(F*T) & 1)*CALC_AUD_MAX_AMPLITUDE;

    alBufferData(audioBuffer, AL_FORMAT_MONO16, samples, L*sizeof(ALshort), CALC_AUD_SAMPLE_RATE);
    free(samples);

    alSourcef(audioSource,  AL_PITCH, 1.0f);
    alSourcef(audioSource,  AL_GAIN,  volume);
    alSourcei(audioSource,  AL_LOOPING, AL_FALSE);
    alSourcei(audioSource,  AL_BUFFER,  audioBuffer);
    alSourcePlay(audioSource);
}
@end
