//
//  CalcAppController.m
//  emu48
//
//  Created by Da Woon Jung on 2009-01-22.
//  Copyright (c) 2009 dwj. All rights reserved.
//

#import "CalcAppController.h"
#import "CalcBackend.h"
#import "CalcDocument.h"
#import "KmlLogController.h"
#import "CalcPrefPanelController.h"
#import "CalcPrefController.h"
#import "CalcDebugPanelController.h"
#import "EMU48.H"
#import "CalcGalleryController.h"
#import "CalcManager.h"

VOID UpdateWindowStatus(VOID){}

@interface CalcAppController(Private)
- (CalcPrefPanelController *)prefController;
@end


@implementation CalcAppController

- (IBAction)openROM:(id)sender
{
    int result;
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    [oPanel setResolvesAliases: YES];
    [oPanel setAllowsMultipleSelection: NO];
    result = [oPanel runModalForTypes: nil];
}

- (IBAction)showDebugger:(id)sender
{
    if (nil==debugger)
        debugger = [[CalcDebugPanelController alloc] init];
    [debugger showWindow: sender];
}

- (IBAction)editBreakpoints:(id)sender
{
    if (nil==debugger)
        debugger = [[CalcDebugPanelController alloc] init];
    [debugger editBreakpoints: sender];
}

- (IBAction)showHistory:(id)sender
{
    if (nil==debugger)
        debugger = [[CalcDebugPanelController alloc] init];
    [debugger showHistory: sender];
}

- (IBAction)showPrefs:(id)sender
{
    [[self prefController] showWindow: sender];
}

- (IBAction)showProfiler:(id)sender
{
    if (nil==debugger)
        debugger = [[CalcDebugPanelController alloc] init];
    [debugger showProfiler: sender];
}

- (IBAction)showWoRegisters:(id)sender
{
    if (nil==debugger)
        debugger = [[CalcDebugPanelController alloc] init];
    [debugger showWoRegisters: sender];
}

- (IBAction)turnOnCalc:(id)sender
{
    [[CalcBackend sharedBackend] onPowerKey];
}


- (void) dealloc
{
    [debugger release];
    [filesToOpen release];
    [kmlLogController release];
    [prefController release];
    [documentController release];
    [calculatorGallery release];
    
    [[NSNotificationCenter defaultCenter]
        removeObserver:self
            name:@"StartupCalculatorDidChange"
          object:nil];
    
    [newStartupCalculatorItem release];
    
    [super dealloc];
}


- (CalcPrefPanelController *)prefController
{
    if (nil==prefController)
        prefController = [[CalcPrefPanelController alloc] init];
    return prefController;
}

- (KmlLogController *)kmlLogController;
{
    if (nil == kmlLogController)
    {
        kmlLogController = [[KmlLogController alloc] init];
        [kmlLogController window];
    }
    return kmlLogController;
}


#pragma mark -
#pragma mark NSApplication delegate methods

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
    [CalcPrefController registerDefaults];
    documentController = [[CalcDocumentController alloc] init];
    [self populateNewCalcMenu];
    [self populateZoomMenu];
    
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:
                @selector(startupCalculatorDidChange:)
                name:@"StartupCalculatorDidChange"
                object:[CalcManager sharedManager]];
}

- (void)applicationDidBecomeActive:(NSNotification *)aNotification
{
    SetApplicationActive(TRUE);

    CalcView *view = [[CalcBackend sharedBackend] calcView];
    [view setInactiveOverlay:NO];

    [self populateNewCalcMenu];
}

- (void)applicationDidResignActive:(NSNotification *)notification
{
    SetApplicationActive(FALSE);
    
    CalcView *view = [[CalcBackend sharedBackend] calcView];
    [view setInactiveOverlay:YES];
    
}

- (void)reviewChangesAndQuitEnumeration:(NSNumber *)cont
{
    [NSApp replyToApplicationShouldTerminate: [cont boolValue]];
}

- (void)reviewChangesAndOpenEnumeration:(NSNumber *)cont
{
    if ([cont boolValue] && filesToOpen)
    {
        [self application:NSApp openFiles:filesToOpen];
    }
    [filesToOpen release]; filesToOpen = nil;
}

- (BOOL)applicationOpenUntitledFile:(NSApplication *)app
{
    return NO;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)app
                    hasVisibleWindows:(BOOL)flag
{
    return NO;
}


#pragma mark -
#pragma mark Dynamic menus

- (void)populateNewCalcMenu
{
    [newCalcMenu setMenuChangedMessagesEnabled:NO];

    [newStartupCalculatorItem release];
    newStartupCalculatorItem = nil;
    
    while ([newCalcMenu numberOfItems] > 0)
        [newCalcMenu removeItemAtIndex:0];

    /*
     * New Calculator with Chooser
     */
    NSMenuItem *chooserItem =
        [[NSMenuItem alloc]
            initWithTitle:@"New Calculator with Chooser"
            action:@selector(newCalculatorWithChooser:)
            keyEquivalent:@"n"];

    [chooserItem setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
    [chooserItem setTarget:self];
    [newCalcMenu addItem:chooserItem];
    [chooserItem release];

    /*
     * New Calculator with Startup Calculator
     */
    NSDictionary *startupCalc =
        [[CalcManager sharedManager] startupCalculator];

    NSString *startupTitle = nil;

    if (startupCalc)
    {
        startupTitle =
            [startupCalc objectForKey:@"title"];
    }

    NSString *title;

    if (startupTitle && [startupTitle length] > 0)
    {
        title =
            [NSString stringWithFormat:
                @"New Calculator with Startup Calculator: %@",
                startupTitle];
    }
    else
    {
        title =
            @"New Calculator with Startup Calculator: None";
    }

    newStartupCalculatorItem =
        [[NSMenuItem alloc]
            initWithTitle:title
                   action:
                       @selector(
                           newCalculatorWithStartupCalculator:)
              keyEquivalent:@""];

    [newStartupCalculatorItem setTarget:self];
    [newStartupCalculatorItem setKeyEquivalent:@"n"];
    [newStartupCalculatorItem setKeyEquivalentModifierMask:
     NSEventModifierFlagCommand | NSEventModifierFlagOption];

    if (startupCalc)
    {
        NSString *path =
            [startupCalc objectForKey:@"path"];

        if (![path isAbsolutePath])
        {
            path =
                [[[NSBundle mainBundle] resourcePath]
                    stringByAppendingPathComponent:path];
        }

        [newStartupCalculatorItem setRepresentedObject:path];
    }

    [newCalcMenu addItem:newStartupCalculatorItem];
    [newCalcMenu setMenuChangedMessagesEnabled:YES];
}

- (void)populateChangeKmlMenu
{
    CalcBackend *backend = [CalcBackend sharedBackend];
    [kmlMenu setMenuChangedMessagesEnabled: NO];
    int i;
    int kmlCount = [kmlMenu numberOfItems];
    for (i = 0; i < kmlCount; ++i)
        [kmlMenu removeItemAtIndex: 0];
    NSArray *calculators = [[[self prefController] prefModel] calculators];
    NSDictionary *calc;
    id model;
    NSString *currentModel = [backend currentModel];
    NSString *calcPath;
    NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    SEL changeKmlAction = @selector(changeKml:);
    kmlCount = [calculators count];
    for (i = 0; i < kmlCount; ++i)
    {
        calc  = [calculators objectAtIndex: i];
        model = [calc objectForKey: @"model"];
        if (![model isEqualToString: currentModel])
            continue;
        calcPath = [calc objectForKey: @"path"];
        if (![calcPath isAbsolutePath])
        {
            calcPath = [resourcePath stringByAppendingPathComponent: calcPath];
        }
        NSMenuItem *mi = [[NSMenuItem alloc] init];
        [mi setTitle: [calc objectForKey: @"title"]];
        [mi setTarget: backend];
        [mi setAction: changeKmlAction];
        [mi setRepresentedObject: calcPath];
        [kmlMenu addItem: mi];
        [mi release];
    }
    [kmlMenu setMenuChangedMessagesEnabled: YES];
}

- (BOOL)validateMenuItem:(NSMenuItem *)sender
{
    if ([sender action] ==
            @selector(newCalculatorWithChooser:) ||
        [sender action] ==
            @selector(newCalculatorWithStartupCalculator:))
    {
        NSArray *docs =
            [[NSDocumentController sharedDocumentController]
                documents];

        if (docs && [docs count] > 0)
            return NO;

        if ([sender action] ==
                @selector(newCalculatorWithStartupCalculator:))
        {
            CalcPrefController *prefs =
                [[self prefController] prefModel];

            return ([prefs startupCalculator] != nil);
        }

        return YES;
    }
    
    if ([sender action] == @selector(openROM:) ||
        [sender action] == @selector(openObject:) ||
        [sender action] == @selector(saveObject:))
    {
        NSArray *docs = [[NSDocumentController sharedDocumentController] documents];
        BOOL canNew = !(docs && [docs count] > 0);
        
        if ([sender action] == @selector(openROM:))
        {
            if (!canNew)
                return NO;	// dim if calc already newed
        }
        else if ([sender action] == @selector(openObject:) ||
                 [sender action] == @selector(saveObject:))
        {
            if (canNew)
                return NO;	// dim if there is no calc window
        }
    }
    
    if ([sender action] == @selector(setAutoFit:))
    {
        [sender setState:
            [[CalcBackend sharedBackend] autoFitZoom]
            ? NSControlStateValueOn
            : NSControlStateValueOff];

        return YES;
    }
    
    if ([sender action] == @selector(setZoom:))
    {
        if ([[CalcBackend sharedBackend] autoFitZoom])
        {
            [sender setState:NSControlStateValueOff];
            return YES;
        }

        NSInteger zoomPercent =
            [[sender representedObject] integerValue];

        [sender setState:
            (zoomPercent == (NSInteger)[[CalcBackend sharedBackend] uiZoomPercent])
            ? NSControlStateValueOn
            : NSControlStateValueOff];

        return YES;
    }
    
    return YES;
}

- (void)populateZoomMenu
{
    NSMenu *mainMenu = [NSApp mainMenu];
    
    if (!mainMenu)
        return;
    
    /*
     * Find the View menu.
     *
     * We don't need an IBOutlet, which is useful because the old
     * MainMenu.nib cannot currently be edited with Xcode 27.
     */
    NSMenuItem *viewMenuItem = nil;
    NSInteger i;
    
    for (i = 0; i < [mainMenu numberOfItems]; ++i)
    {
        NSMenuItem *item = [mainMenu itemAtIndex:i];
        
        if ([[item title] isEqualToString:@"View"])
        {
            viewMenuItem = item;
            break;
        }
    }
    
    if (!viewMenuItem)
        return;
    
    NSMenu *viewMenu = [viewMenuItem submenu];
    
    if (!viewMenu)
        return;
    
    /*
     * Don't create it twice.
     */
    NSMenuItem *existingItem = [viewMenu itemWithTitle:@"Zoom"];
    
    if (existingItem)
    {
        zoomMenu = [[existingItem submenu] retain];
        return;
    }
    
    zoomMenu = [[NSMenu alloc] initWithTitle:@"Zoom"];
    
    NSMenuItem *autoFitItem =
    [[NSMenuItem alloc] initWithTitle:@"AutoFit"
                               action:@selector(setAutoFit:)
                        keyEquivalent:@""];

    [autoFitItem setTarget:self];
    [zoomMenu addItem:autoFitItem];
    [zoomMenu addItem:[NSMenuItem separatorItem]];

    [autoFitItem release];
    
    NSArray *zoomValues = [CalcBackend uiZoomValues];
    
    for (NSNumber *value in zoomValues)
    {
        CGFloat zoom = [value floatValue];
        
        NSString *title =
        [NSString stringWithFormat:@"%g%%", zoom];
        
        NSMenuItem *item =
        [[NSMenuItem alloc] initWithTitle:title
                                   action:@selector(setZoom:)
                            keyEquivalent:@""];
        
        [item setTarget:self];
        [item setRepresentedObject:value];
        
        [zoomMenu addItem:item];
        
        [item release];
    }
    
    NSMenuItem *zoomItem =
    [[NSMenuItem alloc] initWithTitle:@"Zoom"
                               action:nil
                        keyEquivalent:@""];
    
    [zoomItem setSubmenu:zoomMenu];
    
    [viewMenu addItem:[NSMenuItem separatorItem]];
    [viewMenu addItem:zoomItem];
    
    [zoomItem release];
}

- (IBAction)setAutoFit:(id)sender
{
    [[CalcBackend sharedBackend] setAutoFitZoom:YES];
}

- (IBAction)setZoom:(id)sender
{
    CGFloat zoomPercent =
    [[sender representedObject] doubleValue];
    
    CalcBackend *backend =
        [CalcBackend sharedBackend];

    [backend setManualUIZoomPercent:zoomPercent];
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)app
{

    if (handlingStartup)
        return NO;

    handlingStartup = YES;
    
    CalcPrefController *prefs =
        [[self prefController] prefModel];

    [prefs refreshCalculators:nil];

    int startupMode = [prefs StartupMode];

    /*
     * Open last saved state.
     */
    if (startupMode == kStartupLastSavedState)
    {
        NSDocumentController *dc =
            [NSDocumentController sharedDocumentController];

        NSArray *recentFiles =
            [dc recentDocumentURLs];

        BOOL opened = NO;
        NSString *savedFilename = nil;

        if (recentFiles && [recentFiles count] > 0)
        {
            NSURL *url =
                [recentFiles objectAtIndex:0];

            savedFilename =
                [[url path] lastPathComponent];

            NSError *error = nil;

            NSDocument *document =
                [dc openDocumentWithContentsOfURL:url
                                           display:YES
                                             error:&error];

            if (document)
                opened = YES;
        }

        if (!opened)
        {
            NSAlert *alert =
                [[[NSAlert alloc] init] autorelease];

            [alert setMessageText:@"Last saved calculator not found"];

            NSString *message;

            if ([savedFilename length])
            {
                message =
                    [NSString stringWithFormat:
                        @"The last saved calculator \"%@\" "
                         "could not be found. "
                         "Please choose a calculator from the gallery.",
                        savedFilename];
            }
            else
            {
                message =
                    @"There is no last saved calculator. "
                     "Please choose a calculator from the gallery.";
            }

            [alert setInformativeText:message];

            [alert addButtonWithTitle:@"Choose Calculator"];

            [alert runModal];

            [self showCalculatorGalleryIfNeeded];
        }

        /*
         * We handled startup ourselves.
         * Do not let Cocoa create an untitled document.
         */
        return NO;
    }

    /*
     * Show calculator chooser.
     */
    if (startupMode == kStartupCalculatorChooser)
    {
        [self showCalculatorGalleryIfNeeded];
        return NO;
    }

    /*
     * Use configured startup calculator.
     */
    if (startupMode == kStartupCalculator)
    {
        NSDictionary *calc =
            [prefs startupCalculator];

        if (calc)
        {
            NSString *path =
                [calc objectForKey:@"path"];

            if (![path isAbsolutePath])
            {
                path =
                    [[[NSBundle mainBundle] resourcePath]
                        stringByAppendingPathComponent:path];
            }

            NSError *error = nil;

            NSDocument *document =
                [[NSDocumentController sharedDocumentController]
                    openDocumentWithContentsOfURL:
                        [NSURL fileURLWithPath:path]
                    display:YES
                    error:&error];

            if (!document && error)
            {
                [[NSDocumentController sharedDocumentController]
                    presentError:error];
            }

            if (document)
            {
                [(CalcDocument *)document setCalculatorInfo:calc];
                return NO;
            }
        }

        /*
         * No valid startup calculator.
         * Show the chooser instead.
         */
        [self showCalculatorGalleryIfNeeded];
        return NO;
    }

    /*
     * No startup document.
     */
    return NO;
}

- (void)setCalculatorGallery:(CalcGalleryController *)gallery
{
    [calculatorGallery release];
    calculatorGallery = [gallery retain];
}

- (void)showCalculatorGalleryIfNeeded
{
    CalcManager *manager = [CalcManager sharedManager];

    NSArray *calculators =
        [manager calculators];

    if (![calculators count])
        return;

    if (calculatorGallery)
    {
        [[calculatorGallery window]
            makeKeyAndOrderFront:nil];
        return;
    }

    CalcGalleryController *gallery =
        [[CalcGalleryController alloc]
            initWithCalcManager:manager];

    [[gallery window] setTitle:@"Choose a calculator:"];
    [gallery setActionButtonTitle:@"Create"];
    [gallery setDelegate:self];

    [self setCalculatorGallery:gallery];
    [gallery showGallery];
    [gallery release];
}

- (IBAction)newCalculatorWithChooser:(id)sender
{
    CalcGalleryController *gallery =
        [[CalcGalleryController alloc]
            initWithCalcManager:
                [CalcManager sharedManager]];

    [[gallery window] setTitle:@"Choose a calculator:"];
    [gallery setActionButtonTitle:@"Create"];
    [gallery setDelegate:self];
    [self setCalculatorGallery:gallery];
    [gallery showGallery];
    [gallery release];
}

- (IBAction)newCalculatorWithStartupCalculator:(id)sender
{
    NSDictionary *calc =
        [[CalcManager sharedManager] startupCalculator];

    if (!calc)
        return;

    NSString *path =
        [calc objectForKey:@"path"];

    if (![path isAbsolutePath])
    {
        path =
            [[[NSBundle mainBundle] resourcePath]
                stringByAppendingPathComponent:path];
    }

    NSError *error = nil;

    NSDocument *document =
        [[NSDocumentController sharedDocumentController]
            openDocumentWithContentsOfURL:
                [NSURL fileURLWithPath:path]
            display:YES
            error:&error];

    if (error)
    {
        [[NSDocumentController sharedDocumentController]
            presentError:error];
        return;
    }

    [document updateChangeCount:NSChangeCleared];
}

- (void)startupCalculatorDidChange:
    (NSNotification *)notification
{
    [self populateNewCalcMenu];
}

// gallery delegate callback
- (void)calculatorGalleryDidChooseCalculator:
    (NSDictionary *)calc
{
    NSString *path =
        [calc objectForKey:@"path"];

    if (![path isAbsolutePath])
    {
        path =
            [[[NSBundle mainBundle] resourcePath]
                stringByAppendingPathComponent:path];
    }

    NSError *error = nil;

    CalcDocument *document =
        (CalcDocument *)
        [[NSDocumentController sharedDocumentController]
            openDocumentWithContentsOfURL:
                [NSURL fileURLWithPath:path]
            display:YES
            error:&error];

    if (document)
    {
        [document setCalculatorInfo:calc];
    }
    
    if (error)
    {
        [[NSDocumentController sharedDocumentController]
            presentError:error];
    }

    [[calculatorGallery window] close];

    [self setCalculatorGallery:nil];
}

@end
