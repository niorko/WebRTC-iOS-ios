// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_SHARING_SHARING_COORDINATOR_H_
#define IOS_CHROME_BROWSER_UI_SHARING_SHARING_COORDINATOR_H_

#include <UIKit/UIKit.h>

#import "ios/chrome/browser/ui/coordinators/chrome_coordinator.h"

class Browser;

// Coordinator of sharing scenarios. Its default scenario is to share the
// current tab's URL.
@interface SharingCoordinator : ChromeCoordinator

// Creates a coordinator using the base |viewController|, a |browser| and an
// |originView| from which the sharing scenario was triggered.
- (instancetype)initWithBaseViewController:(UIViewController*)viewController
                                   browser:(Browser*)browser
                                originView:(UIView*)originView
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithBaseViewController:(UIViewController*)viewController
                                   browser:(Browser*)browser NS_UNAVAILABLE;

@end

#endif  // IOS_CHROME_BROWSER_UI_SHARING_SHARING_COORDINATOR_H_
