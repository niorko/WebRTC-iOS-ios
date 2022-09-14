// Copyright 2019 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/web_state_list/tab_insertion_browser_agent.h"

#import "components/url_param_filter/core/features.h"
#import "components/url_param_filter/core/url_param_filterer.h"
#import "components/url_param_filter/ios/cross_otr_tab_helper.h"
#import "ios/chrome/browser/browser_state/chrome_browser_state.h"
#import "ios/chrome/browser/ntp/new_tab_page_tab_helper.h"
#import "ios/chrome/browser/web_state_list/web_state_list.h"
#import "ios/chrome/browser/web_state_list/web_state_opener.h"
#import "ios/web/public/web_state.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

BROWSER_USER_DATA_KEY_IMPL(TabInsertionBrowserAgent)

TabInsertionBrowserAgent::TabInsertionBrowserAgent(Browser* browser)
    : browser_state_(browser->GetBrowserState()),
      web_state_list_(browser->GetWebStateList()) {}

TabInsertionBrowserAgent::~TabInsertionBrowserAgent() {}

web::WebState* TabInsertionBrowserAgent::InsertWebState(
    const web::NavigationManager::WebLoadParams& params,
    web::WebState* parent,
    bool opened_by_dom,
    int index,
    bool in_background,
    bool inherit_opener,
    bool should_show_start_surface,
    const url_param_filter::FilterResult& filtering_result) {
  DCHECK(index == TabInsertion::kPositionAutomatically ||
         (index >= 0 && index <= web_state_list_->count()));

  int insertion_index = WebStateList::kInvalidIndex;
  int insertion_flags = WebStateList::INSERT_NO_FLAGS;
  if (index != TabInsertion::kPositionAutomatically) {
    DCHECK_LE(index, INT_MAX);
    insertion_index = static_cast<int>(index);
    insertion_flags |= WebStateList::INSERT_FORCE_INDEX;
  } else if (!ui::PageTransitionCoreTypeIs(params.transition_type,
                                           ui::PAGE_TRANSITION_LINK)) {
    insertion_index = web_state_list_->count();
    insertion_flags |= WebStateList::INSERT_FORCE_INDEX;
  }

  if (!in_background) {
    insertion_flags |= WebStateList::INSERT_ACTIVATE;
  }

  if (inherit_opener) {
    insertion_flags |= WebStateList::INSERT_INHERIT_OPENER;
  }

  web::WebState::CreateParams create_params(browser_state_);
  create_params.created_with_opener = opened_by_dom;

  std::unique_ptr<web::WebState> web_state =
      web::WebState::Create(create_params);
  if (should_show_start_surface) {
    NewTabPageTabHelper::CreateForWebState(web_state.get());
    NewTabPageTabHelper::FromWebState(web_state.get())
        ->SetShowStartSurface(true);
  }

  if (base::FeatureList::IsEnabled(
          url_param_filter::features::kIncognitoParamFilterEnabled) &&
      web_state->GetBrowserState()->IsOffTheRecord() && !parent &&
      filtering_result.filtered_param_count > 0) {
    // Only attach the CrossOtrTabHelper to OTR web_state if parent is null,
    // as this indicates that it's the result of a "Open In Incognito" press.
    url_param_filter::CrossOtrTabHelper::CreateForWebState(web_state.get());
    auto* observer =
        url_param_filter::CrossOtrTabHelper::FromWebState(web_state.get());
    observer->SetExperimentalStatus(filtering_result.experimental_status);
  }

  web_state->GetNavigationManager()->LoadURLWithParams(params);

  int inserted_index =
      web_state_list_->InsertWebState(insertion_index, std::move(web_state),
                                      insertion_flags, WebStateOpener(parent));

  return web_state_list_->GetWebStateAt(inserted_index);
}

web::WebState* TabInsertionBrowserAgent::InsertWebStateOpenedByDOM(
    web::WebState* parent) {
  web::WebState::CreateParams createParams(browser_state_);
  createParams.created_with_opener = YES;
  std::unique_ptr<web::WebState> web_state =
      web::WebState::Create(createParams);
  int insertionFlags =
      WebStateList::INSERT_FORCE_INDEX | WebStateList::INSERT_ACTIVATE;
  int insertedIndex = web_state_list_->InsertWebState(
      web_state_list_->count(), std::move(web_state), insertionFlags,
      WebStateOpener(parent));

  return web_state_list_->GetWebStateAt(insertedIndex);
}
