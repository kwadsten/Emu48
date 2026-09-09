#import "CalcGalleryCollectionView.h"

@implementation CalcGalleryCollectionView

- (void)keyDown:(NSEvent *)event
{
    switch ([event keyCode])
    {
        case 36:  // Return
        case 76:  // Enter (numeric keypad)
        {
            id target = [self delegate];

            if (target &&
                [target respondsToSelector:@selector(openCalculator:)])
            {
                [target openCalculator:self];
                return;
            }

            break;
        }

        default:
            break;
    }

    [super keyDown:event];
}

@end
