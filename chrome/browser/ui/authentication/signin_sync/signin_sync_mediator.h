// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_AUTHENTICATION_SIGNIN_SYNC_SIGNIN_SYNC_MEDIATOR_H_
#define IOS_CHROME_BROWSER_UI_AUTHENTICATION_SIGNIN_SYNC_SIGNIN_SYNC_MEDIATOR_H_

#import <Foundation/Foundation.h>

#import "base/ios/block_types.h"

@class AuthenticationFlow;
class AuthenticationService;
class ChromeAccountManagerService;
@class ChromeIdentity;
@protocol SigninSyncConsumer;

@interface SigninSyncMediator : NSObject

// The designated initializer.
- (instancetype)initWithAccountManagerService:
                    (ChromeAccountManagerService*)accountManagerService
                        authenticationService:
                            (AuthenticationService*)authenticationService
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

// Consumer for this mediator.
@property(nonatomic, weak) id<SigninSyncConsumer> consumer;

// The identity currently selected.
@property(nonatomic, strong) ChromeIdentity* selectedIdentity;

// Whether an account has been added. Must be set externally.
@property(nonatomic, assign) BOOL addedAccount;

// Disconnect the mediator.
- (void)disconnect;

// Sign in the selected account.
- (void)startSignInWithAuthenticationFlow:
            (AuthenticationFlow*)authenticationFlow
                               completion:(ProceduralBlock)completion;

@end

#endif  // IOS_CHROME_BROWSER_UI_AUTHENTICATION_SIGNIN_SYNC_SIGNIN_SYNC_MEDIATOR_H_
