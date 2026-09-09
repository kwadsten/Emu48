//
//  engine.m
//  emu48
//
//  Created by Da Woon Jung on Thu Feb 26 2004.
//  Copyright (c) 2009 dwj. All rights reserved.
//

#import "pch.h"
#import "EMU48.H"
#import "engine.h"
#import "timer.h"

CRITICAL_SECTION csKeyLock;			// critical section for key scan
CRITICAL_SECTION csLcdLock;			// critical section for display update
CRITICAL_SECTION csIOLock;			// critical section for I/O access
CRITICAL_SECTION csT1Lock;			// critical section for timer1 access
CRITICAL_SECTION csT2Lock;			// critical section for timer2 access
//CRITICAL_SECTION csTxdLock;			// critical section for transmit byte
//CRITICAL_SECTION csRecvLock;		// critical section for receive byte
CRITICAL_SECTION csSlowLock;		// critical section for speed slow down
LARGE_INTEGER    lFreq;             // high performance counter frequency
LARGE_INTEGER    lAppStart;         // high performance counter value at Appl. start
HANDLE           hThread;
HANDLE           hEventShutdn;      // event handle to stop cpu thread
extern UINT    nState;
extern UINT    nNextState;


@implementation CalcEngine

- (id) init
{
    self = [super init];
    if (self)
    {
        pthread_mutexattr_t ma;
        pthread_mutexattr_init(&ma);
#ifndef NDEBUG
        pthread_mutexattr_settype(&ma, PTHREAD_MUTEX_ERRORCHECK);
#endif
        pthread_mutex_init(&csKeyLock,  &ma);
        pthread_mutex_init(&csLcdLock,  &ma);
        pthread_mutex_init(&csIOLock,   &ma);
        pthread_mutex_init(&csT1Lock,   &ma);
        pthread_mutex_init(&csT2Lock,   &ma);
        pthread_mutex_init(&csSlowLock, &ma);
        pthread_mutexattr_destroy(&ma);
        hEventShutdn = CreateEvent(0,FALSE,FALSE,0);
        hEventDebug  = CreateEvent(0,FALSE,FALSE,0);
    }
    return self;
}

- (void) dealloc
{
    DestroyEvent(hEventDebug);
    DestroyEvent(hEventShutdn);
    pthread_mutex_destroy(&csSlowLock);
    pthread_mutex_destroy(&csT2Lock);
    pthread_mutex_destroy(&csT1Lock);
    pthread_mutex_destroy(&csIOLock);
    pthread_mutex_destroy(&csLcdLock);
    pthread_mutex_destroy(&csKeyLock);
    [super dealloc];
}

- (void) main
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    WorkerThread(nil);
//    if (pbyRom)
//    {
//        munmap(pbyRom, dwRomSize);
//        pbyRom = nil;
//    }
    [pool release];
}
@end
