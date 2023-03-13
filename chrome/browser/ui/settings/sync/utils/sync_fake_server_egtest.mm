// Copyright 2016 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "base/ios/ios_util.h"
#import "base/strings/sys_string_conversions.h"
#import "base/test/ios/wait_util.h"
#import "base/time/time.h"
#import "components/sync/base/features.h"
#import "ios/chrome/browser/signin/fake_system_identity.h"
#import "ios/chrome/browser/ui/authentication/signin_earl_grey.h"
#import "ios/chrome/browser/ui/authentication/signin_earl_grey_ui_test_util.h"
#import "ios/chrome/browser/ui/bookmarks/bookmark_earl_grey.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey.h"
#import "ios/chrome/test/earl_grey/chrome_matchers.h"
#import "ios/chrome/test/earl_grey/web_http_server_chrome_test_case.h"
#import "ios/testing/earl_grey/app_launch_manager.h"
#import "ios/testing/earl_grey/earl_grey_test.h"
#import "ios/web/public/test/http_server/http_server.h"
#import "ios/web/public/test/http_server/http_server_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

// Constant for timeout while waiting for asynchronous sync operations.
constexpr base::TimeDelta kSyncOperationTimeout = base::Seconds(10);

// Waits for `entity_count` entities of type `entity_type`, and fails with
// a GREYAssert if the condition is not met, within a short period of time.
void WaitForNumberOfEntities(int entity_count, syncer::ModelType entity_type) {
  ConditionBlock condition = ^{
    return [ChromeEarlGrey numberOfSyncEntitiesWithType:entity_type] ==
           entity_count;
  };
  GREYAssert(base::test::ios::WaitUntilConditionOrTimeout(kSyncOperationTimeout,
                                                          condition),
             @"Expected %d entities of the specified type", entity_count);
}

void WaitForAutofillProfileLocallyPresent(const std::string& guid,
                                          const std::string& full_name) {
  GREYAssertTrue(base::test::ios::WaitUntilConditionOrTimeout(
                     kSyncOperationTimeout,
                     ^{
                       return [ChromeEarlGrey
                           isAutofillProfilePresentWithGUID:guid
                                        autofillProfileName:full_name];
                     }),
                 @"Expected Autofill profile to be present");
}

}  // namespace

// Hermetic sync tests, which use the fake sync server.
@interface SyncFakeServerTestCase : WebHttpServerChromeTestCase
@end

@implementation SyncFakeServerTestCase

- (void)tearDown {
  [ChromeEarlGrey waitForBookmarksToFinishLoading];
  [ChromeEarlGrey clearBookmarks];

  [ChromeEarlGrey clearSyncServerData];
  WaitForNumberOfEntities(0, syncer::AUTOFILL_PROFILE);

  [super tearDown];
}

- (void)setUp {
  [super setUp];

  [ChromeEarlGrey clearSyncServerData];

  WaitForNumberOfEntities(0, syncer::AUTOFILL_PROFILE);
  WaitForNumberOfEntities(0, syncer::BOOKMARKS);
  WaitForNumberOfEntities(0, syncer::TYPED_URLS);
}

- (AppLaunchConfiguration)appConfigurationForTestCase {
  AppLaunchConfiguration config;
  if ([self isRunningTest:@selector(testSyncInvalidationsEnabled)]) {
    config.features_enabled.push_back(syncer::kUseSyncInvalidations);
  } else if ([self isRunningTest:@selector(testSyncTypedURLUpload)] ||
             [self isRunningTest:@selector(testSyncTypedUrlDownload)] ||
             [self isRunningTest:@selector(testSyncTypedURLDeleteFromClient)] ||
             [self isRunningTest:@selector(testSyncTypedURLDeleteFromServer)]) {
    // TypedURL tests need to disable the History data type, since that one
    // replaced TypedURLs.
    config.features_disabled.push_back(syncer::kSyncEnableHistoryDataType);
  }
  return config;
}

// Tests that a bookmark added on the client (before Sync is enabled) is
// uploaded to the Sync server once Sync is turned on.
- (void)testSyncUploadBookmarkOnFirstSync {
  [BookmarkEarlGrey addBookmarkWithTitle:@"foo" URL:@"https://www.foo.com"];

  // Sign in to sync, after a bookmark has been added.
  FakeSystemIdentity* fakeIdentity = [FakeSystemIdentity fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];
  [SigninEarlGreyUI signinWithFakeIdentity:fakeIdentity];

  // Assert that the correct number of bookmarks have been synced.
  [ChromeEarlGrey waitForSyncEngineInitialized:YES
                                   syncTimeout:kSyncOperationTimeout];
  WaitForNumberOfEntities(1, syncer::BOOKMARKS);
}

// Tests that a bookmark added on the client is uploaded to the Sync server.
- (void)testSyncUploadBookmark {
  FakeSystemIdentity* fakeIdentity = [FakeSystemIdentity fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];
  [SigninEarlGreyUI signinWithFakeIdentity:fakeIdentity];

  // Add a bookmark after sync is initialized.
  [ChromeEarlGrey waitForSyncEngineInitialized:YES
                                   syncTimeout:kSyncOperationTimeout];
  [BookmarkEarlGrey addBookmarkWithTitle:@"goo" URL:@"https://www.goo.com"];
  WaitForNumberOfEntities(1, syncer::BOOKMARKS);
}

// Tests that a bookmark injected in the FakeServer is synced down to the
// client.
- (void)testSyncDownloadBookmark {
  [BookmarkEarlGrey verifyBookmarksWithTitle:@"hoo" expectedCount:0];
  const GURL URL = web::test::HttpServer::MakeUrl("http://www.hoo.com");
  [ChromeEarlGrey addFakeSyncServerBookmarkWithURL:URL title:"hoo"];

  // Sign in to sync, after a bookmark has been injected in the sync server.
  FakeSystemIdentity* fakeIdentity = [FakeSystemIdentity fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];
  [SigninEarlGreyUI signinWithFakeIdentity:fakeIdentity];

  [ChromeEarlGrey waitForSyncEngineInitialized:YES
                                   syncTimeout:kSyncOperationTimeout];
  WaitForNumberOfEntities(1, syncer::BOOKMARKS);
  [BookmarkEarlGrey verifyBookmarksWithTitle:@"hoo" expectedCount:1];
}

// Tests that the local cache guid does not change when sync is restarted.
- (void)testSyncCheckSameCacheGuid_SyncRestarted {
  // Sign in the fake identity.
  FakeSystemIdentity* fakeIdentity = [FakeSystemIdentity fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];
  [SigninEarlGreyUI signinWithFakeIdentity:fakeIdentity];
  [ChromeEarlGrey
      waitForSyncTransportStateActiveWithTimeout:kSyncOperationTimeout];

  // Store the original guid, then restart sync.
  std::string original_guid = [ChromeEarlGrey syncCacheGUID];
  [ChromeEarlGrey stopSync];
  [ChromeEarlGrey waitForSyncEngineInitialized:NO
                                   syncTimeout:kSyncOperationTimeout];
  [ChromeEarlGrey startSync];

  // Verify the guid did not change.
  [ChromeEarlGrey
      waitForSyncTransportStateActiveWithTimeout:kSyncOperationTimeout];
  GREYAssertEqual([ChromeEarlGrey syncCacheGUID], original_guid,
                  @"Stored guid doesn't match current value");
}

// Tests that the local cache guid changes when the user signs out and then
// signs back in with the same account.
- (void)testSyncCheckDifferentCacheGuid_SignOutAndSignIn {
  // Sign in a fake identity, and store the initial sync guid.
  FakeSystemIdentity* fakeIdentity = [FakeSystemIdentity fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];
  [SigninEarlGreyUI signinWithFakeIdentity:fakeIdentity];
  [ChromeEarlGrey
      waitForSyncTransportStateActiveWithTimeout:kSyncOperationTimeout];
  std::string original_guid = [ChromeEarlGrey syncCacheGUID];

  [SigninEarlGrey verifySignedInWithFakeIdentity:fakeIdentity];
  [SigninEarlGrey signOut];
  [ChromeEarlGrey waitForSyncEngineInitialized:NO
                                   syncTimeout:kSyncOperationTimeout];

  // Sign the user back in, and verify the guid has changed.
  [SigninEarlGreyUI signinWithFakeIdentity:fakeIdentity];
  [ChromeEarlGrey
      waitForSyncTransportStateActiveWithTimeout:kSyncOperationTimeout];
  GREYAssertTrue(
      [ChromeEarlGrey syncCacheGUID] != original_guid,
      @"guid didn't change after user signed out and signed back in");
}

// Tests that the local cache guid does not change when sync is restarted, if
// a user previously signed out and back in.
// Test for http://crbug.com/413611 .
- (void)testSyncCheckSameCacheGuid_SyncRestartedAfterSignOutAndSignIn {
  // Sign in a fake idenitty.
  FakeSystemIdentity* fakeIdentity = [FakeSystemIdentity fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];
  [SigninEarlGreyUI signinWithFakeIdentity:fakeIdentity];
  [ChromeEarlGrey
      waitForSyncTransportStateActiveWithTimeout:kSyncOperationTimeout];

  [SigninEarlGrey verifySignedInWithFakeIdentity:fakeIdentity];
  [SigninEarlGrey signOut];
  [ChromeEarlGrey waitForSyncEngineInitialized:NO
                                   syncTimeout:kSyncOperationTimeout];

  // Sign the user back in.
  [SigninEarlGreyUI signinWithFakeIdentity:fakeIdentity];
  [ChromeEarlGrey
      waitForSyncTransportStateActiveWithTimeout:kSyncOperationTimeout];

  // Record the initial guid, before restarting sync.
  std::string original_guid = [ChromeEarlGrey syncCacheGUID];
  [ChromeEarlGrey stopSync];
  [ChromeEarlGrey waitForSyncEngineInitialized:NO
                                   syncTimeout:kSyncOperationTimeout];
  [ChromeEarlGrey startSync];

  // Verify the guid did not change after restarting sync.
  [ChromeEarlGrey
      waitForSyncTransportStateActiveWithTimeout:kSyncOperationTimeout];
  GREYAssertEqual([ChromeEarlGrey syncCacheGUID], original_guid,
                  @"Stored guid doesn't match current value");
}

// Tests that autofill profile injected in FakeServer gets synced to client.
- (void)testSyncDownloadAutofillProfile {
  const std::string kGuid = "2340E83B-5BEE-4560-8F95-5914EF7F539E";
  const std::string kFullName = "Peter Pan";
  GREYAssertFalse([ChromeEarlGrey isAutofillProfilePresentWithGUID:kGuid
                                               autofillProfileName:kFullName],
                  @"autofill profile should not exist");
  [ChromeEarlGrey addAutofillProfileToFakeSyncServerWithGUID:kGuid
                                         autofillProfileName:kFullName];
  [self setTearDownHandler:^{
    [ChromeEarlGrey clearAutofillProfileWithGUID:kGuid];
  }];

  // Sign in to sync.
  FakeSystemIdentity* fakeIdentity = [FakeSystemIdentity fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];
  [SigninEarlGreyUI signinWithFakeIdentity:fakeIdentity];

  // Verify that the autofill profile has been downloaded.
  [ChromeEarlGrey waitForSyncEngineInitialized:YES
                                   syncTimeout:kSyncOperationTimeout];
  WaitForAutofillProfileLocallyPresent(kGuid, kFullName);
}

// Test that update to autofill profile injected in FakeServer gets synced to
// client.
- (void)testSyncUpdateAutofillProfile {
  const std::string kGuid = "2340E83B-5BEE-4560-8F95-5914EF7F539E";
  const std::string kFullName = "Peter Pan";
  const std::string kUpdatedFullName = "Roger Rabbit";
  GREYAssertFalse([ChromeEarlGrey isAutofillProfilePresentWithGUID:kGuid
                                               autofillProfileName:kFullName],
                  @"autofill profile should not exist");

  [ChromeEarlGrey addAutofillProfileToFakeSyncServerWithGUID:kGuid
                                         autofillProfileName:kFullName];
  [self setTearDownHandler:^{
    [ChromeEarlGrey clearAutofillProfileWithGUID:kGuid];
  }];

  // Sign in to sync.
  FakeSystemIdentity* fakeIdentity = [FakeSystemIdentity fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];
  [SigninEarlGreyUI signinWithFakeIdentity:fakeIdentity];

  // Verify that the autofill profile has been downloaded.
  [ChromeEarlGrey waitForSyncEngineInitialized:YES
                                   syncTimeout:kSyncOperationTimeout];
  WaitForAutofillProfileLocallyPresent(kGuid, kFullName);

  // Update autofill profile.
  [ChromeEarlGrey addAutofillProfileToFakeSyncServerWithGUID:kGuid
                                         autofillProfileName:kUpdatedFullName];

  // Trigger sync cycle and wait for update.
  [ChromeEarlGrey triggerSyncCycleForType:syncer::AUTOFILL_PROFILE];
  WaitForAutofillProfileLocallyPresent(kGuid, kUpdatedFullName);
}

// Test that autofill profile deleted from FakeServer gets deleted from client
// as well.
- (void)testSyncDeleteAutofillProfile {
  const std::string kGuid = "2340E83B-5BEE-4560-8F95-5914EF7F539E";
  const std::string kFullName = "Peter Pan";
  GREYAssertFalse([ChromeEarlGrey isAutofillProfilePresentWithGUID:kGuid
                                               autofillProfileName:kFullName],
                  @"autofill profile should not exist");
  [ChromeEarlGrey addAutofillProfileToFakeSyncServerWithGUID:kGuid
                                         autofillProfileName:kFullName];
  [self setTearDownHandler:^{
    [ChromeEarlGrey clearAutofillProfileWithGUID:kGuid];
  }];

  // Sign in to sync.
  FakeSystemIdentity* fakeIdentity = [FakeSystemIdentity fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];
  [SigninEarlGreyUI signinWithFakeIdentity:fakeIdentity];

  // Verify that the autofill profile has been downloaded
  [ChromeEarlGrey waitForSyncEngineInitialized:YES
                                   syncTimeout:kSyncOperationTimeout];
  WaitForAutofillProfileLocallyPresent(kGuid, kFullName);

  // Delete autofill profile from server, and verify it is removed.
  [ChromeEarlGrey deleteAutofillProfileFromFakeSyncServerWithGUID:kGuid];
  [ChromeEarlGrey triggerSyncCycleForType:syncer::AUTOFILL_PROFILE];
  ConditionBlock condition = ^{
    return ![ChromeEarlGrey isAutofillProfilePresentWithGUID:kGuid
                                         autofillProfileName:kFullName];
  };
  GREYAssert(base::test::ios::WaitUntilConditionOrTimeout(kSyncOperationTimeout,
                                                          condition),
             @"Autofill profile was not deleted.");
}

// Tests that tabs opened on this client are committed to the Sync server and
// that the created sessions entities are correct.
- (void)testSyncUploadOpenTabs {
  // Create map of canned responses and set up the test HTML server.
  const GURL URL1 = web::test::HttpServer::MakeUrl("http://page1");
  const GURL URL2 = web::test::HttpServer::MakeUrl("http://page2");
  std::map<GURL, std::string> responses = {
      {URL1, std::string("page 1")},
      {URL2, std::string("page 2")},
  };
  web::test::SetUpSimpleHttpServer(responses);

  // Load both URLs in separate tabs.
  [ChromeEarlGrey loadURL:URL1];
  [ChromeEarlGrey openNewTab];
  [ChromeEarlGrey loadURL:URL2];

  // Sign in to sync, after opening two tabs.
  FakeSystemIdentity* fakeIdentity = [FakeSystemIdentity fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];
  [SigninEarlGreyUI signinWithFakeIdentity:fakeIdentity];

  // Verify the sessions on the sync server.
  [ChromeEarlGrey waitForSyncEngineInitialized:YES
                                   syncTimeout:kSyncOperationTimeout];
  WaitForNumberOfEntities(3, syncer::SESSIONS);

  NSArray<NSString*>* specs = @[
    base::SysUTF8ToNSString(URL1.spec()),
    base::SysUTF8ToNSString(URL2.spec()),
  ];
  [ChromeEarlGrey verifySyncServerSessionURLs:specs];
}

// Tests that a typed URL (after Sync is enabled) is uploaded to the Sync
// server.
- (void)testSyncTypedURLUpload {
  const GURL mockURL("http://not-a-real-site/");

  [ChromeEarlGrey clearBrowsingHistory];
  [self setTearDownHandler:^{
    [ChromeEarlGrey clearBrowsingHistory];
  }];
  [ChromeEarlGrey addHistoryServiceTypedURL:mockURL];

  // Sign in to sync.
  FakeSystemIdentity* fakeIdentity = [FakeSystemIdentity fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];
  [SigninEarlGreyUI signinWithFakeIdentity:fakeIdentity];

  [ChromeEarlGrey waitForSyncEngineInitialized:YES
                                   syncTimeout:kSyncOperationTimeout];

  // Trigger sync and verify the typed URL is on the fake sync server.
  [ChromeEarlGrey triggerSyncCycleForType:syncer::TYPED_URLS];
  [ChromeEarlGrey waitForSyncServerEntitiesWithType:syncer::TYPED_URLS
                                               name:mockURL.spec()
                                              count:1
                                            timeout:kSyncOperationTimeout];
}

// Tests that typed url is downloaded from sync server.
- (void)testSyncTypedUrlDownload {
  const GURL mockURL("http://not-a-real-site/");

  [ChromeEarlGrey clearBrowsingHistory];
  [self setTearDownHandler:^{
    [ChromeEarlGrey clearBrowsingHistory];
  }];

  // Inject typed url on server.
  [ChromeEarlGrey addFakeSyncServerTypedURL:mockURL];

  // Sign in to sync.
  FakeSystemIdentity* fakeIdentity = [FakeSystemIdentity fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];
  [SigninEarlGreyUI signinWithFakeIdentity:fakeIdentity];

  [ChromeEarlGrey waitForSyncEngineInitialized:YES
                                   syncTimeout:kSyncOperationTimeout];

  // Wait for typed url to appear on client.
  [ChromeEarlGrey waitForTypedURL:mockURL
                    expectPresent:YES
                          timeout:kSyncOperationTimeout];
}

// Tests that when typed url is deleted on the client, sync the change gets
// propagated to server.
- (void)testSyncTypedURLDeleteFromClient {
  const GURL mockURL("http://not-a-real-site/");

  [ChromeEarlGrey clearBrowsingHistory];
  [self setTearDownHandler:^{
    [ChromeEarlGrey clearBrowsingHistory];
  }];

  // Inject typed url on server.
  [ChromeEarlGrey addFakeSyncServerTypedURL:mockURL];

  // Sign in to sync.
  FakeSystemIdentity* fakeIdentity = [FakeSystemIdentity fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];
  [SigninEarlGreyUI signinWithFakeIdentity:fakeIdentity];

  [ChromeEarlGrey waitForSyncEngineInitialized:YES
                                   syncTimeout:kSyncOperationTimeout];

  // Wait for typed url to appear on client.
  [ChromeEarlGrey waitForTypedURL:mockURL
                    expectPresent:YES
                          timeout:kSyncOperationTimeout];
  GREYAssert(
      [ChromeEarlGrey numberOfSyncEntitiesWithType:syncer::TYPED_URLS] == 1,
      @"There should be 1 typed URL entity");

  // Delete typed URL from client.
  [ChromeEarlGrey deleteHistoryServiceTypedURL:mockURL];

  // Trigger sync and wait for typed URL to be deleted.
  [ChromeEarlGrey triggerSyncCycleForType:syncer::TYPED_URLS];
  WaitForNumberOfEntities(0, syncer::TYPED_URLS);
}

// Test that typed url is deleted from client after server sends tombstone for
// that typed url.
- (void)testSyncTypedURLDeleteFromServer {
  const GURL mockURL("http://not-a-real-site/");

  [ChromeEarlGrey clearBrowsingHistory];
  [self setTearDownHandler:^{
    [ChromeEarlGrey clearBrowsingHistory];
  }];
  [ChromeEarlGrey addHistoryServiceTypedURL:mockURL];

  // Sign in to sync.
  FakeSystemIdentity* fakeIdentity = [FakeSystemIdentity fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];
  [SigninEarlGreyUI signinWithFakeIdentity:fakeIdentity];

  [ChromeEarlGrey waitForSyncEngineInitialized:YES
                                   syncTimeout:kSyncOperationTimeout];
  [ChromeEarlGrey triggerSyncCycleForType:syncer::TYPED_URLS];

  [ChromeEarlGrey waitForSyncServerEntitiesWithType:syncer::TYPED_URLS
                                               name:mockURL.spec()
                                              count:1
                                            timeout:kSyncOperationTimeout];
  [ChromeEarlGrey deleteHistoryServiceTypedURL:mockURL];

  // Trigger sync and wait for fake server to be updated.
  [ChromeEarlGrey triggerSyncCycleForType:syncer::TYPED_URLS];
  [ChromeEarlGrey waitForTypedURL:mockURL
                    expectPresent:NO
                          timeout:kSyncOperationTimeout];
}

// Tests download of two legacy bookmarks with the same item id.
// TODO(crbug.com/1423865): The test is flaky on all devices.
- (void)FLAKY_testDownloadTwoPre2015BookmarksWithSameItemId {
  const GURL URL1 = web::test::HttpServer::MakeUrl("http://page1.com");
  const GURL URL2 = web::test::HttpServer::MakeUrl("http://page2.com");
  NSString* title1 = @"title1";
  NSString* title2 = @"title2";

  [BookmarkEarlGrey verifyBookmarksWithTitle:title1 expectedCount:0];
  [BookmarkEarlGrey verifyBookmarksWithTitle:title2 expectedCount:0];

  // Mimic the creation of two bookmarks from two different devices, with the
  // same client item ID.
  [ChromeEarlGrey
      addFakeSyncServerLegacyBookmarkWithURL:URL1
                                       title:base::SysNSStringToUTF8(title1)
                   originator_client_item_id:"1"];
  [ChromeEarlGrey
      addFakeSyncServerLegacyBookmarkWithURL:URL2
                                       title:base::SysNSStringToUTF8(title2)
                   originator_client_item_id:"1"];

  // Sign in to sync.
  FakeSystemIdentity* fakeIdentity = [FakeSystemIdentity fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];
  [SigninEarlGreyUI signinWithFakeIdentity:fakeIdentity];

  [ChromeEarlGrey waitForSyncEngineInitialized:YES
                                   syncTimeout:kSyncOperationTimeout];
  WaitForNumberOfEntities(2, syncer::BOOKMARKS);

  [BookmarkEarlGrey verifyBookmarksWithTitle:title1 expectedCount:1];
  [BookmarkEarlGrey verifyBookmarksWithTitle:title2 expectedCount:1];
}

- (void)testSyncInvalidationsEnabled {
  // Sign in to sync.
  FakeSystemIdentity* fakeIdentity = [FakeSystemIdentity fakeIdentity1];
  [SigninEarlGrey addFakeIdentity:fakeIdentity];
  [SigninEarlGreyUI signinWithFakeIdentity:fakeIdentity];

  [ChromeEarlGrey waitForSyncEngineInitialized:YES
                                   syncTimeout:kSyncOperationTimeout];
  WaitForNumberOfEntities(1, syncer::DEVICE_INFO);
  [ChromeEarlGrey waitForSyncInvalidationFields];
}

@end
