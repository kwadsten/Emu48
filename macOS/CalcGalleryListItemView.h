//
//  CalcGalleryListItemView.h
//

#import <Cocoa/Cocoa.h>

@interface CalcGalleryListItemView : NSCollectionViewItem
{
    NSImageView *imageView;
    NSTextField *title;
    NSTextField *info;
    NSTextField *kmlFilename;
}
@end
