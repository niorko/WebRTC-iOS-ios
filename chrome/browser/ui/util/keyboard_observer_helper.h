// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_UTIL_KEYBOARD_OBSERVER_HELPER_H_
#define IOS_CHROME_BROWSER_UI_UTIL_KEYBOARD_OBSERVER_HELPER_H_

#import <UIKit/UIKit.h>

@protocol EdgeLayoutGuideProvider;

// Struct to track the current keyboard state.
typedef struct {
  // Is YES if the keyboard is visible or becoming visible.
  BOOL isVisible;
  // Is YES if keyboard is or becoming undocked from bottom of screen.
  BOOL isUndocked;
  // Is YES if a hardware keyboard is in use and only the top part of the
  // software keyboard is showing.
  BOOL isHardware;
} KeyboardState;

// Delegate informed about the visible/hidden state of the keyboard.
@protocol KeyboardObserverHelperConsumer <NSObject>

// Indicates that the keyboard state changed, at least on one of the
// |KeyboardState| aspects.
- (void)keyboardWillChangeToState:(KeyboardState)keyboardState;

@end

// Helper to observe the keyboard and report updates.
@interface KeyboardObserverHelper : NSObject

// Singleton for KeyboardObserverHelper.
+ (instancetype)sharedKeyboardObserver;

- (instancetype)init NS_UNAVAILABLE;

// Adds consumer of KeyboardObserverHelper.
- (void)addConsumer:(id<KeyboardObserverHelperConsumer>)consumer;

// Flag that indicates if the keyboard is on screen.
// TODO(crbug.com/974226): look into deprecating keyboardOnScreen for
// isKeyboardVisible.
@property(nonatomic, readonly, getter=isKeyboardOnScreen) BOOL keyboardOnScreen;

// Returns keyboard's height if it's docked, visible and not hardware.
// Otherwise returns 0.
// Note: This includes the keyboard accessory's height.
@property(nonatomic, readonly) CGFloat visibleKeyboardHeight;

@end

#endif  // IOS_CHROME_BROWSER_UI_UTIL_KEYBOARD_OBSERVER_HELPER_H_
