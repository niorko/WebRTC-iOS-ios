// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_SETTINGS_PASSWORD_PASSWORD_SETTINGS_PASSWORD_SETTINGS_VIEW_CONTROLLER_H_
#define IOS_CHROME_BROWSER_UI_SETTINGS_PASSWORD_PASSWORD_SETTINGS_PASSWORD_SETTINGS_VIEW_CONTROLLER_H_

#import <UIKit/UIKit.h>

#import "ios/chrome/browser/ui/commands/application_commands.h"
#import "ios/chrome/browser/ui/settings/password/password_settings/password_settings_consumer.h"
#import "ios/chrome/browser/ui/table_view/chrome_table_view_controller.h"

// Delegate for the PasswordSettingsViewController to talk to its coordinator.
@protocol PasswordSettingsPresentationDelegate

// Method invoked when the page is dismissed.
- (void)passwordSettingsViewControllerDidDismiss;

// Method invoked when the user requests an export of their saved passwords.
- (void)startExportFlow;

@end

// ViewController used to present settings and infrequently-used actions
// relating to passwords. These are displayed in a submenu, separate from the
// Password Manager itself.
@interface PasswordSettingsViewController
    : ChromeTableViewController <PasswordSettingsConsumer>

// Delegate for communicating with the coordinator.
@property(nonatomic, weak) id<PasswordSettingsPresentationDelegate>
    presentationDelegate;

- (instancetype)init;

// Returns a rect suitable for anchoring alerts in the password export flow.
- (CGRect)sourceRectForPasswordExportAlerts;

// Returns a view suitable for anchoring alerts in the password export flow.
- (UIView*)sourceViewForPasswordExportAlerts;

@end

#endif  // IOS_CHROME_BROWSER_UI_SETTINGS_PASSWORD_PASSWORD_SETTINGS_PASSWORD_SETTINGS_VIEW_CONTROLLER_H_
