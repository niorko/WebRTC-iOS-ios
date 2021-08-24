// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/settings/clear_browsing_data/clear_browsing_data_manager.h"

#include "base/bind.h"
#include "base/mac/foundation_util.h"
#include "base/test/scoped_feature_list.h"
#include "components/browsing_data/core/pref_names.h"
#include "components/pref_registry/pref_registry_syncable.h"
#include "components/search_engines/template_url_data_util.h"
#include "components/search_engines/template_url_prepopulate_data.h"
#include "components/search_engines/template_url_service.h"
#include "components/sync/driver/test_sync_service.h"
#include "components/sync_preferences/pref_service_mock_factory.h"
#include "components/sync_preferences/pref_service_syncable.h"
#include "ios/chrome/browser/application_context.h"
#include "ios/chrome/browser/browser_state/test_chrome_browser_state.h"
#include "ios/chrome/browser/browsing_data/browsing_data_features.h"
#include "ios/chrome/browser/browsing_data/cache_counter.h"
#include "ios/chrome/browser/browsing_data/fake_browsing_data_remover.h"
#include "ios/chrome/browser/pref_names.h"
#include "ios/chrome/browser/prefs/browser_prefs.h"
#include "ios/chrome/browser/search_engines/template_url_service_factory.h"
#include "ios/chrome/browser/signin/authentication_service.h"
#include "ios/chrome/browser/signin/authentication_service_delegate_fake.h"
#include "ios/chrome/browser/signin/authentication_service_factory.h"
#import "ios/chrome/browser/signin/chrome_account_manager_service.h"
#import "ios/chrome/browser/signin/chrome_account_manager_service_factory.h"
#include "ios/chrome/browser/sync/sync_service_factory.h"
#include "ios/chrome/browser/sync/sync_setup_service_factory.h"
#include "ios/chrome/browser/sync/sync_setup_service_mock.h"
#import "ios/chrome/browser/ui/settings/clear_browsing_data/fake_browsing_data_counter_wrapper_producer.h"
#import "ios/chrome/browser/ui/table_view/cells/table_view_detail_icon_item.h"
#import "ios/chrome/browser/ui/table_view/cells/table_view_link_header_footer_item.h"
#import "ios/chrome/browser/ui/table_view/table_view_model.h"
#include "ios/chrome/browser/ui/ui_feature_flags.h"
#include "ios/chrome/grit/ios_strings.h"
#include "ios/chrome/test/ios_chrome_scoped_testing_local_state.h"
#include "ios/public/provider/chrome/browser/signin/fake_chrome_identity_service.h"
#include "ios/web/public/test/web_task_environment.h"
#include "testing/gtest/include/gtest/gtest.h"
#import "testing/gtest_mac.h"
#include "testing/platform_test.h"
#include "ui/base/l10n/l10n_util_mac.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using TemplateURLPrepopulateData::GetAllPrepopulatedEngines;
using TemplateURLPrepopulateData::PrepopulatedEngine;

namespace {

std::unique_ptr<KeyedService> CreateTestSyncService(
    web::BrowserState* context) {
  return std::make_unique<syncer::TestSyncService>();
}

class ClearBrowsingDataManagerTest : public PlatformTest {
 public:
  ClearBrowsingDataManagerTest() {
    sync_preferences::PrefServiceMockFactory factory;
    scoped_refptr<user_prefs::PrefRegistrySyncable> registry(
        new user_prefs::PrefRegistrySyncable);
    std::unique_ptr<sync_preferences::PrefServiceSyncable> prefs =
        factory.CreateSyncable(registry.get());
    RegisterBrowserStatePrefs(registry.get());

    TestChromeBrowserState::Builder builder;
    builder.AddTestingFactory(SyncServiceFactory::GetInstance(),
                              base::BindRepeating(&CreateTestSyncService));
    builder.AddTestingFactory(
        SyncSetupServiceFactory::GetInstance(),
        base::BindRepeating(&SyncSetupServiceMock::CreateKeyedService));
    builder.AddTestingFactory(
        AuthenticationServiceFactory::GetInstance(),
        AuthenticationServiceFactory::GetDefaultFactory());
    builder.AddTestingFactory(
        ios::TemplateURLServiceFactory::GetInstance(),
        ios::TemplateURLServiceFactory::GetDefaultFactory());
    browser_state_ = builder.Build();

    AuthenticationServiceFactory::CreateAndInitializeForBrowserState(
        browser_state_.get(),
        std::make_unique<AuthenticationServiceDelegateFake>());
    account_manager_service_ =
        ChromeAccountManagerServiceFactory::GetForBrowserState(
            browser_state_.get());

    // Load TemplateURLService.
    template_url_service_ = ios::TemplateURLServiceFactory::GetForBrowserState(
        browser_state_.get());
    template_url_service_->Load();

    ios::FakeChromeIdentityService::GetInstanceFromChromeProvider()
        ->AddIdentities(@[ @"foo" ]);

    model_ = [[TableViewModel alloc] init];
    remover_ = std::make_unique<FakeBrowsingDataRemover>();
    manager_ = [[ClearBrowsingDataManager alloc]
                      initWithBrowserState:browser_state_.get()
                       browsingDataRemover:remover_.get()
        browsingDataCounterWrapperProducer:
            [[FakeBrowsingDataCounterWrapperProducer alloc] init]];

    test_sync_service_ = static_cast<syncer::TestSyncService*>(
        SyncServiceFactory::GetForBrowserState(browser_state_.get()));

    time_range_pref_.Init(browsing_data::prefs::kDeleteTimePeriod,
                          browser_state_->GetPrefs());
  }

  ChromeIdentity* fake_identity() {
    return account_manager_service_->GetDefaultIdentity();
  }

  // Adds a prepopulated search engine to TemplateURLService.
  // |prepopulate_id| should be big enough (>1000) to avoid collision with real
  // prepopulated search engines. The collision happens when
  // TemplateURLService::SetUserSelectedDefaultSearchProvider is called, in the
  // callback of PrefService the DefaultSearchManager will update the searchable
  // URL of default search engine from prepopulated search engines list.
  TemplateURL* AddPriorSearchEngine(const std::string& short_name,
                                    const GURL& searchable_url,
                                    int prepopulate_id,
                                    bool set_default) {
    DCHECK_GT(prepopulate_id, 1000);
    TemplateURLData data;
    data.SetShortName(base::ASCIIToUTF16(short_name));
    data.SetKeyword(base::ASCIIToUTF16(short_name));
    data.SetURL(searchable_url.possibly_invalid_spec());
    data.favicon_url = TemplateURL::GenerateFaviconURL(searchable_url);
    data.prepopulate_id = prepopulate_id;
    TemplateURL* url =
        template_url_service_->Add(std::make_unique<TemplateURL>(data));
    if (set_default)
      template_url_service_->SetUserSelectedDefaultSearchProvider(url);
    return url;
  }

  // Adds a custom search engine to TemplateURLService.
  TemplateURL* AddCustomSearchEngine(const std::string& short_name,
                                     const GURL& searchable_url,
                                     base::Time last_visited_time,
                                     bool set_default) {
    TemplateURLData data;
    data.SetShortName(base::ASCIIToUTF16(short_name));
    data.SetKeyword(base::ASCIIToUTF16(short_name));
    data.SetURL(searchable_url.possibly_invalid_spec());
    data.favicon_url = TemplateURL::GenerateFaviconURL(searchable_url);
    data.last_visited = last_visited_time;
    TemplateURL* url =
        template_url_service_->Add(std::make_unique<TemplateURL>(data));
    if (set_default)
      template_url_service_->SetUserSelectedDefaultSearchProvider(url);
    return url;
  }

 protected:
  web::WebTaskEnvironment task_environment_;
  IOSChromeScopedTestingLocalState local_state_;
  std::unique_ptr<TestChromeBrowserState> browser_state_;
  TableViewModel* model_;
  std::unique_ptr<BrowsingDataRemover> remover_;
  ClearBrowsingDataManager* manager_;
  syncer::TestSyncService* test_sync_service_;
  IntegerPrefMember time_range_pref_;
  TemplateURLService* template_url_service_;  // weak
  ChromeAccountManagerService* account_manager_service_;
};

// Tests model is set up with all appropriate items and sections.
TEST_F(ClearBrowsingDataManagerTest, TestModel) {
  base::test::ScopedFeatureList scoped_feature_list;
  scoped_feature_list.InitAndDisableFeature(kSearchHistoryLinkIOS);

  [manager_ loadModel:model_];

  EXPECT_EQ(3, [model_ numberOfSections]);
  EXPECT_EQ(1, [model_ numberOfItemsInSection:0]);
  EXPECT_EQ(5, [model_ numberOfItemsInSection:1]);
  EXPECT_EQ(0, [model_ numberOfItemsInSection:2]);
}

// Tests model is set up with correct number of items and sections if signed in
// but sync is off.
TEST_F(ClearBrowsingDataManagerTest, TestModelSignedInSyncOff) {
  base::test::ScopedFeatureList scoped_feature_list;
  scoped_feature_list.InitAndDisableFeature(kSearchHistoryLinkIOS);

  // Ensure that sync is not running.
  test_sync_service_->SetDisableReasons(
      syncer::SyncService::DISABLE_REASON_USER_CHOICE);

  AuthenticationServiceFactory::GetForBrowserState(browser_state_.get())
      ->SignIn(fake_identity());

  [manager_ loadModel:model_];

  EXPECT_EQ(3, [model_ numberOfSections]);
  EXPECT_EQ(1, [model_ numberOfItemsInSection:0]);
  EXPECT_EQ(5, [model_ numberOfItemsInSection:1]);
  EXPECT_EQ(0, [model_ numberOfItemsInSection:2]);
}

TEST_F(ClearBrowsingDataManagerTest, TestCacheCounterFormattingForAllTime) {
  base::test::ScopedFeatureList scoped_feature_list;
  scoped_feature_list.InitAndDisableFeature(kSearchHistoryLinkIOS);

  ASSERT_EQ("en", GetApplicationContext()->GetApplicationLocale());
  PrefService* prefs = browser_state_->GetPrefs();
  prefs->SetInteger(browsing_data::prefs::kDeleteTimePeriod,
                    static_cast<int>(browsing_data::TimePeriod::ALL_TIME));
  CacheCounter counter(browser_state_.get());

  // Test multiple possible types of formatting.
  // clang-format off
    const struct TestCase {
        int cache_size;
        NSString* expected_output;
    } kTestCases[] = {
        {0, @"Less than 1 MB"},
        {(1 << 20) - 1, @"Less than 1 MB"},
        {(1 << 20), @"1 MB"},
        {(1 << 20) + (1 << 19), @"1.5 MB"},
        {(1 << 21), @"2 MB"},
        {(1 << 30), @"1 GB"}
    };
  // clang-format on

  for (const TestCase& test_case : kTestCases) {
    browsing_data::BrowsingDataCounter::FinishedResult result(
        &counter, test_case.cache_size);
    NSString* output = [manager_ counterTextFromResult:result];
    EXPECT_NSEQ(test_case.expected_output, output);
  }
}

TEST_F(ClearBrowsingDataManagerTest,
       TestCacheCounterFormattingForLessThanAllTime) {
  base::test::ScopedFeatureList scoped_feature_list;
  scoped_feature_list.InitAndDisableFeature(kSearchHistoryLinkIOS);

  ASSERT_EQ("en", GetApplicationContext()->GetApplicationLocale());

  PrefService* prefs = browser_state_->GetPrefs();
  prefs->SetInteger(browsing_data::prefs::kDeleteTimePeriod,
                    static_cast<int>(browsing_data::TimePeriod::LAST_HOUR));
  CacheCounter counter(browser_state_.get());

  // Test multiple possible types of formatting.
  // clang-format off
    const struct TestCase {
        int cache_size;
        NSString* expected_output;
    } kTestCases[] = {
        {0, @"Less than 1 MB"},
        {(1 << 20) - 1, @"Less than 1 MB"},
        {(1 << 20), @"Less than 1 MB"},
        {(1 << 20) + (1 << 19), @"Less than 1.5 MB"},
        {(1 << 21), @"Less than 2 MB"},
        {(1 << 30), @"Less than 1 GB"}
    };
  // clang-format on

  for (const TestCase& test_case : kTestCases) {
    browsing_data::BrowsingDataCounter::FinishedResult result(
        &counter, test_case.cache_size);
    NSString* output = [manager_ counterTextFromResult:result];
    EXPECT_NSEQ(test_case.expected_output, output);
  }
}

TEST_F(ClearBrowsingDataManagerTest, TestOnPreferenceChanged) {
  base::test::ScopedFeatureList scoped_feature_list;
  scoped_feature_list.InitAndDisableFeature(kSearchHistoryLinkIOS);

  [manager_ loadModel:model_];
  NSArray* timeRangeItems =
      [model_ itemsInSectionWithIdentifier:SectionIdentifierTimeRange];
  ASSERT_EQ(1UL, timeRangeItems.count);
  TableViewDetailIconItem* timeRangeItem = timeRangeItems.firstObject;
  ASSERT_TRUE([timeRangeItem isKindOfClass:[TableViewDetailIconItem class]]);

  // Changes of Time Range should trigger updates on Time Range item's
  // detailText.
  time_range_pref_.SetValue(2);
  EXPECT_NSEQ(l10n_util::GetNSString(
                  IDS_IOS_CLEAR_BROWSING_DATA_TIME_RANGE_OPTION_PAST_WEEK),
              timeRangeItem.detailText);
  time_range_pref_.SetValue(3);
  EXPECT_NSEQ(
      l10n_util::GetNSString(
          IDS_IOS_CLEAR_BROWSING_DATA_TIME_RANGE_OPTION_LAST_FOUR_WEEKS),
      timeRangeItem.detailText);
}

TEST_F(ClearBrowsingDataManagerTest, TestGoogleDSETextSignedIn) {
  base::test::ScopedFeatureList scoped_feature_list;
  scoped_feature_list.InitAndEnableFeature(kSearchHistoryLinkIOS);

  AuthenticationServiceFactory::GetForBrowserState(browser_state_.get())
      ->SignIn(fake_identity());

  [manager_ loadModel:model_];

  ASSERT_TRUE(
      [model_ hasSectionForSectionIdentifier:SectionIdentifierGoogleAccount]);
  ASSERT_FALSE(
      ![model_ footerForSectionWithIdentifier:SectionIdentifierGoogleAccount]);
  ListItem* googleAccount =
      [model_ footerForSectionWithIdentifier:SectionIdentifierGoogleAccount];
  TableViewLinkHeaderFooterItem* accountFooterTextItem =
      base::mac::ObjCCastStrict<TableViewLinkHeaderFooterItem>(googleAccount);
  ASSERT_TRUE(([accountFooterTextItem.text rangeOfString:@"Google"].location !=
               NSNotFound));
  ASSERT_EQ(2u, accountFooterTextItem.urls.size());
}

TEST_F(ClearBrowsingDataManagerTest, TestGoogleDSETextSignedOut) {
  base::test::ScopedFeatureList scoped_feature_list;
  scoped_feature_list.InitAndEnableFeature(kSearchHistoryLinkIOS);

  AuthenticationServiceFactory::GetForBrowserState(browser_state_.get())
      ->SignOut(signin_metrics::ABORT_SIGNIN,
                /*force_clear_browsing_data=*/false, nil);

  [manager_ loadModel:model_];

  ASSERT_FALSE(
      [model_ hasSectionForSectionIdentifier:SectionIdentifierGoogleAccount]);
}

TEST_F(ClearBrowsingDataManagerTest, TestPrepopulatedTextSignedIn) {
  base::test::ScopedFeatureList scoped_feature_list;
  scoped_feature_list.InitAndEnableFeature(kSearchHistoryLinkIOS);

  AuthenticationServiceFactory::GetForBrowserState(browser_state_.get())
      ->SignIn(fake_identity());

  // Set DSE to one from "prepoulated list".
  const std::string kEngineP1Name = "prepopulated-1";
  const GURL kEngineP1Url = GURL("https://p1.com?q={searchTerms}");

  AddPriorSearchEngine(/* short_name */ kEngineP1Name,
                       /* searchable_url */ kEngineP1Url,
                       /* prepopulated_id */ 1001, /* set_default */ true);

  [manager_ loadModel:model_];

  ASSERT_TRUE(
      [model_ hasSectionForSectionIdentifier:SectionIdentifierGoogleAccount]);
  ASSERT_FALSE(
      ![model_ footerForSectionWithIdentifier:SectionIdentifierGoogleAccount]);
  ListItem* googleAccount =
      [model_ footerForSectionWithIdentifier:SectionIdentifierGoogleAccount];
  TableViewLinkHeaderFooterItem* accountFooterTextItem =
      base::mac::ObjCCastStrict<TableViewLinkHeaderFooterItem>(googleAccount);
  ASSERT_TRUE(
      ([accountFooterTextItem.text
           rangeOfString:[NSString
                             stringWithCString:kEngineP1Name.c_str()
                                      encoding:[NSString
                                                   defaultCStringEncoding]]]
           .location != NSNotFound));
  ASSERT_EQ(1u, accountFooterTextItem.urls.size());
}

TEST_F(ClearBrowsingDataManagerTest, TestPrepopulatedTextSignedOut) {
  base::test::ScopedFeatureList scoped_feature_list;
  scoped_feature_list.InitAndEnableFeature(kSearchHistoryLinkIOS);

  AuthenticationServiceFactory::GetForBrowserState(browser_state_.get())
      ->SignOut(signin_metrics::ABORT_SIGNIN,
                /*force_clear_browsing_data=*/false, nil);

  // Set DSE to one from "prepoulated list".
  const std::string kEngineP1Name = "prepopulated-1";
  // NSString kEngineP1NameNS = kEngineP1Name as NS
  const GURL kEngineP1Url = GURL("https://p1.com?q={searchTerms}");

  AddPriorSearchEngine(/* short_name */ kEngineP1Name,
                       /* searchable_url */ kEngineP1Url,
                       /* prepopulated_id */ 1001, /* set_default */ true);

  [manager_ loadModel:model_];

  ASSERT_TRUE(
      [model_ hasSectionForSectionIdentifier:SectionIdentifierGoogleAccount]);
  ASSERT_FALSE(
      ![model_ footerForSectionWithIdentifier:SectionIdentifierGoogleAccount]);
  ListItem* googleAccount =
      [model_ footerForSectionWithIdentifier:SectionIdentifierGoogleAccount];
  TableViewLinkHeaderFooterItem* accountFooterTextItem =
      base::mac::ObjCCastStrict<TableViewLinkHeaderFooterItem>(googleAccount);
  ASSERT_TRUE(
      ([accountFooterTextItem.text
           rangeOfString:[NSString
                             stringWithCString:kEngineP1Name.c_str()
                                      encoding:[NSString
                                                   defaultCStringEncoding]]]
           .location != NSNotFound));
  ASSERT_EQ(0u, accountFooterTextItem.urls.size());
}

TEST_F(ClearBrowsingDataManagerTest, TestCustomTextSignedIn) {
  base::test::ScopedFeatureList scoped_feature_list;
  scoped_feature_list.InitAndEnableFeature(kSearchHistoryLinkIOS);

  AuthenticationServiceFactory::GetForBrowserState(browser_state_.get())
      ->SignIn(fake_identity());

  // Set DSE to a be fully custom.
  const std::string kEngineC1Name = "custom-1";
  const GURL kEngineC1Url = GURL("https://c1.com?q={searchTerms}");

  AddCustomSearchEngine(/* short_name */ kEngineC1Name,
                        /* searchable_url */ kEngineC1Url,
                        /* last_visited_time */ base::Time::Now() -
                            base::TimeDelta::FromSeconds(10),
                        /* set_default */ true);

  [manager_ loadModel:model_];

  ASSERT_TRUE(
      [model_ hasSectionForSectionIdentifier:SectionIdentifierGoogleAccount]);
  ASSERT_FALSE(
      ![model_ footerForSectionWithIdentifier:SectionIdentifierGoogleAccount]);
  ListItem* googleAccount =
      [model_ footerForSectionWithIdentifier:SectionIdentifierGoogleAccount];
  TableViewLinkHeaderFooterItem* accountFooterTextItem =
      base::mac::ObjCCastStrict<TableViewLinkHeaderFooterItem>(googleAccount);
  ASSERT_FALSE(
      ([accountFooterTextItem.text
           rangeOfString:[NSString
                             stringWithCString:kEngineC1Name.c_str()
                                      encoding:[NSString
                                                   defaultCStringEncoding]]]
           .location != NSNotFound));
  ASSERT_EQ(1u, accountFooterTextItem.urls.size());
}

TEST_F(ClearBrowsingDataManagerTest, TestCustomeTextSignedOut) {
  base::test::ScopedFeatureList scoped_feature_list;
  scoped_feature_list.InitAndEnableFeature(kSearchHistoryLinkIOS);

  AuthenticationServiceFactory::GetForBrowserState(browser_state_.get())
      ->SignOut(signin_metrics::ABORT_SIGNIN,
                /*force_clear_browsing_data=*/false, nil);

  // Set DSE to a be fully custom.
  const std::string kEngineC1Name = "custom-1";
  const GURL kEngineC1Url = GURL("https://c1.com?q={searchTerms}");

  AddCustomSearchEngine(/* short_name */ kEngineC1Name,
                        /* searchable_url */ kEngineC1Url,
                        /* last_visited_time */ base::Time::Now() -
                            base::TimeDelta::FromSeconds(10),
                        /* set_default */ true);

  [manager_ loadModel:model_];

  ASSERT_TRUE(
      [model_ hasSectionForSectionIdentifier:SectionIdentifierGoogleAccount]);
  ASSERT_FALSE(
      ![model_ footerForSectionWithIdentifier:SectionIdentifierGoogleAccount]);
  ListItem* googleAccount =
      [model_ footerForSectionWithIdentifier:SectionIdentifierGoogleAccount];
  TableViewLinkHeaderFooterItem* accountFooterTextItem =
      base::mac::ObjCCastStrict<TableViewLinkHeaderFooterItem>(googleAccount);
  ASSERT_FALSE(
      ([accountFooterTextItem.text
           rangeOfString:[NSString
                             stringWithCString:kEngineC1Name.c_str()
                                      encoding:[NSString
                                                   defaultCStringEncoding]]]
           .location != NSNotFound));
  ASSERT_EQ(0u, accountFooterTextItem.urls.size());
}

}  // namespace
