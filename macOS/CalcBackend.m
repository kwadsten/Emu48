//
//  CalcBackend.m
//  emu48
//
//  Created by Da Woon Jung on 2009-01-23
//  Copyright 2009 dwj. All rights reserved.
//

#import "CalcBackend.h"
#import "rawlcd.h"
#import "engine.h"
#import "timer.h"
#import "files.h"
#import "stack.h"
#import "external.h"
#import "CalcView.h"
#import "lcd.h"
#import "CalcDebugger.h"
#import "EMU48.H"
#import "IO.H"
#import "CalcDocument.h"
#import <sys/stat.h>
#import <sys/mman.h>
#if TARGET_OS_IPHONE
#import <AudioToolbox/AudioToolbox.h>
#endif


CalcBackend *gSharedCalcBackend = nil;
CalcDocument *document;

@interface CalcBackend(Private)
- (void)loadEngine;
- (void)unloadEngine;
@end


@implementation CalcBackend

+ (CalcBackend *)sharedBackend
{
    if (nil == gSharedCalcBackend) {
        gSharedCalcBackend = [[CalcBackend alloc] init];
        gSharedCalcBackend->autoFitZoom = YES;
    }
    return gSharedCalcBackend;
}

- (void)dealloc
{
    [self stop];
    [state release];
    [backups release];
    
    [[NSNotificationCenter defaultCenter]
        removeObserver:self
                  name:NSWindowDidChangeScreenNotification
                object:nil];

    [[NSNotificationCenter defaultCenter]
        removeObserver:self
                  name:NSApplicationDidChangeScreenParametersNotification
                object:nil];
    
    [super dealloc];
}

- (void)loadEngine
{
    if (nil == toneGenerator)
        toneGenerator = [[CalcToneGenerator alloc] init];
    if (nil == debugModel)
        debugModel = [[CalcDebugger alloc] init];
    if (nil == timer)
        timer  = [[CalcTimer alloc] init];
    if (nil == engine)
        engine = [[CalcEngine alloc] init];
}
- (void)unloadEngine
{
    [engine release]; engine = nil;
    [timer release];  timer = nil;
    [debugModel release]; debugModel = nil;
    [toneGenerator release]; toneGenerator = nil;
}

- (BOOL)makeUntitledCalcWithKml:(NSString *)aFilename error:(NSError **)outError
{
    [self loadEngine];

    CalcState *freshState =
        [[CalcState alloc] initWithKml:aFilename error:outError];

    if (freshState)
    {
        [state release];
        state = freshState;
        return YES;
    }
    else
    {
        NSLog(@"Kml FAILED: %@ (%@)",
              aFilename,
              *outError);
        [self unloadEngine];
    }

    return NO;
}


//- (void)changeKml:(id)sender
//{
//    id path = nil;
//    if ([sender respondsToSelector: @selector(representedObject)])
//        path = [sender representedObject];
//    if (path)
//    {
//        NSArray *pathComps = [[path stringByDeletingLastPathComponent] pathComponents];
//        if ([pathComps count] < 2)
//            path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: path];
//        NSError *err = nil;
//        [state setKmlFile:path error:&err];
//    }
//}

- (void)changeKml:(id)sender
{
    id path = nil;

    if ([sender respondsToSelector:@selector(representedObject)])
        path = [sender representedObject];

    if (path)
    {
        NSArray *pathComps =
            [[path stringByDeletingLastPathComponent] pathComponents];

        if ([pathComps count] < 2)
            path = [[[NSBundle mainBundle] resourcePath]
                    stringByAppendingPathComponent:path];

        NSError *err = nil;

        if ([state setKmlFile:path error:&err])
        {
            [self reloadKmlView];
        }
        else if (err)
        {
            NSLog(@"KML change failed: %@", err);
        }
    }
}

- (void)run
{
    if (engine)
    {
        QueryPerformanceFrequency(&lFreq);
        QueryPerformanceCounter(&lAppStart);
        SetSpeed(NO);

        nState     = SM_RUN;
        nNextState = SM_INVALID;

        [NSThread detachNewThreadSelector:@selector(main)
                                 toTarget:engine
                               withObject:nil];

        while (nState != nNextState)
            Sleep(0);

        if (pbyRom)
        {
            SwitchToState(SM_RUN);
            isRunning = YES;
        }
        else
        {
            NSLog(@"*** run: ERROR pbyRom is NULL");
        }
    }
}

- (void)stop
{
    [state release]; state = nil;
    [self unloadEngine];
    isRunning = NO;
}

- (BOOL)isRunning
{
    return isRunning;
}

- (NSString *)currentModel
{
    return [NSString stringWithFormat:@"%c", cCurrentRomType];
}

- (CalcTimer *)timer
{
    return timer;
}

- (CalcView *)calcView
{
    if ([self initDone])
    {
        return calcView;
    }
    return nil;
}

- (void)setCalcView:(CalcView *)aView
{
    calcView = aView;
}

- (CalcDebugger *)debugModel
{
    return debugModel;
}

- (void)playToneWithFrequency:(DWORD)freq duration:(DWORD)duration
{
    [toneGenerator playToneWithFrequency:freq duration:duration];
}

#if TARGET_OS_IPHONE
- (void)interruptToneWithState:(UInt32)aInterruptState
{
    switch (aInterruptState)
    {
        case kAudioSessionBeginInterruption:
            [toneGenerator release]; toneGenerator = nil;
            break;
        case kAudioSessionEndInterruption:
            if (nil == toneGenerator)
                toneGenerator = [[CalcToneGenerator alloc] init];
            break;
        default:
            break;
    }
}
#endif

- (KmlLine *)If:(KmlLine *)pLine
      condition:(BOOL)bCondition
{
	pLine = pLine->pNext;
	if (bCondition)
	{
		while (pLine)
		{
			if (pLine->eCommand == TOK_END)
			{
				pLine = pLine->pNext;
				break;
			}
			if (pLine->eCommand == TOK_ELSE)
			{
				pLine = SkipLines(pLine, TOK_END);
				break;
			}
			pLine = [self RunLine:pLine];
		}
	}
	else
	{
		pLine = SkipLines(pLine, TOK_ELSE);
		while (pLine)
		{
			if (pLine->eCommand == TOK_END)
			{
				pLine = pLine->pNext;
				break;
			}
			pLine = [self RunLine:pLine];
		}
	}
	return pLine;
}

- (KmlLine *)RunLine:(KmlLine *)pLine
{
	switch (pLine->eCommand)
	{
        case TOK_MAP:
            if (byVKeyMap[pLine->nParam[0]&0xFF]&1)
                [self PressButtonById: pLine->nParam[1]];
            else
                [self ReleaseButtonById: pLine->nParam[1]];
            break;
        case TOK_PRESS:
            [self PressButtonById: pLine->nParam[0]];
            break;
        case TOK_RELEASE:
            [self ReleaseButtonById: pLine->nParam[0]];
            break;
//	case TOK_MENUITEM:
//		PostMessage(hWnd, WM_COMMAND, 0x19C40+(pLine->nParam[0]&0xFF), 0);
//		break;
        case TOK_SETFLAG:
            nKMLFlags |= 1<<(pLine->nParam[0]&0x1F);
            break;
        case TOK_RESETFLAG:
            nKMLFlags &= ~(1<<(pLine->nParam[0]&0x1F));
            break;
        case TOK_NOTFLAG:
            nKMLFlags ^= 1<<(pLine->nParam[0]&0x1F);
            break;
        case TOK_IFPRESSED:
            return [self If:pLine condition:byVKeyMap[pLine->nParam[0]&0xFF]];
            break;
        case TOK_IFFLAG:
            return [self If:pLine
                   condition:((nKMLFlags >> (pLine->nParam[0] & 0x1F)) & 1)];
        // v1.68 changes
        case TOK_IFMEM:
        {
            BYTE byVal;
            Npeek(&byVal, (DWORD)pLine->nParam[0], 1);

            return [self If:pLine
                   condition:((byVal & pLine->nParam[1]) == pLine->nParam[2])];
        }
        default:
            break;
	}
	return pLine->pNext;
}


- (void)mouseDownAt:(CalcPoint)aPoint
{
	UINT i;
	for (i=0; i<nButtons; i++)
	{
		if ([self ClipButton:aPoint forId:i])
		{
			if (pButton[i].dwFlags&BUTTON_NOHOLD)
			{
                bClicking = TRUE;
                uButtonClicked = i;
                pButton[i].bDown = TRUE;
                [self DrawButton: i];
                return;
			}
			if (pButton[i].dwFlags&BUTTON_VIRTUAL)
			{
				bClicking = TRUE;
				uButtonClicked = i;
			}
			bPressed = TRUE;				// key pressed
			uLastPressedKey = i;			// save pressed key
			[self PressButton: i];
			return;
		}
	}
}

- (void)rightMouseDownAt:(CalcPoint)aPoint
{
	UINT i;
	for (i=0; i<nButtons; i++)
	{
		if ([self ClipButton:aPoint forId:i])
		{
			if (pButton[i].dwFlags&BUTTON_NOHOLD)
			{
                return;
			}
			if (pButton[i].dwFlags&BUTTON_VIRTUAL)
			{
				return;
			}
			bPressed = TRUE;				// key pressed
			uLastPressedKey = i;			// save pressed key
			[self PressButton: i];
			return;
		}
	}
}

- (void)mouseUpAt:(CalcPoint)aPoint
{
	UINT i;
	if (bPressed)							// emulator key pressed
	{
		[self ReleaseAllButtons];
        return;
	}
	for (i=0; i<nButtons; i++)
	{
		if ([self ClipButton:aPoint forId:i])
		{
			if ((bClicking)&&(uButtonClicked != i)) break;
			[self ReleaseButton :i];
			break;
		}
	}
	bClicking = FALSE;
	uButtonClicked = 0;
}

- (void)runKey:(BYTE)nId pressed:(BOOL)aPressed
{
    
    if (aPressed)
        [self stateDidChange];
    
//    NSLog(@"RUN KEY: id=%u pressed=%d pVKey=%p",
//          nId, aPressed, pVKey[nId]);
//
//    NSLog(@"ALPHA TEST: pVKey[30] = %p", pVKey[30]);
   
	if (pVKey[nId])
	{
		KmlLine *line = pVKey[nId]->pFirstLine;
		byVKeyMap[nId] = aPressed;
		while (line) line = [self RunLine: line];
	}
	else
	{
		if ([[state kml] debug]&&aPressed)
		{
			NSString *msgStr = [NSString stringWithFormat: NSLocalizedString(@"Scancode %i",@""), nId];
			InfoMessage([msgStr UTF8String]);
		}
	}
}


- (BOOL)ClipButton:(CalcPoint)aPoint forId:(unsigned)nId
{
	return (pButton[nId].nOx<=aPoint.x)
        && (pButton[nId].nOy<=aPoint.y)
        && (aPoint.x<(pButton[nId].nOx+pButton[nId].nCx))
        && (aPoint.y<(pButton[nId].nOy+pButton[nId].nCy));
}

- (void)DrawButton:(unsigned)nId
{
    drawingButton = &pButton[nId];
    [calcView buttonDrawing];
}

- (BOOL)drawingButtonPressed
{
    return drawingButton ? drawingButton->bDown : NO;
}

- (UINT)drawingButtonType
{
    return drawingButton ? drawingButton->nType : 0;
}

- (CalcRect)drawingButtonRect
{
    CalcRect result = CalcZeroRect;
    if (drawingButton)
        result = CalcMakeRect(drawingButton->nOx, drawingButton->nOy, drawingButton->nCx, drawingButton->nCy);
    return result;
}

- (CalcRect)drawingButtonRectPressed
{
    CalcRect result = CalcZeroRect;
    if (drawingButton)
        result = CalcMakeRect(drawingButton->nDx, drawingButton->nDy, drawingButton->nCx, drawingButton->nCy);
    return result;
}

- (void)PressButton:(unsigned)nId
{
	if (pButton[nId].bDown) return;			// key already pressed -> exit
    
	pButton[nId].bDown = TRUE;
	[self DrawButton: nId];
	if (pButton[nId].nIn)
	{
		KeyboardEvent(TRUE,pButton[nId].nOut,pButton[nId].nIn);
	}
	else
	{
		KmlLine* pLine = pButton[nId].pOnDown;
		while ((pLine)&&(pLine->eCommand!=TOK_END))
		{
			pLine = [self RunLine: pLine];
		}
	}
    
    if (document)
        [document updateChangeCount:NSChangeDone];
}

- (void)ReleaseButton:(unsigned)nId
{
	pButton[nId].bDown = FALSE;
	[self DrawButton: nId];
	if (pButton[nId].nIn)
	{
		KeyboardEvent(FALSE,pButton[nId].nOut,pButton[nId].nIn);
	}
	else
	{
		KmlLine* pLine = pButton[nId].pOnUp;
		while ((pLine)&&(pLine->eCommand!=TOK_END))
		{
			pLine = [self RunLine: pLine];
		}
	}
}

- (void)PressButtonById:(unsigned)nId
{
	UINT i;
	for (i=0; i<nButtons; i++)
	{
		if (nId == pButton[i].nId)
		{
			[self PressButton: i];
			return;
		}
	}
}

- (void)ReleaseButtonById:(unsigned)nId
{
	UINT i;
	for (i=0; i<nButtons; i++)
	{
		if (nId == pButton[i].nId)
		{
			[self ReleaseButton: i];
			return;
		}
	}
}

- (void)ReleaseAllButtons
{
	UINT i;
	for (i=0; i<nButtons; i++)				// scan all buttons
	{
		if (pButton[i].bDown)				// button pressed
			[self ReleaseButton: i];		// release button
	}
    
	bPressed = FALSE;						// key not pressed
	bClicking = FALSE;						// var uButtonClicked not valid (no virtual or nohold key)
	uButtonClicked = 0;						// set var to default
}


- (void)onPowerKey
{
    KeyboardEvent(TRUE,0,0x8000);
    Sleep(200);
    KeyboardEvent(FALSE,0,0x8000);
    Sleep(200);
}

- (BOOL)initDone
{
    return initDone;
}

- (void)setInitDone:(BOOL)value
{
    initDone = value;
}


- (void)finishInitWithViewContainer:(CalcViewContainer *)aViewContainer
                           lcdClass:(Class)aLcdClass
{
    viewContainer = aViewContainer;  // v1.68 changes
    lcdClass = aLcdClass;
    KmlParseResult *kml = [state kml];

    if (!kml)
    {
        NSLog(@"*** ERROR: state has no KML!");
        return;
    }
    pVKey     = [kml VKeys];
    pButton   = [kml buttons];
    nButtons  = [kml countOfButtons];

    CalcRect bg = [kml background];
    CalcImage *mainBitmap = [kml mainBitmap];

    [calcView setMainBitmap:mainBitmap
                   atOrigin:bg.origin
                       size:bg.size];

    KmlAnnunciatorC *pAnnunciator = [kml annunciators];
    int i;
    for (i = 0; i < 6; ++i)
    {
        // position of annunciator
        CalcRect annunRect = CalcMakeRect(pAnnunciator[i].nDx, pAnnunciator[i].nDy, pAnnunciator[i].nCx, pAnnunciator[i].nCy);
        [calcView setAnnunciatorRect:annunRect atIndex:i isOn:YES];
        // position of background
        annunRect.origin.x = pAnnunciator[i].nOx;
        annunRect.origin.y = pAnnunciator[i].nOy;
        [calcView setAnnunciatorRect:annunRect atIndex:i isOn:NO];
    }

    // v1.68 changes
    [calcView setLCD:
        [[aLcdClass alloc] initWithScaleX:[kml lcdScaleX]
                                   scaleY:[kml lcdScaleY]
                                   colors:[kml lcdColors]]
        atOrigin:[kml lcdOrigin]];
    
    [calcView setLcdGrayscaleMode: [[NSUserDefaults standardUserDefaults] boolForKey: @"Grayscale"]];
#if TARGET_OS_IPHONE
    [calcView setNeedsDisplay];
#else
    [calcView setNeedsDisplay: YES];
#endif
    
    NSInteger zoomPercent =
        [self validatedUIZoomPercent:[state uiZoomPercent]];

    autoFitZoom = (zoomPercent == -1);

    if (autoFitZoom)
    {
        [self updateAutoFitZoomAfterWindowPlacement];
    }
    else
    {
        [self setUIZoomPercent:(CGFloat)zoomPercent];
    }

    /*
     * Do not restore window position from the .e49 file.
     * Window position is managed by macOS/AppKit.
     */

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(windowDidChangeScreen:)
               name:NSWindowDidChangeScreenNotification
             object:nil];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(screenParametersChanged:)
               name:NSApplicationDidChangeScreenParametersNotification
             object:nil];
    
    [self setInitDone:YES];
}

- (void)updateAutoFitZoomAfterWindowPlacement
{
    if (!autoFitZoom || !viewContainer)
        return;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateAutoFitZoom];
    });
}

- (void)screenParametersChanged:(NSNotification *)notification
{
    [self updateAutoFitZoom];
}

// v1.68 changes
- (void)reloadKmlView
{
    KmlParseResult *kml = [state kml];

    if (!kml)
        return;

    pVKey    = [kml VKeys];
    pButton  = [kml buttons];
    nButtons = [kml countOfButtons];

    CalcRect bg = [kml background];
    CalcImage *mainBitmap = [kml mainBitmap];

    if ([viewContainer respondsToSelector:@selector(setContentSize:)])
        // v1.68 changes
        // KML Background Size defines the emulator window, not the bitmap size.
        [viewContainer setContentSize:bg.size];

    [calcView setMainBitmap:mainBitmap
                   atOrigin:bg.origin
                       size:bg.size];

    KmlAnnunciatorC *pAnnunciator = [kml annunciators];

    for (int i = 0; i < 6; ++i)
    {
        CalcRect annunRect =
            CalcMakeRect(pAnnunciator[i].nDx,
                         pAnnunciator[i].nDy,
                         pAnnunciator[i].nCx,
                         pAnnunciator[i].nCy);

        [calcView setAnnunciatorRect:annunRect
                             atIndex:i
                              isOn:YES];

        annunRect.origin.x = pAnnunciator[i].nOx;
        annunRect.origin.y = pAnnunciator[i].nOy;

        [calcView setAnnunciatorRect:annunRect
                             atIndex:i
                              isOn:NO];
    }

    [calcView setLCD:
        [[lcdClass alloc] initWithScaleX:[kml lcdScaleX]
                                   scaleY:[kml lcdScaleY]
                                   colors:[kml lcdColors]]
        atOrigin:[kml lcdOrigin]];

    [calcView setLcdGrayscaleMode:
        [[NSUserDefaults standardUserDefaults] boolForKey:@"Grayscale"]];

#if TARGET_OS_IPHONE
    [calcView setNeedsDisplay];
#else
    [calcView setNeedsDisplay:YES];
#endif
}

#pragma mark -
#pragma mark Open/Save state

- (BOOL)readFromState:(NSString *)statePath error:(NSError **)outError
{
    [self loadEngine];
    CalcState *freshState = [[CalcState alloc] initWithFile:statePath error:outError];
    if (freshState)
    {
        [state release];
        state = freshState;
        return YES;
    }
    else
    {
        [self unloadEngine];
    }
    return NO;
}

- (BOOL)saveStateAs:(NSString *)aStateFile error:(NSError **)outError
{
    // macOS will remember window position automatically
//    NSWindow *window = (NSWindow *)viewContainer;
//    [state setWindowPosition:[window frame].origin];

    return [state saveAs:aStateFile error:outError];
}

+ (NSArray *)uiZoomValues
{
    return @[
        @10,
        @20,
        @30,
        @40,
        @50,
        @75,
        @100,
        @125,
        @150,
        @200
    ];
}

- (NSInteger)validatedUIZoomPercent:(NSInteger)percent
{
    if (percent == -1)
        return -1;

    for (NSNumber *value in [[self class] uiZoomValues])
    {
        if ([value integerValue] == percent)
            return percent;
    }

    return 100;
}

- (void)updateAutoFitZoom
{
    if (!autoFitZoom || !viewContainer || !calcView)
        return;

    NSWindow *window = (NSWindow *)viewContainer;
    NSScreen *screen = [window screen];

    if (!screen)
    {
        NSLog(@"Auto Zoom: window has no screen yet");
        return;
    }

    NSRect visibleFrame = [screen visibleFrame];
    NSSize nativeSize = [calcView nativeContentSize];

    if (nativeSize.width <= 0.0 || nativeSize.height <= 0.0)
        return;

    CGFloat targetHeight = visibleFrame.size.height * 0.80;

    CGFloat zoom = targetHeight / nativeSize.height;

    CGFloat maxWidthZoom =
        visibleFrame.size.width / nativeSize.width;

    if (zoom > maxWidthZoom)
        zoom = maxWidthZoom;

//    NSLog(@"Auto Zoom BEFORE: %@",
//          NSStringFromRect([window frame]));

    [self setUIZoomPercent:zoom * 100.0];

//    NSLog(@"Auto Zoom AFTER: %@",
//          NSStringFromRect([window frame]));
}

- (void)updateAutoFitZoomForScreen:(NSScreen *)screen
{
    if (!autoFitZoom || !viewContainer || !calcView || !screen)
        return;

    NSRect visibleFrame = [screen visibleFrame];
    NSSize nativeSize = [calcView nativeContentSize];

    if (nativeSize.width <= 0.0 || nativeSize.height <= 0.0)
        return;

    CGFloat targetHeight = visibleFrame.size.height * 0.80;

    CGFloat zoom = targetHeight / nativeSize.height;

    CGFloat maxWidthZoom =
        visibleFrame.size.width / nativeSize.width;

    if (zoom > maxWidthZoom)
        zoom = maxWidthZoom;

    [self setUIZoomPercent:zoom * 100.0];
}

- (void)setAutoFitZoom:(BOOL)enabled
{
    if (autoFitZoom == enabled)
        return;

    autoFitZoom = enabled;

    if (autoFitZoom)
    {
        [state setUIZoomPercent:-1];
        [self updateAutoFitZoom];
        [self keepWindowFullyVisible];

        [document updateChangeCount:NSChangeDone];
    }
}

- (void)setManualUIZoomPercent:(CGFloat)percent
{
    autoFitZoom = NO;

    [state setUIZoomPercent:(int32_t)percent];
    [self setUIZoomPercent:percent];

    [document updateChangeCount:NSChangeDone];
}

- (BOOL)autoFitZoom
{
    return autoFitZoom;
}

- (void)windowDidChangeScreen:(NSNotification *)notification
{
    if (!autoFitZoom)
        return;

    if ([notification object] != (NSWindow *)viewContainer)
        return;

    [self updateAutoFitZoom];
}

- (void)keepWindowFullyVisible
{
    if (!viewContainer)
        return;

    NSWindow *window = (NSWindow *)viewContainer;
    NSScreen *screen = [window screen];

    if (!screen)
        screen = [NSScreen mainScreen];

    NSRect visibleFrame = [screen visibleFrame];
    NSRect windowFrame = [window frame];

    NSPoint origin = windowFrame.origin;

    if (NSWidth(windowFrame) > NSWidth(visibleFrame))
    {
        origin.x = NSMinX(visibleFrame);
    }
    else
    {
        if (NSMaxX(windowFrame) > NSMaxX(visibleFrame))
            origin.x -= NSMaxX(windowFrame) - NSMaxX(visibleFrame);

        if (NSMinX(windowFrame) < NSMinX(visibleFrame))
            origin.x += NSMinX(visibleFrame) - NSMinX(windowFrame);
    }

    CGFloat bottomMargin = 20.0;

    if (NSHeight(windowFrame) > NSHeight(visibleFrame) - bottomMargin)
    {
        origin.y =
            NSMaxY(visibleFrame) - bottomMargin - windowFrame.size.height;
    }
    else
    {
        if (NSMaxY(windowFrame) > NSMaxY(visibleFrame))
            origin.y -=
                NSMaxY(windowFrame) - NSMaxY(visibleFrame);

        if (NSMinY(windowFrame) <
            NSMinY(visibleFrame) + bottomMargin)
        {
            origin.y +=
                (NSMinY(visibleFrame) + bottomMargin) -
                NSMinY(windowFrame);
        }
    }

    [window setFrameOrigin:origin];
}

#pragma mark -
#pragma mark Import/Export object

- (BOOL)readFromObject:(NSString *)aObjectFile error:(NSError **)outError
{
    NSData *data = [[NSData alloc] initWithContentsOfFile:aObjectFile options:(NSMappedRead | NSUncachedRead) error:outError];
    CalcStack *stack = nil;
    if (data)
    {
        stack = [[CalcStack alloc] initWithObject: data];
        [stack pasteObjectRepresentation: outError];
        [stack release];
        [data release];
        return (nil == outError);
    }
    return NO;
}

- (BOOL)saveObjectAs:(NSString *)aObjectFile error:(NSError **)outError
{
    BOOL result = NO;
    CalcStack *stack = [[CalcStack alloc] initWithError: outError];
    if (stack)
    {
        NSData *object = [stack objectRepresentation];
        result = [object writeToFile:aObjectFile options:NSAtomicWrite error:outError];
        [stack release];
    }
    return result;
}

#pragma mark -
#pragma mark Backup/Restore

- (void)backup
{
	UINT nOldState;
	if (pbyRom == NULL) return;
	nOldState = SwitchToState(SM_INVALID);
    if (nil == backups) backups = [[NSMutableArray alloc] init];
    // TODO: Maybe implement multiple backups?
    [backups removeAllObjects];
    NSDictionary *backup = [[NSDictionary alloc] initWithObjectsAndKeys:
                            [NSDate date], @"date",
                            [[[CalcBackup alloc] initWithState: state] autorelease], @"state",
                            nil];
    [backups addObject: backup];
    [backup release];
	SwitchToState(nOldState);
}

- (void)restore
{
	SwitchToState(SM_INVALID);
    if (backups && [backups count] > 0)
    {
        NSDictionary *backup = [backups objectAtIndex: 0];
        [[backup objectForKey: @"state"] restoreToState: state];
    }
	if (pbyRom) SwitchToState(SM_RUN);
}

- (void)stateDidChange
{
    if (document)
        [document updateChangeCount:NSChangeDone];
}

- (void)setDocument:(CalcDocument *)aDocument
{
    document = aDocument;
}

- (void)setUIZoomPercent:(CGFloat)percent
{
    if (percent <= 0)
        percent = 100.0;

    NSWindow *window = nil;

    if (viewContainer &&
        [viewContainer isKindOfClass:[NSWindow class]])
    {
        window = (NSWindow *)viewContainer;
    }

    NSRect oldFrame = NSZeroRect;

    if (window)
        oldFrame = [window frame];

    [calcView setUIZoomPercent:percent];

    if (window)
    {
        [window setContentSize:[calcView zoomedContentSize]];

        /*
         * Keep the top edge fixed when the content size changes.
         * This prevents Auto Zoom from moving the restored window
         * vertically.
         */
        NSRect newFrame = [window frame];

        newFrame.origin.y =
            NSMaxY(oldFrame) - newFrame.size.height;

        [window setFrameOrigin:newFrame.origin];
    }
}

- (CGFloat)uiZoomPercent
{
    return [calcView uiZoom] * 100.0;
}

// Primary display contains point 0,0.  It is *not* the display with the current menu bar.
- (NSScreen *)primaryDisplay
{
    NSPoint origin = NSMakePoint(0.0, 0.0);

    for (NSScreen *screen in [NSScreen screens])
    {
        if (NSPointInRect(origin, [screen frame]))
            return screen;
    }

    return [NSScreen mainScreen];
}

@end
