// Copyright 2023 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/price_notifications/price_notifications_table_view_controller.h"

#import <UIKit/UIKit.h>

#import "base/mac/foundation_util.h"
#import "ios/chrome/browser/ui/commands/command_dispatcher.h"
#import "ios/chrome/browser/ui/price_notifications/cells/price_notifications_table_view_item.h"
#import "ios/chrome/browser/ui/price_notifications/price_notifications_consumer.h"
#import "ios/chrome/browser/ui/price_notifications/test_price_notifications_mutator.h"
#import "ios/chrome/browser/ui/table_view/cells/table_view_link_header_footer_item.h"
#import "ios/chrome/browser/ui/table_view/cells/table_view_text_header_footer_item.h"
#import "ios/chrome/browser/ui/table_view/chrome_table_view_controller_test.h"
#import "ios/chrome/grit/ios_strings.h"
#import "testing/platform_test.h"
#import "ui/base/l10n/l10n_util_mac.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
// PriceNotificationsTableViewController SectionIdentifier values.
NSUInteger SectionIdentifierTrackableItemsOnCurrentSite = 10;
NSUInteger SectionIdentifierTrackedItems = 11;
NSUInteger SectionIdentifierTableViewHeader = 12;

// PriceNotificaitonsTableViewController ListItem values.
NSUInteger ItemTypeListItem = 102;

template <typename T>
// Returns the TableViewHeaderFooterItem `T` from `section_id`.
T* GetHeaderItemFromSection(ChromeTableViewController* controller,
                            NSUInteger section_id) {
  return base::mac::ObjCCastStrict<T>([controller.tableViewModel
      headerForSectionIndex:[controller.tableViewModel
                                sectionForSectionIdentifier:section_id]]);
}

// Returns an array of PriceNotificationTableViewItems contained in
// `section_id`.
NSArray<PriceNotificationsTableViewItem*>* GetItemsFromSection(
    TableViewModel* model,
    NSUInteger section_id) {
  NSArray<NSIndexPath*>* paths = [model indexPathsForItemType:ItemTypeListItem
                                            sectionIdentifier:section_id];
  NSMutableArray* items = [[NSMutableArray alloc] initWithCapacity:paths.count];
  for (NSIndexPath* path in paths) {
    [items addObject:[model itemAtIndexPath:path]];
  }

  return items;
}
}  // namespace

class PriceNotificationsTableViewControllerTest
    : public ChromeTableViewControllerTest {
 public:
  ChromeTableViewController* InstantiateController() override {
    return [[PriceNotificationsTableViewController alloc]
        initWithStyle:UITableViewStylePlain];
  }
};

// Tests the Trackable Item is in the loading state, which displays a
// placeholder view, on the creation of the TableViewController.
TEST_F(PriceNotificationsTableViewControllerTest,
       DisplayTrackableItemLoadingScreenWhenThereIsNoData) {
  TableViewModel* model = controller().tableViewModel;
  NSIndexPath* trackableItemPlaceholderIndexPath =
      [model indexPathForItemType:ItemTypeListItem
                sectionIdentifier:SectionIdentifierTrackableItemsOnCurrentSite];
  PriceNotificationsTableViewItem* trackableItemPlaceholder =
      base::mac::ObjCCast<PriceNotificationsTableViewItem>(
          [model itemAtIndexPath:trackableItemPlaceholderIndexPath]);

  EXPECT_EQ(trackableItemPlaceholder.loading, true);
}

// Tests the two tracked items are in the loading state, which displays a
// placeholder view, on the creation of the TableViewController.
TEST_F(PriceNotificationsTableViewControllerTest,
       DisplayTrackedItemsLoadingScreenWhenThereIsNoData) {
  TableViewModel* model = controller().tableViewModel;
  NSArray<NSIndexPath*>* placeholders =
      [model indexPathsForItemType:ItemTypeListItem
                 sectionIdentifier:SectionIdentifierTrackedItems];
  PriceNotificationsTableViewItem* firstTrackedItemPlacholder =
      base::mac::ObjCCast<PriceNotificationsTableViewItem>(
          [model itemAtIndexPath:placeholders[0]]);
  PriceNotificationsTableViewItem* secondTrackedItemPlaceholder =
      base::mac::ObjCCast<PriceNotificationsTableViewItem>(
          [model itemAtIndexPath:placeholders[1]]);

  EXPECT_EQ(placeholders.count, 2u);
  EXPECT_TRUE(firstTrackedItemPlacholder.loading);
  EXPECT_TRUE(secondTrackedItemPlaceholder.loading);
}

// Tests simulates receiving no data from the mediator and checks that the
// correct messages are displayed.
TEST_F(PriceNotificationsTableViewControllerTest,
       DisplayTrackableSectionEmptyStateWhenProductPageIsNotTrackable) {
  id<PriceNotificationsConsumer> consumer =
      base::mac::ObjCCast<PriceNotificationsTableViewController>(controller());

  [consumer setTrackableItem:nil currentlyTracking:NO];
  TableViewLinkHeaderFooterItem* item =
      GetHeaderItemFromSection<TableViewLinkHeaderFooterItem>(
          controller(), SectionIdentifierTableViewHeader);
  NSString* tableHeadingText = item.text;
  TableViewTextHeaderFooterItem* trackableHeaderItem =
      GetHeaderItemFromSection<TableViewTextHeaderFooterItem>(
          controller(), SectionIdentifierTrackableItemsOnCurrentSite);
  TableViewTextHeaderFooterItem* trackedHeaderItem =
      GetHeaderItemFromSection<TableViewTextHeaderFooterItem>(
          controller(), SectionIdentifierTrackedItems);

  EXPECT_TRUE([tableHeadingText
      isEqualToString:
          l10n_util::GetNSString(
              IDS_IOS_PRICE_NOTIFICATIONS_PRICE_TRACK_DESCRIPTION_EMPTY_STATE)]);
  EXPECT_FALSE([controller().tableViewModel
      hasItemForItemType:ItemTypeListItem
       sectionIdentifier:SectionIdentifierTrackableItemsOnCurrentSite]);
  EXPECT_TRUE([trackableHeaderItem.text
      isEqualToString:
          l10n_util::GetNSString(
              IDS_IOS_PRICE_NOTIFICATIONS_PRICE_TRACK_TRACKABLE_SECTION_HEADER)]);
  EXPECT_TRUE([trackableHeaderItem.subtitle
      isEqualToString:
          l10n_util::GetNSString(
              IDS_IOS_PRICE_NOTIFICATIONS_PRICE_TRACK_TRACKABLE_EMPTY_LIST)]);
  EXPECT_FALSE([controller().tableViewModel
      hasItemForItemType:ItemTypeListItem
       sectionIdentifier:SectionIdentifierTrackedItems]);
  EXPECT_TRUE([trackedHeaderItem.text
      isEqualToString:
          l10n_util::GetNSString(
              IDS_IOS_PRICE_NOTIFICATIONS_PRICE_TRACK_TRACKED_SECTION_HEADER)]);
  EXPECT_TRUE([trackedHeaderItem.subtitle
      isEqualToString:
          l10n_util::GetNSString(
              IDS_IOS_PRICE_NOTIFICATIONS_PRICE_TRACK_TRACKING_EMPTY_LIST)]);
}

// Tests simulates that a trackable item exists and is properly displayed.
TEST_F(PriceNotificationsTableViewControllerTest,
       DisplayTrackableItemWhenAvailable) {
  id<PriceNotificationsConsumer> consumer =
      base::mac::ObjCCast<PriceNotificationsTableViewController>(controller());
  PriceNotificationsTableViewItem* item =
      [[PriceNotificationsTableViewItem alloc] initWithType:ItemTypeListItem];
  item.title = @"Test Title";

  [consumer setTrackableItem:item currentlyTracking:NO];
  NSArray<PriceNotificationsTableViewItem*>* items =
      GetItemsFromSection(controller().tableViewModel,
                          SectionIdentifierTrackableItemsOnCurrentSite);

  EXPECT_TRUE([controller().tableViewModel
      hasItemForItemType:ItemTypeListItem
       sectionIdentifier:SectionIdentifierTrackableItemsOnCurrentSite]);
  EXPECT_EQ(items.count, 1u);
  EXPECT_TRUE([items[0].title isEqualToString:item.title]);
}

// tests simulates that a tracked item exists and is displayed
TEST_F(PriceNotificationsTableViewControllerTest, DisplayUsersTrackedItems) {
  id<PriceNotificationsConsumer> consumer =
      base::mac::ObjCCast<PriceNotificationsTableViewController>(controller());
  PriceNotificationsTableViewItem* item =
      [[PriceNotificationsTableViewItem alloc] initWithType:ItemTypeListItem];
  item.title = @"Test Title";

  [consumer addTrackedItem:item toBeginning:NO];
  NSArray<PriceNotificationsTableViewItem*>* items = GetItemsFromSection(
      controller().tableViewModel, SectionIdentifierTrackedItems);

  EXPECT_TRUE([controller().tableViewModel
      hasItemForItemType:ItemTypeListItem
       sectionIdentifier:SectionIdentifierTrackedItems]);
  EXPECT_EQ(items.count, 1u);
  EXPECT_TRUE([items[0].title isEqualToString:item.title]);
}

// Test simulates that a trackable item exists, has been selected to be tracked,
// and the item is moved to the tracked section
TEST_F(PriceNotificationsTableViewControllerTest,
       TrackableItemMovedToTrackedSectionOnStartTracking) {
  id<PriceNotificationsConsumer> consumer =
      base::mac::ObjCCast<PriceNotificationsTableViewController>(controller());
  PriceNotificationsTableViewItem* item =
      [[PriceNotificationsTableViewItem alloc] initWithType:ItemTypeListItem];
  TableViewModel* model = controller().tableViewModel;

  [consumer setTrackableItem:item currentlyTracking:NO];
  NSArray<PriceNotificationsTableViewItem*>* items =
      GetItemsFromSection(model, SectionIdentifierTrackableItemsOnCurrentSite);
  NSUInteger trackableItemCountBeforeStartTracking = items.count;
  items = GetItemsFromSection(model, SectionIdentifierTrackedItems);
  NSUInteger trackedItemCountBeforeStartTracking = items.count;
  [consumer didStartPriceTrackingForItem:item];
  items =
      GetItemsFromSection(model, SectionIdentifierTrackableItemsOnCurrentSite);
  NSUInteger trackableItemCountAfterStartTracking = items.count;
  items = GetItemsFromSection(model, SectionIdentifierTrackedItems);
  NSUInteger trackedItemCountAfterStartTracking = items.count;

  EXPECT_EQ(trackableItemCountBeforeStartTracking, 1u);
  EXPECT_EQ(trackedItemCountBeforeStartTracking, 0u);
  EXPECT_EQ(trackableItemCountAfterStartTracking, 0u);
  EXPECT_EQ(trackedItemCountAfterStartTracking, 1u);
}

// Test simulates the user tapping on a tracked item and being redirected to
// that page.
TEST_F(PriceNotificationsTableViewControllerTest,
       RedirectToTrackedItemsWebpageOnSelection) {
  PriceNotificationsTableViewController* tableViewController =
      base::mac::ObjCCastStrict<PriceNotificationsTableViewController>(
          controller());
  PriceNotificationsTableViewItem* item =
      [[PriceNotificationsTableViewItem alloc] initWithType:ItemTypeListItem];
  item.tracking = YES;
  TableViewModel* model = tableViewController.tableViewModel;
  TestPriceNotificationsMutator* mutator =
      [[TestPriceNotificationsMutator alloc] init];
  tableViewController.mutator = mutator;

  [tableViewController setTrackableItem:item currentlyTracking:NO];
  [tableViewController didStartPriceTrackingForItem:item];
  NSIndexPath* itemIndexPath =
      [model indexPathForItemType:ItemTypeListItem
                sectionIdentifier:SectionIdentifierTrackedItems];

  if (@available(iOS 16, *)) {
    EXPECT_EQ(itemIndexPath,
              [tableViewController tableView:controller().tableView
                    willSelectRowAtIndexPath:itemIndexPath]);
    [tableViewController tableView:tableViewController.tableView
           didSelectRowAtIndexPath:itemIndexPath];
    EXPECT_FALSE(mutator.didNavigateToItemPage);
    EXPECT_TRUE([tableViewController tableView:tableViewController.tableView
        canPerformPrimaryActionForRowAtIndexPath:itemIndexPath]);
    [tableViewController tableView:tableViewController.tableView
        performPrimaryActionForRowAtIndexPath:itemIndexPath];
    EXPECT_TRUE(mutator.didNavigateToItemPage);
    return;
  }

  EXPECT_EQ(itemIndexPath, [tableViewController tableView:controller().tableView
                                 willSelectRowAtIndexPath:itemIndexPath]);
  [tableViewController tableView:tableViewController.tableView
         didSelectRowAtIndexPath:itemIndexPath];
  EXPECT_TRUE(mutator.didNavigateToItemPage);
  return;
}
