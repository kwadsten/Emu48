/*
 *  kmlparser.h
 *  emu48
 *
 *  Cocoa header file for kmlparser.m
 *
 *  Created by Da Woon Jung on Sat Feb 21 2004.
 *  Copyright (c) 2004 dwj. All rights reserved.
 *
 */

#import "pch.h"
#import "KML.H"
#import "mackml.h"

@class KmlParseResult;


@interface KmlParser : NSObject
{
    NSScanner *scanner;
    NSString *szLexString;
    BOOL bDebug;
    UINT nLexLine;
    UINT nLexInteger;
    UINT nBlocksIncludeLevel;
    UINT nLinesIncludeLevel;
    UINT nButtons;
    UINT nScancodes;
    UINT nAnnunciators;
    BOOL romTypeValid;
    BOOL romLoadSuccess;
    BOOL romCrcValid;
    BOOL mainBitmapValid;
    NSString *errReason;
    id delegate;
}

- (id)delegate;
- (void)setDelegate:(id)aDelegate;
- (UINT)blockIncludeLevel;
- (void)setBlockIncludeLevel:(UINT)aLevel;
- (UINT)lineIncludeLevel;
- (void)setLineIncludeLevel:(UINT)aLevel;

- (IBAction)DisplayKMLLog:(id)sender;

- (KmlBlock *)ParseIncludeBlocks:(NSString *)aFilename includeLevel:(int)aIncludeLevel error:(NSString **)aErrmsg;
- (KmlLine *)ParseIncludeLines:(NSString *)aFilename includeLevel:(int)aIncludeLevel error:(NSString **)aErrmsg;
// Call this method to begin parsing
- (KmlParseResult *)ParseKML:(NSString *)filename error:(NSError **)outError;
- (void)KillKML;
- (KmlParseResult *)LoadKMLGlobal:(NSString *)filename;
- (CalcRect)LoadKMLBackground:(NSString *)filename;
- (void)InitLex:(NSString *)szScript;
- (void)CleanLex;
- (TokenId)Lex:(UINT)nMode;
- (KmlBlock *)IncludeBlocks:(NSString *)szFilename;
- (KmlLine *)IncludeLines:(NSString *)szFilename;
- (KmlBlock *)ParseBlocks;
- (KmlBlock *)ParseBlock:(TokenId)eType;
- (KmlLine *)ParseLines;
- (KmlLine *)ParseLine:(TokenId)eCommand;
- (TokenId)ParseToken:(UINT)nMode;
- (void)SkipWhite:(UINT)nMode;
- (void)FatalError;
@end

@interface KmlParser (Init)
- (void)InitGlobal:(KmlBlock *)pBlock;
- (KmlLine *)InitAnnunciator:(KmlBlock *)pBlock;
- (KmlLine *)InitBackground:(KmlBlock *)pBlock;
- (void)InitButton:(KmlBlock *)pBlock;
- (KmlLine *)InitLcd:(KmlBlock *)pBlock;
@end

@interface KmlParseResult : NSObject
{
    KmlBlock *block;
    NSString *kmlPath;
    NSString *romPath;
    NSString *patchPath;
    KmlBlock *pVKey[256];
    KmlButton pButton[256];
    KmlAnnunciatorC pAnnunciator[6];
    unsigned nButtons;
    BOOL     bDebug;	// YES: keyhit=>print scancode to console
    CalcImage *mainBitmap;
    CalcRect   background;
    CalcPoint  lcdOrigin;
    CGFloat lcdScaleX; // v1.68 changes
    CGFloat lcdScaleY;
    unsigned scaleMul; // v1.68 changes
    unsigned scaleDiv;
    NSMutableDictionary *lcdColors;
}
- (id)initWithKmlPath:(NSString *)path;
- (void)setFirstBlock:(KmlBlock *)aBlock;
- (NSString *)stringForBlockId:(TokenId)aBlock
                     commandId:(TokenId)aCommand
                       atIndex:(unsigned int)aIndex;
- (int)integerForBlockId:(TokenId)aBlock
              commandId:(TokenId)aCommand
                atIndex:(unsigned int)aIndex;

- (void)parsedRomPath:(NSString *)path;
- (void)parsedPatchPath:(NSString *)path;
- (void)parsedVKey:(KmlBlock *)aVKey atIndex:(int)aIndex;
- (void)parsedButton:(KmlButton)aButton;
- (void)parsedAnnunciator:(KmlAnnunciatorC)aAnnun atIndex:(int)aIndex;
- (void)parsedDebug:(BOOL)aDebug;
- (BOOL)mainBitmapDefined;
- (void)parsedMainBitmap:(CalcImage *)aImage;
- (void)parsedBackground:(CalcRect)aRect;
- (void)parsedLcdOrigin:(CalcPoint)aPoint;
- (void)applyScale;
- (void)parsedLcdScaleX:(unsigned)x scaleY:(unsigned)y; // v1.68 changes
- (void)parsedLcdColorAtIndex:(UINT)aIndex red:(UINT)aRed green:(UINT)aGreen blue:(UINT)aBlue;

- (NSString *)kmlPath;
- (void)reloadRom;
- (void)reloadButtons:(BYTE *)Keyboard_Row size:(UINT)nSize;
- (KmlBlock **)VKeys;
- (KmlButton *)buttons;
- (KmlAnnunciatorC *)annunciators;
- (unsigned)countOfButtons;
- (BOOL)debug;
- (CalcImage *)mainBitmap;
- (CalcRect)background;
// v1.68 changes
- (unsigned) scaleMul;
- (unsigned) scaleDiv;
- (CalcPoint)lcdOrigin;
- (CGFloat)lcdScaleX;
- (CGFloat)lcdScaleY;
- (NSDictionary *)lcdColors;
- (void)setScaleMul:(unsigned)mul div:(unsigned)div;
@end


// Utility functions
extern NSString *GetStringOf(TokenId);
extern void AddToLog(NSString *);
extern void PrintfToLog(NSString *format, ...);
extern NSString *MapKMLFile(NSString *filename);
extern BOOL IsBlock(TokenId);
extern KmlLine *SkipLines(KmlLine* pLine, TokenId);
