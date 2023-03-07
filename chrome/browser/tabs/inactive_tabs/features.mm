// Copyright 2023 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/tabs/inactive_tabs/features.h"

#import "base/metrics/field_trial_params.h"
#import "base/strings/string_number_conversions.h"
#import "base/time/time.h"
#import "components/prefs/pref_service.h"
#import "ios/chrome/browser/application_context/application_context.h"
#import "ios/chrome/browser/prefs/pref_names.h"
#import "ui/base/device_form_factor.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

BASE_FEATURE(kTabInactivityThreshold,
             "TabInactivityThreshold",
             base::FEATURE_DISABLED_BY_DEFAULT);

const char kTabInactivityThresholdParameterName[] = "default";
const char kTabInactivityThresholdOneWeekParam[] =
    "tab-inactivity-threshold-one-week";
const char kTabInactivityThresholdTwoWeeksParam[] =
    "tab-inactivity-threshold-two-weeks";
const char kTabInactivityThresholdThreeWeeksParam[] =
    "tab-inactivity-threshold-three-weeks";

bool IsInactiveTabsEnabled() {
  if (ui::GetDeviceFormFactor() == ui::DEVICE_FORM_FACTOR_TABLET) {
    return false;
  }

  if (!base::FeatureList::IsEnabled(kTabInactivityThreshold)) {
    return false;
  }

  static const int kDisabledByUser = -1;
  return GetApplicationContext()->GetLocalState()->GetInteger(
             prefs::kInactiveTabsTimeThreshold) != kDisabledByUser;
}

const base::TimeDelta InactiveTabsTimeThreshold() {
  DCHECK(IsInactiveTabsEnabled());

  // Preference.
  PrefService* local_state = GetApplicationContext()->GetLocalState();
  int user_preference_threshold =
      local_state->GetInteger(prefs::kInactiveTabsTimeThreshold);
  if (user_preference_threshold > 0) {
    return base::Days(user_preference_threshold);
  }

  // Feature flag.
  std::string feature_param = base::GetFieldTrialParamValueByFeature(
      kTabInactivityThreshold, kTabInactivityThresholdParameterName);
  if (feature_param == kTabInactivityThresholdOneWeekParam) {
    return base::Days(8);
  } else if (feature_param == kTabInactivityThresholdTwoWeeksParam) {
    return base::Days(15);
  } else if (feature_param == kTabInactivityThresholdThreeWeeksParam) {
    return base::Days(22);
  }
  return base::Days(15);
}

std::u16string InactiveTabsTimeThresholdDisplayString() {
  DCHECK(IsInactiveTabsEnabled());
  // Remove one day to the threshold to get the user-friendly value.
  return base::NumberToString16(InactiveTabsTimeThreshold().InDays() - 1);
}

BASE_FEATURE(kShowInactiveTabsCount,
             "ShowInactiveTabsCount",
             base::FEATURE_DISABLED_BY_DEFAULT);

bool IsShowInactiveTabsCountEnabled() {
  DCHECK(IsInactiveTabsEnabled());
  return base::FeatureList::IsEnabled(kShowInactiveTabsCount);
}
