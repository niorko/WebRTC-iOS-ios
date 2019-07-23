// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_SEARCH_ENGINES_SEARCH_ENGINE_TAB_HELPER_H_
#define IOS_CHROME_BROWSER_SEARCH_ENGINES_SEARCH_ENGINE_TAB_HELPER_H_

#include "base/macros.h"
#include "base/scoped_observer.h"
#include "components/favicon/ios/web_favicon_driver.h"
#import "ios/web/public/web_state/web_state_observer.h"
#import "ios/web/public/web_state/web_state_user_data.h"

namespace web {
class WebState;
}  // namespace web

// Creates TemplateURLs from attached WebState and adds them to
// TemplateURLService. To create a TemplateURL, 3 basic elements are needed:
//   1. A short name (e.g. "Google");
//   2. A keyword (e.g. "google.com");
//   3. A searchable URL (e.g. "https://google.com?name=a&q={searchTerms}").
//
// Both short name and keyword can be generated from navigation history. For
// searchable URL, there are 2 methods to create it:
//   1. If a OSDD(Open Search Description Document) <link> is found in page,
//      use TemplateURLFetcher to download the XML file, parse it and get the
//      searchable URL;
//   2. If a <form> is submitted in page, a searchable URL can be generated
//      by analysing the <form>'s elements and concatenating "name" and
//      "value" attributes of them.
//
// Both these 2 methods depends on injected JavaScript.
//
class SearchEngineTabHelper
    : public web::WebStateObserver,
      public web::WebStateUserData<SearchEngineTabHelper>,
      public favicon::FaviconDriverObserver {
 public:
  ~SearchEngineTabHelper() override;

 private:
  friend class web::WebStateUserData<SearchEngineTabHelper>;

  explicit SearchEngineTabHelper(web::WebState* web_state);

  // Adds a TemplateURL by downloading and parsing the OSDD.
  void AddTemplateURLByOSDD(const GURL& page_url, const GURL& osdd_url);

  // Adds a TemplateURL by |searchable_url|.
  void AddTemplateURLBySearchableURL(const GURL& searchable_url);

  // WebStateObserver implementation.
  void DidFinishNavigation(web::WebState* web_state,
                           web::NavigationContext* navigation_context) override;
  void WebStateDestroyed(web::WebState* web_state) override;

  // Handles messages from JavaScript. Messages can be:
  //   1. A OSDD <link> is found;
  //   2. A searchable URL is generated from <form> submission.
  void OnJsMessage(const base::DictionaryValue& message,
                   const GURL& page_url,
                   bool user_is_interacting,
                   web::WebFrame* sender_frame);

  // favicon::FaviconDriverObserver implementation.
  void OnFaviconUpdated(favicon::FaviconDriver* driver,
                        NotificationIconType notification_icon_type,
                        const GURL& icon_url,
                        bool icon_url_changed,
                        const gfx::Image& image) override;

  // Manages observation relationship between |this| and WebFaviconDriver.
  ScopedObserver<favicon::WebFaviconDriver, favicon::FaviconDriverObserver>
      favicon_driver_observer_{this};

  // WebState this tab helper is attached to.
  web::WebState* web_state_ = nullptr;

  // The searchable URL generated from <form> submission. This ivar is an empty
  // GURL by default. If a web page has a searchable <form>, a searchable URL is
  // generated by JavaScript when the <form> is submitted, and stored in this
  // ivar. When the navigation triggered by the <form> submission finishes
  // successfully, this ivar will be used to add a new TemplateURL and then it
  // will be set to empty GURL again.
  GURL searchable_url_;

  // Subscription for JS message.
  std::unique_ptr<web::WebState::ScriptCommandSubscription> subscription_;

  WEB_STATE_USER_DATA_KEY_DECL();

  DISALLOW_COPY_AND_ASSIGN(SearchEngineTabHelper);
};

#endif  // IOS_CHROME_BROWSER_SEARCH_ENGINES_SEARCH_ENGINE_TAB_HELPER_H_
