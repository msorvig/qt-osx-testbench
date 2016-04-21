
#include <QtTest/QTest>
#include <QtGui/QtGui>
#ifdef HAVE_TRANSFER_NATIVE_VIEW
#include <QtPlatformHeaders/QCocoaWindowFunctions>
#endif
#include <qpa/qplatformnativeinterface.h>

#include <cocoaspy.h>
#include <nativeeventlist.h>
#include <qnativeevents.h>

#include "testsupport.h"

/*!
    \class tst_QCocoaWindow

    QCocoaWindow is the QPlatformWindow subclass used by QWindow on OS X.
    It is implemented in terms of a native NSView and (sometimes) a NSWindow,
    as well as other helper classes. These are in the standard Qt use cases
    considered private implementation details.

    Top-level QWindows have a NSWindow, child QWindows do not. For the top-level
    case the NSView will then be the content view of the NSWindow. Child QWindows
    are added as (child) subviews ot the parent view. Child NSWindows are not
    used (by default, see options below).

    QCocoaWindow supports different NSView configurations: OpenGL or Raster
    content, layer-backed or "classic". The former is controlled by QWindow
    and the application, the latter is similarly under application control but
    can also be forced by externalities (such as a parent view using layers).

    QCocoaWindow supports "extracting" the NSView and using the native view API.
    This makes embedding Qt content in naive view hierachies possible, for
    example when using Qt to write application plugins for native applications.

    QCocoaWindow can be used to control 'foregin' NSViews. This can be used
    to embed native content in Qt applcaitons. The embedding then happens on
    the QWindow level.

    QCocoaWindow _is_ a NSView (conceptually): it behaves as an NSView is
    expected to do, and does not use resources outside of the NSView (global
    event filters etc). At the same time QCocoaWindow _controls_ a NSView
    (setting visibility status and geometry, etc), and we want to make as few
    assumtions as possible about the actual NSView type. There are some
    (if not many) exceptions to this in the QCocoaWindow implementation, but
    think twice before adding more.

    Options summary:
        QT_MAC_WANTS_LAYER
        _q_mac_wants_layer

        QT_MAC_USE_NSWINDOW

    Test function naming:
        native*    Verifies native view behavior
*/
class tst_QCocoaWindow : public QObject
{
    Q_OBJECT
public:
    tst_QCocoaWindow();
    ~tst_QCocoaWindow();
private slots:

    // Window and view instance management
    void nativeViewsAndWindows();
    void construction();
    void embed();

    // Geometry
    //
    // On the Qt side top-level QWindows are in Global (screen) coordinates,
    // while child windows are in local coordinates, relative to the parent
    // window. The same applies to NSWindows and NSViews.
    //
    // The coordinate systems are different: Qt has the origin at the top left
    // corner of the main screen with the y axis pointing downwards. Cocoa has
    // the origin at the bottom left corner with the y axis pointing upwards.
    //
    // QWindows with
    //
    // Geometry updates can happen via Qt API or via Cocoa API.
    //   - Qt: QWindow::setGeometry()
    //   - Cocoa: NSView frame change (observers)
    //
    // Setting geometry:
    //   - QWindows that have a NSWindow: set the NSWindow frame
    //     (the NSWindow will set the geometry for the content view)
    //   - QWindows with now NSWindow: set the NSView frame.
    //
    // Observe Geomery changes
    //   - update QPlatformWindow::geometry() if needed
    //   - send resize event iff this is updated geometry.
    //   - don't send expose event: this wil happen on next drawRect
    //
    // QCocoaWindow/QNSVindow/QNSView construction and recreation. This
    // might create spurious geoemtry change notifications. We'll disable
    // notifications while configuring, and then set the geometry when done.
    // At QCocoaWindow construction time
    //
    // Geometry update on show: OS X may move the window on show (for
    // example move it below the title bar). We'll allow that.
    //
    // TODO:
    //   - differrent notions of top-level:
    //       The top QWindow is top-level from Qt's point of view, but may
    //       be an embedded NSView from cocoa's point of view. In this case,
    //       should QPlatformWindow::geometry() be local or global coordinates
    //       (probably local)
    //   - setParent
    //
    void geometry_toplevel();
    void geometry_toplevel_embed();
    void geometry_child();
    void geometry_child_foreign();


    // Visibility
    //
    // QWindows should become visible when setVisible is called, and
    // not before. This can be a problem since some Cococa API
    // trigger [NSView drawRect] calls as a side effect, which may
    // cause Qt to transition the window to the visible state.
    //
    void visibility_native();
    void visibility_setVisible();
    void visibility_created_setGeometry();
    void visibility_created_propagateSizeHints();
    void visibility_created_drawrect();


    // Event handling
    void nativeMouseEvents();
    void nativeKeyboardEvents();
    void nativeEventForwarding();
    void mouseEvents();
    void keyboardEvents();
    void eventForwarding();

    // Grahpics updates and expose
    //
    // Qts expose event has two meanings:
    //   - Window visibility control: where the expose region indicates if the window
    //     is visible or not. (empty region means 'obscure'). Expose event users can
    //     use this to start/stop animations etc.
    //   - 'Paint now': The window is becoming visible and we need a graphics frame
    //      to display on screen. Expose event users musty flush a frame before returning.
    //
    // Windows visibility must be be accurate (in particular, windows that are covered
    // by other windows should revice an obscure evnent). Expose event timing must be
    // correct: Qt should paint before the window becomes visible, but not before graphics
    // is set up.
    //
    // Natively NSView offers drawRect, which is called when its time for view to produce
    // a frame. However, there is no guarantee that drawRect _will_ be called on a second
    // visiblity event after a hide - Cocoa may decide to used cached content.
    //
    void expose_native(); void expose_native_data();
    void expose_native_stacked();
    void expose(); void expose_data();
    void expose_stacked();

    void expose_resize_data();
    void expose_resize();

    void opengl_layermode();

    // Repaint coverage
    //
    // Verify that raster window updates are correct.
    //
    void paint_coverage(); void paint_coverage_data();
    void paint_coverage_childwindow();

private:
    CGPoint m_cursorPosition; // initial cursor position
};

int iterations = 1;

// Colors: Use "OK" and "FILLER" as general colors (add more if needed).
// "ERROR" (red) is a visual indication of test failure and should not
// be visible during error free test runs.
#define OK_COLOR [NSColor colorWithDeviceRed:0.1 green:0.6 blue:0.1 alpha:1.0] // Green is Good
#define FILLER_COLOR [NSColor colorWithDeviceRed:0.1 green:0.1 blue:0.6 alpha:1.0] // Blue: Filler
#define ERROR_COLOR [NSColor colorWithDeviceRed:0.5 green:0.1 blue:0.1 alpha:1.0] // Red: Error


// QWindow instance [and event] counting facilities
namespace TestWindowSpy
{
    namespace detail {
        static int instanceCount = 0;
    }

    // Creates a test window according to the given configuration. Returns a pointer
    // to the TestWindowBase interface. Access the QWindow with qwindow:
    //    TestWindowBase *ec = createTestWindow(...);
    //    QWindow *window = ec->qwindow;
    // Or cast(?)
    class TestWindowBase;
    TestWindowBase *createTestWindow(WindowConfiguration windowConfiguration);

    // Base class for storing event counts.
    class TestWindowBase
    {
    public:
        QWindow *qwindow; // pointer-to-QWindow-self.
        QColor fillColor;

        int mouseDownCount;
        int mouseUpCount;
        int keyDownCount;
        int keyUpCount;
        int exposeEventCount;
        int obscureEventCount;
        int paintEventCount;

        TestWindowBase()
        {
            resetCounters();
            ++detail::instanceCount;
        }

        virtual ~TestWindowBase()
        {
            --detail::instanceCount;
        }

        void resetCounters()
        {
            mouseDownCount = 0;
            mouseUpCount = 0;
            keyDownCount = 0;
            keyUpCount = 0;
            exposeEventCount = 0;
            obscureEventCount = 0;
            paintEventCount = 0;
        }

        // "take" functions returns wheter an event has been registered
        // and decrements the event counter if so.
        bool takeMouseDownEvent()
        {
            if (mouseDownCount == 0)
                return false;
            --mouseDownCount;
            return true;
        }

        bool takeMouseUpEvent()
        {
            if (mouseUpCount == 0)
                return false;
            --mouseUpCount;
            return true;
        }

        bool takeKeyDownEvent()
        {
            if (keyDownCount == 0)
                return false;
            --keyDownCount;
            return true;
        }

        bool takeKeyUpEvent()
        {
            if (keyUpCount == 0)
                return false;
            --keyUpCount;
            return true;
        }

        bool takeExposeEvent()
        {
            if (exposeEventCount == 0)
                return false;
            --exposeEventCount;
            return true;
        }

        bool takeObscureEvent()
        {
            if (obscureEventCount == 0)
                return false;
            --obscureEventCount;
            return true;
        }

        bool takePaintEvent()
        {
            if (paintEventCount == 0)

                return false;
            --paintEventCount;
            return true;
        }

        virtual void update(QRect rect)
        {
            // Will be overridden by subclass
        }

        virtual void repaint()
        {
            // Will be overridden by subclass
        }
    };

    // We want to have test windows with a common event counting API,
    // inhereting QRasterWindow or QOPenGLWindow. Solve by this slightly
    // evil templated multiple inheritance usage.
    template <typename WindowSubclass>
    class TestWindowTempl : public WindowSubclass, public virtual TestWindowBase
    {
    public:
        bool forwardEvents;
        // Event counter

        TestWindowTempl() {
            WindowSubclass::setGeometry(100, 100, 100, 100);

            forwardEvents = false;
            fillColor = QColor(Qt::green);

            qwindow = this;
        }

        void keyPressEvent(QKeyEvent * ev) {
            ev->setAccepted(!forwardEvents);
            keyDownCount += forwardEvents ? 0 : 1;
            if (!forwardEvents) {
                qDebug() << "key press";
            }
        }

        void keyReleaseEvent(QKeyEvent * ev) {
            ev->setAccepted(!forwardEvents);
            keyUpCount += forwardEvents ? 0 : 1;
        }

        void mousePressEvent(QMouseEvent * ev) {
            ev->setAccepted(!forwardEvents);
            mouseDownCount += forwardEvents ? 0 : 1;
            qDebug() << "mouse press";
        }

        void mouseReleaseEvent(QMouseEvent * ev) {
            ev->setAccepted(!forwardEvents);
            mouseUpCount += forwardEvents ? 0 : 1;
        }

        void exposeEvent(QExposeEvent *event) {
            if (event->region().isEmpty())
                ++obscureEventCount;
            else
                ++exposeEventCount;

            // Call base impl which will call paintEvent()
            WindowSubclass::exposeEvent(event);
        }
    };

    // Raster test window implementation
    class TestRasterImpl : public QRasterWindow, public virtual TestWindowBase
    {
    public:
        TestRasterImpl()
        {

        }

        void update(QRect rect)
        {
            QRasterWindow::update(rect);
        }

        virtual void repaint()
        {
            QRasterWindow::repaint();
        }

        void paintEvent(QPaintEvent *ev) {
            ++TestWindowBase::paintEventCount;

            // Fill the dirty rects with the current fill color.
            QPainter p(this);
            foreach (QRect rect, ev->region().rects()) {
                p.fillRect(rect, fillColor);
            }
        }
    };

    // OpenGL test window implementation
    class TestOpenGLImpl : public QOpenGLWindow, public virtual TestWindowBase
    {
    public:
        TestOpenGLImpl()
            :TestWindowBase(), QOpenGLWindow(QOpenGLWindow::NoPartialUpdate)
        {}

        void paintGL()
        {
            ++TestWindowBase::paintEventCount;
            glClearColor(fillColor.redF(), fillColor.greenF(), fillColor.blueF(), fillColor.alphaF());
            glClear(GL_COLOR_BUFFER_BIT);
        }
    };

    // Assemble window components:
    typedef TestWindowTempl<TestRasterImpl> TestWindow; // Legacy name
    typedef TestWindowTempl<TestRasterImpl> RasterTestWindow;
    typedef TestWindowTempl<TestOpenGLImpl> OpenGLTestWindow;

    bool isRasterWindow(WindowConfiguration windowConfiguration) {
        return windowConfiguration == RasterClassic || windowConfiguration == RasterLayer;
    }
    bool isLayeredWindow(WindowConfiguration windowConfiguration) {
        return windowConfiguration == RasterLayer || windowConfiguration == OpenGLLayer;
    }


    TestWindowBase *createTestWindow(WindowConfiguration windowConfiguration)
    {
        TestWindowBase *window;

        // Select Raster/OpenGL
        if (isRasterWindow(windowConfiguration))
            window = new RasterTestWindow();
        else
            window = new OpenGLTestWindow();

        // Select Layer-backed/Classic
        if (isLayeredWindow(windowConfiguration))
            window->qwindow->setProperty("_q_mac_wantsLayer", QVariant(true));

        return window;
    }

    void reset() {
        detail::instanceCount = 0;
    }

    int windowCount() {
        return detail::instanceCount;
    }
}

@interface TestNSWidnow : NSWindow
{

}
- (id) init;
- (void) dealloc;
@end

@implementation TestNSWidnow

- (id) init
{
    [super init];
    self.releasedWhenClosed = NO; // use explicit releases
    return self;
}

- (void)dealloc
{
//    qDebug() << "dealloc window";
    [super dealloc];
}
@end

NSWindow *createTestWindow()
{
    NSRect frame = NSMakeRect(100, 100, 100, 100);
    NSWindow *window =
        [[NSWindow alloc] initWithContentRect:frame
                                    styleMask:NSTitledWindowMask | NSClosableWindowMask |
                                              NSMiniaturizableWindowMask | NSResizableWindowMask
                                      backing:NSBackingStoreBuffered
                                        defer:NO];
    [window setTitle:@"Test Window"];
    [window setBackgroundColor:[NSColor blueColor]];
    return window;
}



@interface TestNSView : NSView

@property (retain) NSColor *fillColor;   // View background fill color
@property bool forwardEvents;   // Should the View reject and forward events?

// Event counters
@property int mouseDownCount;
@property int mouseUpCount;
@property int keyDownCount;
@property int keyUpCount;
@property int performKeyEquivalentCount;
@property int drawRectCount;

@end

@implementation TestNSView
- (id) init
{
    [super init];

    self.fillColor = OK_COLOR;
    self.forwardEvents = false;

    return self;
}

- (void)drawRect: (NSRect)dirtyRect
{
    ++self.drawRectCount;
    [self.fillColor setFill];
    NSRectFill(dirtyRect);
    [super drawRect:dirtyRect];
}

- (void)mouseDown:(NSEvent *)theEvent
{
    if (self.forwardEvents) {
        [super mouseDown:theEvent];
        return;
    }

    qDebug() << "left mouse down";
    ++self.mouseDownCount;
}

- (void)mouseUp:(NSEvent *)theEvent
{
    if (self.forwardEvents) {
        [super mouseUp:theEvent];
        return;
    }

    qDebug() << "left mouse up";
    ++self.mouseUpCount;
}

- (void)keyDown:(NSEvent *)theEvent
{
    if (self.forwardEvents) {
        [super keyDown:theEvent];
        return;
    }

    NSString *characters = [theEvent characters];
    qDebug() << "key down" << QString::fromNSString(characters);
    ++self.keyDownCount;
}

- (void)keyUp:(NSEvent *)theEvent
{
    if (self.forwardEvents) {
        [super keyUp:theEvent];
        return;
    }

    NSString *characters = [theEvent characters];
    qDebug() << "key up" << QString::fromNSString(characters);
    ++self.keyUpCount;
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
    if (self.forwardEvents) {
        return [super performKeyEquivalent:theEvent];
    }

    qDebug() << "perform key equivalent";
    return NO;
    ++self.performKeyEquivalentCount;
}

@end

// We are testing native NSViews and QWindows in various scenarios where
// we in many cases expect them to behave similarly. In order to avoid
// duplicating tests we create this interface which hides the concrete
// view/window type and gives us a common API for accessing event counters etc.
//
// Usage
//VIEW_TYPES {
//    TestViewInterface *testView = CREATE_TEST_VIEW
//    sendMousePressRelease(testView->geometry()->center());
//    QCOMPARE(testView->mouseDownCount)
//
// }
//
#if 0
class TestViewInterface
{
public:
    TestViewInterface(TestNSView *nsView);
    TestViewInterface(TestWindowSpy::TestWindow *qtWindow);

    TestNSView *ns() {

    }

    TestWindowSpy::TestWindow *qt() {

    }

    NSView *view() {
        return ns() ? ns() : QCocoaWindowFunctions::transferNativeView(qt());
    }

    int mouseDownCount() { return ns() ? ns().mouseDownCount : qt->mouseDownCount; }
    int mouseUpCount() {}
    int keyDownCount() {}
    int keyUpCount() {}
    int exposeEventCount() {}
    int obscureEventCount() {}
    int paintEventCount() {}
private:
    TestNSView m_cocoaView;
    TestWindowSpy::TestWindow *m_qtWindow;
};
#endif

//
//  Test Implementation
//

tst_QCocoaWindow::tst_QCocoaWindow()
{
    QCocoaSpy::init();

    // Save current cursor position.
    CGEventRef event = CGEventCreate(NULL);
    m_cursorPosition = CGEventGetLocation(event);
    CFRelease(event);

    // Some tests functions count keyboard events. The test executable may be
    // launched from a keydown event; give the keyup some time to clear:
    QTest::qWait(200);
}

tst_QCocoaWindow::~tst_QCocoaWindow()
{
    // Be kind, rewind (the cursor position).
    NativeEventList events;
    events.append(new QNativeMouseMoveEvent(toQPoint(m_cursorPosition)));
    events.play();
    WAIT WAIT
}

// Veryfy NSObject lifecycle assumtions and self-test the QCocoaSpy
// view and window counter.
void tst_QCocoaWindow::nativeViewsAndWindows()
{

    // Verify that we have deterministic NSWindow instance life
    // times - it should be possible to predictably have dealloc
    // called after showing and hiding the window
    LOOP {
        QCocoaSpy::reset(@"TestNSWidnow", @"TestNSView");

        QCOMPARE(QCocoaSpy::windowCount(), 0);
        NSWindow *window = [[TestNSWidnow alloc] init];

        // wrap the orderFront / close calls in autoreleasepool
        // to make sure any internal autorealeases are resolved
        @autoreleasepool {
            [window makeKeyAndOrderFront:nil];
            WAIT
            QCOMPARE(QCocoaSpy::windowCount(), 1);
            [window close];
            [window release];
        }

        WAIT // this test is timing-sensitive: needs at least ~20ms wait here
        QCOMPARE(QCocoaSpy::windowCount(), 0);
    }

    // Test NSView alloc/release cycle
    LOOP {
        QCocoaSpy::reset(@"TestNSWidnow", @"TestNSView");
        QCOMPARE(QCocoaSpy::viewCount(), 0);
        NSView *view = [[TestNSView alloc] init];
        QCOMPARE(QCocoaSpy::viewCount(), 1);
        [view release];
        QCOMPARE(QCocoaSpy::viewCount(), 0);
    }

    // Test NSWindow with NSView as content view alloc/release cycle
    LOOP {
        QCocoaSpy::reset(@"TestNSWidnow", @"TestNSView");

        @autoreleasepool {
            // Setup window-with-view: Note that the entire setup is done with
            // an autorelease pool in place: if not then the window.contentView
            // assignment leaks a TestNSView.
            NSWindow *window = [[TestNSWidnow alloc] init];
            NSView *view = [[TestNSView alloc] init];
            window.contentView = view;
            [view release];
            QCOMPARE(QCocoaSpy::windowCount(), 1);
            QCOMPARE(QCocoaSpy::viewCount(), 1);

            [window makeKeyAndOrderFront:nil];
            WAIT
            QCOMPARE(QCocoaSpy::windowCount(), 1);
            QCOMPARE(QCocoaSpy::viewCount(), 1);

            [window close];
            [window release];
        }

        WAIT
        QCOMPARE(QCocoaSpy::windowCount(), 0);
        QCOMPARE(QCocoaSpy::viewCount(), 0);
    }
}

void tst_QCocoaWindow::construction()
{
    LOOP {

        QCocoaSpy::reset(@"QNSWindow", @"QNSView");
        TestWindowSpy::reset();

        @autoreleasepool {
            // The Cocoa platform plugin implements a backend for the QWindow
            // class. Here we use a TestWindow subclass which tracks instances
            // and events.
            QWindow *window = new TestWindowSpy::TestWindow();
            window->setGeometry(100, 100, 100, 100);
            QCOMPARE(TestWindowSpy::windowCount(), 1);

            // The actual implementation is a QPlatformWindow subclass: QCocoaWidnow.
            // Each QWindow has a corresponding QPlatformWindow instance, which is
            // lazily constructed, on demand.
            QVERIFY(window->handle() == 0);

            // Construction can be forced, at which point there is a platform window.
            window->create();
            QVERIFY(window->handle() != 0);

            // The platform plugin _may_ create native windows and views at this point,
            // but is also allowed to further defer that. So we don't test.

            // Calling show() forces the creation of the native views and windows.
            window->show();
            waitForWindowVisible(window);
            // QCOMPARE(QCocoaSpy::visbileWindows, 1);

            // A visible QWindow has two native instances: a NSView and a NSWindow.
            // The NSView is the main backing instance for a QCocoaWindow. A NSWindow
            // is also needed to get a top-level window with a title bar etc.
            QCOMPARE(QCocoaSpy::viewCount(), 1);
            QCOMPARE(QCocoaSpy::windowCount(), 1);

            // deleting the QWindow instance hides and deletes the native views and windows
            delete window;
            WAIT
        }

        QCOMPARE(TestWindowSpy::windowCount(), 0);
        // QCOMPARE(QCocoaSpy::visbileWindows, 0);
        QCOMPARE(QCocoaSpy::windowCount(), 0);
        QCOMPARE(QCocoaSpy::viewCount(), 0);
    }

    // Repeat test, now with window->raise() call
    LOOP {
        QCocoaSpy::reset(@"QNSWindow", @"QNSView");
        TestWindowSpy::reset();

        @autoreleasepool {
            // The Cocoa platform plugin implements a backend for the QWindow
            // class. Here we use a TestWindow subclass which tracks instances
            // and events.
            QWindow *window = new TestWindowSpy::TestWindow();
            window->setGeometry(100, 100, 100, 100);
            QCOMPARE(TestWindowSpy::windowCount(), 1);

            // The actual implementation is a QPlatformWindow subclass: QCocoaWidnow.
            // Each QWindow has a corresponding QPlatformWindow instance, which is
            // lazily constructed, on demand.
            QVERIFY(window->handle() == 0);

            // Construction can be forced, at which point there is a platform window.
            window->create();
            QVERIFY(window->handle() != 0);

            // The platform plugin _may_ create native windows and views at this point,
            // but is also allowed to further defer that. So we don't test.

            // Calling show() forces the creation of the native views and windows.
            window->show();
            window->raise();
            waitForWindowVisible(window);
            // QCOMPARE(QCocoaSpy::visbileWindows, 1);

            // A visible QWindow has two native instances: a NSView and a NSWindow.
            // The NSView is the main backing instance for a QCocoaWindow. A NSWindow
            // is also needed to get a top-level window with a title bar etc.
            QCOMPARE(QCocoaSpy::viewCount(), 1);
            QCOMPARE(QCocoaSpy::windowCount(), 1);

            // deleting the QWindow instance hides and deletes the native views and windows
            delete window;
            WAIT
        }

        QCOMPARE(TestWindowSpy::windowCount(), 0);
        // QCOMPARE(QCocoaSpy::visbileWindows, 0);
        QCOMPARE(QCocoaSpy::windowCount(), 0);
        QCOMPARE(QCocoaSpy::viewCount(), 0);
    }
}

void tst_QCocoaWindow::embed()
{
#ifndef HAVE_TRANSFER_NATIVE_VIEW
    QSKIP("This test requires QCocoaWindowFunctions::transferNativeView");
#endif
    // Test instance lifetimes when transferring ownership of a QWindow to
    // its NSView.
    LOOP {
        QCocoaSpy::reset(@"QNSWindow", @"QNSView");
        TestWindowSpy::reset();

        QPointer<QWindow> window = new TestWindowSpy::TestWindow();
        @autoreleasepool {
            // It is possible to extract the native view for a QWindow and embed
            // that view somewhere in a native NSWidnow/NSView hiearchy. This si
            // done after creating the window instance, before and instead of
            // showing it via the standard QWindow API.
            NSView *view = QCocoaWindowFunctions::transferNativeView(window);
            QVERIFY(view != 0);

            // Extracting the native view transfers ownership of the QWindow instance
            // to the NSView instance. This creates a QCococaWindow instance and a
            // native NSView, but does not create a QNSWindow.
            QCOMPARE(TestWindowSpy::windowCount(), 1);
            QCOMPARE(QCocoaSpy::viewCount(), 1);
            QCOMPARE(QCocoaSpy::windowCount(), 0);

            // Releasing the NSView deletes the QWindow.
            [view release];
        }

        // Verify that all instances were deleted.
        QCOMPARE(QCocoaSpy::viewCount(), 0);
        QCOMPARE(TestWindowSpy::windowCount(), 0);
        QVERIFY(window.isNull());
    }

    // Test instance lifetimes when using the NSView for a QWindow as a
    // NSWindow content view.
    LOOP {
        QCocoaSpy::reset(@"QNSWindow", @"QNSView");
        TestWindowSpy::reset();

        QPointer<QWindow> qtwindow = new TestWindowSpy::TestWindow();
        @autoreleasepool {
            QCOMPARE(QCocoaSpy::viewCount(), 0);
            QCOMPARE(QCocoaSpy::windowCount(), 0);

            NSWindow *window = [[TestNSWidnow alloc] init];
            NSView *view = QCocoaWindowFunctions::transferNativeView(qtwindow);
            window.contentView = view;
            [view release];

            @autoreleasepool { // inner pool needed here to properly release tmp view references
                [window makeKeyAndOrderFront:nil];
            }
            WAIT

            QCOMPARE(TestWindowSpy::windowCount(), 1);
            QCOMPARE(QCocoaSpy::viewCount(), 1);
            QCOMPARE(QCocoaSpy::windowCount(), 0);

            // Make NSAutomaticFocusRing release internal view references now.
            [window makeFirstResponder: nil];

            // Close and release the window.
            [window close];
            [window release];
            WAIT WAIT
        }
        QCOMPARE(QCocoaSpy::viewCount(), 0);
        QCOMPARE(TestWindowSpy::windowCount(), 0);
        QVERIFY(qtwindow.isNull());
    }
}

void tst_QCocoaWindow::geometry_toplevel()
{
    // Test default QWindow geometry
    LOOP {
        TestWindowSpy::TestWindowBase *twindow = TestWindowSpy::createTestWindow(TestWindowSpy::RasterClassic);
        QWindow *qwindow = twindow->qwindow;

        qwindow->setGeometry(QRect()); // undo TestWindow default geometry
        qwindow->show();
        WAIT WAIT

        // OS X may (and will) move the window away from uner/over the menu bar.
        // So we can't be 100% sure of the actual position here. Expected is (0, 45).
        NSWindow *nswindow = getNSWindow(qwindow);
        NSView *nsview = getNSView(qwindow);
        QCOMPARE(screenGeometry(qwindow), screenGeometry(nswindow));
        QCOMPARE(screenGeometry(qwindow), screenGeometry(nsview));

        delete qwindow;
        WAIT WAIT
      }

    // Test specifying geometry
    LOOP {
        TestWindowSpy::TestWindowBase *twindow = TestWindowSpy::createTestWindow(TestWindowSpy::RasterClassic);
        QWindow *qwindow = twindow->qwindow;

        QRect geometry(101, 102, 103, 104);
        qwindow->setGeometry(geometry);
        qwindow->show();
        WAIT WAIT

        NSWindow *nswindow = getNSWindow(qwindow);
        NSView *nsview = getNSView(qwindow);
        QCOMPARE(screenGeometry(qwindow), geometry);
        QCOMPARE(screenGeometry(nswindow), geometry);
        QCOMPARE(screenGeometry(nsview), geometry);

        delete qwindow;
        WAIT WAIT
    }

    // Test changing geometry after create
    LOOP {
        TestWindowSpy::TestWindowBase *twindow = TestWindowSpy::createTestWindow(TestWindowSpy::RasterClassic);
        QWindow *qwindow = twindow->qwindow;

        QRect decoy(201, 202, 203, 204);
        qwindow->setGeometry(decoy);
        qwindow->create();
        QRect geometry(101, 102, 103, 104);
        qwindow->setGeometry(geometry);
        qwindow->show();
        WAIT WAIT

        NSWindow *nswindow = getNSWindow(qwindow);
        NSView *nsview = getNSView(qwindow);
        QCOMPARE(screenGeometry(qwindow), geometry);
        QCOMPARE(screenGeometry(nswindow), geometry);
        QCOMPARE(screenGeometry(nsview), geometry);

        delete qwindow;
        WAIT WAIT
    }

    // Test changing geometry after show
    LOOP {
        TestWindowSpy::TestWindowBase *twindow = TestWindowSpy::createTestWindow(TestWindowSpy::RasterClassic);
        QWindow *qwindow = twindow->qwindow;

        QRect decoy(201, 202, 203, 204);
        qwindow->setGeometry(decoy);
        qwindow->create();
        qwindow->show();
//        VISIBILITY_WAIT(qwindow);
        WAIT

        QRect geometry(101, 102, 103, 104);
//        GEOMETRY_WAIT(qwindow, qwindow->setGeometry(geometry))
        qwindow->setGeometry(geometry);
        WAIT

        NSWindow *nswindow = getNSWindow(qwindow);
        NSView *nsview = getNSView(qwindow);
        QCOMPARE(screenGeometry(qwindow), geometry);
        QCOMPARE(screenGeometry(nswindow), geometry);
        QCOMPARE(screenGeometry(nsview), geometry);

        delete qwindow;
        WAIT WAIT
    }

    // Test changing geometry after show using NSWindow
    LOOP {
        TestWindowSpy::TestWindowBase *twindow = TestWindowSpy::createTestWindow(TestWindowSpy::RasterClassic);
        QWindow *qwindow = twindow->qwindow;

        QRect geometry1(101, 102, 103, 104);
        qwindow->setGeometry(geometry1);
        qwindow->show();
        WAIT WAIT

        // Set geometry unsing NSWindow.
        NSWindow *nswindow = getNSWindow(qwindow);
        QRect geometry2(111, 112, 113, 114);
        NSRect frame = nswindowFrameGeometry(geometry2, nswindow);
        [nswindow setFrame: frame display: YES animate: NO];
        WAIT WAIT

        NSView *nsview = getNSView(qwindow);
        QCOMPARE(screenGeometry(qwindow), geometry2);
        QCOMPARE(screenGeometry(nswindow), geometry2);
        QCOMPARE(screenGeometry(nsview), geometry2);

        delete qwindow;
        WAIT WAIT
    }

    // Possible further testing
    //  - Generate mouse events to resize

}

// Verify that "embedded" QWindows get correct geometry
void tst_QCocoaWindow::geometry_toplevel_embed()
{
#ifndef HAVE_TRANSFER_NATIVE_VIEW
    QSKIP("This test requires QCocoaWindowFunctions::transferNativeView");
#endif

    // Test embedding in a NSWindow as the content view.
    LOOP {
        NSWindow *window = createTestWindow();
        [window setBackgroundColor:ERROR_COLOR];

//        NSView *testView = [[TestNSView alloc] init];

        // Embed the QNSView as contentView for a NSWindow
        QWindow *qwindow = new TestWindowSpy::TestWindow();
        NSView *view = QCocoaWindowFunctions::transferNativeView(qwindow);
        window.contentView = view;
        [view release];
        [window makeKeyAndOrderFront:nil];
        WAIT

        // Expect that the view covers the window content area.
        QCOMPARE(screenGeometry(view), screenGeometry(window));
        QCOMPARE(screenGeometry(view), screenGeometry(qwindow));

        // Give the NSWindow new geometry, verify that the view and Qt is updated.
        QRect newGeometry(111, 112, 113, 114);
        NSRect frame = nswindowFrameGeometry(newGeometry, window);
        [window setFrame: frame display: YES animate: NO];
        WAIT

        QCOMPARE(screenGeometry(window), newGeometry);
        QCOMPARE(screenGeometry(view), newGeometry);
        QCOMPARE(screenGeometry(qwindow), newGeometry);

        [window release];
        WAIT
    }

    // Test embedding in a parent NSView
}

// Test geometry for child QWidgets.
void tst_QCocoaWindow::geometry_child()
{
    // test adding child to already visible parent
    LOOP {
        // Parent
        TestWindowSpy::TestWindowBase *tparent = TestWindowSpy::createTestWindow(TestWindowSpy::RasterClassic);
        tparent->fillColor = toQColor(FILLER_COLOR);
        QWindow *parent = tparent->qwindow;
        QRect parentGeometry(101, 102, 103, 104);
        parent->setGeometry(parentGeometry);
        parent->show();
        WAIT WAIT

        QRect parentScreenGeometry = screenGeometry(parent);
        QCOMPARE(parentScreenGeometry, screenGeometry(getNSView(parent))); // sanity check

        // Create Child at offset from parent.
        QPoint childOffset(10, 11);
        QSize childSize(31, 32);
        QPoint expectedChildScreenPosition = parentScreenGeometry.topLeft() + childOffset;

        TestWindowSpy::TestWindowBase *tchild = TestWindowSpy::createTestWindow(TestWindowSpy::RasterClassic);
        tchild->fillColor = toQColor(OK_COLOR);
        QWindow *child = tchild->qwindow;
        child->setParent(parent);
        QRect childGeometry(childOffset, childSize);
        child->setGeometry(childGeometry);
        child->show();
        WAIT WAIT

        NSView *childView = getNSView(child);
        QCOMPARE(screenGeometry(child).topLeft(), expectedChildScreenPosition);
        QCOMPARE(screenGeometry(childView), screenGeometry(child));

        // Move Child using QWindow API
        childGeometry.translate(childOffset);
        expectedChildScreenPosition += childOffset;
        child->setGeometry(childGeometry);
        WAIT
        QCOMPARE(screenGeometry(child).topLeft(), expectedChildScreenPosition);
        QCOMPARE(screenGeometry(childView).topLeft(), expectedChildScreenPosition);

        // Move Child using NSView API
        childGeometry.translate(childOffset);
        expectedChildScreenPosition += childOffset;
        NSRect frame = nsviewFrameGeometry(childGeometry, childView);
        [childView setFrame:frame];
        WAIT
        QCOMPARE(screenGeometry(child).topLeft(), expectedChildScreenPosition);
        QCOMPARE(screenGeometry(childView).topLeft(), expectedChildScreenPosition);

        WAIT
        delete parent;
        WAIT
    }
}

// Verify that mouse event generation and processing works as expected for native views.
void tst_QCocoaWindow::nativeMouseEvents()
{
    LOOP {
        NSWindow *window = [[TestNSWidnow alloc] init];
        TestNSView *view = [[TestNSView alloc] init];
        window.contentView = view;
        [view release];
        [window makeKeyAndOrderFront:nil];

        WAIT

        QPoint viewCenter = screenGeometry(view).center();
        NativeEventList events;
        events.append(new QNativeMouseButtonEvent(viewCenter, Qt::LeftButton, 1, Qt::NoModifier));
        events.append(new QNativeMouseButtonEvent(viewCenter, Qt::LeftButton, 0, Qt::NoModifier));
        events.play();

        WAIT WAIT

        QCOMPARE(view.mouseDownCount, 1);
        QCOMPARE(view.mouseUpCount, 1);

        [window close];
        [window release];
        WAIT
    }
}

void tst_QCocoaWindow::geometry_child_foreign()
{


}

// Verify some basic NSwindow.isVisible behavior. See also
// expose_native() which further tests repaint behavior when
// hiding and showing windows.
void tst_QCocoaWindow::visibility_native()
{
    LOOP {
        // windows start out not visble
        NSWindow *window = [[TestNSWidnow alloc] init];
        TestNSView *view = [[TestNSView alloc] init];
        window.contentView = view;
        [view release];
        QVERIFY(!window.isVisible);
        QCOMPARE(view.drawRectCount, 0);

        // makeKeyAndOrderFront does display.
        [window makeKeyAndOrderFront:nil];
        QVERIFY(window.isVisible);
        QCOMPARE(view.drawRectCount, 1);
        WAIT

        // orderOut hides
        [window orderOut:nil];
        QVERIFY(!window.isVisible);
        WAIT

        // requesting a view repaint does not make the window visible
        [view setNeedsDisplay:YES];
        WAIT
        QVERIFY(!window.isVisible);

        // setFrame:frame display:NO actually does not display
        NSRect frame = NSMakeRect(120, 120, 100, 100);
        [window setFrame:frame display:NO animate:NO];
        WAIT
        QVERIFY(!window.isVisible);

        [window release];
        WAIT
    }
}

// Verify that native window visibility follows Qt window visibility.
void tst_QCocoaWindow::visibility_setVisible()
{
     WINDOW_CONFIGS  {
     LOOP {
         TestWindowSpy::TestWindowBase *w = TestWindowSpy::createTestWindow(WINDOW_CONFIG);
         QWindow *window = w->qwindow;

         window->setVisible(true);
         NSWindow *nativeWindow = getNSWindow(window);
         WAIT
         QVERIFY(nativeWindow);
         QVERIFY(window->isVisible());
         QVERIFY(nativeWindow.isVisible);

         window->setVisible(false);
         WAIT
         QVERIFY(!window->isVisible());
         QVERIFY(!nativeWindow.isVisible);

         delete window;
         WAIT
     }
     }

     WINDOW_CONFIGS  {
     LOOP {
         TestWindowSpy::TestWindowBase *w = TestWindowSpy::createTestWindow(WINDOW_CONFIG);
         QWindow *window = w->qwindow;

         window->create();
         NSWindow *nativeWindow = getNSWindow(window);
         QVERIFY(nativeWindow);
         QVERIFY(!window->isVisible());
         QVERIFY(!nativeWindow.isVisible);

         window->setVisible(true);
         WAIT
         QVERIFY(window->isVisible());
         QVERIFY(nativeWindow.isVisible);

         window->setVisible(false);
         WAIT
         QVERIFY(!window->isVisible());
         QVERIFY(!nativeWindow.isVisible);

         delete window;
         WAIT
     }
     }
 }

// Verify that calling setGeometry on a (created) QWindow does not make the window visible
void tst_QCocoaWindow::visibility_created_setGeometry()
{
    WINDOW_CONFIGS  {
    LOOP {
        TestWindowSpy::TestWindowBase *w = TestWindowSpy::createTestWindow(WINDOW_CONFIG);
        QWindow *window = w->qwindow;
        window->create();
        window->setGeometry(40, 50, 20, 30);
        WAIT

        NSWindow *nativeWindow = getNSWindow(window);
        QVERIFY(nativeWindow);
        QVERIFY(!window->isVisible());
        QVERIFY(!nativeWindow.isVisible);

        delete window;
        WAIT
    }
    }
}

// Verify that calling propagateSizeHints on a (created) QWindow does not make the window visible
void tst_QCocoaWindow::visibility_created_propagateSizeHints()
{
    WINDOW_CONFIGS  {
    LOOP {
        TestWindowSpy::TestWindowBase *w = TestWindowSpy::createTestWindow(WINDOW_CONFIG);
        QWindow *window = w->qwindow;
        window->create();

        // Set min/max size, which should call propagateSizeHints on the
        // platform window.
        window->setMinimumSize(QSize(50, 50));
        window->setMaximumSize(QSize(150, 150));
        WAIT

        NSWindow *nativeWindow = getNSWindow(window);
        QVERIFY(nativeWindow);
        QVERIFY(!window->isVisible());
        QVERIFY(!nativeWindow.isVisible);

        delete window;
        WAIT
    }
    }
}

// Verify visibility change on drawRect
void tst_QCocoaWindow::visibility_created_drawrect()
{
    // Windows controlled by Qt do not become visible if there is a drawRect call:
    // Qt controls the visiblity.
    WINDOW_CONFIGS  {
    LOOP {
        TestWindowSpy::TestWindowBase *w = TestWindowSpy::createTestWindow(WINDOW_CONFIG);
        QWindow *window = w->qwindow;
        window->create();

        NSWindow *nativeWindow = getNSWindow(window);
        NSView *nativeView = getNSView(window);
        [nativeView setNeedsDisplay:YES];
        WAIT
        QVERIFY(!window->isVisible());
        QVERIFY(!nativeWindow.isVisible);

        delete window;
        WAIT
    }
    }
}

// Verify that key event generation and processing works as expected for native views.
void tst_QCocoaWindow::nativeKeyboardEvents()
{
    LOOP {
        NSWindow *window = [[TestNSWidnow alloc] init];
        TestNSView *view = [[TestNSView alloc] init];
        window.contentView = view;
        [view release];
        [window makeFirstResponder: view]; // no first responder by default
        [window makeKeyAndOrderFront:nil];

        WAIT

        NativeEventList events;
        events.append(new QNativeKeyEvent(QNativeKeyEvent::Key_A, true, Qt::NoModifier));
        events.append(new QNativeKeyEvent(QNativeKeyEvent::Key_A, false, Qt::NoModifier));
        events.play();

            WAIT        WAIT

        QCOMPARE(view.keyDownCount, 1);
        QCOMPARE(view.keyUpCount, 1);

        [window close];
        [window release];
        WAIT
    }
}

// Verify that rejecting/forwarding events with native views works as expected.
// There are two views, where the first responder view forwards received mouse
// and key events to the next responder, which should be the second view.
void tst_QCocoaWindow::nativeEventForwarding()
{
    LOOP {
        NSWindow *window = [[TestNSWidnow alloc] init];

        // Lower view which is completely covered by should get the events
        TestNSView *lower = [[TestNSView alloc] init];
        lower.fillColor = ERROR_COLOR;
        window.contentView = lower;
        [lower release];

        // Upper view which is visble and rejects events
        TestNSView *upper = [[TestNSView alloc] init];
        upper.frame = NSMakeRect(0, 0, 100, 100);
        upper.forwardEvents = true;
        upper.fillColor = OK_COLOR;
        [lower addSubview:upper];
        [upper release];

        [window makeFirstResponder:upper];
        [window makeKeyAndOrderFront:nil];

        WAIT

        {
            // Test mouse events
            QPoint viewCenter = screenGeometry(upper).center();
            NativeEventList events;
            events.append(new QNativeMouseButtonEvent(viewCenter, Qt::LeftButton, 1, Qt::NoModifier));
            events.append(new QNativeMouseButtonEvent(viewCenter, Qt::LeftButton, 0, Qt::NoModifier));
            events.play();

                WAIT

            // Lower view gets the events
            QCOMPARE(upper.mouseDownCount, 0);
            QCOMPARE(upper.mouseUpCount, 0);
            QCOMPARE(lower.mouseDownCount, 1);
            QCOMPARE(lower.mouseUpCount, 1);
        }
        {
            // Test keyboard events
            NativeEventList events;
            events.append(new QNativeKeyEvent(QNativeKeyEvent::Key_A, true, Qt::NoModifier));
            events.append(new QNativeKeyEvent(QNativeKeyEvent::Key_A, false, Qt::NoModifier));
            events.play();

                WAIT

             // Lower view gets the events
            QCOMPARE(upper.keyDownCount, 0);
            QCOMPARE(upper.keyUpCount, 0);
            QCOMPARE(lower.keyDownCount, 1);
            QCOMPARE(lower.keyUpCount, 1);
        }

        [window close];
        [window release];
        WAIT
    }
}


void tst_QCocoaWindow::mouseEvents()
{
    LOOP {
        TestWindowSpy::TestWindow *window = new TestWindowSpy::TestWindow();
        window->setGeometry(100, 100, 100, 100);
        window->show();

        WAIT

        QPoint viewCenter = screenGeometry(window).center();
        NativeEventList events;
        events.append(new QNativeMouseButtonEvent(viewCenter, Qt::LeftButton, 1, Qt::NoModifier));
        events.append(new QNativeMouseButtonEvent(viewCenter, Qt::LeftButton, 0, Qt::NoModifier));
        events.play();

        QTRY_COMPARE(window->mouseDownCount, 1);
        QTRY_COMPARE(window->mouseUpCount, 1);

        delete window;
    }
}

// Verify that key event generation and processing works as expected for native views.
void tst_QCocoaWindow::keyboardEvents()
{
    LOOP {
        TestWindowSpy::TestWindow *window = new TestWindowSpy::TestWindow();
        window->setGeometry(100, 100, 100, 100);
        window->show();

        WAIT

        NativeEventList events;
        events.append(new QNativeKeyEvent(QNativeKeyEvent::Key_A, true, Qt::NoModifier));
        events.append(new QNativeKeyEvent(QNativeKeyEvent::Key_A, false, Qt::NoModifier));
        events.play();

        QTRY_COMPARE(window->keyDownCount, 1);
        QTRY_COMPARE(window->keyUpCount, 1);

        delete window;
    }
}


// Test that rejecting forwarding events with QWindow works.
void tst_QCocoaWindow::eventForwarding()
{
#ifndef HAVE_TRANSFER_NATIVE_VIEW
    QSKIP("This test requires QCocoaWindowFunctions::transferNativeView");
#endif

#if 0
    VIEW_CONFIG_LOOP(
        [](TestNSView *view) { view.forwardEvents = true },
        [](TestWindow *window){ window->forwardEvents = true },
        [](TestWindow *window){ window->setFlags(qtwindow->flags() | Qt::WindowTransparentForInput); },
        [](TestWindow *window){ window->setMask(window->geometry())) },
    ) {
        test test test
    }
#endif

    LOOP {
        NSWindow *window = [[TestNSWidnow alloc] init];

        // Lower view which is completely covered by should get the events
        TestNSView *lower = [[TestNSView alloc] init];
        lower.fillColor = ERROR_COLOR;
        window.contentView = lower;
        [lower release];

        TestWindowSpy::TestWindow *qtwindow = new TestWindowSpy::TestWindow();
        qtwindow->forwardEvents = true;
        NSView *upper = QCocoaWindowFunctions::transferNativeView(qtwindow);
        upper.frame = NSMakeRect(0, 0, 100, 100);
        [lower addSubview:upper];
        [upper release];

        [window makeFirstResponder: upper];
        [window makeKeyAndOrderFront:nil];

        {
            // Test mouse events
            QPoint viewCenter = screenGeometry(upper).center();
            NativeEventList events;
            events.append(new QNativeMouseButtonEvent(viewCenter, Qt::LeftButton, 1, Qt::NoModifier));
            events.append(new QNativeMouseButtonEvent(viewCenter, Qt::LeftButton, 0, Qt::NoModifier));
            events.play();

                WAIT

            // Rejected mouse events go nowhere - if you click on a "blank" section
            // then excepted behavior is that nothing happens, not further event
            // propagation to the blocked view below.
            QCOMPARE(qtwindow->mouseDownCount, 0);
            QCOMPARE(qtwindow->mouseUpCount, 0);
            QCOMPARE(lower.mouseDownCount, 0);
            QCOMPARE(lower.mouseUpCount, 0);
        }
        {
            // Test keyboard events
            NativeEventList events;
            events.append(new QNativeKeyEvent(QNativeKeyEvent::Key_A, true, Qt::NoModifier));
            events.append(new QNativeKeyEvent(QNativeKeyEvent::Key_A, false, Qt::NoModifier));
            events.play();

                WAIT

             // Keyboard events get propagated to the lower view
            QCOMPARE(qtwindow->keyDownCount, 0);
            QCOMPARE(qtwindow->keyUpCount, 0);
            QCOMPARE(lower.keyDownCount, 1);
            QCOMPARE(lower.keyUpCount, 1);
        }

        // Test Qt::WindowTransparentForInput windows
        qtwindow->setFlags(qtwindow->flags() | Qt::WindowTransparentForInput);
        qtwindow->forwardEvents = false;

        {
            // Mouse events
            QPoint viewCenter = screenGeometry(upper).center();
            NativeEventList events;
            events.append(new QNativeMouseButtonEvent(viewCenter, Qt::LeftButton, 1, Qt::NoModifier));
            events.append(new QNativeMouseButtonEvent(viewCenter, Qt::LeftButton, 0, Qt::NoModifier));
            events.play();

                WAIT

            // Events go the lower view
            QCOMPARE(qtwindow->mouseDownCount, 0);
            QCOMPARE(qtwindow->mouseUpCount, 0);
            QCOMPARE(lower.mouseDownCount, 1);
            QCOMPARE(lower.mouseUpCount, 1);
        }

        {
            // Test keyboard events
            NativeEventList events;
            events.append(new QNativeKeyEvent(QNativeKeyEvent::Key_A, true, Qt::NoModifier));
            events.append(new QNativeKeyEvent(QNativeKeyEvent::Key_A, false, Qt::NoModifier));
            events.play();

                WAIT
             // Keyboard events get propagated to the lower view
            QCOMPARE(qtwindow->keyDownCount, 0);
            QCOMPARE(qtwindow->keyUpCount, 0);
            QCOMPARE(lower.keyDownCount, 2);
            QCOMPARE(lower.keyUpCount, 2);
        }
        qtwindow->setFlags(qtwindow->flags() & ~Qt::WindowTransparentForInput);

        // Test masked windows
        qtwindow->setMask(QRect(QPoint(0, 0), qtwindow->geometry().size()));
        qtwindow->setFlags(qtwindow->flags() | Qt::WindowTransparentForInput);
        {
            // Mouse events
            QPoint viewCenter = screenGeometry(upper).center();
            NativeEventList events;
            events.append(new QNativeMouseButtonEvent(viewCenter, Qt::LeftButton, 1, Qt::NoModifier));
            events.append(new QNativeMouseButtonEvent(viewCenter, Qt::LeftButton, 0, Qt::NoModifier));
            events.play();

                WAIT WAIT WAIT

            // Events go the lower view
            QCOMPARE(qtwindow->mouseDownCount, 0);
            QCOMPARE(qtwindow->mouseUpCount, 0);
            QCOMPARE(lower.mouseDownCount, 2);
            QCOMPARE(lower.mouseUpCount, 2);
        }

        [window close];
        [window release];
        WAIT
    }
}

// Test native expose behavior - the number of drawRect calls for visible and
// hidden views, on initial show and repeated shows.
void tst_QCocoaWindow::expose_native()
{
    QFETCH(bool, useLayer);

    LOOP {
        // Test a window with a content view.
        NSWindow *window = [[TestNSWidnow alloc] init];
        TestNSView *view = [[TestNSView alloc] init];
        view.wantsLayer = useLayer;
        window.contentView = view;
        [view release];
        QCOMPARE(view.drawRectCount, 0);

        // Show window and get a drawRect call
        [window makeKeyAndOrderFront:nil];
        WAIT
        QCOMPARE(view.drawRectCount, 1);

        // Hide the window, no extra drawRect calls
        [window orderOut:nil];
        WAIT
        QCOMPARE(view.drawRectCount, 1);

        // [setFrame: display:NO] triggers a drawRect call,
        // even though the containing window is not visible
        NSRect frame = NSMakeRect(120, 120, 100, 100);
        [window setFrame:frame display:NO animate:NO];
        WAIT
        QCOMPARE(view.drawRectCount, 2);

        // [view setNeedsDisplay] on the content view for
        // a hidden window triggers a drawRect call.
        [view setNeedsDisplay:YES];
        WAIT
        QCOMPARE(view.drawRectCount, 3);

        // Show window again: we'll accept a repaint and also that the
        // OS has cached and don't repaint (the latter is observed to be
        // the actual behavior)
        [window makeKeyAndOrderFront:nil];
        WAIT
        QVERIFY(view.drawRectCount >= 3 && view.drawRectCount <= 3);

        [window close];
        [window release];
        WAIT
    }
}

// Test native expose behavior for a window with two stacked views - where the lower
// one is completely hidden.
void tst_QCocoaWindow::expose_native_stacked()
{
    LOOP {
        NSWindow *window = [[TestNSWidnow alloc] init];

        // Lower view which is completely covered
        TestNSView *lower = [[TestNSView alloc] init];
        lower.fillColor = ERROR_COLOR;
        window.contentView = lower;
        [lower release];

        // Upper view which is visble
        TestNSView *upper = [[TestNSView alloc] init];
        upper.frame = NSMakeRect(0, 0, 100, 100);
        upper.fillColor = OK_COLOR;
        [lower addSubview:upper];
        [upper release];

        // Inital show
        [window makeKeyAndOrderFront:nil];
        WAIT
        QCOMPARE(upper.drawRectCount, 1);
        QCOMPARE(lower.drawRectCount, 1); // for raster (no layers) we get a paint event
                                          // for the hidden view
        // Hide
        [window orderOut:nil];
        WAIT
        QCOMPARE(upper.drawRectCount, 1);
        QCOMPARE(lower.drawRectCount, 1);

        // Show again - accept one or no repaints
        [window makeKeyAndOrderFront:nil];
        WAIT
        QVERIFY(upper.drawRectCount >= 1 && upper.drawRectCount <= 2);
        QVERIFY(lower.drawRectCount >= 1 && lower.drawRectCount <= 2);

        [window close];
        [window release];
        WAIT
    }
}

void tst_QCocoaWindow::expose_data()
{
    QTest::addColumn<TestWindowSpy::WindowConfiguration>("windowconfiguration");
    WINDOW_CONFIGS {
        QTest::newRow(windowConfigurationName(WINDOW_CONFIG).constData()) << WINDOW_CONFIG;
    }
}

// Test that a window gets expose (and paint) events on show, and obscure events on hide
void tst_QCocoaWindow::expose()
{
    QFETCH(TestWindowSpy::WindowConfiguration, windowconfiguration);
    {
    LOOP {
        TestWindowSpy::TestWindowBase *window = TestWindowSpy::createTestWindow(windowconfiguration);

        QVERIFY(!window->takeExposeEvent());
        QVERIFY(!window->takeObscureEvent());
        QVERIFY(!window->takePaintEvent());

        // Show the window, expect one expose and one paint event.
        window->qwindow->show();
        WAIT WAIT  WAIT WAIT

        QVERIFY(window->takeExposeEvent());
        QVERIFY(!window->takeObscureEvent());
        QVERIFY(window->takePaintEvent());

        // Hide the window, expect one obscure evnet
        window->qwindow->hide();
        WAIT
        QVERIFY(!window->takeExposeEvent());
        QVERIFY(window->takeObscureEvent());
        QVERIFY(!window->takePaintEvent());

        // Request update on the hidden window: expect no expose or paint events.
        window->update(QRect(0, 0, 40, 40));
        QVERIFY(!window->takeExposeEvent());
        QVERIFY(!window->takePaintEvent());

        // Show the window, expect one expose event
        window->qwindow->show();
        WAIT WAIT
        QVERIFY(window->takeExposeEvent());
        QVERIFY(!window->takeObscureEvent());

        if (TestWindowSpy::isRasterWindow(TestWindowSpy::RasterClassic)) {
            // QRasterWindow may cache via QBackingStore, accept zero or one extra paint evnet
            window->takePaintEvent();
        } else {
            // Expect No caching for OpenGL. ### TODO: apparently not.
            window->takePaintEvent();
        }

        // Hide the window, expect +1 obscure event.
        window->qwindow->hide();
        WAIT WAIT // ### close eats the obscure event.
        window->qwindow->close();
        WAIT WAIT

        QVERIFY(window->takeObscureEvent());

        delete window;
    } // LOOP
    } // WINDOW_CONFIGS
}

void tst_QCocoaWindow::expose_stacked()
{
    WINDOW_CONFIGS  { LOOP {
        TestWindowSpy::TestWindowBase *lower = TestWindowSpy::createTestWindow(WINDOW_CONFIG);
        lower->fillColor = toQColor(ERROR_COLOR);
        TestWindowSpy::TestWindowBase *upper = TestWindowSpy::createTestWindow(WINDOW_CONFIG);
        upper->fillColor = toQColor(OK_COLOR);

        upper->qwindow->setParent(lower->qwindow);
        upper->qwindow->setGeometry(0, 0, 100, 100);
        upper->qwindow->show();
        lower->qwindow->show();


        WAIT WAIT         WAIT WAIT         WAIT WAIT

        delete lower;

        WAIT WAIT         WAIT WAIT         WAIT WAIT
    }}
}


void tst_QCocoaWindow::expose_resize_data()
{
    QTest::addColumn<TestWindowSpy::WindowConfiguration>("windowconfiguration");
#if 0
    // ### layer configs are broken
    WINDOW_CONFIGS {
        QTest::newRow(windowConfigurationName(WINDOW_CONFIG).constData()) << WINDOW_CONFIG;
    }
#else
    QTest::newRow(windowConfigurationName(TestWindowSpy::RasterClassic).constData()) << TestWindowSpy::RasterClassic;
    QTest::newRow(windowConfigurationName(TestWindowSpy::OpenGLClassic).constData()) << TestWindowSpy::OpenGLClassic;
#endif
}

// Verify that there is one expose + paint on window resize.
void tst_QCocoaWindow::expose_resize()
{
    QFETCH(TestWindowSpy::WindowConfiguration, windowconfiguration);

    // Test resize by programatically chainging the NSWindow frame
     LOOP {
        TestWindowSpy::TestWindowBase *twindow = TestWindowSpy::createTestWindow(windowconfiguration);
        QWindow *qwindow = twindow->qwindow;

        QRect geometry1(100, 100, 100, 100);
        qwindow->setGeometry(geometry1);
        qwindow->show();
        WAIT WAIT WAIT // wait-for-painted

        twindow->resetCounters();
        QVERIFY(!twindow->takeExposeEvent());

        NSWindow *nswindow = getNSWindow(qwindow);
        QRect geometry2(100, 100, 200, 200);
        NSRect frame = nswindowFrameGeometry(geometry2, nswindow);
        [nswindow setFrame:frame display:NO animate:NO];
        WAIT

        QVERIFY(twindow->takeExposeEvent());
        QVERIFY(twindow->takePaintEvent());

        delete qwindow;
        WAIT
    }
}

// Test layer-mode QWindow with a custom OPenGL foramt. Expected behavior
// is that the OpneGL context for the layer is configured with the custom
// format set on the context.
void tst_QCocoaWindow::opengl_layermode()
{
    QSKIP("in progress");

    // Construct and configure a window for layer mode.
    QWindow *window = new QWindow;
    window->setSurfaceType(QWindow::OpenGLSurface);
    window->setProperty("_q_mac_wantsLayer", QVariant(true));

    // Construct and configure an OpenGL context with a custom format.
    QOpenGLContext *context = new QOpenGLContext;
    QSurfaceFormat format;
    format.setMajorVersion(4);
    format.setMinorVersion(0);
    format.setProfile(QSurfaceFormat::CoreProfile);
    context->setFormat(format);

    // Create the context
    context->create();

    // Create the platform window. This will immediately create the
    // QNSView instance and OpenGL layer, and will also configure
    // and create the native OpenGL context for the layer.
    window->create();

    WAIT

    // Verify that QSurfaceFormat options are reflected on the native pixel format.
    context->makeCurrent(window);
    {
        // Access pixelformat via QWindow
        NSOpenGLPixelFormat *pixelFormat = getNSOpenGLPixelFormat(window);
        GLint profile;
        [pixelFormat getValues:&profile forAttribute:NSOpenGLPFAOpenGLProfile forVirtualScreen:0];
        QCOMPARE(profile, GLint(NSOpenGLProfileVersion3_2Core));
    }

    {
        // Access pixelformat via NSOpenGLContext current
        NSOpenGLPixelFormat *pixelFormat = getNSOpenGLPixelFormat([NSOpenGLContext currentContext]);
        GLint profile;
        [pixelFormat getValues:&profile forAttribute:NSOpenGLPFAOpenGLProfile forVirtualScreen:0];
        QCOMPARE(profile, GLint(NSOpenGLProfileVersion3_2Core));
    }
    context->doneCurrent();

    // TODO: Verify that the QSurfaceFormat options are reflected on the context
    // which is current during the draw callback.

    delete window;
    WAIT
}

void tst_QCocoaWindow::paint_coverage_data()
{
    QTest::addColumn<TestWindowSpy::WindowConfiguration>("windowconfiguration");
#if 0
    // (### raster_layer is broken)
    RASTER_WINDOW_CONFIGS {
        QTest::newRow(windowConfigurationName(WINDOW_CONFIG).constData()) << WINDOW_CONFIG;
    }
#else
        QTest::newRow(windowConfigurationName(TestWindowSpy::RasterClassic).constData()) << TestWindowSpy::RasterClassic;
#endif
}

// Test that windows are correctly repainted on show(), update(), and repaint()
void tst_QCocoaWindow::paint_coverage()
{
    QFETCH(TestWindowSpy::WindowConfiguration, windowconfiguration);

    LOOP {
        // Show window with solid color
        TestWindowSpy::TestWindowBase *window = TestWindowSpy::createTestWindow(windowconfiguration);
        QRect geometry(20, 20, 200, 200);
        window->fillColor = toQColor(FILLER_COLOR);
        window->qwindow->setGeometry(geometry);
        window->qwindow->show();
        WAIT WAIT

        // Verify that the pixels on screen match
        QRect imageGeometry(QPoint(0, 0), geometry.size());
        QVERIFY(verifyImage( grabWindow(window->qwindow), imageGeometry, toQColor(FILLER_COLOR)));

        // Fill subrect with new color
        window->fillColor = toQColor(OK_COLOR);
        QRect updateRect(50, 50, 50, 50);
        window->update(updateRect);
        WAIT WAIT

        // Verify that the window was partially repainted
        QVERIFY(verifyImage(grabWindow(window->qwindow), updateRect, toQColor(OK_COLOR)));
        QRect notUpdated(110, 110, 50, 50);
        QVERIFY(verifyImage(grabWindow(window->qwindow), notUpdated, toQColor(FILLER_COLOR)));

#ifdef HAVE_TRANSFER_NATIVE_VIEW
        // Call repaint() and verify that the window has been repainted on return.
        window->repaint();
        QVERIFY(verifyImage(grabWindow(window->qwindow), imageGeometry, toQColor(OK_COLOR)));
#endif
        delete window;
        WAIT
    }
}

void tst_QCocoaWindow::paint_coverage_childwindow()
{


}

QTEST_MAIN(tst_QCocoaWindow)
#include <tst_qcocoawindow.moc>
