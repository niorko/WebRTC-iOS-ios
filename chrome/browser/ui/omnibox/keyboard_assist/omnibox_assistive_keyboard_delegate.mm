// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/omnibox/keyboard_assist/omnibox_assistive_keyboard_delegate.h"

#import "base/metrics/user_metrics.h"
#import "base/metrics/user_metrics_action.h"
#import "ios/chrome/browser/ui/commands/application_commands.h"
#import "ios/chrome/browser/ui/commands/browser_commands.h"
#import "ios/chrome/browser/ui/commands/qr_scanner_commands.h"
#import "ios/chrome/browser/ui/location_bar/location_bar_constants.h"
#import "ios/chrome/browser/ui/omnibox/omnibox_text_field_ios.h"
#import "ios/chrome/browser/ui/util/named_guide.h"
#import "ios/public/provider/chrome/browser/voice_search/voice_search_api.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@implementation OmniboxAssistiveKeyboardDelegateImpl

@synthesize applicationCommandsHandler = _applicationCommandsHandler;
@synthesize browserCommandsHandler = _browserCommandsHandler;
@synthesize qrScannerCommandsHandler = _qrScannerCommandsHandler;
@synthesize omniboxTextField = _omniboxTextField;
@synthesize voiceSearchButtonGuide = _voiceSearchButtonGuide;

#pragma mark - Public

- (void)keyboardAccessoryVoiceSearchTouchUpInside:(UIView*)view {
  if (ios::provider::IsVoiceSearchEnabled()) {
    [self.browserCommandsHandler preloadVoiceSearch];
    base::RecordAction(base::UserMetricsAction("MobileCustomRowVoiceSearch"));
    // Since the keyboard accessory view is in a different window than the main
    // UIViewController upon which Voice Search will be presented, the guide
    // must be constrained to a frame instead of the view itself.  The keyboard
    // and its accessory view will be dismissed at the bottom of the screen
    // before the presentation animation, so bottom-align the view's frame.
    if (self.voiceSearchButtonGuide) {
      self.voiceSearchButtonGuide.autoresizingMask =
          (UIViewAutoresizingFlexibleTopMargin |
           UIViewAutoresizingFlexibleRightMargin);
      CGRect frame = view.frame;
      frame.origin.y =
          CGRectGetMaxY(self.voiceSearchButtonGuide.owningView.bounds) -
          CGRectGetHeight(frame);
      self.voiceSearchButtonGuide.constrainedFrame = frame;
    }
    [self.applicationCommandsHandler startVoiceSearch];
  }
}

- (void)keyboardAccessoryCameraSearchTouchUp {
  base::RecordAction(base::UserMetricsAction("MobileCustomRowCameraSearch"));
  [self.qrScannerCommandsHandler showQRScanner];
}

- (void)keyPressed:(NSString*)title {
  NSString* text = [self updateTextForDotCom:title];
  [self.omniboxTextField insertTextWhileEditing:text];
}

#pragma mark - Private

// Insert 'com' without the period if cursor is directly after a period.
- (NSString*)updateTextForDotCom:(NSString*)text {
  if ([text isEqualToString:kDotComTLD]) {
    UITextRange* textRange = [self.omniboxTextField selectedTextRange];
    NSInteger pos = [self.omniboxTextField
        offsetFromPosition:[self.omniboxTextField beginningOfDocument]
                toPosition:textRange.start];
    if (pos > 0 &&
        [[self.omniboxTextField text] characterAtIndex:pos - 1] == '.')
      return [kDotComTLD substringFromIndex:1];
  }
  return text;
}

@end
