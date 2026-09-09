//
//  CalcDocument.m
//  emu48mac
//
//  Created by Da Woon Jung on Wed Feb 18 2004.
//  Copyright (c) 2004 dwj. All rights reserved.
//

#import "CalcDocument.h"
#import "CalcAppController.h"
#import "CalcPrefController.h"
#import "CalcBackend.h"
#import "CalcView.h"
#import "rawlcd.h"

#import <objc/message.h>

static NSString * const kEmu48StateType = @"com.mac.emu48-state";

/*
 * Optional calculator metadata appended to .e48 state files.
 *
 * Older state files simply end before this block.
 */
static const unsigned char kCalcInfoMagic[4] = {
    'C', 'I', 'N', 'F'
};

#define CALC_INFO_VERSION 1

@interface CalcDocument (Private)

- (BOOL)appendCalculatorInfoToStateFile:(NSString *)path
                                  error:(NSError **)outError;

- (void)readCalculatorInfoFromStateFile:(NSString *)path;

@end

@implementation CalcDocument

- (BOOL)appendCalculatorInfoToStateFile:(NSString *)path
                                  error:(NSError **)outError
{
    if (!calculatorInfo)
        return YES;

    /*
     * Only archive the calculator metadata.  The dictionary may contain
     * NSValue objects, so use NSKeyedArchiver rather than a property list.
     */
    NSData *infoData =
        [NSKeyedArchiver archivedDataWithRootObject:calculatorInfo];

    if (!infoData)
        return YES;

    NSFileHandle *file =
        [NSFileHandle fileHandleForWritingAtPath:path];

    if (!file)
    {
        if (outError)
        {
            *outError =
                [NSError errorWithDomain:NSCocoaErrorDomain
                                    code:NSFileWriteUnknownError
                                userInfo:nil];
        }
        return NO;
    }

    [file seekToEndOfFile];

    uint32_t version = CALC_INFO_VERSION;
    uint32_t length = (uint32_t)[infoData length];

    [file writeData:
        [NSData dataWithBytes:kCalcInfoMagic
                       length:sizeof(kCalcInfoMagic)]];

    [file writeData:
        [NSData dataWithBytes:&version
                       length:sizeof(version)]];

    [file writeData:
        [NSData dataWithBytes:&length
                       length:sizeof(length)]];

    [file writeData:infoData];

    [file closeFile];

    return YES;
}


- (void)readCalculatorInfoFromStateFile:(NSString *)path
{
    [calculatorInfo release];
    calculatorInfo = nil;

    NSFileHandle *file =
        [NSFileHandle fileHandleForReadingAtPath:path];

    if (!file)
        return;

    [file seekToEndOfFile];

    unsigned long long fileSize = [file offsetInFile];

    const unsigned long long headerSize =
        sizeof(kCalcInfoMagic) +
        sizeof(uint32_t) +
        sizeof(uint32_t);

    if (fileSize < headerSize)
    {
        [file closeFile];
        return;
    }

    /*
     * We don't know the metadata length yet, so locate the magic by
     * scanning backwards through the final portion of the file.
     *
     * The metadata is small, so reading the last 64 KB is sufficient.
     */
    unsigned long long scanSize =
        (fileSize < 65536) ? fileSize : 65536;
    
    [file seekToFileOffset:fileSize - scanSize];

    NSData *tail =
        [file readDataOfLength:(NSUInteger)scanSize];

    const unsigned char *bytes = [tail bytes];
    NSUInteger count = [tail length];

    NSUInteger magicOffset = NSNotFound;

    if (count >= sizeof(kCalcInfoMagic))
    {
        for (NSUInteger i = count - sizeof(kCalcInfoMagic) + 1;
             i > 0;
             --i)
        {
            NSUInteger offset = i - 1;

            if (memcmp(bytes + offset,
                       kCalcInfoMagic,
                       sizeof(kCalcInfoMagic)) == 0)
            {
                magicOffset = offset;
                break;
            }
        }
    }

    if (magicOffset == NSNotFound ||
        magicOffset + headerSize > count)
    {
        [file closeFile];
        return;
    }

    const unsigned char *header =
        bytes + magicOffset;

    uint32_t version = 0;
    uint32_t length = 0;

    memcpy(&version,
           header + sizeof(kCalcInfoMagic),
           sizeof(version));

    memcpy(&length,
           header + sizeof(kCalcInfoMagic) + sizeof(version),
           sizeof(length));

    if (version != CALC_INFO_VERSION ||
        length == 0)
    {
        [file closeFile];
        return;
    }
    
    unsigned long long dataOffset =
        fileSize - scanSize + magicOffset + headerSize;

    if (dataOffset + length > fileSize)
    {
        [file closeFile];
        return;
    }

    [file seekToFileOffset:dataOffset];

    NSData *infoData =
        [file readDataOfLength:length];

    [file closeFile];

    if ([infoData length] != length)
        return;

    id info =
        [NSKeyedUnarchiver unarchiveObjectWithData:infoData];

    if (![info isKindOfClass:[NSDictionary class]])
    {
        return;
    }

    [self setCalculatorInfo:(NSDictionary *)info];
}

- (IBAction)backupCalc:(id)sender
{
    [[CalcBackend sharedBackend] backup];
}

- (IBAction)changeKmlDummy:(id)sender
{
}

- (IBAction)openObject:(id)sender
{
    int result;
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setResolvesAliases: YES];
    [panel setAllowsMultipleSelection: NO];
    result = [panel runModalForTypes: nil];
    if (result == NSOKButton)
    {
        NSError *err = nil;
        if (![[CalcBackend sharedBackend] readFromObject:[panel filename] error:&err] && err)
            [self presentError: err];
    }
}

- (IBAction)restoreCalc:(id)sender
{
    [[CalcBackend sharedBackend] restore];
}

- (IBAction)saveObject:(id)sender
{
    int result;
    NSArray *types = [[NSDocumentController sharedDocumentController] fileExtensionsFromType: @"HP Stack Object"];
    if (types && 0==[types count]) types = nil;
    NSSavePanel *panel = [NSSavePanel savePanel];
    [panel setAllowedFileTypes: types];
    [panel setCanSelectHiddenExtension: YES];
    result = [panel runModal];
    if (result == NSOKButton)
    {
        NSError *err = nil;
        if (![[CalcBackend sharedBackend] saveObjectAs:[panel filename] error:&err] && err)
            [self presentError: err];
    }
}

- (void)setCalculatorInfo:(NSDictionary *)info
{
//    NSLog(@"CalcDocument setCalculatorInfo: self=%@ info=%@", self, info);

    [calculatorInfo release];
    calculatorInfo = [info retain];

    if (calcView)
        [calcView setCalcInfo:calculatorInfo];

    NSString *displayModel =
        [info objectForKey:@"displayModel"];

    if (displayModel && [displayModel length] > 0)
    {
        NSString *title =
            [NSString stringWithFormat:@"%@ — Untitled",
                                       displayModel];

        NSWindowController *controller =
            [[self windowControllers] firstObject];

        if (controller && [controller window])
            [[controller window] setTitle:title];
    }
}


- (id)init
{
    self = [super init];

    if (self)
    {
        [self setHasUndoManager:NO];
    }

    return self;
}

- (void)dealloc
{
    CalcBackend *backend = [CalcBackend sharedBackend];
    [backend stop];
    [calculatorInfo release];
    [super dealloc];
}


- (NSString *)windowNibName
{
    return @"CalcWindow";
}


- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)aType error:(NSError **)outError
{
    BOOL result = NO;
    if ([aType isEqualToString: kEmu48StateType])
    {
        [[NSFileManager defaultManager] changeCurrentDirectoryPath: [[NSBundle mainBundle] bundlePath]];
        result = [[CalcBackend sharedBackend] readFromState:[absoluteURL path] error:outError];
        
        if (result)
        {
            [self readCalculatorInfoFromStateFile:[absoluteURL path]];
            [[NSApp delegate] populateChangeKmlMenu];
        }
        else
        {
//            if (outError)
//                *outError = [NSError errorWithDomain:[[NSBundle mainBundle] bundleIdentifier] code:-1 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"State file could not be read because the associated calculator template file contains errors.",@""), NSLocalizedDescriptionKey, NSLocalizedString(@"The chosen calculator template file contains errors.",@""), NSLocalizedFailureReasonErrorKey, nil]];
        }
        return result;
    }
    else if ([aType isEqualToString: @"com.mac.emu48-kml"])
    {
        result = [[CalcBackend sharedBackend] makeUntitledCalcWithKml: [absoluteURL path] error:outError];
        if (result)
        {
            CalcAppController *appDelegate =
                (CalcAppController *)[NSApp delegate];

            [appDelegate populateChangeKmlMenu];
        }
        else
        {
//            if (outError)
//                *outError = [NSError errorWithDomain:[[NSBundle mainBundle] bundleIdentifier] code:-1 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Calculator template file could not be read because it contained error(s).",@""), NSLocalizedDescriptionKey, NSLocalizedString(@"The chosen calculator template file contains errors.",@""), NSLocalizedFailureReasonErrorKey, nil]];
        }
        return result;
    }

    // Default action for other types
    return [super readFromURL:absoluteURL ofType:aType error:outError];
}

- (NSData *)dataOfType:(NSString *)aTypeName
                 error:(NSError **)outError
{
    if (![aTypeName isEqualToString:kEmu48StateType])
    {
        if (outError)
        {
            *outError = [NSError errorWithDomain:NSCocoaErrorDomain
                                            code:NSFileWriteUnknownError
                                        userInfo:nil];
        }
        return nil;
    }

    NSString *tempPath =
        [NSTemporaryDirectory()
            stringByAppendingPathComponent:@"emu48-save-state.tmp"];
    
    BOOL result =
        [[CalcBackend sharedBackend] saveStateAs:tempPath
                                           error:outError];
    
    if (!result)
        return nil;
    
    result =
        [self appendCalculatorInfoToStateFile:tempPath
                                        error:outError];

    if (!result)
    {
        [[NSFileManager defaultManager]
            removeItemAtPath:tempPath
                      error:NULL];

        return nil;
    }

    NSData *data =
        [NSData dataWithContentsOfFile:tempPath
                               options:NSDataReadingUncached
                                 error:outError];

    [[NSFileManager defaultManager] removeItemAtPath:tempPath
                                                error:NULL];

    return data;
}


- (BOOL)writeToURL:(NSURL *)absoluteURL
           ofType:(NSString *)aType
            error:(NSError **)outError
{
    if ([aType isEqualToString:kEmu48StateType])
    {
        [[NSFileManager defaultManager]
            changeCurrentDirectoryPath:[[NSBundle mainBundle] bundlePath]];
        
        BOOL result =
            [[CalcBackend sharedBackend]
                saveStateAs:[absoluteURL path]
                       error:outError];

        if (result)
        {
            result =
                [self appendCalculatorInfoToStateFile:[absoluteURL path]
                                                 error:outError];
        }

        return result;
    }

    return [super writeToURL:absoluteURL
                      ofType:aType
                       error:outError];
}

+ (NSURL *)defaultFileURL
{
    NSArray *systemPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    if (systemPaths && [systemPaths count] > 0)
    {
        NSString *statePath = [[[systemPaths objectAtIndex: 0] stringByAppendingPathComponent: CALC_USER_PATH] stringByAppendingPathComponent: CALC_STATE_PATH];
        NSFileManager *fm = [NSFileManager defaultManager];
        BOOL isFolder = NO;
        if (![fm fileExistsAtPath:statePath isDirectory:&isFolder])
        {
            NSArray *pathComponents = [statePath pathComponents];
            NSString *parentPath = @"";
            NSString *pathComp;
            NSEnumerator *pathEnum = [pathComponents objectEnumerator];
            while ((pathComp = [pathEnum nextObject]))
            {
                parentPath = [parentPath stringByAppendingPathComponent: pathComp];
                if (![fm fileExistsAtPath:parentPath isDirectory:&isFolder])
                    [fm createDirectoryAtPath:parentPath attributes:nil];
            }
        }
        else if (!isFolder)
        {
            return nil;
        }
        statePath = [statePath stringByAppendingPathComponent: CALC_DEFAULT_STATE];
        return [NSURL fileURLWithPath: statePath];
    }
    return nil;
}


void (*shouldCloseDispatcher)(id, SEL, NSDocument *, BOOL, void *) =
    (void (*)(id, SEL, NSDocument *, BOOL, void *))objc_msgSend;

// Support saving to a fixed file on exit
- (void)canCloseDocumentWithDelegate:(id)delegate
                 shouldCloseSelector:(SEL)shouldCloseSelector
                         contextInfo:(void *)contextInfo
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey: @"AutoSaveOnExit"])
    {
        BOOL shouldClose = YES;
        NSError *err = nil;
        NSURL *saveURL = [self fileURL];
        if (nil == saveURL)
        {
            saveURL = [[self class] defaultFileURL];
        }
        if (nil == saveURL)
        {
            err = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteNoPermissionError userInfo:nil];
            shouldClose = NO;
        }
        else
        {
            shouldClose = [self saveToURL:saveURL ofType:@"Emu48 State" forSaveOperation:NSSaveOperation error:&err];
        }

        if (!shouldClose)
            [self presentError: err];

        if (delegate)
//            objc_msgSend(delegate, shouldCloseSelector, self, shouldClose, contextInfo);
            shouldCloseDispatcher(
                delegate,
                shouldCloseSelector,
                self,
                shouldClose,
                contextInfo
            );
    }
    else
    {
        [super canCloseDocumentWithDelegate:delegate shouldCloseSelector:shouldCloseSelector contextInfo:contextInfo];
    }
}
// v1.68 changes
- (void)windowControllerDidLoadNib:(NSWindowController *)controller
{
    [super windowControllerDidLoadNib:controller];

    CalcBackend *backend = [CalcBackend sharedBackend];

    [backend setDocument:self];

    [backend setCalcView:calcView];
    [backend finishInitWithViewContainer:[controller window]
                                lcdClass:[CalcRawLCD class]];

    if ([backend initDone])
    {
        if (calculatorInfo)
            [calcView setCalcInfo:calculatorInfo];
        
        [backend performSelector:@selector(run)
                      withObject:nil
                      afterDelay:0.0];
    }
}
+ (BOOL)autosavesInPlace
{
    return NO;
}
@end


@implementation CalcDocumentController

// Overriding newDocument: to implement new document from stationery
- (IBAction)newDocument:(id)sender
{
    NSLog(@"newDocument");
    NSString *path = nil;
    NSError *err = nil;
    if ([sender respondsToSelector: @selector(representedObject)])
    {
        path = [sender representedObject];
    }
    if (path)
    {
        id doc = [self openDocumentWithContentsOfURL:[NSURL fileURLWithPath: path] display:YES error:&err];
        if (nil == doc && err)
        {
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            [userInfo setObject:[[NSString stringWithFormat: NSLocalizedString(@"The document “%@” could not be opened.",@""), [path lastPathComponent]] stringByAppendingFormat: @" %@", [err localizedFailureReason]] forKey:NSLocalizedDescriptionKey];

            [userInfo setObject:[err localizedFailureReason]
                         forKey:NSLocalizedFailureReasonErrorKey];

            NSError *untitledDocError = [NSError errorWithDomain:[err domain] code:[err code] userInfo:userInfo];
            [self presentError: untitledDocError];
        }
    }
}

- (id)openDocumentWithContentsOfURL:(NSURL *)absoluteURL display:(BOOL)displayDocument error:(NSError **)aOutError
{
    NSError *outError = nil;
    id doc = [super openDocumentWithContentsOfURL:absoluteURL display:displayDocument error:&outError];
    if (aOutError)
        *aOutError = outError;

    if (doc)
    {
        NSString *type = [doc fileType];
        if ([type isEqualToString: @"com.mac.emu48-kml"])
        {
            [doc setFileURL: nil];
            [doc setFileModificationDate: nil];
        }
    }

    return doc;
}

- (void)noteNewRecentDocument:(NSDocument *)aDocument
{
    NSString *type = [aDocument fileType];
    if ([type isEqualToString: kEmu48StateType])
    {
        [super noteNewRecentDocument: aDocument];
    }
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem
{
    // TODO: Don't use hack for dimming recent items
    if ([anItem action] == @selector(newDocument:)  ||
        [anItem action] == @selector(openDocument:) ||
        [anItem action] == @selector(_openRecentDocument:))
    {
        return ([[self documents] count] < 1);
    }
    return [super validateUserInterfaceItem: anItem];
}

@end
