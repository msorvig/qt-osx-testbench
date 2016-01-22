
#import <Cocoa/Cocoa.h>


// A Simple NSView that fills with solid color and prints
// Mouse and Keyboard events.
@interface TestBenchContentView : NSView
{

}
@end

// A "window manager" view that gives the contained
// a border for dragging and resizing
@interface TestBenchMDIView : NSView
{
    NSView *controlledView;
    bool isMove;
}
- (id) initWithView: (NSView *) view;
@end

// A View that provides raster layer content
@class QPainterLayer;
@interface RasterLayerView : NSView
{
    QPainterLayer *m_layer;
}
@end

// A View that provides OPenGL layer content
@class QOpenGLLayer;
@interface OpenGLLayerView : NSView
{
    QOpenGLLayer *m_layer;
}
@end

// An animated NSOpenGLView subclass
@interface AnimatedOpenGLVew : NSOpenGLView
{
    CVDisplayLinkRef m_displayLink;
    int frame;
}
@end

// NSView with attached OPenGL context, similar to the QCocoaWindow implementation
@interface OpenGLNSView : NSView
{
    CVDisplayLinkRef m_displayLink;
    NSOpenGLContext *m_glcontext;
    NSSize m_currentViewportSize;
    int frame;
}
@end

// A view that tries to draw at 120 fps.
@interface Native120fpsView : NSView
{

}
@end

