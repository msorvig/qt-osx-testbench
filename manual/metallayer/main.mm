#include <QtGui>

#include <hellotriangle/AAPLRenderer.h>

#include <AppKit/AppKit.h>
#include <QuartzCore/QuartzCore.h>

@interface MetalLayerBackedView : NSView
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
    if (!self)
        return 0;
    
    self.wantsLayer = YES; // Enable layer backing
    
    // self.layerContentsRedrawPolicy has no effect since we return a custom layer in makeBackingLayer
    // self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawDuringViewResize;
    
    [self initMetal];

    // Set up redraw-on-resize
    [self setPostsFrameChangedNotifications:YES];
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(frameDidChangeNotification:)
                   name:NSViewFrameDidChangeNotification
                 object:self];
    
    return self;
}

- (CALayer *)makeBackingLayer
{
    qDebug() << "makeBackingLayer";
    
    // One Metal Layer, please
    metalLayer = [CAMetalLayer layer];
    return metalLayer;
}

- (BOOL)wantsUpdateLayer
{
    qDebug() << "wantsUpdateLayer";
    return YES; // Yes: we manage layer updates
}

- (void)drawRect:(NSRect)dirtyRect
{
    // drawRect is not called since we return YES from wantsUpdateLayer
    Q_UNUSED(dirtyRect);
    qDebug() << "drawRect";
}

- (void)updateLayer
{
    // updateLayer is not called since we set a custom layer in makeBackingLayer (?)
    qDebug() << "updateLayer";
}

- (void)initMetal
{
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

- (void)frameDidChangeNotification:(NSNotification *)notification
{
    Q_UNUSED(notification);

    int windowScale = self.window.backingScaleFactor;
    if (windowScale == 0)
        windowScale = 2;

    // The documentation states that drawableSize will be updated automatically
    // based on the layer size and contentsScale, but this does not seem to be
    // the case in practice.
    CGSize drawableSize = self.layer.bounds.size;
    drawableSize.width *= windowScale;
    drawableSize.height *= windowScale;
    metalLayer.drawableSize = drawableSize;
    
    qDebug() << "frameDidChangeNotification" << "\n"
             << "self.bounds.size" << QSizeF::fromCGSize(self.bounds.size) << "\n"
             << "self.layer.bounds.size" << QSizeF::fromCGSize(self.layer.bounds.size) << "\n"
             << "self.layer.contentsScale" << self.layer.contentsScale << "\n"
             << "self.window.backingScaleFactor" << self.window.backingScaleFactor << "\n"
             << "metalLayer.drawableSize" << QSizeF::fromCGSize(metalLayer.drawableSize);

    [renderer drawFrame];
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