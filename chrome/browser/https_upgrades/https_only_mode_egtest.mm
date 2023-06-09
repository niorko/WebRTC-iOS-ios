// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <map>
#include <string>

#include "base/bind.h"
#include "base/strings/escape.h"
#include "base/strings/string_util.h"
#include "base/strings/stringprintf.h"
#include "base/strings/sys_string_conversions.h"
#import "base/test/ios/wait_util.h"
#include "base/test/metrics/histogram_tester.h"
#include "components/security_interstitials/core/https_only_mode_metrics.h"
#import "ios/chrome/browser/https_upgrades/https_upgrade_app_interface.h"
#import "ios/chrome/browser/https_upgrades/https_upgrade_test_helper.h"
#include "ios/chrome/browser/metrics/metrics_app_interface.h"
#include "ios/chrome/browser/pref_names.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey_app_interface.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey_ui.h"
#import "ios/chrome/test/earl_grey/chrome_matchers.h"
#import "ios/chrome/test/earl_grey/chrome_test_case.h"
#import "ios/chrome/test/earl_grey/web_http_server_chrome_test_case.h"
#include "ios/components/security_interstitials/https_only_mode/feature.h"
#import "ios/testing/earl_grey/earl_grey_test.h"
#include "ios/testing/embedded_test_server_handlers.h"
#include "ios/web/common/features.h"
#include "ios/web/public/test/element_selector.h"
#include "net/test/embedded_test_server/default_handlers.h"
#include "net/test/embedded_test_server/http_request.h"
#include "net/test/embedded_test_server/http_response.h"
#include "net/test/embedded_test_server/request_handler_util.h"
#include "ui/base/l10n/l10n_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using base::test::ios::kWaitForPageLoadTimeout;
using base::test::ios::WaitUntilConditionOrTimeout;

namespace {

const char kInterstitialText[] =
    "You are seeing this warning because this site does not support HTTPS";

}  // namespace

// Tests for HTTPS-Only Mode.
@interface HttpsOnlyModeUpgradeTestCase : HttpsUpgradeTestCase {
}
@end

@implementation HttpsOnlyModeUpgradeTestCase

- (AppLaunchConfiguration)appConfigurationForTestCase {
  AppLaunchConfiguration config;
  config.relaunch_policy = NoForceRelaunchAndResetState;
  config.features_enabled.push_back(
      security_interstitials::features::kHttpsOnlyMode);
  return config;
}

- (void)setUp {
  [super setUp];
  [ChromeEarlGrey clearBrowsingHistory];
  [HttpsUpgradeAppInterface clearAllowlist];

  [ChromeEarlGrey setBoolValue:YES forUserPref:prefs::kHttpsOnlyModeEnabled];
}

- (void)tearDown {
  [ChromeEarlGrey setBoolValue:NO forUserPref:prefs::kHttpsOnlyModeEnabled];
  [HttpsUpgradeAppInterface clearAllowlist];

  [super tearDown];
}

// Asserts that the navigation wasn't upgraded.
- (void)assertNoUpgrade {
  GREYAssertNil([MetricsAppInterface
                    expectTotalCount:0
                        forHistogram:@(security_interstitials::https_only_mode::
                                           kEventHistogram)],
                @"Shouldn't record event histogram");
  GREYAssert(![HttpsUpgradeAppInterface isHttpsOnlyModeTimerRunning],
             @"Timer is still running");
  GREYAssert(![HttpsUpgradeAppInterface isOmniboxUpgradeTimerRunning],
             @"Omnibox upgrade timer is unexpectedly running");
}

// Asserts that the metrics are properly recorded for a successful upgrade.
- (void)assertSuccessfulUpgrade {
  GREYAssertNil([MetricsAppInterface
                    expectTotalCount:2
                        forHistogram:@(security_interstitials::https_only_mode::
                                           kEventHistogram)],
                @"Failed to record event histogram");

  GREYAssertNil([MetricsAppInterface
                     expectCount:1
                       forBucket:static_cast<int>(
                                     security_interstitials::https_only_mode::
                                         Event::kUpgradeAttempted)
                    forHistogram:@(security_interstitials::https_only_mode::
                                       kEventHistogram)],
                @"Failed to record upgrade attempt");
  GREYAssertNil([MetricsAppInterface
                     expectCount:1
                       forBucket:static_cast<int>(
                                     security_interstitials::https_only_mode::
                                         Event::kUpgradeSucceeded)
                    forHistogram:@(security_interstitials::https_only_mode::
                                       kEventHistogram)],
                @"Failed to record upgrade attempt");

  GREYAssert(![HttpsUpgradeAppInterface isHttpsOnlyModeTimerRunning],
             @"Timer is still running");
  GREYAssert(![HttpsUpgradeAppInterface isOmniboxUpgradeTimerRunning],
             @"Omnibox upgrade timer is unexpectedly running");
}

// Asserts that the metrics are properly recorded for a failed upgrade.
// repeatCount is the expected number of times the upgrade failed.
- (void)assertFailedUpgrade:(int)repeatCount {
  GREYAssertNil([MetricsAppInterface
                    expectTotalCount:(repeatCount * 2)
                        forHistogram:@(security_interstitials::https_only_mode::
                                           kEventHistogram)],
                @"Failed to record event histogram");

  GREYAssertNil([MetricsAppInterface
                     expectCount:repeatCount
                       forBucket:static_cast<int>(
                                     security_interstitials::https_only_mode::
                                         Event::kUpgradeAttempted)
                    forHistogram:@(security_interstitials::https_only_mode::
                                       kEventHistogram)],
                @"Failed to record upgrade attempt");
  GREYAssertNil([MetricsAppInterface
                     expectCount:repeatCount
                       forBucket:static_cast<int>(
                                     security_interstitials::https_only_mode::
                                         Event::kUpgradeFailed)
                    forHistogram:@(security_interstitials::https_only_mode::
                                       kEventHistogram)],
                @"Failed to record fail event");
  GREYAssert(![HttpsUpgradeAppInterface isHttpsOnlyModeTimerRunning],
             @"Timer is still running");
  GREYAssert(![HttpsUpgradeAppInterface isOmniboxUpgradeTimerRunning],
             @"Omnibox upgrade timer is unexpectedly running");
}

// Asserts that the metrics are properly recorded for a timed-out upgrade.
// repeatCount is the expected number of times the upgrade failed.
- (void)assertTimedOutUpgrade:(int)repeatCount {
  GREYAssertNil([MetricsAppInterface
                    expectTotalCount:(repeatCount * 2)
                        forHistogram:@(security_interstitials::https_only_mode::
                                           kEventHistogram)],
                @"Incorrect numbber of records in event histogram");

  GREYAssertNil([MetricsAppInterface
                     expectCount:repeatCount
                       forBucket:static_cast<int>(
                                     security_interstitials::https_only_mode::
                                         Event::kUpgradeAttempted)
                    forHistogram:@(security_interstitials::https_only_mode::
                                       kEventHistogram)],
                @"Failed to record upgrade attempt");
  GREYAssertNil([MetricsAppInterface
                     expectCount:repeatCount
                       forBucket:static_cast<int>(
                                     security_interstitials::https_only_mode::
                                         Event::kUpgradeTimedOut)
                    forHistogram:@(security_interstitials::https_only_mode::
                                       kEventHistogram)],
                @"Failed to record fail event");
  GREYAssert(![HttpsUpgradeAppInterface isHttpsOnlyModeTimerRunning],
             @"Timer is still running");
  GREYAssert(![HttpsUpgradeAppInterface isOmniboxUpgradeTimerRunning],
             @"Omnibox upgrade timer is unexpectedly running");
}

#pragma mark - Tests

// Disable the feature and navigate to an HTTP URL directly. Since the feature
// is disabled, this should load the HTTP URL even though the upgraded HTTPS
// version serves good SSL.
- (void)testUpgrade_FeatureDisabled_NoUpgrade {
  [ChromeEarlGrey setBoolValue:NO forUserPref:prefs::kHttpsOnlyModeEnabled];

  [HttpsUpgradeAppInterface setHTTPSPortForTesting:self.goodHTTPSServer->port()
                                      useFakeHTTPS:true];

  GURL testURL = self.testServer->GetURL("/");
  [ChromeEarlGrey loadURL:testURL];
  [ChromeEarlGrey waitForWebStateContainingText:"HTTP_RESPONSE"];
  [self assertNoUpgrade];
}

// Tests that navigations to localhost URLs aren't upgraded.
- (void)testUpgrade_Localhost_NoUpgrade {
  [HttpsUpgradeAppInterface setHTTPSPortForTesting:self.goodHTTPSServer->port()
                                      useFakeHTTPS:true];

  GURL testURL = self.testServer->GetURL("/");
  GURL::Replacements replacements;
  replacements.SetHostStr("localhost");
  GURL localhostURL = testURL.ReplaceComponents(replacements);

  [ChromeEarlGrey loadURL:localhostURL];
  [ChromeEarlGrey waitForWebStateContainingText:"HTTP_RESPONSE"];
  [self assertNoUpgrade];
}

// Navigate to an HTTP URL directly. The upgraded HTTPS version serves good SSL.
// This should end up loading the HTTPS version of the URL.
- (void)testUpgrade_GoodHTTPS {
  [HttpsUpgradeAppInterface setHTTPSPortForTesting:self.goodHTTPSServer->port()
                                      useFakeHTTPS:true];

  GURL testURL = self.testServer->GetURL("/");
  [ChromeEarlGrey loadURL:testURL];
  [ChromeEarlGrey waitForWebStateContainingText:"HTTPS_RESPONSE"];
  [self assertSuccessfulUpgrade];
}

// Navigate to an HTTP URL by clicking a link. This should end up loading the
// HTTPS version of the URL.
- (void)testUpgrade_GoodHTTPS_LinkClick {
  [HttpsUpgradeAppInterface setHTTPSPortForTesting:self.goodHTTPSServer->port()
                                      useFakeHTTPS:true];
  int HTTPPort = self.testServer->port();

  GURL testURL(base::StringPrintf(
      "data:text/html,"
      "<a href='http://127.0.0.1:%d/good-https' id='link'>Link</a><br>READY",
      HTTPPort));
  [ChromeEarlGrey loadURL:testURL];
  [ChromeEarlGrey waitForWebStateContainingText:"READY"];

  // Click on the http link. Should load the https URL.
  [ChromeEarlGrey tapWebStateElementWithID:@"link"];
  [ChromeEarlGrey waitForWebStateContainingText:"HTTPS_RESPONSE"];
  [self assertSuccessfulUpgrade];
}

// Navigate to an HTTP URL directly. The upgraded HTTPS version serves good SSL
// which redirects to the original HTTP URL. This should show the interstitial.
- (void)testUpgrade_HTTPSRedirectsToHTTP {
  [HttpsUpgradeAppInterface setHTTPSPortForTesting:self.goodHTTPSServer->port()
                                      useFakeHTTPS:true];

  [ChromeEarlGrey loadURL:GURL("chrome://version")];
  [ChromeEarlGrey waitForWebStateContainingText:"Revision"];

  GURL targetURL = self.testServer->GetURL("/");
  GURL upgradedURL =
      self.goodHTTPSServer->GetURL("/?redirect=" + targetURL.spec());
  const std::string port_str = base::NumberToString(self.testServer->port());
  GURL::Replacements replacements;
  replacements.SetPortStr(port_str);
  GURL testURL = upgradedURL.ReplaceComponents(replacements);

  [ChromeEarlGrey loadURL:testURL];
  [ChromeEarlGrey waitForWebStateContainingText:kInterstitialText];
  [self assertFailedUpgrade:1];

  // Click through the interstitial. This should load the HTTP page.
  [ChromeEarlGrey tapWebStateElementWithID:@"proceed-button"];
  [ChromeEarlGrey waitForWebStateContainingText:"HTTP_RESPONSE"];
  GREYAssert(![HttpsUpgradeAppInterface isHttpsOnlyModeTimerRunning],
             @"Timer is still running");

  // Going back should go to chrome://version.
  [ChromeEarlGrey goBack];
  [ChromeEarlGrey waitForWebStateContainingText:"Revision"];
  [self assertFailedUpgrade:1];
}

// Tests that prerendered navigations that should be upgraded are cancelled.
// This test is adapted from testTapPrerenderSuggestions() in
// prerender_egtest.mm.
- (void)testUpgrade_BadHTTPS_PrerenderCanceled {
  // TODO(crbug.com/793306): Re-enable the test on iPad once the alternate
  // letters problem is fixed.
  if ([ChromeEarlGrey isIPadIdiom]) {
    EARL_GREY_TEST_DISABLED(
        @"Disabled for iPad due to alternate letters educational screen.");
  }

  // TODO(crbug.com/1315304): Reenable.
  if ([ChromeEarlGrey isNewOmniboxPopupEnabled]) {
    EARL_GREY_TEST_DISABLED(@"Disabled for new popup");
  }

  [HttpsUpgradeAppInterface setHTTPSPortForTesting:self.badHTTPSServer->port()
                                      useFakeHTTPS:false];

  [ChromeEarlGrey clearBrowsingHistory];

  // Type the full URL. This will show an interstitial. This adds the URL to
  // history.
  GURL testURL = self.testServer->GetURL("/");
  NSString* pageString = base::SysUTF8ToNSString(testURL.GetContent());
  [[EarlGrey selectElementWithMatcher:chrome_test_util::FakeOmnibox()]
      performAction:grey_tap()];
  [ChromeEarlGrey
      waitForSufficientlyVisibleElementWithMatcher:chrome_test_util::Omnibox()];
  [[EarlGrey selectElementWithMatcher:chrome_test_util::Omnibox()]
      performAction:grey_typeText([pageString stringByAppendingString:@"\n"])];
  [ChromeEarlGrey waitForWebStateContainingText:kInterstitialText];
  [self assertFailedUpgrade:1];
  GREYAssertEqual(2, _HTTPResponseCounter,
                  @"The server should have responded twice");

  // Click through the interstitial.
  [ChromeEarlGrey tapWebStateElementWithID:@"proceed-button"];
  [ChromeEarlGrey waitForWebStateContainingText:"HTTP_RESPONSE"];
  GREYAssert(![HttpsUpgradeAppInterface isHttpsOnlyModeTimerRunning],
             @"Timer is still running");
  GREYAssertEqual(3, _HTTPResponseCounter,
                  @"The server should have responded three times");

  // Close all tabs and reopen. This clears the allowlist because it's currently
  // per-tab.
  [[self class] closeAllTabs];
  [ChromeEarlGrey openNewTab];

  // Type the begining of the address to have the autocomplete suggestion.
  [[EarlGrey selectElementWithMatcher:chrome_test_util::FakeOmnibox()]
      performAction:grey_tap()];
  [ChromeEarlGrey
      waitForSufficientlyVisibleElementWithMatcher:chrome_test_util::Omnibox()];
  // Type a single character. This causes two prerender attempts.
  [[EarlGrey selectElementWithMatcher:chrome_test_util::Omnibox()]
      performAction:grey_typeText([pageString substringToIndex:1])];

  // Wait until prerender request reaches the server.
  bool prerendered = WaitUntilConditionOrTimeout(kWaitForPageLoadTimeout, ^{
    return self->_HTTPResponseCounter > 3;
  });
  GREYAssertTrue(prerendered, @"Prerender did not happen");

  // Check the histograms. All prerender attempts must be cancelled. Relying on
  // the histogram here isn't great, but there doesn't seem to be a good
  // way of testing that prerenders have been cancelled.
  GREYAssertNil(
      [MetricsAppInterface expectCount:0
                             forBucket:/*PRERENDER_FINAL_STATUS_USED=*/0
                          forHistogram:@"Prerender.FinalStatus"],
      @"Prerender was used");
  // TODO(crbug.com/1302509): Check that the CANCEL bucket has non-zero
  // elements. Not currently supported by MetricsAppInterface.
}

// Navigate to an HTTP URL and allowlist the URL. Then clear browsing data.
// This should clear the HTTP allowlist.
- (void)testUpgrade_RemoveBrowsingData_ShouldClearAllowlist {
  [HttpsUpgradeAppInterface setHTTPSPortForTesting:self.badHTTPSServer->port()
                                      useFakeHTTPS:false];

  GURL testURL = self.testServer->GetURL("/");
  [ChromeEarlGrey loadURL:testURL];
  [ChromeEarlGrey waitForWebStateContainingText:kInterstitialText];
  [self assertFailedUpgrade:1];

  // Click through the interstitial. This should load the HTTP page. Histogram
  // numbers shouldn't change.
  [ChromeEarlGrey tapWebStateElementWithID:@"proceed-button"];
  [ChromeEarlGrey waitForWebStateContainingText:"HTTP_RESPONSE"];
  [self assertFailedUpgrade:1];

  // Reload. Since the URL is now allowlisted, this should immediately load
  // HTTP without trying to upgrade. Histogram numbers shouldn't change.
  [ChromeEarlGrey reload];
  [ChromeEarlGrey waitForWebStateContainingText:"HTTP_RESPONSE"];
  [self assertFailedUpgrade:1];

  // Clear the allowlist by clearing the browsing data. This clears the history
  // programmatically, so it won't automatically reload the tabs.
  [ChromeEarlGrey clearBrowsingHistory];

  // Reloading the should show the interstitial again.
  [ChromeEarlGrey reload];
  [ChromeEarlGrey waitForWebStateContainingText:kInterstitialText];
  [self assertFailedUpgrade:2];

  // Reload once more.
  [ChromeEarlGrey reload];
  [ChromeEarlGrey waitForWebStateContainingText:kInterstitialText];
  [self assertFailedUpgrade:3];
}

// Click on the "Learn more" link in the interstitial. This should open a
// new tab.
- (void)testUpgrade_LearnMore_ShouldOpenNewTab {
  [HttpsUpgradeAppInterface setHTTPSPortForTesting:self.badHTTPSServer->port()
                                      useFakeHTTPS:false];

  GURL testURL = self.testServer->GetURL("/");
  [ChromeEarlGrey loadURL:testURL];
  [ChromeEarlGrey waitForWebStateContainingText:kInterstitialText];
  [self assertFailedUpgrade:1];

  // Check tab count prior to tapping the link.
  NSUInteger oldRegularTabCount = [ChromeEarlGreyAppInterface mainTabCount];
  NSUInteger oldIncognitoTabCount =
      [ChromeEarlGreyAppInterface incognitoTabCount];

  [ChromeEarlGrey tapWebStateElementWithID:@"learn-more-link"];

  // A new tab should open after tapping the link.
  [ChromeEarlGrey waitForMainTabCount:oldRegularTabCount + 1];
  [ChromeEarlGrey waitForIncognitoTabCount:oldIncognitoTabCount];
}

// Navigate to an HTTP URL directly. The upgraded HTTPS version serves bad SSL.
// The upgrade will fail and the HTTPS-Only mode interstitial will be shown.
// Reloading the page should show the interstitial again.
- (void)testUpgrade_BadHTTPS_ReloadInterstitial {
  [HttpsUpgradeAppInterface setHTTPSPortForTesting:self.badHTTPSServer->port()
                                      useFakeHTTPS:false];

  GURL testURL = self.testServer->GetURL("/");
  [ChromeEarlGrey loadURL:testURL];
  [ChromeEarlGrey waitForWebStateContainingText:kInterstitialText];
  [self assertFailedUpgrade:1];

  [ChromeEarlGrey reload];
  [ChromeEarlGrey waitForWebStateContainingText:kInterstitialText];
  [self assertFailedUpgrade:2];
}

// Navigate to an HTTP URL directly. The upgraded HTTPS version serves slow SSL.
// The upgrade will fail and the HTTPS-Only mode interstitial will be shown.
// Reloading the page should show the interstitial again.
- (void)testUpgrade_SlowHTTPS_ReloadInterstitial {
  [HttpsUpgradeAppInterface setHTTPSPortForTesting:self.slowHTTPSServer->port()
                                      useFakeHTTPS:true];
  // Set the fallback delay to zero. This will immediately stop the HTTPS
  // upgrade attempt.
  [HttpsUpgradeAppInterface setFallbackDelayForTesting:0];

  GURL testURL = self.testServer->GetURL("/");
  [ChromeEarlGrey loadURL:testURL];
  [ChromeEarlGrey waitForWebStateContainingText:kInterstitialText];
  [self assertTimedOutUpgrade:1];

  [ChromeEarlGrey reload];
  [ChromeEarlGrey waitForWebStateContainingText:kInterstitialText];
  [self assertTimedOutUpgrade:2];
}

// Navigate to an HTTP URL directly. The upgraded HTTPS version serves bad SSL.
// The upgrade will fail and the HTTPS-Only mode interstitial will be shown.
// Click through the interstitial, then reload the page. The HTTP page should
// be shown.
- (void)testUpgrade_BadHTTPS_ProceedInterstitial_Allowlisted {
  [HttpsUpgradeAppInterface setHTTPSPortForTesting:self.badHTTPSServer->port()
                                      useFakeHTTPS:false];

  GURL testURL = self.testServer->GetURL("/");
  [ChromeEarlGrey loadURL:testURL];
  [ChromeEarlGrey waitForWebStateContainingText:kInterstitialText];
  [self assertFailedUpgrade:1];

  // Click through the interstitial. This should load the HTTP page.
  [ChromeEarlGrey tapWebStateElementWithID:@"proceed-button"];
  [ChromeEarlGrey waitForWebStateContainingText:"HTTP_RESPONSE"];
  GREYAssert(![HttpsUpgradeAppInterface isHttpsOnlyModeTimerRunning],
             @"Timer is still running");

  // Reload. Since the URL is now allowlisted, this should immediately load
  // HTTP without trying to upgrade.
  [ChromeEarlGrey reload];
  [ChromeEarlGrey waitForWebStateContainingText:"HTTP_RESPONSE"];
  GREYAssertNil([MetricsAppInterface
                    expectTotalCount:2
                        forHistogram:@(security_interstitials::https_only_mode::
                                           kEventHistogram)],
                @"Unexpected histogram event recorded.");
  GREYAssert(![HttpsUpgradeAppInterface isHttpsOnlyModeTimerRunning],
             @"Timer is still running");

  // Open a new tab and go to the same URL. Should load the page without an
  // interstitial.
  [ChromeEarlGrey openNewTab];
  [ChromeEarlGrey loadURL:testURL];
  [ChromeEarlGrey waitForWebStateContainingText:"HTTP_RESPONSE"];
  GREYAssert(![HttpsUpgradeAppInterface isHttpsOnlyModeTimerRunning],
             @"Timer is still running");
  [self assertFailedUpgrade:1];

  // Open an incognito tab and try there. Should show the interstitial as
  // allowlist decisions don't carry over to incognito.
  [ChromeEarlGrey openNewIncognitoTab];
  // Set the testing information for the incognito tab.
  [HttpsUpgradeAppInterface setHTTPSPortForTesting:self.badHTTPSServer->port()
                                      useFakeHTTPS:false];

  [ChromeEarlGrey loadURL:testURL];
  [ChromeEarlGrey waitForWebStateContainingText:kInterstitialText];
  // Click through the interstitial. This should load the HTTP page.
  [ChromeEarlGrey tapWebStateElementWithID:@"proceed-button"];
  [ChromeEarlGrey waitForWebStateContainingText:"HTTP_RESPONSE"];
  GREYAssert(![HttpsUpgradeAppInterface isHttpsOnlyModeTimerRunning],
             @"Timer is still running");

  // Reload. Since the URL is now allowlisted, this should immediately load
  // HTTP without trying to upgrade.
  [ChromeEarlGreyUI reload];
  [ChromeEarlGrey waitForWebStateContainingText:"HTTP_RESPONSE"];
}

// Same as testUpgrade_BadHTTPS_ProceedInterstitial_Allowlisted but uses
// a slow HTTPS response instead:
// Navigate to an HTTP URL directly. The upgraded HTTPS version serves a slow
// loading SSL page. The upgrade will be cancelled and the HTTPS-Only mode
// interstitial will be shown. Click through the interstitial, then reload the
// page. The HTTP page should be shown.
- (void)testUpgrade_SlowHTTPS_ProceedInterstitial_Allowlisted {
  [HttpsUpgradeAppInterface setHTTPSPortForTesting:self.slowHTTPSServer->port()
                                      useFakeHTTPS:true];
  // Set the fallback delay to zero. This will immediately stop the HTTPS
  // upgrade attempt.
  [HttpsUpgradeAppInterface setFallbackDelayForTesting:0];

  GURL testURL = self.testServer->GetURL("/");
  [ChromeEarlGrey loadURL:testURL];
  [ChromeEarlGrey waitForWebStateContainingText:kInterstitialText];
  [self assertTimedOutUpgrade:1];

  // Click through the interstitial. This should load the HTTP page.
  [ChromeEarlGrey tapWebStateElementWithID:@"proceed-button"];
  [ChromeEarlGrey waitForWebStateContainingText:"HTTP_RESPONSE"];
  GREYAssert(![HttpsUpgradeAppInterface isHttpsOnlyModeTimerRunning],
             @"Timer is still running");

  // Reload. Since the URL is now allowlisted, this should immediately load
  // HTTP without trying to upgrade.
  [ChromeEarlGrey reload];
  [ChromeEarlGrey waitForWebStateContainingText:"HTTP_RESPONSE"];
  GREYAssertNil([MetricsAppInterface
                    expectTotalCount:2
                        forHistogram:@(security_interstitials::https_only_mode::
                                           kEventHistogram)],
                @"Unexpected histogram event recorded.");
  GREYAssert(![HttpsUpgradeAppInterface isHttpsOnlyModeTimerRunning],
             @"Timer is still running");
}

// Navigate to an HTTP URL directly. The upgraded HTTPS version serves bad SSL.
// The upgrade will fail and the HTTPS-Only mode interstitial will be shown.
// Tap Go back on the interstitial.
- (void)testUpgrade_BadHTTPS_GoBack {
  [HttpsUpgradeAppInterface setHTTPSPortForTesting:self.badHTTPSServer->port()
                                      useFakeHTTPS:false];

  [ChromeEarlGrey loadURL:GURL("chrome://version")];
  [ChromeEarlGrey waitForWebStateContainingText:"Revision"];

  // Load a site with a bad HTTPS upgrade. This shows an interstitial.
  GURL testURL = self.testServer->GetURL("/");
  [ChromeEarlGrey loadURL:testURL];
  [ChromeEarlGrey waitForWebStateContainingText:kInterstitialText];
  [self assertFailedUpgrade:1];

  // Tap "Go back" on the interstitial. This should go back to chrome://version.
  [ChromeEarlGrey tapWebStateElementWithID:@"primary-button"];
  [ChromeEarlGrey waitForWebStateContainingText:"Revision"];

  // Go forward. Should hit the interstitial again.
  [ChromeEarlGrey goForward];
  [ChromeEarlGrey waitForWebStateContainingText:kInterstitialText];
  [self assertFailedUpgrade:2];
}

// Same as testUpgrade_BadHTTPS_GoBack but uses a slow HTTPS response instead:
// Navigate to an HTTP URL directly. The upgraded HTTPS version serves a slow
// loading HTTPS page. The upgrade will be cancelled and the HTTPS-Only mode
// interstitial will be shown. Tap Go back on the interstitial.
- (void)testUpgrade_SlowHTTPS_GoBack {
  [HttpsUpgradeAppInterface setHTTPSPortForTesting:self.slowHTTPSServer->port()
                                      useFakeHTTPS:true];
  // Set the fallback delay to zero. This will immediately stop the HTTPS
  // upgrade attempt.
  [HttpsUpgradeAppInterface setFallbackDelayForTesting:0];

  [ChromeEarlGrey loadURL:GURL("chrome://version")];
  [ChromeEarlGrey waitForWebStateContainingText:"Revision"];

  // Load a site with a slow HTTPS upgrade. This shows an interstitial.
  GURL testURL = self.testServer->GetURL("/");
  [ChromeEarlGrey loadURL:testURL];
  [ChromeEarlGrey waitForWebStateContainingText:kInterstitialText];
  [self assertTimedOutUpgrade:1];

  // Tap "Go back" on the interstitial. This should go back to
  // chrome://version.
  [ChromeEarlGrey tapWebStateElementWithID:@"primary-button"];
  [ChromeEarlGrey waitForWebStateContainingText:"Revision"];

  // Go forward. Should hit the interstitial again.
  [ChromeEarlGrey goForward];
  [ChromeEarlGrey waitForWebStateContainingText:kInterstitialText];
  [self assertTimedOutUpgrade:2];
}

// Navigate to an HTTP URL and click through the interstitial. Then,
// navigate to a new page and go back. This should load the HTTP URL
// without showing the interstitial again.
- (void)testUpgrade_BadHTTPS_GoBackToAllowlistedSite {
  [HttpsUpgradeAppInterface setHTTPSPortForTesting:self.badHTTPSServer->port()
                                      useFakeHTTPS:false];

  [ChromeEarlGrey loadURL:GURL("about:blank")];

  // Load a site with a bad HTTPS upgrade. This shows an interstitial.
  GURL testURL = self.testServer->GetURL("/");
  [ChromeEarlGrey loadURL:testURL];
  [ChromeEarlGrey waitForWebStateContainingText:kInterstitialText];
  [self assertFailedUpgrade:1];

  // Click through the interstitial. This should load the HTTP page.
  [ChromeEarlGrey tapWebStateElementWithID:@"proceed-button"];
  [ChromeEarlGrey waitForWebStateContainingText:"HTTP_RESPONSE"];

  // Go to a new page.
  [ChromeEarlGrey loadURL:GURL("chrome://version")];
  [ChromeEarlGrey waitForWebStateContainingText:"Revision"];

  // Then go back to the HTTP URL. Since we previously clicked through its
  // interstitial, this should immediately load the HTTP response.
  [ChromeEarlGrey goBack];
  [ChromeEarlGrey waitForWebStateContainingText:"HTTP_RESPONSE"];
  // Histogram numbers shouldn't change.
  [self assertFailedUpgrade:1];
}

// Same as testUpgrade_BadHTTPS_GoBackToAllowlistedSite but uses a slow
// HTTPS response instead:
// Navigate to an HTTP URL with a slow HTTPS upgrade, click through the
// interstitial. Then, navigate to a new page and go back. This should load the
// HTTP URL without showing the interstitial again.
- (void)testUpgrade_SlowHTTPS_GoBackToAllowlistedSite {
  [HttpsUpgradeAppInterface setHTTPSPortForTesting:self.slowHTTPSServer->port()
                                      useFakeHTTPS:true];
  // Set the fallback delay to zero. This will immediately stop the HTTPS
  // upgrade attempt.
  [HttpsUpgradeAppInterface setFallbackDelayForTesting:0];

  [ChromeEarlGrey loadURL:GURL("about:blank")];

  // Load a site with a bad HTTPS upgrade. This shows an interstitial.
  GURL testURL = self.testServer->GetURL("/");
  [ChromeEarlGrey loadURL:testURL];
  [ChromeEarlGrey waitForWebStateContainingText:kInterstitialText];
  [self assertTimedOutUpgrade:1];

  // Click through the interstitial. This should load the HTTP page.
  [ChromeEarlGrey tapWebStateElementWithID:@"proceed-button"];
  [ChromeEarlGrey waitForWebStateContainingText:"HTTP_RESPONSE"];
  GREYAssert(![HttpsUpgradeAppInterface isHttpsOnlyModeTimerRunning],
             @"Timer is still running");

  // Go to a new page.
  [ChromeEarlGrey loadURL:GURL("chrome://version")];
  [ChromeEarlGrey waitForWebStateContainingText:"Revision"];

  // Then go back to the HTTP URL. Since we previously clicked through its
  // interstitial, this should immediately load the HTTP response.
  [ChromeEarlGrey goBack];
  [ChromeEarlGrey waitForWebStateContainingText:"HTTP_RESPONSE"];
  // Histogram numbers shouldn't change.
  [self assertTimedOutUpgrade:1];
}

@end
