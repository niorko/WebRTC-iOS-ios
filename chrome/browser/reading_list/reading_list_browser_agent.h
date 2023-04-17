// Copyright 2023 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_READING_LIST_READING_LIST_BROWSER_AGENT_H_
#define IOS_CHROME_BROWSER_READING_LIST_READING_LIST_BROWSER_AGENT_H_

#import "base/scoped_multi_source_observation.h"
#import "base/scoped_observation.h"
#import "ios/chrome/browser/main/browser_user_data.h"
#import "ios/chrome/browser/shared/ui/util/url_with_title.h"

class Browser;
@class MDCSnackbarMessageAction;

class ReadingListBrowserAgent
    : public BrowserUserData<ReadingListBrowserAgent> {
 public:
  ~ReadingListBrowserAgent() override;

  // Not copyable or assignable.
  ReadingListBrowserAgent(const ReadingListBrowserAgent&) = delete;
  ReadingListBrowserAgent& operator=(const ReadingListBrowserAgent&) = delete;
  void AddURLsToReadingList(NSArray<URLWithTitle*>* URLs);

 private:
  friend class BrowserUserData<ReadingListBrowserAgent>;
  BROWSER_USER_DATA_KEY_DECL();

  explicit ReadingListBrowserAgent(Browser* browser);

  void AddURLToReadingListwithTitle(const GURL& URL, NSString* title);

  // Create undo action for the "added to reading list" snackbar, which enables
  // the user to remove the item(s) just added to the reading list.
  // The undo action is not a perfect restore of the previous state. E.g.
  // it will remove the item from both storages if the account storage is
  // enabled, and if the user tries to re-add an existing entry (no-op add),
  // then taps "undo", the existing entry will be removed.
  MDCSnackbarMessageAction* CreateUndoActionWithReadingListURLs(
      NSArray<URLWithTitle*>* urls);

  // Removes the given urls from the reading list.
  void RemoveURLsFromReadingList(NSArray<URLWithTitle*>* urls);

  // The browser associated with this agent.
  Browser* browser_;

  // Create weak pointers to ensure that the callback bound to the object is
  // canceled when the object is destroyed.
  base::WeakPtrFactory<ReadingListBrowserAgent> weak_ptr_factory_{this};
};

#endif  // IOS_CHROME_BROWSER_READING_LIST_READING_LIST_BROWSER_AGENT_H_
