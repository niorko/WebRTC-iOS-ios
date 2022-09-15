// Copyright 2022 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_POST_RESTORE_SIGNIN_POST_RESTORE_SIGNIN_PROVIDER_H_
#define IOS_CHROME_BROWSER_UI_POST_RESTORE_SIGNIN_POST_RESTORE_SIGNIN_PROVIDER_H_

#import "ios/chrome/browser/ui/promos_manager/bannered_promo_view_provider.h"

// Provider for displaying the Post Restore Sign-in Promo.
//
// The Post Restore Sign-in promo comes in two variations: (1) A fullscreen,
// FRE-like promo, and (2) a native iOS alert promo. This handler provides the
// necessary data and functionality to power both variations of this promo.
@interface PostRestoreSignInProvider : NSObject <BanneredPromoViewProvider>
@end

#endif  // IOS_CHROME_BROWSER_UI_POST_RESTORE_SIGNIN_POST_RESTORE_SIGNIN_PROVIDER_H_
