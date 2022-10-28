// Copyright 2016 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/browser_view/key_commands_provider.h"

#import "base/test/scoped_feature_list.h"
#import "base/test/task_environment.h"
#import "ios/chrome/browser/browser_state/test_chrome_browser_state.h"
#import "ios/chrome/browser/find_in_page/find_tab_helper.h"
#import "ios/chrome/browser/main/test_browser.h"
#import "ios/chrome/browser/ui/keyboard/UIKeyCommand+Chrome.h"
#import "ios/chrome/browser/ui/keyboard/features.h"
#import "ios/chrome/browser/web_state_list/web_state_list.h"
#import "ios/chrome/browser/web_state_list/web_state_opener.h"
#import "ios/web/common/uikit_ui_util.h"
#import "ios/web/find_in_page/find_in_page_manager_impl.h"
#import "ios/web/public/test/fakes/fake_web_state.h"
#import "testing/gtest/include/gtest/gtest.h"
#import "testing/platform_test.h"
#import "third_party/ocmock/OCMock/OCMock.h"
#import "third_party/ocmock/gtest_support.h"
#import "third_party/ocmock/ocmock_extensions.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

class NoMenuKeyCommandsProviderTest : public PlatformTest {
 protected:
  NoMenuKeyCommandsProviderTest() {
    browser_state_ = TestChromeBrowserState::Builder().Build();
    browser_ = std::make_unique<TestBrowser>(browser_state_.get());
    web_state_list_ = browser_->GetWebStateList();
    feature_list_.InitWithFeatures(
        /*enabled_features=*/{},
        /*disabled_features=*/{kKeyboardShortcutsMenu});
  }
  ~NoMenuKeyCommandsProviderTest() override {}

  web::FakeWebState* InsertNewWebState(int index) {
    auto web_state = std::make_unique<web::FakeWebState>();
    web_state->SetBrowserState(browser_state_.get());
    int insertedIndex = web_state_list_->InsertWebState(
        index, std::move(web_state), WebStateList::INSERT_ACTIVATE,
        WebStateOpener());
    return static_cast<web::FakeWebState*>(
        web_state_list_->GetWebStateAt(insertedIndex));
  }

  base::test::TaskEnvironment task_environment_;
  std::unique_ptr<TestChromeBrowserState> browser_state_;
  std::unique_ptr<TestBrowser> browser_;
  WebStateList* web_state_list_;

 private:
  base::test::ScopedFeatureList feature_list_;
};

TEST_F(NoMenuKeyCommandsProviderTest, NoTabs_ReturnsObjects) {
  id<ApplicationCommands, BrowserCommands, BrowserCoordinatorCommands,
     FindInPageCommands>
      dispatcher = nil;

  KeyCommandsProvider* provider =
      [[KeyCommandsProvider alloc] initWithBrowser:browser_.get()];
  provider.dispatcher = dispatcher;

  // No tabs.
  EXPECT_EQ(web_state_list_->count(), 0);

  EXPECT_NE(0u, provider.keyCommands.count);
}

TEST_F(NoMenuKeyCommandsProviderTest, ReturnsKeyCommandsObjects) {
  id<ApplicationCommands, BrowserCommands, BrowserCoordinatorCommands,
     FindInPageCommands>
      dispatcher = nil;

  KeyCommandsProvider* provider =
      [[KeyCommandsProvider alloc] initWithBrowser:browser_.get()];
  provider.dispatcher = dispatcher;

  // No tabs.
  EXPECT_EQ(web_state_list_->count(), 0);

  for (id element in provider.keyCommands) {
    EXPECT_TRUE([element isKindOfClass:[UIKeyCommand class]]);
  }
}

TEST_F(NoMenuKeyCommandsProviderTest, MoreKeyboardCommandsWhenTabs) {
  id<ApplicationCommands, BrowserCommands, BrowserCoordinatorCommands,
     FindInPageCommands>
      dispatcher = nil;

  KeyCommandsProvider* provider =
      [[KeyCommandsProvider alloc] initWithBrowser:browser_.get()];
  provider.dispatcher = dispatcher;

  // No tabs.
  EXPECT_EQ(web_state_list_->count(), 0);

  NSUInteger numberOfKeyCommandsWithoutTabs = provider.keyCommands.count;

  InsertNewWebState(0);

  // Tabs.
  EXPECT_EQ(web_state_list_->count(), 1);
  NSUInteger numberOfKeyCommandsWithTabs = provider.keyCommands.count;

  EXPECT_GT(numberOfKeyCommandsWithTabs, numberOfKeyCommandsWithoutTabs);
}

TEST_F(NoMenuKeyCommandsProviderTest, LessKeyCommandsWhenTabsAndEditingText) {
  id<ApplicationCommands, BrowserCommands, BrowserCoordinatorCommands,
     FindInPageCommands>
      dispatcher = nil;

  KeyCommandsProvider* provider =
      [[KeyCommandsProvider alloc] initWithBrowser:browser_.get()];
  provider.dispatcher = dispatcher;

  // No tabs.
  EXPECT_EQ(web_state_list_->count(), 0);

  InsertNewWebState(0);

  // Tabs.
  EXPECT_EQ(web_state_list_->count(), 1);

  // Not editing text.
  NSUInteger numberOfKeyCommandsWhenNotEditingText = provider.keyCommands.count;

  // Focus a text field.
  UITextField* textField = [[UITextField alloc] init];
  [GetAnyKeyWindow() addSubview:textField];
  [textField becomeFirstResponder];

  // Editing text.
  NSUInteger numberOfKeyCommandsWhenEditingText = provider.keyCommands.count;

  EXPECT_LT(numberOfKeyCommandsWhenEditingText,
            numberOfKeyCommandsWhenNotEditingText);

  // Reset the first responder.
  [textField resignFirstResponder];
}

TEST_F(NoMenuKeyCommandsProviderTest,
       MoreKeyboardCommandsWhenFindInPageAvailable) {
  id<ApplicationCommands, BrowserCommands, BrowserCoordinatorCommands,
     FindInPageCommands>
      dispatcher = nil;

  KeyCommandsProvider* provider =
      [[KeyCommandsProvider alloc] initWithBrowser:browser_.get()];
  provider.dispatcher = dispatcher;

  // No tabs.
  EXPECT_EQ(web_state_list_->count(), 0);

  web::FakeWebState* web_state = InsertNewWebState(0);
  web::FindInPageManagerImpl::CreateForWebState(web_state);
  FindTabHelper::CreateForWebState(web_state);

  // Tabs.
  EXPECT_EQ(web_state_list_->count(), 1);

  // No Find in Page.
  web_state->SetContentIsHTML(false);
  NSUInteger numberOfKeyCommandsWithoutFIP = provider.keyCommands.count;

  // Can Find in Page.
  web_state->SetContentIsHTML(true);
  NSUInteger numberOfKeyCommandsWithFIP = provider.keyCommands.count;

  EXPECT_GT(numberOfKeyCommandsWithFIP, numberOfKeyCommandsWithoutFIP);
}

// Verifies the next/previous tab commands from the keyboard work OK.
TEST_F(NoMenuKeyCommandsProviderTest, TestFocusNextPrevious) {
  // Add more web states.
  InsertNewWebState(0);
  InsertNewWebState(1);
  InsertNewWebState(2);

  // This test assumes there are exactly three web states in the list.
  ASSERT_EQ(web_state_list_->count(), 3);

  KeyCommandsProvider* provider =
      [[KeyCommandsProvider alloc] initWithBrowser:browser_.get()];

  SEL focusNextTabAction;
  SEL focusPreviousTabAction;

  NSArray<UIKeyCommand*>* commands = provider.keyCommands;
  for (UIKeyCommand* command in commands) {
    if (([command.input isEqualToString:@"\t"]) &&
        (command.modifierFlags & UIKeyModifierControl)) {
      if (command.modifierFlags & UIKeyModifierShift) {
        focusPreviousTabAction = command.action;
      } else {
        focusNextTabAction = command.action;
      }
    }
  }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
  [provider performSelector:focusNextTabAction];
  EXPECT_EQ(web_state_list_->active_index(), 0);
  [provider performSelector:focusNextTabAction];
  EXPECT_EQ(web_state_list_->active_index(), 1);
  [provider performSelector:focusNextTabAction];
  EXPECT_EQ(web_state_list_->active_index(), 2);
  [provider performSelector:focusNextTabAction];
  EXPECT_EQ(web_state_list_->active_index(), 0);
  [provider performSelector:focusPreviousTabAction];
  EXPECT_EQ(web_state_list_->active_index(), 2);
  [provider performSelector:focusPreviousTabAction];
  EXPECT_EQ(web_state_list_->active_index(), 1);
  [provider performSelector:focusPreviousTabAction];
  EXPECT_EQ(web_state_list_->active_index(), 0);
#pragma clang diagnostic pop
}

}  // namespace
