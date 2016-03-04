
#include <QtTest/QTest>
#include <QtGui/QtGui>
#include <QtPlatformHeaders/QCocoaWindowFunctions>

#include <cocoaspy.h>
#include <nativeeventlist.h>
#include <qnativeevents.h>

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

    // Event handling
    void nativeMouseEvents();
    void nativeKeyboardEvents();
    void nativeEventForwarding();

    // Grahpics udpates and expose
    void nativeExpose();
    void expose();

private:
    CGPoint m_cursorPosition; // initial cursor position
};

// Utility funcitons for waiting and iterating. Colors.
int iterations = 3;
int delay = 25;
#define WAIT QTest::qWait(delay);
#define LOOP for (int i = 0; i < iterations; ++i) @autoreleasepool // Don't leak
#define HAPPY_COLOR [NSColor colorWithDeviceRed:0.1 green:0.6 blue:0.1 alpha:1.0] // Green is Good
#define MEH_COLOR [NSColor colorWithDeviceRed:0.1 green:0.1 blue:0.6 alpha:1.0] // Blue: Filler
#define SAD_COLOR [NSColor colorWithDeviceRed:0.5 green:0.1 blue:0.1 alpha:1.0] // Red: Error

/*

int viewConfigurationCount = 4;
// 0: Raster
// 1: OpenGL
// 2: Raster Layer
// 3s: OpenGL layer

#define VIEW_CONFIGURATIONS for (int _view_configuration = 0; _view_configuration < viewConfigurationCount; ++_view_configuration)
#define VIEW_INSTANCE createTestViewInstance(_view_configuration);

VIEW_CONFIGURATIONS {
    LOOP {
        NSWindow *window =
        window.contentView = VIEW_INSTANCE;
        [window makeKeyAndFront:nil];
        WAIT
        [window close];
        [window release];
    }
}

*/

void waitForWindowVisible(QWindow *window)
{
    // use qWaitForWindowExposed for now.
    QTest::qWaitForWindowExposed(window);
    WAIT
}

//
// Coordinate systems:
//
// Qt, CoreGraphics and this test works in the same coordinate system where the
// origin is at the top left corner of the main screen with the y axis pointing
// downwards. Cocoa has the origin at the bottom left corner with the y axis pointing
// upwards. There are geometry accessor functions:
//
//   QRect screenGeometry(NSView)
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

QRect toQRect(NSRect rect)
{
    return QRect(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
}

QRect screenGeometry(NSView *view)
{
    NSRect windowFrame = [view convertRect:view.bounds toView:nil];
    NSRect screenFrame = [view.window convertRectToScreen:windowFrame];
    NSRect coreGraphicsFrame = qt_mac_flipRect(screenFrame);
    return toQRect(coreGraphicsFrame);
}

NSView *getEmbeddableView(QWindow *window)
{

}

// QWindow instance [and event] counting facilities
namespace TestWindowSpy
{
    namespace detail {
        static int instanceCount = 0;
    }

    class TestWindow : public QRasterWindow
    {
    public:
        QColor fillColor;
        int exposeEventCount;
        int obscureEventCount;
        int paintEventCount;

        TestWindow() {
            setGeometry(100, 100, 100, 100);

            fillColor = QColor(Qt::green);
            exposeEventCount = 0;
            obscureEventCount = 0;
            paintEventCount = 0;

            ++detail::instanceCount;

        }
        ~TestWindow() {
            --detail::instanceCount;
        }

        void exposeEvent(QExposeEvent *event) {
            if (event->region().isEmpty())
                ++obscureEventCount;
            else
                ++exposeEventCount;
        }

        void paintEvent(QPaintEvent *) {
            ++paintEventCount;

            QPainter p(this);
            QRect all(QPoint(0, 0), this->geometry().size());
            p.fillRect(all, fillColor);
        }
    };

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

    self.fillColor = HAPPY_COLOR;
    self.forwardEvents = false;

    return self;
}

- (void)dealloc
{
//    qDebug() << "dealloc view";
    [super dealloc];
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
}

void tst_QCocoaWindow::embed()
{
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
            NSView *view = QCocoaWindowFunctions::getNSView(window);
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
            NSView *view = QCocoaWindowFunctions::getNSView(qtwindow);
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

// Verify that rejecting/forwarding events works as expected. There are two views,
// where the first responder view forwards received mouse and key events to the
// next responder, which should be the second view.
void tst_QCocoaWindow::nativeEventForwarding()
{
    LOOP {
        NSWindow *window = [[TestNSWidnow alloc] init];

        // Lower view which is completely covered by should get the events
        TestNSView *lower = [[TestNSView alloc] init];
        lower.fillColor = SAD_COLOR;
        window.contentView = lower;
        [lower release];

        // Upper view which is visble and rejects events
        TestNSView *upper = [[TestNSView alloc] init];
        upper.frame = NSMakeRect(0, 0, 100, 100);
        upper.forwardEvents = true;
        upper.fillColor = HAPPY_COLOR;
        [lower addSubview:upper];
        [upper release];

        [window makeFirstResponder: upper];
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

// Test native expose behavior - the number of drawRect calls for visible and
// hidden views, on initial show and repeated shows.
void tst_QCocoaWindow::nativeExpose()
{
    LOOP {
        // Test a window with a content view.
        {
            NSWindow *window = [[TestNSWidnow alloc] init];
            TestNSView *view = [[TestNSView alloc] init];
            window.contentView = view;
            [view release];
            QCOMPARE(view.drawRectCount, 0);

            // Show windpw and get a drawRect call
            [window makeKeyAndOrderFront:nil];
            WAIT
            QCOMPARE(view.drawRectCount, 1);

            // Hide the window, no extra drawRect calls
            [window orderOut:nil];
            QCOMPARE(view.drawRectCount, 1);

            // Show window again: we'll accept a repaint and also that the
            // OS has cached and don't repaint (the latter is observed to be
            // the actual behavior)
            [window makeKeyAndOrderFront:nil];
            WAIT
            QVERIFY(view.drawRectCount >= 1 && view.drawRectCount <= 2);

            [window close];
            [window release];
            WAIT
        }

        // Test a window with two stacked views - where the lower one is
        // completely hidden.
        {
            NSWindow *window = [[TestNSWidnow alloc] init];

            // Lower view which is completely covered
            TestNSView *lower = [[TestNSView alloc] init];
            lower.fillColor = SAD_COLOR;
            window.contentView = lower;
            [lower release];

            // Upper view which is visble
            TestNSView *upper = [[TestNSView alloc] init];
            upper.frame = NSMakeRect(0, 0, 100, 100);
            upper.fillColor = HAPPY_COLOR;
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
}

// Test that a window gets paint events on show.
void tst_QCocoaWindow::expose()
{
    LOOP {
        TestWindowSpy::TestWindow *window = new TestWindowSpy::TestWindow();

        QCOMPARE(window->exposeEventCount, 0);
        QCOMPARE(window->obscureEventCount, 0);
        QCOMPARE(window->paintEventCount, 0);

        // Expose event on initial show, and we requrie a paint event
        window->show();
        WAIT WAIT
        QCOMPARE(window->exposeEventCount, 1);
        QCOMPARE(window->obscureEventCount, 0);
        QCOMPARE(window->paintEventCount, 1);

        // Obscure event on hide, and no additional paint events
        window->hide();
        WAIT
        QCOMPARE(window->exposeEventCount, 1);
        QCOMPARE(window->obscureEventCount, 1);
        QCOMPARE(window->paintEventCount, 1);

        // Expose event on re-show, and accept zero or one paint event -
        // the QWindow implementation is allowed to cache and re-use
        // existing content.
        window->show();
        WAIT
        QCOMPARE(window->exposeEventCount, 2);
        QCOMPARE(window->obscureEventCount, 1);
        QVERIFY(window->paintEventCount == 1 || window->paintEventCount == 2);

        window->close();
        WAIT
//      TODO
//        QCOMPARE(window->obscureEventCount, 2);

        delete window;

    }
}


QTEST_MAIN(tst_QCocoaWindow)
#include <tst_qcocoawindow.moc>
