#include <QtGui>

#include <hellotriangle/AAPLRenderer.h>

#include <AppKit/AppKit.h>
#include <QuartzCore/QuartzCore.h>

@interface MetalLayerBackedView : NSView <CALayerDelegate>
{
    id<MTLDevice> metalDevice;
    CAMetalLayer *metalLayer;
    AAPLRenderer *renderer;
}
@end

@implementation MetalLayerBackedView

- (id)init
{
    qDebug() << "MetalLayerBackedView init";
    self = [super init];
    return self;
}

- (BOOL)wantsLayer
{
    qDebug() << "wantsLayer";
    return YES;
}

- (CALayer *)makeBackingLayer
{
    qDebug() << "makeBackingLayer";
    
    // One Metal Layer, please
    metalLayer = [CAMetalLayer layer];
    return metalLayer;
}

- (NSViewLayerContentsRedrawPolicy) layerContentsRedrawPolicy
{
    return NSViewLayerContentsRedrawDuringViewResize;
}

- (void)updateLayerDrawableSize
{
    CGSize drawableSize = self.layer.bounds.size;
    drawableSize.width *= self.layer.contentsScale;
    drawableSize.height *= self.layer.contentsScale;
    metalLayer.drawableSize = drawableSize;
}

- (void)viewDidChangeBackingProperties
{
    qDebug() << "viewDidChangeBackingProperties";
    self.layer.contentsScale = self.window.backingScaleFactor;
    [self updateLayerDrawableSize];
    [self setNeedsDisplay:YES];
}

- (void)layoutSublayersOfLayer:(CALayer *)layer
{
    qDebug() << "layoutSublayersOfLayer";
    [self updateLayerDrawableSize];
}

- (void)displayLayer:(CALayer *)layer
{
    qDebug() << "displayLayer";
    [self initMetal];
    [renderer drawFrame];
}

- (void)initMetal
{
    if (metalDevice != nil)
        return;

    qDebug() << "initMetal";
    
    metalDevice = MTLCreateSystemDefaultDevice();
    if (!metalDevice)
        qFatal("Metal is not supported");

    // Load shaders from Qt resources
    QFile shadersFile(":/hellotriangleshaders.metallib");
    shadersFile.open(QIODevice::ReadOnly);
    QByteArray shaders = shadersFile.readAll();
    dispatch_data_t data = dispatch_data_create(shaders.constData(), shaders.size(),
                           dispatch_get_main_queue(), DISPATCH_DATA_DESTRUCTOR_DEFAULT);
                           
    NSError *error = nil;
    id <MTLLibrary> library = [metalDevice newLibraryWithData:data error:&error];
    dispatch_release(data);
    if (error)
        qWarning() << "Shader Error" << error;
    
    // Create Renderer
    metalLayer.device = metalDevice;
    renderer = [[AAPLRenderer alloc] initWithMetalLayer:metalLayer library:library];
}

@end

@interface AppDelegate : NSObject <NSApplicationDelegate> {
}

@end

@implementation AppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
    NSRect frame = NSMakeRect(40, 40, 300, 200);
    NSWindow *window =
        [[NSWindow alloc] initWithContentRect:frame
                                     styleMask:NSTitledWindowMask | NSClosableWindowMask |
                                               NSMiniaturizableWindowMask | NSResizableWindowMask
                                       backing:NSBackingStoreBuffered
                                         defer:NO];

    [window setTitle:@"CAMetalLayer-backed NSView"];
    
    
    NSView *contentView = [[MetalLayerBackedView alloc] init];
    [window setContentView:contentView];
    [window makeKeyAndOrderFront:nil];
}

@end

int main(int argc, const char *argv[])
{
    NSApplication *app = [NSApplication sharedApplication];
    app.delegate = [[AppDelegate alloc] init];
    return NSApplicationMain(argc, argv);
}
