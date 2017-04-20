// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_PAYMENTS_PAYMENT_REQUEST_SELECTOR_VIEW_CONTROLLER_H_
#define IOS_CHROME_BROWSER_PAYMENTS_PAYMENT_REQUEST_SELECTOR_VIEW_CONTROLLER_H_

#import <UIKit/UIKit.h>

#import "ios/chrome/browser/ui/collection_view/collection_view_controller.h"

@class PaymentRequestSelectorViewController;
@protocol PaymentRequestSelectorViewControllerDataSource;

// Delegate protocol for PaymentRequestSelectorViewController.
@protocol PaymentRequestSelectorViewControllerDelegate<NSObject>

// Notifies the delegate that the user has selected an item at the given index.
- (void)paymentRequestSelectorViewController:
            (PaymentRequestSelectorViewController*)controller
                        didSelectItemAtIndex:(NSUInteger)index;

// Notifies the delegate that the user has chosen to return to the previous
// screen without making a selection.
- (void)paymentRequestSelectorViewControllerDidFinish:
    (PaymentRequestSelectorViewController*)controller;

@optional

// Notifies the delegate that the user has chosen to add an item.
- (void)paymentRequestSelectorViewControllerDidSelectAddItem:
    (PaymentRequestSelectorViewController*)controller;

@end

// View controller responsible for presenting a list of items provided by the
// supplied data source for selection by the user and communicating the choice
// to the supplied delegate. It displays an optional header item provided by the
// data source above the list of selectable items. The list is followed by an
// optional button to add an item.
@interface PaymentRequestSelectorViewController : CollectionViewController

// The delegate to be notified when the user selects an item, returns without
// selection, or decides to add an item.
@property(nonatomic, weak) id<PaymentRequestSelectorViewControllerDelegate>
    delegate;

// The data source for this view controller.
@property(nonatomic, weak) id<PaymentRequestSelectorViewControllerDataSource>
    dataSource;

// Convenience initializer. Initializes this object with the
// CollectionViewControllerStyleAppBar style and sets up the leading (back)
// button.
- (instancetype)init;

@end

#endif  // IOS_CHROME_BROWSER_PAYMENTS_PAYMENT_REQUEST_SELECTOR_VIEW_CONTROLLER_H_
