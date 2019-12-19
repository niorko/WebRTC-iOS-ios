// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/bookmarks/bookmark_earl_grey_app_interface.h"

#include "base/strings/sys_string_conversions.h"
#import "base/test/ios/wait_util.h"
#include "components/bookmarks/browser/bookmark_model.h"
#include "components/bookmarks/browser/titled_url_match.h"
#include "components/prefs/pref_service.h"
#include "ios/chrome/browser/bookmarks/bookmark_model_factory.h"
#include "ios/chrome/browser/browser_state/chrome_browser_state.h"
#include "ios/chrome/browser/pref_names.h"
#import "ios/chrome/browser/ui/bookmarks/bookmark_path_cache.h"
#import "ios/chrome/browser/ui/bookmarks/bookmark_utils_ios.h"
#import "ios/chrome/test/app/chrome_test_util.h"
#import "ios/public/provider/chrome/browser/signin/fake_chrome_identity.h"
#import "ios/public/provider/chrome/browser/signin/fake_chrome_identity_service.h"
#import "ios/testing/nserror_util.h"
#include "ui/base/models/tree_node_iterator.h"
#include "url/gurl.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@implementation BookmarkEarlGreyAppInterface

#pragma mark - Public Interface

+ (void)clearBookmarksPositionCache {
  ios::ChromeBrowserState* browser_state =
      chrome_test_util::GetOriginalBrowserState();
  [BookmarkPathCache
      clearBookmarkTopMostRowCacheWithPrefService:browser_state->GetPrefs()];
}

+ (NSError*)setupStandardBookmarksUsingFirstURL:(NSString*)firstURL
                                      secondURL:(NSString*)secondURL
                                       thirdURL:(NSString*)thirdURL
                                      fourthURL:(NSString*)fourthURL {
  if (![BookmarkEarlGreyAppInterface waitForBookmarkModelLoaded:YES])
    return testing::NSErrorWithLocalizedDescription(
        @"Bookmark model was not loaded");

  bookmarks::BookmarkModel* bookmark_model =
      [BookmarkEarlGreyAppInterface bookmarkModel];

  NSString* firstTitle = @"First URL";
  const GURL firstGURL = GURL(base::SysNSStringToUTF8(firstURL));
  bookmark_model->AddURL(bookmark_model->mobile_node(), 0,
                         base::SysNSStringToUTF16(firstTitle), firstGURL);

  NSString* secondTitle = @"Second URL";
  const GURL secondGURL = GURL(base::SysNSStringToUTF8(secondURL));
  bookmark_model->AddURL(bookmark_model->mobile_node(), 0,
                         base::SysNSStringToUTF16(secondTitle), secondGURL);

  NSString* frenchTitle = @"French URL";
  const GURL thirdGURL = GURL(base::SysNSStringToUTF8(thirdURL));
  bookmark_model->AddURL(bookmark_model->mobile_node(), 0,
                         base::SysNSStringToUTF16(frenchTitle), thirdGURL);

  NSString* folderTitle = @"Folder 1";
  const bookmarks::BookmarkNode* folder1 = bookmark_model->AddFolder(
      bookmark_model->mobile_node(), 0, base::SysNSStringToUTF16(folderTitle));
  folderTitle = @"Folder 1.1";
  bookmark_model->AddFolder(bookmark_model->mobile_node(), 0,
                            base::SysNSStringToUTF16(folderTitle));

  folderTitle = @"Folder 2";
  const bookmarks::BookmarkNode* folder2 = bookmark_model->AddFolder(
      folder1, 0, base::SysNSStringToUTF16(folderTitle));

  folderTitle = @"Folder 3";
  const bookmarks::BookmarkNode* folder3 = bookmark_model->AddFolder(
      folder2, 0, base::SysNSStringToUTF16(folderTitle));

  NSString* thirdTitle = @"Third URL";
  const GURL fourthGURL = GURL(base::SysNSStringToUTF8(fourthURL));
  bookmark_model->AddURL(folder3, 0, base::SysNSStringToUTF16(thirdTitle),
                         fourthGURL);
  return nil;
}

+ (NSError*)setupBookmarksWhichExceedsScreenHeightUsingURL:(NSString*)URL {
  if (![BookmarkEarlGreyAppInterface waitForBookmarkModelLoaded:YES])
    return testing::NSErrorWithLocalizedDescription(
        @"Bookmark model was not loaded");

  bookmarks::BookmarkModel* bookmark_model =
      [BookmarkEarlGreyAppInterface bookmarkModel];

  const GURL dummyURL = GURL(base::SysNSStringToUTF8(URL));
  bookmark_model->AddURL(bookmark_model->mobile_node(), 0,
                         base::SysNSStringToUTF16(@"Bottom URL"), dummyURL);

  NSString* dummyTitle = @"Dummy URL";
  for (int i = 0; i < 20; i++) {
    bookmark_model->AddURL(bookmark_model->mobile_node(), 0,
                           base::SysNSStringToUTF16(dummyTitle), dummyURL);
  }
  NSString* folderTitle = @"Folder 1";
  const bookmarks::BookmarkNode* folder1 = bookmark_model->AddFolder(
      bookmark_model->mobile_node(), 0, base::SysNSStringToUTF16(folderTitle));
  bookmark_model->AddURL(bookmark_model->mobile_node(), 0,
                         base::SysNSStringToUTF16(@"Top URL"), dummyURL);

  // Add URLs to Folder 1.
  bookmark_model->AddURL(folder1, 0, base::SysNSStringToUTF16(dummyTitle),
                         dummyURL);
  bookmark_model->AddURL(folder1, 0, base::SysNSStringToUTF16(@"Bottom 1"),
                         dummyURL);
  for (int i = 0; i < 20; i++) {
    bookmark_model->AddURL(folder1, 0, base::SysNSStringToUTF16(dummyTitle),
                           dummyURL);
  }
  return nil;
}

+ (BOOL)waitForBookmarkModelLoaded:(BOOL)loaded {
  bookmarks::BookmarkModel* bookmarkModel =
      [BookmarkEarlGreyAppInterface bookmarkModel];

  return base::test::ios::WaitUntilConditionOrTimeout(
      base::test::ios::kWaitForUIElementTimeout, ^{
        return bookmarkModel->loaded() == loaded;
      });
}

+ (NSError*)verifyBookmarksWithTitle:(NSString*)title
                       expectedCount:(NSUInteger)expectedCount {
  // Get BookmarkModel and wait for it to be loaded.
  bookmarks::BookmarkModel* bookmarkModel =
      [BookmarkEarlGreyAppInterface bookmarkModel];

  // Verify the correct number of bookmarks exist.
  base::string16 matchString = base::SysNSStringToUTF16(title);
  std::vector<bookmarks::TitledUrlMatch> matches;
  int const kMaxCountOfBoomarks = 50;
  bookmarkModel->GetBookmarksMatching(matchString, kMaxCountOfBoomarks,
                                      &matches);
  if (matches.size() != expectedCount)
    return testing::NSErrorWithLocalizedDescription(
        @"Unexpected number of bookmarks");

  return nil;
}

+ (NSError*)removeBookmarkWithTitle:(NSString*)title {
  base::string16 name16(base::SysNSStringToUTF16(title));
  bookmarks::BookmarkModel* bookmarkModel =
      [BookmarkEarlGreyAppInterface bookmarkModel];
  ui::TreeNodeIterator<const bookmarks::BookmarkNode> iterator(
      bookmarkModel->root_node());
  while (iterator.has_next()) {
    const bookmarks::BookmarkNode* bookmark = iterator.Next();
    if (bookmark->GetTitle() == name16) {
      bookmarkModel->Remove(bookmark);
      return nil;
    }
  }
  return testing::NSErrorWithLocalizedDescription([NSString
      stringWithFormat:@"Could not remove bookmark with name %@", title]);
}

+ (NSError*)moveBookmarkWithTitle:(NSString*)bookmarkTitle
                toFolderWithTitle:(NSString*)newFolder {
  base::string16 name16(base::SysNSStringToUTF16(bookmarkTitle));
  bookmarks::BookmarkModel* bookmarkModel =
      [BookmarkEarlGreyAppInterface bookmarkModel];
  ui::TreeNodeIterator<const bookmarks::BookmarkNode> iterator(
      bookmarkModel->root_node());
  const bookmarks::BookmarkNode* bookmark = iterator.Next();
  while (iterator.has_next()) {
    if (bookmark->GetTitle() == name16) {
      break;
    }
    bookmark = iterator.Next();
  }

  base::string16 folderName16(base::SysNSStringToUTF16(newFolder));
  ui::TreeNodeIterator<const bookmarks::BookmarkNode> iteratorFolder(
      bookmarkModel->root_node());
  const bookmarks::BookmarkNode* folder = iteratorFolder.Next();
  while (iteratorFolder.has_next()) {
    if (folder->GetTitle() == folderName16) {
      break;
    }
    folder = iteratorFolder.Next();
  }
  std::set<const bookmarks::BookmarkNode*> toMove;
  toMove.insert(bookmark);
  if (!bookmark_utils_ios::MoveBookmarks(toMove, bookmarkModel, folder)) {
    return testing::NSErrorWithLocalizedDescription(
        [NSString stringWithFormat:@"Could not move bookmark with name %@",
                                   bookmarkTitle]);
  }

  return nil;
}

+ (NSError*)verifyChildCount:(size_t)count inFolderWithName:(NSString*)name {
  base::string16 name16(base::SysNSStringToUTF16(name));
  bookmarks::BookmarkModel* bookmarkModel =
      [BookmarkEarlGreyAppInterface bookmarkModel];

  ui::TreeNodeIterator<const bookmarks::BookmarkNode> iterator(
      bookmarkModel->root_node());

  const bookmarks::BookmarkNode* folder = nullptr;
  while (iterator.has_next()) {
    const bookmarks::BookmarkNode* bookmark = iterator.Next();
    if (bookmark->is_folder() && bookmark->GetTitle() == name16) {
      folder = bookmark;
      break;
    }
  }
  if (!folder)
    return testing::NSErrorWithLocalizedDescription(
        [NSString stringWithFormat:@"No folder named %@", name]);

  if (folder->children().size() != count)
    return testing::NSErrorWithLocalizedDescription(
        [NSString stringWithFormat:
                      @"Unexpected number of children in folder '%@': %" PRIuS
                       " instead of %" PRIuS,
                      name, folder->children().size(), count]);

  return nil;
}

+ (NSError*)verifyExistenceOfBookmarkWithURL:(NSString*)URL
                                        name:(NSString*)name {
  const bookmarks::BookmarkNode* bookmark =
      [self bookmarkModel] -> GetMostRecentlyAddedUserNodeForURL(
                               GURL(base::SysNSStringToUTF16(URL)));
  if (bookmark->GetTitle().compare(base::SysNSStringToUTF16(name)) != 0) {
    return testing::NSErrorWithLocalizedDescription(
        [NSString stringWithFormat:@"Could not find bookmark named %@ for %@",
                                   name, URL]);
  }

  return nil;
}

+ (NSError*)verifyAbsenceOfBookmarkWithURL:(NSString*)URL {
  const bookmarks::BookmarkNode* bookmark =
      [self bookmarkModel] -> GetMostRecentlyAddedUserNodeForURL(
                               GURL(base::SysNSStringToUTF16(URL)));
  if (bookmark) {
    return testing::NSErrorWithLocalizedDescription(
        [NSString stringWithFormat:@"There is a bookmark for %@", URL]);
  }

  return nil;
}

+ (NSError*)verifyPromoAlreadySeen:(BOOL)seen {
  ios::ChromeBrowserState* browserState =
      chrome_test_util::GetOriginalBrowserState();
  PrefService* prefs = browserState->GetPrefs();
  if (prefs->GetBoolean(prefs::kIosBookmarkPromoAlreadySeen) == seen) {
    return nil;
  }
  NSString* errorDescription =
      seen ? @"Expected promo already seen, but it wasn't."
           : @"Expected promo not already seen, but it was.";
  return testing::NSErrorWithLocalizedDescription(errorDescription);
}

+ (void)setPromoAlreadySeen:(BOOL)seen {
  PrefService* prefs = chrome_test_util::GetOriginalBrowserState()->GetPrefs();
  prefs->SetBoolean(prefs::kIosBookmarkPromoAlreadySeen, seen);
}

+ (void)setPromoAlreadySeenNumberOfTimes:(int)times {
  PrefService* prefs = chrome_test_util::GetOriginalBrowserState()->GetPrefs();
  prefs->SetInteger(prefs::kIosBookmarkSigninPromoDisplayedCount, times);
}

+ (int)numberOfTimesPromoAlreadySeen {
  PrefService* prefs = chrome_test_util::GetOriginalBrowserState()->GetPrefs();
  return prefs->GetInteger(prefs::kIosBookmarkSigninPromoDisplayedCount);
}

+ (NSString*)setupFakeIdentity {
  FakeChromeIdentity* identity =
      [FakeChromeIdentity identityWithEmail:@"foo1@gmail.com"
                                     gaiaID:@"foo1ID"
                                       name:@"Fake Foo 1"];
  ios::FakeChromeIdentityService::GetInstanceFromChromeProvider()->AddIdentity(
      identity);
  return identity.userEmail;
}

#pragma mark - Helpers

+ (bookmarks::BookmarkModel*)bookmarkModel {
  return ios::BookmarkModelFactory::GetForBrowserState(
      chrome_test_util::GetOriginalBrowserState());
}

@end
