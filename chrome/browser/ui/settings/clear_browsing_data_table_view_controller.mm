// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/settings/clear_browsing_data_table_view_controller.h"

#include "base/mac/foundation_util.h"
#import "ios/chrome/browser/ui/settings/cells/table_view_clear_browsing_data_item.h"
#import "ios/chrome/browser/ui/settings/clear_browsing_data_manager.h"
#import "ios/chrome/browser/ui/table_view/cells/table_view_cells_constants.h"
#import "ios/chrome/browser/ui/table_view/chrome_table_view_styler.h"
#include "ios/chrome/grit/ios_strings.h"
#include "ui/base/l10n/l10n_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace ios {
class ChromeBrowserState;
}

@interface ClearBrowsingDataTableViewController ()

// TODO(crbug.com/850699): remove direct dependency and replace with
// delegate.
@property(nonatomic, readonly, strong) ClearBrowsingDataManager* dataManager;

// Browser state.
@property(nonatomic, assign) ios::ChromeBrowserState* browserState;

@end

@implementation ClearBrowsingDataTableViewController
@synthesize browserState = _browserState;
@synthesize dataManager = _dataManager;

#pragma mark - ViewController Lifecycle.

- (instancetype)initWithBrowserState:(ios::ChromeBrowserState*)browserState {
  self = [super initWithTableViewStyle:UITableViewStylePlain
                           appBarStyle:ChromeTableViewControllerStyleNoAppBar];
  if (self) {
    _browserState = browserState;
    _dataManager = [[ClearBrowsingDataManager alloc]
        initWithBrowserState:browserState
                    listType:ClearBrowsingDataListType::kListTypeTableView];
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  // TableView configuration
  self.tableView.estimatedRowHeight = 56;
  self.tableView.rowHeight = UITableViewAutomaticDimension;
  self.tableView.estimatedSectionHeaderHeight = 0;
  self.styler.tableViewBackgroundColor = [UIColor clearColor];
  // Align cell separators with text label leading margin.
  [self.tableView
      setSeparatorInset:UIEdgeInsetsMake(0, kTableViewHorizontalSpacing, 0, 0)];

  // Navigation controller configuration.
  self.title = l10n_util::GetNSString(IDS_IOS_CLEAR_BROWSING_DATA_TITLE);

  [self loadModel];
}

- (void)loadModel {
  [super loadModel];
  [self.dataManager loadModel:self.tableViewModel];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView*)tableView
    didSelectRowAtIndexPath:(NSIndexPath*)indexPath {
  [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
  TableViewItem* item = [self.tableViewModel itemAtIndexPath:indexPath];
  DCHECK(item);
  switch (item.type) {
    case ItemTypeDataTypeBrowsingHistory:
    case ItemTypeDataTypeCookiesSiteData:
    case ItemTypeDataTypeCache:
    case ItemTypeDataTypeSavedPasswords:
    case ItemTypeDataTypeAutofill: {
      TableViewClearBrowsingDataItem* clearBrowsingDataItem =
          base::mac::ObjCCastStrict<TableViewClearBrowsingDataItem>(item);
      clearBrowsingDataItem.checked = !clearBrowsingDataItem.checked;
      [self reconfigureCellsForItems:@[ clearBrowsingDataItem ]];
      break;
    }
    case ItemTypeClearBrowsingDataButton:
    case ItemTypeFooterGoogleAccount:
    case ItemTypeFooterGoogleAccountAndMyActivity:
    case ItemTypeFooterSavedSiteData:
    case ItemTypeFooterClearSyncAndSavedSiteData:
    case ItemTypeTimeRange:
    default:
      break;
  }
}

@end
