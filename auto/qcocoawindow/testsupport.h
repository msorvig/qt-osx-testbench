#ifndef TESTSUPPORT_H
#define TESTSUPPORT_H

#include <QtGui/QtGui>
#include <AppKit/AppKit.h>

#ifdef HAVE_TRANSFER_NATIVE_VIEW
#include <QtPlatformHeaders/QCocoaWindowFunctions>
#endif
#include <qpa/qplatformnativeinterface.h>

// Public window class that abstracts window types and manages window instances,
// with an API similar to QWindow.
//
// TestWindow is-not-at QWindow, but instead manages a QWindow instance, for the
// benefit of providing proper cleanup on test failures where the test function
// will exit.

// The QWindow instanace is accessbile with TestWindow::qwindow(), but consider
// instead adding API to TestWindow that forwards to te qwindow instance.
//
// The design of this class is driven by the following constraints:
//   - Present one type to the tests, covering all window configurations
//   - Implement using QRasterWindow and QOpenGLWindow from QtGui
//   - Provide a common event counting API and implementation
//
class TestWindowImplBase;
class TestWindow
{
public:
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

    static TestWindow *createWindow(WindowConfiguration configuration = RasterClassic);
    static void deleteOpenWindows();
    static QByteArray windowConfigurationName(WindowConfiguration windowConfiguration);
    static bool isRasterWindow(TestWindow::WindowConfiguration configuration);
    static bool isLayeredWindow(TestWindow::WindowConfiguration configuration);
    
    static void resetWindowCounter();
    static int windowCount();
    
    TestWindow(QPaintDeviceWindow *_d, TestWindowImplBase *_dbase);
    ~TestWindow();
    TestWindow (TestWindow &&) = default;	
    TestWindow(const TestWindow&) = delete; // no copy

    QWindow *qwindow();
    QWindow *takeQWindow();

    enum EventType
    {
        MouseDownEvent,
        MouseUpEvent,
        KeyDownEvent,
        KeyUpEvent,
        ExposeEvent,
        ObscureEvent,
        PaintEvent,
        EventTypesCount
    };

    void resetCounters();
    int eventCount(EventType type);
    // "Take" functions for checking if there are zero, or one
    // (exactly), or many events of a particular event type
    // pending. These have the side effect of decrementing
    // the event counter.
    bool takeOneEvent(EventType type);
    bool takeOneOrManyEvents(EventType type);
    
    void setFillColor(QColor color);
    void setForwardEvents(bool forward);

    // Replicate and forward QWindow API
    void show() { dwin->show(); }
    void hide() { dwin->hide(); }
    void close() { dwin->close(); }
    void setVisible(bool visible) { dwin->setVisible(visible); }
    bool isVisible() const { return dwin->isVisible(); }
    void setFlags(Qt::WindowFlags flags) { dwin->setFlags(flags); }
    Qt::WindowFlags flags() const { return dwin->flags(); }
    void setMask(QRect mask) { dwin->setMask(mask); }
    void raise() { dwin->raise(); }
    void create() { dwin->create(); }
    void setParent(TestWindow *parent) { dwin->setParent(parent->qwindow()); }
    QPlatformWindow *handle() { return dwin->handle(); }
    void setGeometry(int x, int y, int w, int h) { dwin->setGeometry(x, y, w, h); }
    void setGeometry(QRect geometry) { dwin->setGeometry(geometry); }
    QRect geometry() const{ return dwin->geometry(); }
    void setMinimumSize(QSize size) { dwin->setMinimumSize(size); }
    void setMaximumSize(QSize size) { dwin->setMaximumSize(size); }
    void update(QRect rect) { dwin->update(rect); }
    void requestUpdate() { dwin->requestUpdate(); }
    void repaint();

private:
    TestWindowImplBase *d;
    QPaintDeviceWindow *dwin;
};
Q_DECLARE_METATYPE(TestWindow::WindowConfiguration);

class TestWindowImplBase
{
public:
    TestWindowImplBase();
    virtual ~TestWindowImplBase();

    static void resetWindowCounter();
    static int windowCount();

    void resetCounters();
    int eventCount(TestWindow::EventType type);
    bool takeOneEvent(TestWindow::EventType type);
    bool takeOneOrManyEvents(TestWindow::EventType type);

    void keyPressEventHandler(QKeyEvent * ev);
    void keyReleaseEventHandler(QKeyEvent * ev);
    void mousePressEventHandler(QMouseEvent * ev);
    void mouseReleaseEventHandler(QMouseEvent * ev);
    void exposeEventHandler(QExposeEvent *ev);
    void paintEventHandler(QPaintEvent *ev);

    static int instanceCount;
    int eventCounts[TestWindow::EventTypesCount];
    bool forwardEvents;  // Controls whether events are accepted
    QColor fillColor;
};

class TestWindowImplRaster : public QRasterWindow, public TestWindowImplBase
{
public:
    TestWindowImplRaster()
    {
        setGeometry(100, 100, 100, 100);
    }
    
    void keyPressEvent(QKeyEvent * ev) Q_DECL_OVERRIDE { keyPressEventHandler(ev); }
    void keyReleaseEvent(QKeyEvent * ev) Q_DECL_OVERRIDE { keyReleaseEventHandler(ev); }
    void mousePressEvent(QMouseEvent * ev) Q_DECL_OVERRIDE { mousePressEventHandler(ev); }
    void mouseReleaseEvent(QMouseEvent * ev) Q_DECL_OVERRIDE { mouseReleaseEventHandler(ev); }
    void exposeEvent(QExposeEvent *ev) Q_DECL_OVERRIDE { exposeEventHandler(ev); QRasterWindow::exposeEvent(ev); }
    void paintEvent(QPaintEvent *ev) Q_DECL_OVERRIDE
    {
        paintEventHandler(ev);

        // Fill the dirty rects with the current fill color.
        QPainter p(this);
        foreach (QRect rect, ev->region().rects()) {
            p.fillRect(rect, fillColor);
        }
    }
};

class TestWindowImplOpenGL : public QOpenGLWindow, public TestWindowImplBase
{
public:
    TestWindowImplOpenGL()
        :QOpenGLWindow(QOpenGLWindow::NoPartialUpdate), TestWindowImplBase()
    {
        setGeometry(100, 100, 100, 100);
    }

    void keyPressEvent(QKeyEvent * ev) Q_DECL_OVERRIDE { keyPressEventHandler(ev); }
    void keyReleaseEvent(QKeyEvent * ev) Q_DECL_OVERRIDE { keyReleaseEventHandler(ev); }
    void mousePressEvent(QMouseEvent * ev) Q_DECL_OVERRIDE { mousePressEventHandler(ev); }
    void mouseReleaseEvent(QMouseEvent * ev) Q_DECL_OVERRIDE { mouseReleaseEventHandler(ev); }
    void exposeEvent(QExposeEvent *ev) Q_DECL_OVERRIDE { exposeEventHandler(ev); QOpenGLWindow::exposeEvent(ev); }
    void paintGL() Q_DECL_OVERRIDE
    {
        paintEventHandler(0);

        glClearColor(fillColor.redF(), fillColor.greenF(), fillColor.blueF(), fillColor.alphaF());
        glClear(GL_COLOR_BUFFER_BIT);
    }
};

// Macro for iterating over window configurations
#define WINDOW_CONFIGS for (int _view_configuration = 0; _view_configuration < TestWindow::WindowConfigurationCount; ++_view_configuration)
#define RASTER_WINDOW_CONFIGS for (int _view_configuration = 0; _view_configuration <= TestWindow::RasterLayer; ++_view_configuration)
#define WINDOW_CONFIG TestWindow::WindowConfiguration(_view_configuration)

QColor toQColor(NSColor *color);
void wait(int delay = 50);
void stackTrace();

#define WAIT wait();
#define STOP wait(300000);
#define LOOP for (int i = 0; i < iterations; ++i) @autoreleasepool // Don't leak

// Utility functions for accessing native objects.
NSWindow *getNSWindow(QWindow *window);
NSWindow *getNSWindow(TestWindow *window);
NSView *getNSView(QWindow *window);
NSView *getNSView(TestWindow *window);
NSView *getNSView(NSView *view);
NSView *getNSView(NSWindow *window);
NSOpenGLContext *getNSOpenGLContext(QWindow *window);
NSOpenGLContext *getNSOpenGLContext(TestWindow *window);
NSOpenGLPixelFormat *getNSOpenGLPixelFormat(NSOpenGLContext *context);
NSOpenGLPixelFormat *getNSOpenGLPixelFormat(QWindow *window);
NSOpenGLContext *getNSOpenGLContext(TestWindow *window);
void waitForWindowVisible(TestWindow *window);

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
QRect screenGeometry(TestWindow *window);
QPoint toQPoint(NSPoint point);
NSPoint toNSPoint(QPoint point);
QRect toQRect(NSRect rect);
NSRect toNSRect(QRect rect);

// Qt global (window-interior) geometry to NSWindow global exterior geometry
NSRect nswindowFrameGeometry(QRect qtWindowGeometry, NSWindow *window);
// Qt local geometry to NSVIew local geometry
NSRect nsviewFrameGeometry(QRect qtWindowGeometry, NSView *view);

QImage toQImage(CGImageRef image);

// Grabs the contents of the given NSWindow, at 1x resolution.
CGImageRef grabWindow(NSWindow *window);
QImage grabWindow(QWindow *window);
QImage grabWindow(TestWindow *window);

// Grabs the contents of the screen, at 1x resolution.
CGImageRef grabScreen(QRect rect);
CGImageRef grabScreen(NSWindow *window);
QImage grabScreen(QWindow *window);
QImage grabScreen(TestWindow *window);

// Tests if pixels inside a rect are of the given color.
bool verifyImage(const QImage &image, QRect rect, QColor color);
bool verifyImage(const QImage &image, QColor color);

#endif
