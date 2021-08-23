// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "ios/chrome/browser/optimization_guide/optimization_guide_tab_helper.h"

#import "base/base64.h"
#import "base/test/ios/wait_util.h"
#import "base/test/metrics/histogram_tester.h"
#import "base/test/scoped_feature_list.h"
#import "base/test/task_environment.h"
#import "components/optimization_guide/core/optimization_guide_features.h"
#import "components/optimization_guide/core/optimization_guide_navigation_data.h"
#import "components/optimization_guide/core/optimization_guide_switches.h"
#import "ios/chrome/browser/browser_state/chrome_browser_state.h"
#import "ios/chrome/browser/browser_state/test_chrome_browser_state.h"
#import "ios/chrome/browser/optimization_guide/optimization_guide_service.h"
#import "ios/chrome/browser/optimization_guide/optimization_guide_service_factory.h"
#import "ios/web/public/test/fakes/fake_navigation_context.h"
#import "ios/web/public/test/fakes/fake_web_state.h"
#import "testing/gmock/include/gmock/gmock.h"
#import "testing/gtest/include/gtest/gtest.h"
#import "testing/platform_test.h"
#import "url/gurl.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using testing::ElementsAre;

namespace {

constexpr int64_t kNavigationID = 1;
constexpr char kHintsURL[] = "https://hints.com/with_hints.html";
constexpr char kNoHintsURL[] = "https://nohints.com/no_hints.html";

void RetryForHistogramUntilCountReached(
    const base::HistogramTester* histogram_tester,
    const std::string& histogram_name,
    int count) {
  EXPECT_TRUE(base::test::ios::WaitUntilConditionOrTimeout(
      base::test::ios::kWaitForPageLoadTimeout, ^{
        base::RunLoop().RunUntilIdle();
        int total = 0;
        for (const auto& bucket :
             histogram_tester->GetAllSamples(histogram_name)) {
          total += bucket.count;
        }
        return total >= count;
      }));
}

std::string CreateHintsConfig() {
  optimization_guide::proto::Configuration config;
  optimization_guide::proto::Hint* hint = config.add_hints();
  GURL hints_url(kHintsURL);
  hint->set_key(hints_url.host());
  hint->set_key_representation(optimization_guide::proto::HOST);

  optimization_guide::proto::PageHint* page_hint = hint->add_page_hints();
  page_hint->set_page_pattern(hints_url.path().substr(1));

  optimization_guide::proto::Optimization* optimization =
      page_hint->add_allowlisted_optimizations();
  optimization->set_optimization_type(optimization_guide::proto::NOSCRIPT);

  std::string encoded_config;
  config.SerializeToString(&encoded_config);
  base::Base64Encode(encoded_config, &encoded_config);
  return encoded_config;
}

class IOSOptimizationGuideNavigationDataTest : public PlatformTest {
 public:
  IOSOptimizationGuideNavigationDataTest()
      : test_navigation_data_(kNavigationID) {}

 protected:
  IOSOptimizationGuideNavigationData test_navigation_data_;
};

TEST_F(IOSOptimizationGuideNavigationDataTest, CheckNavigationId) {
  EXPECT_EQ(kNavigationID, test_navigation_data_.navigation_id());
}

TEST_F(IOSOptimizationGuideNavigationDataTest, CheckNavigationURL) {
  GURL kFooURL("https://foo.com");
  test_navigation_data_.NotifyNavigationStart(kFooURL);
  EXPECT_EQ(kFooURL, test_navigation_data_.navigation_url());
  EXPECT_THAT(test_navigation_data_.redirect_chain(), ElementsAre(kFooURL));
}

TEST_F(IOSOptimizationGuideNavigationDataTest, CheckNavigationRedirect) {
  GURL kFooURL("https://foo.com");
  GURL kRedirectBarURL("https://bar.com");
  GURL kRedirectBazURL("https://baz.com");

  test_navigation_data_.NotifyNavigationStart(kFooURL);
  EXPECT_EQ(kFooURL, test_navigation_data_.navigation_url());
  EXPECT_THAT(test_navigation_data_.redirect_chain(), ElementsAre(kFooURL));

  test_navigation_data_.NotifyNavigationRedirect(kRedirectBarURL);
  EXPECT_EQ(kRedirectBarURL, test_navigation_data_.navigation_url());
  EXPECT_THAT(test_navigation_data_.redirect_chain(),
              ElementsAre(kFooURL, kRedirectBarURL));

  test_navigation_data_.NotifyNavigationRedirect(kRedirectBazURL);
  EXPECT_EQ(kRedirectBazURL, test_navigation_data_.navigation_url());
  EXPECT_THAT(test_navigation_data_.redirect_chain(),
              ElementsAre(kFooURL, kRedirectBarURL, kRedirectBazURL));
}

TEST_F(IOSOptimizationGuideNavigationDataTest,
       CheckNavigationStartCancelsRedirect) {
  GURL kFooURL("https://foo.com");
  GURL kBarURL("https://bar.com");
  GURL kBazURL("https://baz.com");

  test_navigation_data_.NotifyNavigationStart(kFooURL);
  test_navigation_data_.NotifyNavigationRedirect(kBarURL);
  EXPECT_EQ(kBarURL, test_navigation_data_.navigation_url());
  EXPECT_THAT(test_navigation_data_.redirect_chain(),
              ElementsAre(kFooURL, kBarURL));

  test_navigation_data_.NotifyNavigationStart(kBazURL);
  EXPECT_EQ(kBazURL, test_navigation_data_.navigation_url());
  EXPECT_THAT(test_navigation_data_.redirect_chain(), ElementsAre(kBazURL));
}

class OptimizationGuideTabHelperTest : public PlatformTest {
 public:
  OptimizationGuideTabHelperTest() {
    base::CommandLine::ForCurrentProcess()->AppendSwitch(
        optimization_guide::switches::kPurgeHintsStore);
    base::CommandLine::ForCurrentProcess()->AppendSwitchASCII(
        optimization_guide::switches::kHintsProtoOverride, CreateHintsConfig());
  }

  void SetUp() override {
    scoped_feature_list_.InitWithFeatures(
        {optimization_guide::features::kOptimizationHints}, {});

    browser_state_ = TestChromeBrowserState::Builder().Build();

    web_state_.SetBrowserState(browser_state_.get());
    optimization_guide_service_ =
        OptimizationGuideServiceFactory::GetForBrowserState(
            browser_state_.get());

    OptimizationGuideTabHelper::CreateForWebState(&web_state_);

    // Wait for the hints override from CLI is picked up.
    RetryForHistogramUntilCountReached(
        &histogram_tester_, "OptimizationGuide.UpdateComponentHints.Result", 1);
  }

  void RunUntilIdle() { base::RunLoop().RunUntilIdle(); }

 protected:
  base::test::TaskEnvironment task_environment_;
  base::test::ScopedFeatureList scoped_feature_list_;
  base::HistogramTester histogram_tester_;
  std::unique_ptr<TestChromeBrowserState> browser_state_;
  OptimizationGuideService* optimization_guide_service_;
  web::FakeWebState web_state_;
};

TEST_F(OptimizationGuideTabHelperTest, NavigationToURLWithHints) {
  optimization_guide_service_->RegisterOptimizationTypes(
      {optimization_guide::proto::NOSCRIPT});

  web::FakeNavigationContext context;
  context.SetUrl(GURL(kHintsURL));
  web_state_.OnNavigationStarted(&context);
  web_state_.OnNavigationFinished(&context);
  RunUntilIdle();

  auto decision = optimization_guide_service_->CanApplyOptimization(
      GURL(kHintsURL), optimization_guide::proto::NOSCRIPT,
      /*optimization_metadata=*/nullptr);

  EXPECT_EQ(optimization_guide::OptimizationGuideDecision::kTrue, decision);
}

TEST_F(OptimizationGuideTabHelperTest, NavigationToURLWithNoHints) {
  optimization_guide_service_->RegisterOptimizationTypes(
      {optimization_guide::proto::NOSCRIPT});

  web::FakeNavigationContext context;
  context.SetUrl(GURL(kNoHintsURL));
  web_state_.OnNavigationStarted(&context);
  web_state_.OnNavigationFinished(&context);
  RunUntilIdle();

  auto decision = optimization_guide_service_->CanApplyOptimization(
      GURL(kNoHintsURL), optimization_guide::proto::NOSCRIPT,
      /*optimization_metadata=*/nullptr);

  EXPECT_EQ(optimization_guide::OptimizationGuideDecision::kFalse, decision);
}

}  // namespace
