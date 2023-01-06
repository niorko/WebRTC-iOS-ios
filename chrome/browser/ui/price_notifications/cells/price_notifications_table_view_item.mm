// Copyright 2022 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/price_notifications/cells/price_notifications_table_view_item.h"

#import "base/strings/sys_string_conversions.h"
#import "components/url_formatter/elide_url.h"
#import "ios/chrome/browser/ui/icons/symbols.h"
#import "ios/chrome/browser/ui/price_notifications/cells/price_notifications_image_container_view.h"
#import "ios/chrome/browser/ui/price_notifications/cells/price_notifications_menu_button.h"
#import "ios/chrome/browser/ui/price_notifications/cells/price_notifications_price_chip_view.h"
#import "ios/chrome/browser/ui/price_notifications/cells/price_notifications_table_view_cell_delegate.h"
#import "ios/chrome/browser/ui/price_notifications/cells/price_notifications_track_button.h"
#import "ios/chrome/browser/ui/price_notifications/price_notifications_constants.h"
#import "ios/chrome/browser/ui/table_view/chrome_table_view_styler.h"
#import "ios/chrome/browser/ui/util/uikit_ui_util.h"
#import "ios/chrome/common/ui/colors/semantic_color_names.h"
#import "ios/chrome/common/ui/table_view/table_view_cells_constants.h"
#import "ios/chrome/common/ui/util/constraints_ui_util.h"
#import "ios/chrome/grit/ios_strings.h"
#import "ui/base/l10n/l10n_util_mac.h"
#import "url/gurl.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

const CGFloat kCellContentHeight = 64.0;
const CGFloat kCellContentSpacing = 14;
// Notification icon's point size.
const CGFloat kNotificationIconPointSize = 20;
// Identifier for the stop price tracking action item.
NSString* kActionMenuIdentifier = @"priceTrackingActionMenu";

// Creates an action menu for stopping a product's subscription to price
// tracking events.
UIMenu* CreateOptionMenu(void (^completion_handler)(UIAction* action)) {
  UIImageConfiguration* configuration = [UIImageSymbolConfiguration
      configurationWithPointSize:kNotificationIconPointSize
                          weight:UIImageSymbolWeightSemibold
                           scale:UIImageSymbolScaleMedium];

  UIImage* icon = DefaultSymbolWithConfiguration(kBellSymbol, configuration);

  UIAction* stop_tracking = [UIAction
      actionWithTitle:
          l10n_util::GetNSString(
              IDS_IOS_PRICE_NOTIFICATIONS_PRICE_TRACK_MENU_ITEM_STOP_TRACKING)
                image:icon
           identifier:kActionMenuIdentifier
              handler:completion_handler];

  // Create Action Menu
  NSArray<UIMenuElement*>* menu_elements = @[ stop_tracking ];

  return [UIMenu menuWithChildren:menu_elements];
}

}  // namespace

@implementation PriceNotificationsTableViewItem

- (instancetype)initWithType:(NSInteger)type {
  self = [super initWithType:type];
  if (self) {
    self.cellClass = [PriceNotificationsTableViewCell class];
  }
  return self;
}

- (void)configureCell:(PriceNotificationsTableViewCell*)tableCell
           withStyler:(ChromeTableViewStyler*)styler {
  [super configureCell:tableCell withStyler:styler];

  tableCell.titleLabel.text = self.title;
  tableCell.entryURL = self.entryURL;
  [tableCell setImage:self.productImage];
  [tableCell.priceNotificationsChip setPriceDrop:self.currentPrice
                                   previousPrice:self.previousPrice];
  tableCell.tracking = self.tracking;
  tableCell.accessibilityTraits |= UIAccessibilityTraitButton;
  tableCell.delegate = self.delegate;
}

@end

#pragma mark - PriceNotificationsTableViewCell

@interface PriceNotificationsTableViewCell ()

// The imageview that is displayed on the leading edge of the cell.
@property(nonatomic, strong)
    PriceNotificationsImageContainerView* priceNotificationsImageContainerView;
// The button that starts the price tracking process.
@property(nonatomic, strong) UIButton* trackButton;

@end

@implementation PriceNotificationsTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString*)reuseIdentifier {
  self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];

  if (self) {
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.font =
        CreateDynamicFont(UIFontTextStyleSubheadline, UIFontWeightSemibold);
    _titleLabel.adjustsFontForContentSizeCategory = YES;
    _URLLabel = [[UILabel alloc] init];
    _URLLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    _URLLabel.adjustsFontForContentSizeCategory = YES;
    _URLLabel.textColor = [UIColor colorNamed:kTextSecondaryColor];
    _trackButton = [[PriceNotificationsTrackButton alloc] init];
    _menuButton = [[PriceNotificationsMenuButton alloc] init];
    __weak PriceNotificationsTableViewCell* weakSelf = self;
    _menuButton.menu = CreateOptionMenu(^(UIAction* action) {
      [weakSelf willStopTrackingItem];
    });
    _menuButton.showsMenuAsPrimaryAction = YES;
    _priceNotificationsChip = [[PriceNotificationsPriceChipView alloc] init];
    _priceNotificationsChip.translatesAutoresizingMaskIntoConstraints = NO;
    _priceNotificationsImageContainerView =
        [[PriceNotificationsImageContainerView alloc] init];
    _priceNotificationsImageContainerView
        .translatesAutoresizingMaskIntoConstraints = NO;

    [_trackButton addTarget:self
                     action:@selector(trackItem)
           forControlEvents:UIControlEventTouchUpInside];

    // Use stack views to layout the subviews except for the Price Notification
    // Image.
    UIStackView* verticalStack =
        [[UIStackView alloc] initWithArrangedSubviews:@[
          _titleLabel, _URLLabel, _priceNotificationsChip
        ]];
    verticalStack.axis = UILayoutConstraintAxisVertical;
    verticalStack.distribution = UIStackViewDistributionEqualSpacing;
    verticalStack.alignment = UIStackViewAlignmentLeading;

    UIStackView* horizontalStack = [[UIStackView alloc]
        initWithArrangedSubviews:@[ verticalStack, _trackButton, _menuButton ]];
    horizontalStack.axis = UILayoutConstraintAxisHorizontal;
    horizontalStack.spacing = kTableViewHorizontalSpacing;
    horizontalStack.distribution = UIStackViewDistributionEqualSpacing;
    horizontalStack.alignment = UIStackViewAlignmentCenter;
    horizontalStack.translatesAutoresizingMaskIntoConstraints = NO;

    [self.contentView addSubview:_priceNotificationsImageContainerView];
    [self.contentView addSubview:horizontalStack];

    NSLayoutConstraint* heightConstraint = [self.contentView.heightAnchor
        constraintGreaterThanOrEqualToConstant:kCellContentHeight];
    // Don't set the priority to required to avoid clashing with the estimated
    // height.
    heightConstraint.priority = UILayoutPriorityRequired - 1;

    [NSLayoutConstraint activateConstraints:@[
      [self.priceNotificationsImageContainerView.leadingAnchor
          constraintEqualToAnchor:self.contentView.leadingAnchor
                         constant:kTableViewHorizontalSpacing],
      [self.priceNotificationsImageContainerView.centerYAnchor
          constraintEqualToAnchor:self.contentView.centerYAnchor],

      // The stack view fills the remaining space, has an intrinsic height, and
      // is centered vertically.
      [horizontalStack.leadingAnchor
          constraintEqualToAnchor:self.priceNotificationsImageContainerView
                                      .trailingAnchor
                         constant:kTableViewHorizontalSpacing],
      [horizontalStack.trailingAnchor
          constraintEqualToAnchor:self.contentView.trailingAnchor
                         constant:-kTableViewHorizontalSpacing],
      [horizontalStack.topAnchor
          constraintGreaterThanOrEqualToAnchor:self.contentView.topAnchor
                                      constant:kCellContentSpacing],
      [horizontalStack.centerYAnchor
          constraintEqualToAnchor:self.contentView.centerYAnchor],
      [horizontalStack.bottomAnchor
          constraintGreaterThanOrEqualToAnchor:self.contentView.bottomAnchor
                                      constant:-kCellContentSpacing],
      heightConstraint
    ]];
  }
  return self;
}

- (void)setImage:(UIImage*)productImage {
  [self.priceNotificationsImageContainerView setImage:productImage];
}

- (void)setTracking:(BOOL)tracking {
  if (tracking) {
    self.trackButton.hidden = YES;
    self.menuButton.hidden = NO;
    return;
  }

  self.trackButton.hidden = NO;
  self.menuButton.hidden = YES;
  _tracking = tracking;
}

- (void)setEntryURL:(GURL)URL {
  if (URL != _entryURL) {
    _entryURL = URL;
    _URLLabel.text = base::SysUTF16ToNSString(
        url_formatter::
            FormatUrlForDisplayOmitSchemePathTrivialSubdomainsAndMobilePrefix(
                _entryURL));
  }
}

#pragma mark - UITableViewCell

- (void)prepareForReuse {
  [super prepareForReuse];
  self.delegate = nil;
}

#pragma mark - Private

// Initiates the user's subscription to the product's price tracking events.
- (void)trackItem {
  [self.delegate trackItemForCell:self];
}

// Stops the user's subscription to the product's price tracking events.
- (void)willStopTrackingItem {
  [self.delegate stopTrackingItemForCell:self];
}

@end
