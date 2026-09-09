//
//  CalcManager.m
//  emu48
//

#import "CalcManager.h"
#import "pch.h"
#import "EMU48.H"
#import "IO.H"
#import "files.h"
#import "kmlparser.h"

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 30000
#import <MobileCoreServices/MobileCoreServices.h>
#endif

#define CALC_RES_PATH       @"Calculators"
#define CALC_USER_PATH      @"emu48/kml"

@interface CalcManager(Private)

@end


@implementation CalcManager

- (id)init
{
    self = [super init];

    if (self)
    {
        calculators = [[NSMutableArray alloc] init];

//        standardCalcs =
//            [[[self class] calculatorsAtPath:CALC_RES_PATH
//                              relativeToPath:[[NSBundle mainBundle] resourcePath]]
//                retain];

        if (standardCalcs)
        {
            NSEnumerator *standardCalcEnum =
                [standardCalcs objectEnumerator];

            NSNumber *readonly =
                [[NSNumber alloc] initWithBool:YES];

            id standardCalc;

            while ((standardCalc = [standardCalcEnum nextObject]))
            {
                [standardCalc setObject:readonly
                                 forKey:@"readonly"];
            }

            [readonly release];
        }

//        [self refreshCalculators:nil];
    }

    return self;
}


- (void)dealloc
{
    [calculators release];
    [standardCalcs release];
    [startupCalculator release];

    [super dealloc];
}

+ (CalcManager *)sharedManager
{
    static CalcManager *sharedManager = nil;

    if (sharedManager == nil)
    {
        sharedManager = [[CalcManager alloc] init];
    }

    return sharedManager;
}

+ (NSArray *)calculatorsAtPath:(NSString *)aCalcPath
                relativeToPath:(NSString *)base
{
    NSMutableArray *result = nil;
    NSFileManager *fm = [NSFileManager defaultManager];

    BOOL isFolder = NO;

    NSString *calcPath =
        base
        ? [base stringByAppendingPathComponent:aCalcPath]
        : aCalcPath;

    if (![fm fileExistsAtPath:calcPath isDirectory:&isFolder]
        || !isFolder)
    {
        return nil;
    }

    NSDirectoryEnumerator *dirEnum =
        [fm enumeratorAtPath:calcPath];

    NSString *kmlFile;

    NSString *kmlExt =
        (NSString *)UTTypeCopyPreferredTagWithClass(
            (CFStringRef)@"com.mac.emu48-kml",
            kUTTagClassFilenameExtension);

    if (nil == kmlExt)
        return nil;

    KmlParser *parser = [[KmlParser alloc] init];

    result = [NSMutableArray array];

    while ((kmlFile = [dirEnum nextObject]))
    {
        if (NSOrderedSame !=
            [[kmlFile pathExtension]
                caseInsensitiveCompare:kmlExt])
        {
            continue;
        }

        NSString *kmlPath =
            [calcPath stringByAppendingPathComponent:kmlFile];

        KmlParseResult *kml =
            [parser LoadKMLGlobal:kmlPath];

        if (nil == kml)
            continue;

        NSString *title =
            [kml stringForBlockId:TOK_GLOBAL
                        commandId:TOK_TITLE
                          atIndex:0];

        if (nil == title)
            title = NSLocalizedString(@"Untitled", @"");


        NSString *author =
            [kml stringForBlockId:TOK_GLOBAL
                        commandId:TOK_AUTHOR
                          atIndex:0];

        if (nil == author)
            author = NSLocalizedString(@"<Unknown Author>", @"");


        NSString *model =
            [kml stringForBlockId:TOK_GLOBAL
                        commandId:TOK_MODEL
                          atIndex:0];

        if (nil == model)
            model = @"";

        NSString *rom =
        [kml stringForBlockId:TOK_GLOBAL
                                commandId:TOK_ROM
                                  atIndex:0];

        if (nil == rom)
            rom = @"";
        
        int modelClass =
            [kml integerForBlockId:TOK_GLOBAL
                        commandId:TOK_CLASS
                          atIndex:0];

        NSString *displayModel = @"";

        if ([model isEqualToString:@"6"])
        {
            displayModel = @"HP38G (64KB)";
        }
        else if ([model isEqualToString:@"A"])
        {
            displayModel = @"HP38G";
        }
        if ([model isEqualToString:@"E"])
        {
            if (modelClass == 39)
                displayModel = @"HP39G";
            else if (modelClass == 40)
                displayModel = @"HP40G";
            else
                displayModel = @"HP39G/40G";
        }
        else if ([model isEqualToString:@"G"])
        {
            displayModel = @"HP48G/G+/GX";
        }
        else if ([model isEqualToString:@"S"])
        {
            displayModel = @"HP48S/SX";
        }
        else if ([model isEqualToString:@"X"])
        {
            displayModel = @"HP49G";
        }
        else if ([model isEqualToString:@"Q"])
        {
            displayModel = @"HP50G";
        }
        else
        {
            displayModel = model;
        }
        
        if (nil == model)
            model = @"";

        NSString *imagePath =
            [kml stringForBlockId:TOK_GLOBAL
                        commandId:TOK_BITMAP
                          atIndex:0];

        NSMutableDictionary *calc =
            [NSMutableDictionary dictionaryWithObjectsAndKeys:
                title,        @"title",
                author,       @"author",
                model,        @"model",
                rom,          @"rom",
                [NSNumber numberWithInt:modelClass], @"class",
                displayModel, @"displayModel",
                base
                    ? [aCalcPath stringByAppendingPathComponent:kmlFile]
                    : kmlPath,
                @"path",
                nil];


        if (imagePath && [imagePath length] > 0)
        {
            [calc setObject:
                [calcPath stringByAppendingPathComponent:imagePath]
                forKey:@"imagePath"];
            
            CalcRect background =
                [parser LoadKMLBackground:kmlPath];

            [calc setObject:
                [NSValue valueWithBytes:&background
                               objCType:@encode(CalcRect)]
                       forKey:@"background"];
        }

        [result addObject:calc];
    }

    [parser release];
    [kmlExt release];

    return result;
}


- (NSMutableArray *)calculators
{
    return calculators;
}


- (void)setCalculators:(NSArray *)aCalculators
{
    [calculators setArray:aCalculators];
}


- (NSString *)StartupCalculator
{
    return startupCalculator;
}


- (void)setStartupCalculator:(NSString *)aPath
{
    [startupCalculator release];
    startupCalculator = [aPath copy];

    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    if (aPath && [aPath length] > 0)
    {
        [defaults setObject:aPath
                     forKey:@"StartupCalculator"];
    }
    else
    {
        [defaults removeObjectForKey:@"StartupCalculator"];
    }

    [[NSNotificationCenter defaultCenter]
        postNotificationName:@"StartupCalculatorDidChange"
                      object:self];
}


- (NSDictionary *)startupCalculator
{
    if (!startupCalculator)
        return nil;

    NSArray *allCalcs = [self calculators];
    int count = [allCalcs count];

    for (int i = 0; i < count; ++i)
    {
        NSDictionary *calc =
            [allCalcs objectAtIndex:i];

        if ([[calc objectForKey:@"path"]
                isEqualToString:startupCalculator])
        {
            return calc;
        }
    }

    return nil;
}


- (void)refreshCalculators:(id)aArg
{
    
    NSAutoreleasePool *pool =
        [[NSAutoreleasePool alloc] init];

    NSMutableArray *allCalcs =
        [NSMutableArray array];

    /*
     * Built-in calculators.
     */
    if (standardCalcs)
        [allCalcs addObjectsFromArray:standardCalcs];

    /*
     * Search the user's Documents/emu48 Calculators directory.
     */
    NSArray *systemPaths =
        NSSearchPathForDirectoriesInDomains(
            NSDocumentDirectory,
            NSUserDomainMask,
            YES);

    NSString *calcPath;
    NSFileManager *fm = [NSFileManager defaultManager];

    if (systemPaths && [systemPaths count] > 0)
    {
        calcPath =
            [[systemPaths objectAtIndex:0]
                stringByAppendingPathComponent:CALC_USER_PATH];

        NSString *displayPath =
            [calcPath stringByAbbreviatingWithTildeInPath];

        BOOL isFolder = NO;

        if (![fm fileExistsAtPath:calcPath isDirectory:&isFolder])
        {
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];

            [alert setMessageText:@"Emu48 - Calculator directory not found"];

            [alert setInformativeText:
                [NSString stringWithFormat:
                    @"Create this directory:\n \"%@\"\nand add your KML calculator files.",
                 displayPath]];

            [alert addButtonWithTitle:@"OK"];
            [alert runModal];
        }
        else if (!isFolder)
        {
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];

            [alert setMessageText:@"Calculator directory is not a folder"];
            [alert setInformativeText:
                [NSString stringWithFormat:
                    @"The path \"%@\" exists but is not a directory.",
                    displayPath]];

            [alert addButtonWithTitle:@"OK"];
            [alert runModal];
        }
        else
        {
            NSArray *userCalcs =
                [[self class] calculatorsAtPath:calcPath
                                 relativeToPath:nil];

            if (userCalcs && [userCalcs count] > 0)
            {
                [allCalcs addObjectsFromArray:userCalcs];
            }
            else
            {
                NSAlert *alert = [[[NSAlert alloc] init] autorelease];

                [alert setMessageText:@"No calculators found"];
                [alert setInformativeText:
                    [NSString stringWithFormat:
                        @"No KML calculator files were found in \"%@\".",
                        displayPath]];

                [alert addButtonWithTitle:@"OK"];
                [alert runModal];
            }
        }
    }

    /*
     * Replace the shared calculator list.
     */
    [self setCalculators:allCalcs];

    /*
     * Restore the startup calculator by its path.
     */
    NSString *path =
        [[NSUserDefaults standardUserDefaults]
            objectForKey:@"StartupCalculator"];

    if (path && [path isKindOfClass:[NSString class]])
    {
        [startupCalculator release];
        startupCalculator = [path copy];
    }
    else
    {
        [startupCalculator release];
        startupCalculator = nil;
    }

    [pool release];
}

- (int)StartupMode
{
    return [[NSUserDefaults standardUserDefaults]
        integerForKey:@"StartupMode"];
}


- (void)setStartupMode:(int)aMode
{
    [[NSUserDefaults standardUserDefaults]
        setInteger:aMode
           forKey:@"StartupMode"];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:@"CalcManagerStartupModeChanged"
                      object:self];
}

@end
