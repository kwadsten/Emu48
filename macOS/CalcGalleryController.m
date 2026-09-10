//
//  CalcGalleryController.m
//

#import "CalcGalleryController.h"
#import "CalcManager.h"
#import "CalcGalleryImageView.h"
#import "CalcGalleryListItemView.h"
#import "CalcGalleryCardItemView.h"
#import "CalcGalleryCollectionView.h"
#import "CalcGalleryImageHelper.h"
#import "CalcGalleryWindow.h"

static NSString * const kCalcGalleryViewModePreference =
    @"CalcGalleryViewMode";

static const CGFloat kGalleryWindowWidth = 620.0;
static const CGFloat kGalleryWindowHeight = 680.0;
static const CGFloat kGalleryMargin = 24.0;
static const CGFloat kGalleryButtonWidth = 100.0;
static const CGFloat kGalleryButtonSpacing = 20.0;

@interface CalcGalleryController ()
    <NSCollectionViewDataSource,
     NSCollectionViewDelegate>
@end


@implementation CalcGalleryController

- (id)initWithCalcManager:(CalcManager *)aManager
{
    CalcGalleryWindow *window =
        [[CalcGalleryWindow alloc]
            initWithContentRect:NSMakeRect(0, 0, kGalleryWindowWidth, kGalleryWindowHeight)
                      styleMask:(NSWindowStyleMaskTitled |
                                 NSWindowStyleMaskClosable)
                        backing:NSBackingStoreBuffered
                          defer:NO];

    [window setCancelTarget:self];
    [window setDelegate:self];

    self = [super initWithWindow:window];

    if (self)
    {
        calcManager = [aManager retain];

        NSInteger savedMode =
            [[NSUserDefaults standardUserDefaults]
                integerForKey:kCalcGalleryViewModePreference];

        if (savedMode != CalcGalleryViewModeCards &&
            savedMode != CalcGalleryViewModeList)
        {
            savedMode = CalcGalleryViewModeCards;
        }

        viewMode = (CalcGalleryViewMode)savedMode;
        
        [window setTitle:@"Choose Calculator"];
        [window setReleasedWhenClosed:NO];

        NSView *contentView =
            [window contentView];

        /*
         * Title.
         */
        [window setTitle:@"Choose a calculator:"];
        
        /*
         * Collection view.
         */
        scrollView =
            [[NSScrollView alloc]
                initWithFrame:
                    NSMakeRect(kGalleryMargin,
                               60,
                               kGalleryWindowWidth - 2.0 * kGalleryMargin,
                               570)];

        [scrollView setHasVerticalScroller:YES];
        [scrollView setHasHorizontalScroller:NO];
        [scrollView setBorderType:NSBezelBorder];

        NSCollectionViewFlowLayout *layout =
            [[[NSCollectionViewFlowLayout alloc] init] autorelease];

        [layout setItemSize:NSMakeSize(220, 260)];
        [layout setMinimumInteritemSpacing:5.0];
        [layout setMinimumLineSpacing:16.0];
        [layout setSectionInset:
            NSEdgeInsetsMake(16.0, 16.0, 16.0, 16.0)];

        /*
         * View mode control.
         */
        CGFloat contentHeight = NSHeight([contentView bounds]);

        viewModeControl =
            [[NSSegmentedControl alloc]
                initWithFrame:
                    NSMakeRect((kGalleryWindowWidth - 90.0) / 2.0,
                               contentHeight - 37.0,
                               90.0,
                               24.0)];

        [viewModeControl setSegmentCount:2];

        [viewModeControl setLabel:@"Cards" forSegment:0];
        [viewModeControl setLabel:@"List" forSegment:1];

        [viewModeControl setSelectedSegment:viewMode];

        [viewModeControl setTarget:self];
        [viewModeControl setAction:@selector(changeViewMode:)];

        [contentView addSubview:viewModeControl];
        
        calculatorsView =
            [[NSCollectionView alloc]
                initWithFrame:
                    NSMakeRect(0, 0,
                               kGalleryWindowWidth - 2.0 * kGalleryMargin,
                               460)];

        [calculatorsView setCollectionViewLayout:layout];
        [calculatorsView setDataSource:self];
        [calculatorsView setDelegate:self];

        [calculatorsView setSelectable:YES];
        [calculatorsView setAllowsEmptySelection:NO];
        [calculatorsView setAllowsMultipleSelection:NO];

        NSClickGestureRecognizer *doubleClick =
            [[[NSClickGestureRecognizer alloc]
                initWithTarget:self
                        action:@selector(openCalculator:)] autorelease];
        [doubleClick setNumberOfClicksRequired:2];
        [calculatorsView addGestureRecognizer:doubleClick];

        [calculatorsView registerClass:[CalcGalleryCardItemView class]
                    forItemWithIdentifier:@"CalculatorItem"];
        
        [calculatorsView registerClass:[CalcGalleryListItemView class]
                    forItemWithIdentifier:@"CalculatorListItem"];

        [scrollView setDocumentView:calculatorsView];

        [contentView addSubview:scrollView];

        /*
         * Cancel button.
         */
        CGFloat buttonY = 15.0;
        CGFloat rightMargin = kGalleryMargin;

        NSButton *cancelButton =
            [[NSButton alloc]
                initWithFrame:
                    NSMakeRect(kGalleryWindowWidth -
                                   rightMargin -
                                   2.0 * kGalleryButtonWidth -
                                   kGalleryButtonSpacing,
                               buttonY,
                               kGalleryButtonWidth,
                               32)];

        [cancelButton setTitle:@"Cancel"];
        [cancelButton setBezelStyle:NSBezelStyleRounded];
        [cancelButton setTarget:self];
        [cancelButton setAction:@selector(cancelGallery:)];

        [contentView addSubview:cancelButton];

        [cancelButton release];

        /*
         * Open button.
         */
        actionButton =
            [[NSButton alloc]
                initWithFrame:
                    NSMakeRect(kGalleryWindowWidth -
                                   rightMargin -
                                   kGalleryButtonWidth,
                               buttonY,
                               kGalleryButtonWidth,
                               32)];

        [actionButton setTitle:@"Open"];
        [actionButton setKeyEquivalent:@"\r"];
        [actionButton setBezelStyle:NSBezelStyleRounded];
        [actionButton setTarget:self];
        [actionButton setAction:@selector(openCalculator:)];

        [contentView addSubview:actionButton];

        [window center];
    }

    [window release];

    return self;
}

- (IBAction)changeViewMode:(id)sender
{
    viewMode =
        ([sender selectedSegment] == 1)
            ? CalcGalleryViewModeList
            : CalcGalleryViewModeCards;

    [[NSUserDefaults standardUserDefaults]
        setInteger:viewMode
           forKey:@"CalcGalleryViewMode"];

    [self updateGalleryLayout];

    [calculatorsView reloadData];

    NSInteger count =
        [[calcManager calculators] count];

    if (count > 0)
    {
        [calculatorsView
            setSelectionIndexes:
                [NSIndexSet indexSetWithIndex:0]];
    }
}

- (void)updateGalleryLayout
{
    NSCollectionViewFlowLayout *layout =
        [[[NSCollectionViewFlowLayout alloc] init] autorelease];

    if (viewMode == CalcGalleryViewModeCards)
    {
        [layout setItemSize:NSMakeSize(220, 260)];
        [layout setMinimumInteritemSpacing:16.0];
        [layout setMinimumLineSpacing:16.0];
        [layout setSectionInset:
            NSEdgeInsetsMake(16.0, 16.0, 16.0, 16.0)];
    }
    else
    {
        CGFloat width =
            NSWidth([scrollView contentView].bounds) - 16.0;

        [layout setItemSize:NSMakeSize(width, 72)];
        [layout setMinimumInteritemSpacing:0.0];
        [layout setMinimumLineSpacing:1.0];
        [layout setSectionInset:
            NSEdgeInsetsMake(8.0, 8.0, 8.0, 8.0)];
    }

    [calculatorsView setCollectionViewLayout:layout];
}


- (void)dealloc
{
    [viewModeControl release];
    [calculatorsView release];
    [scrollView release];
    [calcManager release];
    [actionButton release];

    [super dealloc];
}

- (void)setActionButtonTitle:(NSString *)title
{
    [actionButton setTitle:title];
}


- (void)showGallery
{
    
    [calcManager refreshCalculators:nil];
    
    [self updateGalleryLayout];

    [calculatorsView reloadData];

    NSInteger count =
        [[calcManager calculators] count];

    [actionButton setEnabled:(count > 0)];

    /*
     * Default to first calculator.
     */
    if (count > 0)
    {
        [calculatorsView
            setSelectionIndexes:
                [NSIndexSet indexSetWithIndex:0]];
    }

    [[self window] makeKeyAndOrderFront:nil];
}


- (IBAction)cancelGallery:(id)sender
{
    NSWindow *window = [self window];
    NSWindow *parent = [window sheetParent];

    if (parent)
        [parent endSheet:window];
    else
        [window close];
}


- (void)defaultCalculatorChanged:(NSNotification *)notification
{
    [calculatorsView reloadData];
}


#pragma mark -
#pragma mark NSCollectionViewDataSource


- (NSInteger)collectionView:(NSCollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section
{
    return [[calcManager calculators] count];
}


- (NSCollectionViewItem *)collectionView:
        (NSCollectionView *)collectionView
        itemForRepresentedObjectAtIndexPath:
        (NSIndexPath *)indexPath
{
    NSString *identifier;

    if (viewMode == CalcGalleryViewModeCards)
        identifier = @"CalculatorItem";
    else
        identifier = @"CalculatorListItem";

    NSCollectionViewItem *item =
        [collectionView makeItemWithIdentifier:identifier
                                   forIndexPath:indexPath];

    NSDictionary *calc =
        [[calcManager calculators]
            objectAtIndex:[indexPath item]];

    [item setRepresentedObject:calc];

    return item;
}


#pragma mark -
#pragma mark Selection


- (void)openCalculator:(id)sender
{
    NSIndexPath *indexPath =
        [[calculatorsView selectionIndexPaths] anyObject];

    if (!indexPath)
        return;

    NSArray *calculators = [calcManager calculators];

    if ([indexPath item] >= [calculators count])
        return;

    NSDictionary *calc =
        [calculators objectAtIndex:[indexPath item]];

    if (![calc isKindOfClass:[NSDictionary class]])
        return;

    NSString *path = [calc objectForKey:@"path"];

    if (![path length] ||
        ![[NSFileManager defaultManager] fileExistsAtPath:path])
    {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];

        [alert setMessageText:@"Calculator not found"];

        [alert setInformativeText:
            [NSString stringWithFormat:
                @"The calculator file could not be found.\n\n%@",
                path ?: @"Unknown location"]];

        [alert addButtonWithTitle:@"OK"];
        [alert runModal];

        return;
    }

    [[self window] orderOut:nil];

    if (delegate &&
        [delegate respondsToSelector:
            @selector(calculatorGalleryDidChooseCalculator:)])
    {
        [delegate
            calculatorGalleryDidChooseCalculator:calc];
    }
}


- (void)setDelegate:(id)aDelegate
{
    delegate = aDelegate;
}

@end
