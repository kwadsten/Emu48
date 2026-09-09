//
//  CalcGalleryCardItemView.h
//

#import <Cocoa/Cocoa.h>

@interface CalcGalleryCardItemView : NSCollectionViewItem
{
    NSImageView *imageView;
    NSTextField *title;
    NSTextField *info;
    NSTextField *kmlFilename;
}
@end
