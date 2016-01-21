#ifndef QCOCOASPY_H
#define QCOCOASPY_H

namespace QCocoaSpy
{
    // Installs / swizzles in instance trackers for Cocoa classes.
    void init();

    // Resets instance counters and instance lists
    void reset();

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
