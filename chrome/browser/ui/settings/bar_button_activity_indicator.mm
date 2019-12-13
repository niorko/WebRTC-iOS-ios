// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/settings/bar_button_activity_indicator.h"

#include "ios/chrome/browser/ui/util/ui_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@implementation BarButtonActivityIndicator {
  UIActivityIndicatorView* _activityIndicator;
}

- (id)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _activityIndicator = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [_activityIndicator setBackgroundColor:[UIColor clearColor]];
    [_activityIndicator setHidesWhenStopped:YES];
    [_activityIndicator startAnimating];
    [self addSubview:_activityIndicator];
  }
  return self;
}

- (void)dealloc {
  [_activityIndicator stopAnimating];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  CGSize boundsSize = self.bounds.size;
  CGPoint center = CGPointMake(boundsSize.width / 2, boundsSize.height / 2);
  [_activityIndicator setCenter:AlignPointToPixel(center)];
}

@end
