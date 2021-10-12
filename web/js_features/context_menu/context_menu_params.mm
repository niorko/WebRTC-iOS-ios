// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/web/public/ui/context_menu_params.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace web {

ContextMenuParams::ContextMenuParams()
    : is_main_frame(true),
      referrer_policy(ReferrerPolicyDefault),
      location(CGPointZero) {}

ContextMenuParams::ContextMenuParams(const ContextMenuParams& other) = default;

ContextMenuParams& ContextMenuParams::operator=(
    const ContextMenuParams& other) = default;

ContextMenuParams::ContextMenuParams(ContextMenuParams&& other) = default;

ContextMenuParams& ContextMenuParams::operator=(ContextMenuParams&& other) =
    default;

ContextMenuParams::~ContextMenuParams() {}

}  // namespace web
