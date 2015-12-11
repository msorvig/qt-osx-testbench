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

// Window configuration/hosting options (mutally exclusive, select one)
bool g_useTopLevelWindows = false; // show each window/view as a top-level window instead
                                   // of as embedded windows.
bool g_useChildWindows = false;    // TODO: embed each window/view in a native NSWindow
bool g_useChildViews = true;       // embed each window/view in a native NSView

bool g_useContainingLayers = true; // use layers for the containing native views --
                                   // the content and coontroller views)

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
    NSWindow *m_topLevelWindow;

    QPoint m_childCascadePoint;
}
- (AppDelegate *) initWithArgc:(int)argc argv:(const char **)argv;
- (void) applicationWillFinishLaunching: (NSNotification *)notification;
- (void)applicationWillTerminate:(NSNotification *)notification;
@end

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
    return self;
}

- (void) addChildView: (NSView *) view
{
    // handle cases that embeds the view in its own window
    if (g_useChildWindows || g_useTopLevelWindows) {
        NSRect frame = NSMakeRect(0, 0, 200, 100);
        NSWindow *window =
            [[NSWindow alloc] initWithContentRect:frame
                                         styleMask:NSTitledWindowMask | NSClosableWindowMask |
                                                   NSMiniaturizableWindowMask | NSResizableWindowMask
                                           backing:NSBackingStoreBuffered
                                             defer:NO];
        [window setContentView:view];

        if (g_useTopLevelWindows) {
            [window makeKeyAndOrderFront:nil];
        } else {
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
    if (g_useTopLevelWindows) {
        window->show();
        return;
    }

    NSView *view = getEmbeddableView(window);
    [self addChildView: view];
    window->show(); // ### fixme
}

- (void) addChildWidget: (QWidget *) widget
{
    widget->winId(); // create, ### fixme
    [self addChildWindow: widget->windowHandle()];
    widget->show(); // ### fixme
}

// test showing several animated OpenGL views, along with a QWidget window.
// The OpenGL views should animate at 60 fps.
- (void) nativeNSOpenGLView
{
    [self addChildView: [[AnimatedOpenGLVew alloc] init]];
    [self addChildView: [[AnimatedOpenGLVew alloc] init]];
    [self addChildView: [[AnimatedOpenGLVew alloc] init]];

    [self addChildWidget: new RedWidget()];
}

// test showing a NSview with an attached OpenGL context.
- (void) nativeOpenGLNSView
{
    // status: flickers when there are layers present. (set g_useContainingLayers
    // to false above to disable). This is proably expected since we want to
    // draw using the layer's context. NSOpenGLView handles this transition
    // transparently to the user.
    //
    // g_useTopLevelWindows also makes this work.

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

- (void) applicationWillFinishLaunching: (NSNotification *)notification
{
    Q_UNUSED(notification);

    // Create the NSWindow
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

    // Select test/example:

    [self nativeNSOpenGLView];
//    [self nativeOpenGLNSView];
//    [self nativeOpenGLLayer];

//    [self qtMultiWindowAnimation];
//    [self qtLayerOpenGLWindow];
//    [self maskedWindow];

    // Show the top-level NSWindow
    if (!g_useTopLevelWindows)
        [window makeKeyAndOrderFront:NSApp];
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
    // Optionally test a layer-backed Qt view
    //qputenv("QT_MAC_WANTS_LAYER", "1");
    
    // Create NSApplicaiton with delgate
    NSApplication *app =[NSApplication sharedApplication];
    app.delegate = [[AppDelegate alloc] initWithArgc:argc argv:argv];
    return NSApplicationMain (argc, argv);
}



