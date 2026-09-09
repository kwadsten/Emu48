//
//  timer.h
//  emu48
//
//  Created by Da Woon Jung on Fri Feb 27 2004.
//  Copyright (c) 2004 dwj. All rights reserved.
//
#import "TYPES.H"


@interface CalcTimer : NSObject
{
    NSTimer *uT1TimerId;
    NSTimer *uT2TimerId;
    BOOL  bStarted;
    BOOL  bOutRange;			// flag if timer value out of range
    BOOL  bNINT2T1;				// state of NINT2 affected from timer1
    BOOL  bNINT2T2;				// state of NINT2 affected from timer2
    
    LARGE_INTEGER lT2Ref;		// counter value at timer2 start
    UINT  uT2MaxTicks;			// max. timer2 ticks handled by one timer event

    DWORD dwT2Ref;				// timer2 value at last timer2 access
    DWORD dwT2Cyc;				// cpu cycle counter at last timer2 access
}
- (void)StartTimers;
- (void)StopTimers;
@end
