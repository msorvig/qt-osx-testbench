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
    NSPoint position = [self convertPoint:[ev locationInWindow] fromView:nil];

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
@implementation RasterLayerView

- (id)init
{
    [super init];
    [self setWantsLayer: true];
    return self;
}

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
    qFatal("Unexpected this is"); // drawRect should not be called.
    [super drawRect: dirtyRect];
}

@end

