// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_module_container.h"

#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_cells_constants.h"
#import "ios/chrome/browser/ui/content_suggestions/cells/content_suggestions_tile_layout_util.h"
#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_feature.h"
#import "ios/chrome/browser/ui/image_util/image_util.h"
#import "ios/chrome/common/ui/colors/semantic_color_names.h"
#import "ios/chrome/common/ui/util/constraints_ui_util.h"
#include "ios/chrome/grit/ios_strings.h"
#include "ui/base/l10n/l10n_util_mac.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

// The horizontal inset of the contents to this container when there is a title.
const float kContentHorizontalInset = 16.0f;

// The vertical spacing between the title and the content of the module.
const float kContentTitleVerticalSpacing = 12.0f;
const float kContentTitleShortenedVerticalSpacing = 10.0f;

// The top inset of the title label to this container.
const float kTitleTopInset = 14.0f;
const float kTitleShortenedTopInset = 11.0f;

// The minimum width of the title label.
const float kTitleMinimumWidth = 99.0f;

// The minimum height of the title label.
const float kTitleMinimumHeight = 11.0f;

// The corner radius of the title placeholder view.
const float kPlaceholderTitleCornerRadius = 2.0f;

// The corner radius of this container.
const float kCornerRadius = 16;

// The shadow offsets of this container.
const CGFloat kHorizontalShadowOffset = 40;
const CGFloat kVerticalShadowOffset = 50;

// Vertical space allocated to the Trending Queries module content.
const float kTrendingQueriesContentHeight = 103;

}  // namespace

@interface ContentSuggestionsModuleContainer ()

@property(nonatomic, assign) ContentSuggestionsModuleType type;

// Title of the Module.
@property(nonatomic, strong) UILabel* title;

// The height constraint of this container view.
@property(nonatomic, strong) NSLayoutConstraint* heightConstraint;

@end

@implementation ContentSuggestionsModuleContainer

- (instancetype)initWithContentView:(UIView*)contentView
                         moduleType:(ContentSuggestionsModuleType)type {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    _type = type;

    self.layer.cornerRadius = kCornerRadius;
    self.backgroundColor =
        [UIColor colorNamed:kGroupedSecondaryBackgroundColor];

    // Create content container with same background as this view so that a
    // shadow view can be placed under it to create a shadow effect.
    UIImageView* shadow = [[UIImageView alloc]
        initWithImage:StretchableImageNamed(@"module_shadow")];
    shadow.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:shadow];
    AddSameConstraintsToSidesWithInsets(
        shadow, self,
        LayoutSides::kTop | LayoutSides::kLeading | LayoutSides::kBottom |
            LayoutSides::kTrailing,
        {-kHorizontalShadowOffset, -kVerticalShadowOffset,
         -kVerticalShadowOffset, -kHorizontalShadowOffset});

    UIView* contentContainer = [[UIView alloc] init];
    contentContainer.backgroundColor =
        [UIColor colorNamed:kGroupedSecondaryBackgroundColor];
    contentContainer.layer.cornerRadius = kCornerRadius;
    contentContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:contentContainer];
    AddSameConstraints(self, contentContainer);

    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [contentContainer addSubview:contentView];

    NSString* titleString = [self titleString];
    if ([titleString length] > 0) {
      self.title = [[UILabel alloc] init];
      self.title.text = [self titleString];
      self.title.font =
          [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
      self.title.textColor = [UIColor colorNamed:kTextSecondaryColor];
      self.title.accessibilityTraits |= UIAccessibilityTraitHeader;
      self.title.accessibilityIdentifier = [self titleString];
      self.title.translatesAutoresizingMaskIntoConstraints = NO;
      [contentContainer addSubview:self.title];
      [NSLayoutConstraint activateConstraints:@[
        // Title constraints.
        [self.title.leadingAnchor
            constraintEqualToAnchor:contentContainer.leadingAnchor
                           constant:kContentHorizontalInset],
        [contentContainer.topAnchor
            constraintEqualToAnchor:self.title.topAnchor
                           constant:-[self titleTopInset]],
        // Ensures placeholder for title is visible.
        [self.title.widthAnchor
            constraintGreaterThanOrEqualToConstant:kTitleMinimumWidth],
        [self.title.heightAnchor
            constraintGreaterThanOrEqualToConstant:kTitleMinimumHeight],
        // contentView constraints.
        [contentView.leadingAnchor
            constraintEqualToAnchor:contentContainer.leadingAnchor
                           constant:kContentHorizontalInset],
        [contentView.trailingAnchor
            constraintEqualToAnchor:contentContainer.trailingAnchor
                           constant:-kContentHorizontalInset],
        [contentView.bottomAnchor
            constraintEqualToAnchor:contentContainer.bottomAnchor],
        [contentView.topAnchor constraintEqualToAnchor:self.title.bottomAnchor
                                              constant:[self titleSpacing]],
      ]];
    } else {
      CGFloat horizontalInsets =
          ShouldRemoveHeadersForModuleRefresh() ? kContentHorizontalInset : 0;
      [NSLayoutConstraint activateConstraints:@[
        [contentView.leadingAnchor
            constraintEqualToAnchor:contentContainer.leadingAnchor
                           constant:horizontalInsets],
        [contentView.trailingAnchor
            constraintEqualToAnchor:contentContainer.trailingAnchor
                           constant:-horizontalInsets],
        [contentView.bottomAnchor
            constraintEqualToAnchor:contentContainer.bottomAnchor],
        [contentView.topAnchor
            constraintEqualToAnchor:contentContainer.topAnchor
                           constant:[self titleTopInset]],
      ]];
    }
    // Height constraint must be flexible since on launch before the Feed
    // CollectionView is used a native UICollectionView is the parent, and it
    // can attempt to apply a large height constraint to the
    // ContentSuggestionsViewController.
    self.heightConstraint = [self.heightAnchor
        constraintGreaterThanOrEqualToConstant:[self calculateIntrinsicHeight]];
    self.heightConstraint.active = YES;
  }
  return self;
}

// Returns the title string for the module, empty string if there should be no
// title.
- (NSString*)titleString {
  switch (self.type) {
    case ContentSuggestionsModuleTypeShortcuts:
      return ShouldRemoveHeadersForModuleRefresh()
                 ? @""
                 : l10n_util::GetNSString(
                       IDS_IOS_CONTENT_SUGGESTIONS_SHORTCUTS_MODULE_TITLE);
    case ContentSuggestionsModuleTypeMostVisited:
      return ShouldRemoveHeadersForModuleRefresh()
                 ? @""
                 : l10n_util::GetNSString(
                       IDS_IOS_CONTENT_SUGGESTIONS_MOST_VISITED_MODULE_TITLE);
    case ContentSuggestionsModuleTypeReturnToRecentTab:
      return @"";
    case ContentSuggestionsModuleTypeTrendingQueries:
      return l10n_util::GetNSString(
          IDS_IOS_CONTENT_SUGGESTIONS_TRENDING_QUERIES_MODULE_TITLE);
  }
}

- (void)setIsPlaceholder:(BOOL)isPlaceholder {
  if (_isPlaceholder == isPlaceholder) {
    return;
  }
  if (isPlaceholder) {
    self.title.text = @"";
    self.title.backgroundColor = [UIColor colorNamed:kGrey100Color];
    self.title.layer.cornerRadius = kPlaceholderTitleCornerRadius;
    self.title.layer.masksToBounds = YES;
  } else {
    self.title.backgroundColor = [UIColor colorNamed:kBackgroundColor];
    self.title.layer.masksToBounds = NO;
    self.title.text = [self titleString];
  }
  _isPlaceholder = isPlaceholder;
}

- (void)traitCollectionDidChange:(UITraitCollection*)previousTraitCollection {
  [super traitCollectionDidChange:previousTraitCollection];
  if (previousTraitCollection.preferredContentSizeCategory !=
      self.traitCollection.preferredContentSizeCategory) {
    self.title.font =
        [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    self.heightConstraint.constant = [self calculateIntrinsicHeight];
  }
}

- (CGFloat)calculateIntrinsicHeight {
  CGFloat contentHeight = 0;
  switch (self.type) {
    case ContentSuggestionsModuleTypeShortcuts:
    case ContentSuggestionsModuleTypeMostVisited:
      contentHeight +=
          MostVisitedCellSize(self.traitCollection.preferredContentSizeCategory)
              .height;
      break;
    case ContentSuggestionsModuleTypeReturnToRecentTab:
      return ReturnToRecentTabHeight();
    case ContentSuggestionsModuleTypeTrendingQueries:
      contentHeight += kTrendingQueriesContentHeight;
  }
  if (!ShouldRemoveHeadersForModuleRefresh()) {
    contentHeight += ceilf(self.title.font.lineHeight);
  }
  return [self titleSpacing] + [self titleTopInset] + contentHeight;
}

// Returns the spacing between the module edge and title. Also used to return
// the spacing between the contents and the module edge if
// ShouldRemoveHeadersForModuleRefresh() is YES where there are no headers for
// modules.
- (CGFloat)titleTopInset {
  if (ShouldMinimizeSpacingForModuleRefresh()) {
    return self.type == ContentSuggestionsModuleTypeReturnToRecentTab
               ? 0
               : kTitleShortenedTopInset;
  } else if (ShouldRemoveHeadersForModuleRefresh() &&
             self.type != ContentSuggestionsModuleTypeTrendingQueries) {
    return self.type == ContentSuggestionsModuleTypeReturnToRecentTab
               ? 0
               : kTitleTopInset;
  } else {
    return kTitleTopInset;
  }
}

// Returns the spacing between the module and title and the content.
- (CGFloat)titleSpacing {
  if (ShouldMinimizeSpacingForModuleRefresh()) {
    return kContentTitleShortenedVerticalSpacing;
  } else if (ShouldRemoveHeadersForModuleRefresh() &&
             self.type != ContentSuggestionsModuleTypeTrendingQueries) {
    return 0;
  } else {
    return kContentTitleVerticalSpacing;
  }
}

@end
