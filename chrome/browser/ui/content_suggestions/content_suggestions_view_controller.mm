// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_view_controller.h"

#include "base/mac/foundation_util.h"
#include "base/metrics/user_metrics.h"
#include "base/metrics/user_metrics_action.h"
#include "components/strings/grit/components_strings.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_cells_constants.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_module_container.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_most_visited_action_item.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_most_visited_item.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_most_visited_tile_view.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_parent_item.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_return_to_recent_tab_item.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_return_to_recent_tab_view.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_selection_actions.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_shortcut_tile_view.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_tile_layout_util.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_whats_new_view.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/query_suggestion_view.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_collection_utils.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_commands.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_constants.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_feature.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_menu_provider.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_view_controller_audience.h"
#import "ios/chrome/browser/ui/content_suggestions/ntp_home_constant.h"
#import "ios/chrome/browser/ui/ntp/new_tab_page_header_constants.h"
#import "ios/chrome/browser/ui/start_surface/start_surface_features.h"
#import "ios/chrome/browser/ui/toolbar/public/toolbar_utils.h"
#import "ios/chrome/browser/ui/ui_feature_flags.h"
#import "ios/chrome/browser/ui/util/uikit_ui_util.h"
#import "ios/chrome/common/material_timing.h"
#import "ios/chrome/common/ui/colors/semantic_color_names.h"
#import "ios/chrome/common/ui/favicon/favicon_view.h"
#import "ios/chrome/common/ui/util/constraints_ui_util.h"
#include "ui/base/l10n/l10n_util.h"
#include "url/gurl.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
// The width of the modules.
const int kModuleWidthCompact = 343;
const int kModuleWidthRegular = 382;

// The height of the modules;
const int kModuleHeight = 139;

// The spacing between the modules.
const float kModuleVerticalSpacing = 16.0f;

// The horizontal spacing between trending query views.
const float kTrendingQueryViewHorizontalSpacing = 12.0f;

// Returns the module width depending on the horizontal trait collection.
CGFloat GetModuleWidthForHorizontalTraitCollection(
    UITraitCollection* traitCollection) {
  return traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular
             ? kModuleWidthRegular
             : kModuleWidthCompact;
}
}  // namespace

@interface ContentSuggestionsViewController () <
    UIGestureRecognizerDelegate,
    ContentSuggestionsSelectionActions>

// Whether an item of type ItemTypePromo has already been added to the model.
@property(nonatomic, assign) BOOL promoAdded;

// StackView holding all subviews.
@property(nonatomic, strong) UIStackView* verticalStackView;

// List of all UITapGestureRecognizers created for the Most Visisted tiles.
@property(nonatomic, strong)
    NSMutableArray<UITapGestureRecognizer*>* mostVisitedTapRecognizers;
// The UITapGestureRecognizer for the Return To Recent Tab tile.
@property(nonatomic, strong)
    UITapGestureRecognizer* returnToRecentTabTapRecognizer;
// The UITapGestureRecognizer for the NTP promo view.
@property(nonatomic, strong) UITapGestureRecognizer* promoTapRecognizer;

// The Return To Recent Tab view.
@property(nonatomic, strong)
    ContentSuggestionsReturnToRecentTabView* returnToRecentTabTile;
// The WhatsNew view.
@property(nonatomic, strong) ContentSuggestionsWhatsNewView* whatsNewView;
// StackView holding all of `mostVisitedViews`.
@property(nonatomic, strong) UIStackView* mostVisitedStackView;
// Module Container for the Most Visited Tiles.
@property(nonatomic, strong)
    ContentSuggestionsModuleContainer* mostVisitedModuleContainer;
// Width Anchor of the Most Visited Tiles container.
@property(nonatomic, strong)
    NSLayoutConstraint* mostVisitedContainerWidthAnchor;
// List of all of the Most Visited views.
@property(nonatomic, strong)
    NSMutableArray<ContentSuggestionsMostVisitedTileView*>* mostVisitedViews;
// Module Container for the Shortcuts.
@property(nonatomic, strong)
    ContentSuggestionsModuleContainer* shortcutsModuleContainer;
// Width Anchor of the Shortcuts container.
@property(nonatomic, strong) NSLayoutConstraint* shortcutsContainerWidthAnchor;
// StackView holding all of `shortcutsViews`.
@property(nonatomic, strong) UIStackView* shortcutsStackView;
// List of all of the Shortcut views.
@property(nonatomic, strong)
    NSMutableArray<ContentSuggestionsShortcutTileView*>* shortcutsViews;
// Module Container for Trending Queries.
@property(nonatomic, strong)
    ContentSuggestionsModuleContainer* trendingQueriesModuleContainer;
@property(nonatomic, strong) UIView* trendingQueriesContainingView;
// List of all of the Trending Query views.
@property(nonatomic, strong)
    NSMutableArray<QuerySuggestionView*>* trendingQueryViews;
// List of all UITapGestureRecognizers created for the Trending Queries.
@property(nonatomic, strong)
    NSMutableArray<UITapGestureRecognizer*>* trendingQueryTapRecognizers;
// Set to YES when the trending queries fetch has been received.
@property(nonatomic, assign) BOOL trendingQueriesReceived;

@end

@implementation ContentSuggestionsViewController

- (instancetype)init {
  return [super initWithNibName:nil bundle:nil];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  if (IsContentSuggestionsUIModuleRefreshEnabled()) {
    self.view.backgroundColor = [UIColor clearColor];
  } else {
    self.view.backgroundColor = ntp_home::kNTPBackgroundColor();
  }
  self.view.accessibilityIdentifier = kContentSuggestionsCollectionIdentifier;

  self.verticalStackView = [[UIStackView alloc] init];
  self.verticalStackView.translatesAutoresizingMaskIntoConstraints = NO;
  if (IsContentSuggestionsUIModuleRefreshEnabled()) {
    self.verticalStackView.spacing = kModuleVerticalSpacing;
  }
  self.verticalStackView.axis = UILayoutConstraintAxisVertical;
  // A centered alignment will ensure the views are centered.
  self.verticalStackView.alignment = UIStackViewAlignmentCenter;
  // A fill distribution allows for the custom spacing between elements and
  // height/width configurations for each row.
  self.verticalStackView.distribution = UIStackViewDistributionFill;
  [self.view addSubview:self.verticalStackView];
  if (IsContentSuggestionsUIModuleRefreshEnabled()) {
    // Add bottom spacing to last module by applying it after
    // `_verticalStackView`.
    [NSLayoutConstraint activateConstraints:@[
      [self.verticalStackView.leadingAnchor
          constraintEqualToAnchor:self.view.leadingAnchor],
      [self.verticalStackView.trailingAnchor
          constraintEqualToAnchor:self.view.trailingAnchor],
      [self.verticalStackView.topAnchor
          constraintEqualToAnchor:self.view.topAnchor],
      [self.verticalStackView.bottomAnchor
          constraintEqualToAnchor:self.view.bottomAnchor
                         constant:-kModuleVerticalSpacing]
    ]];
  } else {
    AddSameConstraints(self.view, self.verticalStackView);
  }

  CGFloat horizontalSpacing =
      ContentSuggestionsTilesHorizontalSpacing(self.traitCollection);
  if (self.returnToRecentTabTile) {
    UIView* parentView = self.returnToRecentTabTile;
    if (IsContentSuggestionsUIModuleRefreshEnabled()) {
      ContentSuggestionsModuleContainer* returnToRecentTabContainer =
          [[ContentSuggestionsModuleContainer alloc]
              initWithContentView:self.returnToRecentTabTile
                       moduleType:
                           ContentSuggestionsModuleTypeReturnToRecentTab];
      parentView = returnToRecentTabContainer;
      [self.verticalStackView addArrangedSubview:returnToRecentTabContainer];
    } else {
      [self addUIElement:self.returnToRecentTabTile
          withCustomBottomSpacing:content_suggestions::
                                      kReturnToRecentTabSectionBottomMargin];
    }
    CGFloat cardWidth = content_suggestions::searchFieldWidth(
        self.view.bounds.size.width, self.traitCollection);
    [NSLayoutConstraint activateConstraints:@[
      [parentView.widthAnchor constraintEqualToConstant:cardWidth],
      [parentView.heightAnchor
          constraintEqualToConstant:kReturnToRecentTabSize.height]
    ]];
  }
  if (self.whatsNewView) {
    [self addUIElement:self.whatsNewView withCustomBottomSpacing:0];
    CGFloat width =
        MostVisitedTilesContentHorizontalSpace(self.traitCollection);
    CGSize size =
        MostVisitedCellSize(self.traitCollection.preferredContentSizeCategory);
    [NSLayoutConstraint activateConstraints:@[
      [self.whatsNewView.widthAnchor constraintEqualToConstant:width],
      [self.whatsNewView.heightAnchor constraintEqualToConstant:size.height]
    ]];
  }
  if (IsContentSuggestionsUIModuleRefreshEnabled() ||
      [self.mostVisitedViews count] > 0) {
    self.mostVisitedStackView = [[UIStackView alloc] init];
    self.mostVisitedStackView.axis = UILayoutConstraintAxisHorizontal;
    self.mostVisitedStackView.distribution = UIStackViewDistributionFillEqually;
    self.mostVisitedStackView.spacing = horizontalSpacing;

    UIView* parentView = self.mostVisitedStackView;
    if (IsContentSuggestionsUIModuleRefreshEnabled()) {
      self.mostVisitedStackView.backgroundColor =
          ntp_home::kNTPBackgroundColor();
      self.mostVisitedStackView.alignment = UIStackViewAlignmentTop;
      self.mostVisitedModuleContainer =
          [[ContentSuggestionsModuleContainer alloc]
              initWithContentView:self.mostVisitedStackView
                       moduleType:ContentSuggestionsModuleTypeMostVisited];
      if (!self.mostVisitedViews) {
        self.mostVisitedViews = [NSMutableArray array];
        self.mostVisitedModuleContainer.isPlaceholder = YES;
        // Add placeholder tiles if Most Visited Tiles are not ready yet.
        for (int i = 0; i < 4; i++) {
          ContentSuggestionsMostVisitedTileView* view =
              [[ContentSuggestionsMostVisitedTileView alloc]
                  initWithConfiguration:nil];
          [self.mostVisitedViews addObject:view];
        }
      }
      parentView = self.mostVisitedModuleContainer;
      [self.verticalStackView
          addArrangedSubview:self.mostVisitedModuleContainer];
    } else {
      self.mostVisitedStackView.alignment = UIStackViewAlignmentTop;
      [self addUIElement:self.mostVisitedStackView
          withCustomBottomSpacing:kMostVisitedBottomMargin];
    }
    CGFloat width =
        IsContentSuggestionsUIModuleRefreshEnabled()
            ? GetModuleWidthForHorizontalTraitCollection(self.traitCollection)
            : MostVisitedTilesContentHorizontalSpace(self.traitCollection);
    CGFloat height =
        IsContentSuggestionsUIModuleRefreshEnabled()
            ? kModuleHeight
            : MostVisitedCellSize(
                  self.traitCollection.preferredContentSizeCategory)
                  .height;
    self.mostVisitedContainerWidthAnchor =
        [parentView.widthAnchor constraintEqualToConstant:width];
    [NSLayoutConstraint activateConstraints:@[
      self.mostVisitedContainerWidthAnchor,
      [parentView.heightAnchor constraintGreaterThanOrEqualToConstant:height]
    ]];
    [self populateMostVisitedModule];
  }
  BOOL noTrendingQueriesToShow =
      self.trendingQueriesReceived && [self.trendingQueryViews count] == 0;
  if (IsTrendingQueriesModuleEnabled() && !noTrendingQueriesToShow) {
    self.trendingQueriesContainingView = [[UIView alloc] init];
    self.trendingQueriesModuleContainer =
        [[ContentSuggestionsModuleContainer alloc]
            initWithContentView:self.trendingQueriesContainingView
                     moduleType:ContentSuggestionsModuleTypeTrendingQueries];
    if (!self.trendingQueryViews) {
      self.mostVisitedModuleContainer.isPlaceholder = YES;
      self.trendingQueryViews = [NSMutableArray array];
      // Add placeholder tiles if Most Visited Tiles are not ready yet.
      for (int i = 0; i < 4; i++) {
        QuerySuggestionView* view =
            [[QuerySuggestionView alloc] initWithConfiguration:nil];
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [self.trendingQueryViews addObject:view];
      }
    }
    [self.verticalStackView
        addArrangedSubview:self.trendingQueriesModuleContainer];
    [NSLayoutConstraint activateConstraints:@[
      [self.trendingQueriesModuleContainer.widthAnchor
          constraintEqualToConstant:GetModuleWidthForHorizontalTraitCollection(
                                        self.traitCollection)],
      [self.trendingQueriesModuleContainer.heightAnchor
          constraintEqualToConstant:[self.trendingQueriesModuleContainer
                                            calculateIntrinsicHeight]]
    ]];
    [self populateTrendingQueriesModule];
  }
  if (self.shortcutsViews) {
    self.shortcutsStackView = [[UIStackView alloc] init];
    self.shortcutsStackView.axis = UILayoutConstraintAxisHorizontal;
    self.shortcutsStackView.distribution = UIStackViewDistributionFillEqually;
    self.shortcutsStackView.spacing = horizontalSpacing;
    if (IsContentSuggestionsUIModuleRefreshEnabled()) {
      self.shortcutsStackView.alignment = UIStackViewAlignmentTop;
      self.shortcutsStackView.backgroundColor = ntp_home::kNTPBackgroundColor();
    } else {
      self.shortcutsStackView.alignment = UIStackViewAlignmentTop;
    }
    NSUInteger index = 0;
    for (ContentSuggestionsShortcutTileView* view in self.shortcutsViews) {
      view.accessibilityIdentifier = [NSString
          stringWithFormat:
              @"%@%li",
              kContentSuggestionsShortcutsAccessibilityIdentifierPrefix, index];
      UITapGestureRecognizer* tapRecognizer = [[UITapGestureRecognizer alloc]
          initWithTarget:self
                  action:@selector(contentSuggestionsElementTapped:)];
      [view addGestureRecognizer:tapRecognizer];
      [self.mostVisitedTapRecognizers addObject:tapRecognizer];
      [self.shortcutsStackView addArrangedSubview:view];
      index++;
    }

    UIView* parentView = self.shortcutsStackView;
    if (IsContentSuggestionsUIModuleRefreshEnabled()) {
      self.shortcutsModuleContainer = [[ContentSuggestionsModuleContainer alloc]
          initWithContentView:self.shortcutsStackView
                   moduleType:ContentSuggestionsModuleTypeShortcuts];
      parentView = self.shortcutsModuleContainer;
      [self.verticalStackView addArrangedSubview:self.shortcutsModuleContainer];
    } else {
      [self addUIElement:self.shortcutsStackView
          withCustomBottomSpacing:kMostVisitedBottomMargin];
    }
    CGFloat width =
        IsContentSuggestionsUIModuleRefreshEnabled()
            ? GetModuleWidthForHorizontalTraitCollection(self.traitCollection)
            : MostVisitedTilesContentHorizontalSpace(self.traitCollection);
    CGFloat height =
        IsContentSuggestionsUIModuleRefreshEnabled()
            ? kModuleHeight
            : MostVisitedCellSize(
                  self.traitCollection.preferredContentSizeCategory)
                  .height;
    self.shortcutsContainerWidthAnchor =
        [parentView.widthAnchor constraintEqualToConstant:width];
    [NSLayoutConstraint activateConstraints:@[
      self.shortcutsContainerWidthAnchor,
      [parentView.heightAnchor constraintGreaterThanOrEqualToConstant:height]
    ]];
  }
}

- (void)viewDidDisappear:(BOOL)animated {
  [super viewDidDisappear:animated];
  if (ShouldShowReturnToMostRecentTabForStartSurface()) {
    [self.audience viewDidDisappear];
  }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer*)gestureRecognizer
       shouldReceiveTouch:(UITouch*)touch {
  return touch.view.accessibilityIdentifier !=
             ntp_home::FakeOmniboxAccessibilityID() &&
         touch.view.superview.accessibilityIdentifier !=
             ntp_home::FakeOmniboxAccessibilityID();
}

#pragma mark - UITraitEnvironment

- (void)traitCollectionDidChange:(UITraitCollection*)previousTraitCollection {
  [super traitCollectionDidChange:previousTraitCollection];
  if (IsContentSuggestionsUIModuleRefreshEnabled() &&
      previousTraitCollection.horizontalSizeClass !=
          self.traitCollection.horizontalSizeClass) {
    self.shortcutsContainerWidthAnchor.constant =
        GetModuleWidthForHorizontalTraitCollection(self.traitCollection);
    self.mostVisitedContainerWidthAnchor.constant =
        GetModuleWidthForHorizontalTraitCollection(self.traitCollection);
  }
}

#pragma mark - ContentSuggestionsConsumer

- (void)showReturnToRecentTabTileWithConfig:
    (ContentSuggestionsReturnToRecentTabItem*)config {
  self.returnToRecentTabTile = [[ContentSuggestionsReturnToRecentTabView alloc]
      initWithConfiguration:config];
  self.returnToRecentTabTapRecognizer = [[UITapGestureRecognizer alloc]
      initWithTarget:self
              action:@selector(contentSuggestionsElementTapped:)];
  [self.returnToRecentTabTile
      addGestureRecognizer:self.returnToRecentTabTapRecognizer];
  self.returnToRecentTabTapRecognizer.enabled = YES;
  // If the Content Suggestions is already shown, add the Return to Recent Tab
  // tile to the StackView.
  if ([[self.verticalStackView arrangedSubviews] count]) {
    UIView* parentView = self.returnToRecentTabTile;
    if (IsContentSuggestionsUIModuleRefreshEnabled()) {
      ContentSuggestionsModuleContainer* returnToRecentTabContainer =
          [[ContentSuggestionsModuleContainer alloc]
              initWithContentView:self.returnToRecentTabTile
                       moduleType:
                           ContentSuggestionsModuleTypeReturnToRecentTab];
      parentView = returnToRecentTabContainer;
      [self.verticalStackView insertArrangedSubview:returnToRecentTabContainer
                                            atIndex:0];
    } else {
      [self.verticalStackView insertArrangedSubview:self.returnToRecentTabTile
                                            atIndex:0];
      [self.verticalStackView
          setCustomSpacing:content_suggestions::
                               kReturnToRecentTabSectionBottomMargin
                 afterView:self.returnToRecentTabTile];
    }
    CGFloat cardWidth = content_suggestions::searchFieldWidth(
        self.view.bounds.size.width, self.traitCollection);
    [NSLayoutConstraint activateConstraints:@[
      [parentView.widthAnchor constraintEqualToConstant:cardWidth],
      [parentView.heightAnchor
          constraintEqualToConstant:kReturnToRecentTabSize.height]
    ]];
    [self.audience returnToRecentTabWasAdded];
  }
}

- (void)updateReturnToRecentTabTileWithConfig:
    (ContentSuggestionsReturnToRecentTabItem*)config {
  if (config.icon) {
    self.returnToRecentTabTile.iconImageView.image = config.icon;
    self.returnToRecentTabTile.iconImageView.hidden = NO;
  }
}

- (void)hideReturnToRecentTabTile {
  UIView* moduleView = [self.returnToRecentTabTile superview];
  [self.returnToRecentTabTile removeFromSuperview];
  self.returnToRecentTabTile = nil;
  if (IsContentSuggestionsUIModuleRefreshEnabled()) {
    // Remove module container.
    [moduleView removeFromSuperview];
  }
}

- (void)showWhatsNewViewWithConfig:(ContentSuggestionsWhatsNewItem*)config {
  self.whatsNewView =
      [[ContentSuggestionsWhatsNewView alloc] initWithConfiguration:config];
  self.promoTapRecognizer = [[UITapGestureRecognizer alloc]
      initWithTarget:self
              action:@selector(contentSuggestionsElementTapped:)];
  [self.whatsNewView addGestureRecognizer:self.promoTapRecognizer];
  self.promoTapRecognizer.enabled = YES;
}

- (void)hideWhatsNewView {
  [self.whatsNewView removeFromSuperview];
  self.whatsNewView = nil;
}

- (void)setMostVisitedTilesWithConfigs:
    (NSArray<ContentSuggestionsMostVisitedItem*>*)configs {
  if (!configs) {
    return;
  }
  if (IsContentSuggestionsUIModuleRefreshEnabled()) {
    self.mostVisitedModuleContainer.isPlaceholder = NO;
  }
  if ([self.mostVisitedViews count]) {
    for (ContentSuggestionsMostVisitedTileView* view in self.mostVisitedViews) {
      [view removeFromSuperview];
    }
    [self.mostVisitedViews removeAllObjects];
    [self.mostVisitedTapRecognizers removeAllObjects];
  } else {
    self.mostVisitedViews = [NSMutableArray array];
  }

  if ([configs count] == 0) {
    // No Most Visited Tiles to show. Remove module.
    [self.mostVisitedStackView removeFromSuperview];
    if (IsContentSuggestionsUIModuleRefreshEnabled()) {
      [self.mostVisitedModuleContainer removeFromSuperview];
    }
    return;
  }
  NSInteger index = 0;
  for (ContentSuggestionsMostVisitedItem* item in configs) {
    ContentSuggestionsMostVisitedTileView* view =
        [[ContentSuggestionsMostVisitedTileView alloc]
            initWithConfiguration:item];
    view.menuProvider = self.menuProvider;
    view.accessibilityIdentifier = [NSString
        stringWithFormat:
            @"%@%li",
            kContentSuggestionsMostVisitedAccessibilityIdentifierPrefix, index];
    [self.mostVisitedViews addObject:view];
    index++;
  }
  [self populateMostVisitedModule];
}

- (void)setShortcutTilesWithConfigs:
    (NSArray<ContentSuggestionsMostVisitedActionItem*>*)configs {
  if (!self.shortcutsViews) {
    self.shortcutsViews = [NSMutableArray array];
  }
  // Assumes this only called before viewDidLoad, so there is no need to add the
  // views into the view hierarchy here.
  for (ContentSuggestionsMostVisitedActionItem* item in configs) {
    ContentSuggestionsShortcutTileView* view =
        [[ContentSuggestionsShortcutTileView alloc] initWithConfiguration:item];
    [self.shortcutsViews addObject:view];
  }
}

- (void)updateReadingListCount:(NSInteger)count {
  for (ContentSuggestionsShortcutTileView* view in self.shortcutsViews) {
    if (view.config.collectionShortcutType ==
        NTPCollectionShortcutTypeReadingList) {
      [view updateCount:count];
      return;
    }
  }
}

- (void)setTrendingQueriesWithConfigs:
    (NSArray<QuerySuggestionConfig*>*)configs {
  DCHECK(IsTrendingQueriesModuleEnabled());
  self.trendingQueriesReceived = YES;
  if (!self.trendingQueriesContainingView) {
    self.trendingQueriesContainingView = [[UIView alloc] init];
  }
  self.trendingQueriesModuleContainer.isPlaceholder = NO;

  if ([self.trendingQueryViews count]) {
    for (QuerySuggestionView* view in self.trendingQueryViews) {
      [view removeFromSuperview];
    }
    [self.trendingQueryViews removeAllObjects];
    [self.trendingQueryTapRecognizers removeAllObjects];
  } else {
    self.trendingQueryViews = [NSMutableArray array];
  }

  if ((int)[configs count] < kMaxTrendingQueries) {
    // No Trending Queries to show. Remove module.
    [self.trendingQueriesContainingView removeFromSuperview];
    [self.trendingQueriesModuleContainer removeFromSuperview];
    [self.audience moduleWasRemoved];
    return;
  }

  for (QuerySuggestionConfig* config in configs) {
    QuerySuggestionView* view =
        [[QuerySuggestionView alloc] initWithConfiguration:config];
    //      view.menuProvider = self.menuProvider;
    view.accessibilityIdentifier =
        [NSString stringWithFormat:@"%@", config.query];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.trendingQueryViews addObject:view];
  }
  [self populateTrendingQueriesModule];
}

- (void)updateMostVisitedTileConfig:(ContentSuggestionsMostVisitedItem*)config {
  for (ContentSuggestionsMostVisitedTileView* view in self.mostVisitedViews) {
    if (view.config == config) {
      dispatch_async(dispatch_get_main_queue(), ^{
        [view.faviconView configureWithAttributes:config.attributes];
      });
      return;
    }
  }
}

- (CGFloat)contentSuggestionsHeight {
  CGFloat height = 0;
  if (IsContentSuggestionsUIModuleRefreshEnabled()) {
    height += [self.mostVisitedModuleContainer calculateIntrinsicHeight] +
              kModuleVerticalSpacing;
  } else if ([self.mostVisitedViews count] > 0) {
    height += MostVisitedCellSize(
                  UIApplication.sharedApplication.preferredContentSizeCategory)
                  .height +
              kMostVisitedBottomMargin;
  }
  if (IsContentSuggestionsUIModuleRefreshEnabled() &&
      IsTrendingQueriesModuleEnabled() &&
      [self.trendingQueriesModuleContainer superview]) {
    height += [self.trendingQueriesModuleContainer calculateIntrinsicHeight] +
              kModuleVerticalSpacing;
  }
  if ([self.shortcutsViews count] > 0) {
    if (IsContentSuggestionsUIModuleRefreshEnabled()) {
      height += [self.shortcutsModuleContainer calculateIntrinsicHeight] +
                kModuleVerticalSpacing;
    } else {
      height +=
          MostVisitedCellSize(
              UIApplication.sharedApplication.preferredContentSizeCategory)
              .height +
          kMostVisitedBottomMargin;
    }
  }
  if (self.returnToRecentTabTile) {
    height += (kReturnToRecentTabSize.height + kModuleVerticalSpacing);
  }
  if (self.whatsNewView) {
    height += MostVisitedCellSize(
                  UIApplication.sharedApplication.preferredContentSizeCategory)
                  .height;
  }
  return height;
}

#pragma mark - ContentSuggestionsSelectionActions

- (void)contentSuggestionsElementTapped:(UIGestureRecognizer*)sender {
  if ([sender.view
          isKindOfClass:[ContentSuggestionsMostVisitedTileView class]]) {
    ContentSuggestionsMostVisitedTileView* mostVisitedView =
        static_cast<ContentSuggestionsMostVisitedTileView*>(sender.view);
    [self.suggestionCommandHandler
        openMostVisitedItem:mostVisitedView.config
                    atIndex:mostVisitedView.config.index];
  } else if ([sender.view
                 isKindOfClass:[ContentSuggestionsShortcutTileView class]]) {
    ContentSuggestionsShortcutTileView* shortcutView =
        static_cast<ContentSuggestionsShortcutTileView*>(sender.view);
    int index = static_cast<int>(shortcutView.config.index);
    [self.suggestionCommandHandler openMostVisitedItem:shortcutView.config
                                               atIndex:index];
  } else if ([sender.view isKindOfClass:[ContentSuggestionsReturnToRecentTabView
                                            class]]) {
    ContentSuggestionsReturnToRecentTabView* returnToRecentTabView =
        static_cast<ContentSuggestionsReturnToRecentTabView*>(sender.view);
    __weak ContentSuggestionsReturnToRecentTabView* weakRecentTabView =
        returnToRecentTabView;
    UIGestureRecognizerState state = sender.state;
    if (state == UIGestureRecognizerStateChanged ||
        state == UIGestureRecognizerStateCancelled) {
      // Do nothing if isn't a gesture start or end.
      // If the gesture was cancelled by the system, then reset the background
      // color since UIGestureRecognizerStateEnded will not be received.
      if (state == UIGestureRecognizerStateCancelled) {
        returnToRecentTabView.backgroundColor = [UIColor clearColor];
      }
      return;
    }
    BOOL touchBegan = state == UIGestureRecognizerStateBegan;
    [UIView transitionWithView:returnToRecentTabView
                      duration:ios::material::kDuration8
                       options:UIViewAnimationOptionCurveEaseInOut
                    animations:^{
                      weakRecentTabView.backgroundColor =
                          touchBegan ? [UIColor colorNamed:kGrey100Color]
                                     : [UIColor clearColor];
                    }
                    completion:nil];
    if (state == UIGestureRecognizerStateEnded) {
      CGPoint point = [sender locationInView:returnToRecentTabView];
      if (point.x < 0 || point.y < 0 ||
          point.x > kReturnToRecentTabSize.width ||
          point.y > kReturnToRecentTabSize.height) {
        // Reset the highlighted state and do nothing if the gesture ended
        // outside of the tile.
        returnToRecentTabView.backgroundColor = [UIColor clearColor];
        return;
      }
      [self.suggestionCommandHandler openMostRecentTab];
    }
  } else if ([sender.view
                 isKindOfClass:[ContentSuggestionsWhatsNewView class]]) {
    [self.suggestionCommandHandler handlePromoTapped];
  } else if ([sender.view isKindOfClass:[QuerySuggestionView class]]) {
    QuerySuggestionView* querySuggestionView =
        static_cast<QuerySuggestionView*>(sender.view);
    [self.suggestionCommandHandler
        loadSuggestedQuery:querySuggestionView.config];
  }
}

#pragma mark - Private

- (void)addUIElement:(UIView*)view withCustomBottomSpacing:(CGFloat)spacing {
  [self.verticalStackView addArrangedSubview:view];
  if (spacing > 0) {
    [self.verticalStackView setCustomSpacing:spacing afterView:view];
  }
}

// Add the elements in `mostVisitedViews` into `verticalStackView`, constructing
// `verticalStackView` beforehand if it has not been yet.
- (void)populateMostVisitedModule {
  // If viewDidLoad has been called before the first valid Most Visited Tiles
  // are available, construct `mostVisitedStackView`.
  if (!IsContentSuggestionsUIModuleRefreshEnabled() && self.verticalStackView &&
      !self.mostVisitedStackView) {
    self.mostVisitedStackView = [[UIStackView alloc] init];
    self.mostVisitedStackView.axis = UILayoutConstraintAxisHorizontal;
    self.mostVisitedStackView.alignment = UIStackViewAlignmentTop;
    self.mostVisitedStackView.distribution = UIStackViewDistributionFillEqually;
    self.mostVisitedStackView.spacing =
        ContentSuggestionsTilesHorizontalSpacing(self.traitCollection);
    // Find correct insertion position in the stack.
    int insertionIndex = 0;
    if (self.returnToRecentTabTile) {
      insertionIndex++;
    }
    if (self.whatsNewView) {
      insertionIndex++;
    }
    [self.verticalStackView insertArrangedSubview:self.mostVisitedStackView
                                          atIndex:insertionIndex];
    [self.verticalStackView setCustomSpacing:kMostVisitedBottomMargin
                                   afterView:self.mostVisitedStackView];
    CGFloat width =
        MostVisitedTilesContentHorizontalSpace(self.traitCollection);
    CGSize size =
        MostVisitedCellSize(self.traitCollection.preferredContentSizeCategory);
    [NSLayoutConstraint activateConstraints:@[
      [self.mostVisitedStackView.widthAnchor constraintEqualToConstant:width],
      [self.mostVisitedStackView.heightAnchor
          constraintEqualToConstant:size.height]
    ]];
  }
  for (ContentSuggestionsMostVisitedTileView* view in self.mostVisitedViews) {
    view.menuProvider = self.menuProvider;
    UITapGestureRecognizer* tapRecognizer = [[UITapGestureRecognizer alloc]
        initWithTarget:self
                action:@selector(contentSuggestionsElementTapped:)];
    [view addGestureRecognizer:tapRecognizer];
    tapRecognizer.enabled = YES;
    [self.mostVisitedTapRecognizers addObject:tapRecognizer];
    [self.mostVisitedStackView addArrangedSubview:view];
  }
}

- (void)populateTrendingQueriesModule {
  for (QuerySuggestionView* view in self.trendingQueryViews) {
    UITapGestureRecognizer* tapRecognizer = [[UITapGestureRecognizer alloc]
        initWithTarget:self
                action:@selector(contentSuggestionsElementTapped:)];
    [view addGestureRecognizer:tapRecognizer];
    tapRecognizer.enabled = YES;
    [self.trendingQueryTapRecognizers addObject:tapRecognizer];
    [self.trendingQueriesContainingView addSubview:view];
  }
  QuerySuggestionView* query1 = self.trendingQueryViews[0];
  [query1 addBottomSeparator];
  QuerySuggestionView* query2 = self.trendingQueryViews[1];
  [query2 addBottomSeparator];
  QuerySuggestionView* query3 = self.trendingQueryViews[2];
  QuerySuggestionView* query4 = self.trendingQueryViews[3];
  [NSLayoutConstraint activateConstraints:@[
    [query1.topAnchor
        constraintEqualToAnchor:self.trendingQueriesContainingView.topAnchor],
    [query1.leadingAnchor
        constraintEqualToAnchor:self.trendingQueriesContainingView
                                    .leadingAnchor],
    [query2.leadingAnchor
        constraintGreaterThanOrEqualToAnchor:query1.trailingAnchor
                                    constant:
                                        kTrendingQueryViewHorizontalSpacing],
    [query2.topAnchor
        constraintEqualToAnchor:self.trendingQueriesContainingView.topAnchor],
    [query2.trailingAnchor
        constraintEqualToAnchor:self.trendingQueriesContainingView
                                    .trailingAnchor],
    [query3.leadingAnchor
        constraintEqualToAnchor:self.trendingQueriesContainingView
                                    .leadingAnchor],
    [query3.bottomAnchor
        constraintEqualToAnchor:self.trendingQueriesContainingView
                                    .bottomAnchor],
    [query3.topAnchor constraintEqualToAnchor:query1.bottomAnchor],
    [query4.leadingAnchor
        constraintGreaterThanOrEqualToAnchor:query3.trailingAnchor
                                    constant:
                                        kTrendingQueryViewHorizontalSpacing],
    [query4.bottomAnchor
        constraintEqualToAnchor:self.trendingQueriesContainingView
                                    .bottomAnchor],
    [query4.trailingAnchor
        constraintEqualToAnchor:self.trendingQueriesContainingView
                                    .trailingAnchor],
    [query4.topAnchor constraintEqualToAnchor:query3.topAnchor]
  ]];
}

@end
