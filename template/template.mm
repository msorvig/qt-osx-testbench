#import <AppKit/AppKit.h>
#include <QtCore>

@interface EventPrinterView : NSView
{

}
@end

@implementation EventPrinterView

- (id) init
{
    [super initWithFrame: NSMakeRect(0, 0, 1, 1)];
    return self;
}

- (void)drawRect: (NSRect)dirtyRect
{
    [[NSColor colorWithDeviceRed:0.7 green:0.7 blue:0.7 alpha:1.0] setFill];
    NSRectFill(dirtyRect);
    [super drawRect:dirtyRect];
}

- (void)mouseDown:(NSEvent *) ev
{
    qDebug() << "EventPrinterView mouse down";
}

- (void)mouseUp:(NSEvent *) ev
{
    qDebug() << "EventPrinterView mouse up";
}

- (void)keyDown:(NSEvent *) ev
{
    qDebug() << "EventPrinterView keyDown";
}

- (void)keyUp:(NSEvent *) ev
{
    qDebug() << "EventPrinterView keyUp";
}

- (void)scrollWheel:(NSEvent *) ev
{
    qDebug() << "EventPrinterView scrollWheel";
}

- (void)tabletProximity:(NSEvent *) ev
{
    qDebug() << "EventPrinterView tabletProximity";
}

- (void)tabletPoint:(NSEvent *) ev
{
    qDebug() << "EventPrinterView tabletPoint";
}

@end


@interface AppDelegate : NSObject <NSApplicationDelegate> {
//    QGuiApplication *m_app;
}
- (AppDelegate *) initWithArgc:(int)argc argv:(const char **)argv;
- (void) applicationWillFinishLaunching: (NSNotification *)notification;
- (void) applicationWillTerminate:(NSNotification *)notification;
@end

@implementation AppDelegate

- (AppDelegate *) initWithArgc:(int)argc argv:(const char **)argv
{
//    m_app = new QApplication(argc, const_cast<char **>(argv));
    return self;
}

- (void) applicationWillFinishLaunching: (NSNotification *)notification
{
    NSRect frame = NSMakeRect(40, 40, 320, 200);
    NSWindow *window =
        [[NSWindow alloc] initWithContentRect:frame
                                     styleMask:NSTitledWindowMask | NSClosableWindowMask |
                                               NSMiniaturizableWindowMask | NSResizableWindowMask
                                       backing:NSBackingStoreBuffered
                                         defer:NO];

    [window setTitle:@"Test Bench Controller"];
    [window setBackgroundColor:[NSColor blueColor]];
    
    EventPrinterView *view = [[EventPrinterView alloc] init];
    window.contentView = view;
    [view release];
    [window makeKeyAndOrderFront:nil];
    [window makeFirstResponder: window.contentView];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{

}

@end

int main(int argc, const char *argv[])
{
    // Create NSApplicatiton with delegate
    NSApplication *app = [NSApplication sharedApplication];
    app.delegate = [[AppDelegate alloc] initWithArgc:argc argv:argv];
    return NSApplicationMain (argc, argv);
}
