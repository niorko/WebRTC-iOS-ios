// Copyright 2023 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_AUTOFILL_AUTOFILL_PROFILE_EDIT_HANDLER_H_
#define IOS_CHROME_BROWSER_UI_AUTOFILL_AUTOFILL_PROFILE_EDIT_HANDLER_H_

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Protocol for updating the autofill profile edit view controller.
@protocol AutofillProfileEditHandler <NSObject>

// Called when the view controller's view has disappeared.
- (void)viewDidDisappear;

// Called for loading the model to the view controller.
- (void)loadModel;

// Called when a row is selected in the view controller.
- (void)didSelectRowAtIndexPath:(NSIndexPath*)indexPath;

// Called for setting `cell` properties at `indexPath`.
- (UITableViewCell*)cell:(UITableViewCell*)cell
       forRowAtIndexPath:(NSIndexPath*)indexPath;

// Returns header sections view controller  whose height should be 0.
- (BOOL)heightForHeaderShouldBeZeroInSection:(NSInteger)section;

// Returns footer sections in the view controller whose height should be 0.
- (BOOL)heightForFooterShouldBeZeroInSection:(NSInteger)section;

// Returns YES if the row is editable for `indexPath` in the view controller.
- (BOOL)canEditRowAtIndexPath:(NSIndexPath*)indexPath;

// Decides the editing style for the `indexPath` in the view controller.
- (UITableViewCellEditingStyle)editingStyleForRowAtIndexPath:
    (NSIndexPath*)indexPath;

// Decides to indent row when editing at `indexPath`.
- (BOOL)shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath*)indexPath;

// Called when the edit button is pressed.
- (void)editButtonPressed;

@end

#endif  // IOS_CHROME_BROWSER_UI_AUTOFILL_AUTOFILL_PROFILE_EDIT_HANDLER_H_
