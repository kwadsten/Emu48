//
//  lcd.h
//  emu48
//
//  Created by Da Woon Jung on Wed Feb 25 2004.
//  Copyright (c) 2004 dwj. All rights reserved.
//

@interface CalcLCDWriteArgument : NSObject
{
    unsigned char *pointer;
    uint32_t offset;
    uint32_t count;
}
- (id)initWithPointer:(unsigned char *)a offset:(uint32_t)d count:(uint32_t)s;
- (unsigned char *)pointer;
- (uint32_t)offset;
- (uint32_t)count;
@end


@protocol CalcLCD
- (id)initWithScale:(unsigned)aScale colors:(NSDictionary *)aColors;
- (void)UpdateContrast:(unsigned char)byContrast;
- (void)SetGrayscaleMode:(BOOL)bMode;

- (void)UpdateMain;
- (void)UpdateMenu;
- (void)RefreshDisp0;
- (void)WriteToMain:(CalcLCDWriteArgument *)args;
- (void)WriteToMenu:(CalcLCDWriteArgument *)args;
- (void)setInactiveOverlay:(BOOL)visible;
- (void)setInactiveOverlayDisplayRect:(NSRect)rect;
- (void)setInactiveOverlayDisplayCenter:(NSPoint)center;
@end

// Utility function for making a correctly-sized LCD
// extern CGSize computeLCDSize(unsigned scaleX, unsigned scaleY);
extern CGSize computeLCDSize(CGFloat scaleX, CGFloat scaleY);
