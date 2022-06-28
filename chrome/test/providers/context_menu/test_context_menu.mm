// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/public/provider/chrome/browser/context_menu/context_menu_api.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace ios {
namespace provider {

bool AddContextMenuElements(NSMutableArray<UIMenuElement*>* menu_elements,
                            ChromeBrowserState* browser_state,
                            web::WebState* web_state,
                            web::ContextMenuParams params,
                            UIViewController* presenting_view_controller) {
  // No context menu elements added for tests.
  return false;
}

ElementsToAddToContextMenu* GetContextMenuElementsToAdd(
    ChromeBrowserState* browser_state,
    web::WebState* web_state,
    web::ContextMenuParams params,
    UIViewController* presenting_view_controller) {
  return nil;
}
}  // namespace provider
}  // namespace ios
