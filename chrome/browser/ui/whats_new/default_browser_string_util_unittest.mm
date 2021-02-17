// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/whats_new/default_browser_string_util.h"

#include "base/test/scoped_feature_list.h"
#include "ios/chrome/browser/ui/ui_feature_flags.h"
#include "ios/chrome/grit/ios_google_chrome_strings.h"
#include "ios/chrome/grit/ios_strings.h"
#include "testing/gtest/include/gtest/gtest.h"
#include "testing/gtest_mac.h"
#include "testing/platform_test.h"
#include "ui/base/l10n/l10n_util_mac.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

using DefaultBrowserStringUtilTest = PlatformTest;

// Tests strings for "Switch" experiment.
TEST_F(DefaultBrowserStringUtilTest, SwitchExperiment) {
  base::FieldTrial* trial =
      base::FieldTrialList::CreateFieldTrial("TrialName", "Switch");
  std::unique_ptr<base::FeatureList> feature_list(
      std::make_unique<base::FeatureList>());
  feature_list->RegisterFieldTrialOverride(
      kDefaultBrowserFullscreenPromoCTAExperiment.name,
      base::FeatureList::OVERRIDE_ENABLE_FEATURE, trial);
  base::test::ScopedFeatureList scoped_feature_list;
  scoped_feature_list.InitWithFeatureList(std::move(feature_list));

  NSString* actualTitle = GetDefaultBrowserPromoTitle();
  NSString* expectedTitle = l10n_util::GetNSString(
      IDS_IOS_DEFAULT_BROWSER_TITLE_CTA_EXPERIMENT_SWITCH);
  ASSERT_NSEQ(expectedTitle, actualTitle);

  NSString* actualLearnMore = GetDefaultBrowserLearnMoreText();
  NSString* expectedLearnMore = l10n_util::GetNSString(
      IDS_IOS_DEFAULT_BROWSER_LEARN_MORE_INSTRUCTIONS_MESSAGE_CTA_EXPERIMENT);
  ASSERT_NSEQ(expectedLearnMore, actualLearnMore);
}

// Tests strings for "Open Links" experiment.
TEST_F(DefaultBrowserStringUtilTest, OpenLinksExperiment) {
  base::FieldTrial* trial =
      base::FieldTrialList::CreateFieldTrial("TrialName", "OpenLinks");
  std::unique_ptr<base::FeatureList> feature_list(
      std::make_unique<base::FeatureList>());
  feature_list->RegisterFieldTrialOverride(
      kDefaultBrowserFullscreenPromoCTAExperiment.name,
      base::FeatureList::OVERRIDE_ENABLE_FEATURE, trial);
  base::test::ScopedFeatureList scoped_feature_list;
  scoped_feature_list.InitWithFeatureList(std::move(feature_list));

  NSString* actualTitle = GetDefaultBrowserPromoTitle();
  NSString* expectedTitle = l10n_util::GetNSString(
      IDS_IOS_DEFAULT_BROWSER_TITLE_CTA_EXPERIMENT_OPEN_LINKS);
  ASSERT_NSEQ(expectedTitle, actualTitle);

  NSString* actualLearnMore = GetDefaultBrowserLearnMoreText();
  NSString* expectedLearnMore = l10n_util::GetNSString(
      IDS_IOS_DEFAULT_BROWSER_LEARN_MORE_INSTRUCTIONS_MESSAGE_CTA_EXPERIMENT);
  ASSERT_NSEQ(expectedLearnMore, actualLearnMore);
}

// Tests strings for default.
TEST_F(DefaultBrowserStringUtilTest, DefaultStrings) {
  NSString* actualTitle = GetDefaultBrowserPromoTitle();
  NSString* expectedTitle =
      l10n_util::GetNSString(IDS_IOS_DEFAULT_BROWSER_TITLE);
  ASSERT_NSEQ(expectedTitle, actualTitle);

  NSString* actualLearnMore = GetDefaultBrowserLearnMoreText();
  NSString* expectedLearnMore =
      l10n_util::GetNSString(IDS_IOS_DEFAULT_BROWSER_LEARN_MORE_MESSAGE);
  ASSERT_NSEQ(expectedLearnMore, actualLearnMore);
}

}  // namespace
