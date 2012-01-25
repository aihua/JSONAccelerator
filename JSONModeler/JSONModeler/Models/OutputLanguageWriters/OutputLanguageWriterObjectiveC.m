//
//  OutputLanguageWriterObjectiveC.m
//  JSONModeler
//
//  Created by Jon Rexeisen on 1/19/12.
//  Copyright (c) 2012 Nerdery Interactive Labs. All rights reserved.
//

#import "OutputLanguageWriterObjectiveC.h"
#import "ClassBaseObject.h"
#import <AddressBook/AddressBook.h>

@interface OutputLanguageWriterObjectiveC ()

- (NSString *) ObjC_HeaderFileForClassObject:(ClassBaseObject *)classObject;
- (NSString *) ObjC_ImplementationFileForClassObject:(ClassBaseObject *)classObject useARC:(BOOL)useARCFlag;

@end

@implementation OutputLanguageWriterObjectiveC
//@synthesize classObject = _classObject;

#pragma mark - File Writing Methods

- (BOOL)writeClassObjects:(NSDictionary *)classObjectsDict toURL:(NSURL *)url options:(NSDictionary *)options generatedError:(BOOL *)generatedErrorFlag
{
    BOOL filesHaveHadError = NO;
    BOOL filesHaveBeenWritten = NO;
    
    NSArray *files = [classObjectsDict allValues];
    
    /* Determine whether or not to build for ARC */
    BOOL buildForARC;
    if (nil != [options objectForKey:kObjectiveCWritingOptionUseARC]) {
        buildForARC = [[options objectForKey:kObjectiveCWritingOptionUseARC] boolValue];
    }
    else {
        /* Default to not building for ARC */
        buildForARC = NO;
    }
    
    for(ClassBaseObject *base in files) {
        
        // This section is to guard against people going through and renaming the class
        // to something that has already been named.
        // This will check the class name and keep appending an additional number until something has been found
        if([[base className] isEqualToString:@"InternalBaseClass"]) {
            NSString *newBaseClassName;
            if (nil != [options objectForKey:kObjectiveCWritingOptionBaseClassName]) {
                newBaseClassName = [options objectForKey:kObjectiveCWritingOptionBaseClassName];
            }
            else {
                newBaseClassName = @"BaseClass";
            }
            BOOL hasUniqueFileNameBeenFound = NO;
            NSUInteger classCheckInteger = 2;
            while (hasUniqueFileNameBeenFound == NO) {
                hasUniqueFileNameBeenFound = YES;
                for(ClassBaseObject *collisionBaseObject in files) {
                    if([[collisionBaseObject className] isEqualToString:newBaseClassName]) {
                        hasUniqueFileNameBeenFound = NO; 
                    }
                }
                if(hasUniqueFileNameBeenFound == NO) {
                    newBaseClassName = [NSString stringWithFormat:@"%@%i", newBaseClassName, classCheckInteger];
                    classCheckInteger++;
                }
            }
            
            [base setClassName:newBaseClassName];
        }
        
        /* Write the h file to disk */
        NSError * hFileError;
        NSString *outputHFile = [self ObjC_HeaderFileForClassObject:base];
        NSString *hFilename = [NSString stringWithFormat:@"%@.h", base.className];
        
        [outputHFile writeToURL:[url URLByAppendingPathComponent:hFilename]
                      atomically:YES
                        encoding:NSUTF8StringEncoding 
                           error:&hFileError];
        if(hFileError) {
            DLog(@"%@", [hFileError localizedDescription]);
            filesHaveHadError = YES;
        } else {
            filesHaveBeenWritten = YES;
        }
        
        /* Write the m file to disk */
        NSError * mFileError;
        NSString *outputMFile = [self ObjC_ImplementationFileForClassObject:base useARC:buildForARC];
        NSString *mFilename = [NSString stringWithFormat:@"%@.m", base.className];
        
        [outputMFile writeToURL:[url URLByAppendingPathComponent:mFilename]
                     atomically:YES
                       encoding:NSUTF8StringEncoding 
                          error:&mFileError];
        if(mFileError) {
            DLog(@"%@", [mFileError localizedDescription]);
            filesHaveHadError = YES;
        } else {
            filesHaveBeenWritten = YES;
        }
    }
    
    /* Return the error flag (by reference) */
    *generatedErrorFlag = filesHaveHadError;
    
    
    return filesHaveBeenWritten;
}

- (NSDictionary *) getOutputFilesForClassObject:(ClassBaseObject *)classObject
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    // Defaults to not use ARC. This should probably be updated at some point.
    
    [dict setObject:[self ObjC_HeaderFileForClassObject:classObject] forKey:[NSString stringWithFormat:@"%@.h", classObject.className]];
    [dict setObject:[self ObjC_ImplementationFileForClassObject:classObject useARC:NO] forKey:[NSString stringWithFormat:@"%@.m", classObject.className]];        
    
    return [NSDictionary dictionaryWithDictionary:dict];

}

- (NSString *) ObjC_HeaderFileForClassObject:(ClassBaseObject *)classObject
{
    NSBundle *mainBundle = [NSBundle mainBundle];
    
    NSString *interfaceTemplate = [mainBundle pathForResource:@"InterfaceTemplate" ofType:@"txt"];
    NSString *templateString = [[NSString alloc] initWithContentsOfFile:interfaceTemplate encoding:NSUTF8StringEncoding error:nil];
    
    templateString = [templateString stringByReplacingOccurrencesOfString:@"{CLASSNAME}" withString:classObject.className];
    
    /* Set the date */
    NSDate *currentDate = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterShortStyle];
    
    templateString = [templateString stringByReplacingOccurrencesOfString:@"{DATE}" withString:[dateFormatter stringFromDate:currentDate]];
    
    /* Set the name and company values in the template from the current logged in user's address book information */
    ABAddressBook *addressBook = [ABAddressBook sharedAddressBook];
    ABPerson *me = [addressBook me];
    NSString *meFirstName = [me valueForProperty:kABFirstNameProperty];
    NSString *meLastName = [me valueForProperty:kABLastNameProperty];
    NSString *meCompany = [me valueForProperty:kABOrganizationProperty];
    
    templateString = [templateString stringByReplacingOccurrencesOfString:@"__NAME__" withString:[NSString stringWithFormat:@"%@ %@", meFirstName, meLastName]];
    templateString = [templateString stringByReplacingOccurrencesOfString:@"__company_name__" withString:[NSString stringWithFormat:@"%@ %@", [currentDate descriptionWithCalendarFormat:@"%Y" timeZone:nil locale:nil] , meCompany]];
    
    // First we need to find if there are any class properties, if so do the @Class business
    NSString *forwardDeclarationString = @"";
    
    for(ClassPropertiesObject *property in [classObject.properties allValues]) {
        if([property isClass]) {
            if([forwardDeclarationString isEqualToString:@""]) {
                forwardDeclarationString = [NSString stringWithFormat:@"@class %@", [[property referenceClass] className]]; 
            } else {
                forwardDeclarationString = [forwardDeclarationString stringByAppendingFormat:@", %@", [[property referenceClass] className]];
            }
        }
    }
    
    if([forwardDeclarationString isEqualToString:@""] == NO) {
        forwardDeclarationString = [forwardDeclarationString stringByAppendingString:@";"];        
    }
    
    templateString = [templateString stringByReplacingOccurrencesOfString:@"{FORWARD_DECLARATION}" withString:forwardDeclarationString];
    templateString = [templateString stringByReplacingOccurrencesOfString:@"{BASEOBJECT}" withString:classObject.baseClass];
    
    NSString *propertyString = @"";
    for(ClassPropertiesObject *property in [classObject.properties allValues]) {
        propertyString = [propertyString stringByAppendingFormat:@"%@\n", property];
    }
    
    templateString = [templateString stringByReplacingOccurrencesOfString:@"{PROPERTIES}" withString:propertyString];
    
    return templateString;
}

- (NSString *) ObjC_ImplementationFileForClassObject:(ClassBaseObject *)classObject useARC:(BOOL)useARCFlag
{
    NSBundle *mainBundle = [NSBundle mainBundle];
    
    NSString *implementationTemplate = [mainBundle pathForResource:@"ImplementationTemplate" ofType:@"txt"];
    NSString *templateString = [[NSString alloc] initWithContentsOfFile:implementationTemplate encoding:NSUTF8StringEncoding error:nil];
    
    NSDate *currentDate = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterShortStyle];
    
    // Need to check for ARC to tell whether or not to use autorelease or not
    if(useARCFlag) {
        // Uses ARC
        templateString = [templateString stringByReplacingOccurrencesOfString:@"{CLASSNAME_INIT}" withString:@"[[{CLASSNAME} alloc] init]"];
    } else {
        // Doesn't use ARC
        templateString = [templateString stringByReplacingOccurrencesOfString:@"{CLASSNAME_INIT}" withString:@"[[[{CLASSNAME} alloc] init] autorelease]"];
    }
    
    
    // IMPORTS
    NSMutableArray *importArray = [NSMutableArray array];
    NSString *importString = @"";
    for(ClassPropertiesObject *property in [classObject.properties allValues]) {
        if([property isClass]) {
            [importArray addObject:[[property referenceClass] className]];
        }
        
        // Check References
        NSArray *referenceArray = [self setterReferenceClassesForProperty:property];
        for(NSString *referenceString in referenceArray) {
            if(![importArray containsObject:referenceString]) {
                [importArray addObject:referenceString];
            }
        }
    }
    
    for(NSString *referenceImport in importArray) {
        importString = [importString stringByAppendingFormat:@"#import \"%@.h\"\n", referenceImport];
    }
    
    
    // SYNTHESIZE
    NSString *sythesizeString = @"";
    for(ClassPropertiesObject *property in [classObject.properties allValues]) {
        sythesizeString = [sythesizeString stringByAppendingFormat:@"@synthesize %@ = _%@;\n", property.name, property.name];
    }
    
    // SETTERS
    NSString *settersString = @"";
    for(ClassPropertiesObject *property in [classObject.properties allValues]) {
        
        settersString = [settersString stringByAppendingString:[self setterForProperty:property]];
    }
    
    // NSCODING SECTION
    NSString *initWithCoderString = @"";
    for (ClassPropertiesObject *property in [classObject.properties allValues]) {
        switch (property.type) {
            case PropertyTypeInt:
                initWithCoderString = [initWithCoderString stringByAppendingString:[NSString stringWithFormat:@"\n    self.%@ = [aDecoder decodeIntegerForKey:@\"%@\"];", property.name, property.name]];
                break;
            case PropertyTypeDouble:
                initWithCoderString = [initWithCoderString stringByAppendingString:[NSString stringWithFormat:@"\n    self.%@ = [aDecoder decodeDoubleForKey:@\"%@\"];", property.name, property.name]];
                break;
            case PropertyTypeBool:
                initWithCoderString = [initWithCoderString stringByAppendingString:[NSString stringWithFormat:@"\n    self.%@ = [aDecoder decodeBoolForKey:@\"%@\"];", property.name, property.name]];
                break;
            default:
                initWithCoderString = [initWithCoderString stringByAppendingString:[NSString stringWithFormat:@"\n    self.%@ = [aDecoder decodeObjectForKey:@\"%@\"];", property.name, property.name]];
                break;
        }
    }
    
    
    NSString *encodeWithCoderString = @"";
    for (ClassPropertiesObject *property in [classObject.properties allValues]) {
        switch (property.type) {
            case PropertyTypeInt:
                encodeWithCoderString = [encodeWithCoderString stringByAppendingString:[NSString stringWithFormat:@"\n    [aCoder encodeInteger:_%@ forKey:@\"%@\"];", property.name, property.name]];
                break;
            case PropertyTypeDouble:
                encodeWithCoderString = [encodeWithCoderString stringByAppendingString:[NSString stringWithFormat:@"\n    [aCoder encodeDouble:_%@ forKey:@\"%@\"];", property.name, property.name]];
                break;
            case PropertyTypeBool:
                encodeWithCoderString = [encodeWithCoderString stringByAppendingString:[NSString stringWithFormat:@"\n    [aCoder encodeBool:_%@ forKey:@\"%@\"];", property.name, property.name]];
                break;
            default:
                encodeWithCoderString = [encodeWithCoderString stringByAppendingString:[NSString stringWithFormat:@"\n    [aCoder encodeObject:_%@ forKey:@\"%@\"];", property.name, property.name]];
                break;
        }
    }
    
    // DEALLOC SECTION
    NSString *deallocString = @"";
    
    /* Add dealloc method only if not building for ARC */
    if(useARCFlag) {
        deallocString = @"\n- (void)dealloc\n{\n";
        for(ClassPropertiesObject *property in [classObject.properties allValues]) {
            if([property type] != PropertyTypeInt && [property type] != PropertyTypeDouble && [property type] != PropertyTypeBool){
                deallocString = [deallocString stringByAppendingString:[NSString stringWithFormat:@"    [_%@ release];\n", property.name]];
            }
        }
        deallocString = [deallocString stringByAppendingString:@"    [super dealloc];\n}\n"];
    }
    
    /* Set the name and company values in the template from the current logged in user's address book information */
    ABAddressBook *addressBook = [ABAddressBook sharedAddressBook];
    ABPerson *me = [addressBook me];
    NSString *meFirstName = [me valueForProperty:kABFirstNameProperty];
    NSString *meLastName = [me valueForProperty:kABLastNameProperty];
    NSString *meCompany = [me valueForProperty:kABOrganizationProperty];
    
    templateString = [templateString stringByReplacingOccurrencesOfString:@"__NAME__" withString:[NSString stringWithFormat:@"%@ %@", meFirstName, meLastName]];
    templateString = [templateString stringByReplacingOccurrencesOfString:@"__company_name__" withString:[NSString stringWithFormat:@"%@ %@", [currentDate descriptionWithCalendarFormat:@"%Y" timeZone:nil locale:nil] , meCompany]];
    
    /* Set other template strings */
    templateString = [templateString stringByReplacingOccurrencesOfString:@"{CLASSNAME}" withString:classObject.className];
    templateString = [templateString stringByReplacingOccurrencesOfString:@"{DATE}" withString:[dateFormatter stringFromDate:currentDate]];
    templateString = [templateString stringByReplacingOccurrencesOfString:@"{IMPORT_BLOCK}" withString:importString];    
    templateString = [templateString stringByReplacingOccurrencesOfString:@"{SYNTHESIZE_BLOCK}" withString:sythesizeString];
    templateString = [templateString stringByReplacingOccurrencesOfString:@"{SETTERS}" withString:settersString];
    templateString = [templateString stringByReplacingOccurrencesOfString:@"{INITWITHCODER}" withString:initWithCoderString];
    templateString = [templateString stringByReplacingOccurrencesOfString:@"{ENCODEWITHCODER}" withString:encodeWithCoderString];
    templateString = [templateString stringByReplacingOccurrencesOfString:@"{DEALLOC}" withString:deallocString];
    
    return templateString;
}

#pragma mark - Property Writing Methods

- (NSString *)propertyForProperty:(ClassPropertiesObject *) property
{
    NSString *returnString = @"@property (";
    if(property.isAtomic == NO) {
        returnString = [returnString stringByAppendingString:@"nonatomic, "];
    }
    
    if(property.isReadWrite == NO) {
        returnString = [returnString stringByAppendingString:@"readonly, "];
    }
    
    switch (property.semantics) {
        case SetterSemanticStrong:
            returnString = [returnString stringByAppendingString:@"strong"];
            break;
        case SetterSemanticWeak:
            returnString = [returnString stringByAppendingString:@"weak"];
            break;
        case SetterSemanticAssign:
            returnString = [returnString stringByAppendingString:@"assign"];
            break;
        case SetterSemanticRetain:
            returnString = [returnString stringByAppendingString:@"retain"];
            break;
        case SetterSemanticCopy:
            returnString = [returnString stringByAppendingString:@"copy"];
            break;
        default:
            break;
    }
    
    returnString = [returnString stringByAppendingFormat:@") %@ %@%@;", [self typeStringForProperty:property], (property.semantics != SetterSemanticAssign) ? @"*" : @"" , property.name];
    
    return returnString;

}

- (NSString *)setterForProperty:(ClassPropertiesObject *)  property
{
    NSString *setterString = @"";
    if(property.isClass && (property.type == PropertyTypeDictionary || property.type == PropertyTypeClass)) {
#warning Need to do testing to make sure the set object is of type of dictionary
        setterString = [setterString stringByAppendingFormat:@"    self.%@ = [%@ initWithDictionary:[dict objectForKey:@\"%@\"]];\n", property.name, property.referenceClass.className, property.jsonName];
    } else if(property.type == PropertyTypeArray && property.referenceClass != nil) {
        NSBundle *mainBundle = [NSBundle mainBundle];
        
        NSString *interfaceTemplate = [mainBundle pathForResource:@"ArraySetterTemplate" ofType:@"txt"];
        NSString *templateString = [[NSString alloc] initWithContentsOfFile:interfaceTemplate encoding:NSUTF8StringEncoding error:nil];
        templateString = [templateString stringByReplacingOccurrencesOfString:@"{JSONNAME}" withString:property.jsonName];
        templateString = [templateString stringByReplacingOccurrencesOfString:@"{SETTERNAME}" withString:property.name];
        setterString = [templateString stringByReplacingOccurrencesOfString:@"{REFERENCE_CLASS}" withString:property.referenceClass.className];
        
    } else {
        setterString = [setterString stringByAppendingString:[NSString stringWithFormat:@"    self.%@ = ", property.name]];
        if([property type] == PropertyTypeInt) {
            setterString = [setterString stringByAppendingFormat:@"[[dict objectForKey:@\"%@\"] intValue];\n", property.jsonName];
        } else if([property type] == PropertyTypeDouble) {
            setterString = [setterString stringByAppendingFormat:@"[[dict objectForKey:@\"%@\"] doubleValue];\n", property.jsonName]; 
        } else if([property type] == PropertyTypeBool) {
            setterString = [setterString stringByAppendingFormat:@"[[dict objectForKey:@\"%@\"] boolValue];\n", property.jsonName]; 
        } else {
            setterString = [setterString stringByAppendingFormat:@"[dict objectForKey:@\"%@\"];\n", property.jsonName];
        }
    }
    return setterString;
}

- (NSString *)getterForProperty:(ClassPropertiesObject *) property
{
    return @"";
}

- (NSArray *)setterReferenceClassesForProperty:(ClassPropertiesObject *)  property
{
    NSMutableArray *array = [NSMutableArray array];

    if(property.referenceClass != nil) {
        [array addObject:property.referenceClass.className];
    }

    return [NSArray arrayWithArray:array];

}

- (NSString *)typeStringForProperty:(ClassPropertiesObject *)  property
{
    switch (property.type) {
        case PropertyTypeString:
            return @"NSString";
            break;
        case PropertyTypeArray:
            return @"NSArray";
            break;
        case PropertyTypeDictionary:
            return @"NSDictionary";
            break;
        case PropertyTypeInt:
            return @"NSInteger";
            break;
        case PropertyTypeBool:
            return @"BOOL";
            break;
        case PropertyTypeDouble:
            return @"double";
            break;
        case PropertyTypeClass:
            return property.referenceClass.className;
            break;
        case PropertyTypeOther:
            return property.otherType;
            break;
            
        default:
            break;
    }
}


@end