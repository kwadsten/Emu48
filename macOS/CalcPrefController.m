//
//  CalcPrefController.m
//  emu48
//
//  Created by Da-Woon Jung on Thu Feb 19 2004.
//  Copyright (c) 2004 dwj. All rights reserved.
//
#import "CalcPrefController.h"
#import "pch.h"
#import "EMU48.H"
#import "IO.H"
#import "files.h"
#import "kmlparser.h"
#import "CalcManager.h"

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 30000
#import <MobileCoreServices/MobileCoreServices.h>
#endif

@interface CalcPrefController(Private)
- (void)refreshPort1WithPluggedStatus:(BOOL)isPlugged writeable:(BOOL)isWriteable;
- (void)refreshPort2WithFilename:(NSString *)aFilename;
- (void)refreshCalculators:(id)aArg;
@end


@implementation CalcPrefController

- (id)init
{
    self = [super init];
    if (self)
    {
        calcManager = [[CalcManager sharedManager] retain];
        
        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(userDefaultsDidChange:)
                   name:NSUserDefaultsDidChangeNotification
                 object:[NSUserDefaults standardUserDefaults]];
    }
    return self;
}

- (void)dealloc
{
    [calcManager release];

    [[NSNotificationCenter defaultCenter]
        removeObserver:self
            name:NSUserDefaultsDidChangeNotification
          object:[NSUserDefaults standardUserDefaults]];
    
    [super dealloc];
}

- (void)userDefaultsDidChange:(NSNotification *)notification
{
    [self willChangeValueForKey:@"AlwaysDisplayLog"];
    [self didChangeValueForKey:@"AlwaysDisplayLog"];
}

+ (void)registerDefaults
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults: [CalcPrefController cleanDefaults]];
}

+ (NSDictionary *)cleanDefaults
{
    NSString *errorDesc = nil;
    NSPropertyListFormat format;
    NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"defaults" ofType:@"plist"];
    NSData *plistData = [[NSFileManager defaultManager] contentsAtPath:plistPath];
    NSDictionary *defaults = (NSDictionary *)[NSPropertyListSerialization propertyListFromData:plistData mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&errorDesc];
    return defaults;
}

+ (void)resetDefaults
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *cleanDefaults = [CalcPrefController cleanDefaults];
    NSEnumerator *keyEnum = [cleanDefaults keyEnumerator];
    NSString *key;
    while ((key = [keyEnum nextObject]))
    {
        [defaults setObject:[cleanDefaults objectForKey:key] forKey:key];
    }
}

/*
+ (NSDictionary *)volatileDefaults
{
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithBool:NO],  @"Port1Plugged",
            [NSNumber numberWithBool:NO],  @"Port1Writeable",
            [NSNumber numberWithBool:NO],  @"Port1Enabled",
            [NSNumber numberWithBool:NO],  @"Port2Enabled",
            nil];
}
*/

- (int)StartupMode
{
    return [[CalcManager sharedManager] StartupMode];
}

- (void)setStartupMode:(int)aMode
{
    [[CalcManager sharedManager] setStartupMode:aMode];
}

- (NSString *)StartupCalculator
{
    return [[NSUserDefaults standardUserDefaults]
        stringForKey:@"StartupCalculator"];
}

- (void)setStartupCalculator:(NSString *)value
{
    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    if (value && [value length] > 0)
    {
        [defaults setObject:value
                     forKey:@"StartupCalculator"];
    }
    else
    {
        [defaults removeObjectForKey:@"StartupCalculator"];
    }

    [[NSNotificationCenter defaultCenter]
        postNotificationName:@"StartupCalculatorDidChange"
                      object:self];
}

- (NSDictionary *)startupCalculator
{
    NSString *startupPath =
        [self StartupCalculator];

    if (!startupPath || [startupPath length] == 0)
        return nil;

    NSArray *allCalcs =
        [self calculators];

    for (NSDictionary *calc in allCalcs)
    {
        if ([[calc objectForKey:@"path"]
             isEqualToString:startupPath])
        {
            return calc;
        }
    }

    return nil;
}

- (NSString *)StartupCalculatorName
{
    NSDictionary *calc =
        [[CalcManager sharedManager] startupCalculator];

    if (!calc)
        return @"Use calculator:";

    NSString *title =
        [calc objectForKey:@"title"];

    if (!title || [title length] == 0)
        return @"Use calculator:";

    return [NSString stringWithFormat:
        @"Use calculator: %@", title];
}

+ (NSSet *)keyPathsForValuesAffectingStartupCalculatorName
{
    return [NSSet setWithObject:@"StartupCalculator"];
}

#define USERDEFAULTS_ACCESSOR_BOOL(n)  -(BOOL)n{return [[NSUserDefaults standardUserDefaults] boolForKey:@#n];} \
    -(void)set##n:(BOOL)value{[[NSUserDefaults standardUserDefaults] setBool:value forKey:@#n];}

#define USERDEFAULTS_ACCESSOR_INT(n)   -(int)n{return [[NSUserDefaults standardUserDefaults] integerForKey:@#n];} \
    -(void)set##n:(int)value{[[NSUserDefaults standardUserDefaults] setInteger:value forKey:@#n];}

USERDEFAULTS_ACCESSOR_BOOL(RealSpeed)
USERDEFAULTS_ACCESSOR_BOOL(Grayscale)
USERDEFAULTS_ACCESSOR_BOOL(AlwaysOnTop)
USERDEFAULTS_ACCESSOR_BOOL(AutoSaveOnExit)
USERDEFAULTS_ACCESSOR_BOOL(ReloadFiles)
USERDEFAULTS_ACCESSOR_BOOL(LoadObjectWarning)
//USERDEFAULTS_ACCESSOR_BOOL(AlwaysDisplayLog)
USERDEFAULTS_ACCESSOR_BOOL(RomWriteable)
USERDEFAULTS_ACCESSOR_INT(Mnemonics)
USERDEFAULTS_ACCESSOR_INT(WaveBeep)

- (BOOL)AlwaysDisplayLog
{
    return [[NSUserDefaults standardUserDefaults]
            boolForKey:@"AlwaysDisplayLog"];
}

- (void)setAlwaysDisplayLog:(BOOL)value
{
    [[NSUserDefaults standardUserDefaults]
        setBool:value
        forKey:@"AlwaysDisplayLog"];
}

- (float)WaveVolume { return [[NSUserDefaults standardUserDefaults] floatForKey: @"WaveVolume"]; }
- (void)setWaveVolume:(float)value { [[NSUserDefaults standardUserDefaults] setFloat:value forKey:@"WaveVolume"]; }

- (BOOL)Port1Plugged
{
    if (cCurrentRomType=='S' || cCurrentRomType=='G' || cCurrentRomType==0)
    {
        return ((Chipset.cards_status & PORT1_PRESENT) != 0);
    }
    return NO;
}
- (BOOL)Port1Writeable
{
    if (cCurrentRomType=='S' || cCurrentRomType=='G' || cCurrentRomType==0)
    {
        return ((Chipset.cards_status & PORT1_WRITE) != 0);
    }
    return NO;
}
- (BOOL)Port2IsShared
{
    return [[NSUserDefaults standardUserDefaults] boolForKey: @"Port2IsShared"];
}
- (NSString *)Port2Filename
{
    return [[NSUserDefaults standardUserDefaults] stringForKey: @"Port2Filename"];
}

- (BOOL)Port1Enabled
{
    if (cCurrentRomType=='S' || cCurrentRomType=='G' || cCurrentRomType==0)
    {
        if (nState != SM_INVALID)		// Invalid State
            return YES;
    }
    return NO;
}
- (BOOL)Port2Enabled
{
    if (cCurrentRomType=='S' || cCurrentRomType=='G' || cCurrentRomType==0)
    {
        return YES;
    }
    return NO;
}
- (void)setPort1Plugged:(BOOL)value
{
    [self refreshPort1WithPluggedStatus:value writeable:[self Port1Writeable]];
}
- (void)setPort1Writeable:(BOOL)value
{
    [self refreshPort1WithPluggedStatus:[self Port1Plugged] writeable:value];
}
- (void)setPort2IsShared:(BOOL)value
{
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:@"Port2IsShared"];
    [self refreshPort2WithFilename: [self Port2Filename]];
}
- (void)setPort2Filename:(NSString *)value
{
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:@"Port2Filename"];
    [self refreshPort2WithFilename: value];
}
- (void)setPort1Enabled:(BOOL)value
{
}
- (void)setPort2Enabled:(BOOL)value
{
}
- (void)refreshPort1WithPlugged:(BOOL)isPlugged writeable:(BOOL)isWriteable
{
    if (Chipset.Port1Size && (cCurrentRomType!='X' || cCurrentRomType!='2' || cCurrentRomType!='Q'))   // CdB for HP: add apples
    {
        UINT nOldState = SwitchToState(SM_SLEEP);
        // save old card status
        BYTE bCardsStatus = Chipset.cards_status;

        // port1 disabled?
        Chipset.cards_status &= ~(PORT1_PRESENT | PORT1_WRITE);
        if (isPlugged)
        {
            Chipset.cards_status |= PORT1_PRESENT;
            if (isWriteable)
                Chipset.cards_status |= PORT1_WRITE;
        }

        // changed card status in slot1?
        if (   ((bCardsStatus ^ Chipset.cards_status) & (PORT1_PRESENT | PORT1_WRITE)) != 0
            && (Chipset.IORam[CARDCTL] & ECDT) != 0 && (Chipset.IORam[TIMER2_CTRL] & RUN) != 0
            )
        {
            Chipset.HST |= MP;			// set Module Pulled
            IOBit(SRQ2,NINT,FALSE);		// set NINT to low
            Chipset.SoftInt = TRUE;		// set interrupt
            bInterrupt = TRUE;
        }
        SwitchToState(nOldState);
    }
}
- (void)refreshPort2WithFilename:(NSString *)aFilename
{
    UINT nOldState = SwitchToState(SM_INVALID);

    UnmapPort2();				// unmap port2

    if (cCurrentRomType)		// ROM defined
    {
        MapPort2([aFilename UTF8String]);

        // port2 changed and card detection enabled
        if (   (Chipset.wPort2Crc != wPort2Crc)
            && (Chipset.IORam[CARDCTL] & ECDT) != 0 && (Chipset.IORam[TIMER2_CTRL] & RUN) != 0
            )
        {
            Chipset.HST |= MP;		// set Module Pulled
            IOBit(SRQ2,NINT,FALSE);	// set NINT to low
            Chipset.SoftInt = TRUE;	// set interrupt
            bInterrupt = TRUE;
        }
        // save fingerprint of port2
        Chipset.wPort2Crc = wPort2Crc;
    }
    SwitchToState(nOldState);
}

+ (NSArray *)calculatorsAtPath:(NSString *)aPath
                relativeToPath:(NSString *)base
{
    return [CalcManager calculatorsAtPath:aPath
                           relativeToPath:base];
}

- (NSMutableArray *)calculators
{
    return [calcManager calculators];
}

- (void)setCalculators:(NSArray *)aCalculators
{
    [calcManager setCalculators:aCalculators];
}

- (void)refreshCalculators:(id)aArg
{
    [calcManager refreshCalculators:aArg];
}


@end
