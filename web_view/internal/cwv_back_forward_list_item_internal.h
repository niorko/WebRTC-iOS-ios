// Copyright 2019 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_WEB_VIEW_INTERNAL_CWV_BACK_FORWARD_LIST_ITEM_INTERNAL_H_
#define IOS_WEB_VIEW_INTERNAL_CWV_BACK_FORWARD_LIST_ITEM_INTERNAL_H_

#import "ios/web_view/public/cwv_back_forward_list_item.h"

NS_ASSUME_NONNULL_BEGIN

namespace web {
class NavigationItem;
}  // namespace web

@interface CWVBackForwardListItem ()

// An unique ID generated by lower level |web::NavigationItem::GetUniqueID()|.
@property(nonatomic, readonly) int uniqueID;

- (instancetype)initWithNavigationItem:
    (const web::NavigationItem*)navigationItem NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END

#endif  // IOS_WEB_VIEW_INTERNAL_CWV_BACK_FORWARD_LIST_ITEM_INTERNAL_H_
