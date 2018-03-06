// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/table_view/cells/table_view_header_footer_item.h"

#include "testing/gtest/include/gtest/gtest.h"
#include "testing/gtest_mac.h"
#include "testing/platform_test.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

using TableViewHeaderFooterItemTest = PlatformTest;

TEST_F(TableViewHeaderFooterItemTest,
       ConfigureHeaderFooterPortsAccessibilityProperties) {
  TableViewHeaderFooterItem* item =
      [[TableViewHeaderFooterItem alloc] initWithType:0];
  item.accessibilityIdentifier = @"test_identifier";
  item.accessibilityTraits = UIAccessibilityTraitButton;
  UITableViewHeaderFooterView* headerFooterView =
      [[[item cellClass] alloc] init];
  EXPECT_TRUE(
      [headerFooterView isMemberOfClass:[UITableViewHeaderFooterView class]]);
  EXPECT_EQ(UIAccessibilityTraitNone, [headerFooterView accessibilityTraits]);
  EXPECT_FALSE([headerFooterView accessibilityIdentifier]);
  [item configureHeaderFooterView:headerFooterView];
  EXPECT_EQ(UIAccessibilityTraitButton, [headerFooterView accessibilityTraits]);
  EXPECT_NSEQ(@"test_identifier", [headerFooterView accessibilityIdentifier]);
}

}  // namespace
