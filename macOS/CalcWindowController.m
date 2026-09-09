//
//  CalcWindowController.m
//  emu48
//
//  Created by Da Woon Jung on Wed Feb 18 2004.
//  Copyright (c) 2004 dwj. All rights reserved.
//

#import "CalcWindowController.h"
#import "CalcView.h"
#import "rawlcd.h"


@implementation CalcWindowController

- (id)init
{
    self = [super initWithWindowNibName:@"CalcWindow"];
    return self;
}

- (void)dealloc
{
    [kmlColors release];
    [super dealloc];
}


- (CalcView *)calcView
{
    return calcView;
}

- (BOOL)initDone
{
    return initDone;
}

- (void)setInitDone:(BOOL)value
{
    initDone = value;
}

- (NSSize)mainWindowSize
{
    return mainWindowSize;
}

- (void)setMainWindowSize:(NSSize)aSize
{
    mainWindowSize =  aSize;
    if(mainWindowSize.width>0.f && mainWindowSize.height>0.f)
        [[self window] setContentSize: mainWindowSize];
}

- (void)setMainBitmapOrigin:(NSPoint)aOrigin
{
    [calcView setMainBitmapOrigin: aOrigin];
}

- (NSPoint)lcdOrigin
{
    return lcdOrigin;
}

- (void)setLcdOrigin:(NSPoint)value
{
    lcdOrigin = value;
}

- (unsigned)lcdScale
{
    return lcdScale;
}

- (void)setLcdScale:(unsigned)value
{
    lcdScale = value;
}

//- (void)windowDidLoad
//{
//    if(mainWindowSize.width>0.f && mainWindowSize.height>0.f)
//        [[self window] setContentSize: mainWindowSize];
//}

- (void)finishInit
{
    [calcView setLCD: [[CalcRawLCD alloc] initWithScale:self.lcdScale colors:kmlColors] atOrigin:self.lcdOrigin];
    [calcView setLcdGrayscaleMode: YES];
    self.initDone = YES;
}

- (BOOL)mainBitmapDefined
{
    return (nil != [calcView mainBitmap]);
}

- (void)setMainBitmap:(NSImage *)aImage
{
    [calcView setMainBitmap: aImage];
}

- (void)setLcdColorAtIndex:(unsigned)nId red:(unsigned)nRed green:(unsigned)nGreen blue:(unsigned)nBlue
{
    if (nil == kmlColors)
        kmlColors = [[NSMutableDictionary alloc] initWithCapacity: 64];
#ifdef USE_BGRA
	KmlColors[nId&0x3F] = ((nRed&0xFF)<<16)|((nGreen&0xFF)<<8)|(nBlue&0xFF);
#else
    uint32_t c = 0xFF000000|((nBlue&0xFF)<<16)|((nGreen&0xFF)<<8)|((nRed&0xFF));
    NSNumber *color = [[NSNumber alloc] initWithUnsignedInt: c];
    NSNumber *index = [[NSNumber alloc] initWithUnsignedInt: (nId&0x3F)];
    [kmlColors setObject:color forKey:index];
    [color release];
    [index release];
//	KmlColors[nId&0x3F] = 0xFF000000|((nBlue&0xFF)<<16)|((nGreen&0xFF)<<8)|((nRed&0xFF));
#endif
//    [calcView SetLcdColorAtIndex:aIndex red:aRed green:aGreen blue:aBlue];
}

- (void)setAnnunciatorRect:(NSRect)aRect atIndex:(int)nId isOn:(BOOL)isOn
{
    [calcView setAnnunciatorRect:aRect atIndex:nId isOn:isOn];
}
@end
