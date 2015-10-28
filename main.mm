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

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    QGuiApplication *m_app;
    QWidget *m_widget;
    QWindow *m_rasterWindow;
    QWindow *m_openglWindow;
    QWindow *m_openglWindowResize;
    QWindow *m_qtquickWindow;

    QWindow *m_window;
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
    return self;
}

- (void) applicationWillFinishLaunching: (NSNotification *)notification
{
    Q_UNUSED(notification);

    // Create the NSWindow
    NSRect frame = NSMakeRect(500, 500, 500, 500);
    NSWindow* window  = [[NSWindow alloc] initWithContentRect:frame
                        styleMask:NSTitledWindowMask |  NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask
                        backing:NSBackingStoreBuffered
                        defer:NO];

    NSString *title = @"Top-level NSWindows";
    [window setTitle:title];
    [window setBackgroundColor:[NSColor blueColor]];

    // Create test windows
    m_widget = new RedWidget;
    m_widget->winId(); // create
    m_rasterWindow = new RasterWindow();
    m_openglWindow = new OpenGLWindow();
    m_openglWindowResize = new MyOpenGLWindow();

    m_qtquickWindow = new QQuickView(QUrl::fromLocalFile("main.qml"));
    
    // select window and set as content view.
    m_window = m_rasterWindow;
//    m_window = m_openglWindow;
//    m_window = m_widget->windowHandle();
    m_window->create();

//    m_window->setMask(QRegion(QRect(0,0, 200, 100)));

    NSView *view = reinterpret_cast<NSView *>(getEmbeddableView(m_window));
    [view setFrame : NSMakeRect(50, 50, 400, 400)];

    NSView *contentView = [[NativeCocoaView alloc] init];
    [window setContentView: contentView];
    [window makeFirstResponder: contentView];

    [[window contentView] addSubview : view];
    [window makeFirstResponder: view];

    // Need show calls. ### making the native NSView visible should be enough
    m_window->show();
    if (m_window == m_widget->windowHandle())
        m_widget->show();

    // Show the NSWindow
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



