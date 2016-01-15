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
#import "nativecocoaview.h"


#include <QtGui>
#include <QtWidgets>
#include <QtQuick>

#import <Cocoa/Cocoa.h>

#include <qpa/qplatformnativeinterface.h>

// Global Options. These can be tweaked to run the examples/test in different configurations
int g_activeTestCase = 0;

enum QWindowConfiguration
{
    TopLevelWindowsAreQNSViews,             // Embed QWindows in a NSView contentview
    TopLevelWindowsAreTopLevelNSWindows,    // Embed QWindows in a separate NSWindows
    TopLevelWindowsAreChildNSWindows,       // Embed QWindows in a single NSWindow
    StandardQWindowShow,                    // Normal QWindow->show() use case
};
QWindowConfiguration g_windowConfiguration = TopLevelWindowsAreQNSViews;

bool g_useContainingLayers = true; // use layers for the containing native views --
                                   // the content and controller views). Since these
                                   // are parent views of the test views the test views
                                   // will be switched to layer mode as well.

// Native View animation drivers (mutally exclusive, select one)
bool g_useNativeAnimationTimer = false; // animate using a timer
bool g_useNativeAnimationSetNeedsDisplay = false; // animate by calling setNeedsDisplay.
bool g_useNativeAnimationDisplaylink = true; // animate using CVDisplayLink

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    QGuiApplication *m_app;
    QWidget *m_widget;
    QWindow *m_rasterWindow;
    QWindow *m_openglWindow;
    QWindow *m_openglWindowResize;
    QWindow *m_qtquickWindow;

    QWindow *m_window;
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

- (void)changeTestCase:(id)sender {
    NSButtonCell *selCell = [sender selectedCell];
    g_activeTestCase = int([selCell tag]);
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

- (NSTextField *) addLabel: (NSString *)text
{
    NSRect frame = NSMakeRect(0, 0, 200, 25);
    NSTextField *label = [[NSTextField alloc] initWithFrame:frame];
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
    [self addControl: myMatrix];
    [myMatrix release];
}

// Add a check box (on by deafault)
- (void) addCheckBox: (NSString *)text withActionTarget: (SEL)onToggled
{
    NSRect frame = NSMakeRect(0, 0, 200, 25);
    NSButton *button = [[NSButton alloc] initWithFrame:frame];
    [button setButtonType:NSSwitchButton];
    [button setTitle:text];
    [button setState:NSOnState];
    [button setAction:onToggled];
    [button setTarget:self];

    [self addControl: button];
}

- (void) createControllerViewContent
{
    [self addLabel:@"Test Case Selection"];
    QStringList testCases =
        QStringList() << "Native NSOpenGLView"
                      << "Native NSView + NSOpenGLContext"
                      << "Native OpenGLLayer"
                      << "Native RasterLayer"
                      << "Qt OpenGLWindow"
                      << "Qt OpenGLWindow (force layer mode)"
                      << "Qt RasterWindow"
                      << "Qt RasterWindow (force layer mode)"
                      << "Qt Widgets"
                      << "Qt Masked Window";
    [self addRadioButtonGroup:testCases
             withActionTarget:@selector(changeTestCase:)];

    [self addLabel:@"QWindow Configuration"];
    QStringList windowConfigurations = // (in QWindowConfiguration order)
        QStringList() << "Child QNSViews"
                      << "Top-level NSWindows"
                      << "Child NSWindows"
                      << "Top-level QNSWindows (Standard Qt config)";
    [self addRadioButtonGroup:windowConfigurations
             withActionTarget:@selector(changeWindowConfiguration:)];

    [self addLabel:@"Layers"];
    [self addCheckBox:@"Force layer mode: Use layers for container views"
      withActionTarget:@selector(changeContainingLayers:)];

    // status label (store global for later modification)
    g_statusText = [self addLabel:@"Status: OK"];
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

    NSString *title = @"Test Bench Controller";
    [window setTitle:title];
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

@implementation AppDelegate
- (AppDelegate *) initWithArgc:(int)argc argv:(const char **)argv
{
    m_app = new QApplication(argc, const_cast<char **>(argv));
    m_widget = 0;
    m_rasterWindow = 0;
    m_openglWindow = 0;
    m_qtquickWindow = 0;
    m_window = 0;
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
        NSView *controllerView = [[ControllerView alloc] initWithView: view];
        m_childCascadePoint += QPoint(50, 50);
        [controllerView setFrame : NSMakeRect(m_childCascadePoint.x(), m_childCascadePoint.y(), 300, 300)];
        [[m_topLevelWindow contentView] addSubview : controllerView];
    }
}

- (void) addChildWindow: (QWindow *) window
{
    if (g_windowConfiguration == StandardQWindowShow) {
        m_topLevelQWindows.append(window);
        window->show();
        return;
    }

    NSView *view = getEmbeddableView(window);
    [self addChildView: view];
    window->show(); // ### fixme
}

- (void) addChildWidget: (QWidget *) widget
{
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
    [self addChildView: [[AnimatedOpenGLVew alloc] init]];
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

    [self addChildView: [[OpenGLNSView alloc] init]];
    [self addChildView: [[OpenGLNSView alloc] init]];
}

// test showing a NSView with a custom NSOpenGLLayer layer
- (void) nativeOpenGLLayer
{
    [self addChildView: [[OpenGLLayerView alloc] init]];
    [self addChildView: [[OpenGLLayerView alloc] init]];
}

// test showing a NSView with raster layer content
- (void) nativeRasterLayer
{
    [self addChildView: [[RasterLayerView alloc] init]];
    [self addChildView: [[RasterLayerView alloc] init]];
}

// test QOpenGLWindow.
- (void) qtOpenGLWindow
{
    [self addChildWindow: new OpenGLWindow()];
    [self addChildWindow: new OpenGLWindow()];
}

// test QOpenGLWindow that requests a layer and enables layer mode
- (void) qtOpenGLLayerWindow
{
    [self addChildWindow: new OpenGLWindow("_q_mac_wantsLayer")];
    [self addChildWindow: new OpenGLWindow("_q_mac_wantsLayer")];
}

// test RasterWindow
- (void) qtRasterWindow
{
    [self addChildWindow: new RasterWindow()];
    [self addChildWindow: new RasterWindow()];
}

// test RasterWindow that requrests a layer and enables layer mode
- (void) qtRasterLayerWindow
{
    [self addChildWindow: new RasterWindow("_q_mac_wantsLayer")];
    [self addChildWindow: new RasterWindow("_q_mac_wantsLayer")];
}

// test QtWidgets
- (void) qtWidget
{
    [self addChildWidget: new RedWidget()];
    [self addChildWidget: new RedWidget()];
}

// test steting a mask on a QWindow. Mouse clicks should
// "click through" for the masked region.
- (void) maskedWindow
{
    QWidget *widget = new RedWidget();
    [self addChildWidget: widget];
    widget->windowHandle()->setMask(QRegion(QRect(0,0, 200, 75)));
}

- (void) recreateTestWindow
{
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

    // Create new test window(s)
    NSRect frame = NSMakeRect(500, 500, 500, 500);
    NSWindow *window =
        [[NSWindow alloc] initWithContentRect:frame
                                     styleMask:NSTitledWindowMask | NSClosableWindowMask |
                                               NSMiniaturizableWindowMask | NSResizableWindowMask
                                       backing:NSBackingStoreBuffered
                                         defer:NO];
    m_topLevelWindow = window;

    NSString *title = @"Qt on OS X Graphics Test Bench";
    [window setTitle:title];
    [window setBackgroundColor:[NSColor blueColor]];

    NSView *contentView = [[NativeCocoaView alloc] init];
    [window setContentView: contentView];
    [window makeFirstResponder: contentView];

    // Select test case
    switch (g_activeTestCase) {
        case 0: [self nativeNSOpenGLView]; break;
        case 1: [self nativeOpenGLNSView]; break;
        case 2: [self nativeOpenGLLayer]; break;
        case 3: [self nativeRasterLayer]; break;
        case 4: [self qtOpenGLWindow]; break;
        case 5: [self qtOpenGLLayerWindow]; break;
        case 6: [self qtRasterWindow]; break;
        case 7: [self qtRasterLayerWindow]; break;
        case 8: [self qtWidget]; break;
        case 9: [self maskedWindow]; break;
        default: break;
    }

    // Show the top-level NSWindow for configs that have a single top-level window
    if (g_windowConfiguration == TopLevelWindowsAreQNSViews ||
        g_windowConfiguration == TopLevelWindowsAreChildNSWindows)
        [window makeKeyAndOrderFront:NSApp];

    // Show status messages for known bad configurations
    if (g_activeTestCase == 1 /*"Native NSView + NSOpenGLView"*/ && g_useContainingLayers) {
        [g_statusText setStringValue:@"Bad Config: NSView + NSGLContext in layer mode"];
        g_statusText.backgroundColor = [NSColor redColor];
    } else {
        [g_statusText setStringValue:@"Status: OK"];
        g_statusText.backgroundColor = [NSColor whiteColor];
    }
}

- (void) applicationWillFinishLaunching: (NSNotification *)notification
{
    Q_UNUSED(notification);

    // Create the controller window with test selection and config
    createControllerWindow();

    // Create the test windows
    [self recreateTestWindow];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    Q_UNUSED(notification);
    delete m_window;
    delete m_widget;
    delete m_app;
}

@end

int main(int argc, const char *argv[])
{
    // Create NSApplicaiton with delgate
    NSApplication *app =[NSApplication sharedApplication];
    app.delegate = [[AppDelegate alloc] initWithArgc:argc argv:argv];
    return NSApplicationMain (argc, argv);
}



