/*
 *  CalcAppController
 *  emu48
 *
 *  This is the application (NSApp) delegate class.
 *
 *  Created by Da Woon Jung on Sat Feb 21 2004.
 *  Copyright (c) 2004 dwj. All rights reserved.
 */

#import "CalcView.h"
#import "CalcGalleryController.h"

enum {
//    kCmdNewMemCard = 128,
//    kCmdOpenROM,
//    kCmdSaveObject,
//    kCmdSaveFlash,
//    kCmdShowDebugger,
    kCmdFullReset = 142
};

@class CalcBackend;
@class CalcDebugPanelController;
@class CalcDocumentController;
@class CalcPrefPanelController;
@class KmlLogController;
@class CalcGalleryController;


@interface CalcAppController :
    NSObject <CalcGalleryControllerDelegate>
{
//    CalcDebugger *debugger;
    IBOutlet NSMenu *newCalcMenu;
    IBOutlet NSMenu *kmlMenu;
    NSMenu *zoomMenu;
    CalcDocumentController   *documentController;
    CalcPrefPanelController  *prefController;
    CalcDebugPanelController *debugger;
    KmlLogController *kmlLogController;
    NSArray *filesToOpen;
    CalcGalleryController *calculatorGallery;
    NSMenuItem *newStartupCalculatorItem;
    BOOL handlingStartup;
}
- (IBAction)openROM:(id)sender;
- (IBAction)showDebugger:(id)sender;
- (IBAction)editBreakpoints:(id)sender;
- (IBAction)showHistory:(id)sender;
- (IBAction)showPrefs:(id)sender;
- (IBAction)showProfiler:(id)sender;
- (IBAction)showWoRegisters:(id)sender;
- (IBAction)turnOnCalc:(id)sender;
- (IBAction)setZoom:(id)sender;

- (IBAction)newCalculatorWithChooser:(id)sender;
- (IBAction)newCalculatorWithStartupCalculator:(id)sender;

- (KmlLogController *)kmlLogController;
- (void)populateNewCalcMenu;
- (void)populateChangeKmlMenu;

- (void)reviewChangesAndQuitEnumeration:(NSNumber *)cont;
- (void)reviewChangesAndOpenEnumeration:(NSNumber *)cont;
- (void)application:(NSApplication *)application
          openFiles:(NSArray *)filenames;

- (void)showCalculatorGalleryIfNeeded;
- (void)setCalculatorGallery:(CalcGalleryController *)gallery;
@end
