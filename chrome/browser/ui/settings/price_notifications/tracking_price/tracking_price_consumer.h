// Copyright 2022 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_SETTINGS_PRICE_NOTIFICATIONS_TRACKING_PRICE_TRACKING_PRICE_CONSUMER_H_
#define IOS_CHROME_BROWSER_UI_SETTINGS_PRICE_NOTIFICATIONS_TRACKING_PRICE_TRACKING_PRICE_CONSUMER_H_

#import <UIKit/UIKit.h>

#import "ios/chrome/browser/ui/table_view/chrome_table_view_consumer.h"

@class TableViewHeaderFooterItem;
@class TableViewItem;

// Consumer protocol for Tracking Price settings menu.
@protocol TrackingPriceConsumer <ChromeTableViewConsumer>

// Initializes `mobileNotificationItem`.
- (void)setMobileNotificationItem:(TableViewItem*)mobileNotificationItem;

// Initializes `trackPriceHeaderItem`.
- (void)setTrackPriceHeaderItem:
    (TableViewHeaderFooterItem*)trackPriceHeaderItem;

@end

#endif  // IOS_CHROME_BROWSER_UI_SETTINGS_PRICE_NOTIFICATIONS_TRACKING_PRICE_TRACKING_PRICE_CONSUMER_H_
