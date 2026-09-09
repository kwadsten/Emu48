//
//  CalcGalleryImageHelper.m
//

#import "CalcGalleryImageHelper.h"

@implementation CalcGalleryImageHelper

+ (NSImage *)calculatorImageForDictionary:(NSDictionary *)calc
{
    NSString *imagePath = [calc objectForKey:@"imagePath"];
    NSValue *backgroundValue = [calc objectForKey:@"background"];

    if (![imagePath length] || !backgroundValue)
        return nil;

    NSImage *sourceImage =
        [[[NSImage alloc] initWithContentsOfFile:imagePath]
            autorelease];

    if (!sourceImage)
        return nil;

    CalcRect background;
    [backgroundValue getValue:&background];

    NSBitmapImageRep *bitmapRep = nil;

    for (NSImageRep *rep in [sourceImage representations])
    {
        if ([rep isKindOfClass:[NSBitmapImageRep class]])
        {
            bitmapRep = (NSBitmapImageRep *)rep;
            break;
        }
    }

    if (!bitmapRep)
        return nil;
    
    NSInteger imageWidth = [bitmapRep pixelsWide];
    NSInteger imageHeight = [bitmapRep pixelsHigh];

    NSInteger x = (NSInteger)background.origin.x;
    NSInteger y = (NSInteger)background.origin.y;
    NSInteger width = (NSInteger)background.size.width;
    NSInteger height = (NSInteger)background.size.height;

    /*
     * KML bitmap coordinates have their origin at the top-left.
     * NSBitmapImageRep drawing coordinates have their origin at
     * the bottom-left.
     */
    y = imageHeight - y - height;

    if (x < 0 || y < 0 ||
        width <= 0 || height <= 0 ||
        x + width > imageWidth ||
        y + height > imageHeight)
    {
        return nil;
    }

    NSRect cropRect =
        NSMakeRect(x, y, width, height);

    NSImage *croppedImage =
        [[[NSImage alloc]
            initWithSize:cropRect.size]
            autorelease];

    [croppedImage lockFocus];

    [sourceImage drawInRect:
        NSMakeRect(0.0,
                   0.0,
                   cropRect.size.width,
                   cropRect.size.height)
                   fromRect:cropRect
                  operation:NSCompositingOperationCopy
                   fraction:1.0];

    [croppedImage unlockFocus];

    return croppedImage;
    }

@end
