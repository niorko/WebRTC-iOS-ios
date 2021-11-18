// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/public/provider/chrome/browser/password_auto_fill/password_auto_fill_api.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace ios {
namespace provider {

BOOL SupportShortenedInstructionForPasswordAutoFill() {
  return NO;
}

void PasswordsInOtherAppsOpensSettings() {
  // Test implementation does nothing.
}

}  // namespace provider
}  // namespace ios
