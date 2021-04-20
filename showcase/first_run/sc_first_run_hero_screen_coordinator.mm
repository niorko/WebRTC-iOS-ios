// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/showcase/first_run/sc_first_run_hero_screen_coordinator.h"

#import "ios/showcase/first_run/sc_first_run_hero_screen_view_controller.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@interface SCFirstRunHeroScreenCoordinator () <HeroScreenDelegate>

@property(nonatomic, strong)
    SCFirstRunHeroScreenViewController* screenViewController;

@end

@implementation SCFirstRunHeroScreenCoordinator
@synthesize baseViewController = _baseViewController;

#pragma mark - Public Methods.

- (void)start {
  self.screenViewController = [[SCFirstRunHeroScreenViewController alloc] init];
  self.screenViewController.delegate = self;
  self.screenViewController.modalPresentationStyle =
      UIModalPresentationFormSheet;
  [self.baseViewController setHidesBarsOnSwipe:NO];
  [self.baseViewController pushViewController:self.screenViewController
                                     animated:YES];
}

#pragma mark - HeroScreenDelegate

- (void)didTapPrimaryActionButton {
  UIAlertController* alert =
      [UIAlertController alertControllerWithTitle:@"Primary Button Tapped"
                                          message:@"This is a message from the "
                                                  @"coordinator."
                                   preferredStyle:UIAlertControllerStyleAlert];

  UIAlertAction* defaultAction =
      [UIAlertAction actionWithTitle:@"OK"
                               style:UIAlertActionStyleDefault
                             handler:^(UIAlertAction* action){
                             }];

  [alert addAction:defaultAction];
  [self.screenViewController presentViewController:alert
                                          animated:YES
                                        completion:nil];
}

- (void)didTapCustomActionButton {
  UIAlertController* alert =
      [UIAlertController alertControllerWithTitle:@"Custom Button Tapped"
                                          message:@"This is a message from the "
                                                  @"coordinator triggered by "
                                                  @"the screen-specific button."
                                   preferredStyle:UIAlertControllerStyleAlert];

  UIAlertAction* defaultAction =
      [UIAlertAction actionWithTitle:@"OK"
                               style:UIAlertActionStyleDefault
                             handler:^(UIAlertAction* action){
                             }];

  [alert addAction:defaultAction];
  [self.screenViewController presentViewController:alert
                                          animated:YES
                                        completion:nil];
}

@end
