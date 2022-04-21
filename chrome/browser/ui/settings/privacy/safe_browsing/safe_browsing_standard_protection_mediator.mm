// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/settings/privacy/safe_browsing/safe_browsing_standard_protection_mediator.h"

#include "base/notreached.h"
#include "components/password_manager/core/common/password_manager_features.h"
#include "components/password_manager/core/common/password_manager_pref_names.h"
#include "components/prefs/pref_service.h"
#include "components/safe_browsing/core/common/safe_browsing_prefs.h"
#import "ios/chrome/browser/signin/authentication_service.h"
#import "ios/chrome/browser/signin/authentication_service_factory.h"
#import "ios/chrome/browser/ui/list_model/list_model.h"
#import "ios/chrome/browser/ui/settings/cells/safe_browsing_header_item.h"
#import "ios/chrome/browser/ui/settings/cells/sync_switch_item.h"
#import "ios/chrome/browser/ui/settings/privacy/safe_browsing/safe_browsing_constants.h"
#import "ios/chrome/browser/ui/settings/privacy/safe_browsing/safe_browsing_standard_protection_consumer.h"
#import "ios/chrome/browser/ui/settings/utils/pref_backed_boolean.h"
#import "ios/chrome/browser/ui/table_view/cells/table_view_info_button_item.h"
#import "ios/chrome/browser/ui/table_view/cells/table_view_switch_item.h"
#import "ios/chrome/common/ui/colors/semantic_color_names.h"
#include "ios/chrome/grit/ios_google_chrome_strings.h"
#include "ios/chrome/grit/ios_strings.h"
#include "ui/base/l10n/l10n_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using ItemArray = NSArray<TableViewItem*>*;

namespace {
// List of item types.
typedef NS_ENUM(NSInteger, ItemType) {
  ItemTypeShieldIcon = kItemTypeEnumZero,
  ItemTypeMetricIcon,
  ItemTypePasswordLeakCheckSwitch,
  ItemTypeSafeBrowsingExtendedReporting,
};
}  // namespace

@interface SafeBrowsingStandardProtectionMediator ()

// User pref service used to check if a specific pref is managed by enterprise
// policies.
@property(nonatomic, assign, readonly) PrefService* userPrefService;

// Local pref service used to check if a specific pref is managed by enterprise
// policies.
@property(nonatomic, assign, readonly) PrefService* localPrefService;

// Authentication service.
@property(nonatomic, assign, readonly) AuthenticationService* authService;

// Preference value for the "Safe Browsing" feature.
@property(nonatomic, strong, readonly)
    PrefBackedBoolean* safeBrowsingStandardProtectionPreference;

// The observable boolean that binds to the password leak check settings
// state.
@property(nonatomic, strong, readonly)
    PrefBackedBoolean* passwordLeakCheckPreference;

// The item related to the switch for the automatic password leak detection
// setting.
@property(nonatomic, strong, null_resettable)
    TableViewSwitchItem* passwordLeakCheckItem;

// Header that has shield icon.
@property(nonatomic, strong) SafeBrowsingHeaderItem* shieldIconHeader;

// Second header which has a metric icon.
@property(nonatomic, strong) SafeBrowsingHeaderItem* metricIconHeader;

// All the items for the standard safe browsing section.
@property(nonatomic, strong, readonly)
    ItemArray safeBrowsingStandardProtectionItems;

@end

@implementation SafeBrowsingStandardProtectionMediator

@synthesize safeBrowsingStandardProtectionItems =
    _safeBrowsingStandardProtectionItems;

- (instancetype)initWithUserPrefService:(PrefService*)userPrefService
                       localPrefService:(PrefService*)localPrefService
                            authService:(AuthenticationService*)authService {
  self = [super init];
  if (self) {
    DCHECK(userPrefService);
    DCHECK(localPrefService);
    _userPrefService = userPrefService;
    _localPrefService = localPrefService;
    _authService = authService;
    _safeBrowsingStandardProtectionPreference = [[PrefBackedBoolean alloc]
        initWithPrefService:userPrefService
                   prefName:prefs::kSafeBrowsingEnabled];
    _passwordLeakCheckPreference = [[PrefBackedBoolean alloc]
        initWithPrefService:userPrefService
                   prefName:password_manager::prefs::
                                kPasswordLeakDetectionEnabled];
  }
  return self;
}

#pragma mark - Properties

- (ItemArray)safeBrowsingStandardProtectionItems {
  if (!_safeBrowsingStandardProtectionItems) {
    NSMutableArray* items = [NSMutableArray array];
    if (self.userPrefService->IsManagedPreference(
            prefs::kSafeBrowsingEnabled)) {
      TableViewInfoButtonItem* safeBrowsingStandardProtectionManagedItem = [self
          tableViewInfoButtonItemType:ItemTypeSafeBrowsingExtendedReporting
                         textStringID:
                             IDS_IOS_SAFE_BROWSING_STANDARD_PROTECTION_EXTENDED_REPORTING_TITLE
                       detailStringID:
                           IDS_IOS_SAFE_BROWSING_STANDARD_PROTECTION_EXTENDED_REPORTING_SUMMARY
                               status:
                                   self.safeBrowsingStandardProtectionPreference
                                       .value];
      [items addObject:safeBrowsingStandardProtectionManagedItem];
    } else {
      SyncSwitchItem* safeBrowsingStandardProtectionItem = [self
          switchItemWithItemType:ItemTypeSafeBrowsingExtendedReporting
                    textStringID:
                        IDS_IOS_SAFE_BROWSING_STANDARD_PROTECTION_EXTENDED_REPORTING_TITLE
                  detailStringID:
                      IDS_IOS_SAFE_BROWSING_STANDARD_PROTECTION_EXTENDED_REPORTING_SUMMARY];
      safeBrowsingStandardProtectionItem.accessibilityIdentifier =
          kSafeBrowsingExtendedReportingCellId;
      [items addObject:safeBrowsingStandardProtectionItem];
    }
    [items addObject:self.passwordLeakCheckItem];

    _safeBrowsingStandardProtectionItems = items;
  }
  return _safeBrowsingStandardProtectionItems;
}

- (SafeBrowsingHeaderItem*)shieldIconHeader {
  if (!_shieldIconHeader) {
    SafeBrowsingHeaderItem* shieldIconItem = [self
             detailItemWithType:ItemTypeShieldIcon
                     detailText:
                         IDS_IOS_SAFE_BROWSING_STANDARD_PROTECTION_BULLET_ONE
                          image:[[UIImage imageNamed:@"shield"]
                                    imageWithRenderingMode:
                                        UIImageRenderingModeAlwaysTemplate]
        accessibilityIdentifier:kSafeBrowsingStandardProtectionShieldCellId];
    _shieldIconHeader = shieldIconItem;
  }
  return _shieldIconHeader;
}

- (SafeBrowsingHeaderItem*)metricIconHeader {
  if (!_metricIconHeader) {
    SafeBrowsingHeaderItem* metricIconItem = [self
             detailItemWithType:ItemTypeMetricIcon
                     detailText:
                         IDS_IOS_SAFE_BROWSING_STANDARD_PROTECTION_BULLET_TWO
                          image:[[UIImage imageNamed:@"bar_chart"]
                                    imageWithRenderingMode:
                                        UIImageRenderingModeAlwaysTemplate]
        accessibilityIdentifier:kSafeBrowsingStandardProtectionMetricCellId];
    _metricIconHeader = metricIconItem;
  }
  return _metricIconHeader;
}

- (TableViewSwitchItem*)passwordLeakCheckItem {
  if (!_passwordLeakCheckItem) {
    TableViewSwitchItem* passwordLeakCheckItem = [[TableViewSwitchItem alloc]
        initWithType:ItemTypePasswordLeakCheckSwitch];
    passwordLeakCheckItem.text = l10n_util::GetNSString(
        IDS_IOS_SAFE_BROWSING_STANDARD_PROTECTION_LEAK_CHECK_TITLE);
    passwordLeakCheckItem.detailText = l10n_util::GetNSString(
        IDS_IOS_SAFE_BROWSING_STANDARD_PROTECTION_LEAK_CHECK_SUMMARY);
    passwordLeakCheckItem.on = [self passwordLeakCheckItemOnState];
    passwordLeakCheckItem.accessibilityIdentifier =
        kSafeBrowsingStandardProtectionPasswordLeakCellId;
    passwordLeakCheckItem.enabled = [self isPasswordLeakCheckEnabled];
    _passwordLeakCheckItem = passwordLeakCheckItem;
  }
  return _passwordLeakCheckItem;
}

- (void)setConsumer:(id<SafeBrowsingStandardProtectionConsumer>)consumer {
  if (_consumer == consumer)
    return;
  _consumer = consumer;
  [_consumer setSafeBrowsingStandardProtectionItems:
                 self.safeBrowsingStandardProtectionItems];
  [_consumer setShieldIconHeader:self.shieldIconHeader];
  [_consumer setMetricIconHeader:self.metricIconHeader];
}

#pragma mark - Private

// Creates header in Standard Protection view.
- (SafeBrowsingHeaderItem*)detailItemWithType:(NSInteger)type
                                   detailText:(NSInteger)detailText
                                        image:(UIImage*)image
                      accessibilityIdentifier:
                          (NSString*)accessibilityIdentifier {
  SafeBrowsingHeaderItem* detailItem =
      [[SafeBrowsingHeaderItem alloc] initWithType:type];
  detailItem.text = l10n_util::GetNSString(detailText);
  detailItem.image = image;
  detailItem.imageViewTintColor = [UIColor colorNamed:kGrey600Color];
  detailItem.accessibilityIdentifier = accessibilityIdentifier;

  return detailItem;
}

// Creates a TableViewInfoButtonItem instance used for items that the user is
// not allowed to switch on or off (enterprise reason for example).
- (TableViewInfoButtonItem*)tableViewInfoButtonItemType:(NSInteger)itemType
                                           textStringID:(int)textStringID
                                         detailStringID:(int)detailStringID
                                                 status:(BOOL)status {
  TableViewInfoButtonItem* managedItem =
      [[TableViewInfoButtonItem alloc] initWithType:itemType];
  managedItem.text = l10n_util::GetNSString(textStringID);
  managedItem.detailText = l10n_util::GetNSString(detailStringID);
  managedItem.statusText = status ? l10n_util::GetNSString(IDS_IOS_SETTING_ON)
                                  : l10n_util::GetNSString(IDS_IOS_SETTING_OFF);
  if (!status) {
    managedItem.tintColor = [UIColor colorNamed:kGrey300Color];

    // This item is not controllable, then set the color opacity to 40%.
    managedItem.textColor =
        [[UIColor colorNamed:kTextPrimaryColor] colorWithAlphaComponent:0.4f];
    managedItem.detailTextColor =
        [[UIColor colorNamed:kTextSecondaryColor] colorWithAlphaComponent:0.4f];

    managedItem.accessibilityHint = l10n_util::GetNSString(
        IDS_IOS_TOGGLE_SETTING_MANAGED_ACCESSIBILITY_HINT);
  }
  return managedItem;
}

// Creates an item with a switch toggle.
- (SyncSwitchItem*)switchItemWithItemType:(NSInteger)itemType
                             textStringID:(int)textStringID
                           detailStringID:(int)detailStringID {
  SyncSwitchItem* switchItem = [[SyncSwitchItem alloc] initWithType:itemType];
  switchItem.text = l10n_util::GetNSString(textStringID);
  if (detailStringID)
    switchItem.detailText = l10n_util::GetNSString(detailStringID);
  return switchItem;
}

// Returns a boolean indicating whether leak detection feature is enabled.
- (BOOL)isPasswordLeakCheckEnabled {
  return self.authService->HasPrimaryIdentity(signin::ConsentLevel::kSignin) ||
         base::FeatureList::IsEnabled(
             password_manager::features::kLeakDetectionUnauthenticated);
}

// Returns a boolean indicating if the switch should appear as "On" or "Off"
// based on the sync preference and the sign in status.
- (BOOL)passwordLeakCheckItemOnState {
  return self.safeBrowsingStandardProtectionPreference.value &&
         self.passwordLeakCheckPreference.value &&
         [self isPasswordLeakCheckEnabled];
}

// Updates the detail text and on state of the leak check item based on the
// state.
- (void)updateLeakCheckItem {
  self.passwordLeakCheckItem.enabled =
      self.safeBrowsingStandardProtectionPreference.value &&
      [self isPasswordLeakCheckEnabled];
  self.passwordLeakCheckItem.on = [self passwordLeakCheckItemOnState];

  if (self.passwordLeakCheckPreference.value &&
      ![self isPasswordLeakCheckEnabled]) {
    // If the user is signed out and the sync preference is enabled, this
    // informs that it will be turned on on sign in.
    self.passwordLeakCheckItem.detailText =
        l10n_util::GetNSString(IDS_IOS_LEAK_CHECK_SIGNED_OUT_ENABLED_DESC);
    return;
  }
  self.passwordLeakCheckItem.detailText = nil;
}

@end
