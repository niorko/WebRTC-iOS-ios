// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <EarlGrey/EarlGrey.h>

#include <string>

#import "base/mac/bind_objc_block.h"
#include "base/strings/sys_string_conversions.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey.h"
#import "ios/chrome/test/earl_grey/chrome_test_case.h"
#include "ios/testing/embedded_test_server_handlers.h"
#include "net/test/embedded_test_server/default_handlers.h"
#include "net/test/embedded_test_server/http_request.h"
#include "net/test/embedded_test_server/http_response.h"
#include "net/test/embedded_test_server/request_handler_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
// Returns ERR_INTERNET_DISCONNECTED error message.
NSString* GetErrorMessage() {
  return base::SysUTF8ToNSString(
      net::ErrorToShortString(net::ERR_INTERNET_DISCONNECTED));
}
}  // namespace

// Tests critical user journeys reloated to page load errors.
@interface ErrorPageTestCase : ChromeTestCase
// YES if test server is replying with valid HTML content (URL query). NO if
// test server closes the socket.
@property(atomic) BOOL serverRespondsWithContent;
@end

@implementation ErrorPageTestCase
@synthesize serverRespondsWithContent = _serverRespondsWithContent;

- (void)setUp {
  [super setUp];

  // Tests handler which replies with URL query for /echo-query path if
  // serverRespondsWithContent set to YES. Otherwise the handler closes the
  // socket.
  using net::test_server::HttpRequest;
  using net::test_server::HttpResponse;
  auto handler = ^std::unique_ptr<HttpResponse>(const HttpRequest& request) {
    if (!self.serverRespondsWithContent) {
      return std::make_unique<net::test_server::RawHttpResponse>(
          /*headers=*/"", /*contents=*/"");
    }
    auto response = std::make_unique<net::test_server::BasicHttpResponse>();
    response->set_content_type("text/html");
    response->set_content(request.GetURL().query());
    return std::move(response);
  };
  self.testServer->RegisterRequestHandler(
      base::BindRepeating(&net::test_server::HandlePrefixedRequest,
                          "/echo-query", base::BindBlockArc(handler)));
  self.testServer->RegisterRequestHandler(
      base::BindRepeating(&net::test_server::HandlePrefixedRequest, "/iframe",
                          base::BindRepeating(&testing::HandleIFrame)));
  RegisterDefaultHandlers(self.testServer);

  GREYAssertTrue(self.testServer->Start(), @"Test server failed to start.");
}

// Loads the URL which fails to load, then sucessfully reloads the page.
- (void)testReloadErrorPage {
  // No response leads to ERR_INTERNET_DISCONNECTED error.
  self.serverRespondsWithContent = NO;
  [ChromeEarlGrey loadURL:self.testServer->GetURL("/echo-query?foo")];
  [ChromeEarlGrey waitForStaticHTMLViewContainingText:GetErrorMessage()];

  // Reload the page, which should load without errors.
  self.serverRespondsWithContent = YES;
  [ChromeEarlGrey reload];
  [ChromeEarlGrey waitForWebViewContainingText:"foo"];
}

// Sucessfully loads the page, stops the server and reloads the page.
- (void)testReloadPageAfterServerIsDown {
  // Sucessfully load the page.
  self.serverRespondsWithContent = YES;
  [ChromeEarlGrey loadURL:self.testServer->GetURL("/echo-query?foo")];
  [ChromeEarlGrey waitForWebViewContainingText:"foo"];

  // Reload the page, no response leads to ERR_INTERNET_DISCONNECTED error.
  self.serverRespondsWithContent = NO;
  [ChromeEarlGrey reload];
  [ChromeEarlGrey waitForStaticHTMLViewContainingText:GetErrorMessage()];
}

// Sucessfully loads the page, goes back, stops the server, goes forward and
// reloads.
- (void)testGoForwardAfterServerIsDownAndReload {
  // First page loads sucessfully.
  [ChromeEarlGrey loadURL:self.testServer->GetURL("/echo")];
  [ChromeEarlGrey waitForWebViewContainingText:"Echo"];

  // Second page loads sucessfully.
  self.serverRespondsWithContent = YES;
  [ChromeEarlGrey loadURL:self.testServer->GetURL("/echo-query?foo")];
  [ChromeEarlGrey waitForWebViewContainingText:"foo"];

  // Go back to the first page.
  [ChromeEarlGrey goBack];
  [ChromeEarlGrey waitForWebViewContainingText:"Echo"];

#if TARGET_IPHONE_SIMULATOR
  // Go forward. The response will be retrieved from the page cache and will not
  // present the error page. Page cache may not always exist on device (which is
  // more memory constrained), so this part of the test is simulator-only.
  self.serverRespondsWithContent = NO;
  [ChromeEarlGrey goForward];
  [ChromeEarlGrey waitForWebViewContainingText:"foo"];

  // Reload bypasses the cache.
  [ChromeEarlGrey reload];
  [ChromeEarlGrey waitForStaticHTMLViewContainingText:GetErrorMessage()];
#endif  // TARGET_IPHONE_SIMULATOR
}

// Sucessfully loads the page, then loads the URL which fails to load, then
// sucessfully goes back to the first page.
- (void)testGoBackFromErrorPage {
  // First page loads sucessfully.
  [ChromeEarlGrey loadURL:self.testServer->GetURL("/echo")];
  [ChromeEarlGrey waitForWebViewContainingText:"Echo"];

  // Second page fails to load.
  [ChromeEarlGrey loadURL:self.testServer->GetURL("/close-socket")];
  [ChromeEarlGrey waitForStaticHTMLViewContainingText:GetErrorMessage()];

  // Going back should sucessfully load the first page.
  [ChromeEarlGrey goBack];
  [ChromeEarlGrey waitForWebViewContainingText:"Echo"];
}

// Loads the URL which redirects to unresponsive server.
- (void)testRedirectToFailingURL {
  // No response leads to ERR_INTERNET_DISCONNECTED error.
  self.serverRespondsWithContent = NO;
  [ChromeEarlGrey
      loadURL:self.testServer->GetURL("/server-redirect?echo-query")];
  [ChromeEarlGrey waitForStaticHTMLViewContainingText:GetErrorMessage()];
}

// Loads the page with iframe, and that iframe fails to load. There should be no
// error page if the main frame has sucessfully loaded.
- (void)testErrorPageInIFrame {
  [ChromeEarlGrey loadURL:self.testServer->GetURL("/iframe?echo-query")];
  [ChromeEarlGrey
      waitForWebViewContainingCSSSelector:"iframe[src*='echo-query']"];
}

@end
