// Copyright 2023 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/recent_tabs/synced_sessions_util.h"

#import "ios/chrome/browser/url_loading/url_loading_browser_agent.h"
#import "ios/chrome/browser/url_loading/url_loading_params.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

void OpenDistantTabsInBackground(const synced_sessions::DistantTabVector& tabs,
                                 bool in_incognito,
                                 UrlLoadingBrowserAgent* url_loader,
                                 UrlLoadStrategy load_strategy) {
  for (auto const& tab : tabs) {
    UrlLoadParams params = UrlLoadParams::InNewTab(tab->virtual_url);
    params.SetInBackground(YES);
    params.web_params.transition_type = ui::PAGE_TRANSITION_AUTO_BOOKMARK;
    params.load_strategy = load_strategy;
    params.in_incognito = in_incognito;
    url_loader->Load(params);
  }
}
