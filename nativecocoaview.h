
#import <Cocoa/Cocoa.h>


// A Simple NSView that fills with solid color and prints
// Mouse and Keyboard events.
@interface NativeCocoaView : NSView
{

}
@end

// A "window manager" view that gives the contained
// a border for dragging and resizing
@interface ControllerView : NSView
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
class QOpenGLLayer;
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

