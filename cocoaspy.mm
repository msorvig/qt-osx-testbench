#import <AppKit/AppKit.h>
#import <objc/runtime.h>

#include <QtCore>

#include "cocoaspy.h"

// Lists of currently live windows and views. These are maintained
// on native instance initialization and deallocation, by swzzling
// in list maintaining functions on the native classes.
Q_GLOBAL_STATIC(QList<NSWindow *>, nativeWindows);
Q_GLOBAL_STATIC(QList<NSView *>, nativeViews);
NSString *g_windowClassName = 0;
NSString *g_viewClassName = 0;

// Monitor NSWidow init.
@implementation NSWindow (QCocoaSpy)
- (instancetype)initWithContentRectSpy:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
{
    if (!g_windowClassName || [NSStringFromClass([self class]) isEqualToString:g_windowClassName])
        nativeWindows()->append(self);

    return [self initWithContentRectSpy:contentRect styleMask:aStyle backing:bufferingType defer:flag];
}

- (instancetype)initWithContentRectSpy:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag screen:(NSScreen *)screen
{
    if (!g_windowClassName || [NSStringFromClass([self class]) isEqualToString:g_windowClassName])
        nativeWindows()->append(self);

    return [self initWithContentRectSpy:contentRect styleMask:aStyle backing:bufferingType defer:flag screen:screen];
}

+ (void)swizzleWindowInit
{
    {
        Method original = class_getInstanceMethod(self, @selector(initWithContentRect:styleMask:backing:defer:));
        Method swizzle  = class_getInstanceMethod(self, @selector(initWithContentRectSpy:styleMask:backing:defer:));
        method_exchangeImplementations(original, swizzle);
    }
    {
        Method original = class_getInstanceMethod(self, @selector(initWithContentRect:styleMask:backing:defer:screen:));
        Method swizzle  = class_getInstanceMethod(self, @selector(initWithContentRectSpy:styleMask:backing:defer:screen:));
        method_exchangeImplementations(original, swizzle);
    }

    // Better:

    //__block IMP originalInitWithFrame = class_swizzleSelectorWithBlock(self, @selector(initWithFrame:), ^(UILabel *self, CGRect frame) {
    //if ((self = ((id (*)(id, SEL, CGRect))originalInitWithFrame)(self, @selector(initWithFrame:), frame))) {
    //    // ...
    // }
    //  return self;
    //});

}
@end

// Monitor NSView init.
@implementation NSView (QCocoaSpy)
- (instancetype)initWithFrameSpy:(NSRect)frameRect
{
    if (!g_viewClassName || [NSStringFromClass([self class]) isEqualToString:g_viewClassName])
        nativeViews()->append(self);

    return [self initWithFrameSpy:frameRect];
}

- (instancetype)initWithCoderSpy:(NSCoder *)coder
{
    if (!g_viewClassName || [NSStringFromClass([self class]) isEqualToString:g_viewClassName])
        nativeViews()->append(self);

    return [self initWithCoderSpy:coder];
}

+ (void)swizzleViewInit
{
    {
        Method original = class_getInstanceMethod(self, @selector(initWithFrame:));
        Method swizzle  = class_getInstanceMethod(self, @selector(initWithFrameSpy:));

        method_exchangeImplementations(original, swizzle);
    }
    {
        Method original = class_getInstanceMethod(self, @selector(initWithCoder:));
        Method swizzle  = class_getInstanceMethod(self, @selector(initWithCoderSpy:));
        method_exchangeImplementations(original, swizzle);
    }
}
@end

// Monitor NSObject dealloc to remove deleted objects fromt the instance lists
@implementation NSObject (QCocoaSpy)
- (void) deallocSpy
{
    nativeWindows()->removeAll(self);
    nativeViews()->removeAll(self);
    [self deallocSpy];
}

+ (void)swizzleObjectDealloc
{
    Method original = class_getInstanceMethod(self, @selector(dealloc));
    Method swizzle  = class_getInstanceMethod(self, @selector(deallocSpy));
    method_exchangeImplementations(original, swizzle);
}
@end

namespace QCocoaSpy
{

    void init() {
        // Install native instance monitors
        [NSWindow swizzleWindowInit];
        [NSView swizzleViewInit];
        [NSObject swizzleObjectDealloc];
    }

    void reset()
    {
        nativeWindows()->clear();
        nativeViews()->clear();
        g_windowClassName = 0;
        g_viewClassName = 0;
    }

    void reset(NSString *windowClassName, NSString *viewClassName)
    {
        reset();
        g_windowClassName = windowClassName;
        g_viewClassName = viewClassName;
    }

    int windowCount()
    {
        return nativeWindows->count();
    }

    NSWindow *window(int index)
    {
        return nativeWindows()->at(index);
    }

    int viewCount()
    {
        return nativeViews->count();
    }

    NSView *view(int index)
    {
        return nativeViews()->at(index);
    }

}
