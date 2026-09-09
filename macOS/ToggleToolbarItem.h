//
//  ToggleToolbarItem.h
//  emu48
//
//  Toolbar item that toggles between two states.
//  Call -toolbarItemToggled to toggle states.
//
//  Created by Da-Woon Jung on 2009-09-17.
//  Copyright 2009 dwj. All rights reserved.
//


@interface ToggleToolbarItem : NSToolbarItem
{
    NSImage  *originalImage;
    NSImage  *alternateImage;
    NSString *originalLabel;
    NSString *alternateLabel;
}
- (void)setAlternateImage:(NSImage *)aAlternateImage;
- (NSImage *)alternateImage;
- (void)setAlternateLabel:(NSString *)aAlternateLabel;
- (NSString *)alternateLabel;
- (void)toolbarItemToggled;
@end
