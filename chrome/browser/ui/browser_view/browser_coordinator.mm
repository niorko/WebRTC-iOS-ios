// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/browser_view/browser_coordinator.h"

#import <memory>

#import "base/metrics/histogram_functions.h"
#import "base/scoped_observation.h"
#import "components/feature_engagement/public/event_constants.h"
#import "components/feature_engagement/public/tracker.h"
#import "components/profile_metrics/browser_profile_type.h"
#import "components/safe_browsing/core/common/features.h"
#import "components/signin/ios/browser/active_state_manager.h"
#import "components/translate/core/browser/translate_manager.h"
#import "ios/chrome/browser/app_launcher/app_launcher_abuse_detector.h"
#import "ios/chrome/browser/app_launcher/app_launcher_tab_helper.h"
#import "ios/chrome/browser/autofill/autofill_tab_helper.h"
#import "ios/chrome/browser/browser_state/chrome_browser_state.h"
#import "ios/chrome/browser/chrome_url_constants.h"
#import "ios/chrome/browser/download/download_directory_util.h"
#import "ios/chrome/browser/download/external_app_util.h"
#import "ios/chrome/browser/download/pass_kit_tab_helper.h"
#import "ios/chrome/browser/feature_engagement/tracker_factory.h"
#import "ios/chrome/browser/feature_engagement/tracker_util.h"
#import "ios/chrome/browser/find_in_page/find_tab_helper.h"
#import "ios/chrome/browser/follow/follow_tab_helper.h"
#import "ios/chrome/browser/main/browser.h"
#import "ios/chrome/browser/ntp/features.h"
#import "ios/chrome/browser/prerender/preload_controller_delegate.h"
#import "ios/chrome/browser/prerender/prerender_service.h"
#import "ios/chrome/browser/prerender/prerender_service_factory.h"
#import "ios/chrome/browser/signin/account_consistency_browser_agent.h"
#import "ios/chrome/browser/signin/account_consistency_service_factory.h"
#import "ios/chrome/browser/ssl/captive_portal_tab_helper.h"
#import "ios/chrome/browser/store_kit/store_kit_coordinator.h"
#import "ios/chrome/browser/store_kit/store_kit_tab_helper.h"
#import "ios/chrome/browser/sync/sync_error_browser_agent.h"
#import "ios/chrome/browser/tabs/tab_title_util.h"
#import "ios/chrome/browser/translate/chrome_ios_translate_client.h"
#import "ios/chrome/browser/ui/activity_services/activity_params.h"
#import "ios/chrome/browser/ui/activity_services/requirements/activity_service_positioner.h"
#import "ios/chrome/browser/ui/alert_coordinator/repost_form_coordinator.h"
#import "ios/chrome/browser/ui/authentication/enterprise/enterprise_prompt/enterprise_prompt_coordinator.h"
#import "ios/chrome/browser/ui/authentication/enterprise/enterprise_prompt/enterprise_prompt_type.h"
#import "ios/chrome/browser/ui/autofill/form_input_accessory/form_input_accessory_coordinator.h"
#import "ios/chrome/browser/ui/badges/badge_popup_menu_coordinator.h"
#import "ios/chrome/browser/ui/bookmarks/bookmark_interaction_controller.h"
#import "ios/chrome/browser/ui/browser_container/browser_container_coordinator.h"
#import "ios/chrome/browser/ui/browser_container/browser_container_view_controller.h"
#import "ios/chrome/browser/ui/browser_view/browser_view_controller+delegates.h"
#import "ios/chrome/browser/ui/browser_view/browser_view_controller+private.h"
#import "ios/chrome/browser/ui/browser_view/browser_view_controller.h"
#import "ios/chrome/browser/ui/browser_view/browser_view_controller_helper.h"
#import "ios/chrome/browser/ui/browser_view/key_commands_provider.h"
#import "ios/chrome/browser/ui/browser_view/tab_lifecycle_mediator.h"
#import "ios/chrome/browser/ui/bubble/bubble_presenter.h"
#import "ios/chrome/browser/ui/commands/activity_service_commands.h"
#import "ios/chrome/browser/ui/commands/application_commands.h"
#import "ios/chrome/browser/ui/commands/browser_coordinator_commands.h"
#import "ios/chrome/browser/ui/commands/command_dispatcher.h"
#import "ios/chrome/browser/ui/commands/feed_commands.h"
#import "ios/chrome/browser/ui/commands/find_in_page_commands.h"
#import "ios/chrome/browser/ui/commands/page_info_commands.h"
#import "ios/chrome/browser/ui/commands/password_breach_commands.h"
#import "ios/chrome/browser/ui/commands/password_protection_commands.h"
#import "ios/chrome/browser/ui/commands/password_suggestion_commands.h"
#import "ios/chrome/browser/ui/commands/policy_change_commands.h"
#import "ios/chrome/browser/ui/commands/qr_generation_commands.h"
#import "ios/chrome/browser/ui/commands/share_highlight_command.h"
#import "ios/chrome/browser/ui/commands/show_signin_command.h"
#import "ios/chrome/browser/ui/commands/snackbar_commands.h"
#import "ios/chrome/browser/ui/commands/text_zoom_commands.h"
#import "ios/chrome/browser/ui/commands/whats_new_commands.h"
#import "ios/chrome/browser/ui/context_menu/context_menu_configuration_provider.h"
#import "ios/chrome/browser/ui/default_promo/default_browser_promo_coordinator.h"
#import "ios/chrome/browser/ui/default_promo/default_browser_promo_non_modal_commands.h"
#import "ios/chrome/browser/ui/default_promo/default_browser_promo_non_modal_coordinator.h"
#import "ios/chrome/browser/ui/default_promo/default_browser_promo_non_modal_scheduler.h"
#import "ios/chrome/browser/ui/default_promo/default_promo_non_modal_presentation_delegate.h"
#import "ios/chrome/browser/ui/default_promo/tailored_promo_coordinator.h"
#import "ios/chrome/browser/ui/download/ar_quick_look_coordinator.h"
#import "ios/chrome/browser/ui/download/download_manager_coordinator.h"
#import "ios/chrome/browser/ui/download/features.h"
#import "ios/chrome/browser/ui/download/pass_kit_coordinator.h"
#import "ios/chrome/browser/ui/download/safari_download_coordinator.h"
#import "ios/chrome/browser/ui/download/vcard_coordinator.h"
#import "ios/chrome/browser/ui/elements/activity_overlay_coordinator.h"
#import "ios/chrome/browser/ui/find_bar/find_bar_controller_ios.h"
#import "ios/chrome/browser/ui/find_bar/find_bar_coordinator.h"
#import "ios/chrome/browser/ui/follow/first_follow_coordinator.h"
#import "ios/chrome/browser/ui/follow/follow_iph_coordinator.h"
#import "ios/chrome/browser/ui/follow/followed_web_channel.h"
#import "ios/chrome/browser/ui/fullscreen/fullscreen_controller.h"
#import "ios/chrome/browser/ui/incognito_reauth/incognito_reauth_mediator.h"
#import "ios/chrome/browser/ui/incognito_reauth/incognito_reauth_scene_agent.h"
#import "ios/chrome/browser/ui/lens/lens_coordinator.h"
#import "ios/chrome/browser/ui/main/default_browser_scene_agent.h"
#import "ios/chrome/browser/ui/main/scene_state_browser_agent.h"
#import "ios/chrome/browser/ui/ntp/new_tab_page_coordinator.h"
#import "ios/chrome/browser/ui/open_in/open_in_coordinator.h"
#import "ios/chrome/browser/ui/overlays/overlay_container_coordinator.h"
#import "ios/chrome/browser/ui/page_info/page_info_coordinator.h"
#import "ios/chrome/browser/ui/passwords/password_breach_coordinator.h"
#import "ios/chrome/browser/ui/passwords/password_protection_coordinator.h"
#import "ios/chrome/browser/ui/passwords/password_suggestion_coordinator.h"
#import "ios/chrome/browser/ui/popup_menu/popup_menu_coordinator.h"
#import "ios/chrome/browser/ui/presenters/vertical_animation_container.h"
#import "ios/chrome/browser/ui/print/print_controller.h"
#import "ios/chrome/browser/ui/qr_generator/qr_generator_coordinator.h"
#import "ios/chrome/browser/ui/qr_scanner/qr_scanner_legacy_coordinator.h"
#import "ios/chrome/browser/ui/reading_list/reading_list_coordinator.h"
#import "ios/chrome/browser/ui/recent_tabs/recent_tabs_coordinator.h"
#import "ios/chrome/browser/ui/sad_tab/sad_tab_coordinator.h"
#import "ios/chrome/browser/ui/safe_browsing/safe_browsing_coordinator.h"
#import "ios/chrome/browser/ui/send_tab_to_self/send_tab_to_self_coordinator.h"
#import "ios/chrome/browser/ui/settings/autofill/autofill_add_credit_card_coordinator.h"
#import "ios/chrome/browser/ui/sharing/sharing_coordinator.h"
#import "ios/chrome/browser/ui/side_swipe/side_swipe_controller.h"
#import "ios/chrome/browser/ui/tab_switcher/tab_strip/tab_strip_coordinator.h"
#import "ios/chrome/browser/ui/tabs/tab_strip_legacy_coordinator.h"
#import "ios/chrome/browser/ui/text_fragments/text_fragments_coordinator.h"
#import "ios/chrome/browser/ui/text_zoom/text_zoom_coordinator.h"
#import "ios/chrome/browser/ui/toolbar/accessory/toolbar_accessory_coordinator_delegate.h"
#import "ios/chrome/browser/ui/toolbar/accessory/toolbar_accessory_presenter.h"
#import "ios/chrome/browser/ui/toolbar/primary_toolbar_coordinator.h"
#import "ios/chrome/browser/ui/toolbar/public/toolbar_coordinating.h"
#import "ios/chrome/browser/ui/toolbar/secondary_toolbar_coordinator.h"
#import "ios/chrome/browser/ui/toolbar/toolbar_coordinator_adaptor.h"
#import "ios/chrome/browser/ui/ui_feature_flags.h"
#import "ios/chrome/browser/ui/voice/text_to_speech_playback_controller.h"
#import "ios/chrome/browser/ui/voice/text_to_speech_playback_controller_factory.h"
#import "ios/chrome/browser/ui/webui/net_export_coordinator.h"
#import "ios/chrome/browser/url_loading/url_loading_browser_agent.h"
#import "ios/chrome/browser/url_loading/url_loading_params.h"
#import "ios/chrome/browser/web/font_size/font_size_tab_helper.h"
#import "ios/chrome/browser/web/print/print_tab_helper.h"
#import "ios/chrome/browser/web/repost_form_tab_helper.h"
#import "ios/chrome/browser/web/repost_form_tab_helper_delegate.h"
#import "ios/chrome/browser/web/web_navigation_browser_agent.h"
#import "ios/chrome/browser/web/web_state_delegate_browser_agent.h"
#import "ios/chrome/browser/web_state_list/tab_insertion_browser_agent.h"
#import "ios/chrome/browser/web_state_list/view_source_browser_agent.h"
#import "ios/chrome/browser/web_state_list/web_state_list.h"
#import "ios/chrome/browser/web_state_list/web_state_list_observer_bridge.h"
#import "ios/chrome/browser/webui/net_export_tab_helper_delegate.h"
#import "ios/chrome/grit/ios_strings.h"
#import "ios/public/provider/chrome/browser/text_zoom/text_zoom_api.h"
#import "ui/base/device_form_factor.h"
#import "ui/base/l10n/l10n_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

// Duration of the toolbar animation.
constexpr base::TimeDelta kLegacyFullscreenControllerToolbarAnimationDuration =
    base::Milliseconds(300);

@interface BrowserCoordinator () <ActivityServiceCommands,
                                  BrowserCoordinatorCommands,
                                  DefaultBrowserPromoCommands,
                                  DefaultPromoNonModalPresentationDelegate,
                                  EnterprisePromptCoordinatorDelegate,
                                  FormInputAccessoryCoordinatorNavigator,
                                  NetExportTabHelperDelegate,
                                  PageInfoCommands,
                                  PasswordBreachCommands,
                                  PasswordProtectionCommands,
                                  PasswordSuggestionCommands,
                                  PasswordSuggestionCoordinatorDelegate,
                                  PolicyChangeCommands,
                                  PreloadControllerDelegate,
                                  RepostFormTabHelperDelegate,
                                  SigninPresenter,
                                  ToolbarAccessoryCoordinatorDelegate,
                                  URLLoadingDelegate,
                                  WebStateListObserving>

// Whether the coordinator is started.
@property(nonatomic, assign, getter=isStarted) BOOL started;

// Handles command dispatching, provided by the Browser instance.
@property(nonatomic, weak) CommandDispatcher* dispatcher;

// The coordinator managing the container view controller.
@property(nonatomic, strong)
    BrowserContainerCoordinator* browserContainerCoordinator;

// Coordinator between OpenIn TabHelper and OpenIn UI.
@property(nonatomic, strong) OpenInCoordinator* openInCoordinator;

// Mediator for incognito reauth.
@property(nonatomic, strong) IncognitoReauthMediator* incognitoAuthMediator;

// Mediator for tab lifecylce.
@property(nonatomic, strong) TabLifecycleMediator* tabLifecycleMediator;

// =================================================
// Child Coordinators, listed in alphabetical order.
// =================================================

// Coordinator for displaying a modal overlay with activity indicator to prevent
// the user from interacting with the browser view.
@property(nonatomic, strong)
    ActivityOverlayCoordinator* activityOverlayCoordinator;

// Presents a QLPreviewController in order to display USDZ format 3D models.
@property(nonatomic, strong) ARQuickLookCoordinator* ARQuickLookCoordinator;

// Coordinator to add new credit card.
@property(nonatomic, strong)
    AutofillAddCreditCardCoordinator* addCreditCardCoordinator;

// Coordinator for the badge popup menu.
@property(nonatomic, strong)
    BadgePopupMenuCoordinator* badgePopupMenuCoordinator;

// Coordinator-ish provider for context menus.
@property(nonatomic, strong)
    ContextMenuConfigurationProvider* contextMenuProvider;

// Coordinator for the find bar.
@property(nonatomic, strong) FindBarCoordinator* findBarCoordinator;

// Coordinator for the First Follow modal.
@property(nonatomic, strong) FirstFollowCoordinator* firstFollowCoordinator;

// Coordinator for the Follow IPH feature.
@property(nonatomic, strong) FollowIPHCoordinator* followIPHCoordinator;

// Coordinator in charge of the presenting autofill options above the
// keyboard.
@property(nonatomic, strong)
    FormInputAccessoryCoordinator* formInputAccessoryCoordinator;

// Presents a SFSafariViewController in order to download .mobileconfig file.
@property(nonatomic, strong)
    SafariDownloadCoordinator* SafariDownloadCoordinator;

// Opens downloaded Vcard.
@property(nonatomic, strong) VcardCoordinator* vcardCoordinator;

// The coordinator that manages net export.
@property(nonatomic, strong) NetExportCoordinator* netExportCoordinator;

// Weak reference for the next coordinator to be displayed over the toolbar.
@property(nonatomic, weak) ChromeCoordinator* nextToolbarCoordinator;

// Coordinator for Page Info UI.
@property(nonatomic, strong) ChromeCoordinator* pageInfoCoordinator;

// Coordinator for the PassKit UI presentation.
@property(nonatomic, strong) PassKitCoordinator* passKitCoordinator;

// Coordinator for the password breach UI presentation.
@property(nonatomic, strong)
    PasswordBreachCoordinator* passwordBreachCoordinator;

// Coordinator for the password protection UI presentation.
@property(nonatomic, strong)
    PasswordProtectionCoordinator* passwordProtectionCoordinator;

// Coordinator for the password suggestion UI presentation.
@property(nonatomic, strong)
    PasswordSuggestionCoordinator* passwordSuggestionCoordinator;

// Used to display the Print UI. Nil if not visible.
// TODO(crbug.com/910017): Convert to coordinator.
@property(nonatomic, strong) PrintController* printController;

// Coordinator for the QR scanner.
@property(nonatomic, strong) QRScannerLegacyCoordinator* qrScannerCoordinator;

// Coordinator for the QR scanner.
@property(nonatomic, strong) PopupMenuCoordinator* popupMenuCoordinator;

// Coordinator that manages Lens features.
@property(nonatomic, strong) LensCoordinator* lensCoordinator;

// Coordinator for displaying the Reading List.
@property(nonatomic, strong) ReadingListCoordinator* readingListCoordinator;

// Coordinator for Recent Tabs.
@property(nonatomic, strong) RecentTabsCoordinator* recentTabsCoordinator;

// Coordinator for displaying Repost Form dialog.
@property(nonatomic, strong) RepostFormCoordinator* repostFormCoordinator;

// Coordinator for displaying Sad Tab.
@property(nonatomic, strong) SadTabCoordinator* sadTabCoordinator;

// Coordinator for Safe Browsing.
@property(nonatomic, strong) SafeBrowsingCoordinator* safeBrowsingCoordinator;

// Coordinator for sharing scenarios.
@property(nonatomic, strong) SharingCoordinator* sharingCoordinator;

// Coordinator for presenting SKStoreProductViewController.
@property(nonatomic, strong) StoreKitCoordinator* storeKitCoordinator;

// Coordinator for Text Zoom.
@property(nonatomic, strong) TextZoomCoordinator* textZoomCoordinator;

// Coordinator that manages the default browser promo modal.
@property(nonatomic, strong)
    DefaultBrowserPromoCoordinator* defaultBrowserPromoCoordinator;

// Coordinator that manages the presentation of Download Manager UI.
@property(nonatomic, strong)
    DownloadManagerCoordinator* downloadManagerCoordinator;

// Coordinator that manages the tailored promo modals.
@property(nonatomic, strong) TailoredPromoCoordinator* tailoredPromoCoordinator;

// The container coordinators for the infobar modalities.
@property(nonatomic, strong)
    OverlayContainerCoordinator* infobarBannerOverlayContainerCoordinator;
@property(nonatomic, strong)
    OverlayContainerCoordinator* infobarModalOverlayContainerCoordinator;

// Coordinator for the non-modal default promo.
@property(nonatomic, strong)
    DefaultBrowserPromoNonModalCoordinator* nonModalPromoCoordinator;

// The coordinator that manages enterprise prompts.
@property(nonatomic, strong)
    EnterprisePromptCoordinator* enterprisePromptCoordinator;

// The coordinator used for the Text Fragments feature.
@property(nonatomic, strong) TextFragmentsCoordinator* textFragmentsCoordinator;
@end

@implementation BrowserCoordinator {
  // Observers for WebStateList.
  std::unique_ptr<WebStateListObserverBridge> _webStateListObserverBridge;
  std::unique_ptr<base::ScopedObservation<WebStateList, WebStateListObserver>>
      _scopedWebStateListObservation;
  BrowserViewControllerDependencies _viewControllerDependencies;
  KeyCommandsProvider* _keyCommandsProvider;
  PrerenderService* _prerenderService;
  BubblePresenter* _bubblePresenter;
  NewTabPageCoordinator* _ntpCoordinator;
  ToolbarCoordinatorAdaptor* _toolbarCoordinatorAdaptor;
  PrimaryToolbarCoordinator* _primaryToolbarCoordinator;
  SecondaryToolbarCoordinator* _secondaryToolbarCoordinator;
  TabStripCoordinator* _tabStripCoordinator;
  TabStripLegacyCoordinator* _legacyTabStripCoordinator;
  SideSwipeController* _sideSwipeController;
  FullscreenController* _fullscreenController;
  // The coordinator that shows the Send Tab To Self UI.
  SendTabToSelfCoordinator* _sendTabToSelfCoordinator;
  BookmarkInteractionController* _bookmarkInteractionController;
  id<TextZoomCommands> _textZoomHandler;
  id<HelpCommands> _helpHandler;
  id<PopupMenuCommands> _popupMenuCommandsHandler;
  id<SnackbarCommands> _snackbarCommandsHandler;
}

#pragma mark - ChromeCoordinator

- (void)start {
  if (self.started)
    return;

  DCHECK(!self.viewController);

  [self createViewControllerDependencies];
  [self createViewController];
  [self updateViewControllerDependencies];
  // Mediators should start before coordinators so model state is accurate for
  // any UI that starts up.
  [self startMediators];
  [self installDelegatesForAllWebStates];
  [self startChildCoordinators];
  // Browser delegates can have dependencies on coordinators.
  [self installDelegatesForBrowser];
  [self installDelegatesForBrowserState];
  [self addWebStateListObserver];
  [super start];
  self.started = YES;
}

- (void)stop {
  if (!self.started)
    return;
  [super stop];

  self.active = NO;
  [self removeWebStateListObserver];
  [self uninstallDelegatesForBrowserState];
  [self uninstallDelegatesForBrowser];
  [self uninstallDelegatesForAllWebStates];
  [self.tabLifecycleMediator disconnect];
  self.viewController.commandDispatcher = nil;
  [self.dispatcher stopDispatchingToTarget:self];
  [self stopChildCoordinators];
  [self destroyViewController];
  [self destroyViewControllerDependencies];
  self.started = NO;
}

#pragma mark - Public

- (void)setActive:(BOOL)active {
  DCHECK_EQ(_active, self.viewController.active);
  if (_active == active) {
    return;
  }
  _active = active;

  // If not active, display an activity indicator overlay over the view to
  // prevent interaction with the web page.
  if (active) {
    [self hideActivityOverlay];
  } else if (!self.activityOverlayCoordinator) {
    [self showActivityOverlay];
  }

  ChromeBrowserState* browserState = self.browser->GetBrowserState();
  if (browserState) {
    // TODO(crbug.com/1272520): Refactor ActiveStateManager for multiwindow.
    ActiveStateManager* active_state_manager =
        ActiveStateManager::FromBrowserState(browserState);
    active_state_manager->SetActive(active);

    TextToSpeechPlaybackControllerFactory::GetInstance()
        ->GetForBrowserState(browserState)
        ->SetEnabled(active);
  }

  // TODO(crbug.com/1272516): Update the WebUsageEnablerBrowserAgent as part of
  // setting active/inactive.
  self.viewController.active = active;
}

- (void)clearPresentedStateWithCompletion:(ProceduralBlock)completion
                           dismissOmnibox:(BOOL)dismissOmnibox {
  [self.passKitCoordinator stop];

  [self.openInCoordinator disableAll];

  [self.printController dismissAnimated:YES];

  [self.readingListCoordinator stop];
  self.readingListCoordinator = nil;

  [self.sharingCoordinator stop];
  self.sharingCoordinator = nil;

  [self.passwordBreachCoordinator stop];
  self.passwordBreachCoordinator = nil;

  [self.passwordProtectionCoordinator stop];
  self.passwordProtectionCoordinator = nil;

  [self.passwordSuggestionCoordinator stop];
  self.passwordSuggestionCoordinator = nil;

  [self.pageInfoCoordinator stop];

  [_sendTabToSelfCoordinator stop];
  _sendTabToSelfCoordinator = nil;

  [self.viewController clearPresentedStateWithCompletion:completion
                                          dismissOmnibox:dismissOmnibox];
}

- (void)displayPopupMenuWithBadgeItems:(NSArray<id<BadgeItem>>*)badgeItems {
  self.badgePopupMenuCoordinator = [[BadgePopupMenuCoordinator alloc]
      initWithBaseViewController:self.viewController
                         browser:self.browser];
  [self.badgePopupMenuCoordinator setBadgeItemsToShow:badgeItems];
  [self.badgePopupMenuCoordinator start];
}

#pragma mark - Private

// Displays activity overlay.
- (void)showActivityOverlay {
  self.activityOverlayCoordinator = [[ActivityOverlayCoordinator alloc]
      initWithBaseViewController:self.viewController
                         browser:self.browser];
  [self.activityOverlayCoordinator start];
}

// Hides activity overlay.
- (void)hideActivityOverlay {
  [self.activityOverlayCoordinator stop];
  self.activityOverlayCoordinator = nil;
}

// Shows a default promo with the passed type or nothing if a tailored promo is
// already present.
- (void)showTailoredPromoWithType:(DefaultPromoType)type {
  if (self.tailoredPromoCoordinator) {
    // Another promo is being shown, return early.
    return;
  }
  self.tailoredPromoCoordinator = [[TailoredPromoCoordinator alloc]
      initWithBaseViewController:self.viewController
                         browser:self.browser
                            type:type];
  self.tailoredPromoCoordinator.handler = self;
  [self.tailoredPromoCoordinator start];
}

// Instantiates a BrowserViewController.
- (void)createViewController {
  DCHECK(self.browserContainerCoordinator.viewController);

  BrowserViewControllerHelper* browserViewControllerHelper =
      [[BrowserViewControllerHelper alloc] init];

  _viewController = [[BrowserViewController alloc]
                     initWithBrowser:self.browser
      browserContainerViewController:self.browserContainerCoordinator
                                         .viewController
         browserViewControllerHelper:browserViewControllerHelper
                          dispatcher:self.dispatcher
                 keyCommandsProvider:_keyCommandsProvider
                        dependencies:_viewControllerDependencies];

  WebNavigationBrowserAgent::FromBrowser(self.browser)
      ->SetDelegate(_viewController);

  self.contextMenuProvider = [[ContextMenuConfigurationProvider alloc]
         initWithBrowser:self.browser
      baseViewController:_viewController];
}

// Shuts down the BrowserViewController.
- (void)destroyViewController {
  // TODO(crbug.com/1272516): Set the WebUsageEnablerBrowserAgent to disabled.
  self.viewController.active = NO;
  [self.viewController shutdown];
  _viewController = nil;
}

// Creates the browser view controller dependencies.
- (void)createViewControllerDependencies {
  _dispatcher = self.browser->GetCommandDispatcher();

  // Add commands protocols handled by this class in this array to let the
  // dispatcher know where to dispatch such commands. This must be done before
  // starting any child coordinator, otherwise they won't be able to resolve
  // handlers.
  NSArray<Protocol*>* protocols = @[
    @protocol(ActivityServiceCommands),
    @protocol(BrowserCoordinatorCommands),
    @protocol(DefaultPromoCommands),
    @protocol(DefaultBrowserPromoNonModalCommands),
    @protocol(FeedCommands),
    @protocol(FindInPageCommands),
    @protocol(PageInfoCommands),
    @protocol(PasswordBreachCommands),
    @protocol(PasswordProtectionCommands),
    @protocol(PasswordSuggestionCommands),
    @protocol(PolicyChangeCommands),
    @protocol(TextZoomCommands),
  ];

  for (Protocol* protocol in protocols) {
    [_dispatcher startDispatchingToTarget:self forProtocol:protocol];
  }

  ChromeBrowserState* browserState = self.browser->GetBrowserState();

  _keyCommandsProvider =
      [[KeyCommandsProvider alloc] initWithBrowser:self.browser];
  _keyCommandsProvider.dispatcher =
      static_cast<id<ApplicationCommands, BrowserCommands,
                     BrowserCoordinatorCommands, FindInPageCommands>>(
          _dispatcher);
  _keyCommandsProvider.omniboxHandler =
      static_cast<id<OmniboxCommands>>(_dispatcher);

  _prerenderService = PrerenderServiceFactory::GetForBrowserState(browserState);
  if (!browserState->IsOffTheRecord()) {
    DCHECK(_prerenderService);
    _prerenderService->SetDelegate(self);
  }

  _fullscreenController = FullscreenController::FromBrowser(self.browser);

  _primaryToolbarCoordinator =
      [[PrimaryToolbarCoordinator alloc] initWithBrowser:self.browser];

  _secondaryToolbarCoordinator =
      [[SecondaryToolbarCoordinator alloc] initWithBrowser:self.browser];

  _toolbarCoordinatorAdaptor =
      [[ToolbarCoordinatorAdaptor alloc] initWithDispatcher:_dispatcher];

  [_toolbarCoordinatorAdaptor addToolbarCoordinator:_primaryToolbarCoordinator];
  [_toolbarCoordinatorAdaptor
      addToolbarCoordinator:_secondaryToolbarCoordinator];

  _bubblePresenter =
      [[BubblePresenter alloc] initWithBrowserState:browserState];
  _bubblePresenter.toolbarHandler =
      HandlerForProtocol(_dispatcher, ToolbarCommands);
  [_dispatcher startDispatchingToTarget:_bubblePresenter
                            forProtocol:@protocol(HelpCommands)];

  _sideSwipeController =
      [[SideSwipeController alloc] initWithBrowser:self.browser];
  _sideSwipeController.toolbarInteractionHandler = _toolbarCoordinatorAdaptor;
  _sideSwipeController.primaryToolbarSnapshotProvider =
      _primaryToolbarCoordinator;
  _sideSwipeController.secondaryToolbarSnapshotProvider =
      _secondaryToolbarCoordinator;

  _bookmarkInteractionController =
      [[BookmarkInteractionController alloc] initWithBrowser:self.browser];

  self.browserContainerCoordinator = [[BrowserContainerCoordinator alloc]
      initWithBaseViewController:nil
                         browser:self.browser];
  [self.browserContainerCoordinator start];

  self.downloadManagerCoordinator = [[DownloadManagerCoordinator alloc]
      initWithBaseViewController:self.browserContainerCoordinator.viewController
                         browser:self.browser];
  self.downloadManagerCoordinator.presenter =
      [[VerticalAnimationContainer alloc] init];

  self.qrScannerCoordinator =
      [[QRScannerLegacyCoordinator alloc] initWithBrowser:self.browser];

  self.popupMenuCoordinator =
      [[PopupMenuCoordinator alloc] initWithBrowser:self.browser];
  self.popupMenuCoordinator.bubblePresenter = _bubblePresenter;
  self.popupMenuCoordinator.UIUpdater = _toolbarCoordinatorAdaptor;
  // Coordinator `start` is executed before setting it's `baseViewController`.
  // It is done intentionally, since this does not affecting the coordinator's
  // behavior but helps command hanlders setup below.
  [self.popupMenuCoordinator start];

  _primaryToolbarCoordinator.longPressDelegate = self.popupMenuCoordinator;
  _secondaryToolbarCoordinator.longPressDelegate = self.popupMenuCoordinator;

  if (ui::GetDeviceFormFactor() == ui::DEVICE_FORM_FACTOR_TABLET) {
    if (base::FeatureList::IsEnabled(kModernTabStrip)) {
      _tabStripCoordinator =
          [[TabStripCoordinator alloc] initWithBrowser:self.browser];
    } else {
      _legacyTabStripCoordinator =
          [[TabStripLegacyCoordinator alloc] initWithBrowser:self.browser];
      _legacyTabStripCoordinator.longPressDelegate = self.popupMenuCoordinator;
      _legacyTabStripCoordinator.animationWaitDuration =
          kLegacyFullscreenControllerToolbarAnimationDuration.InSecondsF();

      [_sideSwipeController setTabStripDelegate:_legacyTabStripCoordinator];
    }
  }

  _ntpCoordinator =
      [[NewTabPageCoordinator alloc] initWithBrowser:self.browser];
  _ntpCoordinator.toolbarDelegate = _toolbarCoordinatorAdaptor;
  _ntpCoordinator.bubblePresenter = _bubblePresenter;

  _textZoomHandler = HandlerForProtocol(_dispatcher, TextZoomCommands);
  _helpHandler = HandlerForProtocol(_dispatcher, HelpCommands);
  _popupMenuCommandsHandler =
      HandlerForProtocol(_dispatcher, PopupMenuCommands);

  // SnackbarCoordinator is not created yet and therefore not dispatching
  // SnackbarCommands.
  _snackbarCommandsHandler = static_cast<id<SnackbarCommands>>(_dispatcher);

  _viewControllerDependencies.prerenderService = _prerenderService;
  _viewControllerDependencies.bubblePresenter = _bubblePresenter;
  _viewControllerDependencies.popupMenuCoordinator = self.popupMenuCoordinator;
  _viewControllerDependencies.downloadManagerCoordinator =
      self.downloadManagerCoordinator;
  _viewControllerDependencies.ntpCoordinator = _ntpCoordinator;
  _viewControllerDependencies.primaryToolbarCoordinator =
      _primaryToolbarCoordinator;
  _viewControllerDependencies.secondaryToolbarCoordinator =
      _secondaryToolbarCoordinator;
  _viewControllerDependencies.tabStripCoordinator = _tabStripCoordinator;
  _viewControllerDependencies.legacyTabStripCoordinator =
      _legacyTabStripCoordinator;
  _viewControllerDependencies.sideSwipeController = _sideSwipeController;
  _viewControllerDependencies.bookmarkInteractionController =
      _bookmarkInteractionController;
  _viewControllerDependencies.fullscreenController = _fullscreenController;
  _viewControllerDependencies.textZoomHandler = _textZoomHandler;
  _viewControllerDependencies.helpHandler = _helpHandler;
  _viewControllerDependencies.popupMenuCommandsHandler =
      _popupMenuCommandsHandler;
  _viewControllerDependencies.snackbarCommandsHandler =
      _snackbarCommandsHandler;
}

- (void)updateViewControllerDependencies {
  _keyCommandsProvider.baseViewController = self.viewController;

  _bookmarkInteractionController.parentController = self.viewController;

  _bubblePresenter.delegate = self.viewController;
  _bubblePresenter.rootViewController = self.viewController;

  self.qrScannerCoordinator.baseViewController = self.viewController;
  [self.qrScannerCoordinator start];

  self.popupMenuCoordinator.baseViewController = self.viewController;

  _primaryToolbarCoordinator.delegate = self.viewController;
  _primaryToolbarCoordinator.popupPresenterDelegate = self.viewController;
  [_primaryToolbarCoordinator start];

  _ntpCoordinator.baseViewController = self.viewController;

  [_dispatcher startDispatchingToTarget:self.viewController
                            forProtocol:@protocol(BrowserCommands)];
  [_dispatcher startDispatchingToTarget:self.viewController
                            forProtocol:@protocol(NewTabPageCommands)];
}

// Destroys the browser view controller dependencies.
- (void)destroyViewControllerDependencies {
  _viewControllerDependencies.prerenderService = nil;
  _viewControllerDependencies.bubblePresenter = nil;
  _viewControllerDependencies.popupMenuCoordinator = nil;
  _viewControllerDependencies.downloadManagerCoordinator = nil;
  _viewControllerDependencies.ntpCoordinator = nil;
  _viewControllerDependencies.primaryToolbarCoordinator = nil;
  _viewControllerDependencies.secondaryToolbarCoordinator = nil;
  _viewControllerDependencies.tabStripCoordinator = nil;
  _viewControllerDependencies.legacyTabStripCoordinator = nil;
  _viewControllerDependencies.sideSwipeController = nil;
  _viewControllerDependencies.textZoomHandler = nil;
  _viewControllerDependencies.helpHandler = nil;
  _viewControllerDependencies.bookmarkInteractionController = nil;

  [_bookmarkInteractionController shutdown];
  _bookmarkInteractionController = nil;

  _textZoomHandler = nil;
  _helpHandler = nil;
  _legacyTabStripCoordinator = nil;
  _tabStripCoordinator = nil;
  _sideSwipeController = nil;
  _toolbarCoordinatorAdaptor = nil;
  _secondaryToolbarCoordinator = nil;
  _primaryToolbarCoordinator = nil;

  [_dispatcher stopDispatchingToTarget:_bubblePresenter];
  [_bubblePresenter stop];
  _bubblePresenter = nil;

  _prerenderService = nil;
  _fullscreenController = nullptr;

  [self.popupMenuCoordinator stop];
  self.popupMenuCoordinator = nil;

  [self.qrScannerCoordinator stop];
  self.qrScannerCoordinator = nil;

  [self.downloadManagerCoordinator stop];
  self.downloadManagerCoordinator = nil;

  [self.browserContainerCoordinator stop];
  self.browserContainerCoordinator = nil;

  [_ntpCoordinator stop];
  _ntpCoordinator = nil;

  _keyCommandsProvider = nil;
  _dispatcher = nil;
}

// Starts child coordinators.
- (void)startChildCoordinators {
  // Dispatcher should be instantiated so that it can be passed to child
  // coordinators.
  DCHECK(self.dispatcher);

  self.ARQuickLookCoordinator = [[ARQuickLookCoordinator alloc]
      initWithBaseViewController:self.viewController
                         browser:self.browser];
  [self.ARQuickLookCoordinator start];

  if (IsWebChannelsEnabled()) {
    self.followIPHCoordinator = [[FollowIPHCoordinator alloc]
        initWithBaseViewController:self.viewController
                           browser:self.browser];
    [self.followIPHCoordinator start];
  }

  self.SafariDownloadCoordinator = [[SafariDownloadCoordinator alloc]
      initWithBaseViewController:self.viewController
                         browser:self.browser];
  [self.SafariDownloadCoordinator start];

  self.vcardCoordinator =
      [[VcardCoordinator alloc] initWithBaseViewController:self.viewController
                                                   browser:self.browser];
  [self.vcardCoordinator start];

  self.passKitCoordinator =
      [[PassKitCoordinator alloc] initWithBaseViewController:self.viewController
                                                     browser:self.browser];

  self.printController =
      [[PrintController alloc] initWithBaseViewController:self.viewController];

  self.lensCoordinator =
      [[LensCoordinator alloc] initWithBaseViewController:self.viewController
                                                  browser:self.browser];
  [self.lensCoordinator start];

  /* NetExportCoordinator is created and started by a delegate method */

  /* passwordBreachCoordinator is created and started by a BrowserCommand */

  /* passwordProtectionCoordinator is created and started by a BrowserCommand */

  /* passwordSuggestionCoordinator is created and started by a BrowserCommand */

  /* ReadingListCoordinator is created and started by a BrowserCommand */

  /* RecentTabsCoordinator is created and started by a BrowserCommand */

  /* RepostFormCoordinator is created and started by a delegate method */

  // TODO(crbug.com/1298934): Should start when the Sad Tab UI appears.
  self.sadTabCoordinator =
      [[SadTabCoordinator alloc] initWithBaseViewController:self.viewController
                                                    browser:self.browser];
  [self.sadTabCoordinator setOverscrollDelegate:self.viewController];
  self.viewController.sadTabViewController =
      self.sadTabCoordinator.viewController;

  /* SharingCoordinator is created and started by an ActivityServiceCommand */

  self.storeKitCoordinator = [[StoreKitCoordinator alloc]
      initWithBaseViewController:self.viewController
                         browser:self.browser];

  self.addCreditCardCoordinator = [[AutofillAddCreditCardCoordinator alloc]
      initWithBaseViewController:self.viewController
                         browser:self.browser];

  if (base::FeatureList::IsEnabled(safe_browsing::kEnhancedProtection)) {
    self.safeBrowsingCoordinator = [[SafeBrowsingCoordinator alloc]
        initWithBaseViewController:self.viewController
                           browser:self.browser];
    [self.safeBrowsingCoordinator start];
  }

  self.textFragmentsCoordinator = [[TextFragmentsCoordinator alloc]
      initWithBaseViewController:self.viewController
                         browser:self.browser];
  [self.textFragmentsCoordinator start];

  // TODO(crbug.com/1334188): Refactor this coordinator so it doesn't directly
  // access the BVC's view.
  self.formInputAccessoryCoordinator = [[FormInputAccessoryCoordinator alloc]
      initWithBaseViewController:self.viewController
                         browser:self.browser];
  self.formInputAccessoryCoordinator.navigator = self;
  [self.formInputAccessoryCoordinator start];

  // TODO(crbug.com/1334188): Refactor this coordinator so it doesn't dirctly
  // access the BVC's view.
  self.infobarModalOverlayContainerCoordinator =
      [[OverlayContainerCoordinator alloc]
          initWithBaseViewController:self.viewController
                             browser:self.browser
                            modality:OverlayModality::kInfobarModal];
  [self.infobarModalOverlayContainerCoordinator start];
  self.viewController.infobarModalOverlayContainerViewController =
      self.infobarModalOverlayContainerCoordinator.viewController;

  // TODO(crbug.com/1334188): Refactor this coordinator so it doesn't directly
  // access the BVC's view.
  self.infobarBannerOverlayContainerCoordinator =
      [[OverlayContainerCoordinator alloc]
          initWithBaseViewController:self.viewController
                             browser:self.browser
                            modality:OverlayModality::kInfobarBanner];
  [self.infobarBannerOverlayContainerCoordinator start];
  self.viewController.infobarBannerOverlayContainerViewController =
      self.infobarBannerOverlayContainerCoordinator.viewController;
}

// Stops child coordinators.
- (void)stopChildCoordinators {
  [self.ARQuickLookCoordinator stop];
  self.ARQuickLookCoordinator = nil;

  [self.findBarCoordinator stop];
  self.findBarCoordinator = nil;

  [self.firstFollowCoordinator stop];
  self.firstFollowCoordinator = nil;

  [self.followIPHCoordinator stop];
  self.followIPHCoordinator = nil;

  [self.formInputAccessoryCoordinator stop];
  self.formInputAccessoryCoordinator = nil;

  [self.SafariDownloadCoordinator stop];
  self.SafariDownloadCoordinator = nil;

  [self.vcardCoordinator stop];
  self.vcardCoordinator = nil;

  [self.pageInfoCoordinator stop];
  self.pageInfoCoordinator = nil;

  [self.passKitCoordinator stop];
  self.passKitCoordinator = nil;

  [self.passwordBreachCoordinator stop];
  self.passwordBreachCoordinator = nil;

  [self.passwordProtectionCoordinator stop];
  self.passwordProtectionCoordinator = nil;

  [self.passwordSuggestionCoordinator stop];
  self.passwordSuggestionCoordinator = nil;

  self.printController = nil;

  [self.lensCoordinator stop];
  self.lensCoordinator = nil;

  [self.readingListCoordinator stop];
  self.readingListCoordinator = nil;

  [self.recentTabsCoordinator stop];
  self.recentTabsCoordinator = nil;

  [self.repostFormCoordinator stop];
  self.repostFormCoordinator = nil;

  // TODO(crbug.com/1298934): Should stop when the Sad Tab UI appears.
  [self.sadTabCoordinator stop];
  [self.sadTabCoordinator disconnect];
  self.sadTabCoordinator = nil;

  if (base::FeatureList::IsEnabled(safe_browsing::kEnhancedProtection)) {
    [self.safeBrowsingCoordinator stop];
    self.safeBrowsingCoordinator = nil;
  } else {
    DCHECK(!self.safeBrowsingCoordinator);
  }

  [self.sharingCoordinator stop];
  self.sharingCoordinator = nil;

  [self.storeKitCoordinator stop];
  self.storeKitCoordinator = nil;

  [self.textZoomCoordinator stop];
  self.textZoomCoordinator = nil;

  [self.addCreditCardCoordinator stop];
  self.addCreditCardCoordinator = nil;

  [self.infobarBannerOverlayContainerCoordinator stop];
  self.infobarBannerOverlayContainerCoordinator = nil;

  [self.infobarModalOverlayContainerCoordinator stop];
  self.infobarModalOverlayContainerCoordinator = nil;

  [self.defaultBrowserPromoCoordinator stop];
  self.defaultBrowserPromoCoordinator = nil;

  [self.tailoredPromoCoordinator stop];
  self.tailoredPromoCoordinator = nil;

  [self.textFragmentsCoordinator stop];
  self.textFragmentsCoordinator = nil;

  [self.nonModalPromoCoordinator stop];
  self.nonModalPromoCoordinator = nil;

  [self.netExportCoordinator stop];
  self.netExportCoordinator = nil;

  [_sendTabToSelfCoordinator stop];
  _sendTabToSelfCoordinator = nil;
}

// Starts mediators owned by this coordinator.
- (void)startMediators {
  // Cache frequently repeated property values to curb generated code bloat.
  ChromeBrowserState* browserState = self.browser->GetBrowserState();
  BrowserViewController* browserViewController = self.viewController;

  TabLifecycleDependencies dependencies;
  dependencies.prerenderService =
      PrerenderServiceFactory::GetForBrowserState(browserState);
  dependencies.sideSwipeController = _sideSwipeController;
  dependencies.downloadManagerCoordinator = self.downloadManagerCoordinator;
  dependencies.baseViewController = browserViewController;
  dependencies.commandDispatcher = self.browser->GetCommandDispatcher();
  dependencies.tabHelperDelegate = self;

  self.tabLifecycleMediator = [[TabLifecycleMediator alloc]
      initWithWebStateList:self.browser->GetWebStateList()
                  delegate:browserViewController
              dependencies:dependencies];

  self.viewController.reauthHandler =
      HandlerForProtocol(self.dispatcher, IncognitoReauthCommands);

  SceneState* sceneState =
      SceneStateBrowserAgent::FromBrowser(self.browser)->GetSceneState();

  self.viewController.nonModalPromoScheduler =
      [DefaultBrowserSceneAgent agentFromScene:sceneState].nonModalScheduler;
  self.viewController.nonModalPromoPresentationDelegate = self;

  if (browserState->IsOffTheRecord()) {
    IncognitoReauthSceneAgent* reauthAgent =
        [IncognitoReauthSceneAgent agentFromScene:sceneState];

    self.incognitoAuthMediator =
        [[IncognitoReauthMediator alloc] initWithConsumer:browserViewController
                                              reauthAgent:reauthAgent];
  }
}

#pragma mark - ActivityServiceCommands

- (void)sharePage {
  ActivityParams* params = [[ActivityParams alloc]
      initWithScenario:ActivityScenario::TabShareButton];

  // Exit fullscreen if needed to make sure that share button is visible.
  _fullscreenController->ExitFullscreen();

  UIBarButtonItem* anchor = nil;
  if ([self.viewController.activityServicePositioner
          respondsToSelector:@selector(barButtonItem)]) {
    anchor = self.viewController.activityServicePositioner.barButtonItem;
  }

  self.sharingCoordinator = [[SharingCoordinator alloc]
      initWithBaseViewController:self.viewController
                         browser:self.browser
                          params:params
                      originView:self.viewController.activityServicePositioner
                                     .sourceView
                      originRect:self.viewController.activityServicePositioner
                                     .sourceRect
                          anchor:anchor];
  [self.sharingCoordinator start];
}

- (void)shareHighlight:(ShareHighlightCommand*)command {
  ActivityParams* params =
      [[ActivityParams alloc] initWithURL:command.URL
                                    title:command.title
                           additionalText:command.selectedText
                                 scenario:ActivityScenario::SharedHighlight];

  self.sharingCoordinator =
      [[SharingCoordinator alloc] initWithBaseViewController:self.viewController
                                                     browser:self.browser
                                                      params:params
                                                  originView:command.sourceView
                                                  originRect:command.sourceRect
                                                      anchor:nil];
  [self.sharingCoordinator start];
}

#pragma mark - BrowserCoordinatorCommands

- (void)printTabWithBaseViewController:(UIViewController*)baseViewController {
  DCHECK(self.printController);
  web::WebState* webState =
      self.browser->GetWebStateList()->GetActiveWebState();
  [self.printController printWebState:webState
                   baseViewController:baseViewController];
}

- (void)printImage:(UIImage*)image
                 title:(NSString*)title
    baseViewController:(UIViewController*)baseViewController {
  DCHECK(self.printController);
  [self.printController printImage:image
                             title:title
                baseViewController:baseViewController];
}

- (void)showReadingList {
  self.readingListCoordinator = [[ReadingListCoordinator alloc]
      initWithBaseViewController:self.viewController
                         browser:self.browser];
  [self.readingListCoordinator start];
}

- (void)showBookmarksManager {
  [_bookmarkInteractionController presentBookmarks];
}

- (void)showReadingListIPH {
  [_bubblePresenter presentReadingListBottomToolbarTipBubble];
}

- (void)showFollowWhileBrowsingIPH {
  [_bubblePresenter presentFollowWhileBrowsingTipBubble];
}

- (void)showDefaultSiteViewIPH {
  [_bubblePresenter presentDefaultSiteViewTipBubble];
}

- (void)showDownloadsFolder {
  NSURL* URL = GetFilesAppUrl();
  if (!URL)
    return;

  [[UIApplication sharedApplication] openURL:URL
                                     options:@{}
                           completionHandler:nil];

  base::UmaHistogramEnumeration(
      "Download.OpenDownloads.PerProfileType",
      profile_metrics::GetBrowserProfileType(self.browser->GetBrowserState()));
}

- (void)showRecentTabs {
  // TODO(crbug.com/825431): If BVC's clearPresentedState is ever called (such
  // as in tearDown after a failed egtest), then this coordinator is left in a
  // started state even though its corresponding VC is no longer on screen.
  // That causes issues when the coordinator is started again and we destroy the
  // old mediator without disconnecting it first.  Temporarily work around these
  // issues by not having a long lived coordinator.  A longer-term solution will
  // require finding a way to stop this coordinator so that the mediator is
  // properly disconnected and destroyed and does not live longer than its
  // associated VC.
  if (self.recentTabsCoordinator) {
    [self.recentTabsCoordinator stop];
    self.recentTabsCoordinator = nil;
  }

  self.recentTabsCoordinator = [[RecentTabsCoordinator alloc]
      initWithBaseViewController:self.viewController
                         browser:self.browser];
  self.recentTabsCoordinator.loadStrategy = UrlLoadStrategy::NORMAL;
  [self.recentTabsCoordinator start];
}

- (void)showTranslate {
  ChromeBrowserState* browserState = self.browser->GetBrowserState();

  feature_engagement::Tracker* engagement_tracker =
      feature_engagement::TrackerFactory::GetForBrowserState(browserState);
  engagement_tracker->NotifyEvent(
      feature_engagement::events::kTriggeredTranslateInfobar);

  web::WebState* currentWebState =
      self.browser->GetWebStateList()->GetActiveWebState();
  DCHECK(currentWebState);

  ChromeIOSTranslateClient* translateClient =
      ChromeIOSTranslateClient::FromWebState(currentWebState);
  if (translateClient) {
    translate::TranslateManager* translateManager =
        translateClient->GetTranslateManager();
    DCHECK(translateManager);
    translateManager->ShowTranslateUI(/*auto_translate=*/true);
  }
}

- (void)showHelpPage {
  GURL helpUrl(l10n_util::GetStringUTF16(IDS_IOS_TOOLS_MENU_HELP_URL));
  UrlLoadParams params = UrlLoadParams::InNewTab(helpUrl);
  params.append_to = kCurrentTab;
  params.user_initiated = NO;
  params.in_incognito = self.browser->GetBrowserState()->IsOffTheRecord();
  UrlLoadingBrowserAgent::FromBrowser(self.browser)->Load(params);
}

- (void)showAddCreditCard {
  [self.addCreditCardCoordinator start];
}

- (void)showSendTabToSelfUI:(const GURL&)url title:(NSString*)title {
  DCHECK(!_sendTabToSelfCoordinator);
  _sendTabToSelfCoordinator = [[SendTabToSelfCoordinator alloc]
      initWithBaseViewController:self.viewController
                         browser:self.browser
                             url:url
                           title:title];
  [_sendTabToSelfCoordinator start];
}

- (void)hideSendTabToSelfUI {
  DCHECK(_sendTabToSelfCoordinator);
  [_sendTabToSelfCoordinator stop];
  _sendTabToSelfCoordinator = nil;
}

- (void)dismissBadgePopupMenu {
  [self.badgePopupMenuCoordinator stop];
}

#if !defined(NDEBUG)
- (void)viewSource {
  ViewSourceBrowserAgent* viewSourceAgent =
      ViewSourceBrowserAgent::FromBrowser(self.browser);
  viewSourceAgent->ViewSourceForActiveWebState();
}
#endif  // !defined(NDEBUG)

#pragma mark - DefaultPromoCommands

- (void)showTailoredPromoStaySafe {
  [self showTailoredPromoWithType:DefaultPromoTypeStaySafe];
}

- (void)showTailoredPromoMadeForIOS {
  [self showTailoredPromoWithType:DefaultPromoTypeMadeForIOS];
}

- (void)showTailoredPromoAllTabs {
  [self showTailoredPromoWithType:DefaultPromoTypeAllTabs];
}

- (void)showDefaultBrowserFullscreenPromo {
  if (!self.defaultBrowserPromoCoordinator) {
    self.defaultBrowserPromoCoordinator =
        [[DefaultBrowserPromoCoordinator alloc]
            initWithBaseViewController:self.viewController
                               browser:self.browser];
    self.defaultBrowserPromoCoordinator.handler = self;
  }
  [self.defaultBrowserPromoCoordinator start];
}

#pragma mark - DefaultBrowserPromoCommands

- (void)hidePromo {
  [self.defaultBrowserPromoCoordinator stop];
  self.defaultBrowserPromoCoordinator = nil;
  [self.tailoredPromoCoordinator stop];
  self.tailoredPromoCoordinator = nil;
}

#pragma mark - FeedCommands

- (void)showFirstFollowUIForWebChannel:(FollowedWebChannel*)followedWebChannel {
  self.firstFollowCoordinator = [[FirstFollowCoordinator alloc]
      initWithBaseViewController:self.viewController
                         browser:self.browser];
  self.firstFollowCoordinator.followedWebChannel = followedWebChannel;
  [self.firstFollowCoordinator start];
}

#pragma mark - FindInPageCommands

- (void)openFindInPage {
  if (!self.canShowFindBar)
    return;

  self.findBarCoordinator =
      [[FindBarCoordinator alloc] initWithBaseViewController:self.viewController
                                                     browser:self.browser];
  self.findBarCoordinator.presenter =
      self.viewController.toolbarAccessoryPresenter;
  self.findBarCoordinator.delegate = self;
  self.findBarCoordinator.presentationDelegate = self.viewController;

  if (self.viewController.toolbarAccessoryPresenter.isPresenting) {
    self.nextToolbarCoordinator = self.findBarCoordinator;
    [self closeTextZoom];
    return;
  }

  [self.findBarCoordinator start];
}

- (void)closeFindInPage {
  web::WebState* currentWebState =
      self.browser->GetWebStateList()->GetActiveWebState();

  if (currentWebState) {
    FindTabHelper* findTabHelper = FindTabHelper::FromWebState(currentWebState);
    if (findTabHelper->IsFindUIActive()) {
      findTabHelper->StopFinding();
    } else {
      [self.findBarCoordinator stop];
    }
  }
}

- (void)showFindUIIfActive {
  web::WebState* currentWebState =
      self.browser->GetWebStateList()->GetActiveWebState();
  auto* findHelper = FindTabHelper::FromWebState(currentWebState);
  if (findHelper && findHelper->IsFindUIActive() &&
      !self.findBarCoordinator.presenter.isPresenting) {
    [self.findBarCoordinator start];
  }
}

- (void)hideFindUI {
  [self.findBarCoordinator stop];
}

- (void)defocusFindInPage {
  [self.findBarCoordinator defocusFindBar];
}

- (void)searchFindInPage {
  web::WebState* currentWebState =
      self.browser->GetWebStateList()->GetActiveWebState();
  DCHECK(currentWebState);
  FindTabHelper* helper = FindTabHelper::FromWebState(currentWebState);
  helper->StartFinding([self.findBarCoordinator.findBarController searchTerm]);

  if (!self.browser->GetBrowserState()->IsOffTheRecord())
    helper->PersistSearchTerm();
}

- (void)findNextStringInPage {
  web::WebState* currentWebState =
      self.browser->GetWebStateList()->GetActiveWebState();
  DCHECK(currentWebState);
  // TODO(crbug.com/603524): Reshow find bar if necessary.
  FindTabHelper::FromWebState(currentWebState)
      ->ContinueFinding(FindTabHelper::FORWARD);
}

- (void)findPreviousStringInPage {
  web::WebState* currentWebState =
      self.browser->GetWebStateList()->GetActiveWebState();
  DCHECK(currentWebState);
  // TODO(crbug.com/603524): Reshow find bar if necessary.
  FindTabHelper::FromWebState(currentWebState)
      ->ContinueFinding(FindTabHelper::REVERSE);
}

#pragma mark - FindInPageCommands Helpers

- (BOOL)canShowFindBar {
  web::WebState* currentWebState =
      self.browser->GetWebStateList()->GetActiveWebState();
  if (!currentWebState) {
    return NO;
  }

  auto* helper = FindTabHelper::FromWebState(currentWebState);
  return (helper && helper->CurrentPageSupportsFindInPage() &&
          !helper->IsFindUIActive());
}

#pragma mark - PageInfoCommands

- (void)showPageInfo {
  PageInfoCoordinator* pageInfoCoordinator = [[PageInfoCoordinator alloc]
      initWithBaseViewController:self.viewController
                         browser:self.browser];
  pageInfoCoordinator.presentationProvider = self.viewController;
  self.pageInfoCoordinator = pageInfoCoordinator;
  [self.pageInfoCoordinator start];
}

- (void)hidePageInfo {
  [self.pageInfoCoordinator stop];
  self.pageInfoCoordinator = nil;
}

- (void)showSecurityHelpPage {
  UrlLoadParams params = UrlLoadParams::InNewTab(GURL(kPageInfoHelpCenterURL));
  params.in_incognito = self.browser->GetBrowserState()->IsOffTheRecord();
  UrlLoadingBrowserAgent::FromBrowser(self.browser)->Load(params);
  [self hidePageInfo];
}

#pragma mark - FormInputAccessoryCoordinatorNavigator

- (void)openPasswordSettings {
  [HandlerForProtocol(self.dispatcher, ApplicationCommands)
      showSavedPasswordsSettingsFromViewController:self.viewController
                                  showCancelButton:YES];
}

- (void)openAddressSettings {
  [HandlerForProtocol(self.dispatcher, ApplicationCommands)
      showProfileSettingsFromViewController:self.viewController];
}

- (void)openCreditCardSettings {
  [HandlerForProtocol(self.dispatcher, ApplicationCommands)
      showCreditCardSettings];
}

#pragma mark - RepostFormTabHelperDelegate

- (void)repostFormTabHelper:(RepostFormTabHelper*)helper
    presentRepostFormDialogForWebState:(web::WebState*)webState
                         dialogAtPoint:(CGPoint)location
                     completionHandler:(void (^)(BOOL))completion {
  self.repostFormCoordinator = [[RepostFormCoordinator alloc]
      initWithBaseViewController:self.viewController
                         browser:self.browser
                  dialogLocation:location
                        webState:webState
               completionHandler:completion];
  [self.repostFormCoordinator start];
}

- (void)repostFormTabHelperDismissRepostFormDialog:
    (RepostFormTabHelper*)helper {
  [self.repostFormCoordinator stop];
  self.repostFormCoordinator = nil;
}

#pragma mark - ToolbarAccessoryCoordinatorDelegate

- (void)toolbarAccessoryCoordinatorDidDismissUI:
    (ChromeCoordinator*)coordinator {
  if (!self.nextToolbarCoordinator) {
    return;
  }
  if (self.nextToolbarCoordinator == self.findBarCoordinator) {
    [self openFindInPage];
    self.nextToolbarCoordinator = nil;
  } else if (self.nextToolbarCoordinator == self.textZoomCoordinator) {
    [self openTextZoom];
    self.nextToolbarCoordinator = nil;
  }
}

#pragma mark - TextZoomCommands

- (void)openTextZoom {
  self.textZoomCoordinator = [[TextZoomCoordinator alloc]
      initWithBaseViewController:self.viewController
                         browser:self.browser];
  self.textZoomCoordinator.presenter =
      self.viewController.toolbarAccessoryPresenter;
  self.textZoomCoordinator.delegate = self;

  if (self.viewController.toolbarAccessoryPresenter.isPresenting) {
    self.nextToolbarCoordinator = self.textZoomCoordinator;
    [self closeFindInPage];
    return;
  }

  [self.textZoomCoordinator start];
}

- (void)closeTextZoom {
  if (!ios::provider::IsTextZoomEnabled()) {
    return;
  }

  web::WebState* currentWebState =
      self.browser->GetWebStateList()->GetActiveWebState();
  if (currentWebState) {
    FontSizeTabHelper* fontSizeTabHelper =
        FontSizeTabHelper::FromWebState(currentWebState);
    fontSizeTabHelper->SetTextZoomUIActive(false);
  }
  [self.textZoomCoordinator stop];
}

- (void)showTextZoomUIIfActive {
  web::WebState* currentWebState =
      self.browser->GetWebStateList()->GetActiveWebState();
  if (!currentWebState) {
    return;
  }

  FontSizeTabHelper* fontSizeTabHelper =
      FontSizeTabHelper::FromWebState(currentWebState);
  if (fontSizeTabHelper && fontSizeTabHelper->IsTextZoomUIActive() &&
      !self.textZoomCoordinator.presenter.isPresenting) {
    [self.textZoomCoordinator start];
  }
}

- (void)hideTextZoomUI {
  [self.textZoomCoordinator stop];
}

#pragma mark - URLLoadingServiceDelegate

- (void)animateOpenBackgroundTabFromParams:(const UrlLoadParams&)params
                                completion:(void (^)())completion {
  [self.viewController
      animateOpenBackgroundTabFromOriginPoint:params.origin_point
                                   completion:completion];
}

// TODO(crbug.com/906525) : Move WebStateListObserving out of
// BrowserCoordinator.
#pragma mark - WebStateListObserving

- (void)webStateList:(WebStateList*)webStateList
    didInsertWebState:(web::WebState*)webState
              atIndex:(int)index
           activating:(BOOL)activating {
  [self installDelegatesForWebState:webState];
}

- (void)webStateList:(WebStateList*)webStateList
    didReplaceWebState:(web::WebState*)oldWebState
          withWebState:(web::WebState*)newWebState
               atIndex:(int)index {
  [self uninstallDelegatesForWebState:oldWebState];
  [self installDelegatesForWebState:newWebState];
}

- (void)webStateList:(WebStateList*)webStateList
    didDetachWebState:(web::WebState*)webState
              atIndex:(int)index {
  [self uninstallDelegatesForWebState:webState];
}

// TODO(crbug.com/906525) : Move out of BrowserCoordinator along with
// WebStateListObserving.
#pragma mark - Private WebState management methods

// Adds observer for WebStateList.
- (void)addWebStateListObserver {
  _webStateListObserverBridge =
      std::make_unique<WebStateListObserverBridge>(self);
  _scopedWebStateListObservation = std::make_unique<
      base::ScopedObservation<WebStateList, WebStateListObserver>>(
      _webStateListObserverBridge.get());
  _scopedWebStateListObservation->Observe(self.browser->GetWebStateList());
}

// Removes observer for WebStateList.
- (void)removeWebStateListObserver {
  _scopedWebStateListObservation.reset();
  _webStateListObserverBridge.reset();
}

// Installs delegates for each WebState in WebStateList.
- (void)installDelegatesForAllWebStates {
  self.openInCoordinator =
      [[OpenInCoordinator alloc] initWithBaseViewController:self.viewController
                                                    browser:self.browser];
  [self.openInCoordinator start];

  for (int i = 0; i < self.browser->GetWebStateList()->count(); i++) {
    web::WebState* webState = self.browser->GetWebStateList()->GetWebStateAt(i);
    [self installDelegatesForWebState:webState];
  }
}

// Installs delegates for self.browser.
- (void)installDelegatesForBrowser {
  // The view controller should have been created.
  DCHECK(self.viewController);

  SyncErrorBrowserAgent::FromBrowser(self.browser)->SetUIProviders(self, self);

  WebStateDelegateBrowserAgent::FromBrowser(self.browser)
      ->SetUIProviders(self.contextMenuProvider,
                       self.formInputAccessoryCoordinator, self.viewController);

  UrlLoadingBrowserAgent* loadingAgent =
      UrlLoadingBrowserAgent::FromBrowser(self.browser);
  if (loadingAgent) {
    loadingAgent->SetDelegate(self);
  }

  id<ApplicationCommands> applicationCommandHandler = HandlerForProtocol(
      self.browser->GetCommandDispatcher(), ApplicationCommands);
  AccountConsistencyBrowserAgent::CreateForBrowser(
      self.browser, self.viewController, applicationCommandHandler);
}

// Installs delegates for self.browser->GetBrowserState()
- (void)installDelegatesForBrowserState {
  ChromeBrowserState* browserState = self.browser->GetBrowserState();
  if (browserState) {
    TextToSpeechPlaybackControllerFactory::GetInstance()
        ->GetForBrowserState(browserState)
        ->SetWebStateList(self.browser->GetWebStateList());
  }
}

// Uninstalls delegates for self.browser->GetBrowserState()
- (void)uninstallDelegatesForBrowserState {
  ChromeBrowserState* browserState = self.browser->GetBrowserState();
  if (browserState) {
    TextToSpeechPlaybackControllerFactory::GetInstance()
        ->GetForBrowserState(browserState)
        ->SetWebStateList(nullptr);
  }
}

// Uninstalls delegates for self.browser.
- (void)uninstallDelegatesForBrowser {
  UrlLoadingBrowserAgent* loadingAgent =
      UrlLoadingBrowserAgent::FromBrowser(self.browser);
  if (loadingAgent) {
    loadingAgent->SetDelegate(nil);
  }

  WebStateDelegateBrowserAgent::FromBrowser(self.browser)->ClearUIProviders();

  SyncErrorBrowserAgent::FromBrowser(self.browser)->ClearUIProviders();
}

// Uninstalls delegates for each WebState in WebStateList.
- (void)uninstallDelegatesForAllWebStates {
  // OpenInCoordinator monitors the webStateList and should be stopped.
  [self.openInCoordinator stop];
  self.openInCoordinator = nil;

  for (int i = 0; i < self.browser->GetWebStateList()->count(); i++) {
    web::WebState* webState = self.browser->GetWebStateList()->GetWebStateAt(i);
    [self uninstallDelegatesForWebState:webState];
  }
}

// Install delegates for `webState`.
- (void)installDelegatesForWebState:(web::WebState*)webState {
  if (AutofillTabHelper::FromWebState(webState)) {
    AutofillTabHelper::FromWebState(webState)->SetBaseViewController(
        self.viewController);
  }

  PassKitTabHelper::FromWebState(webState)->SetDelegate(
      self.passKitCoordinator);

  if (PrintTabHelper::FromWebState(webState)) {
    PrintTabHelper::FromWebState(webState)->set_printer(self.printController);
  }

  RepostFormTabHelper::FromWebState(webState)->SetDelegate(self);

  if (StoreKitTabHelper::FromWebState(webState)) {
    StoreKitTabHelper::FromWebState(webState)->SetLauncher(
        self.storeKitCoordinator);
  }

  if (FollowTabHelper::FromWebState(webState)) {
    FollowTabHelper::FromWebState(webState)->set_follow_iph_presenter(
        self.followIPHCoordinator);
  }

  if (CaptivePortalTabHelper::FromWebState(webState)) {
    TabInsertionBrowserAgent* insertionAgent =
        TabInsertionBrowserAgent::FromBrowser(self.browser);
    CaptivePortalTabHelper::FromWebState(webState)->SetTabInsertionBrowserAgent(
        insertionAgent);
  }
}

// Uninstalls delegates for `webState`.
- (void)uninstallDelegatesForWebState:(web::WebState*)webState {
  if (AutofillTabHelper::FromWebState(webState)) {
    AutofillTabHelper::FromWebState(webState)->SetBaseViewController(nil);
  }

  PassKitTabHelper::FromWebState(webState)->SetDelegate(nil);

  if (PrintTabHelper::FromWebState(webState)) {
    PrintTabHelper::FromWebState(webState)->set_printer(nil);
  }

  RepostFormTabHelper::FromWebState(webState)->SetDelegate(nil);

  if (StoreKitTabHelper::FromWebState(webState)) {
    StoreKitTabHelper::FromWebState(webState)->SetLauncher(nil);
  }

  if (FollowTabHelper::FromWebState(webState)) {
    FollowTabHelper::FromWebState(webState)->set_follow_iph_presenter(nil);
  }

  if (CaptivePortalTabHelper::FromWebState(webState)) {
    CaptivePortalTabHelper::FromWebState(webState)->SetTabInsertionBrowserAgent(
        nil);
  }
}

#pragma mark - PasswordBreachCommands

- (void)showPasswordBreachForLeakType:(CredentialLeakType)leakType {
  self.passwordBreachCoordinator = [[PasswordBreachCoordinator alloc]
      initWithBaseViewController:self.viewController
                         browser:self.browser
                        leakType:leakType];
  [self.passwordBreachCoordinator start];
}

#pragma mark - PasswordProtectionCommands

- (void)showPasswordProtectionWarning:(NSString*)warningText
                           completion:(void (^)(safe_browsing::WarningAction))
                                          completion {
  self.passwordProtectionCoordinator = [[PasswordProtectionCoordinator alloc]
      initWithBaseViewController:self.viewController
                         browser:self.browser
                     warningText:warningText];
  [self.passwordProtectionCoordinator startWithCompletion:completion];
}

#pragma mark - PasswordSuggestionCommands

- (void)showPasswordSuggestion:(NSString*)passwordSuggestion
               decisionHandler:(void (^)(BOOL accept))decisionHandler {
  self.passwordSuggestionCoordinator = [[PasswordSuggestionCoordinator alloc]
      initWithBaseViewController:self.viewController
                         browser:self.browser
              passwordSuggestion:passwordSuggestion
                 decisionHandler:decisionHandler];
  self.passwordSuggestionCoordinator.delegate = self;
  [self.passwordSuggestionCoordinator start];
}

#pragma mark - PolicyChangeCommands

- (void)showForceSignedOutPrompt {
  if (!self.enterprisePromptCoordinator) {
    self.enterprisePromptCoordinator = [[EnterprisePromptCoordinator alloc]
        initWithBaseViewController:self.viewController
                           browser:self.browser
                        promptType:EnterprisePromptTypeForceSignOut];
    self.enterprisePromptCoordinator.delegate = self;
  }
  [self.enterprisePromptCoordinator start];
}

- (void)showSyncDisabledPrompt {
  if (!self.enterprisePromptCoordinator) {
    self.enterprisePromptCoordinator = [[EnterprisePromptCoordinator alloc]
        initWithBaseViewController:self.viewController
                           browser:self.browser
                        promptType:EnterprisePromptTypeSyncDisabled];
    self.enterprisePromptCoordinator.delegate = self;
  }
  [self.enterprisePromptCoordinator start];
}

- (void)showRestrictAccountSignedOutPrompt {
  SceneState* sceneState =
      SceneStateBrowserAgent::FromBrowser(self.browser)->GetSceneState();
  if (sceneState.activationLevel >= SceneActivationLevelForegroundActive) {
    if (!self.enterprisePromptCoordinator) {
      self.enterprisePromptCoordinator = [[EnterprisePromptCoordinator alloc]
          initWithBaseViewController:self.viewController
                             browser:self.browser
                          promptType:
                              EnterprisePromptTypeRestrictAccountSignedOut];
      self.enterprisePromptCoordinator.delegate = self;
    }
    [self.enterprisePromptCoordinator start];
  } else {
    __weak BrowserCoordinator* weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 static_cast<int64_t>(1 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                     [weakSelf showRestrictAccountSignedOutPrompt];
                   });
  }
}

#pragma mark - DefaultBrowserPromoNonModalCommands

- (void)showDefaultBrowserNonModalPromo {
  self.nonModalPromoCoordinator =
      [[DefaultBrowserPromoNonModalCoordinator alloc]
          initWithBaseViewController:self.viewController
                             browser:self.browser];
  [self.nonModalPromoCoordinator start];
  self.nonModalPromoCoordinator.browser = self.browser;
  self.nonModalPromoCoordinator.baseViewController = self.viewController;
  [self.nonModalPromoCoordinator presentInfobarBannerAnimated:YES
                                                   completion:nil];
}

- (void)dismissDefaultBrowserNonModalPromoAnimated:(BOOL)animated {
  [self.nonModalPromoCoordinator dismissInfobarBannerAnimated:animated
                                                   completion:nil];
}

- (void)defaultBrowserNonModalPromoWasDismissed {
  SceneState* sceneState =
      SceneStateBrowserAgent::FromBrowser(self.browser)->GetSceneState();
  DefaultBrowserSceneAgent* agent =
      [DefaultBrowserSceneAgent agentFromScene:sceneState];
  [agent.nonModalScheduler logPromoWasDismissed];
  [self.nonModalPromoCoordinator stop];
  self.nonModalPromoCoordinator = nil;
}

#pragma mark - DefaultPromoNonModalPresentationDelegate

- (BOOL)defaultNonModalPromoIsShowing {
  return self.nonModalPromoCoordinator != nil;
}

- (void)dismissDefaultNonModalPromoAnimated:(BOOL)animated
                                 completion:(void (^)())completion {
  [self.nonModalPromoCoordinator dismissInfobarBannerAnimated:animated
                                                   completion:completion];
}

#pragma mark - EnterprisePromptCoordinatorDelegate

- (void)hideEnterprisePrompForLearnMore:(BOOL)learnMore {
  [self.enterprisePromptCoordinator stop];
  self.enterprisePromptCoordinator = nil;
}

#pragma mark - NetExportTabHelperDelegate

- (void)netExportTabHelper:(NetExportTabHelper*)tabHelper
    showMailComposerWithContext:(ShowMailComposerContext*)context {
  self.netExportCoordinator = [[NetExportCoordinator alloc]
      initWithBaseViewController:self.viewController
                         browser:self.browser
             mailComposerContext:context];

  [self.netExportCoordinator start];
}

#pragma mark - PasswordSuggestionCoordinatorDelegate

- (void)closePasswordSuggestion {
  [self.passwordSuggestionCoordinator stop];
  self.passwordSuggestionCoordinator = nil;
}

#pragma mark - PreloadControllerDelegate methods

- (web::WebState*)webStateToReplace {
  return self.browser ? self.browser->GetWebStateList()->GetActiveWebState()
                      : nullptr;
}

- (UIView*)webViewContainer {
  return self.browserContainerCoordinator.viewController.view;
}

#pragma mark - SyncPresenter (Public)

- (void)showReauthenticateSignin {
  [HandlerForProtocol(self.dispatcher, ApplicationCommands)
              showSignin:
                  [[ShowSigninCommand alloc]
                      initWithOperation:AuthenticationOperationReauthenticate
                            accessPoint:signin_metrics::AccessPoint::
                                            ACCESS_POINT_UNKNOWN]
      baseViewController:self.viewController];
}

- (void)showSyncPassphraseSettings {
  [HandlerForProtocol(self.dispatcher, ApplicationCommands)
      showSyncPassphraseSettingsFromViewController:self.viewController];
}

- (void)showGoogleServicesSettings {
  [HandlerForProtocol(self.dispatcher, ApplicationCommands)
      showGoogleServicesSettingsFromViewController:self.viewController];
}

- (void)showAccountSettings {
  [HandlerForProtocol(self.dispatcher, ApplicationCommands)
      showAccountsSettingsFromViewController:self.viewController];
}

- (void)showTrustedVaultReauthForFetchKeysWithTrigger:
    (syncer::TrustedVaultUserActionTriggerForUMA)trigger {
  [HandlerForProtocol(self.dispatcher, ApplicationCommands)
      showTrustedVaultReauthForFetchKeysFromViewController:self.viewController
                                                   trigger:trigger];
}

- (void)showTrustedVaultReauthForDegradedRecoverabilityWithTrigger:
    (syncer::TrustedVaultUserActionTriggerForUMA)trigger {
  [HandlerForProtocol(self.dispatcher, ApplicationCommands)
      showTrustedVaultReauthForDegradedRecoverabilityFromViewController:
          self.viewController
                                                                trigger:
                                                                    trigger];
}

#pragma mark - SigninPresenter

- (void)showSignin:(ShowSigninCommand*)command {
  [HandlerForProtocol(self.dispatcher, ApplicationCommands)
              showSignin:command
      baseViewController:self.viewController];
}

@end
