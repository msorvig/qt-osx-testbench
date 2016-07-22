
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
private slots:
    void initTestCase_data();
    void initTestCase();
    void cleanupTestCase();
    void init();
    void cleanup();

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
    void visibility_setVisible(); void visibility_setVisible_data();
    void visibility_created_setGeometry(); void visibility_created_setGeometry_data();
    void visibility_created_propagateSizeHints(); void visibility_created_propagateSizeHints_data();
    void visibility_created_drawrect(); void visibility_created_drawrect_data();
    void visibility_child(); void visibility_child_data();


    // Event handling
    void nativeMouseEvents();
    void nativeKeyboardEvents();
    void nativeEventForwarding();
    void mouseEvents();
    void keyboardEvents();
    void eventForwarding();

    // Grahpics updates and expose
    //
    // Native view updates via drawRect:
    //
    // Natively NSView offers drawRect, which is called when it's time for view to produce
    // a frame. Content caching and the parent/child view heirarchy may affect when drawRect
    // is called. The drawRect_native() and drawRect_child_native() tests explore this
    // behavior.
    //
    // Expose events in Qt. Qts expose event has two meanings:
    //   - Window visibility control: where the expose region indicates if the window
    //     is visible or not. (empty region means 'obscure'). Expose event users can
    //     use this to start/stop animations etc.
    //   - 'Paint now': The window is becoming visible and we need a graphics frame
    //     to display on screen. Expose event users musty flush a frame before returning.
    //
    // Window visibility must be be accurate (in particular, windows that are covered
    // by other windows should revice obscure events). Expose event timing must be
    // correct: The first paint should happen as the window beomes visible, in time
    // to show the first frame on screen.
    void drawRect_native(); void drawRect_native_data();
    void drawRect_child_native(); void drawRect_child_native_data();

    void expose(); void expose_data();
    void expose_child(); void expose_child_data();

    void expose_resize(); void expose_resize_data();
    void requestUpdate(); void requestUpdate_data();

    void repaint_native(); void repaint_native_data();
    void repaint(); void repaint_data();

    void opengl_layermode();

    // Repaint coverage
    //
    // Verify that window updates are correct by grabbing
    // window and screen contents.
    //
    void paint_coverage(); void paint_coverage_data();
    void paint_coverage_childwindow(); void paint_coverage_childwindow_data();

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
@property bool _isOpaque;

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
    self._isOpaque = NO;

    return self;
}

- (BOOL)isOpaque
{
    return self._isOpaque;
}

- (void)drawRect:(NSRect)dirtyRect
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

    // qDebug() << "left mouse down";
    ++self.mouseDownCount;
}

- (void)mouseUp:(NSEvent *)theEvent
{
    if (self.forwardEvents) {
        [super mouseUp:theEvent];
        return;
    }

    // qDebug() << "left mouse up";
    ++self.mouseUpCount;
}

- (void)keyDown:(NSEvent *)theEvent
{
    if (self.forwardEvents) {
        [super keyDown:theEvent];
        return;
    }

    NSString *characters = [theEvent characters];
    // qDebug() << "key down" << QString::fromNSString(characters);
    ++self.keyDownCount;
}

- (void)keyUp:(NSEvent *)theEvent
{
    if (self.forwardEvents) {
        [super keyUp:theEvent];
        return;
    }

    NSString *characters = [theEvent characters];
    // qDebug() << "key up" << QString::fromNSString(characters);
    ++self.keyUpCount;
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
    if (self.forwardEvents) {
        return [super performKeyEquivalent:theEvent];
    }

    // qDebug() << "perform key equivalent";
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
    TestViewInterface(TestWindow *qtWindow);

    TestNSView *ns() {

    }

    TestWindow *qt() {

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
    TestWindow *m_qtWindow;
};
#endif

//
//  Test Implementation
//

void tst_QCocoaWindow::initTestCase_data()
{
    QTest::addColumn<bool>("displaylink");
    QTest::newRow("displaylink_update") << true;
    QTest::newRow("timer_update") << false;
}

void tst_QCocoaWindow::initTestCase()
{
    QCocoaSpy::init();

    // Save current cursor position.
    CGEventRef event = CGEventCreate(NULL);
    m_cursorPosition = CGEventGetLocation(event);
    CFRelease(event);

    // Some tests functions count keyboard events. The test executable may be
    // launched from a keydown event; give the keyup some time to clear.
    QTest::qWait(200);
}

void tst_QCocoaWindow::cleanupTestCase()
{
    // Be kind, rewind (the cursor position).
    NativeEventList events;
    events.append(new QNativeMouseMoveEvent(toQPoint(m_cursorPosition)));
    events.play();
    WAIT WAIT
}

void tst_QCocoaWindow::init()
{
    // Select update implementation (timer / cvdisplaylink).
    QFETCH_GLOBAL(bool, displaylink);
    qputenv("QT_MAC_ENABLE_CVDISPLAYLINK", displaylink ? QByteArray("1") : QByteArray("0"));
}

void tst_QCocoaWindow::cleanup()
{
    // Clean up windows left open by failing tests
    TestWindow::deleteOpenWindows();
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
        
        // Use autoreleasepool to make sure temp references
        // to the NSWindow taken by Cocoa are cleaned up.
        @autoreleasepool { 
            NSWindow *window = [[TestNSWidnow alloc] init];

            [window makeKeyAndOrderFront:nil];
            WAIT
            QCOMPARE(QCocoaSpy::windowCount(), 1);
            [window close];
            [window release];
        }
        WAIT

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
        TestWindow::resetWindowCounter();

        @autoreleasepool {
            // The Cocoa platform plugin implements a backend for the QWindow
            // class. Here we use a TestWindow subclass which tracks instances
            // and events.
            TestWindow *window = TestWindow::createWindow();
            window->setGeometry(100, 100, 100, 100);
            QCOMPARE(TestWindow::windowCount(), 1);

            // The actual implementation is a QPlatformWindow subclass: QCocoaWidnow.
            // Each QWindow has a corresponding QPlatformWindow instance, which is
            // lazily constructed, on demand.
            QVERIFY(window->handle() == 0);

            // Construction can be forced, at which point there is a platform window.
            window->create();
            QVERIFY(window->handle() != 0);

            // Native Window creation is possibly lazy
#ifdef HAVE_LAZY_NATIVE_WINDOWS
            QCOMPARE(QCocoaSpy::windowCount(), 0);
#endif
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

        QCOMPARE(TestWindow::windowCount(), 0);
        // QCOMPARE(QCocoaSpy::visbileWindows, 0);
        QCOMPARE(QCocoaSpy::windowCount(), 0);
        QCOMPARE(QCocoaSpy::viewCount(), 0);
    }

    // Repeat test, now with window->raise() call
    LOOP {
        QCocoaSpy::reset(@"QNSWindow", @"QNSView");
        TestWindow::resetWindowCounter();

        @autoreleasepool {
            // The Cocoa platform plugin implements a backend for the QWindow
            // class. Here we use a TestWindow subclass which tracks instances
            // and events.
            TestWindow *window = TestWindow::createWindow();
            window->setGeometry(100, 100, 100, 100);
            QCOMPARE(TestWindow::windowCount(), 1);

            // The actual implementation is a QPlatformWindow subclass: QCocoaWidnow.
            // Each QWindow has a corresponding QPlatformWindow instance, which is
            // lazily constructed, on demand.
            QVERIFY(window->handle() == 0);

            // Construction can be forced, at which point there is a platform window.
            window->create();
            QVERIFY(window->handle() != 0);

            // Native View and Window creation is possibly lazy
#ifdef HAVE_LAZY_NATIVE_WINDOWS
            QCOMPARE(QCocoaSpy::windowCount(), 0);
#endif

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

        QCOMPARE(TestWindow::windowCount(), 0);
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
        TestWindow::resetWindowCounter();

        TestWindow *testWindow = TestWindow::createWindow();
        QPointer<QWindow> qwindow = testWindow->takeQWindow();
        delete testWindow;
        @autoreleasepool {
            // It is possible to extract the native view for a QWindow and embed
            // that view somewhere in a native NSWidnow/NSView hiearchy. This si
            // done after creating the window instance, before and instead of
            // showing it via the standard QWindow API.
            NSView *view = QCocoaWindowFunctions::transferNativeView(qwindow);
            QVERIFY(view != 0);

            // Extracting the native view transfers ownership of the QWindow instance
            // to the NSView instance. This creates a QCococaWindow instance and a
            // native NSView, but does not create a QNSWindow.
            QCOMPARE(TestWindow::windowCount(), 1);
            QCOMPARE(QCocoaSpy::viewCount(), 1);
            QCOMPARE(QCocoaSpy::windowCount(), 0);

            // Releasing the NSView deletes the QWindow.
            [view release];
            QVERIFY(qwindow.isNull());
        }

        // Verify that all instances were deleted.
        QCOMPARE(QCocoaSpy::viewCount(), 0);
        QCOMPARE(TestWindow::windowCount(), 0);
    }

    // Test instance lifetimes when using the NSView for a QWindow as a
    // NSWindow content view.
    LOOP {
        QCocoaSpy::reset(@"QNSWindow", @"QNSView");
        TestWindow::resetWindowCounter();

        QPointer<QWindow> qwindow = TestWindow::createWindow()->takeQWindow();
        @autoreleasepool {
            QCOMPARE(QCocoaSpy::viewCount(), 0);
            QCOMPARE(QCocoaSpy::windowCount(), 0);

            NSWindow *window = [[TestNSWidnow alloc] init];
            NSView *view = QCocoaWindowFunctions::transferNativeView(qwindow);
            window.contentView = view;
            [view release];

            @autoreleasepool { // inner pool needed here to properly release tmp view references
                [window makeKeyAndOrderFront:nil];
            }
            WAIT

            QCOMPARE(TestWindow::windowCount(), 1);
            QCOMPARE(QCocoaSpy::viewCount(), 1);
            QCOMPARE(QCocoaSpy::windowCount(), 0);

            // Make NSAutomaticFocusRing release internal view references now.
            [window makeFirstResponder:nil];

            // Close and release the window.
            [window close];
            [window release];
            WAIT WAIT
        }
        WAIT

        QCOMPARE(QCocoaSpy::viewCount(), 0);
        QCOMPARE(TestWindow::windowCount(), 0);
        QVERIFY(qwindow.isNull());
    }
}

void tst_QCocoaWindow::geometry_toplevel()
{
    // Test default QWindow geometry
    LOOP {
        TestWindow *window = TestWindow::createWindow();

        window->setGeometry(QRect()); // undo TestWindow default geometry
        window->show();
        WAIT WAIT

        // OS X may (and will) move the window away from under/over the menu bar.
        // So we can't be 100% sure of the actual position here. Expected is (0, 45).
        NSWindow *nswindow = getNSWindow(window);
        NSView *nsview = getNSView(window);
        QCOMPARE(screenGeometry(window), screenGeometry(nswindow));
        QCOMPARE(screenGeometry(window), screenGeometry(nsview));

        delete window;
        WAIT WAIT
      }

    // Test specifying geometry
    LOOP {
        TestWindow *window = TestWindow::createWindow();

        QRect geometry(101, 102, 103, 104);
        window->setGeometry(geometry);
        window->show();
        WAIT WAIT

        NSWindow *nswindow = getNSWindow(window);
        NSView *nsview = getNSView(window);
        QCOMPARE(screenGeometry(window), geometry);
        QCOMPARE(screenGeometry(nswindow), geometry);
        QCOMPARE(screenGeometry(nsview), geometry);

        delete window;
        WAIT WAIT
    }

    // Test changing geometry after create
    LOOP {
        TestWindow *window = TestWindow::createWindow();

        QRect decoy(201, 202, 203, 204);
        window->setGeometry(decoy);
        window->create();
        QRect geometry(101, 102, 103, 104);
        window->setGeometry(geometry);
        window->show();
        WAIT WAIT

        NSWindow *nswindow = getNSWindow(window);
        NSView *nsview = getNSView(window);
        QCOMPARE(screenGeometry(window), geometry);
        QCOMPARE(screenGeometry(nswindow), geometry);
        QCOMPARE(screenGeometry(nsview), geometry);

        delete window;
        WAIT WAIT
    }

    // Test changing geometry after show
    LOOP {
        TestWindow *window = TestWindow::createWindow();

        QRect decoy(201, 202, 203, 204);
        window->setGeometry(decoy);
        window->create();
        window->show();
//        VISIBILITY_WAIT(window);
        WAIT

        QRect geometry(101, 102, 103, 104);
//        GEOMETRY_WAIT(window, window->setGeometry(geometry))
        window->setGeometry(geometry);
        WAIT

        NSWindow *nswindow = getNSWindow(window);
        NSView *nsview = getNSView(window);
        QCOMPARE(screenGeometry(window), geometry);
        QCOMPARE(screenGeometry(nswindow), geometry);
        QCOMPARE(screenGeometry(nsview), geometry);

        delete window;
        WAIT WAIT
    }

    // Test changing geometry after show using NSWindow
    LOOP {
        TestWindow *window = TestWindow::createWindow();

        QRect geometry1(101, 102, 103, 104);
        window->setGeometry(geometry1);
        window->show();
        WAIT

        // Set geometry unsing NSWindow.
        NSWindow *nswindow = getNSWindow(window);
        QRect geometry2(111, 112, 113, 114);
        NSRect frame = nswindowFrameGeometry(geometry2, nswindow);
        [nswindow setFrame:frame display:YES animate:NO];
        WAIT WAIT

        NSView *nsview = getNSView(window);
        QCOMPARE(screenGeometry(window), geometry2);
        QCOMPARE(screenGeometry(nswindow), geometry2);
        QCOMPARE(screenGeometry(nsview), geometry2);

        delete window;
        WAIT
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
        QWindow *qwindow = TestWindow::createWindow()->takeQWindow();
        NSView *view = QCocoaWindowFunctions::transferNativeView(qwindow);
        window.contentView = view;
        [view release];
        [window makeKeyAndOrderFront:nil];
        WAIT

        // Expect that the view covers the window content area.
        QCOMPARE(screenGeometry(view), screenGeometry(window));
        QCOMPARE(screenGeometry(view), screenGeometry(window));

        // Give the NSWindow new geometry, verify that the view and Qt is updated.
        QRect newGeometry(111, 112, 113, 114);
        NSRect frame = nswindowFrameGeometry(newGeometry, window);
        [window setFrame:frame display:YES animate:NO];
        WAIT

        QCOMPARE(screenGeometry(window), newGeometry);
        QCOMPARE(screenGeometry(view), newGeometry);
        QCOMPARE(screenGeometry(window), newGeometry);

        [window release];
        WAIT
    }

    // Test embedding in a parent NSView
}

// Test geometry for child QWindows.
void tst_QCocoaWindow::geometry_child()
{
    // test adding child to already visible parent
    LOOP {
        // Parent
        TestWindow *parent = TestWindow::createWindow();
        parent->setFillColor(toQColor(FILLER_COLOR));
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

        TestWindow *child = TestWindow::createWindow(TestWindow::RasterClassic);
        child->setFillColor(toQColor(OK_COLOR));
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

// Verify that an embedded a "foreign" NSView gets correct geometry.
void tst_QCocoaWindow::geometry_child_foreign()
{
    LOOP {
        // Create native parent window with foreign child, show.
        TestWindow *parent = TestWindow::createWindow();
        parent->setFillColor(toQColor(FILLER_COLOR));
        QRect parentGeometry(101, 102, 103, 104);
        parent->setGeometry(parentGeometry);

        NSView *view = [[TestNSView alloc] init];
        QWindow *child = QWindow::fromWinId(WId(view));
        QPoint childOffset(20, 20);
        QSize childSize(51, 51);
        child->setGeometry(QRect(childOffset, childSize));
        child->setParent(parent->qwindow());

        // Show parent and check child geometry
        parent->show();
        WAIT
        QCOMPARE(child->geometry(), QRect(childOffset, childSize));
        QCOMPARE(screenGeometry(child).topLeft(), screenGeometry(parent).topLeft() + childOffset);
        QCOMPARE(screenGeometry(child).size(), childSize);

        // Move child and check geometry.
        QPoint childOffset2(40, 40);
        child->setGeometry(QRect(childOffset2, childSize));
        WAIT
        QCOMPARE(child->geometry(), QRect(childOffset2, childSize));
        QCOMPARE(screenGeometry(child).topLeft(), screenGeometry(parent).topLeft() + childOffset2);
        QCOMPARE(screenGeometry(child).size(), childSize);

        delete parent;
        WAIT
    }
}

// Verify some basic NSwindow.isVisible behavior. See also
// drawRect_native() which further tests repaint behavior when
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
        WAIT
        QVERIFY(window.isVisible);
        QCOMPARE(view.drawRectCount, 1);

        // orderOut hides
        [window orderOut:nil];
        WAIT
        QVERIFY(!window.isVisible);

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

void tst_QCocoaWindow::visibility_setVisible_data()
{
    QTest::addColumn<TestWindow::WindowConfiguration>("windowconfiguration");
    WINDOW_CONFIGS {
        QTest::newRow(TestWindow::windowConfigurationName(WINDOW_CONFIG).constData()) << WINDOW_CONFIG;
    }
}

// Verify that native window visibility follows Qt window visibility.
void tst_QCocoaWindow::visibility_setVisible()
{
    QFETCH(TestWindow::WindowConfiguration, windowconfiguration);

    // Test direct setVisible() call
    LOOP {
         TestWindow *window = TestWindow::createWindow(windowconfiguration);

         window->setVisible(true);
         WAIT

         NSWindow *nativeWindow = getNSWindow(window);
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

     // Test create(), then setVisible();
     LOOP {
         TestWindow *window = TestWindow::createWindow(windowconfiguration);

         window->create();
         NSWindow *nativeWindow = getNSWindow(window);
#ifdef HAVE_LAZY_NATIVE_WINDOWS
         QVERIFY(!nativeWindow);
#else
         QVERIFY(nativeWindow);
         QVERIFY(!window->isVisible());
         QVERIFY(!nativeWindow.isVisible);
#endif
         window->setVisible(true);
         WAIT
         nativeWindow = getNSWindow(window);
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

void tst_QCocoaWindow::visibility_created_setGeometry_data()
{
    QTest::addColumn<TestWindow::WindowConfiguration>("windowconfiguration");
    WINDOW_CONFIGS {
        QTest::newRow(TestWindow::windowConfigurationName(WINDOW_CONFIG).constData()) << WINDOW_CONFIG;
    }
}

// Verify that calling setGeometry on a (created) QWindow does not make the window visible
void tst_QCocoaWindow::visibility_created_setGeometry()
{
    QFETCH(TestWindow::WindowConfiguration, windowconfiguration);

    LOOP {
        TestWindow *window = TestWindow::createWindow(windowconfiguration);
        window->create();
        window->setGeometry(40, 50, 20, 30);
        WAIT

        NSWindow *nativeWindow = getNSWindow(window);
#ifdef HAVE_LAZY_NATIVE_WINDOWS
        QVERIFY(!nativeWindow);
#else
        QVERIFY(nativeWindow);
        QVERIFY(!window->isVisible());
        QVERIFY(!nativeWindow.isVisible);
#endif
        delete window;
        WAIT
    }
}

void tst_QCocoaWindow::visibility_created_propagateSizeHints_data()
{
    QTest::addColumn<TestWindow::WindowConfiguration>("windowconfiguration");
    WINDOW_CONFIGS {
        QTest::newRow(TestWindow::windowConfigurationName(WINDOW_CONFIG).constData()) << WINDOW_CONFIG;
    }
}

// Verify that calling propagateSizeHints on a (created) QWindow does not make the window visible
void tst_QCocoaWindow::visibility_created_propagateSizeHints()
{
    QFETCH(TestWindow::WindowConfiguration, windowconfiguration);

    LOOP {
        TestWindow *window = TestWindow::createWindow(windowconfiguration);
        window->create();

        // Set min/max size, which should call propagateSizeHints on the
        // platform window.
        window->setMinimumSize(QSize(50, 50));
        window->setMaximumSize(QSize(150, 150));
        WAIT

        NSWindow *nativeWindow = getNSWindow(window);
#ifdef HAVE_LAZY_NATIVE_WINDOWS
        QVERIFY(!nativeWindow);
#else
        QVERIFY(nativeWindow);
        QVERIFY(!window->isVisible());
        QVERIFY(!nativeWindow.isVisible);
#endif
        delete window;
        WAIT
    }
}

void tst_QCocoaWindow::visibility_created_drawrect_data()
{
    QTest::addColumn<TestWindow::WindowConfiguration>("windowconfiguration");
    WINDOW_CONFIGS {
        QTest::newRow(TestWindow::windowConfigurationName(WINDOW_CONFIG).constData()) << WINDOW_CONFIG;
    }
}

// Verify visibility change on drawRect
void tst_QCocoaWindow::visibility_created_drawrect()
{
    QFETCH(TestWindow::WindowConfiguration, windowconfiguration);

    // Windows controlled by Qt do not become visible if there is a drawRect call:
    // Qt controls the visiblity.
    LOOP {
        TestWindow *window = TestWindow::createWindow(windowconfiguration);
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

void tst_QCocoaWindow::visibility_child_data()
{
    QTest::addColumn<TestWindow::WindowConfiguration>("windowconfiguration");
    WINDOW_CONFIGS {
        QTest::newRow(TestWindow::windowConfigurationName(WINDOW_CONFIG).constData()) << WINDOW_CONFIG;
    }
}

// Verify that child window visibility is correctly handled
void tst_QCocoaWindow::visibility_child()
{
    QFETCH(TestWindow::WindowConfiguration, windowconfiguration);

    LOOP {
        TestWindow *parent = TestWindow::createWindow(windowconfiguration);
        parent->setFillColor(toQColor(ERROR_COLOR));
        QRect parentGeometry(101, 102, 100, 100);
        parent->setGeometry(parentGeometry);

        TestWindow *child = TestWindow::createWindow(windowconfiguration);
        child->setFillColor(toQColor(OK_COLOR));
        child->setParent(parent);
        child->setGeometry(0, 0, 100, 100);
        child->create();

        NSView *nativeChild = getNSView(child);
        QVERIFY(nativeChild);

        // Verify that [NSView isHidden] status follows Qt visiblity status. Note
        // that a non-hidden view needs a visible ancestor to become actually
        // vsibile.
        
        // ### Initial isHidden state
        // QVERIFY([nativeChild isHidden]);
        child->show();
        WAIT
        QVERIFY(![nativeChild isHidden]);
        child->hide();
        WAIT
        QVERIFY([nativeChild isHidden]);

        // Show parent with child
        parent->show();
        child->show();
        WAIT
        QVERIFY(![nativeChild isHidden]);

        // Hide parent. Child should retain the non-hidden state.
        parent->hide();
        WAIT
        QVERIFY(![nativeChild isHidden]);

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

// Verify that key event generation and processing works as expected for native views.
void tst_QCocoaWindow::nativeKeyboardEvents()
{
    LOOP {
        NSWindow *window = [[TestNSWidnow alloc] init];
        TestNSView *view = [[TestNSView alloc] init];
        window.contentView = view;
        [view release];
        [window makeFirstResponder:view]; // no first responder by default
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
        TestWindow *window = TestWindow::createWindow();
        window->setGeometry(100, 100, 100, 100);
        window->show();

        WAIT

        QPoint viewCenter = screenGeometry(window).center();
        NativeEventList events;
        events.append(new QNativeMouseButtonEvent(viewCenter, Qt::LeftButton, 1, Qt::NoModifier));
        events.append(new QNativeMouseButtonEvent(viewCenter, Qt::LeftButton, 0, Qt::NoModifier));
        events.play();

        WAIT

        QVERIFY(window->takeOneEvent(TestWindow::MouseDownEvent));
        QVERIFY(window->takeOneEvent(TestWindow::MouseUpEvent));

        delete window;
    }
}

// Verify that key event generation and processing works as expected for native views.
void tst_QCocoaWindow::keyboardEvents()
{
    LOOP {
        TestWindow *window = TestWindow::createWindow();
        window->setGeometry(100, 100, 100, 100);
        window->show();

        WAIT

        NativeEventList events;
        events.append(new QNativeKeyEvent(QNativeKeyEvent::Key_A, true, Qt::NoModifier));
        events.append(new QNativeKeyEvent(QNativeKeyEvent::Key_A, false, Qt::NoModifier));
        events.play();

        WAIT

        QVERIFY(window->takeOneEvent(TestWindow::KeyDownEvent));
        QVERIFY(window->takeOneEvent(TestWindow::KeyUpEvent));

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

        TestWindow *qtwindow = TestWindow::createWindow();
        qtwindow->setForwardEvents(true);
        NSView *upper = QCocoaWindowFunctions::transferNativeView(qtwindow->qwindow());
        upper.frame = NSMakeRect(0, 0, 100, 100);
        [lower addSubview:upper];
        [upper release];

        [window makeFirstResponder:upper];
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
            QVERIFY(!qtwindow->takeOneEvent(TestWindow::MouseDownEvent));
            QVERIFY(!qtwindow->takeOneEvent(TestWindow::MouseUpEvent));
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
            QVERIFY(!qtwindow->takeOneEvent(TestWindow::KeyDownEvent));
            QVERIFY(!qtwindow->takeOneEvent(TestWindow::KeyUpEvent));
            QCOMPARE(lower.keyDownCount, 1);
            QCOMPARE(lower.keyUpCount, 1);
        }

        // Test Qt::WindowTransparentForInput windows
        qtwindow->setFlags(qtwindow->flags() | Qt::WindowTransparentForInput);
        qtwindow->setForwardEvents(false);

        {
            // Mouse events
            QPoint viewCenter = screenGeometry(upper).center();
            NativeEventList events;
            events.append(new QNativeMouseButtonEvent(viewCenter, Qt::LeftButton, 1, Qt::NoModifier));
            events.append(new QNativeMouseButtonEvent(viewCenter, Qt::LeftButton, 0, Qt::NoModifier));
            events.play();

                WAIT

            // Events go the lower view
            QVERIFY(!qtwindow->takeOneEvent(TestWindow::MouseDownEvent));
            QVERIFY(!qtwindow->takeOneEvent(TestWindow::MouseUpEvent));
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
            QVERIFY(!qtwindow->takeOneEvent(TestWindow::KeyDownEvent));
            QVERIFY(!qtwindow->takeOneEvent(TestWindow::KeyUpEvent));;
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
            QVERIFY(!qtwindow->takeOneEvent(TestWindow::MouseDownEvent));
            QVERIFY(!qtwindow->takeOneEvent(TestWindow::MouseUpEvent));
            QCOMPARE(lower.mouseDownCount, 2);
            QCOMPARE(lower.mouseUpCount, 2);
        }

        [window close];
        [window release];
        WAIT
    }
}

void tst_QCocoaWindow::drawRect_native_data()
{
    QTest::addColumn<bool>("useLayer");
    QTest::newRow("classic") << false;
    QTest::newRow("layer") << true;
}

// Test native expose behavior - the number of drawRect calls for visible and
// hidden views, on initial show and repeated shows.
void tst_QCocoaWindow::drawRect_native()
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

void tst_QCocoaWindow::drawRect_child_native_data()
{
    QTest::addColumn<bool>("wantsLayer");
    QTest::addColumn<bool>("isOpaque");
    QTest::newRow("classic/opaque") << false << true;
    QTest::newRow("classic/non-opaque") << false << false;
    QTest::newRow("layer/opaque") << true << true;
    QTest::newRow("layer/non-opaque") << true << false;
}

// Verify native drawRect behavior for a window with two stacked views - where the
// lower one is completely hidden. Check the number of drawRect calls on initial
// show and on calling setNeedsDisplay.
void tst_QCocoaWindow::drawRect_child_native()
{
    QFETCH(bool, wantsLayer);
    QFETCH(bool, isOpaque);

    LOOP {
        NSWindow *window = [[TestNSWidnow alloc] init];

        // Lower view which is completely covered
        TestNSView *lower = [[TestNSView alloc] init];
        lower.fillColor = ERROR_COLOR;
        lower.wantsLayer = wantsLayer;
        lower._isOpaque = isOpaque;
        window.contentView = lower;
        [lower release];

        // Upper view which is visble
        TestNSView *upper = [[TestNSView alloc] init];
        upper.frame = NSMakeRect(0, 0, 100, 100);
        upper.fillColor = OK_COLOR;
        upper.wantsLayer = wantsLayer;
        upper._isOpaque = isOpaque;
        [lower addSubview:upper];
        [upper release];

        // Depending on view configuration Cocoa may omit sending draw
        // calls to the obscured lower view on the initial expose. Specifically
        // this happens in non-layer mode when the upper view declares that it is
        // opaque, indicating fills its entire are with solid pixels. In
        // layer mode the views are independently cached and we get drawRect
        // calls for both.
        int expectedLowerDrawRectCount = (!wantsLayer && isOpaque) ? 0 : 1;

        // Inital show.
        [window makeKeyAndOrderFront:nil];
        WAIT
        QCOMPARE(upper.drawRectCount, 1);
        QCOMPARE(lower.drawRectCount, expectedLowerDrawRectCount);

        // Hide. Expect no additional drawRect calls.
        [window orderOut:nil];
        WAIT
        QCOMPARE(upper.drawRectCount, 1);
        QCOMPARE(lower.drawRectCount, expectedLowerDrawRectCount);

        // Show again. Expect no additional drawRect calls (due to caching)
        [window makeKeyAndOrderFront:nil];
        WAIT
        QCOMPARE(upper.drawRectCount, 1);
        QCOMPARE(lower.drawRectCount, expectedLowerDrawRectCount);

        // Invalidate the upper view and check draw calls both views.
        [upper setNeedsDisplay:YES];
        WAIT
        // Expect no drawRect call on the lower view in layer mode
        // due to layer independence. In classic mode Cocoa will composit
        // with (and call drawRect on) the lower view, unless isOpaque
        // is set on the upper view indicating it fills its entire area
        // with solid pixels.
        int expectedUpdateLowerDrawRectCount = (wantsLayer || isOpaque) ? 0 : 1;
        QCOMPARE(upper.drawRectCount, 2);
        QCOMPARE(lower.drawRectCount, expectedLowerDrawRectCount + expectedUpdateLowerDrawRectCount);

        [window close];
        [window release];
        WAIT
    }
}

void tst_QCocoaWindow::expose_data()
{
    QTest::addColumn<TestWindow::WindowConfiguration>("windowconfiguration");
    WINDOW_CONFIGS {
        QTest::newRow(TestWindow::windowConfigurationName(WINDOW_CONFIG).constData()) << WINDOW_CONFIG;
    }
}

// Test that a window gets expose (and paint) events on show, and obscure events on hide
void tst_QCocoaWindow::expose()
{
    QFETCH(TestWindow::WindowConfiguration, windowconfiguration);

    LOOP {
        TestWindow *window = TestWindow::createWindow(windowconfiguration);

        QVERIFY(!window->takeOneEvent(TestWindow::ExposeEvent));
        QVERIFY(!window->takeOneEvent(TestWindow::ObscureEvent));
        QVERIFY(!window->takeOneEvent(TestWindow::PaintEvent));

        // Show the window, expect one expose and one paint event.
        window->show();
        WAIT WAIT  WAIT WAIT

        QVERIFY(window->takeOneEvent(TestWindow::ExposeEvent));
        QVERIFY(!window->takeOneEvent(TestWindow::ObscureEvent));
        QVERIFY(window->takeOneEvent(TestWindow::PaintEvent));

        // Hide the window, expect one obscure evnet
        window->hide();
        WAIT
        QVERIFY(!window->takeOneEvent(TestWindow::ExposeEvent));
        QVERIFY(window->takeOneEvent(TestWindow::ObscureEvent));
        QVERIFY(!window->takeOneEvent(TestWindow::PaintEvent));

        // Request update on the hidden window: expect no expose or paint events.
        window->update(QRect(0, 0, 40, 40));
        QVERIFY(!window->takeOneEvent(TestWindow::ExposeEvent));
        QVERIFY(!window->takeOneEvent(TestWindow::PaintEvent));

        // Show the window, expect one expose event
        window->show();
        WAIT WAIT
        QVERIFY(window->takeOneEvent(TestWindow::ExposeEvent));
        QVERIFY(!window->takeOneEvent(TestWindow::ObscureEvent));

        if (TestWindow::isRasterWindow(windowconfiguration)) {
            // QRasterWindow may cache via QBackingStore, accept zero or one extra paint evnet
            QVERIFY(window->takeOneEvent(TestWindow::PaintEvent));
        } else {
            // Expect No caching for OpenGL. ### TODO: apparently not.
            QVERIFY(window->takeOneEvent(TestWindow::PaintEvent));
        }

        // Hide the window, expect +1 obscure event.
        window->hide();
        WAIT WAIT // ### close eats the obscure event.
        window->close();
        WAIT WAIT

        QVERIFY(window->takeOneEvent(TestWindow::ObscureEvent));

        delete window;
    } // LOOP
}

void tst_QCocoaWindow::expose_child_data()
{
    QTest::addColumn<TestWindow::WindowConfiguration>("windowconfiguration");
    WINDOW_CONFIGS {
        QTest::newRow(TestWindow::windowConfigurationName(WINDOW_CONFIG).constData()) << WINDOW_CONFIG;
    }
}


// Test that child windows gets expose (and paint) events on show, and obscure events on hide
void tst_QCocoaWindow::expose_child()
{
    QFETCH(TestWindow::WindowConfiguration, windowconfiguration);
    LOOP {
        QSize windowSize(100, 100);

        TestWindow *parent = TestWindow::createWindow(windowconfiguration);
        parent->setFillColor(toQColor(FILLER_COLOR));
        parent->setGeometry(QRect(QPoint(20, 20), windowSize));

        TestWindow *child = TestWindow::createWindow(windowconfiguration);
        child->setParent(parent);
        child->setFillColor(toQColor(OK_COLOR));
        child->setGeometry(QRect(QPoint(0, 0), windowSize));

        // QExposeEvent should be sent at window show/hide for all windows. QExposeEvent
        // also mandates a repaint (when becoming visible). This means that QWindow always
        // gets a repaint on show. This is unlike native behavior where the repaint may
        // be omitted if there is cached content.
        child->show();
        parent->show();
        WAIT
        QVERIFY(parent->takeOneEvent(TestWindow::ExposeEvent));
        QVERIFY(parent->takeOneEvent(TestWindow::PaintEvent));
        QVERIFY(child->takeOneEvent(TestWindow::ExposeEvent));
        QVERIFY(child->takeOneEvent(TestWindow::PaintEvent));

        // Hide and test for obscure events
        parent->hide();
        WAIT
        QVERIFY(parent->takeOneEvent(TestWindow::ObscureEvent));
        QVERIFY(child->takeOneEvent(TestWindow::ObscureEvent));

        // Re-show and test for expose/paint
        parent->show();
        WAIT
        QVERIFY(parent->takeOneEvent(TestWindow::ExposeEvent));
        QVERIFY(parent->takeOneEvent(TestWindow::PaintEvent));
//    ### TODO
//        QVERIFY(child->takeOneEvent(TestWindow::ExposeEvent));
//        QVERIFY(child->takeOneEvent(TestWindow::PaintEvent));

        delete parent;
        WAIT
    }
}

void tst_QCocoaWindow::expose_resize_data()
{
    QTest::addColumn<TestWindow::WindowConfiguration>("windowconfiguration");
    WINDOW_CONFIGS {
        QTest::newRow(TestWindow::windowConfigurationName(WINDOW_CONFIG).constData()) << WINDOW_CONFIG;
    }
}

// Verify that there is one expose + paint event on window resize.
void tst_QCocoaWindow::expose_resize()
{
    QFETCH(TestWindow::WindowConfiguration, windowconfiguration);

     LOOP {
        // Create test window with initial geometry
        TestWindow *window = TestWindow::createWindow(windowconfiguration);
        QRect geometry(100, 100, 100, 100);
        window->setGeometry(geometry);
        window->show();
        WAIT WAIT WAIT // wait-for-painted

        // Resize using QWindow API
        {
            window->resetCounters();
            QRect geometry(100, 100, 150, 150);
            window->setGeometry(geometry);
            WAIT
            QVERIFY(window->takeOneEvent(TestWindow::ExposeEvent));
            QVERIFY(window->takeOneEvent(TestWindow::PaintEvent));
        }

        // Resize using NSWindow API
        {
            window->resetCounters();
            NSWindow *nswindow = getNSWindow(window);
            QRect geometry(100, 100, 200, 200);
            NSRect frame = nswindowFrameGeometry(geometry, nswindow);
            [nswindow setFrame:frame display:NO animate:NO];
            WAIT
            QVERIFY(window->takeOneEvent(TestWindow::ExposeEvent));
            QVERIFY(window->takeOneEvent(TestWindow::PaintEvent));
        }

        // Resize using NSWindow API, with immediate display.
        {
            window->resetCounters();
            NSWindow *nswindow = getNSWindow(window);
            QRect geometry(100, 100, 250, 250);
            NSRect frame = nswindowFrameGeometry(geometry, nswindow);
            [nswindow setFrame:frame display:YES animate:NO];
            // WAIT not needed due to immediate display.
            WAIT // ### Event loop sping actually needed on 10.12 Beta
            QVERIFY(window->takeOneEvent(TestWindow::ExposeEvent));
            QVERIFY(window->takeOneEvent(TestWindow::PaintEvent));
        }

        // Resize using NSWindow API, with immediate display and animation
        {
            window->resetCounters();
            NSWindow *nswindow = getNSWindow(window);
            QRect geometry(100, 100, 200, 200);
            NSRect frame = nswindowFrameGeometry(geometry, nswindow);
            [nswindow setFrame:frame display:YES animate:YES];
            // WAIT not needed due to immediate display.

            // There may be many expose/paint events due to the animation,
            // but the exact number is outside of Qt control, so this test
            // accepts any number.
            QVERIFY(window->takeOneOrManyEvents(TestWindow::ExposeEvent));
            QVERIFY(window->takeOneOrManyEvents(TestWindow::PaintEvent));
        }

        delete window;
        WAIT
    }
}

void tst_QCocoaWindow::requestUpdate_data()
{
    QTest::addColumn<TestWindow::WindowConfiguration>("windowconfiguration");
    WINDOW_CONFIGS {
        QTest::newRow(TestWindow::windowConfigurationName(WINDOW_CONFIG).constData()) << WINDOW_CONFIG;
    }
}

// Verify that calls to QWindow::requestUpdate() trigger paint events.
void tst_QCocoaWindow::requestUpdate()
{
    QFETCH(TestWindow::WindowConfiguration, windowconfiguration);
    LOOP {
        // Create test window
        TestWindow *window = TestWindow::createWindow(windowconfiguration);
        QRect geometry(100, 100, 100, 100);
        window->setGeometry(geometry);
        window->show();
        WAIT

        // Run repeated requestUpdate -> paintEvent tests.
        for (int i = 0; i < 5; ++i) {
            window->resetCounters();
            window->requestUpdate();
            WAIT
            QVERIFY(window->takeOneOrManyEvents(TestWindow::PaintEvent));
            // TODO: Be stricter and expect one paint event only?
        }

        delete window;
        WAIT
    }
}

void tst_QCocoaWindow::repaint_native_data()
{
    QTest::addColumn<bool>("useLayer");
    QTest::newRow("classic") << false;
    QTest::newRow("layer") << true;
}

// Verify native displayIfNeeded behavior where we expect that
// displayIfNeeded delivers a drawRect call before it returns.
void tst_QCocoaWindow::repaint_native()
{
    QFETCH(bool, useLayer);

    LOOP {
        // Test a window with a content view.
        NSWindow *window = [[TestNSWidnow alloc] init];
        TestNSView *view = [[TestNSView alloc] init];
        view.wantsLayer = useLayer;
        window.contentView = view;
        [view release];
        [window makeKeyAndOrderFront:nil];
        WAIT
        view.drawRectCount = 0;

        // Calling displayIfNeeded does not repaint
        [view displayIfNeeded];
        QCOMPARE(view.drawRectCount, 0);

        // Calling setNeedsDisplay + displayIfNeeded does repaint
        [view setNeedsDisplay:YES];
        [view displayIfNeeded];
        QCOMPARE(view.drawRectCount, 1);

        // Calling displayIfNeeded again does not repaint
        [view displayIfNeeded];
        QCOMPARE(view.drawRectCount, 1);

        // Calling display unconditionally repaints.
        [view display];
        QCOMPARE(view.drawRectCount, 2);
    }
}

void tst_QCocoaWindow::repaint_data()
{
    QTest::addColumn<TestWindow::WindowConfiguration>("windowconfiguration");
    RASTER_WINDOW_CONFIGS {
        QTest::newRow(TestWindow::windowConfigurationName(WINDOW_CONFIG).constData()) << WINDOW_CONFIG;
    }
}

// Verify that calling repaint/QBackingStore::flush syncrhonously repaints and
// flushes the new content to the window.
void tst_QCocoaWindow::repaint()
{
    QFETCH(TestWindow::WindowConfiguration, windowconfiguration);

    TestWindow *window = TestWindow::createWindow(windowconfiguration);
    QPoint windowPoint(20, 20);
    QSize windowSize(200, 200);
    QRect geometry(windowPoint, windowSize);
    window->setFillColor(toQColor(OK_COLOR));
    window->setGeometry(geometry);
    window->show();
    WAIT WAIT
    window->resetCounters();

    // Repaint should trigger one immediate paint event
    window->repaint();
    QVERIFY(window->takeOneEvent(TestWindow::PaintEvent));

    // For comparison, update does not paint until we spin the event loop
    window->update(geometry);
    QVERIFY(!window->takeOneEvent(TestWindow::PaintEvent));
    WAIT
    QVERIFY(window->takeOneOrManyEvents(TestWindow::PaintEvent));
    // TODO: Be stricter and expect one paint event only?

    // Verify that the updated contents are actually flushed to the window/display
    QRect testGeometry(QPoint(0, 0), windowSize);
    QVERIFY(verifyImage(grabWindow(window), testGeometry, toQColor(OK_COLOR)));
    window->setFillColor(toQColor(FILLER_COLOR));
    window->repaint();
    QVERIFY(verifyImage(grabWindow(window), testGeometry, toQColor(FILLER_COLOR)));

    delete window;
    WAIT
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
    QTest::addColumn<TestWindow::WindowConfiguration>("windowconfiguration");
#if 0
    // (### raster_layer is broken)
    RASTER_WINDOW_CONFIGS {
        QTest::newRow(TestWindow::windowConfigurationName(WINDOW_CONFIG).constData()) << WINDOW_CONFIG;
    }
#else
        QTest::newRow(TestWindow::windowConfigurationName(TestWindow::RasterClassic).constData()) << TestWindow::RasterClassic;
#endif
}

// Test that windows are correctly repainted on show(), update(), and repaint()
void tst_QCocoaWindow::paint_coverage()
{
    QFETCH(TestWindow::WindowConfiguration, windowconfiguration);

    LOOP {
        // Show window with solid color
        TestWindow *window = TestWindow::createWindow(windowconfiguration);
        QRect geometry(20, 20, 200, 200);
        window->setFillColor(toQColor(FILLER_COLOR));
        window->setGeometry(geometry);
        window->show();
        WAIT WAIT

        // Verify that the pixels on screen match
        QRect imageGeometry(QPoint(0, 0), geometry.size());
        QVERIFY(verifyImage(grabWindow(window), imageGeometry, toQColor(FILLER_COLOR)));

        // Fill subrect with new color
        window->setFillColor(toQColor(OK_COLOR));
        QRect updateRect(50, 50, 50, 50);
        window->update(updateRect);
        WAIT WAIT

        // Verify that the window was partially repainted
        QVERIFY(verifyImage(grabWindow(window), updateRect, toQColor(OK_COLOR)));
        QRect notUpdated(110, 110, 50, 50);
        QVERIFY(verifyImage(grabWindow(window), notUpdated, toQColor(FILLER_COLOR)));

#ifdef HAVE_QPAINTDEVICEWINDOW_REPAINT
        // Call repaint() and verify that the window has been repainted on return.
        window->repaint();
        QVERIFY(verifyImage(grabWindow(window), imageGeometry, toQColor(OK_COLOR)));
#endif
        delete window;
        WAIT
    }
}

void tst_QCocoaWindow::paint_coverage_childwindow_data()
{
    QTest::addColumn<TestWindow::WindowConfiguration>("windowconfiguration");
    WINDOW_CONFIGS {
        QTest::newRow(TestWindow::windowConfigurationName(WINDOW_CONFIG).constData()) << WINDOW_CONFIG;
    }
}

void tst_QCocoaWindow::paint_coverage_childwindow()
{
    QFETCH(TestWindow::WindowConfiguration, windowconfiguration);

    QSize windowSize(150, 150);

    // Crate parent/child window configuration where the
    // child to completely covers the parent
    TestWindow *parent = TestWindow::createWindow(windowconfiguration);
    parent->setFillColor(toQColor(ERROR_COLOR));
    parent->setGeometry(QRect(QPoint(20, 20), windowSize));

    TestWindow *child = TestWindow::createWindow(windowconfiguration);
    child->setParent(parent);
    child->setFillColor(toQColor(OK_COLOR));
    child->setGeometry(QRect(QPoint(0, 0), windowSize));

    // Note on show() call ordering: Show child first to ensure no flicker -
    // this show() will be a no-op since the parent is hidden. However, in
    // opengl_classic mode this causes parent window content to be
    // painted over child window content.
    if (windowconfiguration == TestWindow::OpenGLClassic)
        QSKIP("incorrect parent/child QWindow paint order");

    child->show();
    parent->show();
    WAIT

    // Grab parent window/screen contents at parent geometry. Content grabbing
    // happens at the NSWindow level, of which there is one for all tested
    // QWindow configurations.
    QVERIFY(verifyImage(grabWindow(parent), toQColor(OK_COLOR)));
    QVERIFY(verifyImage(grabScreen(parent), toQColor(OK_COLOR)));
}

QTEST_MAIN(tst_QCocoaWindow)
#include <tst_qcocoawindow.moc>
