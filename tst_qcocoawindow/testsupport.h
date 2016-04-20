#ifndef TESTSUPPORT_H
#define TESTSUPPORT_H

#include <QtGui/QtGui>
#include <AppKit/AppKit.h>

#ifdef HAVE_TRANSFER_NATIVE_VIEW
#include <QtPlatformHeaders/QCocoaWindowFunctions>
#endif
#include <qpa/qplatformnativeinterface.h>

namespace TestWindowSpy {
    
    // Test window configurations. In reallity there are two independent
    // config variables but we are making a linear list.
    enum WindowConfiguration
    {
        RasterClassic,
        RasterLayer,
        OpenGLClassic,
        OpenGLLayer,
        WindowConfigurationCount
    };

    QByteArray windowConfigurationName(WindowConfiguration windowConfiguration);
}
Q_DECLARE_METATYPE(TestWindowSpy::WindowConfiguration);

// Macro for iterating over window configurations
#define WINDOW_CONFIGS for (int _view_configuration = 0; _view_configuration < TestWindowSpy::WindowConfigurationCount; ++_view_configuration)
#define RASTER_WINDOW_CONFIGS for (int _view_configuration = 0; _view_configuration <= TestWindowSpy::RasterLayer; ++_view_configuration)
#define WINDOW_CONFIG TestWindowSpy::WindowConfiguration(_view_configuration)

QColor toQColor(NSColor *color);
void wait();
void stackTrace();

#define WAIT wait();
#define LOOP for (int i = 0; i < iterations; ++i) @autoreleasepool // Don't leak


// Utility functions for accessing native objects.
NSWindow *getNSWindow(QWindow *window);
NSView *getNSView(QWindow *window);
NSView *getNSView(NSView *view);
NSView *getNSView(NSWindow *window);
NSOpenGLContext *getNSOpenGLContext(QWindow *window);
NSOpenGLPixelFormat *getNSOpenGLPixelFormat(NSOpenGLContext *context);
NSOpenGLPixelFormat *getNSOpenGLPixelFormat(QWindow *window);
void waitForWindowVisible(QWindow *window);


#ifndef HAVE_TRANSFER_NATIVE_VIEW
// Placeholder for actual transferNativeView() implementation. Usage will cause test failures.
class QCocoaWindowFunctions
{
public:
    static NSView *transferNativeView(QWindow *)
    {
        return 0;
    }
};
#endif

//
// Coordinate systems:
//
// Qt, CoreGraphics and this test works in the same coordinate system where the
// origin is at the top left corner of the main screen with the y axis pointing
// downwards. Cocoa has the origin at the bottom left corner with the y axis pointing
// upwards. There are geometry accessor functions:
//
//   QRect screenGeometry(NSView)
//   QRect screenGeometry(NSWindow)
//   QRect screenGeometry(QWindow)
//
// In addition there are type convertors (which do not change the origin)
//     toQPoint
//     toQRect
//

QRect screenGeometry(NSView *view);
QRect screenGeometry(NSWindow *window);
QRect screenGeometry(QWindow *window);
QPoint toQPoint(NSPoint point);
NSPoint toNSPoint(QPoint point);
QRect toQRect(NSRect rect);
NSRect toNSRect(QRect rect);

// Qt global (window-interior) geometry to NSWindow global exterior geometry
NSRect nswindowFrameGeometry(QRect qtWindowGeometry, NSWindow *window);
// Qt local geometry to NSVIew local geometry
NSRect nsviewFrameGeometry(QRect qtWindowGeometry, NSView *view);

QImage toQImage(CGImageRef image);

// Grabs the contents of the given NSWindow, at standard (1x) resolution.
CGImageRef grabWindow(NSWindow *window);

// Grabs the contents of the given QWindow, at standard (1x) resolution.
QImage grabWindow(QWindow *window);

// Tests if pixels inside a rect are of the given color.
bool verifyImage(const QImage &image, QRect rect, QColor color);


#endif
