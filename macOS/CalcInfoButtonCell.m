#import "CalcInfoButtonCell.h"

@implementation CalcInfoButtonCell

- (void)drawWithFrame:(NSRect)cellFrame
               inView:(NSView *)controlView
{
    CGFloat inset = 2.0;

    NSRect circleRect =
        NSInsetRect(cellFrame, inset, inset);

    /*
     * Transparent outside the circle.
     *
     * Use the existing background behind the button,
     * so the circle itself appears dark.
     */
    [[NSColor colorWithCalibratedWhite:0.0
                                 alpha:0.50] setFill];

    NSBezierPath *circle =
        [NSBezierPath bezierPathWithOvalInRect:circleRect];

    [circle fill];

    /*
     * White circular border.
     */
    [[[NSColor whiteColor] colorWithAlphaComponent:0.7] setStroke];

    [circle setLineWidth:1.5];
    [circle stroke];

    /*
     * White "i".
     */
    NSDictionary *attributes =
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSFont systemFontOfSize:18.0],
            NSFontAttributeName,
            [[NSColor whiteColor] colorWithAlphaComponent:0.7],
            NSForegroundColorAttributeName,
            nil];

    NSString *text = @"i";

    NSSize textSize =
        [text sizeWithAttributes:attributes];

    NSPoint textOrigin =
        NSMakePoint(
            NSMidX(circleRect) - textSize.width / 2.0,
            NSMidY(circleRect) - textSize.height / 2.0 + 1.0
        );

    [text drawAtPoint:textOrigin
       withAttributes:attributes];
}

@end
