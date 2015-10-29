
#import <Cocoa/Cocoa.h>

@interface NativeCocoaView : NSView
{

}
@end

@interface ControllerView : NSView
{
    NSView *controlledView;
}
- (id) initWithView: (NSView *) view;

@end
