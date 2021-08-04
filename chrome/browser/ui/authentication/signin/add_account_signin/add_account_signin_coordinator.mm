// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/authentication/signin/add_account_signin/add_account_signin_coordinator.h"

#import "components/signin/public/identity_manager/identity_manager.h"
#import "ios/chrome/browser/browser_state/chrome_browser_state.h"
#import "ios/chrome/browser/main/browser.h"
#import "ios/chrome/browser/signin/authentication_service.h"
#import "ios/chrome/browser/signin/authentication_service_factory.h"
#import "ios/chrome/browser/signin/identity_manager_factory.h"
#import "ios/chrome/browser/ui/alert_coordinator/alert_coordinator.h"
#import "ios/chrome/browser/ui/authentication/authentication_ui_util.h"
#import "ios/chrome/browser/ui/authentication/signin/add_account_signin/add_account_signin_manager.h"
#import "ios/chrome/browser/ui/authentication/signin/signin_coordinator+protected.h"
#import "ios/public/provider/chrome/browser/chrome_browser_provider.h"
#import "ios/public/provider/chrome/browser/signin/chrome_identity_interaction_manager.h"
#import "ios/public/provider/chrome/browser/signin/chrome_identity_service.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using signin_metrics::AccessPoint;
using signin_metrics::PromoAction;

@interface AddAccountSigninCoordinator () <AddAccountSigninManagerDelegate>

// Coordinator to display modal alerts to the user.
@property(nonatomic, strong) AlertCoordinator* alertCoordinator;
// Coordinator that handles the sign-in UI flow.
@property(nonatomic, strong) SigninCoordinator* userSigninCoordinator;
// Manager that handles sign-in add account UI.
@property(nonatomic, strong) AddAccountSigninManager* addAccountSigninManager;
// Manager that handles interactions to add identities.
@property(nonatomic, strong)
    ChromeIdentityInteractionManager* identityInteractionManager;
// View where the sign-in button was displayed.
@property(nonatomic, assign) AccessPoint accessPoint;
// Promo button used to trigger the sign-in.
@property(nonatomic, assign) PromoAction promoAction;
// Add account sign-in intent.
@property(nonatomic, assign, readonly) AddAccountSigninIntent signinIntent;

@end

@implementation AddAccountSigninCoordinator

#pragma mark - Public

- (instancetype)initWithBaseViewController:(UIViewController*)viewController
                                   browser:(Browser*)browser
                               accessPoint:(AccessPoint)accessPoint
                               promoAction:(PromoAction)promoAction
                              signinIntent:
                                  (AddAccountSigninIntent)signinIntent {
  self = [super initWithBaseViewController:viewController browser:browser];
  if (self) {
    _signinIntent = signinIntent;
    _accessPoint = accessPoint;
    _promoAction = promoAction;
  }
  return self;
}

#pragma mark - SigninCoordinator

- (void)interruptWithAction:(SigninCoordinatorInterruptAction)action
                 completion:(ProceduralBlock)completion {
  if (self.userSigninCoordinator) {
    DCHECK(!self.addAccountSigninManager);
    // When interrupting |self.userSigninCoordinator|,
    // |self.userSigninCoordinator.signinCompletion| is called. This callback
    // is in charge to call |[self runCompletionCallbackWithSigninResult:
    // completionInfo:].
    [self.userSigninCoordinator interruptWithAction:action
                                         completion:completion];
    return;
  }

  DCHECK(self.addAccountSigninManager);
  switch (action) {
    case SigninCoordinatorInterruptActionNoDismiss:
    case SigninCoordinatorInterruptActionDismissWithoutAnimation:
      [self.addAccountSigninManager interruptAddAccountAnimated:NO
                                                     completion:completion];
      break;
    case SigninCoordinatorInterruptActionDismissWithAnimation:
      [self.addAccountSigninManager interruptAddAccountAnimated:YES
                                                     completion:completion];
      break;
  }
}

#pragma mark - ChromeCoordinator

- (void)start {
  [super start];
  ChromeIdentityInteractionManager* identityInteractionManager =
      ios::GetChromeBrowserProvider()
          .GetChromeIdentityService()
          ->CreateChromeIdentityInteractionManager();

  signin::IdentityManager* identityManager =
      IdentityManagerFactory::GetForBrowserState(
          self.browser->GetBrowserState());
  self.addAccountSigninManager = [[AddAccountSigninManager alloc]
      initWithBaseViewController:self.baseViewController
      identityInteractionManager:identityInteractionManager
                     prefService:self.browser->GetBrowserState()->GetPrefs()
                 identityManager:identityManager];
  self.addAccountSigninManager.delegate = self;
  [self.addAccountSigninManager showSigninWithIntent:self.signinIntent];
}

- (void)stop {
  [super stop];
  // If one of those 3 DCHECK() fails, -[AddAccountSigninCoordinator
  // runCompletionCallbackWithSigninResult] has not been called.
  DCHECK(!self.addAccountSigninManager);
  DCHECK(!self.alertCoordinator);
  DCHECK(!self.userSigninCoordinator);
}

#pragma mark - AddAccountSigninManagerDelegate

- (void)addAccountSigninManagerFailedWithError:(NSError*)error {
  DCHECK(error);
  __weak AddAccountSigninCoordinator* weakSelf = self;
  ProceduralBlock dismissAction = ^{
    [weakSelf addAccountSigninManagerFinishedWithSigninResult:
                  SigninCoordinatorResultCanceledByUser
                                                     identity:nil];
  };

  self.alertCoordinator = ErrorCoordinator(
      error, dismissAction, self.baseViewController, self.browser);
  [self.alertCoordinator start];
}

- (void)addAccountSigninManagerFinishedWithSigninResult:
            (SigninCoordinatorResult)signinResult
                                               identity:
                                                   (ChromeIdentity*)identity {
  if (!self.addAccountSigninManager) {
    // The AddAccountSigninManager callback might be called after the
    // interrupt method. If this is the case, the AddAccountSigninCoordinator
    // is already stopped. This call can be ignored.
    return;
  }
  // Add account is done, we don't need |self.AddAccountSigninManager|
  // anymore.
  self.addAccountSigninManager = nil;
  if (signinResult == SigninCoordinatorResultInterrupted) {
    // Stop the reauth flow.
    [self addAccountDoneWithSigninResult:signinResult identity:nil];
    return;
  }
  switch (self.signinIntent) {
    case AddAccountSigninIntentReauthPrimaryAccount: {
      [self presentUserConsentWithIdentity:identity];
      break;
    }
    case AddAccountSigninIntentAddSecondaryAccount: {
      [self addAccountDoneWithSigninResult:signinResult identity:identity];
      break;
    }
  }
}

#pragma mark - Private

// Runs callback completion on finishing the add account flow.
- (void)addAccountDoneWithSigninResult:(SigninCoordinatorResult)signinResult
                              identity:(ChromeIdentity*)identity {
  DCHECK(!self.alertCoordinator);
  DCHECK(!self.userSigninCoordinator);
  // |identity| is set, only and only if the sign-in is successful.
  DCHECK(((signinResult == SigninCoordinatorResultSuccess) && identity) ||
         ((signinResult != SigninCoordinatorResultSuccess) && !identity));
  SigninCompletionInfo* completionInfo =
      [SigninCompletionInfo signinCompletionInfoWithIdentity:identity];
  [self runCompletionCallbackWithSigninResult:signinResult
                               completionInfo:completionInfo];
}

// Presents the user consent screen with |identity| pre-selected.
- (void)presentUserConsentWithIdentity:(ChromeIdentity*)identity {
  // The UserSigninViewController is presented on top of the currently displayed
  // view controller.
  self.userSigninCoordinator = [SigninCoordinator
      userSigninCoordinatorWithBaseViewController:self.baseViewController
                                          browser:self.browser
                                         identity:identity
                                      accessPoint:self.accessPoint
                                      promoAction:self.promoAction];

  __weak AddAccountSigninCoordinator* weakSelf = self;
  self.userSigninCoordinator.signinCompletion =
      ^(SigninCoordinatorResult signinResult,
        SigninCompletionInfo* signinCompletionInfo) {
        [weakSelf.userSigninCoordinator stop];
        weakSelf.userSigninCoordinator = nil;
        [weakSelf addAccountDoneWithSigninResult:signinResult
                                        identity:signinCompletionInfo.identity];
      };
  [self.userSigninCoordinator start];
}

@end
