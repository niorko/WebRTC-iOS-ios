// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/credential_provider_extension/ui/ui_util.h"

#import <AuthenticationServices/AuthenticationServices.h>

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

const CGFloat kUITableViewInsetGroupedTopSpace = 35;

NSString* PromptForServiceIdentifiers(
    NSArray<ASCredentialServiceIdentifier*>* serviceIdentifiers) {
  NSString* identifier = serviceIdentifiers.firstObject.identifier;
  NSURL* promptURL = identifier ? [NSURL URLWithString:identifier] : nil;
  NSString* IDForPrompt = promptURL.host ?: identifier;
  if (!IDForPrompt) {
    return nil;
  }
  NSString* baseLocalizedString = NSLocalizedString(
      @"IDS_IOS_CREDENTIAL_PROVIDER_TITLE_PROMPT",
      @"Extra prompt telling the user what site they are looking at");
  return [baseLocalizedString stringByReplacingOccurrencesOfString:@"$1"
                                                        withString:IDForPrompt];
}
