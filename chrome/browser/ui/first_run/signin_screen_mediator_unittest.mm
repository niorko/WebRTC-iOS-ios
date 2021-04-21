// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/first_run/signin_screen_mediator.h"

#import "base/test/ios/wait_util.h"
#import "ios/chrome/browser/ui/first_run/signin_screen_consumer.h"
#import "ios/public/provider/chrome/browser/signin/fake_chrome_identity.h"
#import "ios/public/provider/chrome/browser/signin/fake_chrome_identity_service.h"
#include "ios/public/provider/chrome/browser/test_chrome_browser_provider.h"
#include "testing/gtest/include/gtest/gtest.h"
#include "testing/platform_test.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using base::test::ios::kWaitForActionTimeout;
using base::test::ios::WaitUntilConditionOrTimeout;

// Fake implementing the consumer protocol.
@interface FakeSigninScreenConsumer : NSObject <SigninScreenConsumer>

@property(nonatomic, assign) BOOL hidden;
@property(nonatomic, copy) NSString* userName;
@property(nonatomic, copy) NSString* email;
@property(nonatomic, strong) UIImage* userImage;

@end

@implementation FakeSigninScreenConsumer

- (void)hideIdentityButtonControl {
  self.hidden = YES;
}

- (void)setUserImage:(UIImage*)userImage {
  _userImage = userImage;
}

- (void)setSelectedIdentityUserName:(NSString*)userName email:(NSString*)email {
  self.userName = userName;
  self.email = email;
}

@end

class SigninScreenMediatorTest : public PlatformTest {
 protected:
  void SetUp() override {
    browser_provider_ = ios::TestChromeBrowserProvider::GetTestProvider();
    identity_service_ =
        ios::FakeChromeIdentityService::GetInstanceFromChromeProvider();
    mediator_ = [[SigninScreenMediator alloc] init];
    consumer_ = [[FakeSigninScreenConsumer alloc] init];
    identity_ = [FakeChromeIdentity identityWithEmail:@"test@email.com"
                                               gaiaID:@"gaiaID"
                                                 name:@"Test Name"];
  }

  SigninScreenMediator* mediator_;
  ios::TestChromeBrowserProvider* browser_provider_;
  ios::FakeChromeIdentityService* identity_service_;
  FakeSigninScreenConsumer* consumer_;
  FakeChromeIdentity* identity_;
};

// Tests that setting the consumer after the selected identity is set is
// correctly notifying the consumer.
TEST_F(SigninScreenMediatorTest, TestSettingConsumerWithExistingIdentity) {
  mediator_.selectedIdentity = identity_;
  mediator_.consumer = consumer_;

  EXPECT_EQ(identity_.userEmail, consumer_.email);
  EXPECT_EQ(identity_.userFullName, consumer_.userName);
  EXPECT_FALSE(consumer_.hidden);
  // The image is added asynchronously.
  EXPECT_EQ(nil, consumer_.userImage);

  EXPECT_TRUE(WaitUntilConditionOrTimeout(kWaitForActionTimeout, ^bool {
    return identity_service_->GetCachedAvatarForIdentity(identity_) ==
           consumer_.userImage;
  }));
}

// Tests that the consumer is correctly updated when the selected identity is
// updated.
TEST_F(SigninScreenMediatorTest, TestUpdatingSelectedIdentity) {
  mediator_.consumer = consumer_;

  EXPECT_EQ(nil, consumer_.email);
  EXPECT_EQ(nil, consumer_.userName);
  // True because the selected identity is nil.
  EXPECT_TRUE(consumer_.hidden);
  EXPECT_EQ(nil, consumer_.userImage);

  consumer_.hidden = NO;
  mediator_.selectedIdentity = identity_;

  EXPECT_EQ(identity_.userEmail, consumer_.email);
  EXPECT_EQ(identity_.userFullName, consumer_.userName);
  EXPECT_FALSE(consumer_.hidden);
  // The image is added asynchronously.
  EXPECT_EQ(nil, consumer_.userImage);

  EXPECT_TRUE(WaitUntilConditionOrTimeout(kWaitForActionTimeout, ^bool {
    return identity_service_->GetCachedAvatarForIdentity(identity_) ==
           consumer_.userImage;
  }));
}

// Tests IdentityService observations of the identity list.
TEST_F(SigninScreenMediatorTest, TestIdentityListChanged) {
  mediator_.consumer = consumer_;

  EXPECT_EQ(nil, consumer_.email);
  EXPECT_EQ(nil, consumer_.userName);
  // True because the selected identity is nil.
  EXPECT_TRUE(consumer_.hidden);
  EXPECT_EQ(nil, consumer_.userImage);

  consumer_.hidden = NO;

  // Adding an identity is selecting it.
  identity_service_->AddIdentity(identity_);

  EXPECT_EQ(identity_.userEmail, consumer_.email);
  EXPECT_EQ(identity_.userFullName, consumer_.userName);
  EXPECT_FALSE(consumer_.hidden);
  // The image is added asynchronously.
  EXPECT_EQ(nil, consumer_.userImage);

  EXPECT_TRUE(WaitUntilConditionOrTimeout(kWaitForActionTimeout, ^bool {
    return identity_service_->GetCachedAvatarForIdentity(identity_) ==
           consumer_.userImage;
  }));

  // Removing all the identity is resetting the selected identity.
  __block bool callback_done = false;
  identity_service_->ForgetIdentity(identity_, ^(NSError*) {
    callback_done = true;
  });
  EXPECT_TRUE(WaitUntilConditionOrTimeout(kWaitForActionTimeout, ^bool {
    return callback_done;
  }));

  EXPECT_TRUE(consumer_.hidden);
  EXPECT_EQ(nil, consumer_.userImage);
}

// Tests BrowserProvider observation of the identity service.
TEST_F(SigninScreenMediatorTest, TestProfileUpdate) {
  mediator_.selectedIdentity = identity_;
  mediator_.consumer = consumer_;

  ASSERT_EQ(identity_.userEmail, consumer_.email);
  ASSERT_EQ(identity_.userFullName, consumer_.userName);

  NSString* email = @"second@email.com";
  NSString* name = @"Second identity";
  FakeChromeIdentity* second_identity =
      [FakeChromeIdentity identityWithEmail:email
                                     gaiaID:@"second gaiaID"
                                       name:name];
  std::unique_ptr<ios::FakeChromeIdentityService> second_service_unique =
      std::make_unique<ios::FakeChromeIdentityService>();
  ios::FakeChromeIdentityService* second_service = second_service_unique.get();
  browser_provider_->SetChromeIdentityServiceForTesting(
      std::move(second_service_unique));

  second_service->AddIdentity(second_identity);

  EXPECT_NE(email, consumer_.email);
  EXPECT_NE(name, consumer_.userName);

  NSString* updated_email = @"updated@email.com";
  NSString* updated_name = @"Second - Updated";

  second_identity.userEmail = updated_email;
  second_identity.userFullName = updated_name;

  // The name shouldn't have changed yet.
  EXPECT_NE(email, consumer_.email);
  EXPECT_NE(name, consumer_.userName);

  // Triggering the update is updating the consumer.
  second_service->TriggerIdentityUpdateNotification(second_identity);

  EXPECT_NE(updated_email, consumer_.email);
  EXPECT_NE(updated_name, consumer_.userName);
}
