
#import <Cocoa/Cocoa.h>

@interface NativeCocoaView : NSView
{

}
@end

@interface ControllerView : NSView
{
    NSView *controlledView;
    bool isMove;
}
- (id) initWithView: (NSView *) view;

@end
