// Copyright 2023 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_DISCOVER_FEED_DISCOVER_FEED_REFRESHER_H_
#define IOS_CHROME_BROWSER_DISCOVER_FEED_DISCOVER_FEED_REFRESHER_H_

enum class FeedRefreshTrigger;

// An interface to refresh the Discover Feed.
class DiscoverFeedRefresher {
 public:
  // Refreshes the Discover Feed if needed. The implementer decides if a refresh
  // is needed or not. This should only be called when the feed is visible to
  // the user.
  // Deprecated.
  virtual void RefreshFeedIfNeeded() {}

  // Refreshes the Discover Feed. `trigger` describes the context of the
  // refresh.
  virtual void RefreshFeed(FeedRefreshTrigger trigger) = 0;
};

#endif  // IOS_CHROME_BROWSER_DISCOVER_FEED_DISCOVER_FEED_REFRESHER_H_
