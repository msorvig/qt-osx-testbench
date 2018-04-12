#include "vendor.h"

CustomObject *vendObjectAutoreleased(NSString *name)
{
    CustomObject *obj = [[CustomObject alloc] init:name];
    return [obj autorelease]; // No ownership transfer; object is autoreleased.
}

CustomObject *vendObjectRetained(NSString *name)
{
    CustomObject *obj = [[CustomObject alloc] init:name];
    return obj; // Transfer ownership of this reference
}

CustomObject *vendObjectUnretained(NSString *name)
{
    CustomObject *obj = [[CustomObject alloc] init:name];
    return obj; // No ownership transfer; object is released manually later on
}

