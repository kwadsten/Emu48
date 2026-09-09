#import "CalcInfoButton.h"

@implementation CalcInfoButton

- (void)resetCursorRects
{
    [super resetCursorRects];

    NSRect bounds = [self bounds];

    /*
     * The info button is a 32x32 square and the circle
     * is drawn inside that area.
     */
    CGFloat inset = 2.0;
    NSRect circleRect = NSInsetRect(bounds, inset, inset);

    [self addCursorRect:circleRect
                 cursor:[NSCursor pointingHandCursor]];
}

@end
