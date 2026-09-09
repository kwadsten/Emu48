//
//  ToggleToolbarItem.m
//  emu48
//
//  Created by Da-Woon Jung on 2009-09-17.
//  Copyright 2009 dwj. All rights reserved.
//

#import "ToggleToolbarItem.h"


@implementation ToggleToolbarItem

- (id)copyWithZone:(NSZone *)zone
{
    id copy = [super copyWithZone: zone];
    [copy setImage: [self image]];
    [copy setLabel: [self label]];
    [copy setAlternateImage: [self alternateImage]];
    [copy setAlternateLabel: [self alternateLabel]];
    return copy;
}

- (void)dealloc
{
    [alternateImage release];
    [alternateLabel release];
    [super dealloc];
}

- (void)setAlternateImage:(NSImage *)aAlternateImage
{
    [alternateImage release];
    alternateImage = [aAlternateImage retain];
}

- (NSImage *)alternateImage
{
    return alternateImage;
}

- (void)setAlternateLabel:(NSString *)aAlternateLabel
{
    [alternateLabel release];
    alternateLabel = [aAlternateLabel retain];
}

- (NSString *)alternateLabel
{
    return alternateLabel;
}

- (void)toolbarItemToggled
{
    if (alternateImage == [self image])
    {
        [self setImage: originalImage];
        [self setLabel: originalLabel];
    }
    else
    {
        originalImage = [self image];
        originalLabel = [self label];
        [self setImage: [self alternateImage]];
        [self setLabel: [self alternateLabel]];
    }
}
@end
