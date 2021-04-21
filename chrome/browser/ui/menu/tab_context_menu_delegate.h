// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_MENU_TAB_CONTEXT_MENU_DELEGATE_H_
#define IOS_CHROME_BROWSER_UI_MENU_TAB_CONTEXT_MENU_DELEGATE_H_

#import <Foundation/Foundation.h>

class GURL;

namespace synced_sessions {
class DistantSession;
}

// Methods used to create context menu actions for tabs.
@protocol TabContextMenuDelegate

// Tells the delegate to trigger the URL sharing flow for the given |URL| and
// |title|, with the origin |view| representing the UI component for that URL.
// TODO(crbug.com/1196956): Investigate removing |view| as a parameter.
- (void)shareURL:(const GURL&)URL title:(NSString*)title fromView:(UIView*)view;

// Tells the delegate to remove Sessions corresponding to the given the table
// view's |sectionIdentifier|.
- (void)removeSessionAtTableSectionWithIdentifier:(NSInteger)sectionIdentifier;

// Asks the delegate for the Session corresponding to the given the table view's
// |sectionIdentifier|.
- (synced_sessions::DistantSession const*)sessionForTableSectionWithIdentifier:
    (NSInteger)sectionIdentifier;

@end

#endif  // IOS_CHROME_BROWSER_UI_MENU_TAB_CONTEXT_MENU_DELEGATE_H_
