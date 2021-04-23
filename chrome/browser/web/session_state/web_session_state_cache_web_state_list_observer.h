// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_WEB_SESSION_STATE_WEB_SESSION_STATE_CACHE_WEB_STATE_LIST_OBSERVER_H_
#define IOS_CHROME_BROWSER_WEB_SESSION_STATE_WEB_SESSION_STATE_CACHE_WEB_STATE_LIST_OBSERVER_H_

#include "base/macros.h"
#import "ios/chrome/browser/web_state_list/web_state_list_observer.h"

@class WebSessionStateCache;

// Updates the WebSessionStateCache when the active tab changes or when
// batch operations occur.
class WebSessionStateCacheWebStateListObserver : public WebStateListObserver {
 public:
  explicit WebSessionStateCacheWebStateListObserver(
      WebSessionStateCache* web_session_state_cache);
  ~WebSessionStateCacheWebStateListObserver() override;

 private:
  // WebStateListObserver implementation.
  void WillCloseWebStateAt(WebStateList* web_state_list,
                           web::WebState* web_state,
                           int index,
                           bool user_action) override;
  void WebStateReplacedAt(WebStateList* web_state_list,
                          web::WebState* old_web_state,
                          web::WebState* new_web_state,
                          int index) override;
  void WillBeginBatchOperation(WebStateList* web_state_list) override;
  void BatchOperationEnded(WebStateList* web_state_list) override;
  WebSessionStateCache* web_session_state_cache_;

  DISALLOW_COPY_AND_ASSIGN(WebSessionStateCacheWebStateListObserver);
};

#endif  // IOS_CHROME_BROWSER_WEB_SESSION_STATE_WEB_SESSION_STATE_CACHE_WEB_STATE_LIST_OBSERVER_H_
