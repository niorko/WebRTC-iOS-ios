// Copyright 2022 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/power_bookmarks/power_bookmark_service_factory.h"

#import "components/keyed_service/ios/browser_state_dependency_manager.h"
#import "components/power_bookmarks/core/power_bookmark_service.h"
#import "ios/chrome/browser/bookmarks/bookmark_model_factory.h"
#import "ios/chrome/browser/browser_state/browser_state_otr_helper.h"
#import "ios/chrome/browser/browser_state/chrome_browser_state.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

// static
power_bookmarks::PowerBookmarkService*
PowerBookmarkServiceFactory::GetForBrowserState(web::BrowserState* state) {
  return static_cast<power_bookmarks::PowerBookmarkService*>(
      GetInstance()->GetServiceForBrowserState(state, true));
}

// static
PowerBookmarkServiceFactory* PowerBookmarkServiceFactory::GetInstance() {
  return base::Singleton<PowerBookmarkServiceFactory>::get();
}

PowerBookmarkServiceFactory::PowerBookmarkServiceFactory()
    : BrowserStateKeyedServiceFactory(
          "PowerBookmarkService",
          BrowserStateDependencyManager::GetInstance()) {
  DependsOn(ios::BookmarkModelFactory::GetInstance());
}

PowerBookmarkServiceFactory::~PowerBookmarkServiceFactory() = default;

std::unique_ptr<KeyedService>
PowerBookmarkServiceFactory::BuildServiceInstanceFor(
    web::BrowserState* state) const {
  ChromeBrowserState* chrome_state =
      ChromeBrowserState::FromBrowserState(state);
  return std::make_unique<power_bookmarks::PowerBookmarkService>(
      ios::BookmarkModelFactory::GetInstance()->GetForBrowserState(
          chrome_state));
}

web::BrowserState* PowerBookmarkServiceFactory::GetBrowserStateToUse(
    web::BrowserState* state) const {
  return GetBrowserStateRedirectedInIncognito(state);
}

bool PowerBookmarkServiceFactory::ServiceIsCreatedWithBrowserState() const {
  return true;
}

bool PowerBookmarkServiceFactory::ServiceIsNULLWhileTesting() const {
  return true;
}
