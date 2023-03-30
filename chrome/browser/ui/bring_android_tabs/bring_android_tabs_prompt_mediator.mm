// Copyright 2023 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/bring_android_tabs/bring_android_tabs_prompt_mediator.h"

#import "base/metrics/histogram_functions.h"
#import "ios/chrome/browser/bring_android_tabs/bring_android_tabs_to_ios_service.h"
#import "ios/chrome/browser/bring_android_tabs/metrics.h"
#import "ios/chrome/browser/synced_sessions/synced_sessions_util.h"
#import "ios/chrome/browser/url_loading/url_loading_browser_agent.h"
#import "ios/chrome/browser/url_loading/url_loading_params.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@implementation BringAndroidTabsPromptMediator {
  // Keyed service to retrieve active tabs from Android.
  BringAndroidTabsToIOSService* _bringAndroidTabsService;
  // URL loader to open tabs when needed.
  UrlLoadingBrowserAgent* _URLLoader;
  // Number of tabs active tabs from Android brought over.
  size_t _tabCount;
  // Whether the prompt view controller had been shown.
  BOOL _promptShown;
}

- (instancetype)
    initWithBringAndroidTabsService:(BringAndroidTabsToIOSService*)service
                          URLLoader:(UrlLoadingBrowserAgent*)URLLoader {
  DCHECK(service != nil);
  self = [super init];
  if (self) {
    _bringAndroidTabsService = service;
    _URLLoader = URLLoader;
    _tabCount = service->GetNumberOfAndroidTabs();
    _promptShown = NO;
  }
  return self;
}

#pragma mark - BringAndroidTabsPromptViewControllerDelegate

- (void)bringAndroidTabsPromptViewControllerDidShow {
  if (!_promptShown) {
    base::UmaHistogramCounts1000(bring_android_tabs::kTabCountHistogramName,
                                 _tabCount);
    _bringAndroidTabsService->OnBringAndroidTabsPromptDisplayed();
  }
  _promptShown = YES;
}

- (void)bringAndroidTabsPromptViewControllerDidTapOpenAllButton {
  [self onPromptDisappear:bring_android_tabs::PromptActionType::kOpenTabs];
  for (size_t idx = 0; idx < _tabCount; idx++) {
    OpenDistantTabInBackground(_bringAndroidTabsService->GetTabAtIndex(idx), NO,
                               _URLLoader, UrlLoadStrategy::NORMAL);
  }
}

- (void)bringAndroidTabsPromptViewControllerDidTapReviewButton {
  [self onPromptDisappear:bring_android_tabs::PromptActionType::kReviewTabs];
}

- (void)bringAndroidTabsPromptViewControllerDidDismiss:(BOOL)swiped {
  [self onPromptDisappear:
            swiped ? bring_android_tabs::PromptActionType::kSwipeToDismiss
                   : bring_android_tabs::PromptActionType::kCancel];
}

#pragma mark - Private

// Helper method that takes the user's interaction with the prompt as
// `actionType` and logs a respective metric and notifies Chromium that the
// prompt has disappeared.
- (void)onPromptDisappear:(bring_android_tabs::PromptActionType)actionType {
  base::UmaHistogramEnumeration(bring_android_tabs::kPromptActionHistogramName,
                                actionType);
  _bringAndroidTabsService->OnUserInteractWithBringAndroidTabsPrompt();
}

@end
