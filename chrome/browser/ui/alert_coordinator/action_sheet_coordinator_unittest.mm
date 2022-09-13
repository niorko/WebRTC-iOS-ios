// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/alert_coordinator/action_sheet_coordinator.h"

#import <UIKit/UIKit.h>

#import "base/mac/foundation_util.h"
#import "base/test/task_environment.h"
#import "ios/chrome/browser/browser_state/test_chrome_browser_state.h"
#import "ios/chrome/browser/main/test_browser.h"
#import "ios/chrome/test/scoped_key_window.h"
#import "testing/gtest_mac.h"
#import "testing/platform_test.h"
#import "ui/base/l10n/l10n_util.h"
#import "ui/strings/grit/ui_strings.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

class ActionSheetCoordinatorTest : public PlatformTest {
 protected:
  ActionSheetCoordinatorTest() {
    browser_state_ = TestChromeBrowserState::Builder().Build();
    browser_ = std::make_unique<TestBrowser>(browser_state_.get());
  }

  void SetUp() override {
    base_view_controller_ = [[UIViewController alloc] init];
    [scoped_key_window_.Get() setRootViewController:base_view_controller_];

    test_view_ =
        [[UIView alloc] initWithFrame:base_view_controller_.view.bounds];
    [base_view_controller_.view addSubview:test_view_];
  }

  ActionSheetCoordinator* CreateCoordinator() {
    return [[ActionSheetCoordinator alloc]
        initWithBaseViewController:base_view_controller_
                           browser:browser_.get()
                             title:@"Some Title"
                           message:nil
                              rect:CGRectMake(124, 432, 126, 63)
                              view:test_view_];
  }

  UIAlertController* GetAlertController() {
    EXPECT_TRUE([base_view_controller_.presentedViewController
        isKindOfClass:[UIAlertController class]]);
    return base::mac::ObjCCastStrict<UIAlertController>(
        base_view_controller_.presentedViewController);
  }

  base::test::TaskEnvironment task_environment_;

  ScopedKeyWindow scoped_key_window_;
  std::unique_ptr<TestChromeBrowserState> browser_state_;
  std::unique_ptr<TestBrowser> browser_;
  UIViewController* base_view_controller_;
  UIView* test_view_;
};

// Tests that if there is a popover, it uses the CGRect passed in init.
TEST_F(ActionSheetCoordinatorTest, CGRectUsage) {
  CGRect rect = CGRectMake(124, 432, 126, 63);
  AlertCoordinator* alertCoordinator = [[ActionSheetCoordinator alloc]
      initWithBaseViewController:base_view_controller_
                         browser:browser_.get()
                           title:@"title"
                         message:nil
                            rect:rect
                            view:test_view_];

  // Action.
  [alertCoordinator start];

  // Test.
  // Get the alert.
  UIAlertController* alertController = GetAlertController();

  // Test the results.
  EXPECT_EQ(UIAlertControllerStyleActionSheet, alertController.preferredStyle);

  if (alertController.popoverPresentationController) {
    UIPopoverPresentationController* popover =
        alertController.popoverPresentationController;
    EXPECT_TRUE(CGRectEqualToRect(rect, popover.sourceRect));
    EXPECT_EQ(test_view_, popover.sourceView);
  }

  [alertCoordinator stop];
}

// Tests that initializing with a location properly sets the popover sourceRect.
TEST_F(ActionSheetCoordinatorTest, Location_CGRectUsage) {
  CGRect rect = CGRectMake(12, 13, 1.0, 1.0);

  AlertCoordinator* alertCoordinator = [[ActionSheetCoordinator alloc]
      initWithBaseViewController:base_view_controller_
                         browser:browser_.get()
                           title:@"title"
                         message:nil
                            rect:rect
                            view:test_view_];

  // Action.
  [alertCoordinator start];

  // Test.
  // Get the alert.
  UIAlertController* alertController = GetAlertController();

  // Test the results.
  EXPECT_EQ(UIAlertControllerStyleActionSheet, alertController.preferredStyle);

  if (alertController.popoverPresentationController) {
    UIPopoverPresentationController* popover =
        alertController.popoverPresentationController;
    EXPECT_TRUE(CGRectEqualToRect(rect, popover.sourceRect));
    EXPECT_EQ(test_view_, popover.sourceView);
  }

  [alertCoordinator stop];
}

// Tests that a Cancel action is added by default upon starting.
TEST_F(ActionSheetCoordinatorTest, Start_AddCancel) {
  ActionSheetCoordinator* coordinator = CreateCoordinator();

  // Add a basic, non-cancel, action.
  NSString* addActionTitle = @"Add";
  [coordinator addItemWithTitle:addActionTitle
                         action:nil
                          style:UIAlertActionStyleDefault];

  EXPECT_FALSE(coordinator.cancelButtonAdded);

  [coordinator start];

  EXPECT_TRUE(coordinator.cancelButtonAdded);

  // Verify that there are two actions total.
  UIAlertController* alertController = GetAlertController();
  EXPECT_EQ(2U, [alertController.actions count]);

  UIAlertAction* addAction = alertController.actions[0];
  EXPECT_EQ(addActionTitle, addAction.title);
  EXPECT_EQ(UIAlertActionStyleDefault, addAction.style);

  UIAlertAction* cancelAction = alertController.actions[1];
  EXPECT_NSEQ(l10n_util::GetNSString(IDS_APP_CANCEL), cancelAction.title);
  EXPECT_EQ(UIAlertActionStyleCancel, cancelAction.style);
}

// Tests that a Cancel action is not added upon starting when another Cancel
// action was already added.
TEST_F(ActionSheetCoordinatorTest, Start_SkipCancel_IfAdded) {
  ActionSheetCoordinator* coordinator = CreateCoordinator();

  EXPECT_FALSE(coordinator.cancelButtonAdded);

  // Add a cancel action.
  NSString* cancelActionTitle = @"Some Cancel Text";
  [coordinator addItemWithTitle:cancelActionTitle
                         action:nil
                          style:UIAlertActionStyleCancel];

  EXPECT_TRUE(coordinator.cancelButtonAdded);

  [coordinator start];

  EXPECT_TRUE(coordinator.cancelButtonAdded);

  // Verify that there is only one action in total.
  UIAlertController* alertController = GetAlertController();
  EXPECT_EQ(1U, [alertController.actions count]);

  UIAlertAction* cancelAction = alertController.actions[0];
  EXPECT_EQ(cancelActionTitle, cancelAction.title);
  EXPECT_EQ(UIAlertActionStyleCancel, cancelAction.style);
}
