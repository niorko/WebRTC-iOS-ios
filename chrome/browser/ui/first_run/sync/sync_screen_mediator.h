// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_FIRST_RUN_SYNC_SYNC_SCREEN_MEDIATOR_H_
#define IOS_CHROME_BROWSER_UI_FIRST_RUN_SYNC_SYNC_SCREEN_MEDIATOR_H_

#import <Foundation/Foundation.h>

class AuthenticationService;
class SyncSetupService;

namespace consent_auditor {
class ConsentAuditor;
}

namespace signin {
class IdentityManager;
}

// Mediator that handles the sync operation.
@interface SyncScreenMediator : NSObject

- (instancetype)init NS_UNAVAILABLE;

// Inits the mediator with
// |authenticationService| provides the authentication library.
// |identityManager| gives access to information of users Google identity.
// |consentAuditor| to record the content.
// |syncSetupService| helps triggering the sync flow.
- (instancetype)
    initWithAuthenticationService:(AuthenticationService*)authenticationService
                  identityManager:(signin::IdentityManager*)identityManager
                   consentAuditor:
                       (consent_auditor::ConsentAuditor*)consentAuditor
                 syncSetupService:(SyncSetupService*)syncSetupService
    NS_DESIGNATED_INITIALIZER;

// Starts the sync engine.
// @param confirmationID: The confirmation string ID of sync.
// @param consentIDs: The consent string IDs of sync screen.
- (void)startSyncWithConfirmationID:(const int)confirmationID
                         consentIDs:(NSArray<NSNumber*>*)consentIDs;

@end

#endif  // IOS_CHROME_BROWSER_UI_FIRST_RUN_SYNC_SYNC_SCREEN_MEDIATOR_H_
