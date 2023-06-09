// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/follow/follow_util.h"

#import <UIKit/UIKit.h>

#include "ios/chrome/browser/browser_state/chrome_browser_state.h"
#import "ios/chrome/browser/ntp/features.h"
#import "ios/chrome/browser/signin/authentication_service.h"
#import "ios/chrome/browser/signin/authentication_service_factory.h"
#include "ios/web/public/web_client.h"
#import "ios/web/public/web_state.h"
#include "url/gurl.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
// Set the Follow IPH apperance threshold to 15 minutes.
NSTimeInterval const kFollowIPHAppearanceThresholdInSeconds = 15 * 60;
// Set the Follow IPH apperance threshold for site to 1 day.
NSTimeInterval const kFollowIPHAppearanceThresholdForSiteInSeconds =
    24 * 60 * 60;
}  // namespace

NSString* const kFollowIPHLastShownTime = @"FollowIPHLastShownTime";
NSString* const kFollowIPHLastShownTimeForSite =
    @"FollowIPHLastShownTimeForSite";

FollowActionState GetFollowActionState(web::WebState* webState) {
  // This method should be called only if the feature flag has been enabled.
  DCHECK(IsWebChannelsEnabled());

  if (!webState) {
    return FollowActionStateHidden;
  }

  ChromeBrowserState* browserState =
      ChromeBrowserState::FromBrowserState(webState->GetBrowserState());
  AuthenticationService* authenticationService =
      AuthenticationServiceFactory::GetForBrowserState(browserState);

  // Hide the follow action when users have not signed in.
  if (!authenticationService || !authenticationService->GetPrimaryIdentity(
                                    signin::ConsentLevel::kSignin)) {
    return FollowActionStateHidden;
  }

  const GURL& URL = webState->GetLastCommittedURL();
  // Show the follow action when:
  // 1. The page url is valid;
  // 2. Users are not on NTP or Chrome internal pages;
  // 3. Users are not in incognito mode.
  if (URL.is_valid() && !web::GetWebClient()->IsAppSpecificURL(URL) &&
      !browserState->IsOffTheRecord()) {
    return FollowActionStateEnabled;
  }
  return FollowActionStateHidden;
}

#pragma mark - For Follow IPH
bool IsFollowIPHShownFrequencyEligible(NSURL* RSSLink) {
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  NSDate* lastFollowIPHShownTime =
      [defaults objectForKey:kFollowIPHLastShownTime];
  // Return false if its too soon to show another IPH.
  if ([[NSDate
          dateWithTimeIntervalSinceNow:-kFollowIPHAppearanceThresholdInSeconds]
          compare:lastFollowIPHShownTime] == NSOrderedAscending)
    return false;

  NSDictionary<NSURL*, NSDate*>* lastFollowIPHShownTimeForSite =
      [defaults objectForKey:kFollowIPHLastShownTimeForSite];
  NSDate* lastIPHForSite = [lastFollowIPHShownTimeForSite objectForKey:RSSLink];
  // Return true if it is long enough to show another IPH for this specific
  // site.
  if (!lastIPHForSite ||
      [[NSDate dateWithTimeIntervalSinceNow:
                   -kFollowIPHAppearanceThresholdForSiteInSeconds]
          compare:lastIPHForSite] != NSOrderedAscending)
    return true;

  return false;
}

void StoreFollowIPHPresentingTime(NSURL* RSSLink) {
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  NSDictionary<NSURL*, NSDate*>* lastFollowIPHShownTimeForSite =
      [defaults objectForKey:kFollowIPHLastShownTimeForSite];

  // Convert the dictionary to a mutable dictionary.
  // If the dictionary value hasn't been set in user default, then create a
  // mutable dictionary.
  NSMutableDictionary<NSURL*, NSDate*>* mutablelLastFollowIPHShownTimeForSite =
      lastFollowIPHShownTimeForSite
          ? [lastFollowIPHShownTimeForSite mutableCopy]
          : [[NSMutableDictionary<NSURL*, NSDate*> alloc] init];

  // Update the last follow IPH show time for `RSSLink`.
  [mutablelLastFollowIPHShownTimeForSite setObject:[NSDate date]
                                            forKey:RSSLink];

  NSDate* uselessDate =
      [NSDate dateWithTimeIntervalSinceNow:
                  -kFollowIPHAppearanceThresholdForSiteInSeconds];
  // Clean up object that has a date older than 1 day ago. Since the follow iph
  // will show less than 5 times a week, this clean up logic won't execute
  // every time when page loaded.
  // TODO(crbug.com/1340154): move the clean up logic to a more fitable place.
  for (NSURL* key in mutablelLastFollowIPHShownTimeForSite) {
    if ([[mutablelLastFollowIPHShownTimeForSite objectForKey:key]
            compare:uselessDate] == NSOrderedAscending) {
      [mutablelLastFollowIPHShownTimeForSite removeObjectForKey:key];
    }
  }

  [defaults setObject:mutablelLastFollowIPHShownTimeForSite
               forKey:kFollowIPHLastShownTimeForSite];
  [defaults synchronize];
}
