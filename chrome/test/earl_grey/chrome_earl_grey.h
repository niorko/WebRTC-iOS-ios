// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_TEST_EARL_GREY_CHROME_EARL_GREY_H_
#define IOS_CHROME_TEST_EARL_GREY_CHROME_EARL_GREY_H_

#import <Foundation/Foundation.h>

#include <string>

#include "base/compiler_specific.h"
#import "components/content_settings/core/common/content_settings.h"
#include "components/sync/base/model_type.h"
#import "ios/testing/earl_grey/base_eg_test_helper_impl.h"
#include "url/gurl.h"

@class ElementSelector;
@protocol GREYMatcher;

namespace chrome_test_util {

// TODO(crbug.com/788813): Evaluate if JS helpers can be consolidated.
// Execute |javascript| on current web state, and wait for either the completion
// of execution or timeout. If |out_error| is not nil, it is set to the
// error resulting from the execution, if one occurs. The return value is the
// result of the JavaScript execution. If the request is timed out, then nil is
// returned.
id ExecuteJavaScript(NSString* javascript, NSError* __autoreleasing* out_error);

}  // namespace chrome_test_util

#define ChromeEarlGrey \
  [ChromeEarlGreyImpl invokedFromFile:@"" __FILE__ lineNumber:__LINE__]

// Test methods that perform actions on Chrome. These methods may read or alter
// Chrome's internal state programmatically or via the UI, but in both cases
// will properly synchronize the UI for Earl Grey tests.
@interface ChromeEarlGreyImpl : BaseEGTestHelperImpl

#pragma mark - History Utilities
// Clears browsing history. Raises an EarlGrey exception if history is not
// cleared within a timeout.
- (void)clearBrowsingHistory;

@end

// Helpers that only compile under EarlGrey 1 are included in this "EG1"
// category.
// TODO(crbug.com/922813): Update these helpers to compile under EG2 and move
// them into the main class declaration as they are converted.
@interface ChromeEarlGreyImpl (EG1)

#pragma mark - Cookie Utilities

// Returns cookies as key value pairs, where key is a cookie name and value is a
// cookie value.
// NOTE: this method fails the test if there are errors getting cookies.
- (NSDictionary*)cookies;

#pragma mark - Navigation Utilities

// Loads |URL| in the current WebState with transition type
// ui::PAGE_TRANSITION_TYPED, and waits for the loading to complete within a
// timeout, or a GREYAssert is induced.
// TODO(crbug.com/963613): Change return type to avoid when
// CHROME_EG_ASSERT_NO_ERROR is removed.
- (NSError*)loadURL:(const GURL&)URL;

// Reloads the page and waits for the loading to complete within a timeout, or a
// GREYAssert is induced.
- (NSError*)reload WARN_UNUSED_RESULT;

// Navigates back to the previous page and waits for the loading to complete
// within a timeout, or a GREYAssert is induced.
- (NSError*)goBack WARN_UNUSED_RESULT;

// Navigates forward to the next page and waits for the loading to complete
// within a timeout, or a GREYAssert is induced.
- (NSError*)goForward WARN_UNUSED_RESULT;

// Opens a new tab and waits for the new tab animation to complete.
- (NSError*)openNewTab WARN_UNUSED_RESULT;

// Opens a new incognito tab and waits for the new tab animation to complete.
- (NSError*)openNewIncognitoTab WARN_UNUSED_RESULT;

// Closes all tabs in the current mode (incognito or normal), and waits for the
// UI to complete. If current mode is Incognito, mode will be switched to
// normal after closing all tabs.
- (void)closeAllTabsInCurrentMode;

// Closes all incognito tabs and waits for the UI to complete.
- (NSError*)closeAllIncognitoTabs WARN_UNUSED_RESULT;

// Closes the current tab and waits for the UI to complete.
- (void)closeCurrentTab;

// Waits for the page to finish loading within a timeout, or a GREYAssert is
// induced.
- (NSError*)waitForPageToFinishLoading WARN_UNUSED_RESULT;

// Taps html element with |elementID| in the current web view.
- (NSError*)tapWebViewElementWithID:(NSString*)elementID WARN_UNUSED_RESULT;

// Waits for a static html view containing |text|. If the condition is not met
// within a timeout, a GREYAssert is induced.
- (NSError*)waitForStaticHTMLViewContainingText:(NSString*)text
    WARN_UNUSED_RESULT;

// Waits for there to be no static html view, or a static html view that does
// not contain |text|. If the condition is not met within a timeout, a
// GREYAssert is induced.
- (NSError*)waitForStaticHTMLViewNotContainingText:(NSString*)text
    WARN_UNUSED_RESULT;

// Waits for a Chrome error page. If it is not found within a timeout, a
// GREYAssert is induced.
- (NSError*)waitForErrorPage WARN_UNUSED_RESULT;

// Waits for the current web view to contain |text|. If the condition is not met
// within a timeout, a GREYAssert is induced.
- (NSError*)waitForWebViewContainingText:(std::string)text WARN_UNUSED_RESULT;

// Waits for the current web view to contain an element matching |selector|.
// If the condition is not met within a timeout, a GREYAssert is induced.
- (NSError*)waitForWebViewContainingElement:(ElementSelector*)selector
    WARN_UNUSED_RESULT;

// Waits for there to be no web view containing |text|. If the condition is not
// met within a timeout, a GREYAssert is induced.
- (NSError*)waitForWebViewNotContainingText:(std::string)text
    WARN_UNUSED_RESULT;

// Waits for there to be |count| number of non-incognito tabs. If the condition
// is not met within a timeout, a GREYAssert is induced.
- (NSError*)waitForMainTabCount:(NSUInteger)count WARN_UNUSED_RESULT;

// Waits for there to be |count| number of incognito tabs. If the condition is
// not met within a timeout, a GREYAssert is induced.
- (NSError*)waitForIncognitoTabCount:(NSUInteger)count WARN_UNUSED_RESULT;

// Waits for there to be a web view containing a blocked |image_id|.  When
// blocked, the image element will be smaller than the actual image size.
- (NSError*)waitForWebViewContainingBlockedImageElementWithID:
    (std::string)imageID WARN_UNUSED_RESULT;

// Waits for there to be a web view containing loaded image with |image_id|.
// When loaded, the image element will have the same size as actual image.
- (NSError*)waitForWebViewContainingLoadedImageElementWithID:
    (std::string)imageID WARN_UNUSED_RESULT;

// Waits for the bookmark internal state to be done loading. If it does not
// happen within a timeout, a GREYAssert is induced.
- (NSError*)waitForBookmarksToFinishLoading WARN_UNUSED_RESULT;

// Clears bookmarks and if any bookmark still presents. Returns nil on success,
// or else an NSError indicating why the operation failed.
- (NSError*)clearBookmarks;

// Waits for the matcher to return an element that is sufficiently visible.
- (NSError*)waitForElementWithMatcherSufficientlyVisible:
    (id<GREYMatcher>)matcher WARN_UNUSED_RESULT;

#pragma mark - Sync Utilities

// Clears fake sync server data.
- (void)clearSyncServerData;

// Starts the sync server. The server should not be running when calling this.
- (void)startSync;

// Stops the sync server. The server should be running when calling this.
- (void)stopSync;

// Waits for sync to be initialized or not. Returns nil on success, or else an
// NSError indicating why the operation failed.
- (NSError*)waitForSyncInitialized:(BOOL)isInitialized
                       syncTimeout:(NSTimeInterval)timeout WARN_UNUSED_RESULT;

// Returns the current sync cache guid. The sync server must be running when
// calling this.
- (std::string)syncCacheGUID WARN_UNUSED_RESULT;

// Verifies that |count| entities of the given |type| and |name| exist on the
// sync FakeServer. Folders are not included in this count. Returns nil on
// success, or else an NSError indicating why the operation failed.
- (NSError*)waitForSyncServerEntitiesWithType:(syncer::ModelType)type
                                         name:(const std::string&)name
                                        count:(size_t)count
                                      timeout:(NSTimeInterval)timeout
    WARN_UNUSED_RESULT;

// Clears the autofill profile for the given |GUID|.
- (void)clearAutofillProfileWithGUID:(const std::string&)GUID;

// Gets the number of entities of the given |type|.
- (int)numberOfSyncEntitiesWithType:(syncer::ModelType)type WARN_UNUSED_RESULT;

// Injects a bookmark into the fake sync server with |URL| and |title|.
- (void)injectBookmarkOnFakeSyncServerWithURL:(const std::string&)URL
                                bookmarkTitle:(const std::string&)title;

// Injects an autofill profile into the fake sync server with |GUID| and
// |full_name|.
- (void)injectAutofillProfileOnFakeSyncServerWithGUID:(const std::string&)GUID
                                  autofillProfileName:
                                      (const std::string&)fullName;

// Returns YES if there is an autofilll profile with the corresponding |GUID|
// and |full_name|.
- (BOOL)isAutofillProfilePresentWithGUID:(const std::string&)GUID
                     autofillProfileName:(const std::string&)fullName
    WARN_UNUSED_RESULT;

// Adds typed URL into HistoryService.
- (void)addTypedURL:(const GURL&)URL;

// Triggers a sync cycle for a |type|.
- (void)triggerSyncCycleForType:(syncer::ModelType)type;

// If the provided |url| is present (or not) if |expected_present|
// is YES (or NO) returns nil, otherwise an NSError indicating why the operation
// failed.
- (NSError*)waitForTypedURL:(const GURL&)URL
              expectPresent:(BOOL)expectPresent
                    timeout:(NSTimeInterval)timeout WARN_UNUSED_RESULT;

// Deletes typed URL from HistoryService.
- (void)deleteTypedURL:(const GURL&)URL;

// Injects typed URL to sync FakeServer.
- (void)injectTypedURLOnFakeSyncServer:(const std::string&)URL;

// Deletes an autofill profile from the fake sync server with |GUID|, if it
// exists. If it doesn't exist, nothing is done.
- (void)deleteAutofillProfileOnFakeSyncServerWithGUID:(const std::string&)GUID;

// Verifies the sessions hierarchy on the Sync FakeServer. |expected_urls| is
// the collection of URLs that are to be expected for a single window. Returns
// nil on success, or else an NSError indicating why the operation failed. See
// the SessionsHierarchy class for documentation regarding the verification.
- (NSError*)verifySyncServerURLs:(const std::multiset<std::string>&)URLs
    WARN_UNUSED_RESULT;

// Sets up a fake sync server to be used by the ProfileSyncService.
- (void)setUpFakeSyncServer;

// Tears down the fake sync server used by the ProfileSyncService and restores
// the real one.
- (void)tearDownFakeSyncServer;

#pragma mark - Settings Utilities

// Sets value for content setting.
- (NSError*)setContentSettings:(ContentSetting)setting WARN_UNUSED_RESULT;

#pragma mark - Sign Utilities

// Signs the user out, clears the known accounts entirely and checks whether
// the accounts were correctly removed from the keychain. Returns nil on
// success, or else an NSError indicating why the operation failed.
- (NSError*)signOutAndClearAccounts WARN_UNUSED_RESULT;

@end

#endif  // IOS_CHROME_TEST_EARL_GREY_CHROME_EARL_GREY_H_
