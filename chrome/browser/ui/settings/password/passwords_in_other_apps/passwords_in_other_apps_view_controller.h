// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_SETTINGS_PASSWORD_PASSWORDS_IN_OTHER_APPS_PASSWORDS_IN_OTHER_APPS_VIEW_CONTROLLER_H_
#define IOS_CHROME_BROWSER_UI_SETTINGS_PASSWORD_PASSWORDS_IN_OTHER_APPS_PASSWORDS_IN_OTHER_APPS_VIEW_CONTROLLER_H_

#import <UIKit/UIKit.h>
#import "ios/chrome/browser/ui/settings/password/passwords_in_other_apps/passwords_in_other_apps_consumer.h"

// Protocol used to display Passwords In Other Apps promotional page.
@protocol PasswordsInOtherAppsPresenter

// Method invoked when the promotional page is dismissed by the user hitting
// "Back".
- (void)passwordsInOtherAppsViewControllerDidDismiss;

@end

// View controller that shows Passwords In Other Apps promotional page.
@interface PasswordsInOtherAppsViewController
    : UIViewController <PasswordsInOtherAppsConsumer>

// Object that manages showing and dismissal of the current view.
@property(nonatomic, weak) id<PasswordsInOtherAppsPresenter> presenter;

@end

#endif  // IOS_CHROME_BROWSER_UI_SETTINGS_PASSWORD_PASSWORDS_IN_OTHER_APPS_PASSWORDS_IN_OTHER_APPS_VIEW_CONTROLLER_H_
