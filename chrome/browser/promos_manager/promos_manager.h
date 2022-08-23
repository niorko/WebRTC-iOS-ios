// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_PROMOS_MANAGER_PROMOS_MANAGER_H_
#define IOS_CHROME_BROWSER_PROMOS_MANAGER_PROMOS_MANAGER_H_

#import <Foundation/Foundation.h>
#import <vector>

#import "base/values.h"
#import "components/prefs/pref_service.h"
#import "ios/chrome/browser/promos_manager/constants.h"
#import "ios/chrome/browser/promos_manager/impression_limit.h"
#import "third_party/abseil-cpp/absl/types/optional.h"

class PromosManagerTest;

// Centralized promos manager for coordinating and scheduling the display of
// app-wide promos. Feature teams interested in displaying promos should
// leverage this manager.
class PromosManager {
 public:
  explicit PromosManager(PrefService* local_state);
  ~PromosManager();

  // Initialize the Promos Manager by restoring state from Prefs. Must be called
  // after creation and before any other operation.
  void Init();

 private:
  // Weak pointer to the local state prefs store.
  const raw_ptr<PrefService> local_state_;

  // base::Value::List of active promos.
  base::Value::List active_promos_;

  // base::Value::List of the promo impression history.
  base::Value::List impression_history_;

  // `promo`-specific impression limits, if defined. May return an empty
  // NSArray, indicating no promo-specific impression limits were defined for
  // `promo`.
  NSArray<ImpressionLimit*>* PromoImpressionLimits(
      promos_manager::Promo promo) const;

  // Returns the least recently shown promo given the set of currently active
  // promo campaigns, `active_promos`. Assumes that `sorted_impressions` is
  // sorted by day (most recent -> least recent).
  //
  // When `active_promos` is empty, returns absl::nullopt.
  //
  // When `sorted_impressions` is empty, no "least recently shown" promo
  // exists—because no promo has ever been shown. In this case,
  // return the first promo in `active_promos`.
  absl::optional<promos_manager::Promo> LeastRecentlyShown(
      const std::set<promos_manager::Promo>& active_promos,
      const std::vector<promos_manager::Impression>& sorted_impressions) const;

  // Impression limits that count against all promos.
  NSArray<ImpressionLimit*>* GlobalImpressionLimits() const;

  // Impression limits that count against any given promo.
  NSArray<ImpressionLimit*>* GlobalPerPromoImpressionLimits() const;

  // Returns the most recent day (int) that `promo` was seen by the user.
  //
  // A day (int) is represented as the number of days since the Unix epoch
  // (running from UTC midnight to UTC midnight).
  //
  // Assumes that `sorted_impressions` is sorted by day (most recent -> least
  // recent).
  //
  // Returns promos_manager::kLastSeenDayPromoNotFound if `promo` isn't
  // found in the impressions list.
  int LastSeenDay(
      promos_manager::Promo promo,
      std::vector<promos_manager::Impression>& sorted_impressions) const;

  // Returns true if any impression limit from `impression_limits` is triggered,
  // and false otherwise.
  //
  // At each limit, evaluates the following:
  //
  // (1) Is the current limit valid for evaluation? This is determined by
  // whether or not `window_days` is < the current limit's window.
  //
  // (2) If the limit is valid for evaluation, compare `impression_count` with
  // the current limit's impression count. If `impression_count` >= the current
  // limit's impression count, the limit has been triggered.

  // (3) If the limit is triggered, exits early and returns true. Otherwise,
  // keep going.
  bool AnyImpressionLimitTriggered(
      int impression_count,
      int window_days,
      NSArray<ImpressionLimit*>* impression_limits) const;

  // Algorithm loops over pre-pruned & pre-sorted impressions history list.
  // The algorithm assumes:
  //
  // (1) `valid_impressions` only contains impressions that occurred in the
  // last `kNumDaysForStoringImpressionHistory` days. (2)
  // `valid_impressions` is sorted by impression day (most recent -> least
  // recent).
  //
  // At each impression, the algorithm asks if either a time-based or
  // time-agnostic impression limit has been met. If so, the algorithm exits
  // early and returns false.
  //
  // If the algorithm reaches its end, no impression limits were hit for
  // `promo`. If so, the algorithm returns true, as it's safe to display
  // `promo`.
  bool CanShowPromo(
      promos_manager::Promo promo,
      const std::vector<promos_manager::Impression>& valid_impressions) const;

  // Returns a list of impression counts (std::vector<int>) from a promo
  // impression counts map.
  std::vector<int> ImpressionCounts(
      std::map<promos_manager::Promo, int>& promo_impression_counts) const;

  // Returns the greatest impression count (int) from a promo impression counts
  // map.
  int MaxImpressionCount(
      std::map<promos_manager::Promo, int>& promo_impression_counts) const;

  // Returns the total number of impressions (int) from a promo impression
  // counts map.
  int TotalImpressionCount(
      std::map<promos_manager::Promo, int>& promo_impression_counts) const;

  // Allow unit tests to access private methods.
  friend class PromosManagerTest;
  FRIEND_TEST_ALL_PREFIXES(PromosManagerTest, ReturnsLastSeenDayForPromo);
  FRIEND_TEST_ALL_PREFIXES(PromosManagerTest,
                           ReturnsSentinelForNonExistentPromo);
  FRIEND_TEST_ALL_PREFIXES(PromosManagerTest, ReturnsImpressionCounts);
  FRIEND_TEST_ALL_PREFIXES(PromosManagerTest, ReturnsEmptyImpressionCounts);
  FRIEND_TEST_ALL_PREFIXES(PromosManagerTest, ReturnsTotalImpressionCount);
  FRIEND_TEST_ALL_PREFIXES(PromosManagerTest,
                           ReturnsZeroForTotalImpressionCount);
  FRIEND_TEST_ALL_PREFIXES(PromosManagerTest, ReturnsMaxImpressionCount);
  FRIEND_TEST_ALL_PREFIXES(PromosManagerTest, ReturnsZeroForMaxImpressionCount);
  FRIEND_TEST_ALL_PREFIXES(PromosManagerTest,
                           DetectsSingleImpressionLimitTriggered);
  FRIEND_TEST_ALL_PREFIXES(PromosManagerTest,
                           DetectsOneOfMultipleImpressionLimitsTriggered);
  FRIEND_TEST_ALL_PREFIXES(PromosManagerTest,
                           DetectsNoImpressionLimitTriggered);
  FRIEND_TEST_ALL_PREFIXES(PromosManagerTest, DecidesCanShowPromo);
  FRIEND_TEST_ALL_PREFIXES(PromosManagerTest, DecidesCannotShowPromo);
  FRIEND_TEST_ALL_PREFIXES(PromosManagerTest, ReturnsLeastRecentlyShown);
  FRIEND_TEST_ALL_PREFIXES(PromosManagerTest,
                           ReturnsLeastRecentlyShownWithSomeInactivePromos);
  FRIEND_TEST_ALL_PREFIXES(PromosManagerTest,
                           ReturnsLeastRecentlyShownBreakingTies);
  FRIEND_TEST_ALL_PREFIXES(PromosManagerTest,
                           ReturnsLeastRecentlyShownWithOnlyOnePromoActive);
  FRIEND_TEST_ALL_PREFIXES(PromosManagerTest,
                           ReturnsLeastRecentlyShownWithoutImpressionHistory);
  FRIEND_TEST_ALL_PREFIXES(
      PromosManagerTest,
      ReturnsNulloptWhenLeastRecentlyShownHasNoActivePromoCampaigns);
  FRIEND_TEST_ALL_PREFIXES(PromosManagerTest,
                           ReturnsFirstUnshownPromoForLeastRecentlyShown);
};

#endif  // IOS_CHROME_BROWSER_PROMOS_MANAGER_PROMOS_MANAGER_H_
