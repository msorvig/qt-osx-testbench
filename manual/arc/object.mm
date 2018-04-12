#include <stdio.h>

#import "object.h"

@implementation CustomObject

@synthesize name;

-(id) init:(NSString *)aName
{
    if (self = [super init]) {
        self.name = aName;
    }
    return self;
}

-(void) letGo
{
    [self release];
}

-(void) dealloc {
    [super dealloc];
    NSLog(@"dealloc %@", name);
}

@end