// Copyright 2023 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_SETTINGS_PASSWORD_PASSWORD_MANAGER_VIEW_CONTROLLER_ITEMS_H_
#define IOS_CHROME_BROWSER_UI_SETTINGS_PASSWORD_PASSWORD_MANAGER_VIEW_CONTROLLER_ITEMS_H_

#import "ios/chrome/browser/ui/table_view/cells/table_view_cell.h"
#import "ios/chrome/browser/ui/table_view/cells/table_view_item.h"

@protocol TableViewFaviconDataSource;

namespace password_manager {
class AffiliatedGroup;
struct CredentialUIEntry;
}  // namespace password_manager

// Used to record favicon impression metrics.
typedef NS_ENUM(NSInteger, FaviconType) {
  FaviconTypeNotLoaded = 0,
  FaviconTypeMonogram = 1,
  FaviconTypeImage = 2,
};

// Represents a group of credentials corresponding to the same overall
// application (though possibly with different URLs, e.g. desktop vs mobile).
@interface AffiliatedGroupTableViewItem : TableViewItem

@property(nonatomic, assign) password_manager::AffiliatedGroup affiliatedGroup;

@property(nonatomic, strong, readonly) NSString* title;

@property(nonatomic, strong, readonly) NSString* detailText;

@end

// TODO(crbug.com/1359392): Once kPasswordsGrouping launches, this will only
// serve for blocked websites. Rename, DCHECK blocked_by_user, drop detailText.
//
// Represents either:
// - A single saved password (pre kPasswordsGrouping launch).
// - A website where the user blocked saving passwords.
@interface CredentialTableViewItem : TableViewItem

@property(nonatomic, assign) password_manager::CredentialUIEntry credential;

@property(nonatomic, strong, readonly) NSString* title;

@property(nonatomic, strong, readonly) NSString* detailText;

@end

// Common cell for AffiliatedGroupTableViewItem and CredentialTableViewItem.
//  ________________________________
// |  [favicon or]  Title           |
// |  [monogram  ]  Optional text   |
//  ________________________________
@interface PasswordFormContentCell : TableViewCell

@property(nonatomic, assign, readonly) FaviconType faviconTypeForMetrics;

// Asynchronously loads and displays the favicon for the item that configured
// this cell. If by the time the favicon arrives, another item with a different
// URL is trying to reuse this cell, this is a no-op.
- (void)loadFavicon:(id<TableViewFaviconDataSource>)faviconDataSource;

@end

#endif  // IOS_CHROME_BROWSER_UI_SETTINGS_PASSWORD_PASSWORD_MANAGER_VIEW_CONTROLLER_ITEMS_H_
