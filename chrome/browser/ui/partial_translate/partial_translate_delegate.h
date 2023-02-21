// Copyright 2023 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_PARTIAL_TRANSLATE_PARTIAL_TRANSLATE_DELEGATE_H_
#define IOS_CHROME_BROWSER_UI_PARTIAL_TRANSLATE_PARTIAL_TRANSLATE_DELEGATE_H_

// Protocol for handling link to text and presenting related UI.
@protocol PartialTranslateDelegate

// Handles the link to text menu item selection.
- (void)handlePartialTranslateSelection;

@end

#endif  // IOS_CHROME_BROWSER_UI_PARTIAL_TRANSLATE_PARTIAL_TRANSLATE_DELEGATE_H_
