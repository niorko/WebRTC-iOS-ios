// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_NTP_FEED_CONTROL_DELEGATE_H_
#define IOS_CHROME_BROWSER_UI_NTP_FEED_CONTROL_DELEGATE_H_

#import "ios/chrome/browser/discover_feed/feed_constants.h"

// Delegate for controlling the presented feed.
@protocol FeedControlDelegate

// Returns the currently selected feed.
- (FeedType)selectedFeed;

// Handles operations after a new feed has been selected. e.g. Displays the
// feed, updates states, etc.
- (void)handleFeedSelected:(FeedType)feedType;

// Handles the sorting being selected for the Following feed.
- (void)handleSortTypeForFollowingFeed:(FollowingFeedSortType)sortType;

// Determines whether the feed should be shown based on the user prefs.
- (BOOL)shouldFeedBeVisible;

// YES if the Following Feed is currently available. e.g. It might be disabled
// for certain circumstances like restricted accounts.
- (BOOL)isFollowingFeedAvailable;

@end

#endif  // IOS_CHROME_BROWSER_UI_NTP_FEED_CONTROL_DELEGATE_H_
