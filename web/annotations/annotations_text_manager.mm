// Copyright 2022 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/web/public/annotations/annotations_text_manager.h"
#import "ios/web/annotations/annotations_text_manager_impl.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace web {

void AnnotationsTextManager::CreateForWebState(WebState* web_state) {
  DCHECK(web_state);
  if (!FromWebState(web_state)) {
    web_state->SetUserData(
        UserDataKey(), std::make_unique<AnnotationsTextManagerImpl>(web_state));
  }
}

}  // namespace web
