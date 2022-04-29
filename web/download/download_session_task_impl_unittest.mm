// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/web/download/download_session_task_impl.h"

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

#import <memory>

#import "base/bind.h"
#import "base/files/file_util.h"
#import "base/files/scoped_temp_dir.h"
#import "base/run_loop.h"
#import "base/strings/utf_string_conversions.h"
#import "base/task/task_traits.h"
#import "base/task/thread_pool.h"
#import "base/test/ios/wait_util.h"
#import "ios/web/net/cookies/wk_cookie_util.h"
#import "ios/web/public/download/download_task_observer.h"
#import "ios/web/public/test/fakes/fake_browser_state.h"
#import "ios/web/public/test/fakes/fake_cookie_store.h"
#import "ios/web/public/test/fakes/fake_web_state.h"
#import "ios/web/public/test/web_task_environment.h"
#import "ios/web/public/test/web_test.h"
#import "ios/web/test/fakes/crw_fake_nsurl_session_task.h"
#import "net/base/net_errors.h"
#import "net/url_request/url_fetcher_response_writer.h"
#import "net/url_request/url_request_context.h"
#import "net/url_request/url_request_context_getter.h"
#import "testing/gmock/include/gmock/gmock.h"
#import "testing/gtest/include/gtest/gtest.h"
#import "testing/gtest_mac.h"
#import "testing/platform_test.h"
#import "third_party/ocmock/OCMock/OCMock.h"
#import "url/gurl.h"

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
const base::FilePath::CharType kTestFileName[] = FILE_PATH_LITERAL("file.test");
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

// Allows waiting for DownloadTaskObserver::OnDownloadUpdated callback.
class OnDownloadUpdatedWaiter : public DownloadTaskObserver {
 public:
  bool Wait() {
    return WaitUntilConditionOrTimeout(kWaitForDownloadTimeout, ^{
      base::RunLoop().RunUntilIdle();
      return download_updated_;
    });
  }

 private:
  void OnDownloadUpdated(DownloadTask* task) override {
    download_updated_ = true;
  }
  bool download_updated_ = false;
};

}  //  namespace

// Test fixture for testing DownloadTaskImplTest class.
class DownloadSessionTaskImplTest : public PlatformTest {
 protected:
  DownloadSessionTaskImplTest()
      : task_(std::make_unique<DownloadSessionTaskImpl>(
            &web_state_,
            GURL(kUrl),
            kHttpMethod,
            kContentDisposition,
            /*total_bytes=*/-1,
            kMimeType,
            [[NSUUID UUID] UUIDString],
            base::ThreadPool::CreateSequencedTaskRunner(
                {base::MayBlock(), base::TaskPriority::USER_BLOCKING}),
            base::BindRepeating(&DownloadSessionTaskImplTest::CreateSession,
                                base::Unretained(this)))),
        session_delegate_callbacks_queue_(
            dispatch_queue_create(nullptr, DISPATCH_QUEUE_SERIAL)) {
    DCHECK(!session_);
    session_ = OCMStrictClassMock([NSURLSession class]);

    browser_state_.SetOffTheRecord(true);
    browser_state_.SetCookieStore(std::make_unique<FakeCookieStore>());
    web_state_.SetBrowserState(&browser_state_);
    task_->AddObserver(&task_observer_);
  }

  // Starts the download and return NSURLSessionDataTask fake for this task.
  CRWFakeNSURLSessionTask* Start(const base::FilePath& path,
                                 DownloadTask::Destination destination_hint) {
    // Inject fake NSURLSessionDataTask into DownloadTaskImpl.
    NSURL* url = [NSURL URLWithString:@(kUrl)];
    CRWFakeNSURLSessionTask* session_task =
        [[CRWFakeNSURLSessionTask alloc] initWithURL:url];
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = kHttpMethod;
    OCMExpect([session_ dataTaskWithRequest:request]).andReturn(session_task);

    // Start the download.
    task_->Start(path, destination_hint);
    bool success = WaitUntilConditionOrTimeout(kWaitForDownloadTimeout, ^{
      base::RunLoop().RunUntilIdle();
      return session_task.state == NSURLSessionTaskStateRunning;
    });
    return success ? session_task : nil;
  }

  FakeCookieStore* cookie_store() {
    auto* context = browser_state_.GetRequestContext()->GetURLRequestContext();
    // This cast is safe because we set a FakeCookieStore in the constructor.
    return static_cast<FakeCookieStore*>(context->cookie_store());
  }

  // Starts the download and return NSURLSessionDataTask fake for this task.
  // Same as above, but uses URLFetcherStringWriter as response writer.
  CRWFakeNSURLSessionTask* Start() {
    return Start(base::FilePath(), DownloadTask::Destination::kToMemory);
  }

  // Session and session delegate injected into DownloadTaskImpl for testing.
  NSURLSession* session() { return session_; }
  id<NSURLSessionDataDelegate> session_delegate() { return session_delegate_; }
  NSURLSessionConfiguration* session_configuration() {
    return session_configuration_;
  }

  // Updates NSURLSessionTask.countOfBytesReceived and calls
  // URLSession:dataTask:didReceiveData: callback. |data_str| is null terminated
  // C-string that represents the downloaded data.
  void SimulateDataDownload(CRWFakeNSURLSessionTask* session_task,
                            const char data_str[]) {
    OnDownloadUpdatedWaiter callback_waiter;
    task_->AddObserver(&callback_waiter);
    session_task.countOfBytesReceived += strlen(data_str);
    NSData* data = [NSData dataWithBytes:data_str length:strlen(data_str)];
    dispatch_async(session_delegate_callbacks_queue_, ^{
      [session_delegate() URLSession:session()
                            dataTask:session_task
                      didReceiveData:data];
    });
    EXPECT_TRUE(callback_waiter.Wait());
    task_->RemoveObserver(&callback_waiter);
  }

  // Sets NSURLSessionTask.state to NSURLSessionTaskStateCompleted and calls
  // URLSession:dataTask:didCompleteWithError: callback.
  void SimulateDownloadCompletion(CRWFakeNSURLSessionTask* session_task,
                                  NSError* error = nil) {
    OnDownloadUpdatedWaiter callback_waiter;
    task_->AddObserver(&callback_waiter);

    session_task.state = NSURLSessionTaskStateCompleted;
    dispatch_async(session_delegate_callbacks_queue_, ^{
      [session_delegate() URLSession:session()
                                task:session_task
                didCompleteWithError:error];
    });
    EXPECT_TRUE(callback_waiter.Wait());
    task_->RemoveObserver(&callback_waiter);
  }

  NSURLSession* CreateSession(NSURLSessionConfiguration* configuration,
                              id<NSURLSessionDataDelegate> delegate) {
    DCHECK(session_);

    session_configuration_ = configuration;
    session_delegate_ = delegate;

    OCMStub([session_ configuration]).andReturn(session_configuration_);

    return session_;
  }

  web::WebTaskEnvironment task_environment_;
  FakeBrowserState browser_state_;
  FakeWebState web_state_;
  std::unique_ptr<DownloadSessionTaskImpl> task_;
  MockDownloadTaskObserver task_observer_;
  // NSURLSessionDataDelegate callbacks are called on background serial queue.
  dispatch_queue_t session_delegate_callbacks_queue_ = 0;
  __strong id session_ = nil;
  __strong id<NSURLSessionDataDelegate> session_delegate_ = nil;
  __strong NSURLSessionConfiguration* session_configuration_ = nil;
};

// Tests DownloadSessionTaskImpl default state after construction.
TEST_F(DownloadSessionTaskImplTest, DefaultState) {
  EXPECT_EQ(&web_state_, task_->GetWebState());
  EXPECT_EQ(DownloadTask::State::kNotStarted, task_->GetState());
  EXPECT_NE(@"", task_->GetIdentifier());
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
  EXPECT_EQ(base::FilePath(kTestFileName), task_->GenerateFileName());
}

// Tests sucessfull download of response without content.
// (No URLSession:dataTask:didReceiveData: callback).
TEST_F(DownloadSessionTaskImplTest, EmptyContentDownload) {
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  CRWFakeNSURLSessionTask* session_task = Start();
  ASSERT_TRUE(session_task);
  testing::Mock::VerifyAndClearExpectations(&task_observer_);

  // Download has finished.
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  SimulateDownloadCompletion(session_task);
  testing::Mock::VerifyAndClearExpectations(&task_observer_);
  ASSERT_TRUE(WaitUntilConditionOrTimeout(kWaitForDownloadTimeout, ^{
    return task_->IsDone();
  }));
  EXPECT_EQ(DownloadTask::State::kComplete, task_->GetState());
  EXPECT_EQ(0, task_->GetErrorCode());
  EXPECT_EQ(0, task_->GetTotalBytes());
  EXPECT_EQ(0, task_->GetReceivedBytes());
  EXPECT_EQ(100, task_->GetPercentComplete());
}

// Tests sucessfull download of response when content length is unknown until
// the download completes.
TEST_F(DownloadSessionTaskImplTest, UnknownLengthContentDownload) {
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  CRWFakeNSURLSessionTask* session_task = Start();
  ASSERT_TRUE(session_task);
  testing::Mock::VerifyAndClearExpectations(&task_observer_);

  // The response has arrived.
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  const char kData[] = "foo";
  session_task.countOfBytesExpectedToReceive = -1;
  SimulateDataDownload(session_task, kData);
  testing::Mock::VerifyAndClearExpectations(&task_observer_);
  EXPECT_EQ(DownloadTask::State::kInProgress, task_->GetState());
  EXPECT_FALSE(task_->IsDone());
  EXPECT_EQ(0, task_->GetErrorCode());
  EXPECT_EQ(-1, task_->GetTotalBytes());
  EXPECT_EQ(-1, task_->GetPercentComplete());
  EXPECT_NSEQ(@(kData), [[NSString alloc] initWithData:task_->GetResponseData()
                                              encoding:NSUTF8StringEncoding]);

  // Download has finished.
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  int64_t kDataSize = strlen(kData);
  session_task.countOfBytesExpectedToReceive = kDataSize;
  SimulateDownloadCompletion(session_task);
  testing::Mock::VerifyAndClearExpectations(&task_observer_);
  ASSERT_TRUE(WaitUntilConditionOrTimeout(kWaitForDownloadTimeout, ^{
    return task_->IsDone();
  }));
  EXPECT_EQ(DownloadTask::State::kComplete, task_->GetState());
  EXPECT_EQ(0, task_->GetErrorCode());
  EXPECT_EQ(kDataSize, task_->GetTotalBytes());
  EXPECT_EQ(100, task_->GetPercentComplete());
  EXPECT_NSEQ(@(kData), [[NSString alloc] initWithData:task_->GetResponseData()
                                              encoding:NSUTF8StringEncoding]);
}

// Tests cancelling the download task.
TEST_F(DownloadSessionTaskImplTest, Cancelling) {
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  CRWFakeNSURLSessionTask* session_task = Start();
  ASSERT_TRUE(session_task);
  testing::Mock::VerifyAndClearExpectations(&task_observer_);

  // Cancel the download.
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  task_->Cancel();
  ASSERT_TRUE(WaitUntilConditionOrTimeout(kWaitForDownloadTimeout, ^{
    return task_->IsDone();
  }));
  testing::Mock::VerifyAndClearExpectations(&task_observer_);
  EXPECT_EQ(DownloadTask::State::kCancelled, task_->GetState());
}

// Tests restarting failed download task.
TEST_F(DownloadSessionTaskImplTest, Restarting) {
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  CRWFakeNSURLSessionTask* session_task = Start();
  ASSERT_TRUE(session_task);
  testing::Mock::VerifyAndClearExpectations(&task_observer_);

  // Download has failed.
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  NSError* error = [NSError errorWithDomain:NSURLErrorDomain
                                       code:NSURLErrorNotConnectedToInternet
                                   userInfo:nil];
  SimulateDownloadCompletion(session_task, error);
  ASSERT_TRUE(WaitUntilConditionOrTimeout(kWaitForDownloadTimeout, ^{
    return task_->IsDone();
  }));
  EXPECT_EQ(100, task_->GetPercentComplete());

  // Restart the task.
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  session_task = Start();
  EXPECT_EQ(0, task_->GetPercentComplete());
  ASSERT_TRUE(session_task);
  testing::Mock::VerifyAndClearExpectations(&task_observer_);

  // Download has finished.
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  SimulateDownloadCompletion(session_task);
  testing::Mock::VerifyAndClearExpectations(&task_observer_);
  ASSERT_TRUE(WaitUntilConditionOrTimeout(kWaitForDownloadTimeout, ^{
    return task_->IsDone();
  }));
  EXPECT_EQ(DownloadTask::State::kComplete, task_->GetState());
  EXPECT_EQ(0, task_->GetErrorCode());
  EXPECT_EQ(100, task_->GetPercentComplete());
}

// Tests sucessfull download of response with only one
// URLSession:dataTask:didReceiveData: callback.
TEST_F(DownloadSessionTaskImplTest, SmallResponseDownload) {
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  CRWFakeNSURLSessionTask* session_task = Start();
  ASSERT_TRUE(session_task);
  testing::Mock::VerifyAndClearExpectations(&task_observer_);

  // The response has arrived.
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  const char kData[] = "foo";
  int64_t kDataSize = strlen(kData);
  session_task.countOfBytesExpectedToReceive = kDataSize;
  SimulateDataDownload(session_task, kData);
  testing::Mock::VerifyAndClearExpectations(&task_observer_);
  EXPECT_EQ(DownloadTask::State::kInProgress, task_->GetState());
  EXPECT_FALSE(task_->IsDone());
  EXPECT_EQ(0, task_->GetErrorCode());
  EXPECT_EQ(kDataSize, task_->GetTotalBytes());
  EXPECT_EQ(kDataSize, task_->GetReceivedBytes());
  EXPECT_EQ(100, task_->GetPercentComplete());
  EXPECT_NSEQ(@(kData), [[NSString alloc] initWithData:task_->GetResponseData()
                                              encoding:NSUTF8StringEncoding]);

  // Download has finished.
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  SimulateDownloadCompletion(session_task);
  testing::Mock::VerifyAndClearExpectations(&task_observer_);
  ASSERT_TRUE(WaitUntilConditionOrTimeout(kWaitForDownloadTimeout, ^{
    return task_->IsDone();
  }));
  EXPECT_EQ(DownloadTask::State::kComplete, task_->GetState());
  EXPECT_EQ(0, task_->GetErrorCode());
  EXPECT_EQ(kDataSize, task_->GetTotalBytes());
  EXPECT_EQ(kDataSize, task_->GetReceivedBytes());
  EXPECT_EQ(100, task_->GetPercentComplete());
  EXPECT_NSEQ(@(kData), [[NSString alloc] initWithData:task_->GetResponseData()
                                              encoding:NSUTF8StringEncoding]);
}

// Tests sucessfull download of response with multiple
// URLSession:dataTask:didReceiveData: callbacks.
TEST_F(DownloadSessionTaskImplTest, LargeResponseDownload) {
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  CRWFakeNSURLSessionTask* session_task = Start();
  ASSERT_TRUE(session_task);
  testing::Mock::VerifyAndClearExpectations(&task_observer_);

  // The first part of the response has arrived.
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  const char kData1[] = "foo";
  const char kData2[] = "buzz";
  int64_t kData1Size = strlen(kData1);
  int64_t kData2Size = strlen(kData2);
  session_task.countOfBytesExpectedToReceive = kData1Size + kData2Size;
  SimulateDataDownload(session_task, kData1);
  testing::Mock::VerifyAndClearExpectations(&task_observer_);
  EXPECT_EQ(DownloadTask::State::kInProgress, task_->GetState());
  EXPECT_FALSE(task_->IsDone());
  EXPECT_EQ(0, task_->GetErrorCode());
  EXPECT_EQ(kData1Size + kData2Size, task_->GetTotalBytes());
  EXPECT_EQ(kData1Size, task_->GetReceivedBytes());
  EXPECT_EQ(42, task_->GetPercentComplete());
  EXPECT_NSEQ(@(kData1), [[NSString alloc] initWithData:task_->GetResponseData()
                                               encoding:NSUTF8StringEncoding]);

  // The second part of the response has arrived.
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  SimulateDataDownload(session_task, kData2);
  testing::Mock::VerifyAndClearExpectations(&task_observer_);
  EXPECT_EQ(DownloadTask::State::kInProgress, task_->GetState());
  EXPECT_FALSE(task_->IsDone());
  EXPECT_EQ(0, task_->GetErrorCode());
  EXPECT_EQ(kData1Size + kData2Size, task_->GetTotalBytes());
  EXPECT_EQ(kData1Size + kData2Size, task_->GetReceivedBytes());
  EXPECT_EQ(100, task_->GetPercentComplete());
  EXPECT_NSEQ([@(kData1) stringByAppendingString:@(kData2)],
              [[NSString alloc] initWithData:task_->GetResponseData()
                                    encoding:NSUTF8StringEncoding]);

  // Download has finished.
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  SimulateDownloadCompletion(session_task);
  testing::Mock::VerifyAndClearExpectations(&task_observer_);
  ASSERT_TRUE(WaitUntilConditionOrTimeout(kWaitForDownloadTimeout, ^{
    return task_->IsDone();
  }));
  EXPECT_EQ(DownloadTask::State::kComplete, task_->GetState());
  EXPECT_EQ(0, task_->GetErrorCode());
  EXPECT_EQ(kData1Size + kData2Size, task_->GetTotalBytes());
  EXPECT_EQ(kData1Size + kData2Size, task_->GetReceivedBytes());
  EXPECT_EQ(100, task_->GetPercentComplete());
  EXPECT_NSEQ([@(kData1) stringByAppendingString:@(kData2)],
              [[NSString alloc] initWithData:task_->GetResponseData()
                                    encoding:NSUTF8StringEncoding]);
}

// Tests failed download when URLSession:dataTask:didReceiveData: callback was
// not even called.
TEST_F(DownloadSessionTaskImplTest, FailureInTheBeginning) {
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  CRWFakeNSURLSessionTask* session_task = Start();
  ASSERT_TRUE(session_task);
  testing::Mock::VerifyAndClearExpectations(&task_observer_);

  // Download has failed.
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  NSError* error = [NSError errorWithDomain:NSURLErrorDomain
                                       code:NSURLErrorNotConnectedToInternet
                                   userInfo:nil];
  SimulateDownloadCompletion(session_task, error);
  ASSERT_TRUE(WaitUntilConditionOrTimeout(kWaitForDownloadTimeout, ^{
    return task_->IsDone();
  }));
  EXPECT_EQ(DownloadTask::State::kFailed, task_->GetState());
  EXPECT_TRUE(task_->GetErrorCode() == net::ERR_INTERNET_DISCONNECTED);
  EXPECT_EQ(0, task_->GetTotalBytes());
  EXPECT_EQ(0, task_->GetReceivedBytes());
  EXPECT_EQ(100, task_->GetPercentComplete());
}

// Tests failed download when URLSession:dataTask:didReceiveData: callback was
// called once.
TEST_F(DownloadSessionTaskImplTest, FailureInTheMiddle) {
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  CRWFakeNSURLSessionTask* session_task = Start();
  ASSERT_TRUE(session_task);
  testing::Mock::VerifyAndClearExpectations(&task_observer_);

  // A part of the response has arrived.
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  const char kReceivedData[] = "foo";
  int64_t kReceivedDataSize = strlen(kReceivedData);
  int64_t kExpectedDataSize = kReceivedDataSize + 10;
  session_task.countOfBytesExpectedToReceive = kExpectedDataSize;
  SimulateDataDownload(session_task, kReceivedData);
  testing::Mock::VerifyAndClearExpectations(&task_observer_);
  EXPECT_EQ(DownloadTask::State::kInProgress, task_->GetState());
  EXPECT_FALSE(task_->IsDone());
  EXPECT_EQ(0, task_->GetErrorCode());
  EXPECT_EQ(kExpectedDataSize, task_->GetTotalBytes());
  EXPECT_EQ(kReceivedDataSize, task_->GetReceivedBytes());
  EXPECT_EQ(23, task_->GetPercentComplete());
  EXPECT_NSEQ(@(kReceivedData),
              [[NSString alloc] initWithData:task_->GetResponseData()
                                    encoding:NSUTF8StringEncoding]);

  // Download has failed.
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  NSError* error = [NSError errorWithDomain:NSURLErrorDomain
                                       code:NSURLErrorNotConnectedToInternet
                                   userInfo:nil];
  session_task.countOfBytesExpectedToReceive = 0;  // This is 0 when offline.
  SimulateDownloadCompletion(session_task, error);
  ASSERT_TRUE(WaitUntilConditionOrTimeout(kWaitForDownloadTimeout, ^{
    return task_->IsDone();
  }));
  EXPECT_EQ(DownloadTask::State::kFailed, task_->GetState());
  EXPECT_TRUE(task_->GetErrorCode() == net::ERR_INTERNET_DISCONNECTED);
  EXPECT_EQ(kExpectedDataSize, task_->GetTotalBytes());
  EXPECT_EQ(kReceivedDataSize, task_->GetReceivedBytes());
  EXPECT_EQ(100, task_->GetPercentComplete());
  EXPECT_NSEQ(@(kReceivedData),
              [[NSString alloc] initWithData:task_->GetResponseData()
                                    encoding:NSUTF8StringEncoding]);
}

// Tests that CreateSession is called with the correct cookies from the cookie
// store.
TEST_F(DownloadSessionTaskImplTest, Cookie) {
  GURL cookie_url(kUrl);
  base::Time now = base::Time::Now();
  std::unique_ptr<net::CanonicalCookie> expected_cookie =
      net::CanonicalCookie::CreateUnsafeCookieForTesting(
          "name", "value", cookie_url.host(), cookie_url.path(),
          /*creation=*/now,
          /*expire_date=*/now + base::Hours(2),
          /*last_access=*/now,
          /*last_update=*/now,
          /*secure=*/false,
          /*httponly=*/false, net::CookieSameSite::UNSPECIFIED,
          net::COOKIE_PRIORITY_DEFAULT, /*same_party=*/false);
  ASSERT_TRUE(expected_cookie);
  cookie_store()->SetAllCookies({*expected_cookie});

  // Start the download and make sure that all cookie from BrowserState were
  // picked up.
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  ASSERT_TRUE(Start());

  NSArray<NSHTTPCookie*>* cookies =
      session_configuration().HTTPCookieStorage.cookies;
  EXPECT_EQ(1U, cookies.count);
  NSHTTPCookie* actual_cookie = cookies.firstObject;
  EXPECT_NSEQ(@"name", actual_cookie.name);
  EXPECT_NSEQ(@"value", actual_cookie.value);
}

// Tests that URLFetcherFileWriter deletes the file if download has failed with
// error.
TEST_F(DownloadSessionTaskImplTest, FileDeletion) {
  // Create URLFetcherFileWriter.
  base::ScopedTempDir temp_dir;
  ASSERT_TRUE(temp_dir.CreateUniqueTempDir());
  base::FilePath temp_file = temp_dir.GetPath().AppendASCII("DownloadTaskImpl");
  base::DeleteFile(temp_file);
  ASSERT_FALSE(base::PathExists(temp_file));

  // Start the download.
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  CRWFakeNSURLSessionTask* session_task =
      Start(temp_file, web::DownloadTask::Destination::kToDisk);
  ASSERT_TRUE(session_task);

  // Deliver the response and verify that download file exists.
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  const char kReceivedData[] = "foo";
  SimulateDataDownload(session_task, kReceivedData);
  ASSERT_TRUE(base::PathExists(temp_file));

  // Fail the download and verify that the file was deleted.
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  NSError* error = [NSError errorWithDomain:NSURLErrorDomain
                                       code:NSURLErrorNotConnectedToInternet
                                   userInfo:nil];
  SimulateDownloadCompletion(session_task, error);
  ASSERT_TRUE(WaitUntilConditionOrTimeout(kWaitForDownloadTimeout, ^{
    return task_->IsDone();
  }));
  ASSERT_TRUE(WaitUntilConditionOrTimeout(kWaitForFileOperationTimeout, ^{
    base::RunLoop().RunUntilIdle();
    return !base::PathExists(temp_file);
  }));
}

// Tests changing MIME type during the download.
TEST_F(DownloadSessionTaskImplTest, MimeTypeChange) {
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  CRWFakeNSURLSessionTask* session_task = Start();
  ASSERT_TRUE(session_task);
  testing::Mock::VerifyAndClearExpectations(&task_observer_);

  ASSERT_EQ(kMimeType, task_->GetOriginalMimeType());
  ASSERT_EQ(kMimeType, task_->GetMimeType());
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  const char kOtherMimeType[] = "application/foo";
  session_task.response =
      [[NSURLResponse alloc] initWithURL:[NSURL URLWithString:@(kUrl)]
                                MIMEType:@(kOtherMimeType)
                   expectedContentLength:0
                        textEncodingName:nil];
  SimulateDownloadCompletion(session_task);
  testing::Mock::VerifyAndClearExpectations(&task_observer_);
  ASSERT_TRUE(WaitUntilConditionOrTimeout(kWaitForDownloadTimeout, ^{
    return task_->IsDone();
  }));
  EXPECT_EQ(kMimeType, task_->GetOriginalMimeType());
  EXPECT_EQ(kOtherMimeType, task_->GetMimeType());
}

// Tests updating HTTP response code.
TEST_F(DownloadSessionTaskImplTest, HttpResponseCode) {
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  CRWFakeNSURLSessionTask* session_task = Start();
  ASSERT_TRUE(session_task);
  testing::Mock::VerifyAndClearExpectations(&task_observer_);

  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  int kHttpCode = 303;
  session_task.response =
      [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@(kUrl)]
                                  statusCode:303
                                 HTTPVersion:nil
                                headerFields:nil];
  SimulateDownloadCompletion(session_task);
  testing::Mock::VerifyAndClearExpectations(&task_observer_);
  ASSERT_TRUE(WaitUntilConditionOrTimeout(kWaitForDownloadTimeout, ^{
    return task_->IsDone();
  }));
  EXPECT_EQ(kHttpCode, task_->GetHttpCode());
}

// Tests that destructing DownloadTaskImpl calls -[NSURLSessionDataTask cancel]
// and OnTaskDestroyed().
TEST_F(DownloadSessionTaskImplTest, DownloadTaskDestruction) {
  EXPECT_CALL(task_observer_, OnDownloadUpdated(task_.get()));
  CRWFakeNSURLSessionTask* session_task = Start();
  ASSERT_TRUE(session_task);
  testing::Mock::VerifyAndClearExpectations(&task_observer_);
  task_ = nullptr;  // Destruct DownloadTaskImpl.
  EXPECT_TRUE(session_task.state = NSURLSessionTaskStateCanceling);
}

}  // namespace web
