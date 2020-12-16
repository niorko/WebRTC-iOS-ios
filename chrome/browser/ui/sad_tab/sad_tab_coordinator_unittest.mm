// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/sad_tab/sad_tab_coordinator.h"

#include "ios/chrome/browser/browser_state/test_chrome_browser_state.h"
#import "ios/chrome/browser/main/test_browser.h"
#import "ios/chrome/browser/ui/commands/application_commands.h"
#import "ios/chrome/browser/ui/commands/browser_commands.h"
#import "ios/chrome/browser/ui/commands/command_dispatcher.h"
#import "ios/chrome/browser/ui/sad_tab/sad_tab_view_controller.h"
#import "ios/chrome/browser/ui/util/named_guide.h"
#import "ios/chrome/browser/web/web_navigation_browser_agent.h"
#import "ios/chrome/common/ui/util/constraints_ui_util.h"
#import "ios/web/public/test/fakes/fake_web_state.h"
#include "ios/web/public/test/web_task_environment.h"
#include "testing/gtest_mac.h"
#include "testing/platform_test.h"
#import "third_party/ocmock/OCMock/OCMock.h"
#include "third_party/ocmock/gtest_support.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

// Test fixture for testing SadTabCoordinator class.
class SadTabCoordinatorTest : public PlatformTest {
 protected:
  SadTabCoordinatorTest()
      : base_view_controller_([[UIViewController alloc] init]),
        browser_(std::make_unique<TestBrowser>()) {
    UILayoutGuide* guide = [[NamedGuide alloc] initWithName:kContentAreaGuide];
    [base_view_controller_.view addLayoutGuide:guide];
    AddSameConstraints(guide, base_view_controller_.view);
    WebNavigationBrowserAgent::CreateForBrowser(browser_.get());
  }
  web::WebTaskEnvironment task_environment_;
  UIViewController* base_view_controller_;
  std::unique_ptr<Browser> browser_;
};

// Tests starting coordinator.
TEST_F(SadTabCoordinatorTest, Start) {
  SadTabCoordinator* coordinator = [[SadTabCoordinator alloc]
      initWithBaseViewController:base_view_controller_
                         browser:browser_.get()];

  [coordinator start];

  // Verify that presented view controller is SadTabViewController.
  EXPECT_EQ(1U, base_view_controller_.childViewControllers.count);
  SadTabViewController* view_controller =
      base_view_controller_.childViewControllers.firstObject;
  ASSERT_EQ([SadTabViewController class], [view_controller class]);

  // Verify SadTabViewController state.
  EXPECT_FALSE(view_controller.offTheRecord);
  EXPECT_FALSE(view_controller.repeatedFailure);
  [coordinator stop];
}

// Tests stopping coordinator.
TEST_F(SadTabCoordinatorTest, Stop) {
  SadTabCoordinator* coordinator = [[SadTabCoordinator alloc]
      initWithBaseViewController:base_view_controller_
                         browser:browser_.get()];

  [coordinator start];
  ASSERT_EQ(1U, base_view_controller_.childViewControllers.count);

  [coordinator stop];
  EXPECT_EQ(0U, base_view_controller_.childViewControllers.count);
}

// Tests dismissing Sad Tab.
TEST_F(SadTabCoordinatorTest, Dismiss) {
  SadTabCoordinator* coordinator = [[SadTabCoordinator alloc]
      initWithBaseViewController:base_view_controller_
                         browser:browser_.get()];

  [coordinator start];
  ASSERT_EQ(1U, base_view_controller_.childViewControllers.count);

  [coordinator sadTabTabHelperDismissSadTab:nullptr];
  EXPECT_EQ(0U, base_view_controller_.childViewControllers.count);
  [coordinator stop];
}

// Tests hiding Sad Tab.
TEST_F(SadTabCoordinatorTest, Hide) {
  SadTabCoordinator* coordinator = [[SadTabCoordinator alloc]
      initWithBaseViewController:base_view_controller_
                         browser:browser_.get()];

  [coordinator start];
  ASSERT_EQ(1U, base_view_controller_.childViewControllers.count);

  [coordinator sadTabTabHelperDidHide:nullptr];
  EXPECT_EQ(0U, base_view_controller_.childViewControllers.count);
  [coordinator stop];
}

// Tests SadTabViewController state for the first failure in non-incognito mode.
TEST_F(SadTabCoordinatorTest, FirstFailureInNonIncognito) {
  web::FakeWebState web_state;
  web_state.WasShown();
  SadTabCoordinator* coordinator = [[SadTabCoordinator alloc]
      initWithBaseViewController:base_view_controller_
                         browser:browser_.get()];

  [coordinator sadTabTabHelper:nullptr
      presentSadTabForWebState:&web_state
               repeatedFailure:NO];

  // Verify that presented view controller is SadTabViewController.
  EXPECT_EQ(1U, base_view_controller_.childViewControllers.count);
  SadTabViewController* view_controller =
      base_view_controller_.childViewControllers.firstObject;
  ASSERT_EQ([SadTabViewController class], [view_controller class]);

  // Verify SadTabViewController state.
  EXPECT_FALSE(view_controller.offTheRecord);
  EXPECT_FALSE(view_controller.repeatedFailure);
  [coordinator stop];
}

// Tests SadTabViewController state for the repeated failure in incognito mode.
TEST_F(SadTabCoordinatorTest, FirstFailureInIncognito) {
  web::FakeWebState web_state;
  web_state.WasShown();
  std::unique_ptr<Browser> otr_browser = std::make_unique<TestBrowser>(
      browser_->GetBrowserState()->GetOffTheRecordChromeBrowserState());
  SadTabCoordinator* coordinator = [[SadTabCoordinator alloc]
      initWithBaseViewController:base_view_controller_
                         browser:otr_browser.get()];

  [coordinator sadTabTabHelper:nullptr
      presentSadTabForWebState:&web_state
               repeatedFailure:YES];

  // Verify that presented view controller is SadTabViewController.
  EXPECT_EQ(1U, base_view_controller_.childViewControllers.count);
  SadTabViewController* view_controller =
      base_view_controller_.childViewControllers.firstObject;
  ASSERT_EQ([SadTabViewController class], [view_controller class]);

  // Verify SadTabViewController state.
  EXPECT_TRUE(view_controller.offTheRecord);
  EXPECT_TRUE(view_controller.repeatedFailure);
  [coordinator stop];
}

// Tests SadTabViewController state for the repeated failure in incognito mode.
TEST_F(SadTabCoordinatorTest, ShowFirstFailureInIncognito) {
  std::unique_ptr<Browser> otr_browser = std::make_unique<TestBrowser>(
      browser_->GetBrowserState()->GetOffTheRecordChromeBrowserState());
  SadTabCoordinator* coordinator = [[SadTabCoordinator alloc]
      initWithBaseViewController:base_view_controller_
                         browser:otr_browser.get()];

  [coordinator sadTabTabHelper:nullptr didShowForRepeatedFailure:YES];

  // Verify that presented view controller is SadTabViewController.
  EXPECT_EQ(1U, base_view_controller_.childViewControllers.count);
  SadTabViewController* view_controller =
      base_view_controller_.childViewControllers.firstObject;
  ASSERT_EQ([SadTabViewController class], [view_controller class]);

  // Verify SadTabViewController state.
  EXPECT_TRUE(view_controller.offTheRecord);
  EXPECT_TRUE(view_controller.repeatedFailure);
  [coordinator stop];
}

// Tests action button tap for the first failure.
TEST_F(SadTabCoordinatorTest, FirstFailureAction) {
  web::FakeWebState web_state;
  web_state.WasShown();
  SadTabCoordinator* coordinator = [[SadTabCoordinator alloc]
      initWithBaseViewController:base_view_controller_
                         browser:browser_.get()];

  [coordinator sadTabTabHelper:nullptr
      presentSadTabForWebState:&web_state
               repeatedFailure:NO];

  // Verify that presented view controller is SadTabViewController.
  EXPECT_EQ(1U, base_view_controller_.childViewControllers.count);
  SadTabViewController* view_controller =
      base_view_controller_.childViewControllers.firstObject;
  ASSERT_EQ([SadTabViewController class], [view_controller class]);

  // Ensure that the action button can be pressed.
  [view_controller.actionButton
      sendActionsForControlEvents:UIControlEventTouchUpInside];
  [coordinator stop];
}

// Tests action button tap for the repeated failure.
TEST_F(SadTabCoordinatorTest, RepeatedFailureAction) {
  web::FakeWebState web_state;
  web_state.WasShown();
  SadTabCoordinator* coordinator = [[SadTabCoordinator alloc]
      initWithBaseViewController:base_view_controller_
                         browser:browser_.get()];

  id mock_application_commands_handler_ =
      OCMStrictProtocolMock(@protocol(ApplicationCommands));
  [browser_->GetCommandDispatcher()
      startDispatchingToTarget:mock_application_commands_handler_
                   forProtocol:@protocol(ApplicationCommands)];
  OCMExpect([mock_application_commands_handler_
      showReportAnIssueFromViewController:base_view_controller_
                                   sender:UserFeedbackSender::SadTab]);

  [coordinator sadTabTabHelper:nullptr
      presentSadTabForWebState:&web_state
               repeatedFailure:YES];

  // Verify that presented view controller is SadTabViewController.
  EXPECT_EQ(1U, base_view_controller_.childViewControllers.count);
  SadTabViewController* view_controller =
      base_view_controller_.childViewControllers.firstObject;
  ASSERT_EQ([SadTabViewController class], [view_controller class]);

  // Verify dispatcher's message.
  [view_controller.actionButton
      sendActionsForControlEvents:UIControlEventTouchUpInside];
  EXPECT_OCMOCK_VERIFY(mock_application_commands_handler_);
  [coordinator stop];
}

// Tests that view controller is not presented for the hidden web state.
TEST_F(SadTabCoordinatorTest, IgnoreSadTabFromHiddenWebState) {
  web::FakeWebState web_state;
  SadTabCoordinator* coordinator = [[SadTabCoordinator alloc]
      initWithBaseViewController:base_view_controller_
                         browser:browser_.get()];

  [coordinator sadTabTabHelper:nullptr
      presentSadTabForWebState:&web_state
               repeatedFailure:NO];

  // Verify that view controller was not presented for the hidden web state.
  EXPECT_EQ(0U, base_view_controller_.childViewControllers.count);
  [coordinator stop];
}
