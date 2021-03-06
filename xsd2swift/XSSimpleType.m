/*
xsd2swift: Command line tool to convert XML schemas to Swift classes.
Copyright (C) 2017  Steven E Wright

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

//
//  XSSimpleTypeTemplate.m
//  xsd2cocoa
//
//  Created by Stefan Winter on 11.08.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "xsd2swift/XSSimpleType.h"
#import "third_party/MGTemplateEngine/ICUTemplateMatcher.h"
#import "third_party/MGTemplateEngine/MGTemplateEngine.h"
#import "xsd2swift/XMLUtils.h"
#import "xsd2swift/XSDattribute.h"
#import "xsd2swift/XSDenumeration.h"
#import "xsd2swift/XSDschema.h"

@interface XSSimpleType ()
@property(strong, nonatomic) NSString* name;
@property(strong, nonatomic) NSString* baseType;
@property(strong, nonatomic) NSArray* attributes;
//@property (strong, nonatomic) NSArray* globalElements;
@property(strong, nonatomic) NSString* targetClassName;
@property(strong, nonatomic) NSString* arrayType;
//@property (strong, nonatomic) NSString* readEnumerationTemplate;
@property(strong, nonatomic) NSString* readAttributeTemplate;
@property(strong, nonatomic) NSString* readElementTemplate;
@property(strong, nonatomic) NSString* readValueCode;
@property(strong, nonatomic) NSString* readPrefixCode;
@property(strong, nonatomic) NSString* writeAttributeTemplate;
@property(strong, nonatomic) NSString* writeElementTemplate;
@property(strong, nonatomic) NSString* writeValueCode;
@property(strong, nonatomic) NSString* writePrefixCode;
@property(strong, nonatomic) NSArray* includes;

@property(strong, nonatomic) NSString* enumReadAttributeTemplate;
@property(strong, nonatomic) NSString* enumReadElementTemplate;
@property(strong, nonatomic) NSString* enumReadValueCode;
@property(strong, nonatomic) NSString* enumReadPrefixCode;

@property(strong, nonatomic) NSString* enumWriteAttributeTemplate;
@property(strong, nonatomic) NSString* enumWriteElementTemplate;
@property(strong, nonatomic) NSString* enumWriteValueCode;
@property(strong, nonatomic) NSString* enumWritePrefixCode;

@property(strong, nonatomic) NSArray* globalElements;

@end

@implementation XSSimpleType {
  MGTemplateEngine* engine;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _globalElements = [NSMutableArray array];
  }
  return self;
}

- (id)initWithNode:(NSXMLElement*)node schema:(XSDschema*)schema {
  self = [super initWithNode:node schema:schema];
  /* Continute to add items to the extended XSSchemaNode class */
  if (self) {
    /* Setup the engine for the templating */
    engine = [MGTemplateEngine templateEngine];
    [engine setMatcher:[ICUTemplateMatcher matcherWithTemplateEngine:engine]];

    /* Grab the name from the current element */
    self.name = [XMLUtils node:node stringAttribute:@"name"];

    /* Check if the element is an extension or a restriction */
    NSArray* elementTags = [XMLUtils node:node childrenWithName:@"extension"];
    if ([elementTags count] == 0) {
      elementTags = [XMLUtils node:node childrenWithName:@"restriction"];
    }

    /* Iterate through the children of the element tag (if there are any)*/
    for (NSXMLElement* anElement in elementTags) {
      /* Set the baseType here */
      self.baseType = [XMLUtils node:anElement stringAttribute:@"base"];

      /* Check if we have an enumeration and assign it to our simpleType object */
      NSMutableArray* newEnumerations = [NSMutableArray array];
      NSArray* enumerationTags = [XMLUtils node:anElement childrenWithName:@"enumeration"];
      for (NSXMLElement* anElement in enumerationTags) {
        [newEnumerations addObject:[[XSDenumeration alloc] initWithNode:anElement schema:schema]];
      }

      /* Assign the list of enumerations that we have found to the simply type element */
      self.enumerations = newEnumerations;

      /* Check if we have attributes for this element and assign it to the element */
      NSMutableArray* newAttributes = [NSMutableArray array];
      NSArray* attributeTags = [XMLUtils node:anElement childrenWithName:@"attribute"];
      for (NSXMLElement* anElement in attributeTags) {
        [newAttributes addObject:[[XSDattribute alloc] initWithNode:anElement schema:schema]];
      }

      /* Assign the list of attributes that we have found to the simply type element */
      self.attributes = newAttributes;
    }
  }

  return self;
}

- (id)initWithName:(NSString*)name baseType:(NSString*)baseType schema:(XSDschema*)schema {
  self = [super initWithNode:nil schema:schema];
  if (self) {
    engine = [MGTemplateEngine templateEngine];
    [engine setMatcher:[ICUTemplateMatcher matcherWithTemplateEngine:engine]];

    self.name = name;
    self.baseType = baseType;
  }

  return self;
}

- (XSSimpleType*)typeForTemplate {
  XSSimpleType* t = self;

  while (!t->_targetClassName && t->_baseType) {
    XSSimpleType* nT = (XSSimpleType*)[t.schema typeForName:t->_baseType];
    if (nT == t) {
      // same type
      break;
    }
    t = nT;
  }

  return t;
}

- (NSString*)targetClassName {
  XSSimpleType* t = self.typeForTemplate;
  return t->_targetClassName;
}

- (NSString*)targetClassFileName {
  return self.targetClassName;
}

- (NSString*)arrayType {
  XSSimpleType* t = self.typeForTemplate;
  return t->_arrayType;
}

#pragma mark template matching
/**
 * Name: supplyTemplate
 * Parameters:  (NSXMLElement *) - the element from the template that is used in the XSD.
 * (NSXMLNode*) - the node with the read codes for processing enums (NSError *) - For error handling
 * Returns:     If it was successful in writing the items to the object
 * Description: When given the template value, iterate through the simpleType in the template
 *              and grab the values about the element type that will define the Objective-C code
 *              and assign it to the object that it is pointed at
 */
- (BOOL)supplyTemplates:(NSXMLElement*)element
           enumTypeNode:(NSXMLNode*)enumTypeNode
                  error:(NSError* __autoreleasing*)error {
  engine = [MGTemplateEngine templateEngine];
  [engine setMatcher:[ICUTemplateMatcher matcherWithTemplateEngine:engine]];

  self.targetClassName = [[element attributeForName:@"objType"] stringValue];
  self.arrayType = [[element attributeForName:@"arrayType"] stringValue];
  self.name = [[element attributeForName:@"name"] stringValue];

  /* Grab the prefix from the matching element type in our template to the current simple type in
   * our XSD */
  NSArray* readPrefixNodes = [element nodesForXPath:@"read[1]/prefix[1]" error:error];
  if (*error != nil) {
    return NO;
  }
  if (readPrefixNodes.count > 0) {
    self.readPrefixCode = [[readPrefixNodes objectAtIndex:0] stringValue];
  }
  /*  */
  NSArray* readAttributeNodes = [element nodesForXPath:@"read[1]/attribute[1]" error:error];
  if (*error != nil) {
    return NO;
  }
  if (readAttributeNodes.count > 0) {
    NSString* temp = [[readAttributeNodes objectAtIndex:0] stringValue];
    self.readAttributeTemplate = temp;
  }
  /*  */
  NSArray* readElementNodes = [element nodesForXPath:@"read[1]/element[1]" error:error];
  if (*error != nil) {
    return NO;
  }
  if (readElementNodes.count > 0) {
    self.readElementTemplate = [[readElementNodes objectAtIndex:0] stringValue];
  }
  /*  */
  NSArray* valueElementNodes = [element nodesForXPath:@"read[1]/value[1]" error:error];
  if (*error != nil) {
    return NO;
  }
  if (valueElementNodes.count > 0) {
    self.readValueCode = [[valueElementNodes objectAtIndex:0] stringValue];
  }
  /*  */

  /* Grab the prefix from the matching element type in our template to the current simple type in
   * our XSD */
  NSArray* writePrefixNodes = [element nodesForXPath:@"write[1]/prefix[1]" error:error];
  if (*error != nil) {
    return NO;
  }
  if (writePrefixNodes.count > 0) {
    self.writePrefixCode = [[writePrefixNodes objectAtIndex:0] stringValue];
  }
  /*  */
  NSArray* writeAttributeNodes = [element nodesForXPath:@"write[1]/attribute[1]" error:error];
  if (*error != nil) {
    return NO;
  }
  if (writeAttributeNodes.count > 0) {
    NSString* temp = [[writeAttributeNodes objectAtIndex:0] stringValue];
    self.writeAttributeTemplate = temp;
  }
  /*  */
  NSArray* writeElementNodes = [element nodesForXPath:@"write[1]/element[1]" error:error];
  if (*error != nil) {
    return NO;
  }
  if (writeElementNodes.count > 0) {
    self.writeElementTemplate = [[writeElementNodes objectAtIndex:0] stringValue];
  }
  /*  */
  NSArray* writeValueElementNodes = [element nodesForXPath:@"write[1]/value[1]" error:error];
  if (*error != nil) {
    return NO;
  }
  if (writeValueElementNodes.count > 0) {
    self.writeValueCode = [[writeValueElementNodes objectAtIndex:0] stringValue];
  }
  /*  */

  NSArray* includeElementNodes = [element nodesForXPath:@"/read[1]/include" error:error];
  if (*error != nil) {
    return NO;
  }
  if (includeElementNodes.count > 0) {
    NSMutableArray* mIncludes = [NSMutableArray array];
    for (NSXMLElement* elem in includeElementNodes) {
      [mIncludes addObject:elem.stringValue];
    }
    self.includes = [NSArray arrayWithArray:mIncludes];
  }

  // enum support
  if (enumTypeNode) {
    NSArray* nodes = [enumTypeNode nodesForXPath:@"read[1]/prefix[1]" error:error];
    if (*error != nil) {
      return NO;
    }
    if (nodes != nil && nodes.count > 0) {
      self.enumReadPrefixCode = [[nodes objectAtIndex:0] stringValue];
    }
    nodes = [enumTypeNode nodesForXPath:@"read[1]/attribute[1]" error:error];
    if (*error != nil) {
      return NO;
    }
    if (nodes != nil && nodes.count > 0) {
      self.enumReadAttributeTemplate = [[nodes objectAtIndex:0] stringValue];
    }
    nodes = [enumTypeNode nodesForXPath:@"read[1]/element[1]" error:error];
    if (*error != nil) {
      return NO;
    }
    if (nodes != nil && nodes.count > 0) {
      self.enumReadElementTemplate = [[nodes objectAtIndex:0] stringValue];
    }
    nodes = [enumTypeNode nodesForXPath:@"read[1]/value[1]" error:error];
    if (*error != nil) {
      return NO;
    }
    if (nodes != nil && nodes.count > 0) {
      self.enumReadValueCode = [[nodes objectAtIndex:0] stringValue];
    }

    /* Write code */
    nodes = [enumTypeNode nodesForXPath:@"write[1]/prefix[1]" error:error];
    if (*error != nil) {
      return NO;
    }
    if (nodes != nil && nodes.count > 0) {
      self.enumWritePrefixCode = [[nodes objectAtIndex:0] stringValue];
    }
    nodes = [enumTypeNode nodesForXPath:@"write[1]/attribute[1]" error:error];
    if (*error != nil) {
      return NO;
    }
    if (nodes != nil && nodes.count > 0) {
      self.enumWriteAttributeTemplate = [[nodes objectAtIndex:0] stringValue];
    }
    nodes = [enumTypeNode nodesForXPath:@"write[1]/element[1]" error:error];
    if (*error != nil) {
      return NO;
    }
    if (nodes != nil && nodes.count > 0) {
      self.enumWriteElementTemplate = [[nodes objectAtIndex:0] stringValue];
    }
    nodes = [enumTypeNode nodesForXPath:@"write[1]/value[1]" error:error];
    if (*error != nil) {
      return NO;
    }
    if (nodes != nil && nodes.count > 0) {
      self.enumWriteValueCode = [[nodes objectAtIndex:0] stringValue];
    }
  }

  return YES;
}

- (NSString*)readAttributeTemplate {
  XSSimpleType* t = self.typeForTemplate;
  if (self.hasEnumeration) return t->_enumReadAttributeTemplate;
  return t->_readAttributeTemplate;
}

- (NSString*)writeAttributeTemplate {
  XSSimpleType* t = self.typeForTemplate;
  if (self.hasEnumeration) return t->_enumWriteAttributeTemplate;
  return t->_writeAttributeTemplate;
}

- (NSString*)readCodeForAttribute:(XSDattribute*)attribute {
  NSDictionary* dict = [NSDictionary dictionaryWithObject:attribute forKey:@"attribute"];
  return [engine processTemplate:self.readAttributeTemplate withVariables:dict];
}

- (NSString*)writeCodeForAttribute:(XSDattribute*)attribute {
  NSDictionary* dict = [NSDictionary dictionaryWithObject:attribute forKey:@"attribute"];
  return [engine processTemplate:self.writeAttributeTemplate withVariables:dict];
}

- (NSString*)readElementTemplate {
  XSSimpleType* t = self.typeForTemplate;
  if (self.hasEnumeration) return t->_enumReadElementTemplate;
  return t->_readElementTemplate;
}

- (NSString*)writeElementTemplate {
  XSSimpleType* t = self.typeForTemplate;
  if (self.hasEnumeration) return t->_enumWriteElementTemplate;
  return t->_writeElementTemplate;
}

- (NSString*)readCodeForElement:(XSDelement*)element {
  NSDictionary* dict = [NSDictionary dictionaryWithObject:element forKey:@"element"];
  return [engine processTemplate:self.readElementTemplate withVariables:dict];
}

- (NSString*)writeCodeForElement:(XSDelement*)element {
  NSDictionary* dict = [NSDictionary dictionaryWithObject:element forKey:@"element"];
  return [engine processTemplate:self.writeElementTemplate withVariables:dict];
}

- (NSString*)readCodeForValue:(NSString*)code {
  NSDictionary* dict = [NSDictionary dictionaryWithObject:self forKey:@"type"];
  return [engine processTemplate:code withVariables:dict];
}

- (NSString*)writeCodeForValue:(NSString*)code {
  NSDictionary* dict = [NSDictionary dictionaryWithObject:self forKey:@"type"];
  return [engine processTemplate:code withVariables:dict];
}

- (NSString*)readValueCode {
  XSSimpleType* t = self.typeForTemplate;
  if (self.hasEnumeration) return [self readCodeForValue:t->_enumReadValueCode];
  return [t readCodeForValue:t->_readValueCode];
}

- (NSString*)writeValueCode {
  XSSimpleType* t = self.typeForTemplate;
  if (self.hasEnumeration) return [self writeCodeForValue:t->_enumWriteValueCode];
  return [t writeCodeForValue:t->_writeValueCode];
}

- (NSString*)readPrefixCode {
  XSSimpleType* t = self.typeForTemplate;
  if (self.hasEnumeration) return t->_enumReadPrefixCode;
  return t->_readPrefixCode;
}

- (NSString*)writePrefixCode {
  XSSimpleType* t = self.typeForTemplate;
  if (self.hasEnumeration) return t->_enumWritePrefixCode;
  return t->_writePrefixCode;
}

#pragma mark enum support

/*
 * Name:        hasEnumeration
 * Parameters:  None
 * Returns:     BOOL value that will equate to
 *              0 - NO - False.
 *              1 - YES - True
 * Description: Will check the current element to see if the element type is associated
 *              with an enumeration values.
 */
- (BOOL)hasEnumeration {
  BOOL isEnumeration = NO;

  /* If we have some, set return value to yes */
  if ([[self enumerations] count] > 0) {
    isEnumeration = YES;
  }

  /* Return BOOL if we have enumerations */
  return isEnumeration;
}

- (NSArray*)enumerationValues {
  NSMutableArray* rtn = [[NSMutableArray alloc] init];
  /* Ensure that we have enumerations for this element */
  if (!self.hasEnumeration) {
    return rtn;
  }

  /* Iterate through the enumerations to grab the value*/
  for (XSDenumeration* enumType in [self enumerations]) {
    NSString* modifiedValue = enumType.value;
    if ([[[NSNumberFormatter alloc] init] numberFromString:modifiedValue])
      modifiedValue = [@"Value" stringByAppendingString:modifiedValue];
    [rtn addObject:[self sanitizeIdentifier:modifiedValue]];
  }

  /* Return the populated array of values */
  return rtn;
}

- (NSString*)sanitizeIdentifier:(NSString *)identifier {
  NSCharacterSet* illegalChars = [NSCharacterSet characterSetWithCharactersInString:@"-#+"];

  NSString* vName = [identifier
      stringByReplacingCharactersInRange:NSMakeRange(0, 1)
                              withString:[[identifier substringToIndex:1] uppercaseString]];
  NSRange range = [vName rangeOfCharacterFromSet:illegalChars];
  while (range.length > 0) {
    // delete illegal char
    vName = [vName stringByReplacingCharactersInRange:range withString:@""];
    // range is now at next char
    vName = [vName
        stringByReplacingCharactersInRange:range
                                withString:[[vName substringWithRange:range] uppercaseString]];

    range = [vName rangeOfCharacterFromSet:illegalChars];
  }

  NSString* prefix = [self.schema classPrefixForType:self];
  NSString* rtn = [NSString
      stringWithFormat:@"%@%@%@", prefix, vName, [vName hasSuffix:@"Value"] ? @"" : @"Value"];
  return rtn;
}

- (NSString*)enumerationName {
  NSCharacterSet* illegalChars = [NSCharacterSet characterSetWithCharactersInString:@"-"];

  NSString* vName = [self.name
      stringByReplacingCharactersInRange:NSMakeRange(0, 1)
                              withString:[[self.name substringToIndex:1] uppercaseString]];
  NSRange range = [vName rangeOfCharacterFromSet:illegalChars];
  while (range.length > 0) {
    // delete illegal char
    vName = [vName stringByReplacingCharactersInRange:range withString:@""];
    // range is now at next char
    vName = [vName
        stringByReplacingCharactersInRange:range
                                withString:[[vName substringWithRange:range] uppercaseString]];

    range = [vName rangeOfCharacterFromSet:illegalChars];
  }

  NSString* prefix = [self.schema classPrefixForType:self];
  NSString* rtn = [NSString
      stringWithFormat:@"%@%@%@", prefix, vName, [vName hasSuffix:@"Enum"] ? @"" : @"Enum"];
  return rtn;
}

- (NSString*)enumerationFileName {
  return [self enumerationName];
}

- (NSDictionary*)substitutionDict {
  return [NSDictionary dictionaryWithObject:self forKey:@"type"];
}

// stupid swift 2 workaround
- (NSString*)swiftIntEnum {
  if (gUnitTestingSwiftCode)
    return @"Int, EVRawInt";
  else
    return @"Int";
}

#pragma mark

#include "xsd2swift/resources/datatypes_xml.h"

/**
 * Name:        knownSimpleTypesForSchema
 * Parameters:  the schema the types are for
 * Returns:     A list of xml data simple types defined in
 * http://www.w3.org/TR/xmlschema-2/#built-in-datatypes Details:     This public method will
 * generate a list of known simple data types listed in the datatypes.xml file in our project.
 */
+ (NSArray*)knownSimpleTypesForSchema:(XSDschema*)schema {
//  NSURL* url = [NSURL fileURLWithPath:];
//      [[NSBundle bundleForClass:[self class]] URLForResource:@"datatypes"
//          withExtension:@"xml"];
  NSData* data = [NSData dataWithBytes:xsd2swift_resources_datatypes_xml
      length:xsd2swift_resources_datatypes_xml_len];
  NSXMLDocument* doc = [[NSXMLDocument alloc] initWithData:data options:0 error:nil];
  if (!doc) {
    return nil;
  }

  /* Select all element types of the root element datatype */
  NSArray* iNodes = [[doc rootElement] nodesForXPath:@"/datatypes/type" error:nil];

  NSMutableArray* types = [NSMutableArray arrayWithCapacity:iNodes.count];
  for (NSXMLElement* element in iNodes) {
    id base = [XMLUtils node:element stringAttribute:@"base"];
    id name = [XMLUtils node:element stringAttribute:@"name"];
    XSSimpleType* st = [[[self class] alloc] initWithName:name baseType:base schema:schema];
    [types addObject:st];
  }
  return types;
}

@end

BOOL gUnitTestingSwiftCode = NO;  // swift 2 workaround
