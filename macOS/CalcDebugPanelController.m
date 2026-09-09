//
//  CalcDebugPanelController.m
//  emu48
//
//  Created by Da-Woon Jung on 2009-09-04.
//  Copyright 2009 dwj. All rights reserved.
//

#import "CalcDebugPanelController.h"
#import "CalcBreakpointPanelController.h"
#import "CalcDebugger.h"
#import "CalcBackend.h"
#import "ToggleToolbarItem.h"

@implementation CalcDebugPanelController

- (IBAction)cont:(id)sender
{
    [self setDebuggerRunning:YES];
    [[self debugModel] cont];
}

- (IBAction)editBreakpoints:(id)sender
{
    [self debugModel];
    [breakpointController showWindow: sender];
}

- (IBAction)fullResetCalc:(id)sender
{
}

- (IBAction)pauseDebug:(id)sender
{
    [[self debugModel] pause];
    [self setDebuggerRunning:NO];
}

- (IBAction)resetCalc:(id)sender
{
}

- (IBAction)setBreakpoint:(id)sender
{
    id sel = [disassemblyController selection];
    id breakpointStatus = [sel valueForKeyPath: @"breakpointStatus"];
    id code = [sel valueForKeyPath: @"code"];
    NSScanner *scanner = [NSScanner scannerWithString: code];
    unsigned hexResult = 0;
    if ([scanner scanHexInt: &hexResult])
    {
        CalcBreakpoint *breakpoint = [[[CalcBreakpoint alloc] init] autorelease];
        [breakpoint setAddress: [NSNumber numberWithUnsignedInt: hexResult]];
        switch ([breakpointStatus intValue])
        {
            case NSOnState:
            case NSOffState:
                break;
            default:
                [breakpointController addBreakpoint: breakpoint];
                break;
        }
    }
}

- (IBAction)stepInto:(id)sender
{
    [self setDebuggerRunning:YES];
    [[self debugModel] stepInto];
}

- (IBAction)stepOut:(id)sender
{
    [self setDebuggerRunning:YES];
    [[self debugModel] stepOut];
}

- (IBAction)stepOver:(id)sender
{
    [self setDebuggerRunning:YES];
    [[self debugModel] stepOver];
}

- (IBAction)showHistory:(id)sender
{
    [historyPanel makeKeyAndOrderFront: sender];
}

- (IBAction)showProfiler:(id)sender
{
    [profilerPanel makeKeyAndOrderFront: sender];
}

- (IBAction)showWoRegisters:(id)sender
{
    [woRegistersPanel makeKeyAndOrderFront: sender];
}

- (IBAction)toggleBreakpoints:(id)sender
{
    [toggleBreakpointsToolbarItem toolbarItemToggled];
    [[self debugModel] toggleBreakpoints];
}

// Translate clicks in first column of disassembly table to
// set/disable/remove breakpoint for an address
- (IBAction)breakpointClicked:(id)sender
{
    int row = [disassemblyTable selectedRow];
    if (row >= 0)
    {
        CalcBreakpoint *breakpoint;
        [disassemblyController setSelectionIndex: row];
        id sel = [disassemblyController selection];
        id breakpointStatus = [sel valueForKeyPath: @"breakpointStatus"];
        id code = [sel valueForKeyPath: @"code"];
        NSScanner *scanner = [NSScanner scannerWithString: code];
        unsigned hexResult = 0;
        if ([scanner scanHexInt: &hexResult])
        {
            breakpoint = [[[CalcBreakpoint alloc] init] autorelease];
            [breakpoint setAddress: [NSNumber numberWithUnsignedInt: hexResult]];
            switch ([breakpointStatus intValue])
            {
                case NSOnState:
                    [breakpointController addBreakpoint: breakpoint];
                    break;
                case NSOffState:
                    [breakpointController disableBreakpoint: breakpoint];
                    break;
                default:
                    [breakpointController removeBreakpoint: breakpoint];
                    break;
            }
        }
    }
}

- (IBAction)clearHistory:(id)sender
{
    [[self debugModel] clearHistory];
}


- (id)init
{
    self = [super initWithWindowNibName:@"Debugger"];

    if (self)
    {
        [self window];

        [self setDebugModel:
            [[CalcBackend sharedBackend] debugModel]];

        [self setDebuggerRunning:YES];

        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(debuggerDidPause:)
                   name:CalcDebuggerDidPauseNotification
                 object:debugModel];

        [breakpointArrayController
            addObserver:self
             forKeyPath:@"arrangedObjects.enabled"
                options:0
                context:nil];

        [self setWindowFrameAutosaveName:@"Debugger"];
        [historyPanel setFrameAutosaveName:@"History"];
        [profilerPanel setFrameAutosaveName:@"Profiler"];
        [woRegistersPanel setFrameAutosaveName:@"WoRegisters"];

        [self setDebuggerToolbar];
    }

    return self;
}

- (void)dealloc
{
    [breakpointArrayController removeObserver:self forKeyPath:@"arrangedObjects.enabled"];
    [toolbarIdList release];
    [toolbarLabelList release];
    [toolbarTooltipList release];
    [toolbarImageList release];
    
    [[NSNotificationCenter defaultCenter]
        removeObserver:self
                  name:CalcDebuggerDidPauseNotification
                object:debugModel];
    
    [super dealloc];
}

- (void)windowWillClose:(NSNotification *)notification
{
    if (!running)
        [[self debugModel] cont];
}

- (CalcDebugger *)debugModel
{
    if (nil == debugModel) {
        [self setDebugModel:
         [[CalcBackend sharedBackend] debugModel]];
    }

    return debugModel;
}

- (void)debuggerDidPause:(NSNotification *)notification
{
    [self setDebuggerRunning:NO];
}

- (void)setDebugModel:(CalcDebugger *)aDebugModel
{
    debugModel = aDebugModel;
    [debugController setContent:aDebugModel];
    [debugModel refresh];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    id sel = [object valueForKeyPath: @"selection"];
    if ([keyPath isEqualToString: @"arrangedObjects.enabled"])
    {
        id enabled = [sel valueForKeyPath: @"enabled"];
        id address = [sel valueForKeyPath: @"address"];
        if (NSBindingSelectionMarker.noSelectionMarker != enabled && address)
        {
            [[self debugModel] performSelectorOnMainThread:@selector(enableDebugger) withObject:nil waitUntilDone:NO];
        }
    }
}

- (void)setDebuggerRunning:(BOOL)value
{
    running = value;

    NSString *status = running ? @"Running..." : @"Paused...";

    [[self window] setTitle:
        [NSString stringWithFormat:@"Debugger — %@", status]];
}

#pragma mark -
#pragma mark Toolbar support

- (void)setDebuggerToolbar
{
    // Fill out constants
    toolbarIdList = [NSArray arrayWithObjects:
                     @"Pause", @"Cont", @"StepOver", @"StepInto", @"StepOut", @"ToggleBreakpoints",
                     nil];
    [toolbarIdList retain];
    toolbarLabelList = [NSArray arrayWithObjects:
                        @"Pause", @"Continue", @"Step Over", @"Step Into", @"Step Out", @"Disable Breakpoints",
                        nil];
    [toolbarLabelList retain];
    toolbarTooltipList = [NSArray arrayWithObjects:
                          @"Pause execution", @"Continue execution", @"Step over subroutine", @"Single step execution", @"Step out of current subroutine", @"Activate/Deactivate breakpoints",
                          nil];
    [toolbarTooltipList retain];
    toolbarImageList = [NSArray arrayWithObjects:
                        @"pause", @"continue", @"step_over", @"step_in", @"step_out", @"breakpoints_enabled",
                        nil];
    [toolbarImageList retain];

    NSToolbar *toolbar = [[NSToolbar alloc]initWithIdentifier:@"DebuggerToolbar"];
    [toolbar autorelease];
    [toolbar setDelegate:self];
    [toolbar setAllowsUserCustomization:YES];
    [toolbar setAutosavesConfiguration:YES];
    // Following will be overriden if a previous config exists
    [toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
    [[self window] setToolbar:toolbar];
}


- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar
     itemForItemIdentifier:(NSString *)itemIdentifier
 willBeInsertedIntoToolbar:(BOOL)flag
{
    id item = [[NSToolbarItem alloc] initWithItemIdentifier: itemIdentifier];

    NSString *toolid;
    NSString *tool_label;
    NSString *tool_tooltip;
    NSImage *tool_image;
    int i, toolcount=[toolbarIdList count];

    for (i=0; i<toolcount; ++i)
    {
        toolid = [toolbarIdList objectAtIndex: i];
        if ([itemIdentifier isEqualToString: toolid])
        {
            switch(i)
            {
                case kDebugToolPause:
                    [item setAction:@selector(pauseDebug:)];
                    break;

                case kDebugToolCont:
                    [item setAction:@selector(cont:)];
                    break;

                case kDebugToolStepOver:
                    [item setAction:@selector(stepOver:)];
                    break;

                case kDebugToolStepInto:
                    [item setAction:@selector(stepInto:)];
                    break;

                case kDebugToolStepOut:
                    [item setAction:@selector(stepOut:)];
                    break;
                case kDebugToolToggleBreakpoints:
                    [item release];
                    item = [[ToggleToolbarItem alloc] initWithItemIdentifier: itemIdentifier];
                    [item setAlternateImage: [NSImage imageNamed: @"breakpoints_disabled"]];
                    [item setAlternateLabel: NSLocalizedString(@"Enable Breakpoints",@"")];
                    [item setAction: @selector(toggleBreakpoints:)];
                    if (flag)
                        toggleBreakpointsToolbarItem = item;
                    break;
            }
            tool_label   = NSLocalizedString([toolbarLabelList objectAtIndex: i],@"");
            tool_tooltip = NSLocalizedString([toolbarTooltipList objectAtIndex: i],@"");
            tool_image   = [NSImage imageNamed:[toolbarImageList objectAtIndex: i]];
            if(nil!=tool_label)
                [item setLabel:tool_label];
            if(nil!=tool_tooltip)
                [item setToolTip:tool_tooltip];
            if (nil != tool_image)
            {
                [item setImage:tool_image];
            }
            [item setEnabled:NO];
            [item setTarget:self];
            [item setPaletteLabel:[item label]];
            break;
        }
    }
    
    return [item autorelease];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
    NSMutableArray *idlist = [[NSMutableArray alloc] initWithArray:toolbarIdList];
    [idlist addObject:NSToolbarSeparatorItemIdentifier];
    [idlist addObject:NSToolbarSpaceItemIdentifier];
    [idlist addObject:NSToolbarFlexibleSpaceItemIdentifier];
    [idlist addObject:NSToolbarCustomizeToolbarItemIdentifier];
    [idlist autorelease];
    return idlist;
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
    NSMutableArray *idlist = [[NSMutableArray alloc] initWithArray:toolbarIdList];
    [idlist insertObject:NSToolbarFlexibleSpaceItemIdentifier
                 atIndex:kDebugToolToggleBreakpoints];
    [idlist autorelease];

    return idlist;
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)item
{
    NSString *identifier = [item itemIdentifier];

    if ([identifier isEqualToString:@"Pause"])
        return running;

    if ([identifier isEqualToString:@"Cont"] ||
        [identifier isEqualToString:@"StepOver"] ||
        [identifier isEqualToString:@"StepInto"] ||
        [identifier isEqualToString:@"StepOut"])
        return !running;

    return YES;
}
@end
