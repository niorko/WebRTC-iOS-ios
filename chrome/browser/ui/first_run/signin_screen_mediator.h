// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_FIRST_RUN_SIGNIN_SCREEN_MEDIATOR_H_
#define IOS_CHROME_BROWSER_UI_FIRST_RUN_SIGNIN_SCREEN_MEDIATOR_H_

#import <Foundation/Foundation.h>

@class ChromeIdentity;
@protocol SigninScreenConsumer;

// Mediator that handles the sign-in operation.
@interface SigninScreenMediator : NSObject

- (instancetype)init NS_DESIGNATED_INITIALIZER;

// Consumer for this mediator.
@property(nonatomic, weak) id<SigninScreenConsumer> consumer;

// The identity currently selected.
@property(nonatomic, strong) ChromeIdentity* selectedIdentity;

@end

#endif  // IOS_CHROME_BROWSER_UI_FIRST_RUN_SIGNIN_SCREEN_MEDIATOR_H_
