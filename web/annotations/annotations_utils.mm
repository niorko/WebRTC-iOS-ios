// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/web/annotations/annotations_text_manager.h"

#import "base/logging.h"
#import "base/strings/string_util.h"
#import "base/strings/sys_string_conversions.h"
#import "base/strings/utf_string_conversions.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace web {
namespace annotations {

// Annotation keys for annotation.
static const char kAnnotationsTextKey[] = "text";
static const char kAnnotationsStartKey[] = "start";
static const char kAnnotationsEndKey[] = "end";
static const char kAnnotationsStyleKey[] = "style";
static const char kAnnotationsDataKey[] = "data";

NSString* EncodeNSTextCheckingResultData(NSTextCheckingResult* match) {
  NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];

  if (match.resultType == NSTextCheckingTypeDate) {
    [dict setObject:@"date" forKey:@"type"];
    if (match.date) {
      [dict setObject:match.date forKey:@"date"];
    }
    if (match.duration) {
      [dict setObject:[NSNumber numberWithDouble:match.duration]
               forKey:@"duration"];
    }
    if (match.timeZone) {
      [dict setObject:match.timeZone forKey:@"timeZone"];
    }
  } else if (match.resultType == NSTextCheckingTypeAddress) {
    [dict setObject:@"address" forKey:@"type"];
    if (match.addressComponents) {
      [dict setObject:match.addressComponents forKey:@"addressComponents"];
    }
  } else if (match.resultType == NSTextCheckingTypePhoneNumber) {
    [dict setObject:@"phoneNumber" forKey:@"type"];
    if (match.phoneNumber) {
      [dict setObject:match.phoneNumber forKey:@"phoneNumber"];
    }
  }

  NSError* error = nil;
  NSData* data = [NSKeyedArchiver archivedDataWithRootObject:dict
                                       requiringSecureCoding:NO
                                                       error:&error];

  if (!data || error) {
    DLOG(ERROR) << "Error serializing data: "
                << base::SysNSStringToUTF8([error description]);
    return nil;
  }

  return [data base64EncodedStringWithOptions:0];
}

NSTextCheckingResult* DecodeNSTextCheckingResultData(NSString* base64_data) {
  NSData* data = [[NSData alloc] initWithBase64EncodedString:base64_data
                                                     options:0];

  NSError* error = nil;
  NSKeyedUnarchiver* unarchiver =
      [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&error];
  if (!unarchiver || error) {
    DLOG(ERROR) << "Error deserializing data: "
                << base::SysNSStringToUTF8([error description]);
    return nil;
  }

  unarchiver.requiresSecureCoding = NO;
  NSMutableDictionary* dict =
      [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];

  NSRange range;
  NSString* type = dict[@"type"];
  if ([type isEqualToString:@"date"]) {
    NSDate* date = dict[@"date"];
    NSNumber* number = dict[@"duration"];
    NSTimeInterval duration = number.doubleValue;
    NSTimeZone* timeZone = dict[@"timeZone"];
    return [NSTextCheckingResult dateCheckingResultWithRange:range
                                                        date:date
                                                    timeZone:timeZone
                                                    duration:duration];
  } else if ([type isEqualToString:@"address"]) {
    NSDictionary* components = dict[@"addressComponents"];
    return [NSTextCheckingResult addressCheckingResultWithRange:range
                                                     components:components];
  } else if ([type isEqualToString:@"phoneNumber"]) {
    NSString* phoneNumber = dict[@"phoneNumber"];
    return
        [NSTextCheckingResult phoneNumberCheckingResultWithRange:range
                                                     phoneNumber:phoneNumber];
  }
  return nil;
}

base::Value::Dict ConvertMatchToAnnotation(NSString* source,
                                           NSRange range,
                                           NSString* data,
                                           const char style[]) {
  base::Value::Dict dict;
  NSString* start = [source substringWithRange:range];
  dict.Set(kAnnotationsStartKey, base::Value(static_cast<int>(range.location)));
  dict.Set(kAnnotationsEndKey,
           base::Value(static_cast<int>(range.location + range.length)));
  dict.Set(kAnnotationsTextKey, base::Value(base::SysNSStringToUTF8(start)));
  dict.Set(kAnnotationsStyleKey, base::Value(style));
  dict.Set(kAnnotationsDataKey, base::Value(base::SysNSStringToUTF8(data)));
  return dict;
};

}  // namespace annotations
}  // namespace web
