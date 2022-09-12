// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/commerce/price_alert_util.h"

#include "base/metrics/field_trial_params.h"
#include "components/commerce/core/commerce_feature_list.h"
#include "components/prefs/pref_service.h"
#include "components/unified_consent/url_keyed_data_collection_consent_helper.h"
#import "ios/chrome/browser/browser_state/chrome_browser_state.h"
#import "ios/chrome/browser/prefs/pref_names.h"
#import "ios/chrome/browser/signin/authentication_service.h"
#import "ios/chrome/browser/signin/authentication_service_factory.h"
#import "ios/chrome/browser/ui/ui_feature_flags.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
const char kPriceTrackingNotifications[] = "enable_price_notification";
}  // namespace

bool IsPriceAlertsEligible(web::BrowserState* browser_state) {
  if (browser_state->IsOffTheRecord()) {
    return false;
  }
  // Price drop annotations are only enabled for en_US.
  NSLocale* current_locale = [NSLocale currentLocale];
  if (![@"en_US" isEqualToString:current_locale.localeIdentifier]) {
    return false;
  }
  ChromeBrowserState* chrome_browser_state =
      ChromeBrowserState::FromBrowserState(browser_state);
  AuthenticationService* authentication_service =
      AuthenticationServiceFactory::GetForBrowserState(chrome_browser_state);
  DCHECK(authentication_service);
  if (!authentication_service->HasPrimaryIdentity(
          signin::ConsentLevel::kSignin)) {
    return false;
  }
  PrefService* pref_service = chrome_browser_state->GetPrefs();
  if (!unified_consent::UrlKeyedDataCollectionConsentHelper::
           NewAnonymizedDataCollectionConsentHelper(pref_service)
               ->IsEnabled() ||
      !pref_service->GetBoolean(prefs::kTrackPricesOnTabsEnabled)) {
    return false;
  }
  return true;
}

// Determine if price drop notifications are enabled.
bool IsPriceNotificationsEnabled() {
  return base::GetFieldTrialParamByFeatureAsBool(
      commerce::kCommercePriceTracking, kPriceTrackingNotifications,
      /** default_value */ false);
}
