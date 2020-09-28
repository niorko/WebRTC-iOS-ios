// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/settings/safety_check/safety_check_coordinator.h"

#include "base/mac/foundation_util.h"
#include "base/memory/scoped_refptr.h"
#include "base/strings/sys_string_conversions.h"
#include "ios/chrome/browser/application_context.h"
#include "ios/chrome/browser/browser_state/chrome_browser_state.h"
#include "ios/chrome/browser/main/browser.h"
#include "ios/chrome/browser/passwords/ios_chrome_password_check_manager.h"
#include "ios/chrome/browser/passwords/ios_chrome_password_check_manager_factory.h"
#include "ios/chrome/browser/passwords/ios_chrome_password_store_factory.h"
#import "ios/chrome/browser/signin/authentication_service_factory.h"
#include "ios/chrome/browser/sync/profile_sync_service_factory.h"
#import "ios/chrome/browser/sync/sync_setup_service.h"
#import "ios/chrome/browser/sync/sync_setup_service_factory.h"
#import "ios/chrome/browser/ui/commands/application_commands.h"
#import "ios/chrome/browser/ui/commands/browser_commands.h"
#import "ios/chrome/browser/ui/commands/command_dispatcher.h"
#import "ios/chrome/browser/ui/commands/open_new_tab_command.h"
#import "ios/chrome/browser/ui/settings/elements/enterprise_info_popover_view_controller.h"
#import "ios/chrome/browser/ui/settings/google_services/google_services_settings_coordinator.h"
#import "ios/chrome/browser/ui/settings/password/password_issues_coordinator.h"
#import "ios/chrome/browser/ui/settings/safety_check/safety_check_mediator.h"
#import "ios/chrome/browser/ui/settings/safety_check/safety_check_navigation_commands.h"
#import "ios/chrome/browser/ui/settings/safety_check/safety_check_table_view_controller.h"
#import "ios/chrome/browser/ui/settings/settings_navigation_controller.h"
#import "ios/chrome/common/ui/elements/popover_label_view_controller.h"
#import "net/base/mac/url_conversions.h"
#include "url/gurl.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@interface SafetyCheckCoordinator () <
    GoogleServicesSettingsCoordinatorDelegate,
    PasswordIssuesCoordinatorDelegate,
    PopoverLabelViewControllerDelegate,
    SafetyCheckNavigationCommands,
    SafetyCheckTableViewControllerPresentationDelegate>

// Safety check mediator.
@property(nonatomic, strong) SafetyCheckMediator* mediator;

// The container view controller.
@property(nonatomic, strong) SafetyCheckTableViewController* viewController;

// Coordinator for passwords issues screen.
@property(nonatomic, strong)
    PasswordIssuesCoordinator* passwordIssuesCoordinator;

// Dispatcher which can handle changing passwords on sites.
@property(nonatomic, strong) id<ApplicationCommands> handler;

// Coordinator for the Google Services screen (SafeBrowsing toggle location).
@property(nonatomic, strong)
    GoogleServicesSettingsCoordinator* googleServicesSettingsCoordinator;

// Popover view controller with error information.
@property(nonatomic, strong)
    PopoverLabelViewController* errorInfoPopoverViewController;

@end

@implementation SafetyCheckCoordinator

@synthesize baseNavigationController = _baseNavigationController;

- (instancetype)initWithBaseNavigationController:
                    (UINavigationController*)navigationController
                                         browser:(Browser*)browser {
  self = [super initWithBaseViewController:navigationController
                                   browser:browser];
  if (self) {
    _baseNavigationController = navigationController;
    _handler = HandlerForProtocol(self.browser->GetCommandDispatcher(),
                                  ApplicationCommands);
  }
  return self;
}

#pragma mark - ChromeCoordinator

- (void)start {
  SafetyCheckTableViewController* viewController =
      [[SafetyCheckTableViewController alloc]
          initWithStyle:UITableViewStyleGrouped];
  self.viewController = viewController;

  scoped_refptr<IOSChromePasswordCheckManager> passwordCheckManager =
      IOSChromePasswordCheckManagerFactory::GetForBrowserState(
          self.browser->GetBrowserState());
  self.mediator = [[SafetyCheckMediator alloc]
      initWithUserPrefService:self.browser->GetBrowserState()->GetPrefs()
         passwordCheckManager:passwordCheckManager
                  authService:AuthenticationServiceFactory::GetForBrowserState(
                                  self.browser->GetBrowserState())
                  syncService:SyncSetupServiceFactory::GetForBrowserState(
                                  self.browser->GetBrowserState())];

  self.mediator.consumer = self.viewController;
  self.mediator.handler = self;
  self.viewController.serviceDelegate = self.mediator;
  self.viewController.presentationDelegate = self;

  DCHECK(self.baseNavigationController);
  [self.baseNavigationController pushViewController:self.viewController
                                           animated:YES];
}

#pragma mark - SafetyCheckTableViewControllerPresentationDelegate

- (void)safetyCheckTableViewControllerDidRemove:
    (SafetyCheckTableViewController*)controller {
  DCHECK_EQ(self.viewController, controller);
  [self.delegate safetyCheckCoordinatorDidRemove:self];
}

#pragma mark - PopoverLabelViewControllerDelegate

- (void)didTapLinkURL:(NSURL*)URL {
  GURL convertedURL = net::GURLWithNSURL(URL);
  const GURL safeBrowsingURL(kSafeBrowsingStringURL);

  // Take the user to Sync and Google Services page in Bling instead of desktop
  // settings.
  if (convertedURL == safeBrowsingURL) {
    [self.errorInfoPopoverViewController
        dismissViewControllerAnimated:YES
                           completion:^{
                             [self showSafeBrowsingPreferencePage];
                           }];
    return;
  }

  OpenNewTabCommand* command =
      [OpenNewTabCommand commandWithURLFromChrome:convertedURL];
  [self.handler closeSettingsUIAndOpenURL:command];
}

#pragma mark - SafetyCheckNavigationCommands

- (void)showPasswordIssuesPage {
  IOSChromePasswordCheckManager* passwordCheckManager =
      IOSChromePasswordCheckManagerFactory::GetForBrowserState(
          self.browser->GetBrowserState())
          .get();
  self.passwordIssuesCoordinator = [[PasswordIssuesCoordinator alloc]
      initWithBaseNavigationController:self.baseNavigationController
                               browser:self.browser
                  passwordCheckManager:passwordCheckManager];
  self.passwordIssuesCoordinator.delegate = self;
  self.passwordIssuesCoordinator.reauthModule = nil;
  [self.passwordIssuesCoordinator start];
}

- (void)showErrorInfoFrom:(UIButton*)buttonView
                 withText:(NSAttributedString*)text {
  self.errorInfoPopoverViewController =
      [[PopoverLabelViewController alloc] initWithPrimaryAttributedString:text
                                                secondaryAttributedString:nil];

  self.errorInfoPopoverViewController.delegate = self;

  self.errorInfoPopoverViewController.popoverPresentationController.sourceView =
      buttonView;
  self.errorInfoPopoverViewController.popoverPresentationController.sourceRect =
      buttonView.bounds;
  self.errorInfoPopoverViewController.popoverPresentationController
      .permittedArrowDirections = UIPopoverArrowDirectionAny;
  [self.viewController presentViewController:self.errorInfoPopoverViewController
                                    animated:YES
                                  completion:nil];
}

- (void)showUpdateAtLocation:(NSString*)location {
  // TODO(crbug.com/1078782): Add navigation to various app update locations.
}

- (void)showSafeBrowsingPreferencePage {
  DCHECK(!self.googleServicesSettingsCoordinator);
  self.googleServicesSettingsCoordinator =
      [[GoogleServicesSettingsCoordinator alloc]
          initWithBaseNavigationController:self.baseNavigationController
                                   browser:self.browser
                                      mode:GoogleServicesSettingsModeSettings];
  self.googleServicesSettingsCoordinator.handler = self.handler;
  self.googleServicesSettingsCoordinator.delegate = self;
  [self.googleServicesSettingsCoordinator start];
}

- (void)showManagedInfoFrom:(UIButton*)buttonView {
  EnterpriseInfoPopoverViewController* bubbleViewController =
      [[EnterpriseInfoPopoverViewController alloc] initWithEnterpriseName:nil];
  [self.viewController presentViewController:bubbleViewController
                                    animated:YES
                                  completion:nil];

  // Disable the button when showing the bubble.
  // The button will be enabled when close the bubble in
  // (void)popoverPresentationControllerDidDismissPopover: of
  // EnterpriseInfoPopoverViewController.
  buttonView.enabled = NO;

  // Set the anchor and arrow direction of the bubble.
  bubbleViewController.popoverPresentationController.sourceView = buttonView;
  bubbleViewController.popoverPresentationController.sourceRect =
      buttonView.bounds;
  bubbleViewController.popoverPresentationController.permittedArrowDirections =
      UIPopoverArrowDirectionAny;
}

#pragma mark - PasswordIssuesCoordinatorDelegate

- (void)passwordIssuesCoordinatorDidRemove:
    (PasswordIssuesCoordinator*)coordinator {
  DCHECK_EQ(self.passwordIssuesCoordinator, coordinator);
  [self.passwordIssuesCoordinator stop];
  self.passwordIssuesCoordinator.delegate = nil;
  self.passwordIssuesCoordinator = nil;
}

- (BOOL)willHandlePasswordDeletion:(const autofill::PasswordForm&)password {
  return NO;
}

#pragma mark - GoogleServicesSettingsCoordinatorDelegate

- (void)googleServicesSettingsCoordinatorDidRemove:
    (GoogleServicesSettingsCoordinator*)coordinator {
  DCHECK_EQ(_googleServicesSettingsCoordinator, coordinator);
  [self.googleServicesSettingsCoordinator stop];
  self.googleServicesSettingsCoordinator.delegate = nil;
  self.googleServicesSettingsCoordinator = nil;
}

@end
