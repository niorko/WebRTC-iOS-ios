// Copyright 2020 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_CONTENT_SUGGESTIONS_CONTENT_SUGGESTIONS_FEATURE_H_
#define IOS_CHROME_BROWSER_UI_CONTENT_SUGGESTIONS_CONTENT_SUGGESTIONS_FEATURE_H_

#include "base/feature_list.h"

// Feature to choose between the old Zine feed or the new Discover feed in the
// Bling new tab page.
// Use IsDiscoverFeedEnabled() instead of this constant directly.
// TODO(crbug.com/1385512): Remove this.
BASE_DECLARE_FEATURE(kDiscoverFeedInNtp);

// Feature to use one NTP for all tabs in a Browser.
BASE_DECLARE_FEATURE(kSingleNtp);

// Feature for the Magic Stack.
BASE_DECLARE_FEATURE(kMagicStack);

// A parameter to indicate whether the native UI is enabled for the discover
// feed.
// TODO(crbug.com/1385512): Remove this.
extern const char kDiscoverFeedIsNativeUIEnabled[];

// Whether the Discover feed is enabled instead of the Zine feed.
// TODO(crbug.com/1385512): Remove this.
bool IsDiscoverFeedEnabled();

// Whether the Magic Stack should be shown.
bool IsMagicStackEnabled();

#endif  // IOS_CHROME_BROWSER_UI_CONTENT_SUGGESTIONS_CONTENT_SUGGESTIONS_FEATURE_H_
