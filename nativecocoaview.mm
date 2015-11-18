#import "nativecocoaview.h"

#include <QtCore/QtCore>
#include <QtGui/QtGui>

@implementation NativeCocoaView

- (id) init
{
    [super init];
    [self setWantsLayer: true];
    return self;
}

- (void)drawRect: (NSRect)dirtyRect
{
    [[NSColor grayColor] setFill];
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


@implementation ControllerView

- (id)initWithView: (NSView *) view
{
    [super init];
    [self init];

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
- (id)init
{
    [super init];
    [self setWantsLayer: true];
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
    [super init];
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
    QSize contentiSize(200, 200);
    QImage content(contentiSize, QImage::Format_ARGB32_Premultiplied);
    QPainter p(&content);
    p.fillRect(QRect(QPoint(0,0), contentiSize), Qt::red);
    self.layer.contents = content.toNSImage();
}

- (void)drawRect: (NSRect)dirtyRect
{
    qWarning("RasterLayerView:drawRect: Unexpected this is"); // drawRect should not be called.
    [super drawRect: dirtyRect];
}

@end

