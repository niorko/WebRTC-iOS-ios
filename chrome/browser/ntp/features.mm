// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ntp/features.h"

#import <Foundation/Foundation.h>

#import "base/metrics/field_trial_params.h"
#import "components/version_info/channel.h"
#import "ios/chrome/app/background_mode_buildflags.h"
#import "ios/chrome/browser/system_flags.h"
#import "ios/chrome/common/channel_info.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

const base::Feature kBlockNewTabPagePendingLoad{
    "BlockNewTabPagePendingLoad", base::FEATURE_DISABLED_BY_DEFAULT};

const base::Feature kEnableWebChannels{"EnableWebChannels",
                                       base::FEATURE_DISABLED_BY_DEFAULT};

const base::Feature kEnableFeedBackgroundRefresh{
    "EnableFeedBackgroundRefresh", base::FEATURE_DISABLED_BY_DEFAULT};

// Key for NSUserDefaults containing a bool indicating whether the next run
// should enable feed backround refresh. This is used because registering for
// background refreshes must happen early in app initialization and FeatureList
// is not yet available. Changing the `kEnableFeedBackgroundRefresh` feature
// will always take effect after two cold starts after the feature has been
// changed on the server (once for the finch configuration, and another for
// reading the stored value from NSUserDefaults).
NSString* const kEnableFeedBackgroundRefreshForNextColdStart =
    @"EnableFeedBackgroundRefreshForNextColdStart";

const char kEnableFollowingFeedBackgroundRefresh[] =
    "EnableFollowingFeedBackgroundRefresh";
const char kEnableServerDrivenBackgroundRefreshSchedule[] =
    "EnableServerDrivenBackgroundRefreshSchedule";
const char kEnableRecurringBackgroundRefreshSchedule[] =
    "EnableRecurringBackgroundRefreshSchedule";
const char kMaxCacheAgeInSeconds[] = "MaxCacheAgeInSeconds";
const char kBackgroundRefreshIntervalInSeconds[] =
    "BackgroundRefreshIntervalInSeconds";
const char kBackgroundRefreshMaxAgeInSeconds[] =
    "BackgroundRefreshMaxAgeInSeconds";

bool IsWebChannelsEnabled() {
  return base::FeatureList::IsEnabled(kEnableWebChannels);
}

bool IsFeedBackgroundRefreshEnabled() {
#if !BUILDFLAG(IOS_BACKGROUND_MODE_ENABLED)
  return false;
#else
  static bool feedBackgroundRefreshEnabled =
      [[NSUserDefaults standardUserDefaults]
          boolForKey:kEnableFeedBackgroundRefreshForNextColdStart];
  return feedBackgroundRefreshEnabled;
#endif  // BUILDFLAG(IOS_BACKGROUND_MODE_ENABLED)
}

void SaveFeedBackgroundRefreshEnabledForNextColdStart() {
  DCHECK(base::FeatureList::GetInstance());
  [[NSUserDefaults standardUserDefaults]
      setBool:base::FeatureList::IsEnabled(kEnableFeedBackgroundRefresh)
       forKey:kEnableFeedBackgroundRefreshForNextColdStart];
}

bool IsFeedOverrideDefaultsEnabled() {
  if (GetChannel() == version_info::Channel::STABLE) {
    return false;
  }
  return [[NSUserDefaults standardUserDefaults]
      boolForKey:@"FeedOverrideDefaultsEnabled"];
}

bool IsFeedBackgroundRefreshCompletedNotificationEnabled() {
  if (GetChannel() == version_info::Channel::STABLE) {
    return false;
  }
  return IsFeedBackgroundRefreshEnabled() &&
         [[NSUserDefaults standardUserDefaults]
             boolForKey:@"FeedBackgroundRefreshNotificationEnabled"];
}

bool IsFollowingFeedBackgroundRefreshEnabled() {
  if (IsFeedOverrideDefaultsEnabled()) {
    return [[NSUserDefaults standardUserDefaults]
        boolForKey:@"FollowingFeedBackgroundRefreshEnabled"];
  }
  return base::GetFieldTrialParamByFeatureAsBool(
      kEnableFeedBackgroundRefresh, kEnableFollowingFeedBackgroundRefresh,
      /*default=*/false);
}

bool IsServerDrivenBackgroundRefreshScheduleEnabled() {
  if (IsFeedOverrideDefaultsEnabled()) {
    return [[NSUserDefaults standardUserDefaults]
        boolForKey:@"FeedServerDrivenBackgroundRefreshScheduleEnabled"];
  }
  return base::GetFieldTrialParamByFeatureAsBool(
      kEnableFeedBackgroundRefresh,
      kEnableServerDrivenBackgroundRefreshSchedule, /*default=*/false);
}

bool IsRecurringBackgroundRefreshScheduleEnabled() {
  if (IsFeedOverrideDefaultsEnabled()) {
    return [[NSUserDefaults standardUserDefaults]
        boolForKey:@"FeedRecurringBackgroundRefreshScheduleEnabled"];
  }
  return base::GetFieldTrialParamByFeatureAsBool(
      kEnableFeedBackgroundRefresh, kEnableRecurringBackgroundRefreshSchedule,
      /*default=*/false);
}

double GetFeedMaxCacheAgeInSeconds() {
  if (IsFeedOverrideDefaultsEnabled()) {
    return [[NSUserDefaults standardUserDefaults]
        doubleForKey:@"FeedMaxCacheAgeInSeconds"];
  }
  return base::GetFieldTrialParamByFeatureAsDouble(kEnableFeedBackgroundRefresh,
                                                   kMaxCacheAgeInSeconds,
                                                   /*default=*/8 * 60 * 60);
}

double GetBackgroundRefreshIntervalInSeconds() {
  if (IsFeedOverrideDefaultsEnabled()) {
    return [[NSUserDefaults standardUserDefaults]
        doubleForKey:@"FeedBackgroundRefreshIntervalInSeconds"];
  }
  return base::GetFieldTrialParamByFeatureAsDouble(
      kEnableFeedBackgroundRefresh, kBackgroundRefreshIntervalInSeconds,
      /*default=*/60 * 60);
}

double GetBackgroundRefreshMaxAgeInSeconds() {
  return base::GetFieldTrialParamByFeatureAsDouble(
      kEnableFeedBackgroundRefresh, kBackgroundRefreshMaxAgeInSeconds,
      /*default=*/0);
}
