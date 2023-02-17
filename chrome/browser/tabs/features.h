// Copyright 2022 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_TABS_FEATURES_H_
#define IOS_CHROME_BROWSER_TABS_FEATURES_H_

#import "base/feature_list.h"

// Feature flags that enables Pinned Tabs.
BASE_DECLARE_FEATURE(kEnablePinnedTabs);
BASE_DECLARE_FEATURE(kEnablePinnedTabsIpad);

// Feature parameter for Pinned Tabs.
extern const char kEnablePinnedTabsOverflowParam[];

// Convenience method for determining if Pinned Tabs is enabled.
bool IsPinnedTabsEnabled();

// Convenience method for determining if Pinned Tabs for the overflow menu is
// enabled.
bool IsPinnedTabsOverflowEnabled();

#endif  // IOS_CHROME_BROWSER_TABS_FEATURES_H_
