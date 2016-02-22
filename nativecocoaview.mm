#import "nativecocoaview.h"

#include "glcontent.h"

#include <QtCore/QtCore>
#include <QtGui/QtGui>

extern bool g_useContainingLayers;
extern bool g_animate;

@implementation TestBenchContentView

- (id) init
{
    [super initWithFrame: NSMakeRect(0, 0, 1, 1)];
    if (g_useContainingLayers)
        [self setWantsLayer: true];
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
    Q_UNUSED(ev)
    qDebug() << "NativeCocoaView mouse down";
}

- (void)mouseUp:(NSEvent *) ev
{
    Q_UNUSED(ev)
    qDebug() << "NativeCocoaView mouse up";
}

- (void)keyDown:(NSEvent *) ev
{
    Q_UNUSED(ev)
    qDebug() << "NativeCocoaView keyDown";
}

- (void)keyUp:(NSEvent *) ev
{
    Q_UNUSED(ev)
    qDebug() << "NativeCocoaView keyUp";
}

@end

@implementation TestBenchMDIView

- (id)initWithView: (NSView *) view
{
    [super initWithFrame: NSMakeRect(0, 0, 1, 1)];

    if (g_useContainingLayers)
        [self setWantsLayer: true];

    controlledView = view;
    [self addSubview: view];

    // enable autolayout with padding
    [controlledView setTranslatesAutoresizingMaskIntoConstraints:NO];
    NSDictionary * views = NSDictionaryOfVariableBindings(controlledView);
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[controlledView]-|"
                                                                       options:0
                                                                       metrics:nil
                                                                       views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[controlledView]-|"
                                                                       options:0
                                                                       metrics:nil
                                                                       views:views]];
    return self;
}

- (void)orderFront: (NSView *) view
{
    // bring to front with layer hack
    CALayer* superlayer = [[view layer] superlayer];
    [[view layer] removeFromSuperlayer];
    [superlayer addSublayer:[view layer]];
}

- (void)drawRect: (NSRect)dirtyRect
{
    [[NSColor colorWithDeviceWhite: 0.5 alpha: 1] setFill];
    [[NSColor colorWithDeviceWhite: 0.4 alpha: 1] set];
    [NSBezierPath strokeRect:[self bounds]];
    [NSBezierPath fillRect:dirtyRect];

    [super drawRect:dirtyRect];
}

- (void)mouseDown:(NSEvent *) ev
{
    qDebug() << "ControllerView mouse down";

    NSRect rect = [self frame];
    NSPoint position = [self convertPoint:[ev locationInWindow] fromView:nil];

    // Prepare drag mode: frame top: move, else: resize.
    isMove = (rect.size.height - position.y) < 20;

    [self orderFront: self];
//    [self orderFront: controlledView];

    [[self window] makeFirstResponder:self];
}

- (void)mouseUp:(NSEvent *) ev
{
    Q_UNUSED(ev)
    qDebug() << "ControllerView mouse up";
}

- (void)mouseDragged:(NSEvent *) ev
{
    NSRect rect = [self frame];

    if (isMove) {
        rect.origin.x += [ev deltaX];
        rect.origin.y -= [ev deltaY];
    } else {
        rect.size.width += [ev deltaX];
        rect.origin.y -= [ev deltaY];
        rect.size.height += [ev deltaY];
    }

    [self setFrame: rect];
//    [[self superview] setNeedsDisplay:YES];
}

@end

@interface QPainterLayer : CALayer
{
    QImage *m_buffer;
}
-(void)updatePaintedContents;
@end

@interface QPainterLayerDelegate : NSObject
{

}
- (void)displayLayer:(CALayer *)layer;
@end

@implementation QPainterLayer

- (id)init
{
    [super init];

    self.needsDisplayOnBoundsChange = true;
    [self updatePaintedContents];

    return self;
}

-(void)updatePaintedContents
{
//    qDebug() << "QPainterLayer::updatePaintedContents";
    QSize contentiSize(200, 200);
    QImage content(contentiSize, QImage::Format_ARGB32_Premultiplied);
    QPainter p(&content);
    p.fillRect(QRect(QPoint(0,0), contentiSize), Qt::red);
    self.contents = content.toNSImage();
}

@end

@implementation QPainterLayerDelegate

- (void)displayLayer:(CALayer *)layer
{
//    qDebug() << "QPainterLayerDelegate::displayLayer";
    [static_cast<QPainterLayer *>(layer) updatePaintedContents];
}

@end

@implementation RasterLayerView

- (id)init
{
    [super initWithFrame: NSMakeRect(0, 0, 1, 1)];
    [self setWantsLayer: true];

    // RasterLayerView supports two modes: either (1) use the standard backing
    // layer and implement wantsUpdateLayer and updateLayer, or (2) use a
    // custom layer, implement makeBackingLayer and set a custom delegate
    // which implements updatePaintedContents.

    // Mode (2): Cocoa will set the delagate during setWantsLayer; reset it here
    // to our delegate:
    // self.layer.delegate = [[QPainterLayerDelegate alloc] init];
    return self;
}

/*
// mode (2)
- (CALayer *)makeBackingLayer
{
    qDebug() << "RasterLayerView::makeBackingLayer";

     // The layer for this view should be a QPainterLayer
    return [[CALayer alloc] init];
    return [[QPainterLayer alloc] init];
}
*/
- (BOOL)wantsUpdateLayer
{
    return YES;
}

- (void)updateLayer
{
//    qDebug() << "RasterLayerView::updateLayer";
    QSize contentSize(200, 200);
    int frame = 0;
    QImage content = drawSimpleImageContent(frame, contentSize);
    self.layer.contents = content.toNSImage();
}

- (void)drawRect: (NSRect)dirtyRect
{
    qWarning("RasterLayerView:drawRect: Unexpected this is"); // drawRect should not be called.
    [super drawRect: dirtyRect];
}
 
@end

@interface QOpenGLLayer : NSOpenGLLayer
{
    int frame;
}
@end

@implementation QOpenGLLayer

- (id)init
{
    [super init];
    frame = 0;
    return self;
}

- (NSOpenGLPixelFormat *)openGLPixelFormatForDisplayMask:(uint32_t)mask
{
    // TODO: according to docs we should use mask and create a NSOpenGLPFAScreenMask... somehow
    // NSOpenGLPFAScreenMask, CGDisplayIDToOpenGLDisplayMask(kCGDirectMainDisplay),

    Q_UNUSED(mask)
    NSOpenGLPixelFormatAttribute attributes [] =
    {
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFANoRecovery,
        NSOpenGLPFAAccelerated,
        0
    };

    NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
    return pixelFormat;
}

- (NSOpenGLContext *)openGLContextForPixelFormat:(NSOpenGLPixelFormat *)pixelFormat
{
    return [[NSOpenGLContext alloc] initWithFormat:pixelFormat shareContext:nil];
}

- (BOOL)isAsynchronous
{
    return YES; // Yes, call canDrawInOpenGLContext (below) at 60 fps
}

- (BOOL)canDrawInOpenGLContext:(NSOpenGLContext *)context
                   pixelFormat:(NSOpenGLPixelFormat *)pixelFormat
                  forLayerTime:(CFTimeInterval)timeInterval
                   displayTime:(const CVTimeStamp *)timeStamp
{
    Q_UNUSED(context);
    Q_UNUSED(pixelFormat);
    Q_UNUSED(timeInterval);
    Q_UNUSED(timeStamp);

    if (g_animate) {
        ++frame;
        return YES; // Yes, we have a frame
    }
}

- (void)drawInOpenGLContext:(NSOpenGLContext *)context
                pixelFormat:(NSOpenGLPixelFormat *)pixelFormat
               forLayerTime:(CFTimeInterval)timeInterval
                displayTime:(const CVTimeStamp *)timeStamp
{
    Q_UNUSED(context);
    Q_UNUSED(pixelFormat);
    Q_UNUSED(timeInterval);
    Q_UNUSED(timeStamp);

    drawSimpleGLContent(frame);  // Here it is
}

@end

@implementation OpenGLLayerView

- (id)init
{
    [super init];
    [self setWantsLayer:YES];
    return self;
}

- (CALayer *)makeBackingLayer
{
    return [[QOpenGLLayer alloc] init];
}

@end

// CVDisplayLink callback that performs [timerFire] on a view, on the main thread
CVReturn mainThreadTimerFireCallback(CVDisplayLinkRef displayLink, const CVTimeStamp* now,
                                              const CVTimeStamp* outputTime, CVOptionFlags flagsIn,
                                              CVOptionFlags* flagsOut, void* displayLinkContext)
{
    Q_UNUSED(displayLink)
    Q_UNUSED(now)
    Q_UNUSED(outputTime)
    Q_UNUSED(flagsIn)
    Q_UNUSED(flagsOut)

    // We're on a secondary thread but want to repaint on the main thread:
    // use performSelectorOnMainThread. (Using dispatch_async() is possible here, but
    // that does not fire during mouse- trakcing run-loop modes.)
    NSView *view = reinterpret_cast<NSView*>(displayLinkContext);
    [view performSelectorOnMainThread:@selector(timerFire)
                           withObject:view
                         waitUntilDone:NO
                                 modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
    return 0;
}


// A View that provides animated OpenGL content
@implementation AnimatedOpenGLVew

- (id)init
{
    frame = 0;

    NSOpenGLPixelFormatAttribute attributes [] =
    {
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFANoRecovery,
        NSOpenGLPFAAccelerated,
        0
    };

    NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc]
                                         initWithAttributes:attributes];

    [super initWithFrame:NSMakeRect(0,0,0,0) pixelFormat:pixelFormat];
//    [self setWantsLayer: true];

#ifdef TIMER
    [[NSTimer scheduledTimerWithTimeInterval:1.0 / 60 target:self
                                                    selector:@selector(timerFire)
                                                    userInfo:nil
                                                    repeats:YES] retain];

#else
	CVDisplayLinkCreateWithActiveCGDisplays(&m_displayLink);
	CVDisplayLinkSetOutputCallback(m_displayLink, &mainThreadTimerFireCallback, self);
    CVDisplayLinkSetCurrentCGDisplay(m_displayLink, kCGDirectMainDisplay);	CVDisplayLinkStart(m_displayLink);
#endif

    return self;

}

- (void)timerFire
{
    if (g_animate) {
        ++frame;
        [self setNeedsDisplay:YES];
    }
}

- (void)drawRect:(NSRect)rect
{
    Q_UNUSED(rect);
    ++frame;

    drawSimpleGLContent(frame);

    [[self openGLContext] flushBuffer];
}

@end

// A View that provides animated OpenGL content
@implementation OpenGLNSView

- (id)init
{
    frame = 0;

    [super initWithFrame: NSMakeRect(0, 0, 1, 1)];

    NSOpenGLPixelFormatAttribute attributes [] =
    {
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFANoRecovery,
        NSOpenGLPFAAccelerated,
        0
    };

    NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc]
                                         initWithAttributes:attributes];
    m_glcontext = [[NSOpenGLContext alloc] initWithFormat:pixelFormat shareContext:nil];

//    GLint val = 0;
//    [m_glcontext setValues:&val forParameter:NSOpenGLCPSwapInterval];

//    [self setWantsLayer: true];

	CVDisplayLinkCreateWithActiveCGDisplays(&m_displayLink);
	CVDisplayLinkSetOutputCallback(m_displayLink, &mainThreadTimerFireCallback, self);
    CVDisplayLinkSetCurrentCGDisplay(m_displayLink, kCGDirectMainDisplay); CVDisplayLinkStart(m_displayLink);

    return self;
}

- (void)timerFire
{
    if (g_animate) {
        ++frame;
        [self setNeedsDisplay:YES];
    }
}

- (void)drawRect:(NSRect)rect
{
    Q_UNUSED(rect);

    [m_glcontext makeCurrentContext];

    // attach to view
    if (m_glcontext.view != self) {
        [m_glcontext setView:self];
    }

    // update on view size change.
    NSSize size = [self convertSizeToBacking:self.frame.size];
    if (m_currentViewportSize.width != size.width ||
        m_currentViewportSize.height != size.height) {
        m_currentViewportSize = size;
        [m_glcontext update];
    }

    glViewport(0, 0, m_currentViewportSize.width, m_currentViewportSize.height);

    drawSimpleGLContent(frame);

    [m_glcontext flushBuffer];
    [NSOpenGLContext clearCurrentContext];
}

@end

@implementation Native120fpsView : NSView

- (id) init
{
    [super initWithFrame: NSMakeRect(0, 0, 1, 1)];

    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 120.0
                                                      target:self
                                                    selector:@selector(syncPaint:)
                                                    userInfo:nil
                                                     repeats:YES];
    [timer fire];
    return self;
}

- (void) syncPaint:(NSTimer *)timer
{
    Q_UNUSED(timer);
    if (!g_animate)
        return;
    [self setNeedsDisplay:YES];
    if (self.window.isVisible)
        [self displayIfNeeded];
}

- (void)drawRect: (NSRect)dirtyRect
{
    [[NSColor colorWithDeviceRed:0.5 green:0.2 blue:0.2 alpha:1.0] setFill];
    NSRectFill(dirtyRect);
    [super drawRect:dirtyRect];
}

@end


