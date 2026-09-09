//
//  timer.m
//  emu48
//
//  Created by Da Woon Jung on Fri Feb 27 2004.
//  Copyright (c) 2004 dwj. All rights reserved.
//

#import "pch.h"
#import "EMU48.H"
#import "OPS.H"
#import "IO.H"
#import "timer.h"
#import <time.h>
#import "engine.h"
//#import "CalcAppController.h"
#import "CalcBackend.h"


extern CHIPSET Chipset;

#define SharedTimer     [[CalcBackend sharedBackend] timer]

@interface CalcTimer(Private)
- (DWORD) CalcT2;
- (void) CheckT1:(BYTE) nT1;
- (void) _CheckT1:(NSNumber *) aNumberT1;
- (void) CheckT2:(DWORD) dwT2;
- (void) RescheduleT2:(BOOL) bRefPoint;
- (void) AbortT2;
- (void) TimeProc:(NSTimer *) aTimer;
- (void) SetT1:(NSNumber *) aNumberValue;
- (void) SetT2:(NSNumber *) aNumberValue;
- (void) ReadT2:(NSMutableData *) aInOutT2;
- (void) SetHPTime;
@end


#define AUTO_OFF    10						// Time in minutes for 'auto off'

// Ticks for 01.01.1970 00:00:00
#define UNIX_0_TIME	( 0x0001cf2e8f800000)

// Ticks for 'auto off'
#define OFF_TIME	(((AUTO_OFF * 60) << 13))

// memory address for clock and auto off
// S(X) = 0x70052-0x70070, G(X) = 0x80058-0x80076, 49G = 0x80058-0x80076
#define RPLTIME		((cCurrentRomType=='S')?0x52:0x58)

#define T1_FREQ		0.062					// Timer1 1/frequency in s
#define T2_FREQ		8192					// Timer2 frequency


VOID SetHP48Time(VOID)						// set date and time
{
    [SharedTimer performSelectorOnMainThread:@selector(SetHPTime) withObject:nil waitUntilDone:YES];
}

VOID StartTimers(VOID)
{
    [SharedTimer performSelectorOnMainThread:@selector(StartTimers) withObject:nil waitUntilDone:YES];
}

VOID StopTimers(VOID)
{
    [SharedTimer performSelectorOnMainThread:@selector(StopTimers) withObject:nil waitUntilDone:NO];
}

DWORD ReadT2(VOID)
{
	DWORD *t2Ptr = NULL;
    DWORD dwT2 = 0;
    NSMutableData *t2Data = [[NSMutableData alloc] initWithBytes:&dwT2 length:sizeof(dwT2)];
    [SharedTimer ReadT2: t2Data];
//    [SharedTimer performSelectorOnMainThread:@selector(ReadT2:) withObject:t2Data waitUntilDone:YES];
    t2Ptr = (DWORD *)[t2Data bytes];
    if (t2Ptr)
        dwT2 = *t2Ptr;
    [t2Data release];
	return dwT2;
}

VOID SetT2(DWORD dwValue)
{
    [SharedTimer performSelectorOnMainThread:@selector(SetT2:) withObject:[NSNumber numberWithUnsignedInt:dwValue] waitUntilDone:YES];
}

BYTE ReadT1(VOID)
{
	BYTE nT1;
	EnterCriticalSection(&csT1Lock);
	{
		nT1 = Chipset.t1;					// read timer1 value
	}
	LeaveCriticalSection(&csT1Lock);
	[SharedTimer performSelectorOnMainThread:@selector(_CheckT1:) withObject:[NSNumber numberWithUnsignedChar:nT1] waitUntilDone:YES];						// update timer1 control bits
	return nT1;
}

VOID SetT1(BYTE byValue)
{
    [SharedTimer performSelectorOnMainThread:@selector(SetT1:) withObject:[NSNumber numberWithUnsignedChar:byValue] waitUntilDone:YES];
}


@implementation CalcTimer

- (DWORD) CalcT2
{
	DWORD dwT2 = Chipset.t2;				// get value from chipset
	if (bStarted)							// timer2 running
	{
		LARGE_INTEGER lT2Act;
		DWORD         dwT2Dif;
        
		// timer should run a little bit faster (10%) than machine in authentic speed mode
		DWORD dwCycPerTick = (9 * T2CYCLES) / 5;
        
		QueryPerformanceCounter(&lT2Act);	// actual time
		// calculate realtime timer2 ticks since reference point
		dwT2 -= (DWORD)
        (((lT2Act.QuadPart - lT2Ref.QuadPart) * T2_FREQ)
         / lFreq.QuadPart);
        
		dwT2Dif = dwT2Ref - dwT2;			// timer2 ticks since last request
        
		// checking if the MSB of dwT2Dif can be used as sign flag
//		_ASSERT((DWORD) tc.wPeriodMax < ((1<<(sizeof(dwT2Dif)*8-1))/8192)*1000);
        
		// 2nd timer call in a 32ms time frame or elapsed time is negative (Win2k bug)
		if (!Chipset.Shutdn && ((dwT2Dif > 0x01 && dwT2Dif <= 0x100) || (dwT2Dif & 0x80000000) != 0))
		{
			DWORD dwT2Ticks = ((DWORD) (Chipset.cycles & 0xFFFFFFFF) - dwT2Cyc) / dwCycPerTick;
            
			// estimated < real elapsed timer2 ticks or negative time
			if (dwT2Ticks < dwT2Dif || (dwT2Dif & 0x80000000) != 0)
			{
				// real time too long or got negative time elapsed
				dwT2 = dwT2Ref - dwT2Ticks;	// estimated timer2 value from CPU cycles
				dwT2Cyc += dwT2Ticks * dwCycPerTick; // estimated CPU cycles for the timer2 ticks
			}
			else
			{
				// reached actual time -> new synchronizing
				dwT2Cyc = (DWORD) (Chipset.cycles & 0xFFFFFFFF) - dwCycPerTick;
			}
		}
		else
		{
			// valid actual time -> new synchronizing
			dwT2Cyc = (DWORD) (Chipset.cycles & 0xFFFFFFFF) - dwCycPerTick;
		}

		// check if timer2 interrupt is active -> no timer2 value below 0xFFFFFFFF
		if (   Chipset.inte
			&& (dwT2 & 0x80000000) != 0
			&& (!Chipset.Shutdn || (Chipset.IORam[TIMER2_CTRL]&WKE))
			&& (Chipset.IORam[TIMER2_CTRL]&INTR)
            )
		{
			dwT2 = 0xFFFFFFFF;
			dwT2Cyc = (DWORD) (Chipset.cycles & 0xFFFFFFFF) - dwCycPerTick;
		}

		dwT2Ref = dwT2;						// new reference time
	}
	return dwT2;
}

- (void) CheckT1:(BYTE) nT1
{
	// implementation of TSRQ
	bNINT2T1 = (Chipset.IORam[TIMER1_CTRL]&INTR) != 0 && (nT1&8) != 0;
	IOBit(SRQ1,TSRQ,bNINT2T1 || bNINT2T2);
    
	if ((nT1&8) == 0)						// timer1 MSB not set
	{
		Chipset.IORam[TIMER1_CTRL] &= ~SRQ;	// clear SRQ bit
		return;
	}
    
	_ASSERT((nT1&8) != 0);					// timer1 MSB set
    
	// timer MSB and INT or WAKE bit is set
	if ((Chipset.IORam[TIMER2_CTRL]&(WKE|INTR)) != 0)
		Chipset.IORam[TIMER1_CTRL] |= SRQ;	// set SRQ
	// cpu not sleeping and T1 -> Interrupt
	if (   (!Chipset.Shutdn || (Chipset.IORam[TIMER1_CTRL]&WKE))
		&& (Chipset.IORam[TIMER1_CTRL]&INTR))
	{
		Chipset.SoftInt = TRUE;
		bInterrupt = TRUE;
	}
	// cpu sleeping and T1 -> Wake Up
	if (Chipset.Shutdn && (Chipset.IORam[TIMER1_CTRL]&WKE))
	{
		Chipset.IORam[TIMER1_CTRL] &= ~WKE;	// clear WKE bit
		Chipset.bShutdnWake = TRUE;			// wake up from SHUTDN mode
		SetEvent(hEventShutdn);				// wake up emulation thread
	}
}

- (void) _CheckT1:(NSNumber *) aNumberT1
{
    [self CheckT1: [aNumberT1 unsignedIntValue]];
}

- (void) CheckT2:(DWORD) dwT2
{
	// implementation of TSRQ
	bNINT2T2 = (Chipset.IORam[TIMER2_CTRL]&INTR) != 0 && (dwT2&0x80000000) != 0;
	IOBit(SRQ1,TSRQ,bNINT2T1 || bNINT2T2);
    
	if ((dwT2&0x80000000) == 0)				// timer2 MSB not set
	{
		Chipset.IORam[TIMER2_CTRL] &= ~SRQ;	// clear SRQ bit
		return;
	}
    
	_ASSERT((dwT2&0x80000000) != 0);		// timer2 MSB set
    
	// timer MSB is one and either INT or WAKE is set
	if (   (Chipset.IORam[TIMER2_CTRL]&WKE)
	    || (Chipset.IORam[TIMER2_CTRL]&INTR))
		Chipset.IORam[TIMER2_CTRL] |= SRQ;	// set SRQ
	// cpu not sleeping and T2 -> Interrupt
	if (   (!Chipset.Shutdn || (Chipset.IORam[TIMER2_CTRL]&WKE))
		&& (Chipset.IORam[TIMER2_CTRL]&INTR))
	{
		Chipset.SoftInt = TRUE;
		bInterrupt = TRUE;
	}
	// cpu sleeping and T2 -> Wake Up
	if (Chipset.Shutdn && (Chipset.IORam[TIMER2_CTRL]&WKE))
	{
		Chipset.IORam[TIMER2_CTRL] &= ~WKE;	// clear WKE bit
		Chipset.bShutdnWake = TRUE;			// wake up from SHUTDN mode
		SetEvent(hEventShutdn);				// wake up emulation thread
	}
}

- (void) RescheduleT2:(BOOL) bRefPoint
{
	UINT uDelay;
	if (bRefPoint)							// save reference time
	{
		dwT2Ref = Chipset.t2;				// timer2 value at last timer2 access
		dwT2Cyc = (DWORD) (Chipset.cycles & 0xFFFFFFFF); // cpu cycle counter at last timer2 access
		QueryPerformanceCounter(&lT2Ref);	// time of corresponding Chipset.t2 value
		uDelay = Chipset.t2;				// timer value for delay
	}
	else									// called without new refpoint, restart t2 with actual value
	{
		uDelay = [self CalcT2];					// actual timer value for delay
	}
	if ((bOutRange = uDelay > uT2MaxTicks))	// delay greater maximum delay
		uDelay = uT2MaxTicks;				// wait maximum delay time
    uDelay = uDelay * 125 + 1023;
	uDelay /= 1024;	// timer delay in ms (1000/8192 = 125/1024)
#if 0
	uDelay = __max(tc.wPeriodMin,uDelay);	// wait minimum delay of timer
	_ASSERT(uDelay <= tc.wPeriodMax);		// inside maximum event delay
#else
    if (uDelay < 10)
        uDelay = 10;
#endif
	// start timer2; schedule event, when Chipset.t2 will be zero
    [uT2TimerId release];
    uT2TimerId = [[NSTimer scheduledTimerWithTimeInterval:(uDelay/1000.0) target:self selector:@selector(TimeProc:) userInfo:nil repeats:NO] retain];
}

- (void) AbortT2
{
	_ASSERT(uT2TimerId);
    [uT2TimerId invalidate];
    [uT2TimerId release];
	uT2TimerId = nil;
}

- (void)StartTimers
{
	if (bStarted)							// timer running
		return;								// -> quit
	if (Chipset.IORam[TIMER2_CTRL]&RUN)		// start timer1 and timer2 ?
	{
		bStarted = TRUE;					// flag timer running
		// initialisation of NINT2 lines
		bNINT2T1 = (Chipset.IORam[TIMER1_CTRL]&INTR) != 0 && (Chipset.t1 & 8) != 0;
		bNINT2T2 = (Chipset.IORam[TIMER2_CTRL]&INTR) != 0 && (Chipset.t2 & 0x80000000) != 0;
        // max. timer2 ticks that can be handled by one timer event
		uT2MaxTicks = (0xFFFFFFFF-1023) / 125;

		[self CheckT1: Chipset.t1];				// check for timer1 interrupts
		[self CheckT2: Chipset.t2];				// check for timer2 interrupts
		// set timer1 with given period
        [uT1TimerId release];
        uT1TimerId = [[NSTimer scheduledTimerWithTimeInterval:T1_FREQ target:self selector:@selector(TimeProc:) userInfo:nil repeats:YES] retain];
		[self RescheduleT2: TRUE];					// start timer2
	}
}

- (void)StopTimers
{
	if (!bStarted)							// timer stopped
		return;								// -> quit
	if ([uT1TimerId isValid])					// timer1 running
	{
		// Critical Section handler may cause a dead lock
        [uT1TimerId invalidate];			// stop timer1
        [uT1TimerId release];
        uT1TimerId = nil;
	}
	if ([uT2TimerId isValid])					// timer2 running
	{
		EnterCriticalSection(&csT2Lock);
		{
			Chipset.t2 = [self CalcT2];			// update chipset timer2 value
		}
		LeaveCriticalSection(&csT2Lock);
		[self AbortT2];							// stop timer2 outside critical section
	}
	bStarted = FALSE;
}

- (void) TimeProc:(NSTimer *) aTimer
{
	if (aTimer == uT1TimerId)				// called from timer1 event (default period 16 Hz)
	{
		EnterCriticalSection(&csT1Lock);
		{
			Chipset.t1 = (Chipset.t1-1)&0xF;// decrement timer value
			[self CheckT1: Chipset.t1];			// test timer1 control bits
		}
		LeaveCriticalSection(&csT1Lock);
		return;
	}
	if (aTimer == uT2TimerId)				// called from timer2 event, Chipset.t2 should be zero
	{
		EnterCriticalSection(&csT2Lock);
		{
            [uT2TimerId release];
			uT2TimerId = nil;				// single shot timer timer2 stopped
			if (!bOutRange)					// timer event elapsed
			{
				// timer2 overrun, test timer2 control bits else restart timer2
				Chipset.t2 = [self CalcT2];		// calculate new timer2 value
				[self CheckT2: Chipset.t2];		// test timer2 control bits
			}
			[self RescheduleT2: !bOutRange];		// restart timer2
		}
		LeaveCriticalSection(&csT2Lock);
		return;
	}
}

- (void) SetT1:(NSNumber *) aNumberValue
{
	BOOL bEqual;

    BYTE byValue = [aNumberValue unsignedIntValue];
	_ASSERT(byValue < 0x10);				// timer1 is only a 4bit counter
    
	EnterCriticalSection(&csT1Lock);
	{
		bEqual = (Chipset.t1 == byValue);	// check for same value
	}
	LeaveCriticalSection(&csT1Lock);
	if (bEqual) return;						// same value doesn't restart timer period

    if ([uT1TimerId isValid])
    {
        [uT1TimerId invalidate];
        [uT1TimerId release];
        uT1TimerId = nil;
    }
	EnterCriticalSection(&csT1Lock);
	{
		Chipset.t1 = byValue;				// set new timer1 value
		[self CheckT1: Chipset.t1];				// test timer1 control bits
	}
	LeaveCriticalSection(&csT1Lock);
	if (bStarted)							// timer running
	{
        // restart timer1 to get full period of frequency
        uT1TimerId = [[NSTimer scheduledTimerWithTimeInterval:T1_FREQ target:self selector:@selector(TimeProc:) userInfo:nil repeats:YES] retain];
    }
}

- (void) SetT2:(NSNumber *) aNumberValue
{
    DWORD dwValue = [aNumberValue unsignedIntValue];
	// calling AbortT2() inside Critical Section handler may cause a dead lock
	if ([uT2TimerId isValid])					// timer2 running
		[self AbortT2];							// stop timer2
	EnterCriticalSection(&csT2Lock);
	{
		Chipset.t2 = dwValue;				// set new value
		[self CheckT2: Chipset.t2];				// test timer2 control bits
		if (bStarted)						// timer running
			[self RescheduleT2: TRUE];				// restart timer2
	}
	LeaveCriticalSection(&csT2Lock);
}

- (void) ReadT2:(NSMutableData *) aInOutT2
{
    DWORD dwT2;
	EnterCriticalSection(&csT2Lock);
    dwT2 = [self CalcT2];					// calculate timer2 value or if stopped last timer value
    [self CheckT2: dwT2];						// update timer2 control bits
    [aInOutT2 replaceBytesInRange:NSMakeRange(0, sizeof(dwT2)) withBytes:&dwT2];
	LeaveCriticalSection(&csT2Lock);
}

- (void) SetHPTime
{
    ULONGLONG  ticks, calctime;
    DWORD      dw;
    WORD       crc, i;
    BYTE       p[4];
    ticks = (ULONGLONG)time(NULL);
#if TARGET_OS_IPHONE
    ticks -= timezone;
#else
    struct tm *lt;
    lt = localtime((time_t *)&ticks);
    ticks += lt->tm_gmtoff;
#endif
    ticks *= 8192;
    ticks += UNIX_0_TIME;					// add offset ticks from year 0
    ticks += Chipset.t2;					// add actual timer2 value

    calctime = ticks;						// save for calc. timeout
    calctime += OFF_TIME;					// add 10 min for auto off

    dw = RPLTIME;							// HP addresses for clock in port0

    crc = 0x0;								// reset crc value
    for (i = 0; i < 13; ++i, ++dw)			// write date and time
    {
        *p = ((BYTE)ticks) & 0xf;
        crc = (crc >> 4) ^ (((crc ^ ((WORD) *p)) & 0xf) * 0x1081);
        Chipset.Port0[dw] = *p;				// always store in port0
        ticks >>= 4; // /= 16.;
    }

    Nunpack(p,crc,4);						// write crc
    memcpy(Chipset.Port0+dw,p,4);			// always store in port0

    dw += 4;								// HP addresses for timeout

    for (i = 0; i < 13; ++i, ++dw)			// write time for auto off
    {
        // always store in port0
        Chipset.Port0[dw] = ((BYTE)calctime) & 0xf;
        calctime >>= 4; // /= 16.;
    }

    Chipset.Port0[dw] = 0xf;				// always store in port0
}
@end
