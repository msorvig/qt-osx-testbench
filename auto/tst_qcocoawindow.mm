
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

void construction()
{
    CococaSpy::reset();
    TestWindowSpy::reset();

    // The Cocoa platform plugin implements a backend for the QWindow
    // class. Here we use a TestWindow subclass which tracks instances
    // and events.
    QWindow *window = new TestWindow();
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
    QCOMPARE(CococaSpy::visbileWindows, 1);

    // A visible QWindow has two native instances: a NSView and a NSWindow.
    // The NSView is the main backing instance for a QCocoaWindow. A NSWindow
    // is also needed to get a top-level window with a title bar etc.
    QCOMPARE(CococaSpy::viewCount(), 1);
    QCOMPARE(CococaSpy::windowCount(), 1);

    // These instacces are actually of the Qt QNSView and QNSWindow subclasses
    QCOMPARE(CococaSpy::className(CococaSpy::lastCreatedView()), QStringLiteral("QNSView"));
    QCOMPARE(CococaSpy::className(CococaSpy::lastCreatedWindow()), QStringLiteral("QNSWindow"));

    // deleting the QWindow instance hides and deletes the native views and windows
    delete window;
    CococaSpy::waitForNoVisibleWindows();

    QCOMPARE(TestWindowSpy::windowCount(), 0);
    QCOMPARE(CococaSpy::visbileWindows, 0);
    QCOMPARE(CococaSpy::viewCount(), 0);
    QCOMPARE(CococaSpy::windowCount(), 0);
}


void embed()
{
    CococaSpy::reset();
    TestWindowSpy::reset();

    // It is possible to extract the native view for a QWindow and embed
    // that view somewhere in a native NSWidnow/NSView hiearchy.
    QPointer<QWindow> window = new TestWindow();

    // Extracting the native view transfers ownership of the QWindow instance
    // to the NSView instance. This creates a QCococaWindow instance and a
    // native NSView, but does not create a NSWindow.
    NSView *view = getEmbeddableView(window);

    QCOMPARE(TestWindowSpy::windowCount(), 1);
    QCOMPARE(CococaSpy::viewCount(), 1);
    QCOMPARE(CococaSpy::windowCount(), 0);
    
    // Releasing the NSView deletes the QWindow;
    [view release];
    QCOMPARE(CococaSpy::viewCount(), 0);
    QCOMPARE(TestWindowSpy::windowCount(), 0);
    QVERIFY(window.isNull());
}    

void geometry()
{
    // Qt geometry origin is top-left
    // 
}
