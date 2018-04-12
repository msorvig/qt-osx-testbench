
#import "object.h"

CustomObject *vendObjectAutoreleased(NSString *name) __attribute__((ns_returns_autoreleased));
CustomObject *vendObjectRetained(NSString *name) __attribute__((ns_returns_retained));
CustomObject *vendObjectUnretained(NSString *name);
