// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_FIRST_RUN_SIGNIN_SIGNIN_SCREEN_COORDINATOR_H_
#define IOS_CHROME_BROWSER_UI_FIRST_RUN_SIGNIN_SIGNIN_SCREEN_COORDINATOR_H_

#import "ios/chrome/browser/ui/coordinators/chrome_coordinator.h"

@protocol FirstRunScreenDelegate;

// Coordinator to present sign-in screen.
@interface SigninScreenCoordinator : ChromeCoordinator

// Initiates a SigninScreenCoordinator with |navigationController| and
// |browser|.
- (instancetype)initWithBaseNavigationController:
                    (UINavigationController*)navigationController
                                         browser:(Browser*)browser
                                        delegate:
                                            (id<FirstRunScreenDelegate>)delegate
    NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithBaseViewController:(UIViewController*)viewController
                                   browser:(Browser*)browser NS_UNAVAILABLE;

@end

#endif  // IOS_CHROME_BROWSER_UI_FIRST_RUN_SIGNIN_SIGNIN_SCREEN_COORDINATOR_H_
