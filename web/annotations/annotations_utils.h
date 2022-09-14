// Copyright 2022 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_WEB_ANNOTATIONS_ANNOTATIONS_UTILS_H_
#define IOS_WEB_ANNOTATIONS_ANNOTATIONS_UTILS_H_

#import <UIKit/UIKit.h>

#import "base/values.h"

@protocol CRWWebViewHandlerDelegate;

namespace web {
namespace annotations {

// Encodes the given `match` into a base64 string that can be parsed back.
// Note that `match.range` isn't encoded because it is not needed on the
// 'way back'.
NSString* EncodeNSTextCheckingResultData(NSTextCheckingResult* match);

// Decodes a string generated by `EncodeNSTextCheckingResultData` into a
// `NSTextCheckingResult` (without range).
NSTextCheckingResult* DecodeNSTextCheckingResultData(NSString* base64_data);

// Encapsulates data into a `base::Value::Type::DICTIONARY` that can be
// passed to JS. `data` must come from `EncodeNSTextCheckingResultData`.
base::Value::Dict ConvertMatchToAnnotation(NSString* source,
                                           NSRange range,
                                           NSString* data,
                                           NSString* type);

}  // namespace annotations
}  // namespace web

#endif  // IOS_WEB_ANNOTATIONS_ANNOTATIONS_UTILS_H_
