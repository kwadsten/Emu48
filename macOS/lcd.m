//
//  lcd.m
//  emu48
//
//  Created by Da Woon Jung on Wed Feb 25 2004.
//  Copyright (c) 2004 dwj. All rights reserved.
//

#import "lcd.h"
#import "pch.h"
#import "EMU48.H"

#define LCD_WIDTH   131.

// v1.68 changes
//CGSize computeLCDSize(unsigned scaleX, unsigned scaleY)
//{
//    return CGSizeMake(scaleX * LCD_WIDTH,
//                      scaleY * SCREENHEIGHT);
//}

// v1.68 changes
CGSize computeLCDSize(CGFloat scaleX, CGFloat scaleY)
{
    return CGSizeMake(scaleX * LCD_WIDTH,
                      scaleY * SCREENHEIGHT);
}

@implementation CalcLCDWriteArgument
- (id)initWithPointer:(unsigned char *)a offset:(uint32_t)d count:(uint32_t)s
{
    self = [super init];
    pointer = a;
    offset  = d;
    count   = s;
    return self;
}
- (unsigned char *)pointer { return pointer; }
- (uint32_t)offset { return offset; }
- (uint32_t)count  { return count; }
@end
