// Copyright 2023 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_BOOKMARKS_FOLDER_CHOOSER_BOOKMARKS_FOLDER_CHOOSER_MEDIATOR_H_
#define IOS_CHROME_BROWSER_UI_BOOKMARKS_FOLDER_CHOOSER_BOOKMARKS_FOLDER_CHOOSER_MEDIATOR_H_

#import "ios/chrome/browser/ui/bookmarks/folder_chooser/bookmarks_folder_chooser_consumer.h"
#import "ios/chrome/browser/ui/bookmarks/folder_chooser/bookmarks_folder_chooser_mutator.h"

#import <Foundation/Foundation.h>
#import <set>

namespace bookmarks {
class BookmarkModel;
class BookmarkNode;
}  // namespace bookmarks

// A mediator class to encapsulate BookmarkModel from the view controller.
@interface BookmarksFolderChooserMediator
    : NSObject <BookmarksFolderChooserDataSource, BookmarksFolderChooserMutator>

// Consumer to reflect model changes in the UI.
@property(nonatomic, weak) id<BookmarksFolderChooserConsumer> consumer;
// The currently selected folder.
@property(nonatomic, assign) const bookmarks::BookmarkNode* selectedFolder;

// Initialize the mediator with a bookmark model.
// `bookmarkModel` must not be `nullptr` and must be loaded.
// `editedNodes` are the list of nodes to hide when displaying folders. This is
// to avoid to move a folder inside a child folder. These are also the list of
// nodes that are being edited (moved to a folder).
- (instancetype)initWithBookmarkModel:(bookmarks::BookmarkModel*)model
                          editedNodes:
                              (std::set<const bookmarks::BookmarkNode*>*)nodes
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

#endif  // IOS_CHROME_BROWSER_UI_BOOKMARKS_FOLDER_CHOOSER_BOOKMARKS_FOLDER_CHOOSER_MEDIATOR_H_
