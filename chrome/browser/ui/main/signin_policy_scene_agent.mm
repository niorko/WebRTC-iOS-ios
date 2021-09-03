// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/main/signin_policy_scene_agent.h"

#include "components/prefs/ios/pref_observer_bridge.h"
#include "components/prefs/pref_change_registrar.h"
#include "components/prefs/pref_service.h"
#include "components/signin/public/base/signin_metrics.h"
#include "components/signin/public/base/signin_pref_names.h"
#include "components/signin/public/identity_manager/identity_manager.h"
#import "components/signin/public/identity_manager/objc/identity_manager_observer_bridge.h"
#import "ios/chrome/app/application_delegate/app_state.h"
#import "ios/chrome/app/application_delegate/app_state_observer.h"
#include "ios/chrome/browser/application_context.h"
#import "ios/chrome/browser/policy/policy_util.h"
#import "ios/chrome/browser/policy/policy_watcher_browser_agent.h"
#import "ios/chrome/browser/policy/policy_watcher_browser_agent_observer_bridge.h"
#include "ios/chrome/browser/pref_names.h"
#import "ios/chrome/browser/signin/authentication_service.h"
#import "ios/chrome/browser/signin/authentication_service_factory.h"
#include "ios/chrome/browser/signin/identity_manager_factory.h"
#import "ios/chrome/browser/ui/authentication/signin/signin_utils.h"
#import "ios/chrome/browser/ui/commands/application_commands.h"
#import "ios/chrome/browser/ui/commands/command_dispatcher.h"
#import "ios/chrome/browser/ui/commands/policy_change_commands.h"
#import "ios/chrome/browser/ui/commands/show_signin_command.h"
#import "ios/chrome/browser/ui/main/browser_interface_provider.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

// TODO(crbug.com/1244632): Use the Authentication Service sign-in status API
// instead of this when available.
bool IsSigninForcedByPolicy() {
  BrowserSigninMode policy_mode = static_cast<BrowserSigninMode>(
      GetApplicationContext()->GetLocalState()->GetInteger(
          prefs::kBrowserSigninPolicy));
  return policy_mode == BrowserSigninMode::kForced;
}

}  // namespace

@interface SigninPolicySceneAgent () <AppStateObserver,
                                      PrefObserverDelegate,
                                      IdentityManagerObserverBridgeDelegate> {
  // Pref observer to track changes to prefs.
  std::unique_ptr<PrefObserverBridge> _prefsObserverBridge;
  // Registrar for pref change notifications.
  std::unique_ptr<PrefChangeRegistrar> _prefChangeRegistrar;
  // Observes changes in identity to make sure that the sign-in state matches
  // the BrowserSignin policy.
  std::unique_ptr<signin::IdentityManagerObserverBridge>
      _identityObserverBridge;
}

@property(nonatomic, weak) CommandDispatcher* dispatcher;

// Browser of the main interface of the scene.
@property(nonatomic, assign) Browser* mainBrowser;

@end

@implementation SigninPolicySceneAgent

- (instancetype)initWithCommandDispatcher:(CommandDispatcher*)dispatcher {
  if ([super init])
    _dispatcher = dispatcher;
  return self;
}

#pragma mark - ObservingSceneAgent

- (void)setSceneState:(SceneState*)sceneState {
  [super setSceneState:sceneState];

  [self.sceneState.appState addObserver:self];
}

#pragma mark - SceneStateObserver

- (void)sceneStateDidDisableUI:(SceneState*)sceneState {
  // Tear down objects tied to the scene state before it is deleted.
  [self tearDownObservers];
  [self.sceneState.appState removeObserver:self];
  [self.sceneState removeObserver:self];
  self.mainBrowser = nullptr;
}

- (void)sceneStateDidEnableUI:(SceneState*)sceneState {
  // Setup objects that need the browser UI objects before being set.
  self.mainBrowser = self.sceneState.interfaceProvider.mainInterface.browser;
  [self setupObservers];
}

- (void)sceneState:(SceneState*)sceneState
    transitionedToActivationLevel:(SceneActivationLevel)level {
  // Monitor the scene activation level to consider showing the sign-in prompt
  // when the scene becomes active and in the foreground. In which case the
  // scene is visible and interactable.
  [self handleSigninPromptsIfUIAvailable];
}

- (void)sceneStateDidHideModalOverlay:(SceneState*)sceneState {
  // Reconsider showing the forced sign-in prompt if the UI blocker is
  // dismissed which might be because the scene that was displaying the
  // sign-in prompt previously was closed. Choosing a new scene to prompt
  // is needed in that case.
  [self handleSigninPromptsIfUIAvailable];
}

#pragma mark - AppStateObserver

- (void)appState:(AppState*)appState
    didTransitionFromInitStage:(InitStage)previousInitStage {
  // Monitor the app intialization stages to consider showing the sign-in
  // prompts at a point in the initialization of the app that allows it.
  [self handleSigninPromptsIfUIAvailable];
}

#pragma mark - PrefObserverDelegate

// TODO(crbug.com/1244632): Use the Authentication Service sign-in status API
// instead of this when available.
- (void)onPreferenceChanged:(const std::string&)preferenceName {
  // Reconsider showing the sign-in prompts when the value of the sign-in
  // policy changes.
  [self handleSigninPromptsIfUIAvailable];
}

#pragma mark - IdentityManagerObserverBridgeDelegate

- (void)onPrimaryAccountChanged:
    (const signin::PrimaryAccountChangeEvent&)event {
  // Consider showing the sign-in prompts when there is change in the
  // primary account.
  [self handleSigninPromptsIfUIAvailable];
}

#pragma mark - Internal

- (void)setupObservers {
  DCHECK(self.mainBrowser);

  // Set observer for policy changes.
  PrefService* prefService = GetApplicationContext()->GetLocalState();
  _prefChangeRegistrar = std::make_unique<PrefChangeRegistrar>();
  _prefChangeRegistrar->Init(prefService);
  _prefsObserverBridge = std::make_unique<PrefObserverBridge>(self);
  _prefsObserverBridge->ObserveChangesForPreference(prefs::kBrowserSigninPolicy,
                                                    _prefChangeRegistrar.get());

  // Set observer for primary account changes.
  signin::IdentityManager* identityManager =
      IdentityManagerFactory::GetForBrowserState(
          self.mainBrowser->GetBrowserState());
  _identityObserverBridge =
      std::make_unique<signin::IdentityManagerObserverBridge>(identityManager,
                                                              self);
}

- (void)tearDownObservers {
  _prefChangeRegistrar.reset();
  _prefsObserverBridge.reset();
  _identityObserverBridge.reset();
}

- (BOOL)isForcedSignInRequiredByPolicy {
  DCHECK(self.mainBrowser);

  if (!IsSigninForcedByPolicy()) {
    return NO;
  }

  AuthenticationService* authService =
      AuthenticationServiceFactory::GetForBrowserState(
          self.mainBrowser->GetBrowserState());
  // Skip prompting to sign-in when there is already a primary account
  // signed in.
  return !authService->HasPrimaryIdentity(signin::ConsentLevel::kSignin);
}

// Handle the policy sign-in prompts if the scene UI is available to show
// prompts.
- (void)handleSigninPromptsIfUIAvailable {
  if (![self isUIAvailableToPrompt]) {
    return;
  }

  if (self.sceneState.appState.shouldShowPolicySignoutPrompt) {
    // Show the sign-out prompt if the user was signed out due to policy.
    [HandlerForProtocol(self.dispatcher, PolicyChangeCommands)
        showPolicySignoutPrompt];
    self.sceneState.appState.shouldShowPolicySignoutPrompt = NO;
  }

  if ([self isForcedSignInRequiredByPolicy]) {
    // Prompt to sign in if required by policy.
    ShowSigninCommand* command = [[ShowSigninCommand alloc]
        initWithOperation:AUTHENTICATION_OPERATION_SIGNIN
                 identity:nil
              accessPoint:signin_metrics::AccessPoint::
                              ACCESS_POINT_FORCED_SIGNIN
              promoAction:signin_metrics::PromoAction::
                              PROMO_ACTION_NO_SIGNIN_PROMO
                 callback:^(BOOL success) {
                   self.sceneState.appState.shouldShowPolicySignoutPrompt = NO;
                 }];

    id<ApplicationCommands> handler =
        HandlerForProtocol(self.dispatcher, ApplicationCommands);
    // TODO(crbug.com/1241451): Use the command for forced sign-in when
    // available.
    [handler showSignin:command
        baseViewController:self.sceneState.interfaceProvider.mainInterface
                               .viewController];
  }
}

// YES if the scene and the app are in a state where the UI of the scene is
// available to show sign-in related prompts.
- (BOOL)isUIAvailableToPrompt {
  if (self.sceneState.appState.initStage < InitStageFinal) {
    return NO;
  }

  if (self.sceneState.activationLevel < SceneActivationLevelForegroundActive) {
    return NO;
  }

  if (self.sceneState.appState.currentUIBlocker) {
    // Return NO when |currentUIBlocker| is set because it means that there is
    // a UI blocking modal being displayed. Re-attempting to show prompts is
    // done when the blocker is dismissed.
    return NO;
  }

  return YES;
}

@end
