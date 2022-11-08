// Copyright 2019 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/omnibox/popup/omnibox_popup_view_controller.h"

#import "base/format_macros.h"
#import "base/logging.h"
#import "base/mac/foundation_util.h"
#import "base/metrics/histogram_macros.h"
#import "base/time/time.h"
#import "components/favicon/core/large_icon_service.h"
#import "components/omnibox/common/omnibox_features.h"
#import "ios/chrome/browser/net/crurl.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_tile_layout_util.h"
#import "ios/chrome/browser/ui/elements/self_sizing_table_view.h"
#import "ios/chrome/browser/ui/favicon/favicon_attributes_provider.h"
#import "ios/chrome/browser/ui/favicon/favicon_attributes_with_payload.h"
#import "ios/chrome/browser/ui/omnibox/omnibox_constants.h"
#import "ios/chrome/browser/ui/omnibox/omnibox_ui_features.h"
#import "ios/chrome/browser/ui/omnibox/popup/autocomplete_suggestion.h"
#import "ios/chrome/browser/ui/omnibox/popup/carousel_item.h"
#import "ios/chrome/browser/ui/omnibox/popup/content_providing.h"
#import "ios/chrome/browser/ui/omnibox/popup/omnibox_popup_accessibility_identifier_constants.h"
#import "ios/chrome/browser/ui/omnibox/popup/omnibox_popup_carousel_cell.h"
#import "ios/chrome/browser/ui/omnibox/popup/omnibox_popup_row_cell.h"
#import "ios/chrome/browser/ui/omnibox/popup/popup_match_preview_delegate.h"
#import "ios/chrome/browser/ui/toolbar/buttons/toolbar_configuration.h"
#import "ios/chrome/browser/ui/util/keyboard_observer_helper.h"
#import "ios/chrome/browser/ui/util/layout_guide_names.h"
#import "ios/chrome/browser/ui/util/named_guide.h"
#import "ios/chrome/browser/ui/util/uikit_ui_util.h"
#import "ios/chrome/common/ui/colors/semantic_color_names.h"
#import "ios/chrome/common/ui/util/constraints_ui_util.h"
#import "ios/chrome/common/ui/util/device_util.h"
#import "ui/base/device_form_factor.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
const CGFloat kTopAndBottomPadding = 8.0;
const CGFloat kTopPaddingVariation1 = 8.0;
const CGFloat kTopPaddingVariation2 = 10.0;
const CGFloat kTopBottomPaddingVariation2Ipad = 16.0;
const CGFloat kFooterHeightVariation1 = 12.0;
const CGFloat kFooterHeightVariation2 = 16.0;
// Percentage of the suggestion height that needs to be visible in order to
// consider the suggestion as visible.
const CGFloat kVisibleSuggestionThreshold = 0.6;
// Minimum size of the fetched favicon for tiles.
const CGFloat kMinTileFaviconSize = 32.0f;
// Maximum size of the fetched favicon for tiles.
const CGFloat kMaxTileFaviconSize = 48.0f;

// Bottom padding for table view headers, variation 2.
const CGFloat kHeaderPaddingBottomVariation2 = 10.0f;
// Leading, trailing, and top padding for table view headers, variation 2.
const CGFloat kHeaderPaddingVariation2 = 2.0f;
}  // namespace

@interface OmniboxPopupViewController () <UITableViewDataSource,
                                          UITableViewDelegate,
                                          OmniboxPopupCarouselCellDelegate,
                                          OmniboxPopupRowCellDelegate>

// Index path of currently highlighted row. The rows can be highlighted by
// tapping and holding on them or by using arrow keys on a hardware keyboard.
@property(nonatomic, strong) NSIndexPath* highlightedIndexPath;

// Flag that enables forwarding scroll events to the delegate. Disabled while
// updating the cells to avoid defocusing the omnibox when the omnibox popup
// changes size and table view issues a scroll event.
@property(nonatomic, assign) BOOL forwardsScrollEvents;

// The height of the keyboard. Used to determine the content inset for the
// scroll view.
@property(nonatomic, assign) CGFloat keyboardHeight;

// Time the view appeared on screen. Used to record a metric of how long this
// view controller was on screen.
@property(nonatomic, assign) base::TimeTicks viewAppearanceTime;
// Table view that displays the results.
@property(nonatomic, strong) UITableView* tableView;

// Alignment of omnibox text. Popup text should match this alignment.
@property(nonatomic, assign) NSTextAlignment alignment;

// Semantic content attribute of omnibox text. Popup should match this
// attribute. This is used by the new omnibox popup.
@property(nonatomic, assign)
    UISemanticContentAttribute semanticContentAttribute;

// Estimated maximum number of visible suggestions.
// Only updated in `newResultsAvailable` method, were the value is used.
@property(nonatomic, assign) NSUInteger visibleSuggestionCount;

// Boolean to update visible suggestion count only once on event such as device
// orientation change or multitasking window change, where multiple keyboard and
// view updates are received.
@property(nonatomic, assign) BOOL shouldUpdateVisibleSuggestionCount;

// Index of the suggestion group that contains the first suggestion to preview
// and highlight.
@property(nonatomic, assign) NSUInteger preselectedMatchGroupIndex;

// Provider used to fetch carousel favicons.
@property(nonatomic, strong)
    FaviconAttributesProvider* carouselAttributeProvider;

// UITableViewCell displaying the most visited carousel in (Web and SRP) ZPS
// state.
@property(nonatomic, strong) OmniboxPopupCarouselCell* carouselCell;

@end

@implementation OmniboxPopupViewController

- (instancetype)init {
  if (self = [super initWithNibName:nil bundle:nil]) {
    _forwardsScrollEvents = YES;
    _preselectedMatchGroupIndex = 0;
    _visibleSuggestionCount = 0;
    NSNotificationCenter* defaultCenter = [NSNotificationCenter defaultCenter];
    if (ui::GetDeviceFormFactor() == ui::DEVICE_FORM_FACTOR_TABLET) {
      // The iPad keyboard can cover some of the rows of the scroll view. The
      // scroll view's content inset may need to be updated when the keyboard is
      // displayed.
      [defaultCenter addObserver:self
                        selector:@selector(keyboardDidShow:)
                            name:UIKeyboardDidShowNotification
                          object:nil];
    }
    // Listen to keyboard frame change event to detect keyboard frame changes
    // (ex: when changing input method) to update the estimated number of
    // visible suggestions.
    [defaultCenter addObserver:self
                      selector:@selector(keyboardDidChangeFrame:)
                          name:UIKeyboardDidChangeFrameNotification
                        object:nil];

    // Listen to content size change to update the estimated number of visible
    // suggestions.
    [defaultCenter addObserver:self
                      selector:@selector(contentSizeDidChange:)
                          name:UIContentSizeCategoryDidChangeNotification
                        object:nil];
  }
  return self;
}

- (void)loadView {
  // TODO(crbug.com/1365374): Check why largeIconService not available in
  // icognito.
  if (self.largeIconService) {
    _carouselAttributeProvider = [[FaviconAttributesProvider alloc]
        initWithFaviconSize:kMaxTileFaviconSize
             minFaviconSize:kMinTileFaviconSize
           largeIconService:self.largeIconService];
    _carouselAttributeProvider.cache = self.largeIconCache;
  }
  UITableViewStyle style = IsOmniboxActionsVisualTreatment2()
                               ? UITableViewStyleInsetGrouped
                               : UITableViewStylePlain;
  self.tableView = [[SelfSizingTableView alloc] initWithFrame:CGRectZero
                                                        style:style];
  self.tableView.delegate = self;
  self.tableView.dataSource = self;
  self.view = self.tableView;
}

- (void)traitCollectionDidChange:(UITraitCollection*)previousTraitCollection {
  [super traitCollectionDidChange:previousTraitCollection];
  [self updateBackgroundColor];
}

#pragma mark - Getter/Setter

- (void)setHighlightedIndexPath:(NSIndexPath*)highlightedIndexPath {
  // Special case for highlight moving inside a carousel-style section.
  if (_highlightedIndexPath &&
      highlightedIndexPath.section == _highlightedIndexPath.section &&
      self.currentResult[highlightedIndexPath.section].displayStyle ==
          SuggestionGroupDisplayStyleCarousel) {
    // The highlight moved inside the section horizontally. No need to
    // unhighlight the previous row. Just notify the delegate.
    _highlightedIndexPath = highlightedIndexPath;
    [self didHighlightSelectedSuggestion];
    return;
  }

  // General case: highlighting moved between different rows.
  if (_highlightedIndexPath) {
    [self unhighlightRowAtIndexPath:_highlightedIndexPath];
  }
  _highlightedIndexPath = highlightedIndexPath;
  if (highlightedIndexPath) {
    [self highlightRowAtIndexPath:_highlightedIndexPath];
    [self didHighlightSelectedSuggestion];
  }
}

- (OmniboxPopupCarouselCell*)carouselCell {
  DCHECK(base::FeatureList::IsEnabled(omnibox::kMostVisitedTiles));
  if (!_carouselCell) {
    _carouselCell = [[OmniboxPopupCarouselCell alloc] init];
    _carouselCell.delegate = self;
    _carouselCell.menuProvider = self.carouselMenuProvider;
  }
  return _carouselCell;
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
  [super viewDidLoad];

  self.tableView.accessibilityIdentifier =
      kOmniboxPopupTableViewAccessibilityIdentifier;
  self.tableView.insetsContentViewsToSafeArea = YES;

  // Initialize the same size as the parent view, autoresize will correct this.
  [self.view setFrame:CGRectZero];
  [self.view setAutoresizingMask:(UIViewAutoresizingFlexibleWidth |
                                  UIViewAutoresizingFlexibleHeight)];

  [self updateBackgroundColor];

  // Table configuration.
  self.tableView.allowsMultipleSelectionDuringEditing = NO;
  self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  self.tableView.separatorInset = UIEdgeInsetsZero;
  if ([self.tableView respondsToSelector:@selector(setLayoutMargins:)]) {
    [self.tableView setLayoutMargins:UIEdgeInsetsZero];
  }
  self.tableView.contentInsetAdjustmentBehavior =
      IsOmniboxActionsVisualTreatment2()
          ? UIScrollViewContentInsetAdjustmentNever
          : UIScrollViewContentInsetAdjustmentAutomatic;
  [self.tableView setContentInset:UIEdgeInsetsMake(self.topPadding, 0,
                                                   self.bottomPadding, 0)];

  self.tableView.sectionHeaderHeight = 0.1;
  self.tableView.estimatedRowHeight = 0;

  self.tableView.rowHeight = UITableViewAutomaticDimension;
  self.tableView.estimatedRowHeight = kOmniboxPopupCellMinimumHeight;

  [self.tableView registerClass:[OmniboxPopupRowCell class]
         forCellReuseIdentifier:OmniboxPopupRowCellReuseIdentifier];
  [self.tableView registerClass:[UITableViewHeaderFooterView class]
      forHeaderFooterViewReuseIdentifier:NSStringFromClass(
                                             [UITableViewHeaderFooterView
                                                 class])];
  self.shouldUpdateVisibleSuggestionCount = YES;

  if (@available(iOS 15.0, *)) {
    self.tableView.sectionHeaderTopPadding = 0;
  }
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  if (IsOmniboxActionsVisualTreatment2()) {
    [self adjustMarginsToMatchOmniboxWidth];
  }

  self.viewAppearanceTime = base::TimeTicks::Now();
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];
  UMA_HISTOGRAM_MEDIUM_TIMES("MobileOmnibox.PopupOpenDuration",
                             base::TimeTicks::Now() - self.viewAppearanceTime);
}

- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:
           (id<UIViewControllerTransitionCoordinator>)coordinator {
  [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
  [self.tableView setEditing:NO animated:NO];
  self.shouldUpdateVisibleSuggestionCount = YES;

  if (IsOmniboxActionsVisualTreatment2()) {
    [coordinator
        animateAlongsideTransition:^(
            id<UIViewControllerTransitionCoordinatorContext> context) {
          [self adjustMarginsToMatchOmniboxWidth];
        }
                        completion:nil];
  }
}

- (void)adjustMarginsToMatchOmniboxWidth {
  NamedGuide* layoutGuide = [NamedGuide guideWithName:kOmniboxGuide
                                                 view:self.view];
  if (!layoutGuide) {
    return;
  }

  CGRect omniboxFrame = [layoutGuide.constrainedView
      convertRect:layoutGuide.constrainedView.bounds
           toView:self.view];
  CGFloat leftMargin =
      IsRegularXRegularSizeClass(self) ? omniboxFrame.origin.x : 0;
  CGFloat rightMargin = IsRegularXRegularSizeClass(self)
                            ? self.view.bounds.size.width -
                                  omniboxFrame.origin.x -
                                  omniboxFrame.size.width
                            : 0;
  self.tableView.layoutMargins =
      UIEdgeInsetsMake(self.tableView.layoutMargins.top, leftMargin,
                       self.tableView.layoutMargins.bottom, rightMargin);
}

#pragma mark - AutocompleteResultConsumer

- (void)updateMatches:(NSArray<id<AutocompleteSuggestionGroup>>*)result
    preselectedMatchGroupIndex:(NSInteger)groupIndex {
  DCHECK(groupIndex == 0 || groupIndex < (NSInteger)result.count);
  self.forwardsScrollEvents = NO;
  // Reset highlight state.
  self.highlightedIndexPath = nil;

  self.preselectedMatchGroupIndex = groupIndex;
  self.currentResult = result;

  [self.tableView reloadData];
  self.forwardsScrollEvents = YES;
  id<AutocompleteSuggestion> firstSuggestionOfPreselectedGroup =
      [self suggestionAtIndexPath:[NSIndexPath indexPathForRow:0
                                                     inSection:groupIndex]];
  [self.matchPreviewDelegate
      setPreviewSuggestion:firstSuggestionOfPreselectedGroup
             isFirstUpdate:YES];
}

// Set text alignment for popup cells.
- (void)setTextAlignment:(NSTextAlignment)alignment {
  self.alignment = alignment;
}

- (void)newResultsAvailable {
  if (self.shouldUpdateVisibleSuggestionCount) {
    [self updateVisibleSuggestionCount];
  }
  [self.dataSource
      requestResultsWithVisibleSuggestionCount:self.visibleSuggestionCount];
}

#pragma mark - OmniboxKeyboardDelegate

- (BOOL)canPerformKeyboardAction:(OmniboxKeyboardAction)keyboardAction {
  switch (keyboardAction) {
    case OmniboxKeyboardActionUpArrow:
    case OmniboxKeyboardActionDownArrow:
      return YES;
    case OmniboxKeyboardActionLeftArrow:
    case OmniboxKeyboardActionRightArrow:
      if (base::FeatureList::IsEnabled(omnibox::kMostVisitedTiles) &&
          self.carouselCell.isHighlighted) {
        return [self.carouselCell canPerformKeyboardAction:keyboardAction];
      }
      return NO;
  }
}

- (void)performKeyboardAction:(OmniboxKeyboardAction)keyboardAction {
  DCHECK([self canPerformKeyboardAction:keyboardAction]);
  switch (keyboardAction) {
    case OmniboxKeyboardActionUpArrow:
      [self highlightPreviousSuggestion];
      break;
    case OmniboxKeyboardActionDownArrow:
      [self highlightNextSuggestion];
      break;
    case OmniboxKeyboardActionLeftArrow:
    case OmniboxKeyboardActionRightArrow:
      if (self.carouselCell.isHighlighted) {
        DCHECK(self.highlightedIndexPath.section ==
               [self.tableView indexPathForCell:self.carouselCell].section);

        [self.carouselCell performKeyboardAction:keyboardAction];
        NSInteger highlightedTileIndex = self.carouselCell.highlightedTileIndex;
        if (highlightedTileIndex == NSNotFound) {
          self.highlightedIndexPath = nil;
        } else {
          self.highlightedIndexPath =
              [NSIndexPath indexPathForRow:highlightedTileIndex
                                 inSection:self.highlightedIndexPath.section];
        }
      }
      break;
  }
}

#pragma mark OmniboxKeyboardDelegate Private

- (void)highlightPreviousSuggestion {
  NSIndexPath* path = self.highlightedIndexPath;
  if (path == nil) {
    // If there is a section above `preselectedMatchGroupIndex` select the last
    // suggestion of this section.
    if (self.preselectedMatchGroupIndex > 0 &&
        self.currentResult.count > self.preselectedMatchGroupIndex - 1) {
      NSInteger sectionAbovePreselectedGroup =
          self.preselectedMatchGroupIndex - 1;
      NSIndexPath* suggestionIndex = [NSIndexPath
          indexPathForRow:(NSInteger)self
                              .currentResult[sectionAbovePreselectedGroup]
                              .suggestions.count -
                          1
                inSection:sectionAbovePreselectedGroup];
      if ([self suggestionAtIndexPath:suggestionIndex]) {
        self.highlightedIndexPath = suggestionIndex;
      }
    }
    return;
  }

  id<AutocompleteSuggestionGroup> suggestionGroup =
      self.currentResult[self.highlightedIndexPath.section];
  BOOL isCurrentHighlightedRowFirstInSection =
      suggestionGroup.displayStyle == SuggestionGroupDisplayStyleCarousel ||
      (path.row == 0);

  if (isCurrentHighlightedRowFirstInSection) {
    NSInteger previousSection = path.section - 1;
    NSInteger previousSectionCount =
        (previousSection >= 0)
            ? [self.tableView numberOfRowsInSection:previousSection]
            : 0;
    BOOL prevSectionHasItems = previousSectionCount > 0;
    if (prevSectionHasItems) {
      path = [NSIndexPath indexPathForRow:previousSectionCount - 1
                                inSection:previousSection];
    } else {
      // Can't move up from first row. Call the delegate again so that the
      // inline autocomplete text is set again (in case the user exited the
      // inline autocomplete).
      [self didHighlightSelectedSuggestion];
      return;
    }
  } else {
    path = [NSIndexPath indexPathForRow:path.row - 1 inSection:path.section];
  }

  self.highlightedIndexPath = path;
}

- (void)highlightNextSuggestion {
  if (!self.highlightedIndexPath) {
    NSIndexPath* preselectedSuggestionIndex =
        [NSIndexPath indexPathForRow:0
                           inSection:self.preselectedMatchGroupIndex];
    if ([self suggestionAtIndexPath:preselectedSuggestionIndex]) {
      self.highlightedIndexPath = preselectedSuggestionIndex;
    }
    return;
  }

  NSIndexPath* path = self.highlightedIndexPath;
  id<AutocompleteSuggestionGroup> suggestionGroup =
      self.currentResult[self.highlightedIndexPath.section];
  BOOL isCurrentHighlightedRowLastInSection =
      suggestionGroup.displayStyle == SuggestionGroupDisplayStyleCarousel ||
      path.row == [self.tableView numberOfRowsInSection:path.section] - 1;
  if (isCurrentHighlightedRowLastInSection) {
    NSInteger nextSection = path.section + 1;
    BOOL nextSectionHasItems =
        [self.tableView numberOfSections] > nextSection &&
        [self.tableView numberOfRowsInSection:nextSection] > 0;

    if (nextSectionHasItems) {
      path = [NSIndexPath indexPathForRow:0 inSection:nextSection];
    } else {
      // Can't go below last row. Call the delegate again so that the inline
      // autocomplete text is set again (in case the user exited the inline
      // autocomplete).
      [self didHighlightSelectedSuggestion];
      return;
    }
  } else {
    path = [NSIndexPath indexPathForRow:path.row + 1 inSection:path.section];
  }

  // There is a row below, move highlight there.
  self.highlightedIndexPath = path;
}

- (void)highlightRowAtIndexPath:(NSIndexPath*)indexPath {
  if (self.currentResult[indexPath.section].displayStyle ==
      SuggestionGroupDisplayStyleCarousel) {
    indexPath = [NSIndexPath indexPathForRow:0 inSection:indexPath.section];
  }
  UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
  [cell setHighlighted:YES animated:NO];
}

- (void)unhighlightRowAtIndexPath:(NSIndexPath*)indexPath {
  if (self.currentResult[indexPath.section].displayStyle ==
      SuggestionGroupDisplayStyleCarousel) {
    indexPath = [NSIndexPath indexPathForRow:0 inSection:indexPath.section];
  }
  UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
  [cell setHighlighted:NO animated:NO];
}

- (void)didHighlightSelectedSuggestion {
  id<AutocompleteSuggestion> suggestion =
      [self suggestionAtIndexPath:self.highlightedIndexPath];
  DCHECK(suggestion);
  [self.matchPreviewDelegate setPreviewSuggestion:suggestion isFirstUpdate:NO];
}

#pragma mark - OmniboxPopupRowCellDelegate

- (void)trailingButtonTappedForCell:(OmniboxPopupRowCell*)cell {
  NSIndexPath* indexPath = [self.tableView indexPathForCell:cell];
  id<AutocompleteSuggestion> suggestion =
      [self suggestionAtIndexPath:indexPath];
  DCHECK(suggestion);
  [self.delegate autocompleteResultConsumer:self
           didTapTrailingButtonOnSuggestion:suggestion
                                      inRow:indexPath.row];
}

#pragma mark - OmniboxReturnDelegate

- (void)omniboxReturnPressed:(id)sender {
  if (self.highlightedIndexPath) {
    id<AutocompleteSuggestion> suggestion =
        [self suggestionAtIndexPath:self.highlightedIndexPath];
    if (suggestion) {
      NSInteger absoluteRow =
          [self absoluteRowIndexForIndexPath:self.highlightedIndexPath];
      [self.delegate autocompleteResultConsumer:self
                            didSelectSuggestion:suggestion
                                          inRow:absoluteRow];
      return;
    }
  }
  [self.acceptReturnDelegate omniboxReturnPressed:sender];
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView*)tableView
      willDisplayCell:(UITableViewCell*)cell
    forRowAtIndexPath:(NSIndexPath*)indexPath {
  if ([cell isKindOfClass:[OmniboxPopupRowCell class]]) {
    OmniboxPopupRowCell* rowCell =
        base::mac::ObjCCastStrict<OmniboxPopupRowCell>(cell);
    // This has to be set here because the cell's content view has its
    // semantic content attribute reset before the cell is displayed (and before
    // this method is called).
    rowCell.omniboxSemanticContentAttribute = self.semanticContentAttribute;

    rowCell.accessibilityIdentifier = [OmniboxPopupAccessibilityIdentifierHelper
        accessibilityIdentifierForRowAtIndexPath:indexPath];
  }
}

- (BOOL)tableView:(UITableView*)tableView
    shouldHighlightRowAtIndexPath:(NSIndexPath*)indexPath {
  return YES;
}

- (void)tableView:(UITableView*)tableView
    didSelectRowAtIndexPath:(NSIndexPath*)indexPath {
  NSUInteger row = indexPath.row;
  NSUInteger section = indexPath.section;
  DCHECK_LT(section, self.currentResult.count);
  DCHECK_LT(row, self.currentResult[indexPath.section].suggestions.count);

  // Crash reports tell us that `section` and `row` are sometimes indexed past
  // the end of the results array. In those cases, just ignore the request and
  // return early. See crbug.com/1378590.
  if (section >= self.currentResult.count ||
      row >= self.currentResult[indexPath.section].suggestions.count)
    return;
  NSInteger absoluteRow = [self absoluteRowIndexForIndexPath:indexPath];
  [self.delegate
      autocompleteResultConsumer:self
             didSelectSuggestion:[self suggestionAtIndexPath:indexPath]
                           inRow:absoluteRow];
}

- (CGFloat)tableView:(UITableView*)tableView
    heightForHeaderInSection:(NSInteger)section {
  if (!IsOmniboxActionsEnabled() &&
      !base::FeatureList::IsEnabled(omnibox::kMostVisitedTiles)) {
    return FLT_MIN;
  }
  BOOL hasTitle = self.currentResult[section].title.length > 0;
  return hasTitle ? UITableViewAutomaticDimension : FLT_MIN;
}

- (CGFloat)tableView:(UITableView*)tableView
    heightForFooterInSection:(NSInteger)section {
  if (!IsOmniboxActionsEnabled()) {
    return FLT_MIN;
  }
  // Don't show the footer on the last section, to not increase the size of the
  // popup on iPad.
  if (section == (tableView.numberOfSections - 1)) {
    return FLT_MIN;
  }

  return IsOmniboxActionsVisualTreatment1() ? kFooterHeightVariation1
                                            : kFooterHeightVariation2;
}

- (UIView*)tableView:(UITableView*)tableView
    viewForFooterInSection:(NSInteger)section {
  if (!IsOmniboxActionsEnabled()) {
    return nil;
  }

  // Do not show footer for the last section
  if (section == (tableView.numberOfSections - 1)) {
    return nil;
  }
  if (IsOmniboxActionsVisualTreatment2()) {
    return [[UIView alloc] init];
  }

  if (base::FeatureList::IsEnabled(omnibox::kMostVisitedTiles)) {
    return nil;
  }

  UIView* footer = [[UIView alloc] init];
  footer.backgroundColor = tableView.backgroundColor;
  UIView* hairline = [[UIView alloc]
      initWithFrame:CGRectMake(0, 8, tableView.bounds.size.width,
                               2 / tableView.window.screen.scale)];
  hairline.backgroundColor =
      self.incognito ? [UIColor.whiteColor colorWithAlphaComponent:0.12]
                     : [UIColor.blackColor colorWithAlphaComponent:0.12];
  [footer addSubview:hairline];
  hairline.autoresizingMask = UIViewAutoresizingFlexibleWidth;

  return footer;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView {
  return self.currentResult.count;
}

- (NSInteger)tableView:(UITableView*)tableView
    numberOfRowsInSection:(NSInteger)section {
  switch (self.currentResult[section].displayStyle) {
    case SuggestionGroupDisplayStyleDefault:
      return self.currentResult[section].suggestions.count;
    case SuggestionGroupDisplayStyleCarousel:
      DCHECK(base::FeatureList::IsEnabled(omnibox::kMostVisitedTiles));
      // The carousel displays suggestions on one row.
      return 1;
  }
}

- (BOOL)tableView:(UITableView*)tableView
    canEditRowAtIndexPath:(NSIndexPath*)indexPath {
  // iOS doesn't check -numberOfRowsInSection before checking
  // -canEditRowAtIndexPath in a reload call. If `indexPath.row` is too large,
  // simple return `NO`.
  if ((NSUInteger)indexPath.row >=
      self.currentResult[indexPath.section].suggestions.count)
    return NO;

  if (self.currentResult[indexPath.section].displayStyle ==
      SuggestionGroupDisplayStyleCarousel) {
    return NO;
  }

  return [self.currentResult[indexPath.section].suggestions[indexPath.row]
      supportsDeletion];
}

- (void)tableView:(UITableView*)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
     forRowAtIndexPath:(NSIndexPath*)indexPath {
  DCHECK_LT((NSUInteger)indexPath.row,
            self.currentResult[indexPath.section].suggestions.count);
  id<AutocompleteSuggestion> suggestion =
      [self suggestionAtIndexPath:indexPath];
  DCHECK(suggestion);
  if (editingStyle == UITableViewCellEditingStyleDelete) {
    [self.delegate autocompleteResultConsumer:self
               didSelectSuggestionForDeletion:suggestion
                                        inRow:indexPath.row];
  }
}

- (CGFloat)tableView:(UITableView*)tableView
    heightForRowAtIndexPath:(NSIndexPath*)indexPath {
  return UITableViewAutomaticDimension;
}

- (UIView*)tableView:(UITableView*)tableView
    viewForHeaderInSection:(NSInteger)section {
  NSString* title = self.currentResult[section].title;
  if (!title) {
    return nil;
  }

  UITableViewHeaderFooterView* header =
      [tableView dequeueReusableHeaderFooterViewWithIdentifier:
                     NSStringFromClass([UITableViewHeaderFooterView class])];

  UIListContentConfiguration* contentConfiguration =
      header.defaultContentConfiguration;

  contentConfiguration.text = title;
  contentConfiguration.textProperties.font =
      [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
  contentConfiguration.textProperties.transform =
      UIListContentTextTransformUppercase;
  contentConfiguration.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(
      kHeaderPaddingVariation2, kHeaderPaddingVariation2,
      kHeaderPaddingBottomVariation2, kHeaderPaddingVariation2);

  header.contentConfiguration = contentConfiguration;
  return header;
}

// Customize the appearance of table view cells.
- (UITableViewCell*)tableView:(UITableView*)tableView
        cellForRowAtIndexPath:(NSIndexPath*)indexPath {
  DCHECK_LT((NSUInteger)indexPath.row,
            self.currentResult[indexPath.section].suggestions.count);

  switch (self.currentResult[indexPath.section].displayStyle) {
    case SuggestionGroupDisplayStyleDefault: {
      OmniboxPopupRowCell* cell = [self.tableView
          dequeueReusableCellWithIdentifier:OmniboxPopupRowCellReuseIdentifier
                               forIndexPath:indexPath];
      cell.faviconRetriever = self.faviconRetriever;
      cell.imageRetriever = self.imageRetriever;
      [cell
          setupWithAutocompleteSuggestion:self.currentResult[indexPath.section]
                                              .suggestions[indexPath.row]
                                incognito:self.incognito];
      cell.showsSeparator =
          (NSUInteger)indexPath.row <
          self.currentResult[indexPath.section].suggestions.count - 1;
      cell.delegate = self;
      return cell;
    }
    case SuggestionGroupDisplayStyleCarousel: {
      DCHECK(base::FeatureList::IsEnabled(omnibox::kMostVisitedTiles));
      NSArray<CarouselItem*>* carouselItems = [self
          carouselItemsFromSuggestionGroup:self.currentResult[indexPath.section]
                            groupIndexPath:indexPath];
      [self.carouselCell setupWithCarouselItems:carouselItems];
      for (CarouselItem* item in carouselItems) {
        [self fetchFaviconForCarouselItem:item];
      }
      return self.carouselCell;
    }
  }
}

#pragma mark - OmniboxPopupCarouselCellDelegate

- (void)carouselCellDidChangeVisibleCount:
    (OmniboxPopupCarouselCell*)carouselCell {
  if (self.highlightedIndexPath.section !=
      [self.tableView indexPathForCell:self.carouselCell].section) {
    return;
  }

  // Defensively update highlightedIndexPath, because the highlighted tile might
  // have been removed.
  NSInteger highlightedTileIndex = self.carouselCell.highlightedTileIndex;
  if (highlightedTileIndex == NSNotFound) {
    [self resetHighlighting];
  } else {
    self.highlightedIndexPath =
        [NSIndexPath indexPathForRow:highlightedTileIndex
                           inSection:self.highlightedIndexPath.section];
  }
}

- (void)carouselCell:(OmniboxPopupCarouselCell*)carouselCell
    didTapCarouselItem:(CarouselItem*)carouselItem {
  id<AutocompleteSuggestion> suggestion =
      [self suggestionAtIndexPath:carouselItem.indexPath];
  DCHECK(suggestion);

  NSInteger absoluteRow =
      [self absoluteRowIndexForIndexPath:carouselItem.indexPath];
  [self.delegate autocompleteResultConsumer:self
                        didSelectSuggestion:suggestion
                                      inRow:absoluteRow];
}

#pragma mark - Internal API methods

// Reset the highlighting to the first suggestion when it's available. Reset
// to nil otherwise.
- (void)resetHighlighting {
  if (self.currentResult.firstObject.suggestions.count > 0) {
    self.highlightedIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
  } else {
    self.highlightedIndexPath = nil;
  }
}

// Adjust the inset on the table view to prevent keyboard from overlapping the
// text.
- (void)updateContentInsetForKeyboard {
  UIWindow* currentWindow = self.tableView.window;
  CGRect absoluteRect =
      [self.tableView convertRect:self.tableView.bounds
                toCoordinateSpace:currentWindow.coordinateSpace];
  CGFloat windowHeight = CGRectGetHeight(currentWindow.bounds);
  CGFloat bottomInset = windowHeight - self.tableView.contentSize.height -
                        self.keyboardHeight - absoluteRect.origin.y -
                        self.bottomPadding - self.topPadding;
  bottomInset = MAX(self.bottomPadding, -bottomInset);
  self.tableView.contentInset =
      UIEdgeInsetsMake(self.topPadding, 0, bottomInset, 0);
  self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
}

// Updates the color of the background based on the incognito-ness and the size
// class.
- (void)updateBackgroundColor {
  ToolbarConfiguration* configuration = [[ToolbarConfiguration alloc]
      initWithStyle:self.incognito ? INCOGNITO : NORMAL];

  if (IsOmniboxActionsVisualTreatment2()) {
    self.view.backgroundColor =
        [UIColor colorNamed:kGroupedPrimaryBackgroundColor];
    return;
  }

  if (IsRegularXRegularSizeClass(self)) {
    self.view.backgroundColor = configuration.backgroundColor;
  } else {
    self.view.backgroundColor = [UIColor clearColor];
  }
}

#pragma mark Action for append UIButton

- (void)setSemanticContentAttribute:
    (UISemanticContentAttribute)semanticContentAttribute {
  _semanticContentAttribute = semanticContentAttribute;
  // If there are any visible cells, update them right away.
  for (UITableViewCell* cell in self.tableView.visibleCells) {
    if ([cell isKindOfClass:[OmniboxPopupRowCell class]]) {
      OmniboxPopupRowCell* rowCell =
          base::mac::ObjCCastStrict<OmniboxPopupRowCell>(cell);
      // This has to be set here because the cell's content view has its
      // semantic content attribute reset before the cell is displayed (and
      // before this method is called).
      rowCell.omniboxSemanticContentAttribute = self.semanticContentAttribute;
    }
  }
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView*)scrollView {
  // TODO(crbug.com/733650): Default to the dragging check once it's been tested
  // on trunk.
  if (!scrollView.dragging)
    return;

  // TODO(crbug.com/911534): The following call chain ultimately just dismisses
  // the keyboard, but involves many layers of plumbing, and should be
  // refactored.
  if (self.forwardsScrollEvents)
    [self.delegate autocompleteResultConsumerDidScroll:self];

  [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow
                                animated:NO];
}

#pragma mark - Keyboard events

- (void)keyboardDidShow:(NSNotification*)notification {
  self.keyboardHeight =
      [KeyboardObserverHelper keyboardHeightInWindow:self.tableView.window];
  if (self.tableView.contentSize.height > 0)
    [self updateContentInsetForKeyboard];
}

- (void)keyboardDidChangeFrame:(NSNotification*)notification {
  CGFloat keyboardHeight =
      [KeyboardObserverHelper keyboardHeightInWindow:self.tableView.window];
  if (self.keyboardHeight != keyboardHeight) {
    self.keyboardHeight = keyboardHeight;
    self.shouldUpdateVisibleSuggestionCount = YES;
  }
}

#pragma mark - Content size events

- (void)contentSizeDidChange:(NSNotification*)notification {
  self.shouldUpdateVisibleSuggestionCount = YES;
}

#pragma mark - ContentProviding

- (BOOL)hasContent {
  return self.tableView.numberOfSections > 0 &&
         [self.tableView numberOfRowsInSection:0] > 0;
}

#pragma mark - CarouselItemConsumer

- (void)carouselItem:(CarouselItem*)carouselItem setHidden:(BOOL)hidden {
  [self.carouselCell carouselItem:carouselItem setHidden:hidden];
}

#pragma mark - Private Methods

- (id<AutocompleteSuggestion>)suggestionAtIndexPath:(NSIndexPath*)indexPath {
  if (indexPath.section < 0 || indexPath.row < 0) {
    return nil;
  }
  if (!self.currentResult || self.currentResult.count == 0 ||
      self.currentResult.count <= (NSUInteger)indexPath.section ||
      self.currentResult[indexPath.section].suggestions.count <=
          (NSUInteger)indexPath.row) {
    return nil;
  }
  return self.currentResult[indexPath.section].suggestions[indexPath.row];
}

// Returns the absolute row number for `indexPath`, counting every row in every
// section above. Used for logging.
- (NSInteger)absoluteRowIndexForIndexPath:(NSIndexPath*)indexPath {
  if (![self suggestionAtIndexPath:indexPath]) {
    return NSNotFound;
  }
  NSInteger rowCount = 0;
  // For each section above `indexPath` add the number of row used by the
  // section.
  for (NSInteger i = 0; i < indexPath.section; ++i) {
    rowCount += [self.tableView numberOfRowsInSection:i];
  }
  switch (self.currentResult[indexPath.section].displayStyle) {
    case SuggestionGroupDisplayStyleDefault:
      return rowCount + indexPath.row;
    case SuggestionGroupDisplayStyleCarousel:
      return rowCount;
  }
}

- (void)updateVisibleSuggestionCount {
  CGRect tableViewFrameInCurrentWindowCoordinateSpace =
      [self.tableView convertRect:self.tableView.bounds
                toCoordinateSpace:self.tableView.window.coordinateSpace];
  // Computes the visible area between the omnibox and the keyboard.
  CGFloat visibleTableViewHeight =
      CGRectGetHeight(self.tableView.window.bounds) -
      tableViewFrameInCurrentWindowCoordinateSpace.origin.y -
      self.keyboardHeight - self.tableView.contentInset.top;
  // Use font size to estimate the size of a omnibox search suggestion.
  CGFloat fontSizeHeight = [@"T" sizeWithAttributes:@{
                             NSFontAttributeName : [UIFont
                                 preferredFontForTextStyle:UIFontTextStyleBody]
                           }]
                               .height;
  // Add padding to the estimated row height and set its minimum to be at
  // `kOmniboxPopupCellMinimumHeight`.
  CGFloat estimatedRowHeight = MAX(fontSizeHeight + 2 * kTopAndBottomPadding,
                                   kOmniboxPopupCellMinimumHeight);
  CGFloat visibleRows = visibleTableViewHeight / estimatedRowHeight;
  // A row is considered visible if `kVisibleSuggestionTreshold` percent of its
  // height is visible.
  self.visibleSuggestionCount =
      floor(visibleRows + (1.0 - kVisibleSuggestionThreshold));
  self.shouldUpdateVisibleSuggestionCount = NO;
}

- (CGFloat)topPadding {
  CGFloat topPadding = kTopAndBottomPadding;
  if (IsOmniboxActionsVisualTreatment1()) {
    topPadding = kTopPaddingVariation1;
  }
  if (IsOmniboxActionsVisualTreatment2()) {
    // On iPad, even in compact width, the popup is displayed differently than
    // on the iPhone (it's "under" the always visible toolbar). So the check
    // here is intentionally for device type, not size class.
    BOOL isIpad = ui::GetDeviceFormFactor() == ui::DEVICE_FORM_FACTOR_TABLET;
    topPadding =
        isIpad ? kTopBottomPaddingVariation2Ipad : kTopPaddingVariation2;
  }
  return topPadding;
}

- (CGFloat)bottomPadding {
  if (IsOmniboxActionsVisualTreatment2() &&
      (ui::GetDeviceFormFactor() == ui::DEVICE_FORM_FACTOR_TABLET)) {
    return kTopBottomPaddingVariation2Ipad;
  }
  return kTopAndBottomPadding;
}

- (NSArray<CarouselItem*>*)
    carouselItemsFromSuggestionGroup:(id<AutocompleteSuggestionGroup>)group
                      groupIndexPath:(NSIndexPath*)groupIndexPath {
  NSMutableArray* carouselItems =
      [[NSMutableArray alloc] initWithCapacity:group.suggestions.count];
  for (NSUInteger i = 0; i < group.suggestions.count; ++i) {
    id<AutocompleteSuggestion> suggestion = group.suggestions[i];
    NSIndexPath* itemIndexPath =
        [NSIndexPath indexPathForRow:i inSection:groupIndexPath.section];
    CarouselItem* item = [[CarouselItem alloc] init];
    item.title = suggestion.text.string;
    item.indexPath = itemIndexPath;
    item.URL = suggestion.destinationUrl;
    [carouselItems addObject:item];
  }
  return carouselItems;
}

// TODO(crbug.com/1365374): Move to a mediator.
- (void)fetchFaviconForCarouselItem:(CarouselItem*)carouselItem {
  __weak OmniboxPopupCarouselCell* weakCell = self.carouselCell;
  __weak CarouselItem* weakItem = carouselItem;

  void (^completion)(FaviconAttributes*) = ^(FaviconAttributes* attributes) {
    OmniboxPopupCarouselCell* strongCell = weakCell;
    CarouselItem* strongItem = weakItem;
    if (!strongCell || !strongItem)
      return;

    strongItem.faviconAttributes = attributes;
    [strongCell updateCarouselItem:strongItem];
  };

  [self.carouselAttributeProvider
      fetchFaviconAttributesForURL:carouselItem.URL.gurl
                        completion:completion];
}

@end
