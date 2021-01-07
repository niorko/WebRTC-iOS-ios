// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_WEB_COMMON_UIKIT_UI_UTIL_H_
#define IOS_WEB_COMMON_UIKIT_UI_UTIL_H_

#import <UIKit/UIKit.h>

// Returns current keyWindow, from the list of all of this application windows.
// Use only if the context of which window doesn't matter.
UIWindow* GetAnyKeyWindow();

#endif  // IOS_WEB_COMMON_UIKIT_UI_UTIL_H_
