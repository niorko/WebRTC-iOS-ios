// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_AUTHENTICATION_CELLS_SIGNIN_PROMO_VIEW_CONSTANTS_H_
#define IOS_CHROME_BROWSER_UI_AUTHENTICATION_CELLS_SIGNIN_PROMO_VIEW_CONSTANTS_H_

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, IdentityPromoViewMode) {
  // No identity available on the device.
  IdentityPromoViewModeNoAccounts,
  // At least one identity is available on the device and the user can sign in
  // without entering their credentials.
  IdentityPromoViewModeSigninWithAccount,
  // The user is signed in to Chrome and can enable Sync on the primary account.
  IdentityPromoViewModeSyncWithPrimaryAccount,
};

extern NSString* const kSigninPromoViewId;
extern NSString* const kSigninPromoPrimaryButtonId;
extern NSString* const kSigninPromoSecondaryButtonId;
extern NSString* const kSigninPromoCloseButtonId;

#endif  // IOS_CHROME_BROWSER_UI_AUTHENTICATION_CELLS_SIGNIN_PROMO_VIEW_CONSTANTS_H_
