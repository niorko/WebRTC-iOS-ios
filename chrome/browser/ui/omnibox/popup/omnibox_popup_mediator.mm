// Copyright 2017 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/omnibox/popup/omnibox_popup_mediator.h"

#import <MaterialComponents/MaterialSnackbar.h>

#import "base/feature_list.h"
#import "base/metrics/user_metrics.h"
#import "base/metrics/user_metrics_action.h"
#import "base/strings/sys_string_conversions.h"
#import "base/strings/utf_string_conversions.h"
#import "components/image_fetcher/core/image_data_fetcher.h"
#import "components/omnibox/browser/autocomplete_input.h"
#import "components/omnibox/browser/autocomplete_match.h"
#import "components/omnibox/browser/autocomplete_result.h"
#import "components/omnibox/common/omnibox_features.h"
#import "components/strings/grit/components_strings.h"
#import "ios/chrome/browser/favicon/favicon_loader.h"
#import "ios/chrome/browser/ui/commands/browser_commands.h"
#import "ios/chrome/browser/ui/commands/snackbar_commands.h"
#import "ios/chrome/browser/ui/default_promo/default_browser_promo_non_modal_scheduler.h"
#import "ios/chrome/browser/ui/menu/browser_action_factory.h"
#import "ios/chrome/browser/ui/ntp/ntp_util.h"
#import "ios/chrome/browser/ui/omnibox/popup/autocomplete_match_formatter.h"
#import "ios/chrome/browser/ui/omnibox/popup/autocomplete_suggestion_group_impl.h"
#import "ios/chrome/browser/ui/omnibox/popup/carousel_item.h"
#import "ios/chrome/browser/ui/omnibox/popup/carousel_item_menu_provider.h"
#import "ios/chrome/browser/ui/omnibox/popup/omnibox_pedal_annotator.h"
#import "ios/chrome/browser/ui/omnibox/popup/omnibox_popup_presenter.h"
#import "ios/chrome/browser/ui/omnibox/popup/pedal_section_extractor.h"
#import "ios/chrome/browser/ui/omnibox/popup/pedal_suggestion_wrapper.h"
#import "ios/chrome/browser/ui/omnibox/popup/popup_swift.h"
#import "ios/chrome/browser/web_state_list/web_state_list.h"
#import "ios/chrome/common/ui/favicon/favicon_attributes.h"
#import "ui/base/l10n/l10n_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
const CGFloat kOmniboxIconSize = 16;
}  // namespace

@interface OmniboxPopupMediator () <PedalSectionExtractorDelegate>

// Extracts pedals from AutocompleSuggestions.
@property(nonatomic, strong) PedalSectionExtractor* pedalSectionExtractor;
// List of suggestions without the pedal group. Used to debouce pedals.
@property(nonatomic, strong)
    NSArray<id<AutocompleteSuggestionGroup>>* nonPedalSuggestions;
// Index of the group containing AutocompleteSuggestion, first group to be
// highlighted on down arrow key.
@property(nonatomic, assign) NSInteger preselectedGroupIndex;

@end

@implementation OmniboxPopupMediator {
  // Fetcher for Answers in Suggest images.
  std::unique_ptr<image_fetcher::ImageDataFetcher> _imageFetcher;

  OmniboxPopupMediatorDelegate* _delegate;  // weak

  AutocompleteResult _currentResult;
}
@synthesize consumer = _consumer;
@synthesize hasResults = _hasResults;
@synthesize incognito = _incognito;
@synthesize open = _open;
@synthesize presenter = _presenter;

- (instancetype)initWithFetcher:
                    (std::unique_ptr<image_fetcher::ImageDataFetcher>)
                        imageFetcher
                  faviconLoader:(FaviconLoader*)faviconLoader
                       delegate:(OmniboxPopupMediatorDelegate*)delegate {
  self = [super init];
  if (self) {
    DCHECK(delegate);
    _delegate = delegate;
    _imageFetcher = std::move(imageFetcher);
    _faviconLoader = faviconLoader;
    _open = NO;
    _pedalSectionExtractor = [[PedalSectionExtractor alloc] init];
    _pedalSectionExtractor.delegate = self;
    _preselectedGroupIndex = 0;
  }
  return self;
}

- (void)updateMatches:(const AutocompleteResult&)result {
  _currentResult.Reset();
  _currentResult.CopyFrom(result);
  self.nonPedalSuggestions = nil;

  self.hasResults = !_currentResult.empty();
  if (base::FeatureList::IsEnabled(omnibox::kAdaptiveSuggestionsCount)) {
    [self.consumer newResultsAvailable];
  } else {
    // Avoid calling consumer visible size and set all suggestions as visible to
    // get only one grouping.
    [self requestResultsWithVisibleSuggestionCount:_currentResult.size()];
  }
}

- (void)updateWithResults:(const AutocompleteResult&)result {
  [self updateMatches:result];
  self.open = !result.empty();
  [self.presenter updatePopup];
}

- (void)setTextAlignment:(NSTextAlignment)alignment {
  [self.consumer setTextAlignment:alignment];
}

- (void)setSemanticContentAttribute:
    (UISemanticContentAttribute)semanticContentAttribute {
  [self.consumer setSemanticContentAttribute:semanticContentAttribute];
}

#pragma mark - AutocompleteResultDataSource

- (void)requestResultsWithVisibleSuggestionCount:
    (NSUInteger)visibleSuggestionCount {
  // If no suggestions are visible, consider all of them visible.
  if (visibleSuggestionCount == 0) {
    visibleSuggestionCount = _currentResult.size();
  }
  NSUInteger visibleSuggestions =
      MIN(visibleSuggestionCount, _currentResult.size());
  if (visibleSuggestions > 0) {
    // Groups visible suggestions by search vs url. Skip the first suggestion
    // because it's the omnibox content.
    [self groupCurrentSuggestionsFrom:1 to:visibleSuggestions];
  }
  // Groups hidden suggestions by search vs url.
  [self groupCurrentSuggestionsFrom:visibleSuggestions
                                 to:_currentResult.size()];

  NSArray<id<AutocompleteSuggestionGroup>>* groups = [self wrappedMatches];

  [self.consumer updateMatches:groups
      preselectedMatchGroupIndex:self.preselectedGroupIndex];

  [self loadModelImages];
}

#pragma mark - AutocompleteResultConsumerDelegate

- (void)autocompleteResultConsumer:(id<AutocompleteResultConsumer>)sender
               didSelectSuggestion:(id<AutocompleteSuggestion>)suggestion
                             inRow:(NSUInteger)row {
  if ([suggestion isKindOfClass:[PedalSuggestionWrapper class]]) {
    PedalSuggestionWrapper* pedalSuggestionWrapper =
        (PedalSuggestionWrapper*)suggestion;
    if (pedalSuggestionWrapper.innerPedal.action) {
      pedalSuggestionWrapper.innerPedal.action();
    }
  } else if ([suggestion isKindOfClass:[AutocompleteMatchFormatter class]]) {
    AutocompleteMatchFormatter* autocompleteMatchFormatter =
        (AutocompleteMatchFormatter*)suggestion;
    const AutocompleteMatch& match =
        autocompleteMatchFormatter.autocompleteMatch;

    // Don't log pastes in incognito.
    if (!self.incognito && match.type == AutocompleteMatchType::CLIPBOARD_URL) {
      [self.promoScheduler logUserPastedInOmnibox];
    }

    _delegate->OnMatchSelected(match, row, WindowOpenDisposition::CURRENT_TAB);
  } else {
    NOTREACHED() << "Suggestion type " << NSStringFromClass(suggestion.class)
                 << " not handled for selection.";
  }
}

- (void)autocompleteResultConsumer:(id<AutocompleteResultConsumer>)sender
    didTapTrailingButtonOnSuggestion:(id<AutocompleteSuggestion>)suggestion
                               inRow:(NSUInteger)row {
  if ([suggestion isKindOfClass:[AutocompleteMatchFormatter class]]) {
    AutocompleteMatchFormatter* autocompleteMatchFormatter =
        (AutocompleteMatchFormatter*)suggestion;
    const AutocompleteMatch& match =
        autocompleteMatchFormatter.autocompleteMatch;
    if (match.has_tab_match.value_or(false)) {
      _delegate->OnMatchSelected(match, row,
                                 WindowOpenDisposition::SWITCH_TO_TAB);
    } else {
      if (AutocompleteMatch::IsSearchType(match.type)) {
        base::RecordAction(
            base::UserMetricsAction("MobileOmniboxRefineSuggestion.Search"));
      } else {
        base::RecordAction(
            base::UserMetricsAction("MobileOmniboxRefineSuggestion.Url"));
      }
      _delegate->OnMatchSelectedForAppending(match);
    }
  } else {
    NOTREACHED() << "Suggestion type " << NSStringFromClass(suggestion.class)
                 << " not handled for trailing button tap.";
  }
}

- (void)autocompleteResultConsumer:(id<AutocompleteResultConsumer>)sender
    didSelectSuggestionForDeletion:(id<AutocompleteSuggestion>)suggestion
                             inRow:(NSUInteger)row {
  if ([suggestion isKindOfClass:[AutocompleteMatchFormatter class]]) {
    AutocompleteMatchFormatter* autocompleteMatchFormatter =
        (AutocompleteMatchFormatter*)suggestion;
    const AutocompleteMatch& match =
        autocompleteMatchFormatter.autocompleteMatch;
    _delegate->OnMatchSelectedForDeletion(match);
  } else {
    NOTREACHED() << "Suggestion type " << NSStringFromClass(suggestion.class)
                 << " not handled for deletion.";
  }
}

- (void)autocompleteResultConsumerDidScroll:
    (id<AutocompleteResultConsumer>)sender {
  _delegate->OnScroll();
}

- (void)loadModelImages {
  for (PopupMatchSection* section in self.model.sections) {
    for (PopupMatch* match in section.matches) {
      PopupImage* popupImage = match.image;
      switch (popupImage.icon.iconType) {
        case OmniboxIconTypeSuggestionIcon:
          break;
        case OmniboxIconTypeImage: {
          [self fetchImage:popupImage.icon.imageURL.gurl
                completion:^(UIImage* image) {
                  popupImage.iconUIImageFromURL = image;
                }];
          break;
        }
        case OmniboxIconTypeFavicon: {
          [self fetchFavicon:popupImage.icon.imageURL.gurl
                  completion:^(UIImage* image) {
                    popupImage.iconUIImageFromURL = image;
                  }];
          break;
        }
      }
    }
  }
}

#pragma mark - ImageFetcher

- (void)fetchImage:(GURL)imageURL completion:(void (^)(UIImage*))completion {
  auto callback =
      base::BindOnce(^(const std::string& image_data,
                       const image_fetcher::RequestMetadata& metadata) {
        NSData* data = [NSData dataWithBytes:image_data.data()
                                      length:image_data.size()];
        if (data) {
          UIImage* image = [UIImage imageWithData:data
                                            scale:[UIScreen mainScreen].scale];
          completion(image);
        } else {
          completion(nil);
        }
      });

  _imageFetcher->FetchImageData(imageURL, std::move(callback),
                                NO_TRAFFIC_ANNOTATION_YET);
}

#pragma mark - FaviconRetriever

- (void)fetchFavicon:(GURL)pageURL completion:(void (^)(UIImage*))completion {
  if (!self.faviconLoader) {
    return;
  }

  self.faviconLoader->FaviconForPageUrl(
      pageURL, kOmniboxIconSize, kOmniboxIconSize,
      /*fallback_to_google_server=*/false, ^(FaviconAttributes* attributes) {
        if (attributes.faviconImage && !attributes.usesDefaultImage)
          completion(attributes.faviconImage);
      });
}

#pragma mark - PedalSectionExtractorDelegate

// Removes the pedal group from suggestions. Pedal are removed from suggestions
// with a debouce timer in `PedalSectionExtractor`. When the timer ends the
// pedal group is removed.
- (void)invalidatePedals {
  if (self.nonPedalSuggestions) {
    [self.consumer updateMatches:self.nonPedalSuggestions
        preselectedMatchGroupIndex:0];
  }
}

#pragma mark - Private methods

// Wraps `match` with AutocompleteMatchFormatter.
- (AutocompleteMatchFormatter*)wrapMatch:(const AutocompleteMatch&)match
                              fromResult:(const AutocompleteResult&)result {
  AutocompleteMatchFormatter* formatter =
      [AutocompleteMatchFormatter formatterWithMatch:match];
  formatter.starred = _delegate->IsStarredMatch(match);
  formatter.incognito = _incognito;
  formatter.defaultSearchEngineIsGoogle = self.defaultSearchEngineIsGoogle;
  formatter.pedalData = [self.pedalAnnotator pedalForMatch:match
                                                 incognito:_incognito];

  if (formatter.suggestionGroupId) {
    omnibox::GroupId groupId =
        static_cast<omnibox::GroupId>(formatter.suggestionGroupId.intValue);
    omnibox::GroupSection sectionId =
        result.GetSectionForSuggestionGroup(groupId);
    formatter.suggestionSectionId =
        [NSNumber numberWithInt:static_cast<int>(sectionId)];
  }

  return formatter;
}

/// Extract normal (non-tile) matches from `autocompleteResult`.
- (NSMutableArray<id<AutocompleteSuggestion>>*)extractMatches:
    (const AutocompleteResult&)autocompleteResult {
  NSMutableArray<id<AutocompleteSuggestion>>* wrappedMatches =
      [[NSMutableArray alloc] init];
  for (size_t i = 0; i < _currentResult.size(); i++) {
    const AutocompleteMatch& match =
        ((const AutocompleteResult&)_currentResult).match_at((NSUInteger)i);

    if (match.type == AutocompleteMatchType::TILE_NAVSUGGEST) {
      DCHECK(match.type == AutocompleteMatchType::TILE_NAVSUGGEST);
      DCHECK(base::FeatureList::IsEnabled(omnibox::kMostVisitedTiles));
      for (const AutocompleteMatch::SuggestTile& tile : match.suggest_tiles) {
        AutocompleteMatch tileMatch = AutocompleteMatch(match);
        // TODO(crbug.com/1363546): replace with a new wrapper.
        tileMatch.destination_url = tile.url;
        tileMatch.fill_into_edit = base::UTF8ToUTF16(tile.url.spec());
        tileMatch.description = tile.title;
        AutocompleteMatchFormatter* formatter =
            [self wrapMatch:tileMatch fromResult:autocompleteResult];
        [wrappedMatches addObject:formatter];
      }
    } else {
      [wrappedMatches addObject:[self wrapMatch:match
                                     fromResult:autocompleteResult]];
    }
  }

  return wrappedMatches;
}

/// Take a list of suggestions and break it into groups determined by sectionId
/// field. Use `headerMap` to extract group names.
- (NSArray<id<AutocompleteSuggestionGroup>>*)
            groupSuggestions:(NSArray<id<AutocompleteSuggestion>>*)suggestions
    usingACResultAsHeaderMap:(const AutocompleteResult&)headerMap {
  __block NSMutableArray<id<AutocompleteSuggestion>>* currentGroup =
      [[NSMutableArray alloc] init];
  NSMutableArray<id<AutocompleteSuggestionGroup>>* groups =
      [[NSMutableArray alloc] init];

  if (suggestions.count == 0) {
    return @[];
  }

  id<AutocompleteSuggestion> firstSuggestion = suggestions.firstObject;

  __block NSNumber* currentSectionId = firstSuggestion.suggestionSectionId;
  __block NSNumber* currentGroupId = firstSuggestion.suggestionGroupId;

  [currentGroup addObject:firstSuggestion];

  void (^startNewGroup)() = ^{
    if (currentGroup.count == 0) {
      return;
    }

    NSString* groupTitle =
        currentGroupId
            ? base::SysUTF16ToNSString(headerMap.GetHeaderForSuggestionGroup(
                  static_cast<omnibox::GroupId>([currentGroupId intValue])))
            : nil;
    SuggestionGroupDisplayStyle displayStyle =
        SuggestionGroupDisplayStyleDefault;
    if (base::FeatureList::IsEnabled(omnibox::kMostVisitedTiles)) {
      if (currentSectionId &&
          static_cast<omnibox::GroupSection>(currentSectionId.intValue) ==
              omnibox::SECTION_MOBILE_MOST_VISITED) {
        displayStyle = SuggestionGroupDisplayStyleCarousel;
      }
    }
    [groups addObject:[AutocompleteSuggestionGroupImpl
                          groupWithTitle:groupTitle
                             suggestions:currentGroup
                            displayStyle:displayStyle]];
    currentGroup = [[NSMutableArray alloc] init];
  };

  for (NSUInteger i = 1; i < suggestions.count; i++) {
    id<AutocompleteSuggestion> suggestion = suggestions[i];
    if ((!suggestion.suggestionSectionId && !currentSectionId) ||
        [suggestion.suggestionSectionId isEqual:currentSectionId]) {
      [currentGroup addObject:suggestion];
    } else {
      startNewGroup();
      currentGroupId = suggestion.suggestionGroupId;
      currentSectionId = suggestion.suggestionSectionId;
      [currentGroup addObject:suggestion];
    }
  }
  startNewGroup();

  return groups;
}

// Unpacks AutocompleteMatch into wrapped AutocompleteSuggestion and
// AutocompleteSuggestionGroup. Sets `preselectedGroupIndex`.
- (NSArray<id<AutocompleteSuggestionGroup>>*)wrappedMatches {
  NSMutableArray<id<AutocompleteSuggestionGroup>>* groups =
      [[NSMutableArray alloc] init];

  // Group the suggestions by the section Id.
  NSMutableArray<id<AutocompleteSuggestion>>* allMatches =
      [self extractMatches:_currentResult];
  NSArray<id<AutocompleteSuggestionGroup>>* allGroups =
      [self groupSuggestions:allMatches
          usingACResultAsHeaderMap:_currentResult];
  [groups addObjectsFromArray:allGroups];

  // Before inserting pedals above all, back up non-pedal suggestions for
  // debouncing.
  self.nonPedalSuggestions = groups;

  // Get pedals, if any. They go at the very top of the list.
  id<AutocompleteSuggestionGroup> pedalGroup =
      [self.pedalSectionExtractor extractPedals:allMatches];
  if (pedalGroup) {
    [groups insertObject:pedalGroup atIndex:0];
  }

  // Preselect the verbatim match. It's the top match, unless we inserted pedals
  // and pushed it one section down.
  self.preselectedGroupIndex = pedalGroup ? MIN(1, groups.count) : 0;

  return groups;
}

- (void)groupCurrentSuggestionsFrom:(NSUInteger)begin to:(NSUInteger)end {
  DCHECK(begin <= _currentResult.size());
  DCHECK(end <= _currentResult.size());
  AutocompleteResult::GroupSuggestionsBySearchVsURL(
      std::next(_currentResult.begin(), begin),
      std::next(_currentResult.begin(), end));
}

#pragma mark - CarouselItemMenuProvider

// Context Menu for carousel `item` in `view`.
- (UIContextMenuConfiguration*)
    contextMenuConfigurationForCarouselItem:(CarouselItem*)carouselItem
                                   fromView:(UIView*)view {
  __weak __typeof(self) weakSelf = self;
  __weak CarouselItem* weakItem = carouselItem;
  GURL copyURL = carouselItem.URL.gurl;

  UIContextMenuActionProvider actionProvider =
      ^(NSArray<UIMenuElement*>* suggestedActions) {
        DCHECK(weakSelf);

        __typeof(self) strongSelf = weakSelf;
        BrowserActionFactory* actionFactory =
            strongSelf.mostVisitedActionFactory;

        NSMutableArray<UIMenuElement*>* menuElements =
            [[NSMutableArray alloc] init];

        [menuElements addObject:[actionFactory actionToRemoveWithBlock:^{
                        [weakSelf removeMostVisitedForURL:copyURL
                                         withCarouselItem:weakItem];
                      }]];

        return [UIMenu menuWithTitle:@"" children:menuElements];
      };
  return
      [UIContextMenuConfiguration configurationWithIdentifier:nil
                                              previewProvider:nil
                                               actionProvider:actionProvider];
}

#pragma mark CarouselItemMenuProvider Private

// Blocks `URL` so it won't appear in most visited URLs.
- (void)blockMostVisitedURL:(GURL)URL {
  scoped_refptr<history::TopSites> top_sites = [self.protocolProvider topSites];
  if (top_sites) {
    top_sites->AddBlockedUrl(URL);
  }
}

// Unblocks `URL` so it can appear in most visited URLs.
- (void)allowMostVisitedURL:(GURL)URL {
  scoped_refptr<history::TopSites> top_sites = [self.protocolProvider topSites];
  if (top_sites) {
    top_sites->RemoveBlockedUrl(URL);
  }
}

// Blocks `URL` in most visited sites and hides `CarouselItem` if it still
// exist.
- (void)removeMostVisitedForURL:(GURL)URL
               withCarouselItem:(CarouselItem*)carouselItem {
  if (!carouselItem) {
    return;
  }
  [self blockMostVisitedURL:URL];
  [self.carouselItemConsumer carouselItem:carouselItem setHidden:YES];
  [self showMostVisitedUndoForURL:URL withCarouselItem:carouselItem];
}

// Shows a snackbar with an action to undo the removal of the most visited item
// with a `URL`. Unhides CarouselItem if it still exist.
- (void)showMostVisitedUndoForURL:(GURL)URL
                 withCarouselItem:(CarouselItem*)carouselItem {
  GURL copiedURL = URL;
  MDCSnackbarMessageAction* action = [[MDCSnackbarMessageAction alloc] init];
  action.title = l10n_util::GetNSString(IDS_NEW_TAB_UNDO_THUMBNAIL_REMOVE);
  action.accessibilityIdentifier = @"Undo";

  __weak __typeof(self) weakSelf = self;
  __weak CarouselItem* weakItem = carouselItem;
  action.handler = ^{
    __typeof(self) strongSelf = weakSelf;
    if (!strongSelf) {
      return;
    }
    [strongSelf allowMostVisitedURL:copiedURL];
    CarouselItem* strongItem = weakItem;
    if (strongItem) {
      [strongSelf.carouselItemConsumer carouselItem:strongItem setHidden:NO];
    }
  };

  TriggerHapticFeedbackForNotification(UINotificationFeedbackTypeSuccess);
  MDCSnackbarMessage* message = [MDCSnackbarMessage
      messageWithText:l10n_util::GetNSString(
                          IDS_IOS_NEW_TAB_MOST_VISITED_ITEM_REMOVED)];
  message.action = action;
  message.category = @"MostVisitedUndo";
  [self.protocolProvider.snackbarCommandsHandler showSnackbarMessage:message];
}

@end
