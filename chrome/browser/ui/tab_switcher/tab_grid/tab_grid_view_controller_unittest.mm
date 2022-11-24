// Copyright 2022 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/tab_switcher/tab_grid/tab_grid_view_controller.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

#import "base/test/metrics/user_action_tester.h"
#import "base/test/scoped_feature_list.h"
#import "ios/chrome/browser/ui/gestures/view_revealing_vertical_pan_handler.h"
#import "ios/chrome/browser/ui/keyboard/features.h"
#import "ios/chrome/grit/ios_strings.h"
#import "testing/platform_test.h"
#import "ui/base/l10n/l10n_util.h"

namespace {

class TabGridViewControllerTest : public PlatformTest {
 protected:
  TabGridViewControllerTest() {
    view_controller_ = [[TabGridViewController alloc]
        initWithPageConfiguration:TabGridPageConfiguration::kAllPagesEnabled];
  }
  ~TabGridViewControllerTest() override {}

  // Checks that `view_controller_` can perform the `action` with the given
  // `sender`.
  bool CanPerform(NSString* action, id sender) {
    return [view_controller_ canPerformAction:NSSelectorFromString(action)
                                   withSender:sender];
  }

  // Checks that `view_controller_` can perform the `action`. The sender is set
  // to nil when performing this check.
  bool CanPerform(NSString* action) { return CanPerform(action, nil); }

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

// Checks whether TabGridViewController can perform the actions to open tabs.
TEST_F(TabGridViewControllerTest, CanPerform_OpenTabsActions) {
  NSArray<NSString*>* actions = @[
    @"keyCommand_openNewTab",
    @"keyCommand_openNewRegularTab",
    @"keyCommand_openNewIncognitoTab",
  ];

  [view_controller_ setCurrentPageAndPageControl:TabGridPageIncognitoTabs
                                        animated:NO];
  for (NSString* action in actions) {
    EXPECT_TRUE(CanPerform(action));
  }

  [view_controller_ setCurrentPageAndPageControl:TabGridPageRegularTabs
                                        animated:NO];
  for (NSString* action in actions) {
    EXPECT_TRUE(CanPerform(action));
  }

  [view_controller_ setCurrentPageAndPageControl:TabGridPageRemoteTabs
                                        animated:NO];
  for (NSString* action in actions) {
    EXPECT_FALSE(CanPerform(action));
  }

  [view_controller_ setCurrentPageAndPageControl:TabGridPageRegularTabs
                                        animated:NO];
  for (NSString* action in actions) {
    EXPECT_TRUE(CanPerform(action));
  }
}

// Checks that TabGridViewController implements the following actions.
TEST_F(TabGridViewControllerTest, ImplementsActions) {
  // Load the view.
  std::ignore = view_controller_.view;
  [view_controller_ keyCommand_openNewTab];
  [view_controller_ keyCommand_openNewRegularTab];
  [view_controller_ keyCommand_openNewIncognitoTab];
  [view_controller_ keyCommand_find];
}

// Checks that metrics are correctly reported.
TEST_F(TabGridViewControllerTest, Metrics) {
  // Load the view.
  std::ignore = view_controller_.view;
  ExpectUMA(@"keyCommand_openNewTab", "MobileKeyCommandOpenNewTab");
  ExpectUMA(@"keyCommand_openNewRegularTab",
            "MobileKeyCommandOpenNewRegularTab");
  ExpectUMA(@"keyCommand_openNewIncognitoTab",
            "MobileKeyCommandOpenNewIncognitoTab");
  ExpectUMA(@"keyCommand_find", "MobileKeyCommandSearchTabs");
}

// This test ensure 2 things:
// * the key command find is available when the tab grid is currently visible,
// * the key command associated title is correct.
TEST_F(TabGridViewControllerTest, ValidateCommand_find) {
  // Load the view.
  std::ignore = view_controller_.view;
  EXPECT_FALSE(CanPerform(@"keyCommand_find"));
  // Create a view revealing vertical pan handler.
  ViewRevealingVerticalPanHandler* pan_handler =
      [[ViewRevealingVerticalPanHandler alloc]
          initWithPeekedHeight:212.0f
                baseViewHeight:800.0f
                  initialState:ViewRevealState::Peeked];

  // Displays the tab grid.
  [pan_handler addAnimatee:view_controller_];
  [pan_handler setNextState:ViewRevealState::Revealed
                   animated:NO
                    trigger:ViewRevealTrigger::Unknown];

  // Ensures that the command is available.
  EXPECT_TRUE(CanPerform(@"keyCommand_find"));
  id findTarget = [view_controller_ targetForAction:@selector(keyCommand_find)
                                         withSender:nil];
  EXPECT_EQ(findTarget, view_controller_);

  // Ensures that the title is correct.
  for (UIKeyCommand* command in view_controller_.keyCommands) {
    [view_controller_ validateCommand:command];
    if (command.action == @selector(keyCommand_find)) {
      EXPECT_TRUE([command.discoverabilityTitle
          isEqualToString:l10n_util::GetNSStringWithFixup(
                              IDS_IOS_KEYBOARD_SEARCH_TABS)]);
    }
  }
}

}  // namespace
