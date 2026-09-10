#import "CalcGalleryWindow.h"

@implementation CalcGalleryWindow

@synthesize cancelTarget;

- (void)cancelOperation:(id)sender
{
    if (cancelTarget &&
        [cancelTarget respondsToSelector:@selector(cancelGallery:)])
    {
        [cancelTarget cancelGallery:sender];
    }
}

@end
