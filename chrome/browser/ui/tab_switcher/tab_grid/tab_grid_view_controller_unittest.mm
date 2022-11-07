// Copyright 2022 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/tab_switcher/tab_grid/tab_grid_view_controller.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

#import "base/test/metrics/user_action_tester.h"
#import "base/test/scoped_feature_list.h"
#import "ios/chrome/browser/ui/keyboard/features.h"
#import "testing/platform_test.h"

namespace {

class TabGridViewControllerTest : public PlatformTest {
 protected:
  TabGridViewControllerTest() {
    view_controller_ = [[TabGridViewController alloc]
        initWithPageConfiguration:TabGridPageConfiguration::kAllPagesEnabled];
  }
  ~TabGridViewControllerTest() override {}

  void ExpectUMA(NSString* action, const std::string& user_action) {
    ASSERT_EQ(user_action_tester_.GetActionCount(user_action), 0);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [view_controller_ performSelector:NSSelectorFromString(action)];
#pragma clang diagnostic pop
    EXPECT_EQ(user_action_tester_.GetActionCount(user_action), 1);
  }

  base::UserActionTester user_action_tester_;
  TabGridViewController* view_controller_;
};

// Checks that TabGridViewController returns key commands when the Keyboard
// Shortcuts Menu feature is enabled.
TEST_F(TabGridViewControllerTest, ReturnsKeyCommands_MenuEnabled) {
  base::test::ScopedFeatureList feature_list;
  feature_list.InitWithFeatures(
      /*enabled_features=*/{kKeyboardShortcutsMenu},
      /*disabled_features=*/{});

  EXPECT_GT(view_controller_.keyCommands.count, 0u);
}

// Checks that TabGridViewController returns key commands when the Keyboard
// Shortcuts Menu feature is disabled.
TEST_F(TabGridViewControllerTest, ReturnsKeyCommands_MenuDisabled) {
  base::test::ScopedFeatureList feature_list;
  feature_list.InitWithFeatures(
      /*enabled_features=*/{},
      /*disabled_features=*/{kKeyboardShortcutsMenu});

  EXPECT_GT(view_controller_.keyCommands.count, 0u);
}

// Checks that TabGridViewController implements the following actions.
TEST_F(TabGridViewControllerTest, ImplementsActions) {
  [view_controller_ keyCommand_openNewTab];
  [view_controller_ keyCommand_openNewRegularTab];
  [view_controller_ keyCommand_openNewIncognitoTab];
}

// Checks that metrics are correctly reported.
TEST_F(TabGridViewControllerTest, Metrics) {
  ExpectUMA(@"keyCommand_openNewTab", "MobileKeyCommandOpenNewTab");
  ExpectUMA(@"keyCommand_openNewRegularTab",
            "MobileKeyCommandOpenNewRegularTab");
  ExpectUMA(@"keyCommand_openNewIncognitoTab",
            "MobileKeyCommandOpenNewIncognitoTab");
}

}  // namespace
