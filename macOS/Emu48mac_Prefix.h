#ifdef __OBJC__
    #import <Cocoa/Cocoa.h>
    typedef NSRect  CalcRect;
    typedef NSSize  CalcSize;
    typedef NSPoint CalcPoint;
    #define CalcZeroRect NSZeroRect;
    #define CalcMakeRect(x,y,w,h) NSMakeRect(x,y,w,h)
    #define CalcMakePoint(x,y) NSMakePoint(x,y)
    typedef NSImage  CalcImage;
    typedef NSWindow CalcViewContainer;
    typedef NSPasteboard CalcPasteboard;
#endif

#import "TargetConditionals.h"
