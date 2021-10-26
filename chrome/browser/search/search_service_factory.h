// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_SEARCH_SEARCH_SERVICE_FACTORY_H_
#define IOS_CHROME_BROWSER_SEARCH_SEARCH_SERVICE_FACTORY_H_

#include "base/no_destructor.h"
#include "components/keyed_service/ios/browser_state_keyed_service_factory.h"

class ChromeBrowserState;
class SearchService;

// Singleton that owns all SearchServices and associates them with
// ChromeBrowserState.
class SearchServiceFactory : public BrowserStateKeyedServiceFactory {
 public:
  SearchServiceFactory(const SearchServiceFactory&) = delete;
  SearchServiceFactory& operator=(const SearchServiceFactory&) = delete;

  static SearchService* GetForBrowserState(ChromeBrowserState* browser_state);
  static SearchServiceFactory* GetInstance();

 private:
  friend class base::NoDestructor<SearchServiceFactory>;

  SearchServiceFactory();
  ~SearchServiceFactory() override;

  // BrowserStateKeyedServiceFactory:
  std::unique_ptr<KeyedService> BuildServiceInstanceFor(
      web::BrowserState* context) const override;
  web::BrowserState* GetBrowserStateToUse(
      web::BrowserState* context) const override;
};

#endif  // IOS_CHROME_BROWSER_SEARCH_SEARCH_SERVICE_FACTORY_H_
