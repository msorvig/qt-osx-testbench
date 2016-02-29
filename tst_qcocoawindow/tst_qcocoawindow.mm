
#include <QtTest/QTest>

#include <cocoaspy.h>

int iterations = 5;
int delay = 25;
#define WAIT QTest::qWait(delay);
#define LOOP for (int i = 0; i < iterations; ++i)

void waitForWindowVisible(QWindow *window)
{
    // use qWaitForWindowExposed for now.
    QTest::qWaitForWindowExposed(window);
    WAIT
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

    class TestWindow : public QWindow
    {
    public:
        TestWindow() {
            ++detail::instanceCount;
        }
        ~TestWindow() {
            --detail::instanceCount;
        }
    };

    void reset() {
        detail::instanceCount = 0;
    }

    int windowCount() {
        return detail::instanceCount;
    }
}

/*!
    \class tst_QCocoaWindow

    Test
*/
class tst_QCocoaWindow : public QObject
{
    Q_OBJECT
public:
    tst_QCocoaWindow();
private slots:
    void nativeViewsAndWindows();
    void construction();
    void embed();
};

tst_QCocoaWindow::tst_QCocoaWindow()
{
    QCocoaSpy::init();
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
{

}
- (void) dealloc;
@end

@implementation TestNSView
- (void)dealloc
{
//    qDebug() << "dealloc view";
    [super dealloc];
}
@end


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

            // Setup window-with-view: Not that this is under the atuorelease pool
            // as well: if not then the window.contentView assignment leaks a TestNSView.
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
    QCocoaSpy::reset(@"QNSWindow", @"QNSView");
    TestWindowSpy::reset();

    @autoreleasepool {

        // The Cocoa platform plugin implements a backend for the QWindow
        // class. Here we use a TestWindow subclass which tracks instances
        // and events.
        QWindow *window = new TestWindowSpy::TestWindow();
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
        qDebug() << "delete";
        delete window;
        qDebug() << "delete DONE";
        //QCocoaSpy::waitForNoVisibleWindows();

        WAIT
        qDebug() << "wait DONE";
    }

    QCOMPARE(TestWindowSpy::windowCount(), 0);
    // QCOMPARE(QCocoaSpy::visbileWindows, 0);
    QCOMPARE(QCocoaSpy::windowCount(), 0);
    QCOMPARE(QCocoaSpy::viewCount(), 0);
}

void tst_QCocoaWindow::embed()
{
    QCocoaSpy::reset();
    TestWindowSpy::reset();

    QPointer<QWindow> window;

    @autoreleasepool {

        window = new TestWindowSpy::TestWindow();

        // It is possible to extract the native view for a QWindow and embed
        // that view somewhere in a native NSWidnow/NSView hiearchy.
        NSView *view = getEmbeddableView(window);
        QVERIFY(view != 0);

        // Extracting the native view transfers ownership of the QWindow instance
        // to the NSView instance. This creates a QCococaWindow instance and a
        // native NSView, but does not create a QNSWindow.
        QVERIFY(!window.isNull()); // valid for now
        QCOMPARE(TestWindowSpy::windowCount(), 1);
        QCOMPARE(QCocoaSpy::viewCount(), 1);
        QCOMPARE(QCocoaSpy::windowCount(), 0);

        // Releasing the NSView deletes the QWindow;
        [view release];
    }

    QCOMPARE(QCocoaSpy::viewCount(), 0);
    QCOMPARE(TestWindowSpy::windowCount(), 0);
    QVERIFY(window.isNull());
}

void tst_QCocoaWindow::nativeEvents()
{


}


QTEST_MAIN(tst_QCocoaWindow)
#include <tst_qcocoawindow.moc>

#if 0




// Utilites
QString className(NSObject *object)
{
    return QString::fromNSString(NSStringFromClass([object class]));
}

void waitForWindowVisible(QWindow *window)
{

}

class TestWindow : public QWindow
{

}

namespace TestWindowSpy
{
    int windowCount();
}



void geometry()
{
    // Qt geometry origin is top-left
    //
}

#endif
