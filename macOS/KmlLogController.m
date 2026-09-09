/*
 *  KmlLogController.m
 *  emu48
 *
 *  Created by Da Woon Jung on 2009-01-21.
 *  Copyright (c) 2009 dwj. All rights reserved.
 *
 */
#import "KmlLogController.h"

#define KML_LOG_TOOLBAR_ID      @"KML_LOG_TOOLBAR"
#define KML_LOG_CLEAR_ID        @"Clear Log"
#define KML_LOG_CLEAR_ID_ICON   @"clear_log"

@interface KmlLogController(Private)
- (void)setupToolbar;
@end


@implementation KmlLogController
- (id) init
{
    self = [super initWithWindowNibName: @"KmlLogWindow" ];
    if (self)
    {
        [self setWindowFrameAutosaveName: @"KmlLogWindow"];
    }
    return self;
}

/*
- (void)setTitle: (NSString *)aTitle
{
    [kmlTitle setStringValue: aTitle];
    [kmlTitle setNeedsDisplay];
}

- (void)setAuthor: (NSString *)aAuthor
{
    [kmlAuthor setStringValue: aAuthor];
    [kmlAuthor setNeedsDisplay];
}
*/

- (void)clearLog:(id)aSender
{
    [kmlLog selectAll: self];
    [kmlLog setEditable: YES];
    [kmlLog delete: self];
    [kmlLog setEditable: NO];
}

- (void)appendLog: (NSString *)aLogmsg
{
    NSTextStorage *storage = nil;
    if (kmlLog)
    {
        storage = [kmlLog textStorage];
        NSAttributedString *logStr = [[NSAttributedString alloc] initWithString: aLogmsg];
        [storage appendAttributedString: logStr];
        [logStr release];
        logStr = [[NSAttributedString alloc] initWithString: @"\n"];
        [storage appendAttributedString: logStr];
        [logStr release];
    }
}


#pragma mark -
#pragma mark Internal methods

- (void)windowDidLoad
{
    if (nil == [[self window] toolbar])
        [self setupToolbar];
}

- (void)setupToolbar
{
    NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier: KML_LOG_TOOLBAR_ID];
    [toolbar setDisplayMode: NSToolbarDisplayModeIconOnly];
    [toolbar setAllowsUserCustomization: YES];
    [toolbar setAutosavesConfiguration:  YES];
    [toolbar setDelegate: self];
    [[self window] setToolbar: toolbar];
    [toolbar release];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)aToolbar
     itemForItemIdentifier:(NSString *)aId
 willBeInsertedIntoToolbar:(BOOL)aFlag
{
    NSToolbarItem *item = nil;
    if ([aId isEqualToString: KML_LOG_CLEAR_ID])
    {
        item = [[[NSToolbarItem alloc] initWithItemIdentifier: aId] autorelease];
        NSString *label = NSLocalizedString(aId,@"");
        [item setLabel: label]; [item setPaletteLabel: label];
        [item setImage: [NSImage imageNamed: KML_LOG_CLEAR_ID_ICON]];
        [item setTarget: self]; [item setAction: @selector(clearLog:)];
    }

    return item;
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)aToolbar
{
    return [NSArray arrayWithObjects:
            KML_LOG_CLEAR_ID,
            NSToolbarCustomizeToolbarItemIdentifier,
            NSToolbarFlexibleSpaceItemIdentifier,
            NSToolbarSpaceItemIdentifier,
            NSToolbarSeparatorItemIdentifier,
            nil];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)aToolbar
{
    return [NSArray arrayWithObjects:
            NSToolbarFlexibleSpaceItemIdentifier,
            KML_LOG_CLEAR_ID,
            nil];
}
@end
