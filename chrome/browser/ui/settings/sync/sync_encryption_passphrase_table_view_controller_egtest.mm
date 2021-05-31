// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <UIKit/UIKit.h>
#include "components/signin/public/base/account_consistency_method.h"
#include "components/strings/grit/components_strings.h"
#import "ios/chrome/browser/ui/authentication/signin_earl_grey.h"
#import "ios/chrome/browser/ui/authentication/signin_earl_grey_ui.h"
#import "ios/chrome/browser/ui/settings/google_services/google_services_settings_constants.h"
#import "ios/chrome/browser/ui/settings/google_services/manage_sync_settings_constants.h"
#import "ios/chrome/grit/ios_strings.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey_ui.h"
#import "ios/chrome/test/earl_grey/chrome_matchers.h"
#import "ios/chrome/test/earl_grey/chrome_test_case.h"
#import "ios/testing/earl_grey/earl_grey_test.h"
#include "ui/base/l10n/l10n_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using chrome_test_util::ButtonWithAccessibilityLabel;
using chrome_test_util::ButtonWithAccessibilityLabelId;
using chrome_test_util::NavigationBarCancelButton;
using chrome_test_util::MatchInWindowWithNumber;
using chrome_test_util::SettingsDoneButton;
using chrome_test_util::SettingsMenuBackButton;
using chrome_test_util::SyncSettingsConfirmButton;
using chrome_test_util::PrimarySignInButton;

@interface SyncEncryptionPassphraseTestCase : ChromeTestCase
@end

@implementation SyncEncryptionPassphraseTestCase

- (AppLaunchConfiguration)appConfigurationForTestCase {
  AppLaunchConfiguration config;
  config.features_disabled.push_back(signin::kMobileIdentityConsistency);
  return config;
}

// Tests to open the sync passphrase view, and to close it.
- (void)testShowSyncPassphraseAndDismiss {
  [ChromeEarlGrey addBookmarkWithSyncPassphrase:@"hello"];
  // Signin.
  FakeChromeIdentity* fakeIdentity = [SigninEarlGrey fakeIdentity1];
  [SigninEarlGreyUI signinWithFakeIdentity:fakeIdentity];
  [ChromeEarlGrey openNewTab];
  [[EarlGrey selectElementWithMatcher:ButtonWithAccessibilityLabelId(
                                          IDS_IOS_SYNC_ENTER_PASSPHRASE)]
      performAction:grey_tap()];
  [[EarlGrey selectElementWithMatcher:NavigationBarCancelButton()]
      performAction:grey_tap()];
  // Wait until the settings is fully removed.
  [ChromeEarlGreyUI waitForAppToIdle];
}

// Tests opening the sync passphrase view, then a new window and check that
// enter passphrase message appears.
- (void)testShowSyncPassphraseInNewWindowAndDismiss {
  if (![ChromeEarlGrey areMultipleWindowsSupported])
    EARL_GREY_TEST_DISABLED(@"Multiple windows can't be opened.");

  [ChromeEarlGrey addBookmarkWithSyncPassphrase:@"hello"];
  // Signin.
  FakeChromeIdentity* fakeIdentity = [SigninEarlGrey fakeIdentity1];
  [SigninEarlGreyUI signinWithFakeIdentity:fakeIdentity];

  [ChromeEarlGrey openNewWindow];
  [ChromeEarlGrey waitForForegroundWindowCount:2];

  [[EarlGrey
      selectElementWithMatcher:MatchInWindowWithNumber(
                                   1, ButtonWithAccessibilityLabelId(
                                          IDS_IOS_SYNC_ENTER_PASSPHRASE))]
      performAction:grey_tap()];
  [[EarlGrey selectElementWithMatcher:MatchInWindowWithNumber(
                                          1, NavigationBarCancelButton())]
      performAction:grey_tap()];
  // Wait until the settings is fully removed.
  [ChromeEarlGreyUI waitForAppToIdle];

  [ChromeEarlGrey closeWindowWithNumber:1];
  [ChromeEarlGrey waitForForegroundWindowCount:1];

  [SigninEarlGrey signOut];
  [SigninEarlGrey verifySignedOut];
}

// Tests entering sync passphrase from the sign-in flow.
- (void)testEnterSyncPassphraseInSignIn {
  [ChromeEarlGrey addBookmarkWithSyncPassphrase:@"hello"];
  // Access advanced settings sign-in.
  FakeChromeIdentity* fakeIdentity = [SigninEarlGrey fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];
  [ChromeEarlGreyUI openSettingsMenu];
  [ChromeEarlGreyUI tapSettingsMenuButton:PrimarySignInButton()];
  [SigninEarlGreyUI tapSettingsLink];

  [[EarlGrey
      selectElementWithMatcher:grey_accessibilityID(
                                   kManageSyncCellAccessibilityIdentifier)]
      performAction:grey_tap()];

  // Scroll to bottom of Manage Sync Settings, if necessary.
  [[EarlGrey selectElementWithMatcher:
                 grey_allOf(grey_accessibilityID(
                                kManageSyncTableViewAccessibilityIdentifier),
                            grey_sufficientlyVisible(), nil)]
      performAction:grey_scrollToContentEdge(kGREYContentEdgeBottom)];

  // Select Encryption item.
  [[EarlGrey
      selectElementWithMatcher:grey_accessibilityLabel(l10n_util::GetNSString(
                                   IDS_IOS_MANAGE_SYNC_ENCRYPTION))]
      performAction:grey_tap()];

  [[EarlGrey selectElementWithMatcher:
                 grey_accessibilityID(
                     kSyncEncryptionPassphraseTextFieldAccessibilityIdentifier)]
      performAction:grey_typeText(@"hello")];

  [[EarlGrey
      selectElementWithMatcher:grey_allOf(
                                   grey_kindOfClassName(@"_UIButtonBarButton"),
                                   ButtonWithAccessibilityLabel(
                                       l10n_util::GetNSString(
                                           IDS_IOS_SYNC_DECRYPT_BUTTON)),
                                   nil)] performAction:grey_tap()];
  [[EarlGrey selectElementWithMatcher:SettingsMenuBackButton()]
      performAction:grey_tap()];
  [[EarlGrey selectElementWithMatcher:SyncSettingsConfirmButton()]
      performAction:grey_tap()];

  // Test the user is signed in.
  [SigninEarlGrey verifySignedInWithFakeIdentity:fakeIdentity];
}

@end
