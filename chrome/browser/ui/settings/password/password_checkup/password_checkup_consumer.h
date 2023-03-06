// Copyright 2023 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_SETTINGS_PASSWORD_PASSWORD_CHECKUP_PASSWORD_CHECKUP_CONSUMER_H_
#define IOS_CHROME_BROWSER_UI_SETTINGS_PASSWORD_PASSWORD_CHECKUP_PASSWORD_CHECKUP_CONSUMER_H_

#import <Foundation/Foundation.h>

struct InsecurePasswordCounts;

// Enum with all possible states for the Password Checkup homepage.
typedef NS_ENUM(NSInteger, PasswordCheckupHomepageState) {
  // When the password check is completed.
  PasswordCheckupHomepageStateDone,
  // When the password check is running.
  PasswordCheckupHomepageStateRunning,
  // When password check failed due to network issues, quota limit or others.
  PasswordCheckupHomepageStateError,
  // When user has no passwords and check can't be performed.
  PasswordCheckupHomepageStateDisabled,
};

// Consumer for the Password Checkup homepage.
@protocol PasswordCheckupConsumer

// Sets the current PasswordCheckupHomepageState and the insecure password
// counts.
- (void)setPasswordCheckupHomepageState:(PasswordCheckupHomepageState)state
                 insecurePasswordCounts:
                     (InsecurePasswordCounts)insecurePasswordCounts;

// Sets the number of affiliated groups for which the user has saved passwords.
- (void)setAffiliatedGroupCount:(NSInteger)affiliatedGroupCount;

@end

#endif  // IOS_CHROME_BROWSER_UI_SETTINGS_PASSWORD_PASSWORD_CHECKUP_PASSWORD_CHECKUP_CONSUMER_H_
