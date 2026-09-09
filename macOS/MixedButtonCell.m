//
//  MixedButtonCell.m
//  emu48
//
//  Created by Da-Woon Jung on 2009-09-21.
//  Copyright 2009 dwj. All rights reserved.
//

#import "MixedButtonCell.h"


@implementation MixedButtonCell

- (void)dealloc
{
    [mixedImage release];
    [super dealloc];
}

- (NSImage *)mixedImage
{
    return mixedImage;
}
- (void)setMixedImage:(NSImage *)aImage
{
    [mixedImage release];
    mixedImage = [aImage retain];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    NSImage *img = nil;
    int state = [self state];
    switch (state)
    {
        case NSOnState:
            img = [self image];
            break;
        case NSOffState:
            img = [self alternateImage];
            break;
        case NSMixedState:
            img = [self mixedImage];
            break;
        default:
            break;
    }
    
    if (img != nil)
    {
        NSSize	imageSize;
        NSRect	imageFrame;
        
        imageSize = [img size];
        NSDivideRect(cellFrame, &imageFrame, &cellFrame, 3 + imageSize.width, NSMinXEdge);
        imageFrame.origin.x += 3;
        imageFrame.size = imageSize;
        
        if ([controlView isFlipped])
            imageFrame.origin.y += ceil((cellFrame.size.height + imageFrame.size.height) / 2);
        else
            imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2);
        
        [img compositeToPoint:imageFrame.origin operation:NSCompositeSourceOver];
    }
}
@end
