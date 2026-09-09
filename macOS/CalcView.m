//
//  CalcView.m
//  emu48
//
//  A container for the calc background, lcd, annunciators,
//  and button redrawing operations. This is the calc UI.
//
//  Created by Da Woon Jung on Wed Feb 18 2004.
//  Copyright (c) 2004 dwj. All rights reserved.
//
#import "CalcView.h"
#import "pch.h"
#import "EMU48.H"
#import "IO.H"
#import "CalcAppController.h"
#import "CalcBackend.h"
#import "stack.h"
#import "MacKeycodes.h" // For kVK_* key mappings
#import "CalcScancodes.h"
#import "CalcInfoButton.h"
#import "CalcInfoButtonCell.h"

#define SharedView      [[CalcBackend sharedBackend] calcView]

// display update 1/frequency (1/64) in seconds
#define DISPLAY_FREQ    0.033
//0.019

BOOL   bGrayscale = FALSE;
static BYTE byVblRef = 0;					// VBL stop reference

extern CHIPSET Chipset;

BYTE (*GetLineCounter)(VOID) = NULL;
VOID (*StartDisplay)(BYTE byInitial) = NULL;
VOID (*StopDisplay)(VOID) = NULL;

BYTE GetLineCounterGray(VOID);
VOID StartDisplayGray(BYTE byInitial);
VOID StopDisplayGray(VOID);
BYTE GetLineCounterBW(VOID);
VOID StartDisplayBW(BYTE byInitial);
VOID StopDisplayBW(VOID);


@interface CalcView(Private)
- (void)UpdateContrast:(BYTE)byContrast;
- (void)GetLineCounter:(NSMutableData *)aOutData;
- (void)scheduleBWUpdate;
- (BOOL)keyEvent:(NSEvent *)theEvent pressed:(BOOL)aPressed;
@end


@implementation CalcView

- (id)initWithFrame:(NSRect)aFrame
{
    self = [super initWithFrame:aFrame];
    if (self)
    {
        uiZoom = 1.0;

        [self registerForDraggedTypes:[CalcStack copyableTypes]];

        infoButton =
            [[CalcInfoButton alloc] initWithFrame:NSMakeRect(0, 0, 32, 32)];

        [infoButton setCell:
         [[[CalcInfoButtonCell alloc] init] autorelease]];

        [infoButton setButtonType:NSButtonTypeMomentaryPushIn];
        [infoButton setTarget:self];
        [infoButton setAction:@selector(showCalculatorInfo:)];
        [infoButton setHidden:NO];

        [self addSubview:infoButton];

        [self positionInfoButton];
    }

    return self;
}

- (void)dealloc
{
    CalcBackend *backend = [CalcBackend sharedBackend];
    if ([backend calcView] == self)
        [backend setCalcView:nil];
    
    [infoButton release];
    [calcInfo release];
    [bwLcdTimer release];
    [uLcdTimerId release];
    [mainBitmap release];
    
    [super dealloc];
}

- (void)setFrameSize:(NSSize)newSize
{
    [super setFrameSize:newSize];

    if (infoButton)
        [self positionInfoButton];
}

+ (CalcImage *)CreateMainBitmap:(NSString *)filename
{
    if (nil==filename)
        return nil;

    NSData *imgData = [[NSData alloc] initWithContentsOfFile: filename];
    if (nil == imgData)
        return nil;
    // Using NSImage -initWithContentsOfFile: results in dpi scaling
    // We want to ignore dpi, so use an image rep instead
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithData: imgData];
    CalcImage *img = nil;
    if (rep)
    {
        img = [[CalcImage alloc] initWithSize:NSMakeSize([rep pixelsWide], [rep pixelsHigh])];
    }
    if (img)
    {
        [img addRepresentation:rep];
        [img setScalesWhenResized:YES];
        [img setSize:NSMakeSize([rep pixelsWide], [rep pixelsHigh])];
        [rep release];
    }

    [imgData release];
    return [img autorelease];
}

// v1.68 changes
static CGFloat ScaleCGFloat(CGFloat value, unsigned mul, unsigned div)
{
    if (div == 0)
        return value;

    return value * (CGFloat)mul / (CGFloat)div;
}

+ (CalcImage *)scaleMainBitmap:(CalcImage *)source
                           mul:(unsigned)mul
                           div:(unsigned)div
{
    if (!source || mul == 0 || div == 0)
        return source;

    NSSize sourceSize = [source size];

    NSSize destSize = NSMakeSize(
        ScaleCGFloat(sourceSize.width, mul, div),
        ScaleCGFloat(sourceSize.height, mul, div)
    );

    CalcImage *scaled =
        [[CalcImage alloc] initWithSize:destSize];

    if (!scaled)
        return source;

    [scaled lockFocus];

    [source drawInRect:NSMakeRect(0, 0,
                                  destSize.width,
                                  destSize.height)
              fromRect:NSMakeRect(0, 0,
                                  sourceSize.width,
                                  sourceSize.height)
             operation:NSCompositingOperationCopy
              fraction:1.0];

    [scaled unlockFocus];

    return [scaled autorelease];
}

- (void)setInactiveOverlay:(BOOL)visible
{
    inactiveOverlay = visible;

    if (lcd &&
        [lcd respondsToSelector:@selector(setInactiveOverlay:)])
    {
        [lcd setInactiveOverlay:visible];
    }

    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)aRect
{
    CGContextRef context =
    [[NSGraphicsContext currentContext] CGContext];
    
    CGContextSaveGState(context);
    
    /*
     * UI zoom is applied to the entire calculator coordinate system.
     */
    CGContextScaleCTM(context, uiZoom, uiZoom);
    
    /*
     * Convert the dirty rectangle from zoomed view coordinates
     * back into native calculator coordinates.
     */
    NSRect nativeRect = NSMakeRect(
                                   aRect.origin.x / uiZoom,
                                   aRect.origin.y / uiZoom,
                                   aRect.size.width / uiZoom,
                                   aRect.size.height / uiZoom
                                   );
    
    /*
     * The bitmap can be larger than the KML Background.
     * The extra area contains source artwork for annunciators
     * and buttons and must never be displayed.
     */
    NSRect backgroundRect = NSMakeRect(
        0,
        0,
        backgroundSize.width,
        backgroundSize.height
    );

    NSRectClip(backgroundRect);

    NSSize bitmapSize = [mainBitmap size];

    NSRect backgroundSrcRect = NSMakeRect(
        mainBitmapOrigin.x,
        bitmapSize.height - mainBitmapOrigin.y - backgroundSize.height,
        backgroundSize.width,
        backgroundSize.height
    );

    [mainBitmap drawAtPoint:NSZeroPoint
                   fromRect:backgroundSrcRect
                  operation:NSCompositingOperationCopy
                   fraction:1.0];
    /*
     * Redraw annunciators from their source rectangles in
     * the main bitmap.
     */
    CalcImage *annunciator = mainBitmap;

    for (int i = 0; i < 6; ++i)
    {
        if (!NSIntersectsRect(nativeRect, annunciatorOff[i]))
            continue;

        NSRect annunSrcRect;

        if (annunciatorStates[i])
        {
            // ON: source is the KML Down rectangle.
            annunSrcRect = annunciatorOn[i];
        }
        else
        {
            annunSrcRect = annunciatorOffSource[i];
        }

        // Trim 0.5 pixel from the left/right edge of the source artwork.
        annunSrcRect.origin.x += 0.5;
        annunSrcRect.size.width -= 1.0;
        
        [annunciator drawInRect:annunciatorOff[i]
                       fromRect:annunSrcRect
                      operation:NSCompositingOperationCopy
                       fraction:1.0];
    }

    // Paused overlay
    /*
     * Build the complete logical display area from the KML-defined
     * LCD and annunciator destination rectangles.
     *
     * displayRect is in KML/native calculator coordinates.
     */
    NSRect displayRect = NSMakeRect(
        lcdOrigin.x,
        backgroundSize.height -
            lcdOrigin.y -
            lcdNativeSize.height,
        lcdNativeSize.width,
        lcdNativeSize.height
    );

    for (int i = 0; i < 6; ++i)
    {
        displayRect = NSUnionRect(
            displayRect,
            annunciatorOff[i]
        );
    }

    /*
     * Convert the KML/native display center into CalcRawLCD's
     * local coordinate system.
     *
     * lcdNativeSize is the KML LCD size.
     * lcd.bounds is the actual rendered RawLCD size, which already
     * incorporates the current UI zoom.
     */

    /*
     * Center the inactive overlay over the LCD plus the
     * annunciator strip above it.
     */

    NSRect lcdDisplayRect = NSMakeRect(
        lcdOrigin.x,
        backgroundSize.height -
            lcdOrigin.y -
            lcdNativeSize.height,
        lcdNativeSize.width,
        lcdNativeSize.height
    );

    CGFloat annunciatorHeight = annunciatorOff[0].size.height;

    /*
     * The logical display extends upward from the LCD by
     * one annunciator height.
     */
    CGFloat displayCenterY =
        NSMinY(lcdDisplayRect) +
        (lcdNativeSize.height + annunciatorHeight) * 0.5;

    /*
     * Convert the native-coordinate center to LCD-local
     * coordinates.
     */
    CGFloat scaleY =
        lcd.bounds.size.height / lcdNativeSize.height;

    NSPoint displayCenter =
        NSMakePoint(
            lcd.bounds.size.width * 0.5,
            (displayCenterY - NSMinY(lcdDisplayRect)) * scaleY
        );

    [lcd setInactiveOverlayDisplayCenter:displayCenter];
    
    if (inactiveOverlay)
    {
        NSRect overlayRect = NSMakeRect(
            0,
            0,
            backgroundSize.width,
            backgroundSize.height
        );

        [[NSColor colorWithDeviceWhite:0.0 alpha:0.25] setFill];

        NSRectFillUsingOperation(
            overlayRect,
            NSCompositingOperationSourceOver
        );
    }
    
    /*
     * Button drawing.
     */
    NSRect displayButtonRect = drawingButtonRect;

    CGFloat nativeHeight =
        [self bounds].size.height / uiZoom;

    displayButtonRect.origin.y =
        nativeHeight -
        displayButtonRect.origin.y -
        displayButtonRect.size.height;

    if (NSIntersectsRect(nativeRect, displayButtonRect))
    {
        CalcImage *button = mainBitmap;

        NSRect srcButtonRect = drawingButtonRect;
        NSRect srcButtonRectPressed = drawingButtonRectPressed;

        srcButtonRect.origin.y =
            [mainBitmap size].height -
            srcButtonRect.origin.y -
            srcButtonRect.size.height;

        srcButtonRectPressed.origin.y =
            [mainBitmap size].height -
            srcButtonRectPressed.origin.y -
            srcButtonRectPressed.size.height;

        switch (drawingButtonType)
        {
            case 0:
                if (drawingButtonPressed)
                {
                    [button drawInRect:displayButtonRect
                              fromRect:srcButtonRectPressed
                             operation:NSCompositingOperationCopy
                              fraction:1.0];
                }
                break;

            case 1:
                if (drawingButtonPressed)
                {
                    float x0 = displayButtonRect.origin.x;
                    float y0 = displayButtonRect.origin.y +
                               displayButtonRect.size.height;
                    float x1 = x0 +
                               displayButtonRect.size.width - 1.;
                    float y1 = displayButtonRect.origin.y + 1.;

                    NSRect offsetRectSrc =
                        NSOffsetRect(srcButtonRect, 2., 3.);

                    offsetRectSrc.size.width -= 5.;
                    offsetRectSrc.size.height -= 5.;

                    NSRect offsetRectDst =
                        NSOffsetRect(displayButtonRect, 3., 2.);

                    offsetRectDst.size.width -= 5.;
                    offsetRectDst.size.height -= 5.;

                    [button drawInRect:offsetRectDst
                              fromRect:offsetRectSrc
                             operation:NSCompositingOperationCopy
                              fraction:1.0];

                    [[NSColor blackColor] setStroke];
                    [NSBezierPath strokeLineFromPoint:NSMakePoint(x0, y0)
                                              toPoint:NSMakePoint(x1, y0)];
                    [NSBezierPath strokeLineFromPoint:NSMakePoint(x0, y0)
                                              toPoint:NSMakePoint(x0, y1)];

                    [[NSColor whiteColor] setStroke];
                    [NSBezierPath strokeLineFromPoint:NSMakePoint(x1, y0)
                                              toPoint:NSMakePoint(x1, y1)];
                    [NSBezierPath strokeLineFromPoint:NSMakePoint(x0, y1)
                                              toPoint:NSMakePoint(x1 + 1., y1)];
                }
                break;

            case 2:
                break;

            case 3:
                if (drawingButtonPressed)
                {
                    CGContextRef ctxt =
                        [[NSGraphicsContext currentContext] CGContext];

                    CGContextSetBlendMode(
                        ctxt, kCGBlendModeDifference);

                    CGContextSetGrayFillColor(
                        ctxt, 1.0, 1.0);

                    CGContextFillRect(
                        ctxt, *(CGRect *)&displayButtonRect);
                }
                break;

            case 4:
                break;

            case 5:
                if (drawingButtonPressed)
                {
                    NSRect circleRect = displayButtonRect;

                    if (circleRect.size.height < circleRect.size.width)
                        circleRect.size.width = circleRect.size.height;
                    else
                        circleRect.size.height = circleRect.size.width;

                    circleRect.origin.x +=
                        (displayButtonRect.size.width -
                         circleRect.size.width) * 0.5;

                    circleRect.origin.y +=
                        (displayButtonRect.size.height -
                         circleRect.size.height) * 0.5;

                    NSColor *milkyWhite =
                        [NSColor colorWithDeviceWhite:1.0 alpha:0.5];

                    [milkyWhite setFill];

                    NSBezierPath *circle =
                        [NSBezierPath bezierPathWithOvalInRect:circleRect];

                    [circle fill];
                }
                break;

            default:
                if (drawingButtonPressed)
                {
                    [[NSColor blackColor] setFill];
                    NSRectFill(displayButtonRect);
                }
                break;
        }
    }
    
    CGContextRestoreGState(context);
}

- (void)setMainBitmap:(CalcImage *)aImage
             atOrigin:(CalcPoint)aOrigin
                 size:(CalcSize)aSize
{
    [mainBitmap release];
    mainBitmap = [aImage retain];

    mainBitmapOrigin = aOrigin;
    backgroundSize = aSize;
}

- (CalcImage *)mainBitmap
{
    return mainBitmap;
//    return [self image];
}

- (void)setLCD:(NSView<CalcLCD> *)aLcd
     atOrigin:(CalcPoint)origin
{
    [lcd removeFromSuperviewWithoutNeedingDisplay];

    lcd = aLcd;

    [self addSubview:lcd];

    lcdOrigin = origin;

    if (lcdNativeSize.width == 0 || lcdNativeSize.height == 0)
        lcdNativeSize = [lcd bounds].size;

    // KML LCD coordinates are in the main bitmap coordinate system,
    // not the cropped Background coordinate system.
    NSRect frame = NSMakeRect(
        round((origin.x - mainBitmapOrigin.x) * uiZoom),
        round((backgroundSize.height -
               (origin.y - mainBitmapOrigin.y) -
               lcdNativeSize.height) * uiZoom),
        round(lcdNativeSize.width * uiZoom),
        round(lcdNativeSize.height * uiZoom)
    );

    [lcd setFrame:frame];
    [lcd setNeedsDisplay:YES];
}

- (void)setCalcInfo:(NSDictionary *)info
{
    [calcInfo release];
    calcInfo = [info retain];

    [infoButton setHidden:(calcInfo == nil)];
}

- (void)positionInfoButton
{
    NSRect bounds = [self bounds];

    CGFloat infoSize = 24.0;
    CGFloat margin = 2.0;

    NSRect infoFrame = NSMakeRect(
        NSMaxX(bounds) - infoSize - margin,
        NSMaxY(bounds) - infoSize - margin,
        infoSize,
        infoSize
    );

    [infoButton setFrame:infoFrame];
}

- (void)showCalculatorInfo:(id)sender
{
    if (!calcInfo)
        return;

    NSString *title =
        [calcInfo objectForKey:@"title"];

    NSString *author =
        [calcInfo objectForKey:@"author"];

    NSString *displayModel =
        [calcInfo objectForKey:@"displayModel"];

    NSString *rom =
        [calcInfo objectForKey:@"rom"];

    NSString *path =
        [calcInfo objectForKey:@"path"];

    if (!title)
        title = @"";

    if (!author)
        author = @"";

    if (!displayModel)
        displayModel = @"";

    if (!rom)
        rom = @"";

    if (!path)
        path = @"";

    /*
     * Display only the filename for ROM and KML.
     */
    rom = [rom lastPathComponent];
    NSString *kmlPath = [path lastPathComponent];

    NSArray *labels =
        [NSArray arrayWithObjects:
            @"Title:",
            @"Author:",
            @"Model:",
            @"ROM:",
            @"KML:",
            nil];

    NSArray *values =
        [NSArray arrayWithObjects:
            title,
            author,
            displayModel,
            rom,
            kmlPath,
            nil];

    NSFont *font =
        [NSFont systemFontOfSize:17.0];

    NSDictionary *attributes =
        [NSDictionary dictionaryWithObjectsAndKeys:
            font,
            NSFontAttributeName,
            nil];

    /*
     * Layout.
     */
    CGFloat labelWidth = 62.0;
    CGFloat columnGap = 8.0;
    CGFloat horizontalMargin = 18.0;
    CGFloat verticalMargin = 16.0;

    /*
     * Calculate the width needed for the longest value.
     */
    CGFloat valueWidth = 0.0;

    for (NSString *value in values)
    {
        NSRect textRect =
            [value boundingRectWithSize:
                NSMakeSize(CGFLOAT_MAX, 22.0)
                               options:NSStringDrawingUsesFontLeading
                            attributes:attributes];

        if (textRect.size.width > valueWidth)
            valueWidth = textRect.size.width;
    }

    /*
     * Add extra room so the text is not clipped.
     */
    valueWidth += 12.0;

    CGFloat contentWidth =
        horizontalMargin +
        labelWidth +
        columnGap +
        valueWidth +
        horizontalMargin;

    CGFloat lineHeight = 22.0;

    CGFloat contentHeight =
        verticalMargin * 2.0 +
        lineHeight * [labels count];

    NSView *contentView =
        [[[NSView alloc]
            initWithFrame:NSMakeRect(
                0,
                0,
                contentWidth,
                contentHeight)]
        autorelease];

    /*
     * Create the two columns.
     */
    for (NSUInteger i = 0; i < [labels count]; i++)
    {
        CGFloat y =
            contentHeight -
            verticalMargin -
            lineHeight * (i + 1);

        /*
         * Label column.
         */
        NSTextField *label =
            [[[NSTextField alloc]
                initWithFrame:NSMakeRect(
                    horizontalMargin,
                    y,
                    labelWidth,
                    lineHeight)]
            autorelease];

        [label setEditable:NO];
        [label setSelectable:NO];
        [label setBordered:NO];
        [label setDrawsBackground:NO];
        [label setFont:font];
        [label setStringValue:
            [labels objectAtIndex:i]];

        [contentView addSubview:label];

        /*
         * Value column.
         */
        NSTextField *value =
            [[[NSTextField alloc]
                initWithFrame:NSMakeRect(
                    horizontalMargin +
                        labelWidth +
                        columnGap,
                    y,
                    valueWidth,
                    lineHeight)]
            autorelease];

        [value setEditable:NO];
        [value setSelectable:YES];
        [value setBordered:NO];
        [value setDrawsBackground:NO];
        [value setFont:font];

        /*
         * Do not wrap or truncate the value.
         */
        [value setLineBreakMode:NSLineBreakByClipping];

        [value setStringValue:
            [values objectAtIndex:i]];

        [contentView addSubview:value];
    }

    /*
     * Create the popover.
     */
    NSViewController *viewController =
        [[[NSViewController alloc] init] autorelease];

    [viewController setView:contentView];

    NSPopover *popover =
        [[[NSPopover alloc] init] autorelease];

    [popover setBehavior:NSPopoverBehaviorTransient];
    [popover setAnimates:YES];
    [popover setContentViewController:viewController];

    [popover setContentSize:
        NSMakeSize(contentWidth, contentHeight)];

    [popover showRelativeToRect:[sender bounds]
                         ofView:sender
                  preferredEdge:NSMaxYEdge];
}

- (void)setLcdGrayscaleMode:(BOOL)isGrayscale
{
    if ((bGrayscale = isGrayscale))
    {
		GetLineCounter = GetLineCounterGray;
		StartDisplay   = StartDisplayGray;
		StopDisplay    = StopDisplayGray;
    }
    else
    {
		GetLineCounter = GetLineCounterBW;
		StartDisplay   = StartDisplayBW;
		StopDisplay    = StopDisplayBW;
    }
    [lcd SetGrayscaleMode: isGrayscale];
}

- (void) UpdateContrast:(BYTE) byContrast
{
    [lcd UpdateContrast: byContrast];
}

- (void)setAnnunciatorRect:(CalcRect)aRect atIndex:(int)nId isOn:(BOOL)isOn
{
    NSRect sourceRect = aRect;

    sourceRect.origin.y =
        [mainBitmap size].height -
        sourceRect.origin.y -
        sourceRect.size.height;

    if (isOn)
    {
        annunciatorOn[nId] = sourceRect;
    }
    else
    {
        annunciatorOffSource[nId] = sourceRect;

        annunciatorOff[nId] = NSMakeRect(
            aRect.origin.x - mainBitmapOrigin.x,
            backgroundSize.height -
                (aRect.origin.y - mainBitmapOrigin.y) -
                aRect.size.height,
            aRect.size.width,
            aRect.size.height
        );
    }
}

- (void) GetLineCounter:(NSMutableData *) aOutData
{
	LARGE_INTEGER lLC;
	BYTE          byTime;
    BYTE          result = 0;

	if (![uLcdTimerId isValid])					// display off
    {
        result = ((Chipset.IORam[LINECOUNT+1] & (LC5|LC4)) << 4) | Chipset.IORam[LINECOUNT];
    }
    else
    {
        QueryPerformanceCounter(&lLC);			// get elapsed time since display update
        
        // elapsed ticks so far
        byTime = (BYTE) (((lLC.QuadPart - lLcdRef.QuadPart) << 12) / lFreq.QuadPart);
        
        if (byTime > 0x3F) byTime = 0x3F;		// all counts made

        result = 0x3F - byTime;
    }
    [aOutData replaceBytesInRange:NSMakeRange(0, sizeof(result)) withBytes:&result];
}

- (void)update:(NSTimer *)timer
{
	EnterCriticalSection(&csLcdLock);
	{
        [self UpdateMainDisplay];
        [self UpdateMenuDisplay];
        [self RefreshDisp0];
    }
	LeaveCriticalSection(&csLcdLock);

	QueryPerformanceCounter(&lLcdRef);		// actual time
}

- (void)updateBW:(NSTimer *)timer
{
    [lcd setNeedsDisplay: YES];
    [bwLcdTimer release];
    bwLcdTimer = nil;
}

- (void)scheduleBWUpdate
{
    bwLcdTimer = [[NSTimer scheduledTimerWithTimeInterval:DISPLAY_FREQ target:self selector:@selector(updateBW:) userInfo:nil repeats:NO] retain];  // one-shot update
}

- (void)StartDisplay:(NSNumber *)aInitial
{
    BYTE byInitial = [aInitial unsignedCharValue];
	if ([uLcdTimerId isValid])						// LCD update timer running
		return;								// -> quit

	if (Chipset.IORam[BITOFFSET]&DON)		// display on?
	{
		QueryPerformanceCounter(&lLcdRef);	// actual time of top line

		// adjust startup counter to get the right VBL value
		_ASSERT(byInitial <= 0x3F);			// line counter value 0 - 63
		lLcdRef.QuadPart -= ((LONGLONG) (0x3F - byInitial) * lFreq.QuadPart) >> 12;

        [uLcdTimerId release];
        uLcdTimerId = [[NSTimer scheduledTimerWithTimeInterval:DISPLAY_FREQ target:self selector:@selector(update:) userInfo:nil repeats:YES] retain];
	}
}


- (void)StopDisplay
{
	BYTE a[2];
	ReadIO(a,LINECOUNT,2,TRUE);					// update VBL at display off time
    
	if (![uLcdTimerId isValid])					// timer stopped
		return;								// -> quit

    [uLcdTimerId invalidate];
    [uLcdTimerId release];
    uLcdTimerId = nil;

	EnterCriticalSection(&csLcdLock);		// update to last condition
	{
		[self UpdateMainDisplay];				// update display
		[self UpdateMenuDisplay];
        [self RefreshDisp0];
	}
	LeaveCriticalSection(&csLcdLock);
}


- (void)UpdateDisplayPointers
{
	EnterCriticalSection(&csLcdLock);
	{
#if defined DEBUG_DISPLAY
		{
			NSLog(@"%.5lx: Update Display Pointer", Chipset.pc);
		}
#endif

		// calculate display width
		Chipset.width = (34 + Chipset.loffset + (Chipset.boffset / 4) * 2) & 0xFFFFFFFE;
		Chipset.end1 = Chipset.start1 + MAINSCREENHEIGHT * Chipset.width;
		if (Chipset.end1 < Chipset.start1)
		{
			// calculate first address of main display
			Chipset.start12 = Chipset.end1 - Chipset.width;
			// calculate last address of main display
			Chipset.end1 = Chipset.start1 - Chipset.width;
		}
		else
		{
			Chipset.start12 = Chipset.start1;
		}
		Chipset.end2 = Chipset.start2 + MENUHEIGHT * 34;
	}
	LeaveCriticalSection(&csLcdLock);
}

- (void)UpdateMainDisplay
{
    // [lcd performSelectorOnMainThread:@selector(UpdateMain) withObject:nil waitUntilDone:NO];
    [lcd performSelectorOnMainThread:@selector(UpdateMain)
                           withObject:nil
                        waitUntilDone:YES];
}

- (void)UpdateMenuDisplay
{
    [lcd performSelectorOnMainThread:@selector(UpdateMenu) withObject:nil waitUntilDone:NO];
}

- (void)RefreshDisp0
{
    [lcd performSelectorOnMainThread:@selector(RefreshDisp0) withObject:nil waitUntilDone:NO];
}

- (void)WriteToMain:(CalcLCDWriteArgument *)args
{
    [lcd WriteToMain: args];
    // Do our own display coalescing as incremental updates using
    // setNeedsDisplayInRect is proving to be too inefficient
    if (nil == bwLcdTimer)
        [self performSelectorOnMainThread:@selector(scheduleBWUpdate) withObject:nil waitUntilDone:YES];
}

- (void)WriteToMenu:(CalcLCDWriteArgument *)args
{
    [lcd WriteToMenu: args];
    if (nil == bwLcdTimer)
        [self performSelectorOnMainThread:@selector(scheduleBWUpdate) withObject:nil waitUntilDone:YES];
}

- (void)UpdateAnnunciators
{
    const BYTE annCtrl[] = { LA1, LA2, LA3, LA4, LA5, LA6 };
    CalcBackend *backend = [CalcBackend sharedBackend];
    BYTE c = (BYTE)(Chipset.IORam[ANNCTRL] | (Chipset.IORam[ANNCTRL+1]<<4));
	// switch annunciators off if timer stopped
	if ((c & AON) == 0 || (Chipset.IORam[TIMER2_CTRL] & RUN) == 0)
		c = 0;

    int i;
    BOOL annunciatorState;
    for (i = 0; i < sizeof(annCtrl); ++i)
    {
        annunciatorState = (0 != (c&annCtrl[i]));
        if (annunciatorStates[i] != annunciatorState)
        {
            annunciatorStates[i]  = annunciatorState;
            NSRect rect = annunciatorOff[i];
            rect.origin.x *= uiZoom;
            rect.origin.y *= uiZoom;
            rect.size.width *= uiZoom;
            rect.size.height *= uiZoom;
            [self setNeedsDisplayInRect:rect];
        }
    }
}


- (void)mouseDown:(NSEvent *)theEvent
{
    NSPoint point =
        [self convertPoint:[theEvent locationInWindow]
                  fromView:nil];

    point.y = [self bounds].size.height - point.y;
    point.x /= uiZoom;
    point.y /= uiZoom;

    [[CalcBackend sharedBackend] mouseDownAt:point];
}

- (void)rightMouseDown:(NSEvent *)theEvent
{
    NSPoint point = [self convertPoint:[theEvent locationInWindow] fromView:nil];

    point.y = [self bounds].size.height - point.y;

    point.x /= uiZoom;
    point.y /= uiZoom;

    [[CalcBackend sharedBackend] rightMouseDownAt:point];
}

- (void)mouseUp:(NSEvent *)theEvent
{
    NSPoint point = [self convertPoint:[theEvent locationInWindow] fromView:nil];

    point.y = [self bounds].size.height - point.y;

    point.x /= uiZoom;
    point.y /= uiZoom;

    [[CalcBackend sharedBackend] mouseUpAt:point];
}

- (NSDragOperation)draggingEntered:(id < NSDraggingInfo >)sender
{
    NSDragOperation result = NSDragOperationNone;
    NSPasteboard *pb = [sender draggingPasteboard];
    if ([CalcStack bestTypeFromPasteboard: pb])
        result = NSDragOperationCopy;
    return result;
}

- (void)copy:(id)sender
{
    NSError *err = nil;
    CalcStack *stack = [[CalcStack alloc] initWithError: &err];
    if (stack)
        [stack copyToPasteboard: [NSPasteboard generalPasteboard]];
    else
        NSBeep();
}

- (void)paste:(id)sender
{
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    CalcStack *stack = [[[CalcStack alloc] init] autorelease];
    if (![stack pasteFromPasteboard: pb])
        NSBeep();
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)item
{
    if ([item action] == @selector(paste:))
    {
        return (nil != [CalcStack bestTypeFromPasteboard: [NSPasteboard generalPasteboard]]);
    }
    return YES;
}

- (BOOL)prepareForDragOperation:(id < NSDraggingInfo >)sender
{
    return YES;
}

- (BOOL)performDragOperation:(id < NSDraggingInfo >)sender
{
    NSPasteboard *pb = [sender draggingPasteboard];
    CalcStack *stack = [[[CalcStack alloc] init] autorelease];
    return [stack pasteFromPasteboard: pb];
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (BOOL)keyEvent:(NSEvent *)theEvent pressed:(BOOL)aPressed
{
    unsigned modifiers = [theEvent modifierFlags];
    NSUInteger keyCode = [theEvent keyCode];
    
    if (0 != (modifiers & NSCommandKeyMask))
        return NO;

    CalcBackend *backend = [CalcBackend sharedBackend];

    /*
     * Mac numeric keypad -> KMI/Windows virtual key codes.
     */
    switch (keyCode)
    {
        case kVK_ANSI_KeypadDivide:
            [backend runKey:calcScancodeDivide pressed:aPressed];
            return YES;

        case kVK_ANSI_KeypadMultiply:
            [backend runKey:calcScancodeMultiply pressed:aPressed];
            return YES;

        case kVK_ANSI_KeypadMinus:
            [backend runKey:calcScancodeMinus pressed:aPressed];
            return YES;

        case kVK_ANSI_KeypadPlus:
            [backend runKey:calcScancodePlus pressed:aPressed];
            return YES;

        case kVK_ANSI_KeypadDecimal:
            [backend runKey:calcScancodeDecimal pressed:aPressed];
            return YES;

        case kVK_ANSI_KeypadEnter:
            [backend runKey:calcScancodeEnter pressed:aPressed];
            return YES;

        default:
            break;
    }

    /*
     * Normal keyboard.
     */
    NSString *chars = [theEvent characters];
    if ([chars length] == 0)
        return NO;

    unichar key;

    if ((modifiers & NSEventModifierFlagControl) &&
        [[theEvent charactersIgnoringModifiers] length] > 0)
    {
        key = [[theEvent charactersIgnoringModifiers] characterAtIndex:0];
    }
    else
    {
        key = [chars characterAtIndex:0];
    }

    /*
     * Normal keyboard operators.
     */
    switch (keyCode)
    {
        case kVK_ANSI_Slash:
            [backend runKey:calcScancodeDivide pressed:aPressed];
            return YES;

        case kVK_ANSI_Minus:
            [backend runKey:calcScancodeMinus pressed:aPressed];
            return YES;

        case kVK_ANSI_Period:
            [backend runKey:calcScancodeDecimal pressed:aPressed];
            return YES;

        case kVK_ANSI_Equal:
            [backend runKey:calcScancodePlus pressed:aPressed];
            return YES;

        case kVK_ANSI_8:
            if (modifiers & NSEventModifierFlagShift)
            {
                [backend runKey:calcScancodeMultiply pressed:aPressed];
                return YES;
            }
            break;

        default:
            break;
    }

    /*
     * Fix for Mac version.
     * KMI alphabet keycodes expect uppercase ASCII.
     */
    if (key >= 'a' && key <= 'z')
        key = (unichar)(key - 'a' + 'A');

    switch (key)
    {
        case 127:
        case NSDeleteFunctionKey:
            key = 8;
            break;

        case NSLeftArrowFunctionKey:
            key = 37;
            break;

        case NSUpArrowFunctionKey:
            key = 38;
            break;

        case NSRightArrowFunctionKey:
            key = 39;
            break;

        case NSDownArrowFunctionKey:
            key = 40;
            break;

        default:
            break;
    }
    
    [backend runKey:(BYTE)key pressed:aPressed];
    return YES;
}
- (void)keyDown:(NSEvent *)theEvent
{
    if (![self keyEvent:theEvent pressed:YES])
    {
        [super keyDown: theEvent];
    }
}

- (void)keyUp:(NSEvent *)theEvent
{
    if (![self keyEvent:theEvent pressed:NO])
    {
        [super keyUp: theEvent];
    }
}

// Updated to allow control to be held down (left-shift)
- (void)flagsChanged:(NSEvent *)theEvent
{
    unsigned modifiers = [theEvent modifierFlags];

    if (modifiers & NSEventModifierFlagCommand)
    {
        [super flagsChanged:theEvent];
        return;
    }

    CalcBackend *backend = [CalcBackend sharedBackend];

    /*
     * Mac Control = calculator Left Shift.
     */
    BOOL controlDown =
        (modifiers & NSEventModifierFlagControl) != 0;

    [backend runKey:16 pressed:controlDown];

    /*
     * Mac Option = calculator Right Shift.
     */
    BOOL optionDown =
        (modifiers & NSEventModifierFlagOption) != 0;

    [backend runKey:17 pressed:optionDown];
    
    [self setNeedsDisplay:YES];
}

- (void)buttonDrawing
{
    CalcBackend *backend = [CalcBackend sharedBackend];
    drawingButtonPressed = [backend drawingButtonPressed];
    drawingButtonType    = [backend drawingButtonType];
    drawingButtonRect    = [backend drawingButtonRect];
    drawingButtonRectPressed = [backend drawingButtonRectPressed];

    switch (drawingButtonType)
    {
        case 2: // do nothing
			break;
        default:
        {
            CGFloat nativeHeight = [self bounds].size.height / uiZoom;
            NSRect displayRect = drawingButtonRect;

            displayRect.origin.y =
                nativeHeight -
                displayRect.origin.y -
                displayRect.size.height;

            displayRect.origin.x *= uiZoom;
            displayRect.origin.y *= uiZoom;
            displayRect.size.width *= uiZoom;
            displayRect.size.height *= uiZoom;

            [self setNeedsDisplayInRect:displayRect];
        }
    }
}
- (CGFloat)uiZoom
{
    return uiZoom;
}

- (void)setUIZoomPercent:(CGFloat)percent
{
    if (percent <= 0)
        percent = 100.0;

    uiZoom = percent / 100.0;

    if (lcd && mainBitmap)
    {
        [self setLCD:lcd atOrigin:lcdOrigin];
    }

    [self setNeedsDisplay:YES];
}

- (NSSize)zoomedContentSize
{
    return NSMakeSize(
        backgroundSize.width * uiZoom,
        backgroundSize.height * uiZoom
    );
}

- (NSSize)nativeContentSize
{
    return NSMakeSize(
        backgroundSize.width,
        backgroundSize.height
    );
}

@end


VOID UpdateContrast(BYTE byContrast)
{
    [SharedView UpdateContrast: byContrast];
}

VOID UpdateDisplayPointers(VOID)
{
    [SharedView UpdateDisplayPointers];
}

VOID UpdateMainDisplay(VOID)
{
    [SharedView UpdateMainDisplay];
}

VOID UpdateMenuDisplay(VOID)
{
    [SharedView UpdateMenuDisplay];
}

// CdB for HP: add header management
VOID RefreshDisp0()
{
    [SharedView RefreshDisp0];
}

VOID WriteToMainDisplay(LPBYTE a, DWORD d, UINT s)
{
    CalcLCDWriteArgument *args = [[CalcLCDWriteArgument alloc] initWithPointer:a offset:d count:s];
    [SharedView WriteToMain: args];
    [args release];
}

VOID WriteToMenuDisplay(LPBYTE a, DWORD d, UINT s)
{
    CalcLCDWriteArgument *args = [[CalcLCDWriteArgument alloc] initWithPointer:a offset:d count:s];
    [SharedView WriteToMenu: args];
    [args release];
}

VOID UpdateAnnunciators(VOID)
{
    [SharedView performSelectorOnMainThread:@selector(UpdateAnnunciators) withObject:nil waitUntilDone:YES];
}

BYTE GetLineCounterGray(VOID)
{
    BYTE result = 0;
    BYTE *resultPtr = nil;
    NSMutableData *resultData = [[NSMutableData alloc] initWithBytes:&result length:sizeof(result)];
    [SharedView performSelectorOnMainThread:@selector(GetLineCounter:) withObject:resultData waitUntilDone:YES];
    resultPtr = (BYTE *)[resultData bytes];
    if (resultPtr)
        result = *resultPtr;
    [resultData release];
    return result;
}

VOID StartDisplayGray(BYTE byInitial)
{
    [SharedView performSelectorOnMainThread:@selector(StartDisplay:) withObject:[NSNumber numberWithUnsignedChar:byInitial] waitUntilDone:YES];
}

VOID StopDisplayGray(VOID)
{
    [SharedView performSelectorOnMainThread:@selector(StopDisplay) withObject:nil waitUntilDone:YES];
}

//################
//#
//# functions for black and white implementation
//#
//################

// LCD line counter calculation in BW mode
static BYTE F4096Hz(VOID)					// get a 6 bit 4096Hz down counter value
{
	LARGE_INTEGER lLC;
    
	QueryPerformanceCounter(&lLC);			// get counter value
    
	// calculate 4096 Hz frequency down counter value
	return -(BYTE)(((lLC.QuadPart - lAppStart.QuadPart) << 12) / lFreq.QuadPart) & 0x3F;
}

BYTE GetLineCounterBW(VOID)			// get line counter value
{
	_ASSERT(byVblRef < 0x40);
#ifdef USE_VBL
    // TODO: Make vbl work without garbage
	return (0x40 + F4096Hz() - byVblRef) & 0x3F;
#else
    return 0;   // avoids garbage
#endif
}

VOID StartDisplayBW(BYTE byInitial)
{
	// get positive VBL difference between now and stop time
	byVblRef = (0x40 + F4096Hz() - byInitial) & 0x3F;
}

VOID StopDisplayBW(VOID)
{
	BYTE a[2];
	ReadIO(a,LINECOUNT,2,TRUE);				// update VBL at display off time
}
