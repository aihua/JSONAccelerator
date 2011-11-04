//
//  ClassBaseObject.m
//  JSONModeler
//
//  Created by Jon Rexeisen on 11/4/11.
//  Copyright (c) 2011 Nerdery Interactive Labs. All rights reserved.
//

#import "ClassBaseObject.h"
#import "ClassPropertiesObject.h"

@implementation ClassBaseObject

@synthesize className = _className;
@synthesize baseClass = _baseClass;
@synthesize properties = _properties;

- (id) init
{
    self = [super init];
    if(self) {
        self.properties = [NSMutableArray array];
    }
    
    return self;
}

- (NSString *) headerStringWithHeader: (NSString *) headerString
{
    NSString *returnString = [[NSString alloc] initWithString:headerString];
    returnString = [returnString stringByAppendingString:@"\n\n#import <Foundation/Foundation.h>\n\n"];
    
    // First we need to find if there are any class properties, if so do the @Class business
    NSString *forwardDeclarationString = @"";
    for(ClassPropertiesObject *property in _properties) {
        if([property isClass]) {
            if([forwardDeclarationString isEqualToString:@""]) {
                forwardDeclarationString = [NSString stringWithFormat:@"@class %@", [[property name] capitalizedString]]; 
            } else {
                forwardDeclarationString = [forwardDeclarationString stringByAppendingFormat:@", %@", [[property name] capitalizedString]];
            }
        }
    }
        
    if([forwardDeclarationString isEqualToString:@""] == NO) {
        returnString = [returnString stringByAppendingFormat:@"%@;", forwardDeclarationString];
        returnString = [returnString stringByAppendingString:@"\n\n"];
    }
    
    returnString = [returnString stringByAppendingFormat:@"@interface %@ : %@\n\n", _className, _baseClass];
    
    for(ClassPropertiesObject *property in _properties) {
        returnString = [returnString stringByAppendingFormat:@"%@\n", property];
    }
    
    returnString = [returnString stringByAppendingFormat:@"\n+ (%@ *) initWithDictionary: (NSDictionary *) dict", _className];
    returnString = [returnString stringByAppendingString:@"\n- (void) importDictionary: (NSDictionary *) dict"];
        
    returnString = [returnString stringByAppendingString:@"\n@end"];
    
    return returnString;
}

- (NSString *) implementationStringWithHeader: (NSString *) headerString
{
    return @"";
}

@end
