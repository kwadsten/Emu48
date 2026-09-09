//
//  CalcPrefPanelController.h
//  emu48
//
//  Created by Da-Woon Jung on 2009-09-04.
//  Copyright 2009 dwj. All rights reserved.
//

#import "CalcGalleryController.h"

@class CalcPrefController;
@class CalcGalleryController;

@interface CalcPrefPanelController :
    NSWindowController <CalcGalleryControllerDelegate>
{
    IBOutlet NSView *startupView;
    IBOutlet NSView *settingsView;
    IBOutlet NSView *cardSizeView;
    IBOutlet NSPopUpButton *cardSizePopup;
    IBOutlet CalcPrefController *prefModel;
    IBOutlet NSMatrix *startupModeMatrix;

    CalcGalleryController *calculatorGallery;

    NSDictionary *views;
    NSArray *allIdentifiers;
    NSString *selectedIdentifier;
}

- (IBAction)prefBrowsePort2File:(id)sender;
- (IBAction)prefNewPort2File:(id)sender;
- (IBAction)prefReset:(id)sender;
- (IBAction)prefChangeStartupCalculator:(id)sender;

- (CalcPrefController *)prefModel;
- (void)switchToViewWithIdentifier:(NSString *)aIdentifier;

@end
