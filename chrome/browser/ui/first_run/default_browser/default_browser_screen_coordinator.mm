// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/first_run/default_browser/default_browser_screen_coordinator.h"

#import "ios/chrome/browser/ui/first_run/default_browser/default_browser_screen_view_controller.h"
#import "ios/chrome/browser/ui/first_run/first_run_screen_delegate.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@interface DefaultBrowserScreenCoordinator () <
    FirstRunScreenViewControllerDelegate>

// Default browser screen view controller.
@property(nonatomic, strong) DefaultBrowserScreenViewController* viewController;

// First run screen delegate.
@property(nonatomic, weak) id<FirstRunScreenDelegate> delegate;

@end

@implementation DefaultBrowserScreenCoordinator

@synthesize baseNavigationController = _baseNavigationController;

- (instancetype)initWithBaseNavigationController:
                    (UINavigationController*)navigationController
                                         browser:(Browser*)browser
                                        delegate:(id<FirstRunScreenDelegate>)
                                                     delegate {
  self = [super initWithBaseViewController:navigationController
                                   browser:browser];
  if (self) {
    _baseNavigationController = navigationController;
    _delegate = delegate;
  }
  return self;
}

#pragma mark - ChromeCoordinator

- (void)start {
  self.viewController = [[DefaultBrowserScreenViewController alloc] init];
  self.viewController.delegate = self;

  BOOL animated = self.baseNavigationController.topViewController != nil;
  [self.baseNavigationController setViewControllers:@[ self.viewController ]
                                           animated:animated];
  self.viewController.modalInPresentation = YES;
}

- (void)stop {
  self.delegate = nil;
  self.viewController = nil;
}

#pragma mark - FirstRunScreenViewControllerDelegate

- (void)didTapPrimaryActionButton {
  [[UIApplication sharedApplication]
                openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]
                options:{}
      completionHandler:nil];
  [self.delegate willFinishPresenting];
}

- (void)didTapSecondaryActionButton {
  [self.delegate willFinishPresenting];
}

@end
