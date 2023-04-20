#import "OAISchemaCharacteristicProperties.h"

@implementation OAISchemaCharacteristicProperties

- (instancetype)init {
  self = [super init];
  if (self) {
    // initialize property's default value, if any
    
  }
  return self;
}


/**
 * Maps json key to property name.
 * This method is used by `JSONModel`.
 */
+ (JSONKeyMapper *)keyMapper {
  return [[JSONKeyMapper alloc] initWithModelToJSONDictionary:@{ @"broadcast": @"broadcast", @"read": @"read", @"writeWithoutResponse": @"write_without_response", @"write": @"write", @"notify": @"notify", @"indicate": @"indicate", @"authenticatedSignedWrites": @"authenticated_signed_writes", @"extendedProperties": @"extended_properties", @"notifyEncryptionRequired": @"notify_encryption_required", @"indicateEncryptionRequired": @"indicate_encryption_required" }];
}

/**
 * Indicates whether the property with the given name is optional.
 * If `propertyName` is optional, then return `YES`, otherwise return `NO`.
 * This method is used by `JSONModel`.
 */
+ (BOOL)propertyIsOptional:(NSString *)propertyName {

  NSArray *optionalProperties = @[];
  return [optionalProperties containsObject:propertyName];
}

@end
