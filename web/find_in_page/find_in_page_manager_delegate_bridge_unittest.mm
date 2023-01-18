// Copyright 2019 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/web/public/find_in_page/find_in_page_manager_delegate_bridge.h"

#import "ios/web/find_in_page/java_script_find_in_page_manager_impl.h"
#import "ios/web/public/test/fakes/crw_fake_find_in_page_manager_delegate.h"
#import "ios/web/public/test/fakes/fake_web_state.h"
#import "testing/platform_test.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace web {

// Test fixture to test FindInPageManagerDelegateBridge class.
class FindInPageManagerDelegateBridgeTest : public PlatformTest {
 protected:
  FindInPageManagerDelegateBridgeTest()
      : delegate_([[CRWFakeFindInPageManagerDelegate alloc] init]),
        bridge_(std::make_unique<FindInPageManagerDelegateBridge>(delegate_)) {
    JavaScriptFindInPageManagerImpl::CreateForWebState(&fake_web_state_);
  }

  CRWFakeFindInPageManagerDelegate* delegate_ = nil;
  std::unique_ptr<FindInPageManagerDelegateBridge> bridge_;
  web::FakeWebState fake_web_state_;
};

// Tests that CRWFindInPageManagerDelegate properly receives values from
// DidHighlightMatches().
TEST_F(FindInPageManagerDelegateBridgeTest, DidHighlightMatches) {
  auto* manager = JavaScriptFindInPageManager::FromWebState(&fake_web_state_);
  bridge_->DidHighlightMatches(manager, &fake_web_state_, 1, @"foo");
  EXPECT_EQ(1, delegate_.matchCount);
  EXPECT_EQ(@"foo", delegate_.query);
  EXPECT_EQ(&fake_web_state_, delegate_.webState);
}

// Tests that CRWFindInPageManagerDelegate properly receives values from
// DidSelectMatch().
TEST_F(FindInPageManagerDelegateBridgeTest, DidSelectMatch) {
  auto* manager = JavaScriptFindInPageManager::FromWebState(&fake_web_state_);
  bridge_->DidSelectMatch(manager, &fake_web_state_, 1, @"match context");
  EXPECT_EQ(1, delegate_.index);
  EXPECT_EQ(&fake_web_state_, delegate_.webState);
  EXPECT_EQ(@"match context", delegate_.contextString);
}

}  // namespace web
