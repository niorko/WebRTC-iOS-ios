// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/tabs_search/tabs_search_service.h"

#include <memory>
#include <vector>

#include "base/i18n/case_conversion.h"
#include "base/strings/utf_string_conversions.h"
#include "components/sessions/core/tab_restore_service_impl.h"
#include "ios/chrome/browser/browser_state/test_chrome_browser_state.h"
#include "ios/chrome/browser/browser_state/test_chrome_browser_state_manager.h"
#import "ios/chrome/browser/main/browser_list.h"
#import "ios/chrome/browser/main/browser_list_factory.h"
#include "ios/chrome/browser/main/test_browser.h"
#include "ios/chrome/browser/sessions/ios_chrome_tab_restore_service_client.h"
#include "ios/chrome/browser/sessions/ios_chrome_tab_restore_service_factory.h"
#import "ios/chrome/browser/tabs/closing_web_state_observer_browser_agent.h"
#import "ios/chrome/browser/tabs_search/tabs_search_service_factory.h"
#import "ios/chrome/browser/web_state_list/web_state_list.h"
#import "ios/chrome/browser/web_state_list/web_state_opener.h"
#include "ios/chrome/test/ios_chrome_scoped_testing_chrome_browser_state_manager.h"
#import "ios/web/public/test/fakes/fake_navigation_manager.h"
#import "ios/web/public/test/fakes/fake_web_state.h"
#include "ios/web/public/test/web_task_environment.h"
#include "testing/platform_test.h"
#include "url/gurl.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
// A search term which matches all WebStates.
const char16_t kSearchQueryMatchesAll[] = u"State";
// A search term which matches no WebStates.
const char16_t kSearchQueryMatchesNone[] = u"term";

// URL details for a sample WebState.
const char kWebState1Url[] =
    "http://www.url1.com/some/path/to/page?param=value";
const char16_t kWebState1Domain[] = u"url1";
const char16_t kWebState1PartialPath[] = u"path";
const char16_t kWebState1Param[] = u"param";
const char16_t kWebState1ParamValue[] = u"value";
// Title for a sample WebState.
const char16_t kWebState1Title[] = u"Web State 1";

// URL for a second sample WebState.
const char kWebState2Url[] = "http://www.url2.com/";
// Title for a second sample WebState.
const char16_t kWebState2Title[] = u"Web State 2";

std::unique_ptr<KeyedService> BuildTabRestoreService(
    web::BrowserState* context) {
  ChromeBrowserState* browser_state =
      ChromeBrowserState::FromBrowserState(context);
  return std::make_unique<sessions::TabRestoreServiceImpl>(
      base::WrapUnique(new IOSChromeTabRestoreServiceClient(browser_state)),
      browser_state->GetPrefs(), nullptr);
}
}  // namespace

// Test fixture to test the search service.
class TabsSearchServiceTest : public PlatformTest {
 public:
  TabsSearchServiceTest()
      : scoped_browser_state_manager_(
            std::make_unique<TestChromeBrowserStateManager>(base::FilePath())) {
    TestChromeBrowserState::Builder test_browser_state_builder;
    chrome_browser_state_ = test_browser_state_builder.Build();
    IOSChromeTabRestoreServiceFactory::GetInstance()->SetTestingFactoryAndUse(
        chrome_browser_state_.get(),
        base::BindRepeating(&BuildTabRestoreService));

    browser_list_ =
        BrowserListFactory::GetForBrowserState(chrome_browser_state_.get());

    browser_ = std::make_unique<TestBrowser>(chrome_browser_state_.get());
    ClosingWebStateObserverBrowserAgent::CreateForBrowser(browser_.get());

    browser_list_->AddBrowser(browser_.get());

    other_browser_ = std::make_unique<TestBrowser>(chrome_browser_state_.get());
    browser_list_->AddBrowser(other_browser_.get());

    incognito_browser_ = std::make_unique<TestBrowser>(
        chrome_browser_state_->GetOffTheRecordChromeBrowserState());
    browser_list_->AddIncognitoBrowser(incognito_browser_.get());

    other_incognito_browser_ = std::make_unique<TestBrowser>(
        chrome_browser_state_->GetOffTheRecordChromeBrowserState());
    browser_list_->AddIncognitoBrowser(other_incognito_browser_.get());
  }

 protected:
  // Appends a new web state to the web state list of |browser|.
  web::WebState* AppendNewWebState(Browser* browser,
                                   const std::u16string& title,
                                   const GURL& url) {
    auto fake_web_state = std::make_unique<web::FakeWebState>();
    fake_web_state->SetVisibleURL(url);
    fake_web_state->SetTitle(title);

    auto navigation_manager = std::make_unique<web::FakeNavigationManager>();

    navigation_manager->AddItem(url, ui::PAGE_TRANSITION_LINK);
    int item_index = navigation_manager->GetLastCommittedItemIndex();
    navigation_manager->GetItemAtIndex(item_index)->SetTitle(title);

    fake_web_state->SetNavigationManager(std::move(navigation_manager));

    web::FakeWebState* inserted_web_state = fake_web_state.get();
    browser->GetWebStateList()->InsertWebState(
        WebStateList::kInvalidIndex, std::move(fake_web_state),
        WebStateList::INSERT_ACTIVATE, WebStateOpener());
    return inserted_web_state;
  }

  // Returns the associated search service.
  TabsSearchService* search_service() {
    return TabsSearchServiceFactory::GetForBrowserState(
        chrome_browser_state_.get());
  }

  web::WebTaskEnvironment task_environment_;
  IOSChromeScopedTestingChromeBrowserStateManager scoped_browser_state_manager_;
  std::unique_ptr<TestChromeBrowserState> chrome_browser_state_;
  std::unique_ptr<Browser> browser_;
  std::unique_ptr<Browser> other_browser_;
  std::unique_ptr<Browser> incognito_browser_;
  std::unique_ptr<Browser> other_incognito_browser_;
  BrowserList* browser_list_;
};

// Tests that no results are returned when there are no WebStates.
TEST_F(TabsSearchServiceTest, NoWebStates) {
  __block bool results_received = false;
  search_service()->Search(
      kSearchQueryMatchesAll,
      base::BindOnce(^(std::vector<web::WebState*> results) {
        EXPECT_TRUE(results.empty());
        results_received = true;
      }));

  ASSERT_TRUE(results_received);
}

// Tests that no results are returned when the search term doesn't match any
// of the current tabs.
TEST_F(TabsSearchServiceTest, NoMatchingResults) {
  AppendNewWebState(browser_.get(), kWebState1Title, GURL(kWebState1Url));

  __block bool results_received = false;
  search_service()->Search(
      kSearchQueryMatchesNone,
      base::BindOnce(^(std::vector<web::WebState*> results) {
        EXPECT_TRUE(results.empty());
        results_received = true;
      }));

  ASSERT_TRUE(results_received);
}

// Tests that an exact page title matches the correct WebState.
TEST_F(TabsSearchServiceTest, MatchExactTitle) {
  web::WebState* expected_web_state =
      AppendNewWebState(browser_.get(), kWebState1Title, GURL(kWebState1Url));
  AppendNewWebState(browser_.get(), kWebState2Title, GURL(kWebState2Url));

  __block bool results_received = false;
  search_service()->Search(
      kWebState1Title, base::BindOnce(^(std::vector<web::WebState*> results) {
        ASSERT_EQ(1ul, results.size());
        EXPECT_EQ(expected_web_state, results.front());
        results_received = true;
      }));

  ASSERT_TRUE(results_received);
}

// Tests that a partial page title matches the correct WebStates.
TEST_F(TabsSearchServiceTest, MatchPartialTitle) {
  web::WebState* web_state_1 =
      AppendNewWebState(browser_.get(), kWebState1Title, GURL(kWebState1Url));
  web::WebState* web_state_2 =
      AppendNewWebState(browser_.get(), kWebState2Title, GURL(kWebState2Url));

  __block bool results_received = false;
  search_service()->Search(
      kSearchQueryMatchesAll,
      base::BindOnce(^(std::vector<web::WebState*> results) {
        ASSERT_EQ(2ul, results.size());
        EXPECT_EQ(results.front(), web_state_1);
        EXPECT_EQ(results.back(), web_state_2);
        results_received = true;
      }));

  ASSERT_TRUE(results_received);
}

// Tests that WebStates can be matched across multiple Browsers.
TEST_F(TabsSearchServiceTest, MatchAcrossBrowsers) {
  web::WebState* web_state_1 =
      AppendNewWebState(browser_.get(), kWebState1Title, GURL(kWebState1Url));
  web::WebState* web_state_2 = AppendNewWebState(
      other_browser_.get(), kWebState2Title, GURL(kWebState2Url));

  __block bool results_received = false;
  search_service()->Search(
      kSearchQueryMatchesAll,
      base::BindOnce(^(std::vector<web::WebState*> results) {
        ASSERT_EQ(2ul, results.size());
        // The order of results across browsers is unknown, so check both
        // possibilities.
        EXPECT_TRUE(
            (results.front() == web_state_1 && results.back() == web_state_2) ||
            (results.back() == web_state_1 && results.front() == web_state_2));
        results_received = true;
      }));

  ASSERT_TRUE(results_received);
}

// Tests that matches from incognito tabs are not returns from |Search|.
TEST_F(TabsSearchServiceTest, NoIncognitoResults) {
  web::WebState* expected_web_state =
      AppendNewWebState(browser_.get(), kWebState1Title, GURL(kWebState1Url));
  AppendNewWebState(incognito_browser_.get(), kWebState2Title,
                    GURL(kWebState2Url));

  __block bool results_received = false;
  search_service()->Search(
      kSearchQueryMatchesAll,
      base::BindOnce(^(std::vector<web::WebState*> results) {
        ASSERT_EQ(1ul, results.size());
        EXPECT_EQ(expected_web_state, results.front());
        results_received = true;
      }));

  ASSERT_TRUE(results_received);
}

// Tests that only incognito tabs are returned from |SearchIncognito|.
TEST_F(TabsSearchServiceTest, IncognitoResults) {
  AppendNewWebState(browser_.get(), kWebState1Title, GURL(kWebState1Url));
  web::WebState* expected_web_state = AppendNewWebState(
      incognito_browser_.get(), kWebState2Title, GURL(kWebState2Url));

  __block bool results_received = false;
  search_service()->SearchIncognito(
      kSearchQueryMatchesAll,
      base::BindOnce(^(std::vector<web::WebState*> results) {
        ASSERT_EQ(1ul, results.size());
        EXPECT_EQ(expected_web_state, results.front());
        results_received = true;
      }));

  ASSERT_TRUE(results_received);
}

// Tests that a WebState is matched when the entire current URL is used as the
// search term.
TEST_F(TabsSearchServiceTest, MatchExactURL) {
  web::WebState* expected_web_state =
      AppendNewWebState(browser_.get(), kWebState1Title, GURL(kWebState1Url));

  __block bool results_received = false;
  std::string full_url_string(kWebState1Url);
  search_service()->Search(
      base::UTF8ToUTF16(full_url_string),
      base::BindOnce(^(std::vector<web::WebState*> results) {
        ASSERT_EQ(1ul, results.size());
        EXPECT_EQ(expected_web_state, results.front());
        results_received = true;
      }));

  ASSERT_TRUE(results_received);
}

// Tests that a WebState is matched when only the domain of the current URL is
// used as the search term.
TEST_F(TabsSearchServiceTest, MatchURLDomain) {
  web::WebState* expected_web_state =
      AppendNewWebState(browser_.get(), kWebState1Title, GURL(kWebState1Url));

  __block bool results_received = false;
  search_service()->Search(
      kWebState1Domain, base::BindOnce(^(std::vector<web::WebState*> results) {
        ASSERT_EQ(1ul, results.size());
        EXPECT_EQ(expected_web_state, results.front());
        results_received = true;
      }));

  ASSERT_TRUE(results_received);
}

// Tests that a WebState is matched when only a portion of the current URL path
// is used as the search term.
TEST_F(TabsSearchServiceTest, MatchURLPath) {
  web::WebState* expected_web_state =
      AppendNewWebState(browser_.get(), kWebState1Title, GURL(kWebState1Url));

  __block bool results_received = false;
  search_service()->Search(
      kWebState1PartialPath,
      base::BindOnce(^(std::vector<web::WebState*> results) {
        ASSERT_EQ(1ul, results.size());
        EXPECT_EQ(expected_web_state, results.front());
        results_received = true;
      }));

  ASSERT_TRUE(results_received);
}

// Tests that a WebState is matched when only a parameter name of the current
// URL is used as the search term.
TEST_F(TabsSearchServiceTest, MatchURLParam) {
  web::WebState* expected_web_state =
      AppendNewWebState(browser_.get(), kWebState1Title, GURL(kWebState1Url));

  __block bool results_received = false;
  search_service()->Search(
      kWebState1Param, base::BindOnce(^(std::vector<web::WebState*> results) {
        ASSERT_EQ(1ul, results.size());
        EXPECT_EQ(expected_web_state, results.front());
        results_received = true;
      }));

  ASSERT_TRUE(results_received);
}

// Tests that a WebState is matched when only a parameter value of the current
// URL is used as the search term.
TEST_F(TabsSearchServiceTest, MatchURLParamValue) {
  web::WebState* expected_web_state =
      AppendNewWebState(browser_.get(), kWebState1Title, GURL(kWebState1Url));

  __block bool results_received = false;
  search_service()->Search(
      kWebState1ParamValue,
      base::BindOnce(^(std::vector<web::WebState*> results) {
        ASSERT_EQ(1ul, results.size());
        EXPECT_EQ(expected_web_state, results.front());
        results_received = true;
      }));

  ASSERT_TRUE(results_received);
}

// Tests that the title search is case insensitive.
TEST_F(TabsSearchServiceTest, CaseInsensitiveTitleSearch) {
  web::WebState* expected_web_state =
      AppendNewWebState(browser_.get(), kWebState1Title, GURL(kWebState1Url));

  auto uppercase_title = base::i18n::ToUpper(std::u16string(kWebState1Title));

  __block bool results_received = false;
  search_service()->Search(
      uppercase_title, base::BindOnce(^(std::vector<web::WebState*> results) {
        ASSERT_EQ(1ul, results.size());
        EXPECT_EQ(expected_web_state, results.front());
        results_received = true;
      }));

  ASSERT_TRUE(results_received);
}

// Tests that the URL search is case insensitive.
TEST_F(TabsSearchServiceTest, CaseInsensitiveURLSearch) {
  web::WebState* expected_web_state =
      AppendNewWebState(browser_.get(), kWebState1Title, GURL(kWebState1Url));

  auto uppercase_param_value = base::i18n::ToUpper(kWebState1ParamValue);

  __block bool results_received = false;
  search_service()->Search(
      uppercase_param_value,
      base::BindOnce(^(std::vector<web::WebState*> results) {
        ASSERT_EQ(1ul, results.size());
        EXPECT_EQ(expected_web_state, results.front());
        results_received = true;
      }));

  ASSERT_TRUE(results_received);
}

// Tests that no recently closed tabs are returned before any tabs are closed.
TEST_F(TabsSearchServiceTest, RecentlyClosedNoResults) {
  AppendNewWebState(browser_.get(), kWebState1Title, GURL(kWebState1Url));

  __block bool results_received = false;
  search_service()->SearchRecentlyClosed(
      kWebState1Title,
      base::BindOnce(
          ^(std::vector<const sessions::SerializedNavigationEntry> results) {
            ASSERT_EQ(0ul, results.size());
            results_received = true;
          }));

  ASSERT_TRUE(results_received);
}

// Tests that no recently closed tabs are returned when the search term doesn't
// match the recently closed tabs.
TEST_F(TabsSearchServiceTest, RecentlyClosedNoMatch) {
  AppendNewWebState(browser_.get(), kWebState1Title, GURL(kWebState1Url));

  browser_->GetWebStateList()->CloseWebStateAt(/*index=*/0,
                                               WebStateList::CLOSE_NO_FLAGS);

  __block bool results_received = false;
  search_service()->SearchRecentlyClosed(
      kSearchQueryMatchesNone,
      base::BindOnce(
          ^(std::vector<const sessions::SerializedNavigationEntry> results) {
            ASSERT_EQ(0ul, results.size());
            results_received = true;
          }));

  ASSERT_TRUE(results_received);
}

// Tests that a recently closed tab is matched based on a title string match.
TEST_F(TabsSearchServiceTest, RecentlyClosedMatchTitle) {
  AppendNewWebState(browser_.get(), kWebState1Title, GURL(kWebState1Url));
  AppendNewWebState(browser_.get(), kWebState2Title, GURL(kWebState2Url));

  browser_->GetWebStateList()->CloseWebStateAt(/*index=*/0,
                                               WebStateList::CLOSE_NO_FLAGS);

  __block bool results_received = false;
  search_service()->SearchRecentlyClosed(
      kWebState1Title,
      base::BindOnce(
          ^(std::vector<const sessions::SerializedNavigationEntry> results) {
            ASSERT_EQ(1ul, results.size());
            EXPECT_EQ(kWebState1Url, results.front().virtual_url().spec());
            EXPECT_EQ(kWebState1Title, results.front().title());
            results_received = true;
          }));

  ASSERT_TRUE(results_received);
}

// Tests that a recently closed tab is matched based on a url match.
TEST_F(TabsSearchServiceTest, RecentlyClosedMatchURL) {
  AppendNewWebState(browser_.get(), kWebState1Title, GURL(kWebState1Url));
  AppendNewWebState(browser_.get(), kWebState2Title, GURL(kWebState2Url));

  browser_->GetWebStateList()->CloseWebStateAt(/*index=*/0,
                                               WebStateList::CLOSE_NO_FLAGS);

  __block bool results_received = false;
  search_service()->SearchRecentlyClosed(
      kWebState1ParamValue,
      base::BindOnce(
          ^(std::vector<const sessions::SerializedNavigationEntry> results) {
            ASSERT_EQ(1ul, results.size());
            EXPECT_EQ(kWebState1Url, results.front().virtual_url().spec());
            EXPECT_EQ(kWebState1Title, results.front().title());

            results_received = true;
          }));

  ASSERT_TRUE(results_received);
}

// Tests that a recently closed tab is matched based on a title string match.
TEST_F(TabsSearchServiceTest, RecentlyClosedMatchTitleAllClosed) {
  AppendNewWebState(browser_.get(), kWebState1Title, GURL(kWebState1Url));
  AppendNewWebState(browser_.get(), kWebState2Title, GURL(kWebState2Url));
  // Add a webstate which will not match |kSearchQueryMatchesAll|.
  AppendNewWebState(browser_.get(), u"X", GURL("http://abc.xyz"));

  browser_->GetWebStateList()->CloseAllWebStates(WebStateList::CLOSE_NO_FLAGS);

  __block bool results_received = false;
  search_service()->SearchRecentlyClosed(
      kSearchQueryMatchesAll,
      base::BindOnce(
          ^(std::vector<const sessions::SerializedNavigationEntry> results) {
            ASSERT_EQ(2ul, results.size());
            EXPECT_EQ(kWebState1Url, results.front().virtual_url().spec());
            EXPECT_EQ(kWebState1Title, results.front().title());
            EXPECT_EQ(kWebState2Url, results.back().virtual_url().spec());
            EXPECT_EQ(kWebState2Title, results.back().title());
            results_received = true;
          }));

  ASSERT_TRUE(results_received);
}
