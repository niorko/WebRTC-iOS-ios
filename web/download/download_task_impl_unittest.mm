// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/web/download/download_task_impl.h"

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

#include <memory>

#include "base/files/file_util.h"
#include "base/strings/utf_string_conversions.h"
#import "base/test/ios/wait_util.h"
#import "ios/web/net/cookies/wk_cookie_util.h"
#import "ios/web/public/download/download_task_observer.h"
#include "ios/web/public/test/fakes/fake_cookie_store.h"
#import "ios/web/public/test/fakes/fake_web_state.h"
#include "ios/web/public/test/web_test.h"
#import "ios/web/test/fakes/crw_fake_nsurl_session_task.h"
#include "net/base/net_errors.h"
#include "testing/gmock/include/gmock/gmock.h"
#include "testing/gtest/include/gtest/gtest.h"
#include "testing/gtest_mac.h"
#include "testing/platform_test.h"
#import "third_party/ocmock/OCMock/OCMock.h"
#include "url/gurl.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using base::test::ios::kWaitForCookiesTimeout;
using base::test::ios::kWaitForDownloadTimeout;
using base::test::ios::kWaitForFileOperationTimeout;
using base::test::ios::WaitUntilConditionOrTimeout;

namespace web {

namespace {

const char kUrl[] = "chromium://download.test/";
const char kContentDisposition[] = "attachment; filename=file.test";
const char kMimeType[] = "application/pdf";
NSString* const kHttpMethod = @"POST";

class MockDownloadTaskObserver : public DownloadTaskObserver {
 public:
  MOCK_METHOD1(OnDownloadUpdated, void(DownloadTask* task));
  void OnDownloadDestroyed(DownloadTask* task) override {
    // Removing observer here works as a test that
    // DownloadTaskObserver::OnDownloadDestroyed is actually called.
    // DownloadTask DCHECKs if it is destroyed without observer removal.
    task->RemoveObserver(this);
  }
};

}  //  namespace

// Creates a non-virtual class to use for testing
class FakeDownloadTaskImpl : public DownloadTaskImpl {
 public:
  FakeDownloadTaskImpl(WebState* web_state,
                       const GURL& original_url,
                       NSString* http_method,
                       const std::string& content_disposition,
                       int64_t total_bytes,
                       const std::string& mime_type,
                       NSString* identifier)
      : DownloadTaskImpl(web_state,
                         original_url,
                         http_method,
                         content_disposition,
                         total_bytes,
                         mime_type,
                         identifier) {}

  NSData* GetResponseData() const override { return response_data_; }

  const base::FilePath& GetResponsePath() const override {
    return response_path_;
  }

 private:
  base::FilePath response_path_;
  __strong NSData* response_data_ = nil;
};

// Test fixture for testing DownloadTaskImplTest class.
class DownloadTaskImplTest : public PlatformTest {
 protected:
  DownloadTaskImplTest()
      : task_(std::make_unique<FakeDownloadTaskImpl>(
            &web_state_,
            GURL(kUrl),
            kHttpMethod,
            kContentDisposition,
            /*total_bytes=*/-1,
            kMimeType,
            [[NSUUID UUID] UUIDString])) {
    task_->AddObserver(&task_observer_);
  }

  web::WebTaskEnvironment task_environment_;
  FakeWebState web_state_;
  std::unique_ptr<FakeDownloadTaskImpl> task_;
  MockDownloadTaskObserver task_observer_;
};

// Tests DownloadTaskImpl default state after construction.
TEST_F(DownloadTaskImplTest, DefaultState) {
  EXPECT_EQ(&web_state_, task_->GetWebState());
  EXPECT_EQ(DownloadTask::State::kNotStarted, task_->GetState());
  EXPECT_NSNE(@"", task_->GetIdentifier());
  EXPECT_EQ(kUrl, task_->GetOriginalUrl());
  EXPECT_FALSE(task_->IsDone());
  EXPECT_EQ(0, task_->GetErrorCode());
  EXPECT_EQ(-1, task_->GetHttpCode());
  EXPECT_EQ(-1, task_->GetTotalBytes());
  EXPECT_EQ(0, task_->GetReceivedBytes());
  EXPECT_EQ(-1, task_->GetPercentComplete());
  EXPECT_EQ(kContentDisposition, task_->GetContentDisposition());
  EXPECT_EQ(kMimeType, task_->GetMimeType());
  EXPECT_EQ(kMimeType, task_->GetOriginalMimeType());
  EXPECT_EQ("file.test", base::UTF16ToUTF8(task_->GetSuggestedFilename()));
}

// Tests that DownloadTaskImpl methods are overloaded
TEST_F(DownloadTaskImplTest, SuccessfulInitialization) {
  // Simulates successful download and tests that Start() and
  // OnDownloadFinished are overloaded correctly
  task_->Start(base::FilePath(), web::DownloadTask::Destination::kToMemory);
  EXPECT_EQ(DownloadTask::State::kInProgress, task_->GetState());

  // Tests that Cancel() is overloaded
  task_->Cancel();
  EXPECT_EQ(DownloadTask::State::kCancelled, task_->GetState());
}
}  // namespace web
