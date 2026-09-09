//
//  CalcGalleryListItemView.m
//  emu48
//
//  A single calculator item for list view
//

#import "CalcGalleryListItemView.h"
#import "CalcGalleryImageView.h"
#import "CalcGalleryImageHelper.h"

@implementation CalcGalleryListItemView

- (void)loadView
{
    // 
    // Build the views for a single calculator (in list view)
    //
    const CGFloat listItemWidth = 680.0;
    const CGFloat listItemHeight = 72.0;

    NSFont *titleFont = [NSFont systemFontOfSize:14.0
                                          weight:NSFontWeightSemibold];
    const CGFloat titleFontHeight = 18;

    NSFont *bodyFont = [NSFont systemFontOfSize:14.0];
    const CGFloat bodyFontHeight = 18;

    const CGFloat imageWidth = 56.0;
    const CGFloat imageHeight = 56.0;

    const CGFloat kmlFilenameY = 9.0;
    const CGFloat titleBottomMargin = 1.0;
    const CGFloat textAreaWidth = 580.0;
    const CGFloat textAreaX = 80.0;

    CGFloat currYPos = kmlFilenameY;

    // List item view
    self.view =
        [[[NSView alloc]
            initWithFrame:NSMakeRect(0, 0, listItemWidth, listItemHeight)]
            autorelease];

    [self.view setWantsLayer:YES];

    // View coordinates are (0,0) = bottom left
    // So build our view from the bottom to the top

    // Calc kmlFilename line
    kmlFilename =
        [[NSTextField alloc]
            initWithFrame:NSMakeRect(textAreaX, currYPos, textAreaWidth, bodyFontHeight)];

    [kmlFilename setBezeled:NO];
    [kmlFilename setDrawsBackground:NO];
    [kmlFilename setEditable:NO];
    [kmlFilename setSelectable:NO];
    [kmlFilename setFont:bodyFont];
    [kmlFilename setTextColor:[NSColor secondaryLabelColor]];

    [self.view addSubview:kmlFilename];
    
    currYPos += bodyFontHeight;

    // Calc info line
    info =
        [[NSTextField alloc]
            initWithFrame:NSMakeRect(textAreaX, currYPos, textAreaWidth, bodyFontHeight)];

    [info setBezeled:NO];
    [info setDrawsBackground:NO];
    [info setEditable:NO];
    [info setSelectable:NO];
    [info setFont:bodyFont];
    [info setTextColor:[NSColor secondaryLabelColor]];

    [self.view addSubview:info];

    currYPos += bodyFontHeight + titleBottomMargin;

    // Calc title
    title =
        [[NSTextField alloc]
            initWithFrame:NSMakeRect(textAreaX, currYPos, textAreaWidth, titleFontHeight)];

    [title setBezeled:NO];
    [title setDrawsBackground:NO];
    [title setEditable:NO];
    [title setSelectable:NO];
    [title setFont:titleFont];

    [self.view addSubview:title];
   
    // Calc image
    imageView =
        [[CalcGalleryImageView alloc]
            initWithFrame:NSMakeRect(8, 8, imageWidth, imageHeight)];
    [imageView setCornerRadius:4.0];
    [imageView setImageScaling:NSImageScaleProportionallyUpOrDown];
    [imageView setImageAlignment:NSImageAlignCenter];
    [imageView setImageFrameStyle:NSImageFrameNone];

    [self.view addSubview:imageView];
}

- (void)dealloc
{
    [imageView release];
    [title release];
    [info release];

    [super dealloc];
}

// Called when NSCollectionView needs a view item to be 
//   loaded with data.  object = our calc data.
- (void)setRepresentedObject:(id)object
{
    [super setRepresentedObject:object];
    
    // Sometimes setRepresentedObject is called with nil object
    if (![object isKindOfClass:[NSDictionary class]])
    {
        [title setStringValue:@""];
        [info setStringValue:@""];
        [kmlFilename setStringValue:@""];

        return;
    }
    
    NSDictionary *calc = object;
    
    // List view doesn't need to split long title
   [title setStringValue:[calc objectForKey:@"title"]];
    
    // Info line has model desc * rom filename
    NSString *displayModel =
        [calc objectForKey:@"displayModel"];

    NSString *rom =
    [[calc objectForKey:@"rom"] lowercaseString];
        
    NSMutableArray *infoParts =
        [NSMutableArray array];

    if ([displayModel length])
        [infoParts addObject: displayModel];

    if ([rom length])
        [infoParts addObject:rom];

    [info setStringValue:
        [infoParts componentsJoinedByString:@"  •  "]];
    
    // kml filename line
    NSString *kmlPath = [calc objectForKey:@"path"];
    [kmlFilename setStringValue: [[kmlPath lastPathComponent] lowercaseString]];
    
    // Calc image
    [imageView setImage:
     [CalcGalleryImageHelper
      calculatorImageForDictionary:calc]];
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];

    if (selected)
    {
        [self.view.layer setBorderWidth:2.0];

        [self.view.layer setBorderColor:
            [[NSColor controlAccentColor] CGColor]];

        [self.view.layer setCornerRadius:8.0];
    }
    else
    {
        [self.view.layer setBorderWidth:0.0];
    }
}

@end
