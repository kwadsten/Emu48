#import "CalcGalleryImageView.h"
#import "CalcGalleryImageHelper.h"
#import "CalcGalleryImageView.h"

@implementation CalcGalleryImageView

- (void)setCornerRadius:(CGFloat)radius
{
    cornerRadius = radius;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect
{
    NSImage *image = [self image];

    if (!image)
        return;

    NSRect bounds = [self bounds];
    NSSize imageSize = [image size];

    if (imageSize.width <= 0.0 || imageSize.height <= 0.0)
        return;

    CGFloat scaleX = bounds.size.width / imageSize.width;
    CGFloat scaleY = bounds.size.height / imageSize.height;
    CGFloat scale = MIN(scaleX, scaleY);

    NSSize displayedSize =
        NSMakeSize(imageSize.width * scale,
                   imageSize.height * scale);

    NSRect imageRect =
        NSMakeRect(
            bounds.origin.x +
                (bounds.size.width - displayedSize.width) / 2.0,
            bounds.origin.y +
                (bounds.size.height - displayedSize.height) / 2.0,
            displayedSize.width,
            displayedSize.height);

    /*
     * Shadow.
     */
    NSBezierPath *shadowPath =
        [NSBezierPath bezierPathWithRoundedRect:imageRect
                                         xRadius:cornerRadius
                                         yRadius:cornerRadius];

    NSShadow *shadow =
        [[[NSShadow alloc] init] autorelease];

    [shadow setShadowColor:
        [[NSColor blackColor] colorWithAlphaComponent:0.35]];

    [shadow setShadowBlurRadius:8.0];

    [shadow setShadowOffset:NSMakeSize(0.0, -4.0)];

    [shadow set];

    [[NSColor blackColor] setFill];
    [shadowPath fill];

    /*
     * Clip the calculator image to rounded corners.
     */
    NSBezierPath *clipPath =
        [NSBezierPath bezierPathWithRoundedRect:imageRect
                                         xRadius:cornerRadius
                                         yRadius:cornerRadius];

    [clipPath addClip];

    [image drawInRect:imageRect
             fromRect:NSZeroRect
            operation:NSCompositingOperationSourceOver
             fraction:1.0];
}

@end
