// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_AUTHENTICATION_TANGIBLE_SYNC_TANGIBLE_SYNC_MEDIATOR_H_
#define IOS_CHROME_BROWSER_UI_AUTHENTICATION_TANGIBLE_SYNC_TANGIBLE_SYNC_MEDIATOR_H_

#import <UIKit/UIKit.h>

@protocol TangibleSyncConsumer;

// Mediator that handles the sync operations.
@interface TangibleSyncMediator : NSObject

// Consumer for this mediator.
@property(nonatomic, weak) id<TangibleSyncConsumer> consumer;

// Disconnect the mediator.
- (void)disconnect;

@end

#endif  // IOS_CHROME_BROWSER_UI_AUTHENTICATION_TANGIBLE_SYNC_TANGIBLE_SYNC_MEDIATOR_H_
