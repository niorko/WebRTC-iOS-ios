// Copyright 2022 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/tabs/features.h"

#import "base/mac/foundation_util.h"
#import "base/metrics/field_trial_params.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

BASE_FEATURE(kEnablePinnedTabs,
             "EnablePinnedTabs",
             base::FEATURE_DISABLED_BY_DEFAULT);

const char kEnablePinnedTabsOverflowParam[] = "overflow_param";

bool IsPinnedTabsEnabled() {
  return base::FeatureList::IsEnabled(kEnablePinnedTabs);
}

bool IsPinnedTabsOverflowEnabled() {
  if (!IsPinnedTabsEnabled()) {
    return false;
  }
  return base::GetFieldTrialParamByFeatureAsBool(
      kEnablePinnedTabs, kEnablePinnedTabsOverflowParam, /*default=*/false);
}
