// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_FOLLOW_FIRST_FOLLOW_COORDINATOR_H_
#define IOS_CHROME_BROWSER_UI_FOLLOW_FIRST_FOLLOW_COORDINATOR_H_

#import <Foundation/Foundation.h>

#import "ios/chrome/browser/ui/coordinators/chrome_coordinator.h"

// Coordinator for the First Follow feature. This feature informs the user about
// the feed and following channels after the first few times the user follows
// any channel.
@interface FirstFollowCoordinator : ChromeCoordinator

// The web channel title to display on the modal.
@property(nonatomic, copy) NSString* webChannelTitle;

@end

#endif  // IOS_CHROME_BROWSER_UI_FOLLOW_FIRST_FOLLOW_COORDINATOR_H_
