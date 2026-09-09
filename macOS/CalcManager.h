//
//  CalcManager.h
//  emu48
//

#import <Cocoa/Cocoa.h>

@interface CalcManager : NSObject
{
    NSArray *standardCalcs;
    NSMutableArray *calculators;
    NSString *startupCalculator;
}

+ (CalcManager *)sharedManager;

+ (NSArray *)calculatorsAtPath:(NSString *)aPath
                relativeToPath:(NSString *)base;

- (NSMutableArray *)calculators;
- (void)setCalculators:(NSArray *)aCalculators;

- (NSString *)StartupCalculator;
- (void)setStartupCalculator:(NSString *)aPath;
- (NSDictionary *)startupCalculator;

- (void)refreshCalculators:(id)sender;

- (int)StartupMode;
- (void)setStartupMode:(int)aMode;

@end
