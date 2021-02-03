// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_START_SURFACE_START_SURFACE_FEATURES_H_
#define IOS_CHROME_BROWSER_UI_START_SURFACE_START_SURFACE_FEATURES_H_

#include "base/feature_list.h"

// The feature to enable or disable the Start Surface.
extern const base::Feature kStartSurface;

bool IsStartSurfaceEnabled();

#endif  // IOS_CHROME_BROWSER_UI_START_SURFACE_START_SURFACE_FEATURES_H_.
