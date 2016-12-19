// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/find_bar/find_bar_touch_forwarding_view.h"

@implementation FindBarTouchForwardingView
@synthesize targetView = _targetView;

- (UIView*)hitTest:(CGPoint)point withEvent:(UIEvent*)event {
  if (self.targetView && [self pointInside:point withEvent:event]) {
    return self.targetView;
  }

  return [super hitTest:point withEvent:event];
}

@end
