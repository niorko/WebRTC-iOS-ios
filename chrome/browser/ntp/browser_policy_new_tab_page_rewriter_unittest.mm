// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "ios/chrome/browser/ntp/browser_policy_new_tab_page_rewriter.h"

#include "base/test/gtest_util.h"
#include "components/sync_preferences/testing_pref_service_syncable.h"
#import "ios/chrome/browser/browser_state/test_chrome_browser_state.h"
#include "ios/chrome/browser/chrome_url_constants.h"
#include "ios/chrome/browser/pref_names.h"
#include "ios/web/public/test/fakes/fake_browser_state.h"
#import "ios/web/public/test/web_task_environment.h"
#include "testing/platform_test.h"
#include "url/gurl.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

class BrowserPolicyNewTabPageRewriterTest : public PlatformTest {
 public:
  void SetUp() override {
    TestChromeBrowserState::Builder builder;
    browser_state_ = builder.Build();
  }

 protected:
  web::WebTaskEnvironment task_environment_;
  std::unique_ptr<TestChromeBrowserState> browser_state_;
};

// Test that chrome://newtab is re-written to the custom NTP Location URL when
// it is set by the policy.
TEST_F(BrowserPolicyNewTabPageRewriterTest, CustomNtpUrl) {
  std::string custom_url = "https://store.google.com";
  browser_state_->GetPrefs()->SetString(prefs::kNewTabPageLocationOverride,
                                        custom_url);
  GURL url = GURL(kChromeUINewTabURL);

  EXPECT_TRUE(
      WillHandleWebBrowserNewTabPageURLForPolicy(&url, browser_state_.get()));
  EXPECT_EQ(url, GURL(custom_url));
}

// Test that chrome://newtab is not re-written if the custom NTP Location URL is
// the same.
TEST_F(BrowserPolicyNewTabPageRewriterTest, SameNtpUrl) {
  std::string custom_url = kChromeUINewTabURL;
  browser_state_->GetPrefs()->SetString(prefs::kNewTabPageLocationOverride,
                                        custom_url);

  GURL url = GURL(kChromeUINewTabURL);

  EXPECT_FALSE(
      WillHandleWebBrowserNewTabPageURLForPolicy(&url, browser_state_.get()));
  EXPECT_EQ(url, GURL(kChromeUINewTabURL));
}

// Test that chrome://newtab is not re-written if the custom NTP Location URL is
// not valid.
TEST_F(BrowserPolicyNewTabPageRewriterTest, InvalidCustomNtpUrl) {
  std::string custom_url = "blabla";
  browser_state_->GetPrefs()->SetString(prefs::kNewTabPageLocationOverride,
                                        custom_url);
  GURL url = GURL(kChromeUINewTabURL);

  EXPECT_FALSE(
      WillHandleWebBrowserNewTabPageURLForPolicy(&url, browser_state_.get()));
  EXPECT_EQ(url, GURL(kChromeUINewTabURL));
}

// Test that chrome://newtab is not re-written when there is no custom NTP
// Location URL.
TEST_F(BrowserPolicyNewTabPageRewriterTest, NoCustomNtpUrl) {
  GURL url = GURL(kChromeUINewTabURL);
  EXPECT_FALSE(
      WillHandleWebBrowserNewTabPageURLForPolicy(&url, browser_state_.get()));
  EXPECT_EQ(url, GURL(kChromeUINewTabURL));
}

// Test that chrome://newtab is not re-written when it is in incognito mode.
TEST_F(BrowserPolicyNewTabPageRewriterTest, IncognitoMode) {
  web::FakeBrowserState fake_browser_state;
  fake_browser_state.SetOffTheRecord(true);
  GURL url = GURL(kChromeUINewTabURL);
  EXPECT_FALSE(
      WillHandleWebBrowserNewTabPageURLForPolicy(&url, &fake_browser_state));
}
