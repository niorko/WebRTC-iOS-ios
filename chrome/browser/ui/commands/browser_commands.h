// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_COMMANDS_BROWSER_COMMANDS_H_
#define IOS_CHROME_BROWSER_UI_COMMANDS_BROWSER_COMMANDS_H_

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "ios/chrome/browser/ui/commands/browser_coordinator_commands.h"
#import "ios/chrome/browser/ui/commands/lens_commands.h"
#import "ios/chrome/browser/ui/commands/new_tab_page_commands.h"
#import "ios/chrome/browser/ui/commands/page_info_commands.h"
#import "ios/chrome/browser/ui/commands/popup_menu_commands.h"
#import "ios/chrome/browser/ui/commands/qr_scanner_commands.h"
#import "ios/chrome/browser/ui/commands/snackbar_commands.h"
#import "ios/chrome/browser/ui/commands/whats_new_commands.h"

@class ReadingListAddCommand;

// Protocol for commands that will generally be handled by the "current tab",
// which in practice is the BrowserViewController instance displaying the tab.
@protocol BrowserCommands <
    NSObject,
    // TODO(crbug.com/1323764): Remove PopupMenuCommands conformance.
    PopupMenuCommands,
    // TODO(crbug.com/1323778): Remove SnackbarCommands conformance.
    SnackbarCommands>

// Closes the current tab.
// TODO(crbug.com/1272498): Refactor this command away; call sites should close
// via the WebStateList.
- (void)closeCurrentTab;

// Bookmarks the current page.
// TODO(crbug.com/1134586): Reuse BookmarksCommands' bookmark instead.
- (void)bookmarkCurrentPage;

// Adds a page to the reading list using data in `command`.
// TODO(crbug.com/1272540): Remove this command.
- (void)addToReadingList:(ReadingListAddCommand*)command;

// Preloads voice search on the current BVC.
- (void)preloadVoiceSearch;

// Closes all tabs.
- (void)closeAllTabs;

// Prepares the browser to display a popup menu.
- (void)prepareForPopupMenuPresentation:(PopupMenuCommandType)type;

// Animates the NTP fakebox to the focused position and focuses the real
// omnibox.
- (void)focusFakebox;

@end

#endif  // IOS_CHROME_BROWSER_UI_COMMANDS_BROWSER_COMMANDS_H_
