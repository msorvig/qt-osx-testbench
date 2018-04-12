#include <stdio.h>

#import "object.h"
#import "vendor.h"

int main(int argc, char **argv)
{
    // Some experiments with ARC. ARC is enabled for this file. vendor.mm uses manual
    // reference counting. object.mm does not hold references to itself. The expected
    // behavior is that all CustomObject instances are released (they log from dealloc)
    // at a determinisitc point, and that there are no double-deallocs.
    
    __weak CustomObject *weak; // weak pointers do not prevent dealloc
    {
        // NSObject pointers on stack deref their objects when going out of scope
        NSLog(@"on arc stack");
        CustomObject *obj = [[CustomObject alloc] init:@"on-arc-stack"];
        weak = obj;
    }

    NSLog(@" ");
    {
        CustomObject *strong;
        @autoreleasepool {
            // (ns_returns_autoreleased) guarantees that the vended object is live
            // for the scope of the most inner @autoreleasepool.
            __weak CustomObject *weak;
            {
                NSLog(@"return vendObjectAutoreleased");
                CustomObject *vended = vendObjectAutoreleased(@"vended-autoreleased");
                weak = vended;
            }
            NSLog(@"fell off inner scope");
            // At this point there are no strong ARC references to the object. It
            // is autoreleased and kept live by the @autoreleasepool.
            
            // Form a new strong reference to the object to keep it live when autoreleased.
            strong = weak;
        }
        NSLog(@"fell off autoreleasepool scope");
        // Object will be deallocated when exiting scope
    }
    NSLog(@"fell off outer scope");

    NSLog(@" ");
    {
        // (ns_returns_retained) functions transfer ownership of a +1 retain count
        NSLog(@"return vendObjectRetained");
        CustomObject *vended = vendObjectRetained(@"vended-retained");
        // will be dealloced when exiting scope
    }
    NSLog(@"fell off scope");
    
    NSLog(@" ");
    // autorelease is not strictly needed if the vendor can guarantee that that
    // the object stays live across the return from the vendor function.
    NSLog(@"vendObject");
    {
        __weak CustomObject *vended = vendObjectUnretained(@"vended");
        // No strong ARC references exist at this point; the object may be deallocated immedeately:
        // [vended letGo]; // <- will dealloc
        
        // Form a new strong reference to the object to keep it live when
        // the vendor releases it.
        CustomObject *strong = vended;

        // Release the vendor reference
        NSLog(@"vended release");
        [vended letGo];

        // The object will be deallocated when strong goes out of scope and ARC releases it.
        NSLog(@"fall off scope");
    }    
    NSLog(@"fell off scope");
    
    return 0;
}