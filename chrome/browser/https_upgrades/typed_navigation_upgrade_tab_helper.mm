// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/https_upgrades/typed_navigation_upgrade_tab_helper.h"

#include "base/feature_list.h"
#include "base/metrics/histogram_functions.h"
#include "base/strings/string_number_conversions.h"
#include "components/security_interstitials/core/omnibox_https_upgrade_metrics.h"
#include "ios/chrome/browser/browser_state/chrome_browser_state.h"
#include "ios/chrome/browser/https_upgrades/https_upgrade_service_factory.h"
#include "ios/chrome/browser/https_upgrades/https_upgrade_service_impl.h"
#import "ios/chrome/browser/prerender/prerender_service.h"
#import "ios/chrome/browser/prerender/prerender_service_factory.h"
#include "ios/components/security_interstitials/https_only_mode/https_upgrade_service.h"
#import "ios/web/public/navigation/https_upgrade_type.h"
#import "ios/web/public/navigation/navigation_context.h"
#include "ios/web/public/navigation/navigation_item.h"
#include "ios/web/public/navigation/navigation_manager.h"
#import "net/base/mac/url_conversions.h"
#include "ui/base/window_open_disposition.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using security_interstitials::omnibox_https_upgrades::Event;
using security_interstitials::omnibox_https_upgrades::kEventHistogram;

namespace {

void RecordUMA(Event event) {
  base::UmaHistogramEnumeration(kEventHistogram, event);
}

}  // namespace

TypedNavigationUpgradeTabHelper::~TypedNavigationUpgradeTabHelper() = default;

TypedNavigationUpgradeTabHelper::TypedNavigationUpgradeTabHelper(
    web::WebState* web_state,
    PrerenderService* prerender_service,
    HttpsUpgradeService* service)
    : prerender_service_(prerender_service), service_(service) {
  web_state->AddObserver(this);
}

// static
void TypedNavigationUpgradeTabHelper::CreateForWebState(
    web::WebState* web_state) {
  DCHECK(web_state);
  if (!FromWebState(web_state)) {
    PrerenderService* prerender_service =
        PrerenderServiceFactory::GetForBrowserState(
            ChromeBrowserState::FromBrowserState(web_state->GetBrowserState()));
    HttpsUpgradeService* service =
        HttpsUpgradeServiceFactory::GetForBrowserState(
            web_state->GetBrowserState());
    web_state->SetUserData(UserDataKey(),
                           base::WrapUnique(new TypedNavigationUpgradeTabHelper(
                               web_state, prerender_service, service)));
  }
}

void TypedNavigationUpgradeTabHelper::FallbackToHttp(web::WebState* web_state,
                                                     const GURL& https_url) {
  const GURL http_url = service_->GetHttpUrl(https_url);
  DCHECK(http_url.is_valid());
  state_ = State::kFallbackStarted;
  // Start a new navigation to the original HTTP page.
  web::NavigationManager::WebLoadParams params(http_url);
  params.transition_type = navigation_transition_type_;
  params.is_renderer_initiated = navigation_is_renderer_initiated_;
  params.referrer = referrer_;
  // The fallback navigation is no longer considered upgraded.
  params.https_upgrade_type = web::HttpsUpgradeType::kNone;
  // Post a task to navigate to the fallback URL. We don't want to navigate
  // synchronously from a DidNavigationFinish() call.
  base::SequencedTaskRunnerHandle::Get()->PostTask(
      FROM_HERE,
      base::BindOnce(
          [](base::WeakPtr<web::WebState> web_state,
             const web::NavigationManager::WebLoadParams& params) {
            if (web_state)
              web_state->GetNavigationManager()->LoadURLWithParams(params);
          },
          web_state->GetWeakPtr(), std::move(params)));
}

void TypedNavigationUpgradeTabHelper::DidStartNavigation(
    web::WebState* web_state,
    web::NavigationContext* navigation_context) {
  if (navigation_context->IsSameDocument()) {
    return;
  }
  if (prerender_service_ &&
      prerender_service_->IsWebStatePrerendered(web_state)) {
    return;
  }

  web::NavigationItem* item_pending =
      web_state->GetNavigationManager()->GetPendingItem();
  if (item_pending &&
      item_pending->GetHttpsUpgradeType() == web::HttpsUpgradeType::kOmnibox) {
    // TODO(crbug.com/1340742): Remove this scheme check once fixed. Without
    // the fix, kHttpsLoadStarted bucket is mildly overcounted.
    GURL url = item_pending->GetURL();
    if (url.SchemeIs(url::kHttpsScheme) ||
        service_->IsFakeHTTPSForTesting(url)) {
      // Pending navigation may not always correspond to the initial navigation,
      // e.g. when a new navigation is started before the first one is finished,
      // but we are only using it to record metrics so this is acceptable.
      state_ = State::kUpgraded;
      RecordUMA(Event::kHttpsLoadStarted);
    }
  }
}

void TypedNavigationUpgradeTabHelper::DidFinishNavigation(
    web::WebState* web_state,
    web::NavigationContext* navigation_context) {
  if (navigation_context->IsSameDocument() || state_ == State::kNone) {
    return;
  }
  if (prerender_service_ &&
      prerender_service_->IsWebStatePrerendered(web_state)) {
    return;
  }

  // Start a fallback navigation if the upgraded navigation failed.
  if (navigation_context->GetFailedHttpsUpgradeType() ==
      web::HttpsUpgradeType::kOmnibox) {
    RecordUMA(Event::kHttpsLoadFailedWithCertError);
    FallbackToHttp(web_state, navigation_context->GetUrl());
    return;
  }

  // Record success.
  if (state_ == State::kUpgraded &&
      (navigation_context->GetUrl().SchemeIs(url::kHttpsScheme) ||
       service_->IsFakeHTTPSForTesting(navigation_context->GetUrl()))) {
    RecordUMA(Event::kHttpsLoadSucceeded);
  }
  state_ = State::kNone;
}

void TypedNavigationUpgradeTabHelper::WebStateDestroyed(
    web::WebState* web_state) {
  web_state->RemoveObserver(this);
}

WEB_STATE_USER_DATA_KEY_IMPL(TypedNavigationUpgradeTabHelper)
