// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/app_launcher/app_launcher_tab_helper.h"

#import <UIKit/UIKit.h>

#include "base/memory/ptr_util.h"
#include "base/metrics/histogram_macros.h"
#import "base/strings/sys_string_conversions.h"
#include "components/policy/core/browser/url_blocklist_manager.h"
#include "components/reading_list/core/reading_list_model.h"
#import "ios/chrome/browser/app_launcher/app_launcher_tab_helper_delegate.h"
#include "ios/chrome/browser/browser_state/chrome_browser_state.h"
#import "ios/chrome/browser/chrome_url_util.h"
#import "ios/chrome/browser/policy/policy_features.h"
#import "ios/chrome/browser/policy_url_blocking/policy_url_blocking_service.h"
#import "ios/chrome/browser/policy_url_blocking/policy_url_blocking_util.h"
#include "ios/chrome/browser/reading_list/reading_list_model_factory.h"
#import "ios/chrome/browser/u2f/u2f_tab_helper.h"
#import "ios/web/common/url_scheme_util.h"
#import "ios/web/public/navigation/navigation_item.h"
#import "ios/web/public/navigation/navigation_manager.h"
#import "ios/web/public/web_client.h"
#import "net/base/mac/url_conversions.h"
#include "url/gurl.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

bool IsValidAppUrl(const GURL& app_url) {
  if (!app_url.is_valid())
    return false;

  if (!app_url.has_scheme())
    return false;

  // If the url is a direct FIDO U2F x-callback call, consider it as invalid, to
  // prevent pages from spoofing requests with different origins.
  // See https://crbug.com/897329#c2 for details on how U2F works.
  if (app_url.SchemeIs("u2f-x-callback"))
    return false;

  // Block attempts to open this application's settings in the native system
  // settings application.
  if (app_url.SchemeIs("app-settings"))
    return false;
  return true;
}

// Returns True if |app_url| has a Chrome bundle URL scheme.
bool HasChromeAppScheme(const GURL& app_url) {
  NSArray* chrome_schemes =
      [[ChromeAppConstants sharedInstance] allBundleURLSchemes];
  NSString* app_url_scheme = base::SysUTF8ToNSString(app_url.scheme());
  return [chrome_schemes containsObject:app_url_scheme];
}

// This enum used by the Applauncher to log to UMA, if App launching request was
// allowed or blocked.
// These values are persisted to logs. Entries should not be renumbered and
// numeric values should never be reused.
enum class ExternalURLRequestStatus {
  kMainFrameRequestAllowed = 0,
  kSubFrameRequestAllowed = 1,
  kSubFrameRequestBlocked = 2,
  kCount,
};

}  // namespace

// static
void AppLauncherTabHelper::CreateForWebState(
    web::WebState* web_state,
    AppLauncherAbuseDetector* abuse_detector) {
  if (FromWebState(web_state))
    return;

  web_state->SetUserData(
      UserDataKey(),
      base::WrapUnique(new AppLauncherTabHelper(web_state, abuse_detector)));
}

AppLauncherTabHelper::AppLauncherTabHelper(
    web::WebState* web_state,
    AppLauncherAbuseDetector* abuse_detector)
    : web::WebStatePolicyDecider(web_state),
      web_state_(web_state),
      abuse_detector_(abuse_detector) {
  DCHECK(abuse_detector_);
}

AppLauncherTabHelper::~AppLauncherTabHelper() = default;

// static
bool AppLauncherTabHelper::IsAppUrl(const GURL& url) {
  return !(web::UrlHasWebScheme(url) ||
           web::GetWebClient()->IsAppSpecificURL(url) ||
           url.SchemeIs(url::kFileScheme) || url.SchemeIs(url::kAboutScheme) ||
           url.SchemeIs(url::kBlobScheme));
}

void AppLauncherTabHelper::SetDelegate(AppLauncherTabHelperDelegate* delegate) {
  delegate_ = delegate;
}

void AppLauncherTabHelper::RequestToLaunchApp(const GURL& url,
                                              const GURL& source_page_url,
                                              bool link_transition) {
  // Don't open external application if chrome is not active.
  if ([[UIApplication sharedApplication] applicationState] !=
      UIApplicationStateActive) {
    return;
  }

  // Don't try to open external application if a prompt is already active.
  if (is_prompt_active_)
    return;

  [abuse_detector_ didRequestLaunchExternalAppURL:url
                                fromSourcePageURL:source_page_url];
  ExternalAppLaunchPolicy policy =
      [abuse_detector_ launchPolicyForURL:url
                        fromSourcePageURL:source_page_url];
  switch (policy) {
    case ExternalAppLaunchPolicyBlock: {
      return;
    }
    case ExternalAppLaunchPolicyAllow: {
      if (delegate_)
        delegate_->LaunchAppForTabHelper(this, url, link_transition);
      return;
    }
    case ExternalAppLaunchPolicyPrompt: {
      is_prompt_active_ = true;
      base::WeakPtr<AppLauncherTabHelper> weak_this =
          weak_factory_.GetWeakPtr();
      GURL copied_url = url;
      GURL copied_source_page_url = source_page_url;
      if (!delegate_)
        return;
      delegate_->ShowRepeatedAppLaunchAlert(
          this, base::BindOnce(^(bool user_allowed) {
            if (!weak_this.get())
              return;
            if (user_allowed && weak_this->delegate()) {
              // By confirming that user wants to launch the application, there
              // is no need to check for |link_tapped|.
              weak_this->delegate()->LaunchAppForTabHelper(
                  this, copied_url,
                  /*link_transition=*/true);
            }
            is_prompt_active_ = false;
          }));
      return;
    }
  }
}

void AppLauncherTabHelper::ShouldAllowRequest(
    NSURLRequest* request,
    const web::WebStatePolicyDecider::RequestInfo& request_info,
    web::WebStatePolicyDecider::PolicyDecisionCallback callback) {
  GURL request_url = net::GURLWithNSURL(request.URL);
  if (!IsAppUrl(request_url)) {
    // This URL can be handled by the WebState and doesn't require App launcher
    // handling.
    return std::move(callback).Run(
        web::WebStatePolicyDecider::PolicyDecision::Allow());
  }

  if (IsURLBlocklistEnabled()) {
    // Do not allow allow navigation if URL is blocked by enterprise policy.
    PolicyBlocklistService* blocklistService =
        PolicyBlocklistServiceFactory::GetForBrowserState(
            web_state()->GetBrowserState());
    if (blocklistService->GetURLBlocklistState(request_url) ==
        policy::URLBlocklist::URLBlocklistState::URL_IN_BLOCKLIST) {
      return std::move(callback).Run(
          web::WebStatePolicyDecider::PolicyDecision::CancelAndDisplayError(
              policy_url_blocking_util::CreateBlockedUrlError()));
    }
  }

  // Disallow navigations to tel: URLs from cross-origin frames.
  if (request_url.SchemeIs(url::kTelScheme) &&
      request_info.target_frame_is_cross_origin) {
    return std::move(callback).Run(
        web::WebStatePolicyDecider::PolicyDecision::Cancel());
  }

  ExternalURLRequestStatus request_status =
      ExternalURLRequestStatus::kMainFrameRequestAllowed;
  // TODO(crbug.com/852489): Check if the source frame should also be
  // considered.
  if (!request_info.target_frame_is_main) {
    request_status = ExternalURLRequestStatus::kSubFrameRequestAllowed;
    // Don't allow navigations from iframe to apps if there is no user gesture
    // or the URL scheme is for Chrome app.
    if (!request_info.has_user_gesture || HasChromeAppScheme(request_url)) {
      request_status = ExternalURLRequestStatus::kSubFrameRequestBlocked;
    }
  }
  UMA_HISTOGRAM_ENUMERATION("WebController.ExternalURLRequestBlocking",
                            request_status, ExternalURLRequestStatus::kCount);
  // Request is blocked.
  if (request_status == ExternalURLRequestStatus::kSubFrameRequestBlocked) {
    return std::move(callback).Run(
        web::WebStatePolicyDecider::PolicyDecision::Cancel());
  }

  if (!IsValidAppUrl(request_url)) {
    return std::move(callback).Run(
        web::WebStatePolicyDecider::PolicyDecision::Cancel());
  }

  // If this is a Universal 2nd Factor (U2F) call, the origin needs to be
  // checked to make sure it's secure and then update the |request_url| with
  // the generated x-callback GURL based on x-callback-url specs.
  if (request_url.SchemeIs("u2f")) {
    GURL origin = web_state_->GetNavigationManager()
                      ->GetLastCommittedItem()
                      ->GetURL()
                      .GetOrigin();
    U2FTabHelper* u2f_helper = U2FTabHelper::FromWebState(web_state_);
    request_url = u2f_helper->GetXCallbackUrl(request_url, origin);
    // If the URL was rejected by the U2F handler, |request_url| will be empty.
    if (!request_url.is_valid()) {
      return std::move(callback).Run(
          web::WebStatePolicyDecider::PolicyDecision::Cancel());
    }
  }

  GURL last_committed_url = web_state_->GetLastCommittedURL();
  web::NavigationItem* pending_item =
      web_state_->GetNavigationManager()->GetPendingItem();
  GURL original_pending_url =
      pending_item ? pending_item->GetOriginalRequestURL() : GURL::EmptyGURL();
  bool is_link_transition = ui::PageTransitionCoreTypeIs(
      request_info.transition_type, ui::PAGE_TRANSITION_LINK);

  ChromeBrowserState* browser_state =
      ChromeBrowserState::FromBrowserState(web_state_->GetBrowserState());

  if (!is_link_transition && original_pending_url.is_valid()) {
    // At this stage the navigation will be canceled in all cases. If this
    // was a redirection, the |source_url| may not have been reported to
    // ReadingListWebStateObserver. Report it to mark as read if needed.
    ReadingListModel* model =
        ReadingListModelFactory::GetForBrowserState(browser_state);
    if (model && model->loaded())
      model->SetReadStatus(original_pending_url, true);
  }
  if (last_committed_url.is_valid() ||
      !web_state_->GetNavigationManager()->GetLastCommittedItem()) {
    // Launch the app if the URL is valid or if it is the first page of the
    // tab.
    RequestToLaunchApp(request_url, last_committed_url, is_link_transition);
  }
  std::move(callback).Run(web::WebStatePolicyDecider::PolicyDecision::Cancel());
}

WEB_STATE_USER_DATA_KEY_IMPL(AppLauncherTabHelper)
