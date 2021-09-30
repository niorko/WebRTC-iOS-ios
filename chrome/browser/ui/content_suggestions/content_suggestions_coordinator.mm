// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_coordinator.h"

#import "base/ios/ios_util.h"
#include "base/mac/foundation_util.h"
#include "base/metrics/user_metrics.h"
#include "base/metrics/user_metrics_action.h"
#include "base/strings/sys_string_conversions.h"
#import "components/feature_engagement/public/event_constants.h"
#import "components/feature_engagement/public/tracker.h"
#include "components/feed/core/v2/public/ios/pref_names.h"
#include "components/ntp_tiles/most_visited_sites.h"
#include "components/prefs/pref_service.h"
#import "components/search_engines/template_url.h"
#import "components/search_engines/template_url_service.h"
#import "ios/chrome/app/application_delegate/app_state.h"
#include "ios/chrome/app/tests_hook.h"
#include "ios/chrome/browser/browser_state/chrome_browser_state.h"
#import "ios/chrome/browser/drag_and_drop/url_drag_drop_handler.h"
#include "ios/chrome/browser/favicon/ios_chrome_large_icon_cache_factory.h"
#include "ios/chrome/browser/favicon/ios_chrome_large_icon_service_factory.h"
#include "ios/chrome/browser/favicon/large_icon_cache.h"
#import "ios/chrome/browser/feature_engagement/tracker_factory.h"
#import "ios/chrome/browser/main/browser.h"
#include "ios/chrome/browser/ntp_tiles/ios_most_visited_sites_factory.h"
#import "ios/chrome/browser/policy/policy_util.h"
#include "ios/chrome/browser/pref_names.h"
#include "ios/chrome/browser/reading_list/reading_list_model_factory.h"
#import "ios/chrome/browser/search_engines/template_url_service_factory.h"
#import "ios/chrome/browser/signin/authentication_service.h"
#import "ios/chrome/browser/signin/authentication_service_factory.h"
#import "ios/chrome/browser/ui/activity_services/activity_params.h"
#import "ios/chrome/browser/ui/alert_coordinator/action_sheet_coordinator.h"
#import "ios/chrome/browser/ui/commands/application_commands.h"
#import "ios/chrome/browser/ui/commands/browser_commands.h"
#import "ios/chrome/browser/ui/commands/command_dispatcher.h"
#import "ios/chrome/browser/ui/commands/omnibox_commands.h"
#import "ios/chrome/browser/ui/commands/open_new_tab_command.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_most_visited_item.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_constants.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_data_sink.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_feature.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_header_commands.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_header_synchronizer.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_header_view_controller.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_mediator.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_menu_provider.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_view_controller.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_view_controller_audience.h"
#import "ios/chrome/browser/ui/content_suggestions/discover_feed_header_changing.h"
#import "ios/chrome/browser/ui/content_suggestions/discover_feed_menu_commands.h"
#import "ios/chrome/browser/ui/content_suggestions/discover_feed_metrics_recorder.h"
#import "ios/chrome/browser/ui/content_suggestions/ntp_home_constant.h"
#import "ios/chrome/browser/ui/content_suggestions/ntp_home_mediator.h"
#import "ios/chrome/browser/ui/content_suggestions/ntp_home_metrics.h"
#import "ios/chrome/browser/ui/content_suggestions/theme_change_delegate.h"
#import "ios/chrome/browser/ui/main/scene_state.h"
#import "ios/chrome/browser/ui/main/scene_state_browser_agent.h"
#import "ios/chrome/browser/ui/menu/browser_action_factory.h"
#import "ios/chrome/browser/ui/menu/menu_histograms.h"
#import "ios/chrome/browser/ui/ntp/new_tab_page_commands.h"
#import "ios/chrome/browser/ui/ntp/new_tab_page_constants.h"
#import "ios/chrome/browser/ui/ntp/new_tab_page_feature.h"
#import "ios/chrome/browser/ui/ntp/new_tab_page_header_constants.h"
#import "ios/chrome/browser/ui/ntp/notification_promo_whats_new.h"
#import "ios/chrome/browser/ui/settings/utils/pref_backed_boolean.h"
#import "ios/chrome/browser/ui/sharing/sharing_coordinator.h"
#import "ios/chrome/browser/ui/start_surface/start_surface_features.h"
#import "ios/chrome/browser/ui/start_surface/start_surface_recent_tab_browser_agent.h"
#import "ios/chrome/browser/ui/start_surface/start_surface_util.h"
#include "ios/chrome/browser/ui/ui_feature_flags.h"
#import "ios/chrome/browser/ui/util/named_guide.h"
#import "ios/chrome/browser/ui/util/uikit_ui_util.h"
#import "ios/chrome/browser/url_loading/url_loading_browser_agent.h"
#import "ios/chrome/browser/url_loading/url_loading_params.h"
#import "ios/chrome/browser/web_state_list/web_state_list.h"
#include "ios/chrome/grit/ios_strings.h"
#import "ios/public/provider/chrome/browser/chrome_browser_provider.h"
#import "ios/public/provider/chrome/browser/discover_feed/discover_feed_provider.h"
#import "ios/web/public/web_state.h"
#import "ui/base/l10n/l10n_util_mac.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@interface ContentSuggestionsCoordinator () <
    AppStateObserver,
    ContentSuggestionsHeaderCommands,
    ContentSuggestionsMenuProvider,
    ContentSuggestionsViewControllerAudience,
    DiscoverFeedMenuCommands,
    ThemeChangeDelegate,
    URLDropDelegate> {
  // Observer bridge for mediator to listen to
  // StartSurfaceRecentTabObserverBridge.
  std::unique_ptr<StartSurfaceRecentTabObserverBridge> _startSurfaceObserver;
}

@property(nonatomic, strong)
    ContentSuggestionsViewController* suggestionsViewController;
@property(nonatomic, strong)
    ContentSuggestionsMediator* contentSuggestionsMediator;
@property(nonatomic, strong)
    ContentSuggestionsHeaderSynchronizer* headerCollectionInteractionHandler;
@property(nonatomic, strong) UIView* discoverFeedHeaderMenuButton;
@property(nonatomic, strong) URLDragDropHandler* dragDropHandler;
@property(nonatomic, strong) ActionSheetCoordinator* alertCoordinator;
// Redefined as readwrite.
@property(nonatomic, strong, readwrite)
    ContentSuggestionsHeaderViewController* headerController;
@property(nonatomic, strong) PrefBackedBoolean* contentSuggestionsExpanded;
@property(nonatomic, assign) BOOL contentSuggestionsEnabled;
// Delegate for handling Discover feed header UI changes.
@property(nonatomic, weak) id<DiscoverFeedHeaderChanging>
    discoverFeedHeaderDelegate;
// Authentication Service for the user's signed-in state.
@property(nonatomic, assign) AuthenticationService* authService;
// Coordinator in charge of handling sharing use cases.
@property(nonatomic, strong) SharingCoordinator* sharingCoordinator;

@end

@implementation ContentSuggestionsCoordinator

- (void)start {
  DCHECK(self.browser);
  DCHECK(self.ntpMediator);
  if (self.started) {
    // Prevent this coordinator from being started twice in a row
    return;
  }

  _started = YES;

  // Make sure that the omnibox is unfocused to prevent having it visually
  // focused while the NTP is just created (with the fakebox visible).
  id<OmniboxCommands> omniboxCommandHandler =
      HandlerForProtocol(self.browser->GetCommandDispatcher(), OmniboxCommands);
  [omniboxCommandHandler cancelOmniboxEdit];

  self.authService = AuthenticationServiceFactory::GetForBrowserState(
      self.browser->GetBrowserState());

  PrefService* prefs =
      ChromeBrowserState::FromBrowserState(self.browser->GetBrowserState())
          ->GetPrefs();

  self.contentSuggestionsEnabled =
      prefs->GetBoolean(prefs::kArticlesForYouEnabled) &&
      prefs->GetBoolean(prefs::kNTPContentSuggestionsEnabled);
  self.contentSuggestionsExpanded = [[PrefBackedBoolean alloc]
      initWithPrefService:prefs
                 prefName:feed::prefs::kArticlesListVisible];
  if (self.contentSuggestionsEnabled) {
    if ([self.contentSuggestionsExpanded value]) {
      ntp_home::RecordNTPImpression(ntp_home::REMOTE_SUGGESTIONS);
    } else {
      ntp_home::RecordNTPImpression(ntp_home::REMOTE_COLLAPSED);
    }
  } else {
    ntp_home::RecordNTPImpression(ntp_home::LOCAL_SUGGESTIONS);
  }

  self.headerController = [[ContentSuggestionsHeaderViewController alloc] init];
  // TODO(crbug.com/1045047): Use HandlerForProtocol after commands protocol
  // clean up.
  self.headerController.dispatcher =
      static_cast<id<ApplicationCommands, BrowserCommands, OmniboxCommands,
                     FakeboxFocuser>>(self.browser->GetCommandDispatcher());
  self.headerController.commandHandler = self;
  self.headerController.delegate = self.ntpMediator;

  self.headerController.readingListModel =
      ReadingListModelFactory::GetForBrowserState(
          self.browser->GetBrowserState());
  self.headerController.toolbarDelegate = self.toolbarDelegate;

  // Only handle app state for the new First Run UI.
  if (base::FeatureList::IsEnabled(kEnableFREUIModuleIOS)) {
    SceneState* sceneState =
        SceneStateBrowserAgent::FromBrowser(self.browser)->GetSceneState();
    AppState* appState = sceneState.appState;
    [appState addObserver:self];

    // Do not focus on omnibox for voice over if there are other screens to
    // show.
    if (appState.initStage < InitStageFinal) {
      self.headerController.focusOmniboxWhenViewAppears = NO;
    }
  }

  favicon::LargeIconService* largeIconService =
      IOSChromeLargeIconServiceFactory::GetForBrowserState(
          self.browser->GetBrowserState());
  LargeIconCache* cache = IOSChromeLargeIconCacheFactory::GetForBrowserState(
      self.browser->GetBrowserState());
  std::unique_ptr<ntp_tiles::MostVisitedSites> mostVisitedFactory =
      IOSMostVisitedSitesFactory::NewForBrowserState(
          self.browser->GetBrowserState());
  ReadingListModel* readingListModel =
      ReadingListModelFactory::GetForBrowserState(
          self.browser->GetBrowserState());

  TemplateURLService* templateURLService =
      ios::TemplateURLServiceFactory::GetForBrowserState(
          self.browser->GetBrowserState());
  const TemplateURL* defaultURL =
      templateURLService->GetDefaultSearchProvider();
  BOOL isGoogleDefaultSearchProvider =
      defaultURL &&
      defaultURL->GetEngineType(templateURLService->search_terms_data()) ==
          SEARCH_ENGINE_GOOGLE;

  self.contentSuggestionsMediator = [[ContentSuggestionsMediator alloc]
           initWithLargeIconService:largeIconService
                     largeIconCache:cache
                    mostVisitedSite:std::move(mostVisitedFactory)
                   readingListModel:readingListModel
                        prefService:prefs
      isGoogleDefaultSearchProvider:isGoogleDefaultSearchProvider];
  self.contentSuggestionsMediator.commandHandler = self.ntpMediator;
  self.contentSuggestionsMediator.headerProvider = self.headerController;
  self.contentSuggestionsMediator.discoverFeedDelegate =
      self.discoverFeedDelegate;
  self.contentSuggestionsMediator.webStateList =
      self.browser->GetWebStateList();
  [self configureStartSurfaceIfNeeded];

  self.headerController.promoCanShow =
      [self.contentSuggestionsMediator notificationPromo]->CanShow();

  self.suggestionsViewController = [[ContentSuggestionsViewController alloc]
      initWithStyle:CollectionViewControllerStyleDefault];
  [self.suggestionsViewController
      setDataSource:self.contentSuggestionsMediator];
  self.suggestionsViewController.suggestionCommandHandler = self.ntpMediator;
  self.suggestionsViewController.audience = self;
  self.suggestionsViewController.themeChangeDelegate = self;
  id<SnackbarCommands> dispatcher =
      static_cast<id<SnackbarCommands>>(self.browser->GetCommandDispatcher());
  self.suggestionsViewController.dispatcher = dispatcher;
  self.suggestionsViewController.discoverFeedMenuHandler = self;
  self.suggestionsViewController.bubblePresenter = self.bubblePresenter;

  self.discoverFeedHeaderDelegate =
      self.suggestionsViewController.discoverFeedHeaderDelegate;
  [self.discoverFeedHeaderDelegate
      changeDiscoverFeedHeaderVisibility:[self.contentSuggestionsExpanded
                                                 value]];
  self.suggestionsViewController.contentSuggestionsEnabled =
      self.contentSuggestionsEnabled;

  if (@available(iOS 13.0, *)) {
    self.suggestionsViewController.menuProvider = self;
  }

  self.ntpMediator.consumer = self.headerController;
  // TODO(crbug.com/1045047): Use HandlerForProtocol after commands protocol
  // clean up.
  self.ntpMediator.dispatcher =
      static_cast<id<ApplicationCommands, BrowserCommands, OmniboxCommands,
                     SnackbarCommands>>(self.browser->GetCommandDispatcher());
  self.ntpMediator.NTPMetrics = [[NTPHomeMetrics alloc]
      initWithBrowserState:self.browser->GetBrowserState()
                  webState:self.webState];
  self.ntpMediator.suggestionsViewController = self.suggestionsViewController;
  self.ntpMediator.suggestionsMediator = self.contentSuggestionsMediator;
  [self.ntpMediator setUp];
  self.ntpMediator.discoverFeedMetrics = self.discoverFeedMetricsRecorder;

  [self.suggestionsViewController addChildViewController:self.headerController];
  [self.headerController
      didMoveToParentViewController:self.suggestionsViewController];

  // TODO(crbug.com/1114792): Remove header provider and use refactored header
  // synchronizer instead.
  self.suggestionsViewController.headerProvider = self.headerController;

  self.suggestionsViewController.collectionView.accessibilityIdentifier =
      kContentSuggestionsCollectionIdentifier;

  self.dragDropHandler = [[URLDragDropHandler alloc] init];
  self.dragDropHandler.dropDelegate = self;
  [self.suggestionsViewController.collectionView
      addInteraction:[[UIDropInteraction alloc]
                         initWithDelegate:self.dragDropHandler]];
}

- (void)stop {
  [self.ntpMediator shutdown];
  self.ntpMediator = nil;
  // Reset the observer bridge object before setting
  // |contentSuggestionsMediator| nil.
  if (_startSurfaceObserver) {
    StartSurfaceRecentTabBrowserAgent::FromBrowser(self.browser)
        ->RemoveObserver(_startSurfaceObserver.get());
    _startSurfaceObserver.reset();
  }
  [self.contentSuggestionsMediator disconnect];
  self.contentSuggestionsMediator = nil;
  self.suggestionsViewController = nil;
  [self.sharingCoordinator stop];
  self.sharingCoordinator = nil;
  self.headerController = nil;
  self.contentSuggestionsExpanded = nil;
  _started = NO;
}

- (UIViewController*)viewController {
  return self.suggestionsViewController;
}

- (void)constrainDiscoverHeaderMenuButtonNamedGuide {
  NamedGuide* menuButtonGuide =
      [NamedGuide guideWithName:kDiscoverFeedHeaderMenuGuide
                           view:self.discoverFeedHeaderMenuButton];

  menuButtonGuide.constrainedView = self.discoverFeedHeaderMenuButton;
}

#pragma mark - ContentSuggestionsViewControllerAudience

- (void)promoShown {
  NotificationPromoWhatsNew* notificationPromo =
      [self.contentSuggestionsMediator notificationPromo];
  notificationPromo->HandleViewed();
  [self.headerController setPromoCanShow:notificationPromo->CanShow()];
}

- (void)discoverHeaderMenuButtonShown:(UIView*)menuButton {
  _discoverFeedHeaderMenuButton = menuButton;
}

- (void)viewDidDisappear {
  if (ShouldShowReturnToMostRecentTabForStartSurface()) {
    [self.contentSuggestionsMediator hideRecentTabTile];
  }
}


#pragma mark - ThemeChangeDelegate

- (void)handleThemeChange {
  if (IsDiscoverFeedEnabled()) {
    ios::GetChromeBrowserProvider().GetDiscoverFeedProvider()->UpdateTheme();
  }
}

#pragma mark - URLDropDelegate

- (BOOL)canHandleURLDropInView:(UIView*)view {
  return YES;
}

- (void)view:(UIView*)view didDropURL:(const GURL&)URL atPoint:(CGPoint)point {
  UrlLoadingBrowserAgent::FromBrowser(self.browser)
      ->Load(UrlLoadParams::InCurrentTab(URL));
}

#pragma mark - DiscoverFeedMenuCommands

- (void)openDiscoverFeedMenu {
  [self.alertCoordinator stop];
  self.alertCoordinator = nil;

  self.alertCoordinator = [[ActionSheetCoordinator alloc]
      initWithBaseViewController:self.suggestionsViewController
                         browser:self.browser
                           title:nil
                         message:nil
                            rect:self.discoverFeedHeaderMenuButton.frame
                            view:self.discoverFeedHeaderMenuButton.superview];
  __weak ContentSuggestionsCoordinator* weakSelf = self;

  if ([self.contentSuggestionsExpanded value]) {
    [self.alertCoordinator
        addItemWithTitle:l10n_util::GetNSString(
                             IDS_IOS_DISCOVER_FEED_MENU_TURN_OFF_ITEM)
                  action:^{
                    [weakSelf setDiscoverFeedVisible:NO];
                    [weakSelf.ntpCommandHandler updateNTPForDiscoverFeed];
                  }
                   style:UIAlertActionStyleDestructive];
  } else {
    [self.alertCoordinator
        addItemWithTitle:l10n_util::GetNSString(
                             IDS_IOS_DISCOVER_FEED_MENU_TURN_ON_ITEM)
                  action:^{
                    [weakSelf setDiscoverFeedVisible:YES];
                    [weakSelf.ntpCommandHandler updateNTPForDiscoverFeed];
                  }
                   style:UIAlertActionStyleDefault];
  }

  if (self.authService->HasPrimaryIdentity(signin::ConsentLevel::kSignin)) {
    [self.alertCoordinator
        addItemWithTitle:l10n_util::GetNSString(
                             IDS_IOS_DISCOVER_FEED_MENU_MANAGE_ACTIVITY_ITEM)
                  action:^{
                    [weakSelf.ntpMediator handleFeedManageActivityTapped];
                  }
                   style:UIAlertActionStyleDefault];

    [self.alertCoordinator
        addItemWithTitle:l10n_util::GetNSString(
                             IDS_IOS_DISCOVER_FEED_MENU_MANAGE_INTERESTS_ITEM)
                  action:^{
                    [weakSelf.ntpMediator handleFeedManageInterestsTapped];
                  }
                   style:UIAlertActionStyleDefault];
  }

  [self.alertCoordinator
      addItemWithTitle:l10n_util::GetNSString(
                           IDS_IOS_DISCOVER_FEED_MENU_LEARN_MORE_ITEM)
                action:^{
                  [weakSelf.ntpMediator handleFeedLearnMoreTapped];
                }
                 style:UIAlertActionStyleDefault];
  [self.alertCoordinator start];
}

- (void)notifyFeedLoadedForHeaderMenu {
  feature_engagement::TrackerFactory::GetForBrowserState(
      self.browser->GetBrowserState())
      ->NotifyEvent(feature_engagement::events::kDiscoverFeedLoaded);
}

#pragma mark - ContentSuggestionsHeaderCommands

- (void)prepareForVoiceSearchPresentation {
  [self.ntpMediator dismissModals];
}

- (void)updateForHeaderSizeChange {
  [self.ntpCommandHandler updateDiscoverFeedLayout];
}

- (void)updateForLocationBarResignedFirstResponder {
  // TODO(crbug.com/1200303): Check if doing this is actually needed.
  [self.ntpMediator dismissModals];
}

#pragma mark - Public methods

- (UIView*)view {
  return self.suggestionsViewController.view;
}

- (void)dismissModals {
  [self.ntpMediator dismissModals];
}

- (void)stopScrolling {
  UIScrollView* scrollView = self.suggestionsViewController.collectionView;
  [scrollView setContentOffset:scrollView.contentOffset animated:NO];
}

- (UIEdgeInsets)contentInset {
  return self.suggestionsViewController.collectionView.contentInset;
}

- (CGPoint)contentOffset {
  CGPoint collectionOffset =
      self.suggestionsViewController.collectionView.contentOffset;
  collectionOffset.y -=
      self.headerCollectionInteractionHandler.collectionShiftingOffset;
  return collectionOffset;
}

- (void)reload {
  [self.contentSuggestionsMediator.dataSink reloadAllData];
}

- (void)locationBarDidBecomeFirstResponder {
  [self.ntpMediator locationBarDidBecomeFirstResponder];
}

- (void)locationBarDidResignFirstResponder {
  [self.ntpMediator locationBarDidResignFirstResponder];
}

#pragma mark - ContentSuggestionsMenuProvider

- (UIContextMenuConfiguration*)contextMenuConfigurationForItem:
                                   (ContentSuggestionsMostVisitedItem*)item
                                                      fromView:(UIView*)view {
  __weak __typeof(self) weakSelf = self;

  UIContextMenuActionProvider actionProvider =
      ^(NSArray<UIMenuElement*>* suggestedActions) {
        if (!weakSelf) {
          // Return an empty menu.
          return [UIMenu menuWithTitle:@"" children:@[]];
        }

        ContentSuggestionsCoordinator* strongSelf = weakSelf;

        // Record that this context menu was shown to the user.
        RecordMenuShown(MenuScenario::kMostVisitedEntry);

        BrowserActionFactory* actionFactory = [[BrowserActionFactory alloc]
            initWithBrowser:strongSelf.browser
                   scenario:MenuScenario::kMostVisitedEntry];

        NSMutableArray<UIMenuElement*>* menuElements =
            [[NSMutableArray alloc] init];

        NSIndexPath* indexPath =
            [self.suggestionsViewController.collectionViewModel
                indexPathForItem:item];

        [menuElements addObject:[actionFactory actionToOpenInNewTabWithBlock:^{
                        [weakSelf.ntpMediator
                            openNewTabWithMostVisitedItem:item
                                                incognito:NO
                                                  atIndex:indexPath.item];
                      }]];

        UIAction* incognitoAction =
            [actionFactory actionToOpenInNewIncognitoTabWithBlock:^{
              [weakSelf.ntpMediator
                  openNewTabWithMostVisitedItem:item
                                      incognito:YES
                                        atIndex:indexPath.item];
            }];

        if (IsIncognitoModeDisabled(
                self.browser->GetBrowserState()->GetPrefs())) {
          // Disable the "Open in Incognito" option if the incognito mode is
          // disabled.
          incognitoAction.attributes = UIMenuElementAttributesDisabled;
        }

        [menuElements addObject:incognitoAction];

        if (base::ios::IsMultipleScenesSupported()) {
          UIAction* newWindowAction = [actionFactory
              actionToOpenInNewWindowWithURL:item.URL
                              activityOrigin:
                                  WindowActivityContentSuggestionsOrigin];
          [menuElements addObject:newWindowAction];
        }

        [menuElements addObject:[actionFactory actionToCopyURL:item.URL]];

        [menuElements addObject:[actionFactory actionToShareWithBlock:^{
                        [weakSelf shareURL:item.URL
                                     title:item.title
                                  fromView:view];
                      }]];

        [menuElements addObject:[actionFactory actionToRemoveWithBlock:^{
                        [weakSelf.ntpMediator removeMostVisited:item];
                      }]];

        return [UIMenu menuWithTitle:@"" children:menuElements];
      };
  return
      [UIContextMenuConfiguration configurationWithIdentifier:nil
                                              previewProvider:nil
                                               actionProvider:actionProvider];
}

#pragma mark - Helpers

- (void)configureStartSurfaceIfNeeded {
  SceneState* scene =
      SceneStateBrowserAgent::FromBrowser(self.browser)->GetSceneState();
  if (!scene.modifytVisibleNTPForStartSurface)
    return;

  if (ShouldShowReturnToMostRecentTabForStartSurface()) {
    base::RecordAction(
        base::UserMetricsAction("IOS.StartSurface.ShowReturnToRecentTabTile"));
    web::WebState* most_recent_tab =
        StartSurfaceRecentTabBrowserAgent::FromBrowser(self.browser)
            ->most_recent_tab();
    DCHECK(most_recent_tab);
    NSString* time_label = GetRecentTabTileTimeLabelForSceneState(scene);
    [self.contentSuggestionsMediator
        configureMostRecentTabItemWithWebState:most_recent_tab
                                     timeLabel:time_label];
    if (!_startSurfaceObserver) {
      _startSurfaceObserver =
          std::make_unique<StartSurfaceRecentTabObserverBridge>(
              self.contentSuggestionsMediator);
      StartSurfaceRecentTabBrowserAgent::FromBrowser(self.browser)
          ->AddObserver(_startSurfaceObserver.get());
    }
  }
  if (ShouldShrinkLogoForStartSurface()) {
    base::RecordAction(base::UserMetricsAction("IOS.StartSurface.ShrinkLogo"));
  }
  if (ShouldHideShortcutsForStartSurface()) {
    base::RecordAction(
        base::UserMetricsAction("IOS.StartSurface.HideShortcuts"));
  }
  scene.modifytVisibleNTPForStartSurface = NO;
}

// Triggers the URL sharing flow for the given |URL| and |title|, with the
// origin |view| representing the UI component for that URL.
- (void)shareURL:(const GURL&)URL
           title:(NSString*)title
        fromView:(UIView*)view {
  ActivityParams* params =
      [[ActivityParams alloc] initWithURL:URL
                                    title:title
                                 scenario:ActivityScenario::MostVisitedEntry];
  self.sharingCoordinator =
      [[SharingCoordinator alloc] initWithBaseViewController:self.viewController
                                                     browser:self.browser
                                                      params:params
                                                  originView:view];
  [self.sharingCoordinator start];
}

// Toggles Discover feed visibility between hidden or expanded.
- (void)setDiscoverFeedVisible:(BOOL)visible {
  [self.contentSuggestionsExpanded setValue:visible];
  [self.discoverFeedHeaderDelegate changeDiscoverFeedHeaderVisibility:visible];
  [self.contentSuggestionsMediator reloadAllData];
  [self.discoverFeedMetricsRecorder
      recordDiscoverFeedVisibilityChanged:visible];
}

#pragma mark - AppStateObserver

- (void)appState:(AppState*)appState
    didTransitionFromInitStage:(InitStage)previousInitStage {
  if (base::FeatureList::IsEnabled(kEnableFREUIModuleIOS)) {
    if (previousInitStage == InitStageFirstRun) {
      self.headerController.focusOmniboxWhenViewAppears = YES;
      [self.headerController focusAccessibilityOnOmnibox];

      [appState removeObserver:self];
    }
  }
}

@end
