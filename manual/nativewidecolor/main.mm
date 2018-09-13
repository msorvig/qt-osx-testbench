#include <AppKit/AppKit.h>
#include <QtCore/QtCore>

@interface FillColorView : NSView
{

}
@end

@implementation FillColorView

bool useLayer = YES;

- (id) init
{
    self = [super initWithFrame: NSMakeRect(0, 0, 256, 256)];

}

- (BOOL)wantsLayer
{
    return useLayer;
}


- (BOOL)wantsUpdateLayer
{
    return useLayer;
}

- (void)drawRect: (NSRect)dirtyRect
{
    NSColor *green = [NSColor colorWithDisplayP3Red:0 green:1 blue:0 alpha:1.0];
    [green setFill];
    NSRectFill(dirtyRect);
    [super drawRect:dirtyRect];
}

- (void)updateLayer
{
    NSSize size = NSMakeSize(320, 200);
    NSImage *image = [[[NSImage alloc] initWithSize:size] autorelease];
    [image lockFocus];
    NSColor *green = [NSColor colorWithDisplayP3Red:0 green:1 blue:0 alpha:1.0];
    [green drawSwatchInRect:NSMakeRect(0, 0, size.width, size.height)];
    [image unlockFocus];
    self.layer.contents = [image layerContentsForContentsScale:1.0];
}

@end

@interface AppDelegate : NSObject <NSApplicationDelegate>


@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    {
        NSRect frame = NSMakeRect(-1, -1, 320, 200);
        NSWindow *window =
            [[NSWindow alloc] initWithContentRect:frame
                                     styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                               NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                       backing:NSBackingStoreBuffered
                                         defer:NO];

        [window setTitle:@"Wide Color Test DisplayP3"];
        NSColor *green = [NSColor colorWithDisplayP3Red:0 green:1 blue:0 alpha:1.0];
        [window setBackgroundColor:green];
        [window makeKeyAndOrderFront:nil];
    }
    
    {
        NSRect frame = NSMakeRect(-1, -1, 320, 200);
        NSWindow *window =
            [[NSWindow alloc] initWithContentRect:frame
                                     styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                               NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                       backing:NSBackingStoreBuffered
                                         defer:NO];

        [window setTitle:@"Wide Color Test sRGB"];
        NSColor *green = [NSColor colorWithSRGBRed:0 green:1 blue:0 alpha:1.0];
        [window setBackgroundColor:green];
        [window makeKeyAndOrderFront:nil];
    }
    {
        NSRect frame = NSMakeRect(-1, -1, 320, 200);
        NSWindow *window =
            [[NSWindow alloc] initWithContentRect:frame
                                     styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                               NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                       backing:NSBackingStoreBuffered
                                         defer:NO];

        [window setTitle:@"Wide Color Test View DeviceP3"];
        window.contentView = [[FillColorView alloc] init];
        [window makeKeyAndOrderFront:nil];
    }
}

@end

int main(int argc, char **argv)
{
    NSApplication *app = [NSApplication sharedApplication];
    app.delegate = [[AppDelegate alloc] init];
    return NSApplicationMain(argc, (const char **)argv);
}