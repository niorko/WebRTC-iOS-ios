// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/itunes_urls/itunes_urls_handler_tab_helper.h"

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

#include <vector>

#include "base/check.h"
#include "base/metrics/histogram_macros.h"
#include "base/metrics/user_metrics.h"
#include "base/metrics/user_metrics_action.h"
#include "base/strings/string_split.h"
#include "base/strings/sys_string_conversions.h"
#import "ios/chrome/browser/store_kit/store_kit_tab_helper.h"
#include "ios/web/public/browser_state.h"
#import "ios/web/public/navigation/navigation_item.h"
#import "ios/web/public/navigation/navigation_manager.h"
#import "ios/web/public/navigation/web_state_policy_decider.h"
#import "net/base/mac/url_conversions.h"
#include "net/base/url_util.h"
#include "url/gurl.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

// The hosts for iTunes appstore URLs (Legacy itunes link maker links).
const char kLegacyITunesUrlHost[] = "itunes.apple.com";
const char kLegacyITunesGlobalUrlHost[] = "geo.itunes.apple.com";

// The host for iOS applications URLs generated by itunes link maker.
const char kAppUrlHost[] = "apps.apple.com";

const char kITunesProductIdPrefix[] = "id";
const char kITunesAppPathIdentifier[] = "app";
const size_t kITunesUrlPathMinComponentsCount = 2;
const size_t kITunesUrlRegionComponentDefaultIndex = 0;
const size_t kITunesUrlMediaTypeComponentDefaultIndex = 1;

// Records the StoreKit handling result to IOS.StoreKit.ITunesURLsHandlingResult
// UMA histogram.
void RecordStoreKitHandlingResult(ITunesUrlsStoreKitHandlingResult result) {
  UMA_HISTOGRAM_ENUMERATION("IOS.StoreKit.ITunesURLsHandlingResult", result,
                            ITunesUrlsStoreKitHandlingResult::kCount);
}

// Returns true, it the given `url` is iTunes product URL.
// iTunes URL should start with apple host and has product id.
bool IsITunesProductUrl(const GURL& url) {
  if (!url.SchemeIsHTTPOrHTTPS() ||
      !(strcmp(url.host().c_str(), kLegacyITunesUrlHost) == 0 ||
        strcmp(url.host().c_str(), kLegacyITunesGlobalUrlHost) == 0 ||
        strcmp(url.host().c_str(), kAppUrlHost) == 0))
    return false;

  std::string file_name = url.ExtractFileName();
  // The first `kITunesProductIdLength` characters must be
  // `kITunesProductIdPrefix`, followed by the app ID.
  return base::StartsWith(file_name, kITunesProductIdPrefix);
}

// Extracts iTunes product parameters from the given `url` to be used with the
// StoreKit launcher.
NSDictionary* ExtractITunesProductParameters(const GURL& url) {
  NSMutableDictionary<NSString*, NSString*>* params_dictionary =
      [[NSMutableDictionary alloc] init];
  std::string product_id =
      url.ExtractFileName().substr(strlen(kITunesProductIdPrefix));
  params_dictionary[SKStoreProductParameterITunesItemIdentifier] =
      base::SysUTF8ToNSString(product_id);
  for (net::QueryIterator it(url); !it.IsAtEnd(); it.Advance()) {
    params_dictionary[base::SysUTF8ToNSString(it.GetKey())] =
        base::SysUTF8ToNSString(it.GetValue());
  }
  return params_dictionary;
}

}  // namespace

ITunesUrlsHandlerTabHelper::~ITunesUrlsHandlerTabHelper() = default;

ITunesUrlsHandlerTabHelper::ITunesUrlsHandlerTabHelper(web::WebState* web_state)
    : web::WebStatePolicyDecider(web_state) {}

// static
bool ITunesUrlsHandlerTabHelper::CanHandleUrl(const GURL& url) {
  if (!IsITunesProductUrl(url))
    return false;
  // Valid iTunes URL structure:
  // HOST/OPTIONAL_REGION_CODE/MEDIA_TYPE/OPTIONAL_MEDIA_NAME/ID?PARAMETERS
  // Check the URL media type, to determine if it is supported.
  std::vector<std::string> path_components = base::SplitString(
      url.path(), "/", base::KEEP_WHITESPACE, base::SPLIT_WANT_NONEMPTY);

  if (path_components.size() < kITunesUrlPathMinComponentsCount)
    return false;
  size_t media_type_index = kITunesUrlMediaTypeComponentDefaultIndex;
  DCHECK(media_type_index > 0);
  // If there is no region code in the URL then media type has to appear
  // earlier in the URL.
  if (path_components[kITunesUrlRegionComponentDefaultIndex].size() != 2)
    media_type_index--;
  return path_components[media_type_index] == kITunesAppPathIdentifier;
}

void ITunesUrlsHandlerTabHelper::ShouldAllowRequest(
    NSURLRequest* request,
    web::WebStatePolicyDecider::RequestInfo request_info,
    web::WebStatePolicyDecider::PolicyDecisionCallback callback) {
  // Don't Handle URLS in Off The record mode as this will open StoreKit with
  // Users' iTunes account. Also don't Handle navigations in iframe because they
  // may be spam, and they will be handled by other policy deciders.
  if (web_state()->GetBrowserState()->IsOffTheRecord() ||
      !request_info.target_frame_is_main) {
    return std::move(callback).Run(
        web::WebStatePolicyDecider::PolicyDecision::Allow());
  }

  GURL request_url = net::GURLWithNSURL(request.URL);
  if (!CanHandleUrl(request_url)) {
    return std::move(callback).Run(
        web::WebStatePolicyDecider::PolicyDecision::Allow());
  }

  HandleITunesUrl(request_url);
  std::move(callback).Run(web::WebStatePolicyDecider::PolicyDecision::Cancel());
}

// private
void ITunesUrlsHandlerTabHelper::HandleITunesUrl(const GURL& url) {
  ITunesUrlsStoreKitHandlingResult handling_result =
      ITunesUrlsStoreKitHandlingResult::kSingleAppUrlHandled;
  StoreKitTabHelper* tab_helper = StoreKitTabHelper::FromWebState(web_state());
  if (tab_helper) {
    base::RecordAction(
        base::UserMetricsAction("ITunesLinksHandler_StoreKitLaunched"));
    tab_helper->OpenAppStore(ExtractITunesProductParameters(url));
  } else {
    handling_result = ITunesUrlsStoreKitHandlingResult::kUrlHandlingFailed;
  }
  RecordStoreKitHandlingResult(handling_result);
}

WEB_STATE_USER_DATA_KEY_IMPL(ITunesUrlsHandlerTabHelper)
