#include <Foundation/Foundation.h>

@interface CustomObject : NSObject

@property (retain) NSString *name;

-(id) init:(NSString *)name;
-(void) letGo;

@end