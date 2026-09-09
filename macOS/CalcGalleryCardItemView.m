//
//  CalcGalleryItemView.m
//  emu48
//
//  A single calculator item for the card view
//

#import "CalcGalleryCardItemView.h"
#import "CalcGalleryImageView.h"
#import "CalcGalleryImageHelper.h"

@implementation CalcGalleryCardItemView

- (void)loadView
{
    // 
    // Build the views for a single calculator (in card view)
    //
    const CGFloat cardItemWidth = 220.0;
    const CGFloat cardItemHeight = 260.0;

    NSFont *titleFont = [NSFont systemFontOfSize:14.0
                                          weight:NSFontWeightSemibold];
    const CGFloat titleFontHeight = 18;

    NSFont *bodyFont = [NSFont systemFontOfSize:14.0];
    const CGFloat bodyFontHeight = 18;

    const CGFloat imageHeight = 160.0;
    const CGFloat imageBottomMargin = 10.0;

    const CGFloat contentWidth = 190.0;
    const CGFloat xPos = 15.0; // Left margin

    CGFloat currYPos = 6.0;

    // Card item view
    self.view =
        [[[NSView alloc]
            initWithFrame:NSMakeRect(0, 0, cardItemWidth, cardItemHeight)]
            autorelease];

    [self.view setWantsLayer:YES];

    // View coordinates are (0,0) = bottom left
    // So build our view from the bottom to the top

    //
    // kml filename line
    //
    kmlFilename =
        [[[NSTextField alloc]
            initWithFrame:NSMakeRect(xPos, currYPos, contentWidth, bodyFontHeight)]
            autorelease];

    [kmlFilename setBezeled:NO];
    [kmlFilename setDrawsBackground:NO];
    [kmlFilename setEditable:NO];
    [kmlFilename setSelectable:NO];
    [kmlFilename setAlignment:NSTextAlignmentCenter];
    [kmlFilename setFont:bodyFont];
    [kmlFilename setTextColor:[NSColor secondaryLabelColor]];
    [kmlFilename setIdentifier:@"calculatorKmlFilename"];

    [self.view addSubview:kmlFilename];

    currYPos += bodyFontHeight;

    //
    // info line
    //
    info =
        [[[NSTextField alloc]
            initWithFrame:NSMakeRect(xPos, currYPos, contentWidth, bodyFontHeight)]
            autorelease];

    [info setBezeled:NO];
    [info setDrawsBackground:NO];
    [info setEditable:NO];
    [info setSelectable:NO];
    [info setAlignment:NSTextAlignmentCenter];
    [info setFont:bodyFont];
    [info setTextColor:[NSColor secondaryLabelColor]];
    [info setIdentifier:@"calculatorInfo"];

    [self.view addSubview:info];

    currYPos += bodyFontHeight;

    //
    // Calculator title
    //
    title =
        [[[NSTextField alloc]
            initWithFrame:NSMakeRect(xPos, currYPos, contentWidth, titleFontHeight * 2)]
            autorelease];

    [title setBezeled:NO];
    [title setDrawsBackground:NO];
    [title setEditable:NO];
    [title setSelectable:NO];
    [title setAlignment:NSTextAlignmentCenter];
    [title setFont:titleFont];
    [title setLineBreakMode:NSLineBreakByTruncatingTail];
    [title setMaximumNumberOfLines:2];
    [title setIdentifier:@"calculatorTitle"];

    [self.view addSubview:title];
    
    currYPos += (titleFontHeight * 2) + imageBottomMargin;
    
    //
    // Calculator image
    //
    imageView =
        [[[CalcGalleryImageView alloc]
            initWithFrame:NSMakeRect(xPos, currYPos, contentWidth, imageHeight)]
            autorelease];

    [imageView setCornerRadius:8.0];
    [imageView setImageScaling:NSImageScaleProportionallyUpOrDown];
    [imageView setImageAlignment:NSImageAlignCenter];
    [imageView setIdentifier:@"calculatorImage"];

    [self.view addSubview:imageView];
}

- (NSView *)viewWithIdentifier:(NSString *)identifier
{
    for (NSView *subview in [self.view subviews])
    {
        if ([[subview identifier] isEqualToString:identifier])
            return subview;
    }

    return nil;
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

    // Split long title if necessary
    NSString *fullTitle = [calc objectForKey:@"title"] ?: @"";
    NSRange splitRange = [fullTitle rangeOfString:@" ("];

    if (splitRange.location != NSNotFound)
    {
        NSString *firstLine =
            [fullTitle substringToIndex:splitRange.location];

        NSString *secondLine =
            [fullTitle substringFromIndex:splitRange.location + 1];

        [title setStringValue:
            [NSString stringWithFormat:@"%@\n%@", firstLine, secondLine]];
    }
    else
    {
        [title setStringValue:fullTitle];
    }
    
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
