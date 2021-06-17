// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "base/bind.h"
#include "components/strings/grit/components_strings.h"
#include "ios/chrome/browser/web/features.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey.h"
#import "ios/chrome/test/earl_grey/chrome_matchers.h"
#import "ios/chrome/test/earl_grey/chrome_test_case.h"
#import "ios/testing/earl_grey/earl_grey_test.h"
#include "ios/testing/embedded_test_server_handlers.h"
#include "ios/web/common/features.h"
#include "net/test/embedded_test_server/default_handlers.h"
#include "net/test/embedded_test_server/http_request.h"
#include "net/test/embedded_test_server/http_response.h"
#include "net/test/embedded_test_server/request_handler_util.h"
#include "ui/base/l10n/l10n_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@interface SSLTestCase : ChromeTestCase {
  std::unique_ptr<net::test_server::EmbeddedTestServer> _HTTPSServer;
}

@end

@implementation SSLTestCase

- (AppLaunchConfiguration)appConfigurationForTestCase {
  AppLaunchConfiguration config;
  config.relaunch_policy = NoForceRelaunchAndResetState;
  if ([self isRunningTest:@selector(testBadSSLInSessionRestore)]) {
    // TOOD(crbug.com/1221250): Re-enable this test when iOS 15 native session
    // restore is fixed. The issue is likely that -URLNeedsUserAgentType does
    // not allow restoring user agent types for file://error_page_loaded.html.
    if (@available(iOS 15, *)) {
      config.features_disabled.push_back(web::kRestoreSessionFromCache);
    }
  }
  return config;
}

- (void)setUp {
  [super setUp];
  _HTTPSServer = std::make_unique<net::test_server::EmbeddedTestServer>(
      net::test_server::EmbeddedTestServer::TYPE_HTTPS);
  RegisterDefaultHandlers(_HTTPSServer.get());

  GREYAssertTrue(_HTTPSServer->Start(), @"Test server failed to start.");

  const GURL pageURL = _HTTPSServer->GetURL("/echo");
  [ChromeEarlGrey loadURL:pageURL];

  [ChromeEarlGrey waitForWebStateContainingText:l10n_util::GetStringUTF8(
                                                    IDS_SSL_V2_HEADING)];
}

// Tests loading a bad ssl page and tapping "proceed".
- (void)testProceedToBadSSL {
  // Tap on the "Proceed" link and verify that we go to the unsafe page.
  [ChromeEarlGrey tapWebStateElementWithID:@"details-button"];
  [ChromeEarlGrey tapWebStateElementWithID:@"proceed-link"];
  [ChromeEarlGrey waitForWebStateContainingText:"Echo"];
}

// Tests loading a bad ssl page and tapping "Back to safety". The bad ssl page
// is loaded from the NTP to prevent https://crbug.com/1067250 from regressing.
- (void)testBackToSafetyFromBadSSL {
  // Tap on the "Back to safety" link and verify that we go to the NTP.
  [ChromeEarlGrey tapWebStateElementWithID:@"primary-button"];
  [[EarlGrey selectElementWithMatcher:chrome_test_util::FakeOmnibox()]
      assertWithMatcher:grey_sufficientlyVisible()];
}

// Tests loading a BadSSL URL then a good URL then pressing back to navigates
// back to the BadSSL URL is showing the warning.
- (void)testNavigateBackToBadSSL {
  // Load a server without SSL issues.
  GREYAssertTrue(self.testServer->Start(), @"Test server failed to start.");

  const GURL pageURL = self.testServer->GetURL("/echo");
  [ChromeEarlGrey loadURL:pageURL];

  [ChromeEarlGrey waitForWebStateContainingText:"Echo"];

  // Navigate back to the bad SSL page.
  [ChromeEarlGrey goBack];
  [ChromeEarlGrey waitForWebStateContainingText:l10n_util::GetStringUTF8(
                                                    IDS_SSL_V2_HEADING)];
}

// Test loading a page with a bad SSL certificate during session restore, to
// avoid regressing https://crbug.com/1050808.
- (void)testBadSSLInSessionRestore {
  [ChromeEarlGrey triggerRestoreViaTabGridRemoveAllUndo];
  [ChromeEarlGrey waitForWebStateContainingText:l10n_util::GetStringUTF8(
                                                    IDS_SSL_V2_HEADING)];
}

@end
