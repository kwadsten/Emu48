//
//  CalcGalleryController.h
//

#import <Cocoa/Cocoa.h>

@class CalcManager;

@protocol CalcGalleryControllerDelegate;

typedef NS_ENUM(NSInteger, CalcGalleryViewMode)
{
    CalcGalleryViewModeCards = 0,
    CalcGalleryViewModeList = 1
};

@interface CalcGalleryController : NSWindowController <NSWindowDelegate>
{
    CalcManager *calcManager;
    id delegate;

    NSButton *actionButton;

    NSScrollView *scrollView;
    NSCollectionView *calculatorsView;

    CalcGalleryViewMode viewMode;
    NSSegmentedControl *viewModeControl;
}

- (id)initWithCalcManager:(CalcManager *)aManager;

- (void)setDelegate:(id)aDelegate;
- (void)setActionButtonTitle:(NSString *)title;

- (void)showGallery;
- (IBAction)cancelGallery:(id)sender;
- (IBAction)changeViewMode:(id)sender;

@end

@protocol CalcGalleryControllerDelegate <NSObject>

@optional

- (void)calculatorGalleryDidChooseCalculator:(NSDictionary *)calculator;

@end
