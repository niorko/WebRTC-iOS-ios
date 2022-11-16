// Copyright 2017 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_OMNIBOX_POPUP_OMNIBOX_POPUP_MEDIATOR_H_
#define IOS_CHROME_BROWSER_UI_OMNIBOX_POPUP_OMNIBOX_POPUP_MEDIATOR_H_

#import <UIKit/UIKit.h>

#include <memory>

#import "components/history/core/browser/top_sites.h"
#include "components/omnibox/browser/autocomplete_result.h"
#import "ios/chrome/browser/ui/omnibox/popup/autocomplete_result_consumer.h"
#import "ios/chrome/browser/ui/omnibox/popup/carousel_item_menu_provider.h"
#import "ios/chrome/browser/ui/omnibox/popup/favicon_retriever.h"
#import "ios/chrome/browser/ui/omnibox/popup/image_retriever.h"
#import "ui/base/window_open_disposition.h"

@protocol BrowserCommands;
@class BrowserActionFactory;
@class CarouselItem;
@protocol CarouselItemConsumer;
@class DefaultBrowserPromoNonModalScheduler;
class FaviconLoader;
@class OmniboxPedalAnnotator;
@class OmniboxPopupMediator;
@class OmniboxPopupPresenter;
@class PopupModel;
@protocol SnackbarCommands;
class WebStateList;

namespace image_fetcher {
class ImageDataFetcher;
}  // namespace

class OmniboxPopupMediatorDelegate {
 public:
  virtual bool IsStarredMatch(const AutocompleteMatch& match) const = 0;
  virtual void OnMatchSelected(const AutocompleteMatch& match,
                               size_t row,
                               WindowOpenDisposition disposition) = 0;
  virtual void OnMatchSelectedForAppending(const AutocompleteMatch& match) = 0;
  virtual void OnMatchSelectedForDeletion(const AutocompleteMatch& match) = 0;
  virtual void OnScroll() = 0;
};

// Provider that returns protocols and services that are instantiated after
// OmniboxPopupCoordinator.
@protocol OmniboxPopupMediatorProtocolProvider

// Returns the TopSites object to add/remove blocked URLs.
- (scoped_refptr<history::TopSites>)topSites;

// Returns command handler for SnackbarCommands;
- (id<SnackbarCommands>)snackbarCommandsHandler;

@end

// Delegate for share purposes, such as sharing URLs from the popup.
@protocol OmniboxPopupMediatorSharingDelegate

// Called by `popupMediator` to share `URL` with `title`, originating from
// `originView`.
- (void)popupMediator:(OmniboxPopupMediator*)mediator
             shareURL:(GURL)URL
                title:(NSString*)title
           originView:(UIView*)originView;
@end

@interface OmniboxPopupMediator : NSObject <AutocompleteResultConsumerDelegate,
                                            AutocompleteResultDataSource,
                                            CarouselItemMenuProvider,
                                            ImageRetriever,
                                            FaviconRetriever>

@property(nonatomic, readonly, assign) FaviconLoader* faviconLoader;

// Whether the mediator has results to show.
@property(nonatomic, assign) BOOL hasResults;

// Sets the semantic content attribute of the popup content.
- (void)setSemanticContentAttribute:
    (UISemanticContentAttribute)semanticContentAttribute;

@property(nonatomic, weak) id<BrowserCommands> dispatcher;
@property(nonatomic, weak) id<AutocompleteResultConsumer> consumer;
// Scheduler to notify about events happening in this popup.
@property(nonatomic, weak) DefaultBrowserPromoNonModalScheduler* promoScheduler;
@property(nonatomic, assign, getter=isIncognito) BOOL incognito;
// Whether the popup is open.
@property(nonatomic, assign, getter=isOpen) BOOL open;
// Presenter for the popup, handling the positioning and the presentation
// animations.
@property(nonatomic, strong) OmniboxPopupPresenter* presenter;
// The web state list this mediator is handling.
@property(nonatomic, assign) WebStateList* webStateList;
// Whether the default search engine is Google impacts which icon is used in
// some cases
@property(nonatomic, assign) BOOL defaultSearchEngineIsGoogle;
// The model for this mediator, if one exists.
@property(nonatomic, weak) PopupModel* model;
// The annotator to create pedals for ths mediator.
@property(nonatomic) OmniboxPedalAnnotator* pedalAnnotator;
// Flag that marks that incognito actions are available. Those can be disabled
// by an enterprise policy.
@property(nonatomic, assign) BOOL allowIncognitoActions;

// Delegate for sharing popup content.
@property(nonatomic, weak) id<OmniboxPopupMediatorSharingDelegate>
    sharingDelegate;
@property(nonatomic, weak) id<OmniboxPopupMediatorProtocolProvider>
    protocolProvider;
@property(nonatomic, strong) BrowserActionFactory* mostVisitedActionFactory;
@property(nonatomic, weak) id<CarouselItemConsumer> carouselItemConsumer;

// Designated initializer. Takes ownership of `imageFetcher`.
- (instancetype)initWithFetcher:
                    (std::unique_ptr<image_fetcher::ImageDataFetcher>)
                        imageFetcher
                  faviconLoader:(FaviconLoader*)faviconLoader
                       delegate:(OmniboxPopupMediatorDelegate*)delegate;

- (void)updateMatches:(const AutocompleteResult&)result;

// Sets the text alignment of the popup content.
- (void)setTextAlignment:(NSTextAlignment)alignment;

// Updates the popup with the `results`.
- (void)updateWithResults:(const AutocompleteResult&)results;

@end

#endif  // IOS_CHROME_BROWSER_UI_OMNIBOX_POPUP_OMNIBOX_POPUP_MEDIATOR_H_
