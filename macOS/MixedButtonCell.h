//
//  MixedButtonCell.h
//  emu48
//
//  A button cell that supports 3 images (on/off/mixed)
//
//  Created by Da-Woon Jung on 2009-09-21.
//  Copyright 2009 dwj. All rights reserved.
//


@interface MixedButtonCell : NSButtonCell
{
    NSImage *mixedImage;
}
- (NSImage *)mixedImage;
- (void)setMixedImage:(NSImage *)aImage;
@end
