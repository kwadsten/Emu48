//
//  CalcViewController.h
//  emu48
//
//  Created by Da Woon Jung on Wed Feb 18 2004.
//  Copyright (c) 2004 dwj. All rights reserved.
//

@class CalcView;


@interface CalcWindowController : NSWindowController
{
    IBOutlet CalcView *calcView;
    BOOL initDone;
    NSSize mainWindowSize;
    NSPoint  lcdOrigin;
    unsigned lcdScale;
    NSMutableDictionary *kmlColors;
}
- (CalcView *)calcView;
- (BOOL)initDone;
- (void)setInitDone:(BOOL)aDone;
- (NSSize)mainWindowSize;
- (void)setMainWindowSize:(NSSize)aSize;
- (void)setMainBitmapOrigin:(NSPoint)aOrigin;
- (NSPoint)lcdOrigin;
- (void)setLcdOrigin:(NSPoint)aOrigin;
- (unsigned)lcdScale;
- (void)setLcdScale:(unsigned)aScale;

- (void)finishInit;
- (BOOL)mainBitmapDefined;
- (void)setMainBitmap:(NSImage *)aImage;
- (void)setLcdColorAtIndex:(unsigned)aIndex red:(unsigned)aRed green:(unsigned)aGreen blue:(unsigned)aBlue;
- (void)setAnnunciatorRect:(NSRect)aRect atIndex:(int)nId isOn:(BOOL)isOn;
@end
