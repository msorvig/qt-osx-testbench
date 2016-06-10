#include "testsupport.h"

#include <QtTest/QTest>
#include <QtGui/QtGui>

TestWindow *TestWindow::createWindow(TestWindow::WindowConfiguration configuration)
{
    QPaintDeviceWindow *window = 0;
    TestWindowImplBase *baseWindow = 0;
 
    // Select Raster/OpenGL
    if (isRasterWindow(configuration)) {
        TestWindowImplRaster *w = new TestWindowImplRaster();
        window = w;
        baseWindow = w;
    } else {
        TestWindowImplOpenGL *w = new TestWindowImplOpenGL();
        window = w;
        baseWindow = w;
    }

    // Select Layer-backed/Classic
    if (isLayeredWindow(configuration))
        window->setProperty("_q_mac_wantsLayer", QVariant(true));
    
    return new TestWindow(window, baseWindow);
}

QByteArray TestWindow::windowConfigurationName(WindowConfiguration configuration)
{
    switch (configuration) {
        case TestWindow::RasterClassic: return QByteArray("raster_classic");
        case TestWindow::RasterLayer: return QByteArray("raster_layer");
        case TestWindow::OpenGLClassic: return QByteArray("opengl_classic");
        case TestWindow::OpenGLLayer: return QByteArray("opengl_layer");
        case TestWindow::WindowConfigurationCount: break;
    };
    return QByteArray("unknown_window_config");
}

bool TestWindow::isRasterWindow(TestWindow::WindowConfiguration configuration)
{
    return configuration == TestWindow::RasterClassic
        || configuration == TestWindow::RasterLayer;
}

bool TestWindow::isLayeredWindow(TestWindow::WindowConfiguration configuration)
{
    return configuration == TestWindow::RasterLayer
        || configuration == TestWindow::OpenGLLayer;
}

void TestWindow::resetWindowCounter()
{
    TestWindowImplBase::resetWindowCounter();
}

int TestWindow::windowCount()
{
    return TestWindowImplBase::windowCount();
}

TestWindow::TestWindow(QPaintDeviceWindow *_dwin, TestWindowImplBase *_dbase)
    :d(_dbase)
    ,dwin(_dwin)
{
    resetCounters();
}

TestWindow::~TestWindow()
{
    delete d;
}

QWindow *TestWindow::qwindow()
{
    return dwin;
}

QWindow *TestWindow::takeQWindow()
{
    QWindow *ans = dwin;
    dwin = 0;
    d = 0;
    return ans;
}

void TestWindow::resetCounters()
{
    d->resetCounters();
}

bool TestWindow::takeOneEvent(EventType type)
{
    return d->takeOneEvent(type);
}

bool TestWindow::takeOneOrManyEvents(EventType type)
{
    return d->takeOneOrManyEvents(type);
}

void TestWindow::setFillColor(QColor color)
{
    d->fillColor = color; 
}

void TestWindow::setForwardEvents(bool forward)
{
    d->forwardEvents = forward;
}

void TestWindow::repaint()
{
#ifdef HAVE_QPAINTDEVICEWINDOW_REPAINT
    dwin->repaint();
#else
    qWarning("No QPaintDeviceWindow::repaint(), expect test failures");
#endif
}

TestWindowImplBase::TestWindowImplBase()
{
    forwardEvents = false;
    fillColor = QColor(Qt::green);
    ++instanceCount;
}

TestWindowImplBase::~TestWindowImplBase()
{
    --instanceCount;
}

int TestWindowImplBase::instanceCount = 0;

void TestWindowImplBase::resetWindowCounter()
{
    instanceCount  = 0;
}

int TestWindowImplBase::windowCount()
{
    return instanceCount;
}

void TestWindowImplBase::resetCounters()
{
    for (int i = 0; i < TestWindow::EventTypesCount; ++i)
        eventCounts[i] = 0;
}

bool TestWindowImplBase::takeOneEvent(TestWindow::EventType type)
{
    if (eventCounts[type] != 1)
        return false;
    --eventCounts[type];
    return true;
}

bool TestWindowImplBase::takeOneOrManyEvents(TestWindow::EventType type)
{
    if (eventCounts[type] < 1)
        return false;
    eventCounts[type] = 0;
    return true;
}

void TestWindowImplBase::keyPressEventHandler(QKeyEvent * ev)
{
    ev->setAccepted(!forwardEvents);
    eventCounts[TestWindow::KeyDownEvent] += forwardEvents ? 0 : 1;
}

void TestWindowImplBase::keyReleaseEventHandler(QKeyEvent * ev)
{
    ev->setAccepted(!forwardEvents);
    eventCounts[TestWindow::KeyUpEvent] += forwardEvents ? 0 : 1;
}

void TestWindowImplBase::mousePressEventHandler(QMouseEvent * ev)
{
    ev->setAccepted(!forwardEvents);
    eventCounts[TestWindow::MouseDownEvent] += forwardEvents ? 0 : 1;
}

void TestWindowImplBase::mouseReleaseEventHandler(QMouseEvent * ev)
{
    ev->setAccepted(!forwardEvents);
    eventCounts[TestWindow::MouseUpEvent] += forwardEvents ? 0 : 1;
}

void TestWindowImplBase::exposeEventHandler(QExposeEvent *ev)
{
    if (ev->region().isEmpty())
        ++eventCounts[TestWindow::ObscureEvent];
    else
        ++eventCounts[TestWindow::ExposeEvent];
}

void TestWindowImplBase::paintEventHandler(QPaintEvent *)
{
    ++eventCounts[TestWindow::PaintEvent];
}

QColor toQColor(NSColor *color) {
    CGFloat r,g,b,a;
    [color getRed:&r green:&g blue:&b alpha:&a];
    return QColor(r * 255, g * 255, b * 255, a * 255);
}

void wait()
{
    int delay = 25;
    QTest::qWait(delay);
}

// from qtestcase.cpp
void stackTrace()
{
    Q_UNUSED(stackTrace);
    fprintf(stderr, "\n========= Received signal, dumping stack ==============\n");
    char cmd[512];
    qsnprintf(cmd, 512, "lldb -p %d 2>/dev/null <<EOF\n"
                         "bt all\n"
                         "quit\n"
                         "EOF\n",
                         (int)getpid());
    if (system(cmd) == -1)
        fprintf(stderr, "calling lldb failed\n");
    fprintf(stderr, "========= End of stack trace ==============\n");
}

NSWindow *getNSWindow(QWindow *window)
{
    void *nswindow = QGuiApplication::platformNativeInterface()->
                     nativeResourceForWindow(QByteArrayLiteral("nswindow"), window);
    return static_cast<NSWindow*>(nswindow);
}

NSWindow *getNSWindow(TestWindow *window)
{
    return getNSWindow(window->qwindow());
}

NSView *getNSView(QWindow *window)
{
    void *nsview = QGuiApplication::platformNativeInterface()->
                     nativeResourceForWindow(QByteArrayLiteral("nsview"), window);
    return static_cast<NSView*>(nsview);
}

NSView *getNSView(TestWindow *window)
{
    return getNSView(window->qwindow());
}

NSView *getNSView(NSView *view)
{
    return view;
}

NSView *getNSView(NSWindow *window)
{
    return window.contentView;
}

NSOpenGLContext *getNSOpenGLContext(QWindow *window)
{
    void *context = QGuiApplication::platformNativeInterface()->
                     nativeResourceForWindow(QByteArrayLiteral("nsopenglcontext"), window);
    return static_cast<NSOpenGLContext*>(context);
}

NSOpenGLContext *getNSOpenGLContext(TestWindow *window)
{
    return getNSOpenGLContext(window->qwindow());
}    

NSOpenGLPixelFormat *getNSOpenGLPixelFormat(NSOpenGLContext *context)
{
    CGLContextObj cglContext = [context CGLContextObj];
    CGLPixelFormatObj cglPixelFormat = CGLGetPixelFormat(cglContext);
    return [[[NSOpenGLPixelFormat alloc] initWithCGLPixelFormatObj:cglPixelFormat] autorelease];
}

NSOpenGLPixelFormat *getNSOpenGLPixelFormat(QWindow *window)
{
    return getNSOpenGLPixelFormat(getNSOpenGLContext(window));
}

NSOpenGLPixelFormat *getNSOpenGLPixelFormat(TestWindow *window)
{
    return getNSOpenGLPixelFormat(window->qwindow());
}

void waitForWindowVisible(TestWindow *window)
{
    // use qWaitForWindowExposed for now.
    QTest::qWaitForWindowExposed(window->qwindow());
    WAIT
}

#if 0

bool waitForWindowGeometryUpdate(QWindow *window)
{
    return waitForWindowGeometryUpdate(getNSView(window));
}

bool waitForWindowGeometryUpdate(NSWindow *window)
{

}


bool waitForWindowGeometryUpdate(NSView *view)
{
    bool done = false;


}

class GeometryWaiter
{
public:
    template <typename T>
    GeometryWaiter(const T &object)
    {
        m_view = getNSView(object);

        wasPostFrameChangeNotifications = view.postsFrameChangedNotifications;
        view.postsFrameChangedNotifications = YES; // scary modification of NSView property
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        id observer = [center
            addObserverForNotificationName:NSViewFrameDidChangeNotification
                                    object:view
                                    queue:[NSOperationQueue mainQueue]
                                    block:^(NSNotification *notification) {
                                        qDebug() << "NSViewFrameDidChangeNotification"
                                            done = true;
                                    }];
        done = false; // not interested in notifications prior to this.
    };

    bool wait() {
        // wait for notification.
        // AND/OR should we just poll NSView.frame here
        while (!done) {
            QTest::qWait(5); // spin event loop
        }
        // TODO time out
    }

    ~GeometryWaiter()
    {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center removeObserver:observer];
        view.postsFrameChangedNotifications = wasPostFrameChangeNotifications;
    }
private:
    NSView *m_view;
    bool wasPostFrameChangeNotifications:
    bool done;
    id observer;
};

#define GEOMETRY_WAIT(OBJECT, CODE) \
{ \
    GeometryWaiter waiter(OBJECT) \
    CODE \
    waiter.wait(); {} \
}

#define VISIBILITY_WAIT(OBJECT, CODE) \
{ \
    VisibilityWaiter waiter(OBJECT) \
    CODE \
    waiter.wait(); {} \
}

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
int qt_mac_mainScreenHeight()
{
    QMacAutoReleasePool pool;
    // The first screen in the screens array is documented
    // to have the (0,0) origin.
    NSRect screenFrame = [[[NSScreen screens] firstObject] frame];
    return screenFrame.size.height;
}

int qt_mac_flipYCoordinate(int y)
{
    return qt_mac_mainScreenHeight() - y;
}

qreal qt_mac_flipYCoordinate(qreal y)
{
    return qt_mac_mainScreenHeight() - y;
}

NSPoint qt_mac_flipPoint(NSPoint point)
{
    return NSMakePoint(point.x, qt_mac_flipYCoordinate(point.y));
}

NSRect qt_mac_flipRect(NSRect rect)
{
    int flippedY = qt_mac_flipYCoordinate(rect.origin.y + rect.size.height);
    return NSMakeRect(rect.origin.x, flippedY, rect.size.width, rect.size.height);
}

QPoint toQPoint(NSPoint point)
{
    return QPoint(point.x, point.y);
}

NSPoint toNSPoint(QPoint point)
{
    return NSMakePoint(point.x(), point.y());
}

QRect toQRect(NSRect rect)
{
    return QRect(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
}

NSRect toNSRect(QRect rect)
{
    return NSMakeRect(rect.x(), rect.y(), rect.width(), rect.height());
}

QRect screenGeometry(NSView *view)
{
    NSRect windowFrame = [view convertRect:view.bounds toView:nil];
    NSRect screenFrame = [view.window convertRectToScreen:windowFrame];
    NSRect qtScreenFrame = qt_mac_flipRect(screenFrame);
    return toQRect(qtScreenFrame);
}

QRect screenGeometry(NSWindow *window)
{
    // We want interior geometry (excluding window decorations). Use the contentView.
    return screenGeometry(window.contentView);
    // OR: return toQRect(qt_mac_flipRect[window contentRectForFrameRect:[window frame]]);
}

QRect screenGeometry(QWindow *window)
{
    return QRect(window->mapToGlobal(QPoint(0,0)), window->geometry().size());
}

QRect screenGeometry(TestWindow *window)
{
    return screenGeometry(window->qwindow());
}

// Qt global (window-interior) geometry to NSWindow global exterior geometry
NSRect nswindowFrameGeometry(QRect qtWindowGeometry, NSWindow *window)
{
    NSRect screenWindowContent = qt_mac_flipRect(toNSRect(qtWindowGeometry));
    return [window frameRectForContentRect:screenWindowContent];
}

// Qt local geometry to NSVIew local geometry
NSRect nsviewFrameGeometry(QRect qtWindowGeometry, NSView *view)
{
    if ([view isFlipped])
        return toNSRect(qtWindowGeometry);
    qFatal("unexpected this is");
}

QImage toQImage(CGImageRef image)
{
    if (!image)
        return QImage();

    QPlatformNativeInterface::NativeResourceForIntegrationFunction function =
            QGuiApplication::platformNativeInterface()->nativeResourceFunctionForIntegration("cgimagetoqimage");
    if (!function)
        return QImage(); // Not Cocoa platform plugin.

    typedef QImage (*CGImageToQImageFunction)(CGImageRef);
    return reinterpret_cast<CGImageToQImageFunction>(function)(image);
}

// Grabs the contents of the given NSWindow, at standard (1x) resolution.
CGImageRef grabWindow(NSWindow *window)
{
    if (!window)
        return nullptr;
    CGWindowID windowID = (CGWindowID)[window windowNumber];
    CGRect contentRect = NSRectToCGRect(toNSRect(screenGeometry(window)));
    CGImageRef image = CGWindowListCreateImage(contentRect, kCGWindowListOptionIncludingWindow,
                                               windowID, kCGWindowImageNominalResolution);
    return image;
}

// Grabs the contents of the given QWindow, at standard (1x) resolution.
QImage grabWindow(QWindow *window)
{
    return toQImage(grabWindow(getNSWindow(window)));
}

QImage grabWindow(TestWindow *window)
{
    return grabWindow(window->qwindow());
}

// Tests if pixels inside a rect are of the given color.
bool verifyImage(const QImage &image, QRect rect, QColor color)
{
    int stride = 10;
    for (int y = rect.y(); y < rect.y() + rect.height(); y += stride) {
        for (int x = rect.x(); x < rect.x() + rect.width(); x += stride) {
            QRgb pixel = image.pixel(x, y);
            if (pixel != color.rgb())
                return false;
        }
    }

    return true; // match
}




