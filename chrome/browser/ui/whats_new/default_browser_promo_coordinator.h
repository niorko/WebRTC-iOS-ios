// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_WHATS_NEW_DEFAULT_BROWSER_PROMO_COORDINATOR_H_
#define IOS_CHROME_BROWSER_UI_WHATS_NEW_DEFAULT_BROWSER_PROMO_COORDINATOR_H_

#import "ios/chrome/browser/ui/coordinators/chrome_coordinator.h"

#import "ios/chrome/browser/ui/whats_new/default_browser_promo_commands.h"

@interface DefaultBrowserPromoCoordinator : ChromeCoordinator
// Handler for all actions of this coordinator.
@property(nonatomic, weak) id<DefaultBrowserPromoCommands> handler;
@end

#endif  // IOS_CHROME_BROWSER_UI_WHATS_NEW_DEFAULT_BROWSER_PROMO_COORDINATOR_H_
