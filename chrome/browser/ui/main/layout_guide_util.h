// Copyright 2022 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_MAIN_LAYOUT_GUIDE_UTIL_H_
#define IOS_CHROME_BROWSER_UI_MAIN_LAYOUT_GUIDE_UTIL_H_

class Browser;
@class LayoutGuideCenter;

// Returns the layout guide center assigned to the given `browser`.
LayoutGuideCenter* LayoutGuideCenterForBrowser(Browser* browser);

#endif  // IOS_CHROME_BROWSER_UI_MAIN_LAYOUT_GUIDE_UTIL_H_
