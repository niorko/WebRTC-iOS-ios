// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/clean/chrome/browser/ui/web_contents/web_contents_mediator.h"

#include "base/memory/ptr_util.h"
#import "ios/clean/chrome/browser/ui/web_contents/web_contents_consumer.h"
#import "ios/web/public/test/fakes/test_navigation_manager.h"
#import "ios/web/public/test/fakes/test_web_state.h"
#include "testing/gtest/include/gtest/gtest.h"
#include "testing/gtest_mac.h"
#include "testing/platform_test.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@interface StubContentsConsumer : NSObject<WebContentsConsumer>
@property(nonatomic, weak) UIView* contentView;
@end

@implementation StubContentsConsumer
@synthesize contentView = _contentView;

- (void)contentViewDidChange:(UIView*)contentView {
  self.contentView = contentView;
}

@end

namespace {

class StubNavigationManager : public web::TestNavigationManager {
 public:
  int GetItemCount() const override { return item_count_; }

  void LoadURLWithParams(const NavigationManager::WebLoadParams&) override {
    has_loaded_url_ = true;
  }

  void SetItemCount(int count) { item_count_ = count; }
  bool GetHasLoadedUrl() { return has_loaded_url_; }

 private:
  int item_count_;
  bool has_loaded_url_;
};

class WebContentsMediatorTest : public PlatformTest {
 public:
  WebContentsMediatorTest() {
    auto navigation_manager = base::MakeUnique<StubNavigationManager>();
    navigation_manager->SetItemCount(0);
    test_web_state_.SetView([[UIView alloc] init]);
    test_web_state_.SetNavigationManager(std::move(navigation_manager));

    auto new_navigation_manager = base::MakeUnique<StubNavigationManager>();
    new_test_web_state_.SetView([[UIView alloc] init]);
    new_test_web_state_.SetNavigationManager(std::move(new_navigation_manager));

    mediator_ = [[WebContentsMediator alloc] init];
  }
  ~WebContentsMediatorTest() override { [mediator_ disconnect]; }

  StubNavigationManager* navigation_manager() {
    return static_cast<StubNavigationManager*>(
        test_web_state_.GetNavigationManager());
  }

  StubNavigationManager* new_navigation_manager() {
    return static_cast<StubNavigationManager*>(
        new_test_web_state_.GetNavigationManager());
  }

 protected:
  WebContentsMediator* mediator_;
  web::TestWebState test_web_state_;
  web::TestWebState new_test_web_state_;
};

// Tests that webUsage is disabled when mediator is disconnected.
TEST_F(WebContentsMediatorTest, TestDisconnect) {
  mediator_.webState = &test_web_state_;
  EXPECT_TRUE(test_web_state_.IsWebUsageEnabled());
  [mediator_ disconnect];
  EXPECT_FALSE(test_web_state_.IsWebUsageEnabled());
}

// Tests that both the old and new active web states have WebUsageEnabled
// updated.
TEST_F(WebContentsMediatorTest, TestWebUsageEnabled) {
  mediator_.webState = &test_web_state_;
  test_web_state_.SetWebUsageEnabled(true);
  new_test_web_state_.SetWebUsageEnabled(false);
  mediator_.webState = &new_test_web_state_;
  EXPECT_FALSE(test_web_state_.IsWebUsageEnabled());
  EXPECT_TRUE(new_test_web_state_.IsWebUsageEnabled());
}

// Tests that a URL is loaded if the new active web state has zero navigation
// items.
TEST_F(WebContentsMediatorTest, TestURLHasLoaded) {
  mediator_.webState = &test_web_state_;
  new_navigation_manager()->SetItemCount(0);
  mediator_.webState = &new_test_web_state_;
  EXPECT_TRUE(navigation_manager()->GetHasLoadedUrl());
}

// Tests that a URL is not loaded if the new active web state has some
// navigation items.
TEST_F(WebContentsMediatorTest, TestNoLoadURL) {
  mediator_.webState = &test_web_state_;
  new_navigation_manager()->SetItemCount(2);
  mediator_.webState = &new_test_web_state_;
  EXPECT_FALSE(new_navigation_manager()->GetHasLoadedUrl());
}

// Tests that the consumer is updated immediately once both consumer and
// webStateList are set. This test sets webStateList first.
TEST_F(WebContentsMediatorTest, TestConsumerViewIsSetWebStateListFirst) {
  StubContentsConsumer* consumer = [[StubContentsConsumer alloc] init];
  mediator_.webState = &test_web_state_;
  EXPECT_NE(test_web_state_.GetView(), consumer.contentView);
  mediator_.consumer = consumer;
  EXPECT_EQ(test_web_state_.GetView(), consumer.contentView);
}

// Tests that the consumer is updated immediately once both consumer and
// webStateList are set. This test sets consumer first.
TEST_F(WebContentsMediatorTest, TestConsumerViewIsSetConsumerFirst) {
  StubContentsConsumer* consumer = [[StubContentsConsumer alloc] init];
  mediator_.consumer = consumer;
  EXPECT_NE(test_web_state_.GetView(), consumer.contentView);
  mediator_.webState = &test_web_state_;
  EXPECT_EQ(test_web_state_.GetView(), consumer.contentView);
}

}  // namespace
