// Copyright 2022 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/post_restore_signin/post_restore_signin_provider.h"

#import "base/check_op.h"
#import "base/notreached.h"
#import "base/strings/sys_string_conversions.h"
#import "components/signin/public/identity_manager/account_info.h"
#import "ios/chrome/browser/promos_manager/constants.h"
#import "ios/chrome/browser/signin/signin_util.h"
#import "ios/chrome/browser/ui/commands/show_signin_command.h"
#import "ios/chrome/browser/ui/post_restore_signin/features.h"
#import "ios/chrome/browser/ui/post_restore_signin/post_restore_signin_view_controller.h"
#import "ios/chrome/common/ui/promo_style/promo_style_view_controller.h"
#import "ios/chrome/grit/ios_strings.h"
#import "ui/base/l10n/l10n_util_mac.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@interface PostRestoreSignInProvider ()

// Returns the email address of the last account that was signed in pre-restore.
@property(readonly) NSString* userEmail;

// Returns the given name of the last account that was signed in pre-restore.
@property(readonly) NSString* userGivenName;

@end

@implementation PostRestoreSignInProvider {
  PromoStyleViewController* _viewController;
  absl::optional<AccountInfo> _accountInfo;
}

#pragma mark - Initializers

- (instancetype)init {
  if (self = [super init])
    _accountInfo = GetPreRestoreIdentity();
  return self;
}

#pragma mark - PromoProtocol

// Conditionally returns the promo identifier (promos_manager::Promo) based on
// which variation of the Post Restore Sign-in Promo is currently active.
- (promos_manager::Promo)identifier {
  post_restore_signin::features::PostRestoreSignInType promoType =
      post_restore_signin::features::CurrentPostRestoreSignInType();

  // PostRestoreSignInProvider should not exist unless the feature
  // `kIOSNewPostRestoreExperience` is enabled. Therefore, `promoType` should
  // never be `kDisabled` here.
  DCHECK_NE(promoType,
            post_restore_signin::features::PostRestoreSignInType::kDisabled);

  if (promoType ==
      post_restore_signin::features::PostRestoreSignInType::kFullscreen) {
    return promos_manager::Promo::PostRestoreSignInFullscreen;
  } else if (promoType ==
             post_restore_signin::features::PostRestoreSignInType::kAlert) {
    return promos_manager::Promo::PostRestoreSignInAlert;
  }

  // PostRestoreSignInProvider should not exist unless the feature
  // `kIOSNewPostRestoreExperience` is enabled. Therefore, this code path should
  // never be reached.
  NOTREACHED();

  // Returns the fullscreen, FRE-like promo as the default.
  return promos_manager::Promo::PostRestoreSignInFullscreen;
}

#pragma mark - StandardPromoAlertHandler

- (void)standardPromoAlertDefaultAction {
  [self showSignin];
}

- (void)standardPromoAlertCancelAction {
  // TODO(crbug.com/1363893): Implement UMA metrics.
}

#pragma mark - StandardPromoAlertProvider

- (NSString*)title {
  return l10n_util::GetNSStringF(
      IDS_IOS_POST_RESTORE_SIGN_IN_FULLSCREEN_PROMO_TITLE,
      base::SysNSStringToUTF16(self.userGivenName));
}

- (NSString*)message {
  return l10n_util::GetNSStringF(
      IDS_IOS_POST_RESTORE_SIGN_IN_ALERT_PROMO_MESSAGE,
      base::SysNSStringToUTF16(self.userEmail));
}

#pragma mark - StandardPromoViewProvider

- (PromoStyleViewController*)viewController {
  if (_viewController)
    return _viewController;

  _viewController = [[PostRestoreSignInViewController alloc]
      initWithAccountInfo:_accountInfo.value()];

  return _viewController;
}

#pragma mark - StandardPromoActionHandler

// The "Primary Action" was touched.
- (void)standardPromoPrimaryAction {
  [self.viewController dismissViewControllerAnimated:YES
                                          completion:^{
                                            [self showSignin];
                                          }];
}

// The "Dismiss" button was touched. This same dismiss handler will be used for
// two promo variations:
//
// (Variation #1) A fullscren, FRE-like promo, where the dismiss button says
// "Don't Sign In".
//
// (Variation #2) A native iOS alert promo, where the dismiss button says
// "Cancel".
//
// In both variations, the same dismiss functionality is desired.
- (void)standardPromoDismissAction {
  // TODO(crbug.com/1363893): Implement UMA metrics.
}

#pragma mark - Internal

// Returns the user's pre-restore given name.
- (NSString*)userGivenName {
  if (!_accountInfo.has_value())
    return nil;

  return base::SysUTF8ToNSString(_accountInfo->given_name);
}

// Returns the user's pre-restore email.
- (NSString*)userEmail {
  if (!_accountInfo.has_value())
    return nil;

  return base::SysUTF8ToNSString(_accountInfo->email);
}

- (void)showSignin {
  DCHECK(self.handler);

  ShowSigninCommand* command = [[ShowSigninCommand alloc]
      initWithOperation:AuthenticationOperationReauthenticate
               identity:nil
            accessPoint:signin_metrics::AccessPoint::
                            ACCESS_POINT_POST_DEVICE_RESTORE_SIGNIN_PROMO
            promoAction:signin_metrics::PromoAction::
                            PROMO_ACTION_NO_SIGNIN_PROMO
               callback:nil];
  [self.handler showSignin:command];
}

@end
