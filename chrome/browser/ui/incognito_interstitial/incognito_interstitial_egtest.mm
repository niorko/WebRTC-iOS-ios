// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "base/strings/sys_string_conversions.h"
#import "ios/chrome/browser/pref_names.h"
#import "ios/chrome/browser/ui/ui_feature_flags.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey.h"
#import "ios/chrome/test/earl_grey/chrome_matchers.h"
#import "ios/chrome/test/earl_grey/web_http_server_chrome_test_case.h"
#import "ios/testing/earl_grey/earl_grey_test.h"
#import "net/test/embedded_test_server/embedded_test_server.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using chrome_test_util::IncognitoInterstitialCancelButton;
using chrome_test_util::IncognitoInterstitialMatcher;
using chrome_test_util::IncognitoInterstitialOpenInChromeButton;
using chrome_test_util::IncognitoInterstitialOpenInChromeIncognitoButton;
using chrome_test_util::IncognitoInterstitialSubtitleForURL;
using chrome_test_util::NTPIncognitoView;

@interface IncognitoInterstitialTestCase : ChromeTestCase
@end

@implementation IncognitoInterstitialTestCase

- (AppLaunchConfiguration)appConfigurationForTestCase {
  AppLaunchConfiguration config = [super appConfigurationForTestCase];
  config.features_enabled.push_back(kIOS3PIntentsInIncognito);
  return config;
}

- (void)setUp {
  [super setUp];
  [ChromeEarlGrey setBoolValue:YES
                   forUserPref:prefs::kIncognitoInterstitialEnabled];

  GREYAssertTrue(self.testServer->Start(), @"Server did not start.");
}

- (void)tearDown {
  [ChromeEarlGrey setBoolValue:NO
                   forUserPref:prefs::kIncognitoInterstitialEnabled];
  [super tearDown];
}

// Test the "Open in Chrome Incognito" journey through the Incognito
// interstitial.
- (void)testOpenInIncognitoFromNTP {
  [ChromeEarlGrey closeCurrentTab];
  [ChromeEarlGrey openNewIncognitoTab];

  // Starting from Incognito NTP, loading a new URL.
  GURL destinationURL = self.testServer->GetURL("/destination.html");
  [ChromeEarlGrey sceneOpenURL:destinationURL];
  // Wait for the interstitial to appear.
  [ChromeEarlGrey
      waitForUIElementToAppearWithMatcher:IncognitoInterstitialMatcher()];
  // Check the appropriate subtitle is sufficiently visible within the
  // Interstitial.
  [[EarlGrey selectElementWithMatcher:IncognitoInterstitialSubtitleForURL(
                                          destinationURL.spec())]
      assertWithMatcher:grey_sufficientlyVisible()];
  // Tap the "Open in Chrome Incognito" button.
  [[EarlGrey selectElementWithMatcher:
                 IncognitoInterstitialOpenInChromeIncognitoButton()]
      performAction:grey_tap()];
  // Wait for the interstitial to disappear.
  [ChromeEarlGrey
      waitForUIElementToDisappearWithMatcher:IncognitoInterstitialMatcher()];
  // Wait for the expected page content to be displayed.
  [ChromeEarlGrey waitForWebStateContainingText:"You've arrived"];
  // Wait for the Incognito tab count to be one, as expected.
  [ChromeEarlGrey waitForIncognitoTabCount:1];
}

// Test the "Open in Chrome" journey through the Incognito interstitial.
- (void)testOpenInChromeFromNTP {
  // Starting from NTP, loading a new URL.
  GURL destinationURL = self.testServer->GetURL("/destination.html");
  [ChromeEarlGrey sceneOpenURL:destinationURL];
  // Wait for the interstitial to appear.
  [ChromeEarlGrey
      waitForUIElementToAppearWithMatcher:IncognitoInterstitialMatcher()];
  // Check the appropriate subtitle is sufficiently visible within the
  // Interstitial.
  [[EarlGrey selectElementWithMatcher:IncognitoInterstitialSubtitleForURL(
                                          destinationURL.spec())]
      assertWithMatcher:grey_sufficientlyVisible()];
  // Tap the "Open in Chrome" button.
  [[EarlGrey selectElementWithMatcher:IncognitoInterstitialOpenInChromeButton()]
      performAction:grey_tap()];
  // Wait for the interstitial to disappear.
  [ChromeEarlGrey
      waitForUIElementToDisappearWithMatcher:IncognitoInterstitialMatcher()];
  // Wait for the expected page content to be displayed.
  [ChromeEarlGrey waitForWebStateContainingText:"You've arrived"];
  // Wait for the main tab count to be one, as expected.
  [ChromeEarlGrey waitForMainTabCount:1];
}

// Test the "Open in Chrome" journey starting from an already opened tab.
- (void)testOpenInChromeFromTab {
  // Go from NTP to some other web page.
  [ChromeEarlGrey loadURL:GURL("https://invalid")];

  // Starting from this regular tab, loading a new URL.
  GURL destinationURL = self.testServer->GetURL("/destination.html");
  [ChromeEarlGrey sceneOpenURL:destinationURL];
  // Wait for the interstitial to appear.
  [ChromeEarlGrey
      waitForUIElementToAppearWithMatcher:IncognitoInterstitialMatcher()];
  // Check the appropriate subtitle is sufficiently visible within the
  // Interstitial.
  [[EarlGrey selectElementWithMatcher:IncognitoInterstitialSubtitleForURL(
                                          destinationURL.spec())]
      assertWithMatcher:grey_sufficientlyVisible()];
  // Tap the "Open in Chrome" button.
  [[EarlGrey selectElementWithMatcher:IncognitoInterstitialOpenInChromeButton()]
      performAction:grey_tap()];
  // Wait for the interstitial to disappear.
  [ChromeEarlGrey
      waitForUIElementToDisappearWithMatcher:IncognitoInterstitialMatcher()];
  // Wait for the expected page content to be displayed.
  [ChromeEarlGrey waitForWebStateContainingText:"You've arrived"];
  // Wait for the main tab count to be two, as expected.
  [ChromeEarlGrey waitForMainTabCount:2];
}

// Test the "Open in Chrome Incognito" journey starting from the tab switcher.
- (void)testOpenInChromeIncognitoFromTabSwitcher {
  // Close the NTP to go to the tab switcher.
  [ChromeEarlGrey closeCurrentTab];
  [ChromeEarlGrey waitForMainTabCount:0];

  // Starting from the tab switcher, loading a new URL.
  GURL destinationURL = self.testServer->GetURL("/destination.html");
  [ChromeEarlGrey sceneOpenURL:destinationURL];
  // Wait for the interstitial to appear.
  [ChromeEarlGrey
      waitForUIElementToAppearWithMatcher:IncognitoInterstitialMatcher()];
  // Check the appropriate subtitle is sufficiently visible within the
  // Interstitial.
  [[EarlGrey selectElementWithMatcher:IncognitoInterstitialSubtitleForURL(
                                          destinationURL.spec())]
      assertWithMatcher:grey_sufficientlyVisible()];
  // Tap the "Open in Chrome Incognito" button.
  [[EarlGrey selectElementWithMatcher:
                 IncognitoInterstitialOpenInChromeIncognitoButton()]
      performAction:grey_tap()];
  // Wait for the interstitial to disappear.
  [ChromeEarlGrey
      waitForUIElementToDisappearWithMatcher:IncognitoInterstitialMatcher()];
  // Wait for the expected page content to be displayed.
  [ChromeEarlGrey waitForWebStateContainingText:"You've arrived"];
  // Wait for the main tab count to be two, as expected.
  [ChromeEarlGrey waitForIncognitoTabCount:1];
}

// Test the "Cancel" button of the Incognito Interstitial.
- (void)testCancelButton {
  [ChromeEarlGrey openNewIncognitoTab];

  // Starting from this regular tab, loading a new URL.
  GURL destinationURL = self.testServer->GetURL("/destination.html");
  [ChromeEarlGrey sceneOpenURL:destinationURL];
  // Wait for the interstitial to appear.
  [ChromeEarlGrey
      waitForUIElementToAppearWithMatcher:IncognitoInterstitialMatcher()];
  // Check the appropriate subtitle is sufficiently visible within the
  // Interstitial.
  [[EarlGrey selectElementWithMatcher:IncognitoInterstitialSubtitleForURL(
                                          destinationURL.spec())]
      assertWithMatcher:grey_sufficientlyVisible()];
  // Tap the Cancel button.
  [[EarlGrey selectElementWithMatcher:IncognitoInterstitialCancelButton()]
      performAction:grey_tap()];
  // Wait for the interstitial to disappear.
  [ChromeEarlGrey
      waitForUIElementToDisappearWithMatcher:IncognitoInterstitialMatcher()];
  // Wait for the Incognito tab count to be one, as expected.
  [ChromeEarlGrey waitForIncognitoTabCount:1];
  // Check the Incognito NTP is back.
  [[EarlGrey selectElementWithMatcher:NTPIncognitoView()]
      assertWithMatcher:grey_sufficientlyVisible()];
}

// Test that a new intent triggers the dismissal of a former instance of the
// Interstitial, then displays an Interstitial with the new URL.
- (void)testNewInterstitialReplacesFormerInterstitial {
  // Starting from NTP, loading a new URL.
  GURL destinationURL = self.testServer->GetURL("/destination.html");
  [ChromeEarlGrey sceneOpenURL:destinationURL];
  // Wait for the interstitial to appear.
  [ChromeEarlGrey
      waitForUIElementToAppearWithMatcher:IncognitoInterstitialMatcher()];
  // Check the appropriate subtitle is sufficiently visible within the
  // Interstitial.
  [[EarlGrey selectElementWithMatcher:IncognitoInterstitialSubtitleForURL(
                                          destinationURL.spec())]
      assertWithMatcher:grey_sufficientlyVisible()];
  // While the Interstitial is shown, loading an alternative URL.
  GURL alternativeURL = self.testServer->GetURL("/chromium_logo_page.html");
  [ChromeEarlGrey sceneOpenURL:alternativeURL];
  // Wait for the interstitial to appear.
  [ChromeEarlGrey
      waitForUIElementToAppearWithMatcher:IncognitoInterstitialMatcher()];
  // Check the appropriate subtitle is sufficiently visible within the
  // Interstitial.
  [[EarlGrey selectElementWithMatcher:IncognitoInterstitialSubtitleForURL(
                                          alternativeURL.spec())]
      assertWithMatcher:grey_sufficientlyVisible()];
  // Tap the "Open in Chrome Incognito" button.
  [[EarlGrey selectElementWithMatcher:
                 IncognitoInterstitialOpenInChromeIncognitoButton()]
      performAction:grey_tap()];
  // Wait for the interstitial to disappear.
  [ChromeEarlGrey
      waitForUIElementToDisappearWithMatcher:IncognitoInterstitialMatcher()];
  // Wait for the expected page content to be displayed.
  [ChromeEarlGrey waitForWebStateContainingText:
                      "Page with some text and the chromium logo image."];
  // Wait for the Incognito tab count to be one, as expected.
  [ChromeEarlGrey waitForIncognitoTabCount:1];
}

@end