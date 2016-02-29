#ifndef QCOCOASPY_H
#define QCOCOASPY_H

#include <AppKit/AppKit.h>

namespace QCocoaSpy
{
    // Installs / swizzles in instance trackers for Cocoa classes.
    void init();

    // Resets instance counters and instance lists
    void reset();
    // Resets, and also limits tracking to the given class names
    void reset(NSString *windowClassName, NSString *viewClassName);

    // Returns the number if live NSWindows created since the last reset().
    // (short-lived windows that have been deallocated are not countet)
    int windowCount();
    // Returns a pointer to the Nth window. The windows are in creation order.
    NSWindow *window(int index);

    // NSView count and access
    int viewCount();
    NSView *view(int index);
}

#endif
