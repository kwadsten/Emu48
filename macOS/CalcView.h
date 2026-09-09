//
//  CalcView.h
//  emu48
//
//  A container for the calc background, lcd, annunciators,
//  and button redrawing operations. This is the calc UI.
//
//  Created by Da Woon Jung on Wed Feb 18 2004.
//  Copyright (c) 2004 dwj. All rights reserved.
//
#import "lcd.h"
#import "MacWinAPIPatch.h"


@interface CalcView : NSView
{
    CalcPoint mainBitmapOrigin;
    CalcImage *mainBitmap;
    NSView<CalcLCD> *lcd;	// may be initialized with different kinds of lcds
    NSTimer *uLcdTimerId;
    NSTimer *bwLcdTimer;
    LARGE_INTEGER    lLcdRef;			// reference time for VBL counter
    
    NSRect annunciatorRect[6];       // KML Offset - destination
    NSRect annunciatorOn[6];         // KML Down - ON source
    NSRect annunciatorOff[6];        // KML Offset - OFF source
    NSRect annunciatorOffSource[6];
    
    CalcPoint backgroundOrigin;
    
    BOOL     annunciatorStates[6];
    BOOL     drawingButtonPressed;
    UINT     drawingButtonType;
    CalcRect drawingButtonRect;
    CalcRect drawingButtonRectPressed;
    CGFloat uiZoom;
    CalcSize backgroundSize;
    CalcPoint lcdOrigin;
    NSSize lcdNativeSize;
    BOOL inactiveOverlay;
    NSButton *infoButton;
    NSDictionary *calcInfo;
}
+ (CalcImage *)CreateMainBitmap:(NSString *)filename;
+ (CalcImage *)scaleMainBitmap:(CalcImage *)source mul:(unsigned)mul div:(unsigned)div;
//- (void)setMainBitmapOrigin:(NSPoint)aOrigin;
- (void)setMainBitmap:(CalcImage *)aImage atOrigin:(CalcPoint)aOrigin size:(CalcSize)aSize;
- (CalcImage *)mainBitmap;

- (void)setLCD:(NSView<CalcLCD> *)lcd  atOrigin:(CalcPoint)origin;
- (void)setLcdGrayscaleMode:(BOOL) isGrayscale;
- (void)setAnnunciatorRect:(CalcRect)aRect atIndex:(int)nId isOn:(BOOL)isOn;

// Starts periodic LCD updates
- (void)StartDisplay:(NSNumber *)byInitial;
- (void)StopDisplay;
// Called by the engine, passed on to the lcd
- (void)UpdateDisplayPointers;
- (void)UpdateMainDisplay;
- (void)UpdateMenuDisplay;
- (void)RefreshDisp0;
- (void)WriteToMain:(CalcLCDWriteArgument *)args;
- (void)WriteToMenu:(CalcLCDWriteArgument *)args;
- (void)UpdateAnnunciators;
- (void)buttonDrawing;
- (void)setInactiveOverlay:(BOOL)visible;
- (void)setCalcInfo:(NSDictionary *)info;

// UI Zoom
- (CGFloat)uiZoom;
- (void)setUIZoomPercent:(CGFloat)percent;
- (NSSize)zoomedContentSize;
- (NSSize)nativeContentSize;
@end
