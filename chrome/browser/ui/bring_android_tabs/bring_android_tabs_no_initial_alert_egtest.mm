// Copyright 2023 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/bring_android_tabs/bring_android_tabs_app_interface.h"
#import "ios/chrome/browser/ui/bring_android_tabs/bring_android_tabs_test_utils.h"
#import "ios/chrome/grit/ios_strings.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey_app_interface.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey_ui.h"
#import "ios/chrome/test/earl_grey/chrome_matchers.h"
#import "ios/chrome/test/earl_grey/chrome_test_case.h"
#import "ios/testing/earl_grey/app_launch_manager.h"
#import "ios/testing/earl_grey/disabled_test_macros.h"
#import "ios/testing/earl_grey/earl_grey_test.h"
#import "ui/base/l10n/l10n_util_mac.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

// Test suite that tests cases where the prompt may not be shown when the user
// first goes to the tab grid.
@interface BringAndroidTabsNoInitialAlertTestCase : ChromeTestCase

@end

@implementation BringAndroidTabsNoInitialAlertTestCase

- (void)tearDown {
  CleanUp();
  [super tearDown];
}

// Tests that non Android Switchers should not see the prompt, even if they have
// enrolled in sync and have recent tabs from Android phones.
- (void)testNonAndroidSwitcherShouldNotSeePrompt {
  if ([ChromeEarlGrey isIPadIdiom]) {
    EARL_GREY_TEST_SKIPPED(@"Test skipped on iPad.");
  }
  AppLaunchConfiguration config = GetConfiguration(/*is_android_switcher=*/NO,
                                                   /*show_bottom_message=*/NO);
  [[AppLaunchManager sharedManager] ensureAppLaunchedWithConfiguration:config];
  [BringAndroidTabsAppInterface
      addSessionToFakeSyncServer:BringAndroidTabsAppInterfaceForeignSession::
                                     kRecentFromAndroidPhone];
  CompleteFREWithSyncEnabled(YES);
  [ChromeEarlGreyUI openTabGrid];
  VerifyConfirmationAlertPromptVisibility(NO);
}

// Tests that if the user is currently using Chrome on iPad, they should not see
// the prompt, even if they are classified as Android switcher, enrolled in
// sync, and have recent tabs from Android phones.
- (void)testAndroidSwitcherOnIPadShouldNotSeePrompt {
  if (![ChromeEarlGrey isIPadIdiom]) {
    EARL_GREY_TEST_SKIPPED(@"Test skipped on iPhone.");
  }
  AppLaunchConfiguration config = GetConfiguration(/*is_android_switcher=*/YES,
                                                   /*show_bottom_message=*/NO);
  [[AppLaunchManager sharedManager] ensureAppLaunchedWithConfiguration:config];
  [BringAndroidTabsAppInterface
      addSessionToFakeSyncServer:BringAndroidTabsAppInterfaceForeignSession::
                                     kRecentFromAndroidPhone];
  CompleteFREWithSyncEnabled(YES);
  [ChromeEarlGreyUI openTabGrid];
  VerifyConfirmationAlertPromptVisibility(NO);
}

// Tests that users who are not enrolled in sync would not see the prompt, even
// if they have recent tabs from Android phones.
- (void)testUserWhoIsNotEnrolledInSyncShouldNotSeePromptUntilSync {
  if ([ChromeEarlGrey isIPadIdiom]) {
    EARL_GREY_TEST_SKIPPED(@"Test skipped on iPad.");
  }
  AppLaunchConfiguration config = GetConfiguration(/*is_android_switcher=*/YES,
                                                   /*show_bottom_message=*/NO);
  [[AppLaunchManager sharedManager] ensureAppLaunchedWithConfiguration:config];
  [BringAndroidTabsAppInterface
      addSessionToFakeSyncServer:BringAndroidTabsAppInterfaceForeignSession::
                                     kRecentFromAndroidPhone];
  CompleteFREWithSyncEnabled(NO);
  [ChromeEarlGreyUI openTabGrid];
  VerifyConfirmationAlertPromptVisibility(NO);
  // Enroll in sync and check again.
  [[EarlGrey selectElementWithMatcher:chrome_test_util::TabGridDoneButton()]
      performAction:grey_tap()];
  SignInAndSync();
  [ChromeEarlGreyUI openTabGrid];
  VerifyConfirmationAlertPromptVisibility(YES);
}

// Tests that Android switchers enrolled in sync would not see the prompt, if
// the tabs synced from other devices have not been active for more than two
// weeks.
- (void)testAndroidSwitcherWithOnlyExpiredTabsShouldNotSeePrompt {
  if ([ChromeEarlGrey isIPadIdiom]) {
    EARL_GREY_TEST_SKIPPED(@"Test skipped on iPad.");
  }
  AppLaunchConfiguration config = GetConfiguration(/*is_android_switcher=*/YES,
                                                   /*show_bottom_message=*/NO);
  [[AppLaunchManager sharedManager] ensureAppLaunchedWithConfiguration:config];
  [BringAndroidTabsAppInterface
      addSessionToFakeSyncServer:BringAndroidTabsAppInterfaceForeignSession::
                                     kExpiredFromAndroidPhone];
  CompleteFREWithSyncEnabled(YES);
  [ChromeEarlGreyUI openTabGrid];
  VerifyConfirmationAlertPromptVisibility(NO);
}

// Tests that Android switchers enrolled in sync would not see the prompt, if
// the tabs are not synced from phone devices.
- (void)testAndroidSwitcherWithNoTabsFromPhoneShouldNotSeePrompt {
  if ([ChromeEarlGrey isIPadIdiom]) {
    EARL_GREY_TEST_SKIPPED(@"Test skipped on iPad.");
  }
  AppLaunchConfiguration config = GetConfiguration(/*is_android_switcher=*/YES,
                                                   /*show_bottom_message=*/NO);
  [[AppLaunchManager sharedManager] ensureAppLaunchedWithConfiguration:config];
  [BringAndroidTabsAppInterface
      addSessionToFakeSyncServer:BringAndroidTabsAppInterfaceForeignSession::
                                     kRecentFromDesktop];
  CompleteFREWithSyncEnabled(YES);
  [ChromeEarlGreyUI openTabGrid];
  VerifyConfirmationAlertPromptVisibility(NO);
}

// Tests that Android switchers enrolled in sync and have recent tabs would see
// the prompt, but the prompt would not include tabs that have not been active
// for more than two weeks or are not from an Android phone.
- (void)testAndroidSwitcherShouldSeePromptShowingOnlyRecentSessionsFromPhone {
  if ([ChromeEarlGrey isIPadIdiom]) {
    EARL_GREY_TEST_SKIPPED(@"Test skipped on iPad.");
  }
  AppLaunchConfiguration config = GetConfiguration(/*is_android_switcher=*/YES,
                                                   /*show_bottom_message=*/NO);
  [[AppLaunchManager sharedManager] ensureAppLaunchedWithConfiguration:config];
  // Add all test sessions.
  [BringAndroidTabsAppInterface
      addSessionToFakeSyncServer:BringAndroidTabsAppInterfaceForeignSession::
                                     kRecentFromAndroidPhone];
  [BringAndroidTabsAppInterface
      addSessionToFakeSyncServer:BringAndroidTabsAppInterfaceForeignSession::
                                     kExpiredFromAndroidPhone];
  [BringAndroidTabsAppInterface
      addSessionToFakeSyncServer:BringAndroidTabsAppInterfaceForeignSession::
                                     kRecentFromDesktop];
  // Execute test behavior.
  CompleteFREWithSyncEnabled(YES);
  [ChromeEarlGreyUI openTabGrid];
  VerifyConfirmationAlertPromptVisibility(YES);
  // Verify tab count.
  int expectedTabCountFromDistantSessions = [BringAndroidTabsAppInterface
      tabsCountForSession:BringAndroidTabsAppInterfaceForeignSession::
                              kRecentFromAndroidPhone];
  NSString* expectedButtonText = l10n_util::GetPluralNSStringF(
      IDS_IOS_BRING_ANDROID_TABS_PROMPT_OPEN_TABS_BUTTON,
      expectedTabCountFromDistantSessions);
  [[EarlGrey selectElementWithMatcher:grey_buttonTitle(expectedButtonText)]
      assertWithMatcher:grey_sufficientlyVisible()];
}

@end
