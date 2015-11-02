
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
