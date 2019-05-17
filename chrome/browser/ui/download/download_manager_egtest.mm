// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <EarlGrey/EarlGrey.h>

#include "base/bind.h"
#import "base/test/ios/wait_util.h"
#include "ios/chrome/browser/chrome_url_constants.h"
#include "ios/chrome/grit/ios_strings.h"
#import "ios/chrome/test/app/chrome_test_util.h"
#import "ios/chrome/test/app/tab_test_util.h"
#include "ios/chrome/test/earl_grey/accessibility_util.h"
#import "ios/chrome/test/earl_grey/chrome_actions.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey_ui.h"
#import "ios/chrome/test/earl_grey/chrome_error_util.h"
#import "ios/chrome/test/earl_grey/chrome_matchers.h"
#import "ios/chrome/test/earl_grey/chrome_test_case.h"
#import "ios/chrome/test/scoped_eg_synchronization_disabler.h"
#include "ios/testing/embedded_test_server_handlers.h"
#import "ios/web/public/test/earl_grey/web_view_matchers.h"
#include "ios/web/public/test/element_selector.h"
#include "net/test/embedded_test_server/http_request.h"
#include "net/test/embedded_test_server/http_response.h"
#include "net/test/embedded_test_server/request_handler_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using chrome_test_util::ButtonWithAccessibilityLabelId;
using chrome_test_util::GetCurrentWebState;
using chrome_test_util::OpenLinkInNewTabButton;
using web::WebViewInWebState;

namespace {

// Matcher for "Download" button on Download Manager UI.
id<GREYMatcher> DownloadButton() {
  return ButtonWithAccessibilityLabelId(IDS_IOS_DOWNLOAD_MANAGER_DOWNLOAD);
}

// Matcher for "Open In..." button on Download Manager UI.
id<GREYMatcher> OpenInButton() {
  return ButtonWithAccessibilityLabelId(IDS_IOS_OPEN_IN);
}

// Provides downloads landing page with download link.
std::unique_ptr<net::test_server::HttpResponse> GetResponse(
    const net::test_server::HttpRequest& request) {
  auto result = std::make_unique<net::test_server::BasicHttpResponse>();
  result->set_code(net::HTTP_OK);
  result->set_content("<a id='download' href='/download?50000'>Download</a>");
  return result;
}

// Waits until Open in... button is shown.
bool WaitForOpenInButton() WARN_UNUSED_RESULT;
bool WaitForOpenInButton() {
  // These downloads usually take longer and need a longer timeout.
  const NSTimeInterval kLongDownloadTimeout = 35;
  return base::test::ios::WaitUntilConditionOrTimeout(kLongDownloadTimeout, ^{
    NSError* error = nil;
    [[EarlGrey selectElementWithMatcher:OpenInButton()]
        assertWithMatcher:grey_notNil()
                    error:&error];
    return (error == nil);
  });
}

// Waits until Download button is shown.
bool WaitForDownloadButton() WARN_UNUSED_RESULT;
bool WaitForDownloadButton() {
  return base::test::ios::WaitUntilConditionOrTimeout(
      base::test::ios::kWaitForPageLoadTimeout, ^{
        NSError* error = nil;
        [[EarlGrey selectElementWithMatcher:DownloadButton()]
            assertWithMatcher:grey_notNil()
                        error:&error];
        return (error == nil);
      });
}

}  // namespace

// Tests critical user journeys for Download Manager.
@interface DownloadManagerTestCase : ChromeTestCase
@end

@implementation DownloadManagerTestCase

- (void)setUp {
  [super setUp];

  self.testServer->RegisterRequestHandler(
      base::BindRepeating(&net::test_server::HandlePrefixedRequest, "/",
                          base::BindRepeating(&GetResponse)));

  self.testServer->RegisterRequestHandler(
      base::BindRepeating(&net::test_server::HandlePrefixedRequest, "/download",
                          base::BindRepeating(&testing::HandleDownload)));

  GREYAssertTrue(self.testServer->Start(), @"Test server failed to start.");
}

// Tests sucessfull download up to the point where "Open in..." button is
// presented. EarlGrey does not allow testing "Open in..." dialog, because it
// is run in a separate process.
- (void)testSucessfullDownload {
  CHROME_EG_ASSERT_NO_ERROR(
      [ChromeEarlGrey loadURL:self.testServer->GetURL("/")]);
  CHROME_EG_ASSERT_NO_ERROR(
      [ChromeEarlGrey waitForWebViewContainingText:"Download"]);
  CHROME_EG_ASSERT_NO_ERROR(
      [ChromeEarlGrey tapWebViewElementWithID:@"download"]);

  GREYAssert(WaitForDownloadButton(), @"Download button did not show up");
  [[EarlGrey selectElementWithMatcher:DownloadButton()]
      performAction:grey_tap()];

  GREYAssert(WaitForOpenInButton(), @"Open in... button did not show up");
}

// Tests sucessfull download up to the point where "Open in..." button is
// presented. EarlGrey does not allow testing "Open in..." dialog, because it
// is run in a separate process. Performs download in Incognito.
- (void)testSucessfullDownloadInIncognito {
  CHROME_EG_ASSERT_NO_ERROR([ChromeEarlGrey openNewIncognitoTab]);
  CHROME_EG_ASSERT_NO_ERROR(
      [ChromeEarlGrey loadURL:self.testServer->GetURL("/")]);
  CHROME_EG_ASSERT_NO_ERROR(
      [ChromeEarlGrey waitForWebViewContainingText:"Download"]);
  CHROME_EG_ASSERT_NO_ERROR(
      [ChromeEarlGrey tapWebViewElementWithID:@"download"]);

  GREYAssert(WaitForDownloadButton(), @"Download button did not show up");
  [[EarlGrey selectElementWithMatcher:DownloadButton()]
      performAction:grey_tap()];

  GREYAssert(WaitForOpenInButton(), @"Open in... button did not show up");
}

// Tests cancelling download UI.
- (void)testCancellingDownload {
  CHROME_EG_ASSERT_NO_ERROR(
      [ChromeEarlGrey loadURL:self.testServer->GetURL("/")]);
  CHROME_EG_ASSERT_NO_ERROR(
      [ChromeEarlGrey waitForWebViewContainingText:"Download"]);
  CHROME_EG_ASSERT_NO_ERROR(
      [ChromeEarlGrey tapWebViewElementWithID:@"download"]);

  GREYAssert(WaitForDownloadButton(), @"Download button did not show up");
  [[EarlGrey selectElementWithMatcher:DownloadButton()]
      assertWithMatcher:grey_notNil()];

  [[EarlGrey selectElementWithMatcher:chrome_test_util::CloseButton()]
      performAction:grey_tap()];

  [[EarlGrey selectElementWithMatcher:DownloadButton()]
      assertWithMatcher:grey_nil()];
}

// Tests sucessfull download up to the point where "Open in..." button is
// presented. EarlGrey does not allow testing "Open in..." dialog, because it
// is run in a separate process. After tapping Download this test opens a
// separate tabs and loads the URL there. Then closes the tab and waits for
// the download completion.
- (void)testDownloadWhileBrowsing {
  CHROME_EG_ASSERT_NO_ERROR(
      [ChromeEarlGrey loadURL:self.testServer->GetURL("/")]);
  CHROME_EG_ASSERT_NO_ERROR(
      [ChromeEarlGrey waitForWebViewContainingText:"Download"]);
  CHROME_EG_ASSERT_NO_ERROR(
      [ChromeEarlGrey tapWebViewElementWithID:@"download"]);

  GREYAssert(WaitForDownloadButton(), @"Download button did not show up");
  [[EarlGrey selectElementWithMatcher:DownloadButton()]
      performAction:grey_tap()];

  {
    // In order to open a new Tab, disable EG synchronization so the framework
    // does not wait until the download progress bar becomes idle (which will
    // not happen until the download is complete).
    ScopedSynchronizationDisabler disabler;
    CHROME_EG_ASSERT_NO_ERROR([ChromeEarlGrey openNewTab]);
  }

  // Load a URL in a separate Tab and close that tab.
  CHROME_EG_ASSERT_NO_ERROR([ChromeEarlGrey loadURL:GURL(kChromeUITermsURL)]);
  const char kTermsText[] = "Google Chrome Terms of Service";
  CHROME_EG_ASSERT_NO_ERROR(
      [ChromeEarlGrey waitForWebViewContainingText:kTermsText]);
  [ChromeEarlGrey closeCurrentTab];
  GREYAssert(WaitForOpenInButton(), @"Open in... button did not show up");
}

// Tests "Open in New Tab" on download link.
- (void)testDownloadInNewTab {
  CHROME_EG_ASSERT_NO_ERROR(
      [ChromeEarlGrey loadURL:self.testServer->GetURL("/")]);
  CHROME_EG_ASSERT_NO_ERROR(
      [ChromeEarlGrey waitForWebViewContainingText:"Download"]);

  // Open context menu for download link.
  [[EarlGrey selectElementWithMatcher:WebViewInWebState(GetCurrentWebState())]
      performAction:chrome_test_util::LongPressElementForContextMenu(
                        [ElementSelector selectorWithElementID:"download"],
                        /*menu_should_appear=*/true)];

  // Tap "Open In New Tab".
  [[EarlGrey selectElementWithMatcher:OpenLinkInNewTabButton()]
      assertWithMatcher:grey_notNil()];
  [[EarlGrey selectElementWithMatcher:OpenLinkInNewTabButton()]
      performAction:grey_tap()];

  // Wait until the new tab is open and switch to that tab.
  CHROME_EG_ASSERT_NO_ERROR([ChromeEarlGrey waitForMainTabCount:2]);
  chrome_test_util::SelectTabAtIndexInCurrentMode(1U);
  GREYAssert(WaitForDownloadButton(), @"Download button did not show up");

  // Proceed with download.
  [[EarlGrey selectElementWithMatcher:DownloadButton()]
      performAction:grey_tap()];
  GREYAssert(WaitForOpenInButton(), @"Open in... button did not show up");
}

// Tests accessibility on Download Manager UI when download is not started.
- (void)testAccessibilityOnNotStartedDownloadToolbar {
  CHROME_EG_ASSERT_NO_ERROR(
      [ChromeEarlGrey loadURL:self.testServer->GetURL("/")]);
  CHROME_EG_ASSERT_NO_ERROR(
      [ChromeEarlGrey waitForWebViewContainingText:"Download"]);
  CHROME_EG_ASSERT_NO_ERROR(
      [ChromeEarlGrey tapWebViewElementWithID:@"download"]);

  GREYAssert(WaitForDownloadButton(), @"Download button did not show up");
  [[EarlGrey selectElementWithMatcher:DownloadButton()]
      assertWithMatcher:grey_notNil()];

  chrome_test_util::VerifyAccessibilityForCurrentScreen();
}

// Tests accessibility on Download Manager UI when download is complete.
- (void)testAccessibilityOnCompletedDownloadToolbar {
  CHROME_EG_ASSERT_NO_ERROR(
      [ChromeEarlGrey loadURL:self.testServer->GetURL("/")]);
  CHROME_EG_ASSERT_NO_ERROR(
      [ChromeEarlGrey waitForWebViewContainingText:"Download"]);
  CHROME_EG_ASSERT_NO_ERROR(
      [ChromeEarlGrey tapWebViewElementWithID:@"download"]);

  GREYAssert(WaitForDownloadButton(), @"Download button did not show up");
  [[EarlGrey selectElementWithMatcher:DownloadButton()]
      performAction:grey_tap()];

  GREYAssert(WaitForOpenInButton(), @"Open in... button did not show up");

  chrome_test_util::VerifyAccessibilityForCurrentScreen();
}

@end
