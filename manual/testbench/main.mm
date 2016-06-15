/****************************************************************************
**
** Copyright (C) 2015 The Qt Company Ltd.
** Contact: http://www.qt.io/licensing/
**
** This file is part of the test suite of the Qt Toolkit.
**
** $QT_BEGIN_LICENSE:LGPL21$
** Commercial License Usage
** Licensees holding valid commercial Qt licenses may use this file in
** accordance with the commercial license agreement provided with the
** Software or, alternatively, in accordance with the terms contained in
** a written agreement between you and The Qt Company. For licensing terms
** and conditions see http://www.qt.io/terms-conditions. For further
** information use the contact form at http://www.qt.io/contact-us.
**
** GNU Lesser General Public License Usage
** Alternatively, this file may be used under the terms of the GNU Lesser
** General Public License version 2.1 or version 3 as published by the Free
** Software Foundation and appearing in the file LICENSE.LGPLv21 and
** LICENSE.LGPLv3 included in the packaging of this file. Please review the
** following information to ensure the GNU Lesser General Public License
** requirements will be met: https://www.gnu.org/licenses/lgpl.html and
** http://www.gnu.org/licenses/old-licenses/lgpl-2.1.html.
**
** As a special exception, The Qt Company gives you certain additional
** rights. These rights are described in The Qt Company LGPL Exception
** version 1.1, included in the file LGPL_EXCEPTION.txt in this package.
**
** $QT_END_LICENSE$
**
****************************************************************************/

#include "rasterwindow.h"
#include "openglwindow.h"
#include "widgetwindow.h"
#include "openglwindowresize.h"
#include "nativecocoaview.h"
#include "qtcontent.h"
#include "cocoaspy.h"

#include <QtGui>
#include <QtWidgets>
#include <QtQuick>
#include <QQuickWidget>

#import <Cocoa/Cocoa.h>

#include <qpa/qplatformnativeinterface.h>
#include <QtPlatformHeaders/QCocoaWindowFunctions>

//
// Global Options. These can be tweaked to run the examples/test in different configurations
//

QSet<int> g_activeTestCases = { 0 }; // The currently active test cases (indices)
int g_testViewCount = 1; // The number of test views to display
bool g_animate = true; // animations enabled

// QWindow configuration. This is a fuzzy concept (especially for the native view
// test cases where there is no QWindow). The point is to test the setups a QNSView
// may find itself in.
enum QWindowConfiguration
{
    TopLevelWindowsAreQNSViews,             // Embed QWindows in NSViews
    TopLevelWindowsAreTopLevelNSWindows,    // Embed QWindows in top-level NSWindows
    TopLevelWindowsAreChildNSWindows,       // Embed QWindows in child NSWindows
    StandardQWindowShow,                    // Normal QWindow::show() use case
};
QWindowConfiguration g_windowConfiguration = TopLevelWindowsAreQNSViews;

bool g_useContainingLayers = true; // use layers for the containing native views --
                                   // the content and controller views). Since these
                                   // are parent views of the test views the test views
                                   // will be switched to layer mode as well.

bool g_useQWindowLayers = false; // enable layer mode for QWindows.

// Native View animation drivers (mutally exclusive, select one)
bool g_useNativeAnimationTimer = false; // animate using a timer
bool g_useNativeAnimationSetNeedsDisplay = false; // animate by calling setNeedsDisplay.
bool g_useNativeAnimationDisplaylink = true; // animate using CVDisplayLink

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    QGuiApplication *m_app;
    QWindow *m_qtquickWindow;

    NSWindow *m_topLevelWindow; // _the_ toplevel window (if there is a main one)
    QList<NSWindow *> m_topLevelNSWindows; // top-level windows for TopLevelWindowsAreNSWindows
    QList<QWindow *> m_topLevelQWindows; // top-level QWindows for StandardQWindowShow
    QList<QWidget *> m_topLevelWidgets;

    QPoint m_childCascadePoint;
}
- (AppDelegate *) initWithArgc:(int)argc argv:(const char **)argv;
- (void) recreateTestWindow;
- (void) applicationWillFinishLaunching: (NSNotification *)notification;
- (void)applicationWillTerminate:(NSNotification *)notification;
@end

AppDelegate *g_appDelegate = 0;
NSTextField *g_statusText = 0;
NSTextField *g_nativeInstanceStatus = 0;



// A NSTextField which notifies on changes via a callback
@interface NotifyingIntField : NSTextField<NSTextFieldDelegate>
{
    void (^changeCallback)(int);
}
- (void) setCallback:(void (^)(int))changed;
@end

@implementation NotifyingIntField
- (id)init
{
    NSRect frame = NSMakeRect(0, 0, 200, 25);
    [super initWithFrame:frame];
    [self setDelegate:self];
    return self;
}

- (void) setCallback:(void (^)(int))changed
{
    changeCallback = changed;
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    NSTextField *textField = [notification object];
    int newValue = [textField intValue];

    if (newValue > 0) // we get 0 on parse error: ignore
        changeCallback(newValue);
}

@end

@interface TestBenchControllerView : NSStackView
{

}
@end

@implementation TestBenchControllerView

- (id) init
{
    [super init];
    self.orientation = NSUserInterfaceLayoutOrientationVertical;
    return self;
}

- (void)updateTestCases:(id)sender {
    NSButton *selCell = sender;
    int index  = int([selCell tag]);
    bool enable = bool([selCell intValue]);

    if (enable)
        g_activeTestCases.insert(index);
    else
        g_activeTestCases.remove(index);

    [g_appDelegate recreateTestWindow];
}

- (void)changeWindowConfiguration:(id)sender {
    NSButtonCell *selCell = [sender selectedCell];
    g_windowConfiguration = QWindowConfiguration(int([selCell tag]));
    [g_appDelegate recreateTestWindow];
}

- (void)changeContainingLayers:(id)sender {
    g_useContainingLayers = ([sender state] == NSOnState);
    [g_appDelegate recreateTestWindow];
}

- (void)changeQWindowLayers:(id)sender {
    g_useQWindowLayers = ([sender state] == NSOnState);
    [g_appDelegate recreateTestWindow];
}

- (void)changeAnimate:(id)sender {
    g_animate = ([sender state] == NSOnState);
    // Don't [g_appDelegate recreateTestWindow]. Test cases read g_animate continuously.
}

- (void)changeInstanceCount:(int)newInstanceCount {
    g_testViewCount = newInstanceCount;
   [g_appDelegate recreateTestWindow];
}

- (NSTextField *) addLabel: (NSString *)text
{
    NSTextField *label = [[NSTextField alloc] init];
    [label setStringValue:text];
    [label setEditable:NO];
    [self addControl: label];
    return label;
}

- (void) addRadioButtonGroup: (QStringList)texts withActionTarget: (SEL)onSelected
{
    NSButtonCell *prototype = [[NSButtonCell alloc] init];
    [prototype setTitle:@"Placeholder-string-with-sufficent-length-for-all-options"];
    [prototype setButtonType:NSRadioButton];

    NSRect matrixRect = NSMakeRect(20.0, 20.0, 125.0, 125.0);
    NSMatrix *myMatrix = [[NSMatrix alloc] initWithFrame:matrixRect
                                                    mode:NSRadioModeMatrix
                                               prototype:(NSCell *)prototype
                                             numberOfRows:texts.count()
                                          numberOfColumns:1];
    NSArray *cellArray = [myMatrix cells];

    for (int i = 0; i < texts.count(); ++i) {
        [[cellArray objectAtIndex:i] setTitle:texts.at(i).toNSString()];
        [[cellArray objectAtIndex:i] setTag:i];
    }

    [myMatrix setAction:onSelected];
    [myMatrix setTarget:self];

    [prototype release];
    [self addControl:myMatrix];
    [myMatrix release];
}

- (void) addCheckBoxGroup: (QStringList)texts withActionTarget: (SEL)onSelected
{
    // Add check boxes for all texts, with onSelected as the action
    // and self as the target.
    for (int i = 0; i < texts.count(); ++i) {
        QString text = texts.at(i);
        NSButton *button = [[NSButton alloc] init];
        button.title = text.toNSString();
        button.buttonType = NSSwitchButton;
        button.tag = i;
        button.action = onSelected;
        button.target = self;
        [self addControl:button];

        // First button gets selected by default
        if (i == 0)
            button.intValue = 1;
    }

    return;
}

// Add a check box with text, target, and inital state
- (void) addCheckBox: (NSString *)text withActionTarget: (SEL)onToggled state: (NSCellStateValue)initialState
{
    NSRect frame = NSMakeRect(0, 0, 200, 25);
    NSButton *button = [[NSButton alloc] initWithFrame:frame];
    [button setButtonType:NSSwitchButton];
    [button setTitle:text];
    [button setState:initialState];
    [button setAction:onToggled];
    [button setTarget:self];

    [self addControl:button];
}

TestBenchControllerView *theControllerViewHack = 0; // There is only one, so OK.

- (void) addNumberInput:(NSString *)text withActionTarget:(SEL)onChanged
{
    NotifyingIntField *textField = [[NotifyingIntField alloc] init];
    [textField setStringValue:text];

    theControllerViewHack = self; // ### why does use of captured self crash?

    [textField setCallback:^void(int newValue) {
        [theControllerViewHack changeInstanceCount:newValue];
    }];

    [self addControl:textField];
}

- (void) createControllerViewContent
{
    [self addLabel:@"Test Case Selection"];
    QStringList testCases =
        QStringList() << "Native NSOpenGLView"
                      << "Native NSView + NSOpenGLContext"
                      << "Native OpenGLLayer"
                      << "Native RasterLayer"
                      << "Native 120fps view"
                      << "Qt OpenGLWindow"
                      << "Qt RasterWindow"
                      << "Qt Widgets"
                      << "Qt Masked Window"
                      << "Qt QtQuickWindow"
                      << "Qt QOpenGLWidget"
                      << "Qt QtQuickWidget";

    [self addCheckBoxGroup:testCases
             withActionTarget:@selector(updateTestCases:)];

    [self addLabel:@"QWindow Configuration"];
    QStringList windowConfigurations = // (in QWindowConfiguration order)
        QStringList() << "Child QNSViews"
                      << "Top-level NSWindows"
                      << "Child NSWindows"
                      << "Top-level QNSWindows (Standard Qt config)";
    [self addRadioButtonGroup:windowConfigurations
             withActionTarget:@selector(changeWindowConfiguration:)];

    [self addLabel:@"Options"];
    [self addCheckBox:@"Use layers for container views"
     withActionTarget:@selector(changeContainingLayers:)
                state:NSOnState];
    [self addCheckBox:@"Use layers for QWindows"
     withActionTarget:@selector(changeQWindowLayers:)
                state:NSOffState];
    [self addCheckBox:@"Animate"
     withActionTarget:@selector(changeAnimate:)
                 state:NSOnState];
    [self addLabel:@"Instance Count"];
    [self addNumberInput:@"1"
        withActionTarget:@selector(changeInstanceCount:)];

    // status label (store global for later modification)
    g_statusText = [self addLabel:@"Status: OK"];

    QString nativeInstanceStatius = "NSWindow Count:"; // will be completed later
    g_nativeInstanceStatus = [self addLabel:nativeInstanceStatius.toNSString()];

}

- (void)addControl: (NSView *) control
{
    control.translatesAutoresizingMaskIntoConstraints = false; // un-break my NSStackView
    [self addView:control inGravity:NSStackViewGravityTop];
}

- (void)drawRect: (NSRect)dirtyRect
{
    [[NSColor colorWithDeviceRed:0.7 green:0.7 blue:0.7 alpha:1.0] setFill];
    NSRectFill(dirtyRect);
    [super drawRect:dirtyRect];
}

@end

// creates and shows a window for run-time configuration of test bench options
void createControllerWindow()
{
    NSRect frame = NSMakeRect(40, 40, 300, 800);
    NSWindow *window =
        [[NSWindow alloc] initWithContentRect:frame
                                     styleMask:NSTitledWindowMask | NSClosableWindowMask |
                                               NSMiniaturizableWindowMask | NSResizableWindowMask
                                       backing:NSBackingStoreBuffered
                                         defer:NO];

    [window setTitle:@"Test Bench Controller"];
    [window setBackgroundColor:[NSColor blueColor]];

    TestBenchControllerView *view = [[TestBenchControllerView alloc] init];
    [view createControllerViewContent];
    window.contentView = view;
    [window makeKeyAndOrderFront:nil];
}


inline QPlatformNativeInterface::NativeResourceForIntegrationFunction resolvePlatformFunction(const QByteArray &functionName)
{
    QPlatformNativeInterface *nativeInterface = QGuiApplication::platformNativeInterface();
    QPlatformNativeInterface::NativeResourceForIntegrationFunction function =
        nativeInterface->nativeResourceFunctionForIntegration(functionName);
    if (!function)
         qWarning() << "Qt could not resolve function" << functionName
                    << "from QGuiApplication::platformNativeInterface()->nativeResourceFunctionForIntegration()";
    return function;
}

@implementation AppDelegate
- (AppDelegate *) initWithArgc:(int)argc argv:(const char **)argv
{
    m_app = new QApplication(argc, const_cast<char **>(argv));
    m_topLevelWindow = 0;

    g_appDelegate = self;

    return self;
}

- (void) addChildView: (NSView *) view
{
    // handle cases that embeds each view in its own NSWindow
    if (g_windowConfiguration == TopLevelWindowsAreTopLevelNSWindows ||
        g_windowConfiguration == TopLevelWindowsAreChildNSWindows) {
        NSRect frame = NSMakeRect(0, 0, 200, 100);
        NSWindow *window =
            [[NSWindow alloc] initWithContentRect:frame
                                         styleMask:NSTitledWindowMask | NSClosableWindowMask |
                                                   NSMiniaturizableWindowMask | NSResizableWindowMask
                                           backing:NSBackingStoreBuffered
                                             defer:NO];
        [window setContentView:view];

        if (g_windowConfiguration == TopLevelWindowsAreTopLevelNSWindows) {
            [window makeKeyAndOrderFront:nil];
            m_topLevelNSWindows.append(window);
        } else { // TopLevelWindowsAreChildNSWindows
            [m_topLevelWindow addChildWindow:window ordered:NSWindowAbove];
        }
    } else {
        // Add controller view for child view
        NSView *controllerView = [[TestBenchMDIView alloc] initWithView: view];
        [view release];
        m_childCascadePoint += QPoint(50, 50);
        [controllerView setFrame : NSMakeRect(m_childCascadePoint.x(), m_childCascadePoint.y(), 300, 300)];
        [[m_topLevelWindow contentView] addSubview : controllerView];
    }
}

#ifndef HAVE_TRANSFER_NATIVE_VIEW

NSView *getEmbeddableView(QWindow *qtWindow)
{
    // Make sure the platform window is created
    qtWindow->create();

    // Inform the window that it's a subwindow of a non-Qt window. This must be
    // done after create() because we need to have a QPlatformWindow instance.
    // The corresponding NSWindow will not be shown and can be deleted later.
    typedef void (*SetEmbeddedInForeignViewFunction)(QPlatformWindow *window, bool embedded);
    reinterpret_cast<SetEmbeddedInForeignViewFunction>(resolvePlatformFunction("setEmbeddedInForeignView"))(qtWindow->handle(), true);

    // Get the Qt content NSView for the QWindow from the Qt platform plugin
    QPlatformNativeInterface *platformNativeInterface = QGuiApplication::platformNativeInterface();
    NSView *qtView = (NSView *)platformNativeInterface->nativeResourceForWindow("nsview", qtWindow);
    return qtView; // qtView is ready for use.
}

#endif

- (void) addChildWindow: (QWindow *) window
{
    if (g_useQWindowLayers)
        window->setProperty("_q_mac_wantsLayer", true);

    if (g_windowConfiguration == StandardQWindowShow) {
        m_topLevelQWindows.append(window);
        window->show();
        return;
    }

#ifdef HAVE_TRANSFER_NATIVE_VIEW
    NSView *view = QCocoaWindowFunctions::transferNativeView(window);
#else
    NSView *view = getEmbeddableView(window);
#endif
    [self addChildView: view];
    window->show(); // ### fixme
}

- (void) addChildWidget: (QWidget *) widget
{
    if (g_useQWindowLayers)
        widget->setProperty("_q_mac_wantsLayer", true);

    if (g_windowConfiguration == StandardQWindowShow) {
        m_topLevelWidgets.append(widget);
        widget->show();
        return;
    }
    widget->winId(); // create, ### fixme
    [self addChildWindow: widget->windowHandle()];
    widget->show(); // ### fixme
}

// test showing several animated OpenGL views
- (void) nativeNSOpenGLView
{
    for (int i = 0; i < g_testViewCount; ++i)
        [self addChildView: [[AnimatedOpenGLVew alloc] init]];
}

// test showing a NSview with an attached OpenGL context.
- (void) nativeOpenGLNSView
{
    // status: flickers when there are layers present. (set g_useContainingLayers
    // to false above to disable). This is proably expected since we want to
    // draw using the layer's context. NSOpenGLView handles this transition
    // transparently to the user.
    //

    for (int i = 0; i < g_testViewCount; ++i)
        [self addChildView: [[OpenGLNSView alloc] init]];
}

// test showing a NSView with a custom NSOpenGLLayer layer
- (void) nativeOpenGLLayer
{
    for (int i = 0; i < g_testViewCount; ++i)
        [self addChildView: [[OpenGLLayerView alloc] init]];
}

// test showing a NSView with raster layer content
- (void) nativeRasterLayer
{
    for (int i = 0; i < g_testViewCount; ++i)
        [self addChildView: [[RasterLayerView alloc] init]];
}

// test showing a NSView animating on a 120 fps timer
- (void) native120fpsView
{
    // Findings:
    //  - Works (surprisingly) well for a single view
    //  - With 2 or 3 views we are starting to see blocking in displayIfNeeded.
    //    Updating the view geometry is sluggish.
    //  - Enabling layer mode has similar blocking. However, the visual output
    //    is better with smoother resizing.
    //
    for (int i = 0; i < g_testViewCount; ++i)
        [self addChildView: [[Native120fpsView alloc] init]];
}

// test QOpenGLWindow.
- (void) qtOpenGLWindow
{
    for (int i = 0; i < g_testViewCount; ++i)
        [self addChildWindow: new OpenGLWindow()];
}

// test RasterWindow
- (void) qtRasterWindow
{
    for (int i = 0; i < g_testViewCount; ++i)
        [self addChildWindow: new RasterWindow()];
}

// test QtWidgets
- (void) qtWidget
{
    for (int i = 0; i < g_testViewCount; ++i) {
        QWidget *widget = new RedWidget();
        [self addChildWidget: widget];
    }
}

// test steting a mask on a QWindow. Mouse clicks should
// "click through" for the masked region.
- (void) maskedWindow
{
    for (int i = 0; i < g_testViewCount; ++i) {
        QWidget *widget = new RedWidget();
        [self addChildWidget: widget];
        widget->windowHandle()->setMask(QRegion(QRect(0,0, 200, 75)));
    }
}

- (void) qtQuickWindow
{
    for (int i = 0; i < g_testViewCount; ++i) {
        QQuickView *view = new QQuickView;
        view->setSource(QUrl::fromLocalFile("main.qml"));
        [self addChildWindow: view];
    }
}

- (void) qtOpenGLWidget
{
    for (int i = 0; i < g_testViewCount; ++i) {
        QtOpenGLWidget *openglWidget = new QtOpenGLWidget();
        [self addChildWidget: openglWidget];
    }
}

- (void) qtQuickWidget
{
    for (int i = 0; i < g_testViewCount; ++i) {
        QQuickWidget *quickWidget = new QQuickWidget;
        quickWidget->setSource(QUrl::fromLocalFile("main.qml"));
        [self addChildWidget: quickWidget];
    }
}

- (void) recreateTestWindow
{
    // Save current test window geometry or set up default geometry
    NSRect frame = m_topLevelWindow ? [m_topLevelWindow frame] : NSMakeRect(500, 500, 500, 500);

    // Destroy current test window(s)
    [m_topLevelWindow release];
    m_topLevelWindow = 0;
    foreach(NSWindow *window, m_topLevelNSWindows) {
        [window release];
    }
    m_topLevelNSWindows.clear();
    foreach(QWindow *window, m_topLevelQWindows) {
        delete window;
    }
    m_topLevelQWindows.clear();
    foreach(QWidget *widget, m_topLevelWidgets) {
        delete widget;
    }
    m_topLevelWidgets.clear();

    m_childCascadePoint = QPoint(0,0);

    // Reset native instance counter
    QCocoaSpy::reset();

    // Create new test window(s)
    NSWindow *window =
        [[NSWindow alloc] initWithContentRect:frame
                                     styleMask:NSTitledWindowMask | NSClosableWindowMask |
                                               NSMiniaturizableWindowMask | NSResizableWindowMask
                                       backing:NSBackingStoreBuffered
                                         defer:NO];
    [window setFrame:frame display:NO];
    m_topLevelWindow = window;

    NSString *title = @"Qt on OS X Graphics Test Bench";
    [window setTitle:title];
    [window setBackgroundColor:[NSColor blueColor]];

    NSView *contentView = [[TestBenchContentView alloc] init];
    [window setContentView:contentView];
    [window makeFirstResponder:contentView];
    [contentView release];
    contentView = 0;

    // Select test cases
    for (int i : g_activeTestCases) {
        switch (i) {
            case 0: [self nativeNSOpenGLView]; break;
            case 1: [self nativeOpenGLNSView]; break;
            case 2: [self nativeOpenGLLayer]; break;
            case 3: [self nativeRasterLayer]; break;
            case 4: [self native120fpsView]; break;
            case 5: [self qtOpenGLWindow]; break;
            case 6: [self qtRasterWindow]; break;
            case 7: [self qtWidget]; break;
            case 8: [self maskedWindow]; break;
            case 9: [self qtQuickWindow]; break;
            case 10: [self qtOpenGLWidget]; break;
            case 11: [self qtQuickWidget]; break;
            default: break;
        }
    }

    // Show the top-level NSWindow for configs that have a single top-level window
    if (g_windowConfiguration == TopLevelWindowsAreQNSViews ||
        g_windowConfiguration == TopLevelWindowsAreChildNSWindows) {
        [window makeKeyAndOrderFront:NSApp];
    } else {
        // else the window is not in use.
        [window release];
        m_topLevelWindow = 0;
    }

    // Show status messages for known bad configurations
    if (g_activeTestCases.contains(1) /*"Native NSView + NSOpenGLView"*/ && g_useContainingLayers) {
        [g_statusText setStringValue:@"Bad Config: NSView + NSGLContext in layer mode"];
        g_statusText.backgroundColor = [NSColor redColor];
    } else {
        [g_statusText setStringValue:@"Status: OK"];
        g_statusText.backgroundColor = [NSColor whiteColor];
    }


#if 0
    // Optionally print view hiearchy with [NSView _subtreeDescription]
    if (m_topLevelWindow) {
        NSString *subtree = [m_topLevelWindow.contentView _subtreeDescription];
        qDebug() <<  QString::fromNSString(subtree);
    }
#endif

    // Update status message view with NSWindow and NSView instance stats.
    QString nativeStatus;

    nativeStatus += "NSWindow count: " + QString::number(QCocoaSpy::windowCount()) + "\n";
    for (int i = 0; i < QCocoaSpy::windowCount(); ++i) {
        NSWindow *window = QCocoaSpy::window(i);
        nativeStatus += "  #" + QString::number(i);
        nativeStatus += " Class \'" + QString::fromNSString(NSStringFromClass([window class]));
        nativeStatus += " Title \'" + QString::fromNSString(window.title) + "\'\n";
    }

    // Filter out some uninteresting views (NSWindow title bar views etc)
    QList<NSView *> filteredViews;
    for (int i = 0; i < QCocoaSpy::viewCount(); ++i) {
        NSView *view = QCocoaSpy::view(i);
        QString className = QString::fromNSString(NSStringFromClass([view class]));
        // theme and title bar
        if (className.startsWith("_NSTheme") || className.startsWith("NSTheme") || className.startsWith("NSTitlebar"))
            continue;
        // more title bar (?) ### filter by hiearchy instead
        if (className.startsWith("NSView") || className.startsWith("NSTextField"))
            continue;

        filteredViews.append(view);
    }

    nativeStatus += "NSView count: " + QString::number(QCocoaSpy::viewCount());
    nativeStatus += " (filtered: " + QString::number(filteredViews.count()) + ")\n";

    const int maxViewListingSize = 15;
    for (int i = 0; i < qMin(maxViewListingSize, filteredViews.count()); ++i) {
        NSView *view = filteredViews.at(i);
        nativeStatus += "  #" + QString::number(i);
        nativeStatus += " Class \'" + QString::fromNSString(NSStringFromClass([view class])) + "'\n";
    }

    [g_nativeInstanceStatus setStringValue:nativeStatus.toNSString()];
}

- (void) applicationWillFinishLaunching: (NSNotification *)notification
{
    Q_UNUSED(notification);

    // Install NSWindow and NSView instance monitor
    QCocoaSpy::init();

    // Create the controller window with test selection and config
    createControllerWindow();

    // Create the test windows
    [self recreateTestWindow];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    Q_UNUSED(notification);

    QCocoaSpy::reset();
    delete m_app;
}

@end

int main(int argc, const char *argv[])
{
    // Work with the Gui thread render loop for now.
    qDebug() << "qputenv(\"QSG_RENDER_LOOP\", \"basic\");";
    qputenv("QSG_RENDER_LOOP", "basic");

    // Create NSApplicaiton with delgate
    NSApplication *app =[NSApplication sharedApplication];
    app.delegate = [[AppDelegate alloc] initWithArgc:argc argv:argv];
    return NSApplicationMain (argc, argv);
}
