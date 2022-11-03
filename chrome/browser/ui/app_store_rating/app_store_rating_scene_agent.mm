// Copyright 2022 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/app_store_rating/app_store_rating_scene_agent.h"

#import <Foundation/Foundation.h>

#import "base/mac/foundation_util.h"
#import "base/time/time.h"
#import "components/password_manager/core/browser/password_manager_util.h"
#import "components/prefs/pref_service.h"
#import "ios/chrome/browser/application_context/application_context.h"
#import "ios/chrome/browser/browser_state/chrome_browser_state.h"
#import "ios/chrome/browser/main/browser.h"
#import "ios/chrome/browser/promos_manager/constants.h"
#import "ios/chrome/browser/promos_manager/promos_manager.h"
#import "ios/chrome/browser/ui/app_store_rating/constants.h"
#import "ios/chrome/browser/ui/default_promo/default_browser_utils.h"
#import "ios/chrome/browser/ui/main/browser_interface_provider.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@interface AppStoreRatingSceneAgent ()

// Determines whether the user has used Chrome for at least 3
// different days within the past 7 days.
@property(nonatomic, assign, readonly, getter=isChromeUsed3DaysInPastWeek)
    BOOL chromeUsed3DaysInPastWeek;

// Determines whether the user has used Chrome for at least 15
// different days overall.
@property(nonatomic, assign, readonly, getter=isChromeUsed15Days)
    BOOL chromeUsed15Days;

// Determines whether the user has enabled the Credentials
// Provider Extension.
@property(nonatomic, assign, readonly, getter=isCPEEnabled) BOOL CPEEnabled;

// The PromosManager is used to register promos.
@property(nonatomic, assign) PromosManager* promosManager;

@end

@implementation AppStoreRatingSceneAgent

- (instancetype)initWithPromosManager:(PromosManager*)promosManager {
  if (self = [super init]) {
    _promosManager = promosManager;
  }
  return self;
}

- (BOOL)isUserEngaged {
  return IsChromeLikelyDefaultBrowser() && self.chromeUsed3DaysInPastWeek &&
         self.chromeUsed15Days && self.CPEEnabled;
}

#pragma mark - SceneStateObserver

- (void)sceneState:(SceneState*)sceneState
    transitionedToActivationLevel:(SceneActivationLevel)level {
  switch (level) {
    case SceneActivationLevelUnattached:
      // no-op.
      break;
    case SceneActivationLevelBackground:
      // no-op.
      break;
    case SceneActivationLevelForegroundInactive:
      // no-op.
      break;
    case SceneActivationLevelForegroundActive:
      [self updateUserDefaults];
      if ([self isUserEngaged]) {
        [self requestPromoDisplay];
      }
      break;
  }
}

#pragma mark - Getters

- (BOOL)isChromeUsed3DaysInPastWeek {
  NSArray* activeDaysInPastWeek =
      base::mac::ObjCCastStrict<NSArray>([[NSUserDefaults standardUserDefaults]
          objectForKey:kAppStoreRatingActiveDaysInPastWeekKey]);
  return [activeDaysInPastWeek count] >= 3;
}

- (BOOL)isChromeUsed15Days {
  return [[NSUserDefaults standardUserDefaults]
             integerForKey:kAppStoreRatingTotalDaysOnChromeKey] >= 15;
}

- (BOOL)isCPEEnabled {
  DCHECK(self.sceneState.interfaceProvider.mainInterface.browser);
  PrefService* pref_service =
      self.sceneState.interfaceProvider.mainInterface.browser->GetBrowserState()
          ->GetPrefs();
  return password_manager_util::IsCredentialProviderEnabledOnStartup(
      pref_service);
}

#pragma mark - Private

// Calls the PromosManager to request iOS displays the
// App Store Rating prompt to the user.
- (void)requestPromoDisplay {
  if (!_promosManager)
    return;
  _promosManager->RegisterPromoForSingleDisplay(
      promos_manager::Promo::AppStoreRating);
}

// Returns an array of user's active days in the past week, not including the
// current session.
- (std::vector<base::Time>)activeDaysInPastWeek {
  NSArray* storedActiveDaysInPastWeek =
      base::mac::ObjCCastStrict<NSArray>([[NSUserDefaults standardUserDefaults]
          objectForKey:kAppStoreRatingActiveDaysInPastWeekKey]);

  std::vector<base::Time> activeDaysInPastWeek;
  base::Time midnightToday = base::Time::Now().UTCMidnight();
  for (NSDate* storedDate : storedActiveDaysInPastWeek) {
    base::Time date = base::Time::FromNSDate(storedDate).UTCMidnight();
    if (midnightToday - date < base::Days(7)) {
      activeDaysInPastWeek.push_back(date.UTCMidnight());
    }
  }

  return activeDaysInPastWeek;
}

// Stores array of user's active days in the past week to
// `kAppStoreRatingActiveDaysInPastWeekKey` in NSUserDefaults.
- (void)storeActiveDaysInPastWeek:
    (const std::vector<base::Time>&)activeDaysInPastWeek {
  NSMutableArray* datesToStore = [[NSMutableArray alloc] init];
  for (base::Time date : activeDaysInPastWeek) {
    NSDate* dateToStore = date.ToNSDate();
    [datesToStore addObject:dateToStore];
  }

  [[NSUserDefaults standardUserDefaults]
      setObject:datesToStore
         forKey:kAppStoreRatingActiveDaysInPastWeekKey];
}

// Updates `kAppStoreRatingTotalDaysOnChromeKey` and
// `kAppStoreRatingActiveDaysInPastWeekKey` in NSUserDefaults. This method is
// destructive and may modify `kAppStoreRatingActiveDaysInPastWeekKey`.
- (void)updateUserDefaults {
  std::vector<base::Time> activeDaysInPastWeek = [self activeDaysInPastWeek];

  // Check if today has been recorded. If not, record today.
  base::Time today = base::Time::Now().UTCMidnight();
  BOOL isTodayRecorded = !activeDaysInPastWeek.empty() &&
                         today - activeDaysInPastWeek.back() < base::Days(1);

  if (isTodayRecorded) {
    return;
  }

  activeDaysInPastWeek.push_back(today);
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  NSInteger totalDaysOnChrome =
      [defaults integerForKey:kAppStoreRatingTotalDaysOnChromeKey] + 1;
  [defaults setInteger:totalDaysOnChrome
                forKey:kAppStoreRatingTotalDaysOnChromeKey];

  [self storeActiveDaysInPastWeek:activeDaysInPastWeek];
}

@end
