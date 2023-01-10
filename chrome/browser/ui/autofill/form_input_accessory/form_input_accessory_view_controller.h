// Copyright 2014 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_AUTOFILL_FORM_INPUT_ACCESSORY_FORM_INPUT_ACCESSORY_VIEW_CONTROLLER_H_
#define IOS_CHROME_BROWSER_UI_AUTOFILL_FORM_INPUT_ACCESSORY_FORM_INPUT_ACCESSORY_VIEW_CONTROLLER_H_

#import <UIKit/UIKit.h>

#import "ios/chrome/browser/ui/autofill/form_input_accessory/form_input_accessory_consumer.h"

@protocol BrandingViewControllerDelegate;
@protocol FormSuggestionClient;
@class ManualFillAccessoryViewController;
@protocol ManualFillAccessoryViewControllerDelegate;

// Creates and manages a custom input accessory view while the user is
// interacting with a form.
@interface FormInputAccessoryViewController
    : UIViewController <FormInputAccessoryConsumer>

// Client in charge of handling actions in suggestions.
@property(nonatomic, weak) id<FormSuggestionClient> formSuggestionClient;

// Delegate object for the branding view controller.
@property(nonatomic, weak) id<BrandingViewControllerDelegate>
    brandingViewControllerDelegate;

// Shows the manual fallback icons as the first option in the suggestions bar,
// and locks them in that position.
- (void)lockManualFallbackView;

// Tells the view to restore the manual fallback icons to a clean state. That
// means no icon selected and the manual fallback view is unlocked.
- (void)reset;

// Instances an object with the desired delegate.
//
// @param manualFillAccessoryViewControllerDelegate the delegate for the actions
// in the manual fallback icons.
// @return A fresh object with the passed delegate.
- (instancetype)initWithManualFillAccessoryViewControllerDelegate:
    (id<ManualFillAccessoryViewControllerDelegate>)
        manualFillAccessoryViewControllerDelegate;

// Unavailable
- (instancetype)init NS_UNAVAILABLE;

@end

#endif  // IOS_CHROME_BROWSER_UI_AUTOFILL_FORM_INPUT_ACCESSORY_FORM_INPUT_ACCESSORY_VIEW_CONTROLLER_H_
