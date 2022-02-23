// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/tab_switcher/tab_grid/suggested_actions/suggested_actions_grid_cell.h"

#import "ios/chrome/browser/ui/tab_switcher/tab_grid/grid/grid_constants.h"
#import "ios/chrome/common/ui/util/constraints_ui_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@implementation SuggestedActionsGridCell

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.layer.cornerRadius = kGridCellCornerRadius;
    self.layer.masksToBounds = YES;
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.backgroundView = [[UIView alloc] init];
    self.backgroundView.backgroundColor =
        [UIColor colorNamed:kGridBackgroundColor];
  }
  return self;
}

#pragma mark UICollectionViewCell Overrides

- (void)prepareForReuse {
  [super prepareForReuse];
  _suggestedActionsView = nil;
}

#pragma mark - Public

- (void)setSuggestedActionsView:(UIView*)view {
  if (view == _suggestedActionsView)
    return;
  if (_suggestedActionsView)
    [_suggestedActionsView removeFromSuperview];
  _suggestedActionsView = view;
  _suggestedActionsView.translatesAutoresizingMaskIntoConstraints = NO;
  [self.contentView addSubview:_suggestedActionsView];
  NSArray* constraints = @[
    [_suggestedActionsView.centerYAnchor
        constraintEqualToAnchor:self.contentView.centerYAnchor],
    [_suggestedActionsView.topAnchor
        constraintEqualToAnchor:self.contentView.topAnchor],
    [_suggestedActionsView.bottomAnchor
        constraintEqualToAnchor:self.contentView.bottomAnchor],
    [_suggestedActionsView.leadingAnchor
        constraintEqualToAnchor:self.contentView.leadingAnchor],
    [_suggestedActionsView.widthAnchor
        constraintEqualToAnchor:self.contentView.widthAnchor]
  ];
  [NSLayoutConstraint activateConstraints:constraints];
}

@end
