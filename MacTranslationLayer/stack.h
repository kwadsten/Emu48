//
//  stack.h
//  emu48
//
//  Created by Da-Woon Jung on 2009-07-16.
//  Copyright 2009 dwj. All rights reserved.
//

#import "TYPES.H"
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 30000
#import <MobileCoreServices/MobileCoreServices.h>
#endif

extern NSString *Emu48ObjectPBoardType;


@interface CalcStack : NSObject
{
    NSData   *objectRepresentation;
    NSString *stringRepresentation;
}
- (id)initWithError:(NSError **)outError;
- (id)initWithObject:(NSData *)aData;
- (id)initWithString:(NSString *)aString;

- (NSData *)objectRepresentation;
- (NSString *)stringRepresentation;
- (void)setObjectRepresentation:(NSData *)aObjectRepresentation;
- (void)setStringRepresentation:(NSString *)aStringRepresentation;

- (void)pasteObjectRepresentation:(NSError **)outError;
- (void)pasteStringRepresentation:(NSError **)outError;

#if !TARGET_OS_IPHONE || (__IPHONE_OS_VERSION_MIN_REQUIRED >= 30000)
+ (NSArray *)copyableTypes;
+ (NSString *)bestTypeFromPasteboard:(CalcPasteboard *)pb;
- (BOOL)copyToPasteboard:(CalcPasteboard *)pb;
- (BOOL)pasteFromPasteboard:(CalcPasteboard *)pb;
#endif
@end
