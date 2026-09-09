//
//  CalcBreakpointPanelController.h
//  emu48
//
//  Created by Da-Woon Jung on 2009-09-14.
//  Copyright 2009 dwj. All rights reserved.
//

@class CalcBreakpoint;

@interface CalcBreakpointPanelController : NSWindowController
{
    IBOutlet NSArrayController *breakpointController;
    IBOutlet NSPanel *breakpointPanel;
    IBOutlet NSTableView *breakpointTable;
}
- (IBAction)breakpointAdd:(id)sender;
- (void)addBreakpoint:(CalcBreakpoint *)aBreakpoint;
- (void)disableBreakpoint:(CalcBreakpoint *)aBreakpoint;
- (void)removeBreakpoint:(CalcBreakpoint *)aBreakpoint;
- (void)textDidEndEditing:(NSNotification *)aNotification;
@end
