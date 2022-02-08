// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "base/test/ios/wait_util.h"
#import "components/shared_highlighting/core/common/shared_highlighting_features.h"
#import "components/shared_highlighting/ios/shared_highlighting_constants.h"
#import "ios/chrome/grit/ios_strings.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey.h"
#import "ios/chrome/test/earl_grey/chrome_matchers.h"
#import "ios/chrome/test/earl_grey/chrome_test_case.h"
#import "ios/testing/earl_grey/earl_grey_test.h"
#import "ios/web/public/test/element_selector.h"
#import "net/test/embedded_test_server/default_handlers.h"
#import "net/test/embedded_test_server/http_request.h"
#import "net/test/embedded_test_server/http_response.h"
#import "net/test/embedded_test_server/request_handler_util.h"
#import "ui/base/l10n/l10n_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

const char kTestURL[] = "/testPage";
const char kURLWithFragment[] = "/testPage/#:~:text=lorem%20ipsum";
const char kHTMLOfTestPage[] =
    "<html><body><p>"
    "<span id='target'>Lorem ipsum</span> dolor sit amet, consectetur "
    "adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore "
    "magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco "
    "laboris nisi ut aliquip ex ea commodo consequat."
    "</p></body></html>";
const char kTestPageTextSample[] = "Lorem ipsum";

std::unique_ptr<net::test_server::HttpResponse> LoadHtml(
    const std::string& html,
    const net::test_server::HttpRequest& request) {
  std::unique_ptr<net::test_server::BasicHttpResponse> http_response(
      new net::test_server::BasicHttpResponse);
  http_response->set_content_type("text/html");
  http_response->set_content(html);
  return std::move(http_response);
}

auto GetMenuTitleMatcher() {
  return grey_text(l10n_util::GetNSString(IDS_IOS_SHARED_HIGHLIGHT_MENU_TITLE));
}

void ClickMarkAndWaitForMenu() {
  ElementSelector* selector = [ElementSelector selectorWithCSSSelector:"mark"];
  [ChromeEarlGrey waitForWebStateContainingElement:selector];
  [ChromeEarlGrey
      evaluateJavaScriptForSideEffect:
          @"document.getElementById('target').children[0].click();"];
  [ChromeEarlGrey
      waitForSufficientlyVisibleElementWithMatcher:GetMenuTitleMatcher()];
}

void DismissMenu() {
  if ([ChromeEarlGrey isIPadIdiom]) {
    // Tap the tools menu to dismiss the popover.
    [[EarlGrey selectElementWithMatcher:chrome_test_util::ToolsMenuButton()]
        performAction:grey_tap()];
  } else {
    [[EarlGrey selectElementWithMatcher:chrome_test_util::CancelButton()]
        performAction:grey_tap()];
  }
}

}  // namespace

// Test class verifying behavior of interactions with text fragments in web
// pages.
@interface TextFragmentsTestCase : ChromeTestCase
@end

@implementation TextFragmentsTestCase

- (AppLaunchConfiguration)appConfigurationForTestCase {
  AppLaunchConfiguration config;
  config.features_enabled.push_back(
      shared_highlighting::kIOSSharedHighlightingV2);
  return config;
}

- (void)setUp {
  [super setUp];

  RegisterDefaultHandlers(self.testServer);
  self.testServer->RegisterRequestHandler(
      base::BindRepeating(&net::test_server::HandlePrefixedRequest, kTestURL,
                          base::BindRepeating(&LoadHtml, kHTMLOfTestPage)));

  GREYAssertTrue(self.testServer->Start(), @"Test server failed to start.");
}

- (void)testOpenMenu {
  [ChromeEarlGrey loadURL:self.testServer->GetURL(kURLWithFragment)];
  [ChromeEarlGrey waitForWebStateContainingText:kTestPageTextSample];

  ClickMarkAndWaitForMenu();
}

- (void)testRemove {
  [ChromeEarlGrey loadURL:self.testServer->GetURL(kURLWithFragment)];
  [ChromeEarlGrey waitForWebStateContainingText:kTestPageTextSample];

  ClickMarkAndWaitForMenu();

  [[EarlGrey selectElementWithMatcher:grey_text(l10n_util::GetNSString(
                                          IDS_IOS_SHARED_HIGHLIGHT_REMOVE))]
      performAction:grey_tap()];

  // Verify that the mark is gone
  ElementSelector* selector = [ElementSelector selectorWithCSSSelector:"mark"];
  [ChromeEarlGrey waitForWebStateNotContainingElement:selector];
}

- (void)testCancel {
  [ChromeEarlGrey loadURL:self.testServer->GetURL(kURLWithFragment)];
  [ChromeEarlGrey waitForWebStateContainingText:kTestPageTextSample];

  ClickMarkAndWaitForMenu();

  DismissMenu();

  [ChromeEarlGrey waitForUIElementToDisappearWithMatcher:GetMenuTitleMatcher()];

  // Verify that the mark is still present
  ElementSelector* selector = [ElementSelector selectorWithCSSSelector:"mark"];
  [ChromeEarlGrey waitForWebStateContainingElement:selector];
}

- (void)testLearnMore {
  [ChromeEarlGrey loadURL:self.testServer->GetURL(kURLWithFragment)];
  [ChromeEarlGrey waitForWebStateContainingText:kTestPageTextSample];

  ClickMarkAndWaitForMenu();
  [[EarlGrey selectElementWithMatcher:grey_text(l10n_util::GetNSString(
                                          IDS_IOS_SHARED_HIGHLIGHT_LEARN_MORE))]
      performAction:grey_tap()];

  [ChromeEarlGrey waitForMainTabCount:2];

  // Compare only the host; the path could change upon opening.
  GREYAssertEqual([ChromeEarlGrey webStateLastCommittedURL].host(),
                  GURL(shared_highlighting::kLearnMoreUrl).host(),
                  @"Did not open correct Learn More URL.");
}

- (void)testReshare {
  // Clear the pasteboard
  UIPasteboard* pasteboard = UIPasteboard.generalPasteboard;
  [pasteboard setValue:@"" forPasteboardType:UIPasteboardNameGeneral];

  GURL pageURL = self.testServer->GetURL(kURLWithFragment);
  [ChromeEarlGrey loadURL:pageURL];
  [ChromeEarlGrey waitForWebStateContainingText:kTestPageTextSample];
  ClickMarkAndWaitForMenu();
  [[EarlGrey selectElementWithMatcher:grey_text(l10n_util::GetNSString(
                                          IDS_IOS_SHARED_HIGHLIGHT_RESHARE))]
      performAction:grey_tap()];

  // Wait for the Activity View to show up (look for the Copy action).
  id<GREYMatcher> copyActivityButton = chrome_test_util::CopyActivityButton();
  [ChromeEarlGrey
      waitForSufficientlyVisibleElementWithMatcher:copyActivityButton];

  // Tap on the Copy action.
  [[EarlGrey selectElementWithMatcher:copyActivityButton]
      performAction:grey_tap()];

  // Wait for the value to be in the pasteboard.
  GREYCondition* getPastedURL = [GREYCondition
      conditionWithName:@"Could not get expected URL from the pasteboard."
                  block:^{
                    return pageURL == [ChromeEarlGrey pasteboardURL];
                  }];
  GREYAssert(
      [getPastedURL waitWithTimeout:base::test::ios::kWaitForActionTimeout],
      @"Could not get expected URL from pasteboard.");
}

@end
