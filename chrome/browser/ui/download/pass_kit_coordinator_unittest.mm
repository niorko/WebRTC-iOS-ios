// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/download/pass_kit_coordinator.h"

#import <PassKit/PassKit.h>

#import <memory>

#import "base/logging.h"
#import "base/test/ios/wait_util.h"
#import "base/test/metrics/histogram_tester.h"
#import "base/test/task_environment.h"
#import "components/infobars/core/confirm_infobar_delegate.h"
#import "components/infobars/core/infobar.h"
#import "ios/chrome/browser/browser_state/test_chrome_browser_state.h"
#import "ios/chrome/browser/download/download_test_util.h"
#import "ios/chrome/browser/download/pass_kit_tab_helper.h"
#import "ios/chrome/browser/infobars/infobar_manager_impl.h"
#import "ios/chrome/browser/main/test_browser.h"
#import "ios/chrome/grit/ios_strings.h"
#import "ios/chrome/test/fakes/fake_pass_kit_tab_helper_delegate.h"
#import "ios/chrome/test/scoped_key_window.h"
#import "ios/web/public/test/fakes/fake_navigation_manager.h"
#import "ios/web/public/test/fakes/fake_web_state.h"
#import "testing/gtest/include/gtest/gtest.h"
#import "testing/platform_test.h"
#import "ui/base/device_form_factor.h"
#import "ui/base/l10n/l10n_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using base::test::ios::WaitUntilConditionOrTimeout;
using base::test::ios::kWaitForUIElementTimeout;

// Test fixture for PassKitCoordinator class.
class PassKitCoordinatorTest : public PlatformTest {
 protected:
  PassKitCoordinatorTest() {
    browser_state_ = TestChromeBrowserState::Builder().Build();
    browser_ = std::make_unique<TestBrowser>(browser_state_.get());
    base_view_controller_ = [[UIViewController alloc] init];
    coordinator_ = [[PassKitCoordinator alloc]
        initWithBaseViewController:base_view_controller_
                           browser:browser_.get()];
    web_state_ = std::make_unique<web::FakeWebState>();
    delegate_ = [[FakePassKitTabHelperDelegate alloc]
        initWithWebState:web_state_.get()];
    test_navigation_manager_ = std::make_unique<web::FakeNavigationManager>();

    PassKitTabHelper::CreateForWebState(web_state_.get());
    PassKitTabHelper::FromWebState(web_state_.get())->SetDelegate(delegate_);
    InfoBarManagerImpl::CreateForWebState(web_state_.get());
    web_state_->SetNavigationManager(std::move(test_navigation_manager_));
    [scoped_key_window_.Get() setRootViewController:base_view_controller_];
  }

  PassKitTabHelper* tab_helper() {
    return PassKitTabHelper::FromWebState(web_state_.get());
  }

  base::test::TaskEnvironment task_environment_;
  std::unique_ptr<TestChromeBrowserState> browser_state_;
  std::unique_ptr<TestBrowser> browser_;
  UIViewController* base_view_controller_;
  PassKitCoordinator* coordinator_;
  std::unique_ptr<web::FakeWebState> web_state_;
  FakePassKitTabHelperDelegate* delegate_;
  ScopedKeyWindow scoped_key_window_;
  std::unique_ptr<web::NavigationManager> test_navigation_manager_;
  base::HistogramTester histogram_tester_;
};

// Tests that PassKitCoordinator presents PKAddPassesViewController for the
// valid PKPass object.
// TODO(crbug.com/804250): this test is flaky.
TEST_F(PassKitCoordinatorTest, ValidPassKitObject) {
  std::string data = testing::GetTestFileContents(testing::kPkPassFilePath);
  NSData* nsdata = [NSData dataWithBytes:data.c_str() length:data.size()];
  PKPass* pass = [[PKPass alloc] initWithData:nsdata error:nil];
  ASSERT_TRUE(pass);

  [coordinator_ passKitTabHelper:tab_helper()
            presentDialogForPass:pass
                        webState:web_state_.get()];

  if (ui::GetDeviceFormFactor() == ui::DEVICE_FORM_FACTOR_TABLET) {
    // Wallet app is not supported on iPads.
  } else {
    EXPECT_TRUE(WaitUntilConditionOrTimeout(kWaitForUIElementTimeout, ^{
      return [base_view_controller_.presentedViewController class] ==
             [PKAddPassesViewController class];
    }));

    [coordinator_ stop];

    EXPECT_TRUE(WaitUntilConditionOrTimeout(kWaitForUIElementTimeout, ^{
      return base_view_controller_.presentedViewController == nil;
    }));

    histogram_tester_.ExpectUniqueSample(
        kUmaPresentAddPassesDialogResult,
        static_cast<base::HistogramBase::Sample>(
            PresentAddPassesDialogResult::kSuccessful),
        1);
  }

  EXPECT_FALSE(coordinator_.webState);
  EXPECT_FALSE(coordinator_.pass);
}

// Tests presenting multiple valid PKPass objects.
// TODO(crbug.com/804250): this test is flaky.
TEST_F(PassKitCoordinatorTest, MultiplePassKitObjects) {
  if (ui::GetDeviceFormFactor() == ui::DEVICE_FORM_FACTOR_TABLET) {
    // Wallet app is not supported on iPads.
    return;
  }

  std::string data = testing::GetTestFileContents(testing::kPkPassFilePath);
  NSData* nsdata = [NSData dataWithBytes:data.c_str() length:data.size()];
  PKPass* pass = [[PKPass alloc] initWithData:nsdata error:nil];
  ASSERT_TRUE(pass);

  [coordinator_ passKitTabHelper:tab_helper()
            presentDialogForPass:pass
                        webState:web_state_.get()];

  EXPECT_TRUE(
      WaitUntilConditionOrTimeout(base::test::ios::kWaitForUIElementTimeout, ^{
        return [base_view_controller_.presentedViewController class] ==
               [PKAddPassesViewController class];
      }));

  histogram_tester_.ExpectUniqueSample(
      kUmaPresentAddPassesDialogResult,
      static_cast<base::HistogramBase::Sample>(
          PresentAddPassesDialogResult::kSuccessful),
      1);

  UIViewController* presented_controller =
      base_view_controller_.presentedViewController;

  [coordinator_ passKitTabHelper:tab_helper()
            presentDialogForPass:pass
                        webState:web_state_.get()];

  // New UI presentation is ignored.
  EXPECT_EQ(presented_controller,
            base_view_controller_.presentedViewController);

  histogram_tester_.ExpectBucketCount(
      kUmaPresentAddPassesDialogResult,
      static_cast<base::HistogramBase::Sample>(
          PresentAddPassesDialogResult::
              kAnotherAddPassesViewControllerIsPresented),
      1);

  // Previously presented view controller can be dismissed.
  [coordinator_ stop];
  EXPECT_TRUE(WaitUntilConditionOrTimeout(kWaitForUIElementTimeout, ^{
    return base_view_controller_.presentedViewController == nil;
  }));
}

// Tests presenting valid PKPass object, while another view controller is
// already presented.
TEST_F(PassKitCoordinatorTest, AnotherViewControllerIsPresented) {
  if (ui::GetDeviceFormFactor() == ui::DEVICE_FORM_FACTOR_TABLET) {
    // Wallet app is not supported on iPads.
    return;
  }

  // Present another view controller.
  UIViewController* presented_controller = [[UIViewController alloc] init];
  [base_view_controller_ presentViewController:presented_controller
                                      animated:YES
                                    completion:nil];
  EXPECT_TRUE(
      WaitUntilConditionOrTimeout(base::test::ios::kWaitForUIElementTimeout, ^{
        return presented_controller ==
               base_view_controller_.presentedViewController;
      }));

  // Attempt to present "Add pkpass UI".
  std::string data = testing::GetTestFileContents(testing::kPkPassFilePath);
  NSData* nsdata = [NSData dataWithBytes:data.c_str() length:data.size()];
  PKPass* pass = [[PKPass alloc] initWithData:nsdata error:nil];
  ASSERT_TRUE(pass);

  [coordinator_ passKitTabHelper:tab_helper()
            presentDialogForPass:pass
                        webState:web_state_.get()];

  // New UI presentation is ignored.
  EXPECT_EQ(presented_controller,
            base_view_controller_.presentedViewController);

  histogram_tester_.ExpectBucketCount(
      kUmaPresentAddPassesDialogResult,
      static_cast<base::HistogramBase::Sample>(
          PresentAddPassesDialogResult::kAnotherViewControllerIsPresented),
      1);
}

// Tests that PassKitCoordinator presents error infobar for invalid PKPass
// object.
TEST_F(PassKitCoordinatorTest, InvalidPassKitObject) {
  [coordinator_ passKitTabHelper:tab_helper()
            presentDialogForPass:nil
                        webState:web_state_.get()];

  infobars::InfoBarManager* infobar_manager =
      InfoBarManagerImpl::FromWebState(web_state_.get());
  ASSERT_EQ(1U, infobar_manager->infobar_count());
  infobars::InfoBar* infobar = infobar_manager->infobar_at(0);
  ASSERT_TRUE(infobar->delegate());
  auto* delegate = infobar->delegate()->AsConfirmInfoBarDelegate();
  ASSERT_TRUE(delegate);
  DCHECK_EQ(l10n_util::GetStringUTF16(IDS_IOS_GENERIC_PASSKIT_ERROR),
            delegate->GetMessageText());
  EXPECT_FALSE(coordinator_.webState);
  EXPECT_FALSE(coordinator_.pass);

  histogram_tester_.ExpectTotalCount(kUmaPresentAddPassesDialogResult, 0);
}

// Tests that destroying web state nulls out webState property.
TEST_F(PassKitCoordinatorTest, DestroyWebState) {
  coordinator_.webState = web_state_.get();
  ASSERT_TRUE(coordinator_.webState);
  web_state_.reset();
  EXPECT_FALSE(coordinator_.webState);
}
