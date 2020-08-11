#include <QtGui>
#include <QtWidgets/QtWidgets>

#include <AppKit/AppKit.h>

int main(int argc, char **argv)
{
    QApplication app(argc, argv);

    NSRect frame = NSMakeRect(0, 0, 200, 200);
    NSWindow* window  = [[[NSWindow alloc] initWithContentRect:frame
                        styleMask:NSWindowStyleMaskBorderless
                        backing:NSBackingStoreBuffered
                        defer:NO] autorelease];
    [window makeKeyAndOrderFront:NSApp];
    NSSize backingSize = [window.contentView convertSizeToBacking:NSMakeSize(1.0, 1.0)];

    qDebug() << "view backingSize" << backingSize.width << backingSize.height;
    qDebug() << "sceen backingScaleFactor" << [[NSScreen mainScreen] backingScaleFactor];
}
