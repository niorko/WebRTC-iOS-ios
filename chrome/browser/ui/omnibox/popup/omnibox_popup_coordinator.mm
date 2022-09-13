// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/omnibox/popup/omnibox_popup_coordinator.h"

#import "base/feature_list.h"
#import "components/image_fetcher/core/image_data_fetcher.h"
#import "components/omnibox/browser/autocomplete_result.h"
#import "components/omnibox/common/omnibox_features.h"
#import "components/search_engines/template_url_service.h"
#import "ios/chrome/browser/browser_state/chrome_browser_state.h"
#import "ios/chrome/browser/favicon/ios_chrome_favicon_loader_factory.h"
#import "ios/chrome/browser/main/browser.h"
#import "ios/chrome/browser/search_engines/template_url_service_factory.h"
#import "ios/chrome/browser/ui/commands/application_commands.h"
#import "ios/chrome/browser/ui/commands/command_dispatcher.h"
#import "ios/chrome/browser/ui/commands/omnibox_commands.h"
#import "ios/chrome/browser/ui/main/default_browser_scene_agent.h"
#import "ios/chrome/browser/ui/main/scene_state_browser_agent.h"
#import "ios/chrome/browser/ui/ntp/ntp_util.h"
#import "ios/chrome/browser/ui/omnibox/omnibox_ui_features.h"
#import "ios/chrome/browser/ui/omnibox/popup/content_providing.h"
#import "ios/chrome/browser/ui/omnibox/popup/omnibox_pedal_annotator.h"
#import "ios/chrome/browser/ui/omnibox/popup/omnibox_popup_container_view.h"
#import "ios/chrome/browser/ui/omnibox/popup/omnibox_popup_mediator.h"
#import "ios/chrome/browser/ui/omnibox/popup/omnibox_popup_presenter.h"
#import "ios/chrome/browser/ui/omnibox/popup/omnibox_popup_view_controller.h"
#import "ios/chrome/browser/ui/omnibox/popup/omnibox_popup_view_ios.h"
#import "ios/chrome/browser/ui/omnibox/popup/pedal_section_extractor.h"
#import "ios/chrome/browser/ui/omnibox/popup/popup_swift.h"
#import "ios/chrome/browser/ui/ui_feature_flags.h"
#import "ios/chrome/browser/ui/util/ui_util.h"
#import "ios/chrome/browser/web_state_list/web_state_list.h"
#import "services/network/public/cpp/shared_url_loader_factory.h"
#import "ui/base/device_form_factor.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@interface OmniboxPopupCoordinator () {
  std::unique_ptr<OmniboxPopupViewIOS> _popupView;
}

@property(nonatomic, strong)
    UIViewController<ContentProviding>* popupViewController;
@property(nonatomic, strong) OmniboxPopupMediator* mediator;
@property(nonatomic, strong) PopupModel* model;
@property(nonatomic, strong) PopupUIConfiguration* uiConfiguration;

@end

@implementation OmniboxPopupCoordinator

@synthesize mediator = _mediator;
@synthesize popupViewController = _popupViewController;

#pragma mark - Public

- (instancetype)
    initWithBaseViewController:(UIViewController*)viewController
                       browser:(Browser*)browser
                     popupView:(std::unique_ptr<OmniboxPopupViewIOS>)popupView {
  self = [super initWithBaseViewController:nil browser:browser];
  if (self) {
    _popupView = std::move(popupView);
    self.pedalExtractor = [[PedalSectionExtractor alloc] init];
  }
  return self;
}

- (void)start {
  std::unique_ptr<image_fetcher::ImageDataFetcher> imageFetcher =
      std::make_unique<image_fetcher::ImageDataFetcher>(
          self.browser->GetBrowserState()->GetSharedURLLoaderFactory());

  BOOL isIncognito = self.browser->GetBrowserState()->IsOffTheRecord();

  self.mediator = [[OmniboxPopupMediator alloc]
      initWithFetcher:std::move(imageFetcher)
        faviconLoader:IOSChromeFaviconLoaderFactory::GetForBrowserState(
                          self.browser->GetBrowserState())
             delegate:_popupView.get()];
  // TODO(crbug.com/1045047): Use HandlerForProtocol after commands protocol
  // clean up.
  self.mediator.dispatcher =
      static_cast<id<BrowserCommands>>(self.browser->GetCommandDispatcher());
  self.mediator.webStateList = self.browser->GetWebStateList();
  TemplateURLService* templateURLService =
      ios::TemplateURLServiceFactory::GetForBrowserState(
          self.browser->GetBrowserState());
  self.mediator.defaultSearchEngineIsGoogle =
      templateURLService && templateURLService->GetDefaultSearchProvider() &&
      templateURLService->GetDefaultSearchProvider()->GetEngineType(
          templateURLService->search_terms_data()) == SEARCH_ENGINE_GOOGLE;

  if (IsSwiftUIPopupEnabled()) {
    self.model = [[PopupModel alloc] initWithMatches:@[]
                                             headers:@[]
                                          dataSource:self.mediator
                                            delegate:self.pedalExtractor];
    ToolbarConfiguration* toolbarConfiguration = [[ToolbarConfiguration alloc]
        initWithStyle:isIncognito ? INCOGNITO : NORMAL];
    self.uiConfiguration = [[PopupUIConfiguration alloc]
        initWithToolbarConfiguration:toolbarConfiguration];
    if (@available(iOS 16, *)) {
      self.uiConfiguration.shouldDismissKeyboardOnScroll =
          (ui::GetDeviceFormFactor() != ui::DEVICE_FORM_FACTOR_TABLET ||
           base::FeatureList::IsEnabled(kEnableSuggestionsScrollingOnIPad));
    }

    BOOL popupShouldSelfSize =
        (ui::GetDeviceFormFactor() == ui::DEVICE_FORM_FACTOR_TABLET);
    self.mediator.model = self.model;

    PopupUIVariation popupUIVariation = IsOmniboxActionsVisualTreatment1()
                                            ? PopupUIVariationOne
                                            : PopupUIVariationTwo;

    std::string pasteButtonVariationName =
        base::GetFieldTrialParamValueByFeature(
            kOmniboxPasteButton, kOmniboxPasteButtonParameterName);

    PopupPasteButtonVariation popupPasteButtonVariation =
        (pasteButtonVariationName ==
         kOmniboxPasteButtonParameterBlueFullCapsule)
            ? PopupPasteButtonVariationIconText
            : PopupPasteButtonVariationIcon;

    self.popupViewController = [OmniboxPopupViewProvider
        makeViewControllerWithModel:self.model
                    uiConfiguration:self.uiConfiguration
                   popupUIVariation:popupUIVariation
          popupPasteButtonVariation:popupPasteButtonVariation
                popupShouldSelfSize:popupShouldSelfSize
            appearanceContainerType:[OmniboxPopupContainerView class]];
    [self.browser->GetCommandDispatcher()
        startDispatchingToTarget:self.model
                     forProtocol:@protocol(OmniboxSuggestionCommands)];
    self.mediator.consumer = self.pedalExtractor;
    self.pedalExtractor.dataSink = self.model;
    self.pedalExtractor.delegate = self.mediator;
  } else {
    OmniboxPopupViewController* popupViewController =
        [[OmniboxPopupViewController alloc] init];
    popupViewController.imageRetriever = self.mediator;
    popupViewController.faviconRetriever = self.mediator;
    popupViewController.delegate = self.pedalExtractor;
    popupViewController.dataSource = self.mediator;
    popupViewController.incognito = isIncognito;
    [self.browser->GetCommandDispatcher()
        startDispatchingToTarget:popupViewController
                     forProtocol:@protocol(OmniboxSuggestionCommands)];

    self.mediator.consumer = self.pedalExtractor;
    self.pedalExtractor.dataSink = popupViewController;
    self.pedalExtractor.delegate = self.mediator;

    self.popupViewController = popupViewController;
  }

  if (IsOmniboxActionsEnabled()) {
    OmniboxPedalAnnotator* annotator = [[OmniboxPedalAnnotator alloc] init];
    annotator.pedalsEndpoint = HandlerForProtocol(
        self.browser->GetCommandDispatcher(), ApplicationCommands);
    annotator.omniboxCommandHandler = HandlerForProtocol(
        self.browser->GetCommandDispatcher(), OmniboxCommands);
    self.mediator.pedalAnnotator = annotator;
  }

  self.mediator.incognito = isIncognito;
  SceneState* sceneState =
      SceneStateBrowserAgent::FromBrowser(self.browser)->GetSceneState();
  self.mediator.promoScheduler =
      [DefaultBrowserSceneAgent agentFromScene:sceneState].nonModalScheduler;
  self.mediator.presenter = [[OmniboxPopupPresenter alloc]
      initWithPopupPresenterDelegate:self.presenterDelegate
                 popupViewController:self.popupViewController
                           incognito:isIncognito];

  _popupView->SetMediator(self.mediator);
}

- (void)stop {
  _popupView.reset();
  [self.browser->GetCommandDispatcher()
      stopDispatchingForProtocol:@protocol(OmniboxSuggestionCommands)];
}

- (BOOL)isOpen {
  return self.mediator.isOpen;
}

#pragma mark - Property accessor

- (BOOL)hasResults {
  return self.mediator.hasResults;
}

@end
