// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/tab_strip/tab_strip_coordinator.h"

#include "base/check_op.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@interface TabStripCoordinator ()
@end

@implementation TabStripCoordinator

#pragma mark - ChromeCoordinator

- (instancetype)initWithBrowser:(Browser*)browser {
  DCHECK(browser);
  return [super initWithBaseViewController:nil browser:browser];
}

@end
